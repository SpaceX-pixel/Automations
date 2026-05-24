# Chapter 6 — Azure Kubernetes Service (AKS)

> *Mastering DevOps in Kubernetes*
> Architecture · Node Pools · Azure CNI · AAD · Managed Identities · KEDA · Azure DevOps

---

## 1. Introduction & Learning Objectives

Azure Kubernetes Service (AKS) is Microsoft's managed Kubernetes offering, deeply integrated with the Azure ecosystem — Azure Active Directory for identity, Azure Monitor for observability, Azure Policy for governance, and the full Azure networking stack. Like EKS, AKS manages the Kubernetes control plane on your behalf. Unlike EKS, it does so at no charge — you pay only for the worker node VMs, storage, and networking.

AKS has its own architectural opinions that differ meaningfully from EKS: workload identity through Managed Identities and the Azure AD Workload Identity federation, networking through Azure CNI (both Overlay and non-overlay modes), node pool architecture that separates system workloads from user workloads, and deep Azure DevOps integration for end-to-end GitOps CI/CD pipelines.

This chapter builds a production-grade AKS cluster from first principles — provisioned first through the Azure CLI for rapid understanding, then through Terraform for production GitOps workflows. We cover every essential integration: Azure CNI networking, Azure AD authentication, Managed Identities, the Azure Disk and Azure File CSI drivers, KEDA for event-driven autoscaling, Azure Monitor, and a complete Azure DevOps pipeline that builds, scans, and deploys containerized applications to AKS.

> **Learning Objectives**
> - Explain the AKS architecture: control plane, node pools, and the Azure-managed shared responsibility model.
> - Provision AKS clusters using Azure CLI and Terraform with production-ready configurations.
> - Configure system and user node pools with the correct VM SKUs, autoscaling, and taints.
> - Understand Azure CNI, Azure CNI Overlay, and Azure CNI with Cilium network modes and their tradeoffs.
> - Integrate AKS with Azure Active Directory using Managed Identities and Workload Identity federation.
> - Install and configure the Azure Disk CSI driver for block storage and the Azure File CSI driver for shared storage.
> - Deploy and configure KEDA for event-driven autoscaling with Azure Service Bus, Event Hubs, and Storage Queue triggers.
> - Enable Azure Monitor managed Prometheus and Container Insights for cluster observability.
> - Build a complete Azure DevOps pipeline that builds a container image, runs security scanning, and deploys to AKS via Helm.

---

## 2. Core Concepts

### 2.1 AKS Architecture and Shared Responsibility

AKS uses the same control plane / data plane split as EKS, but with a different cost model and a tighter integration with Azure-native services.

```
┌──────────────────────────────────────────────────────────────────────────┐
│  Azure Managed (Free)                              Your Subscription     │
│  ─────────────────────────────────────────────────────────────────────   │
│                                                                          │
│  ┌──────────────────────────────────────────────┐                        │
│  │  AKS Control Plane (Multi-region, managed)   │                        │
│  │                                              │                        │
│  │  kube-apiserver  etcd  Scheduler  Controller │                        │
│  │                                              │                        │
│  │  ✅ Free — no hourly control plane charge    │                        │
│  │  ✅ Auto-patched, SLA-backed (99.95% Uptime) │                        │
│  │  ✅ Automatic etcd backups                   │                        │
│  └──────────────────────────────────────────────┘                        │
│                         │  Kubernetes API                                │
│  ┌──────────────────────▼───────────────────────────────────────────┐    │
│  │  Your Azure Virtual Network                                      │    │
│  │                                                                  │    │
│  │  ┌────────────────────────────────────────────────────────────┐  │    │
│  │  │  System Node Pool (CriticalAddonsOnly taint)               │  │    │
│  │  │  Hosts: CoreDNS, metrics-server, konnectivity-agent        │  │    │
│  │  │  Recommended: D4s_v5 × 3 nodes, across 3 AZs               │  │    │
│  │  └────────────────────────────────────────────────────────────┘  │    │
│  │                                                                  │    │
│  │  ┌────────────────────────────────────────────────────────────┐  │    │
│  │  │  User Node Pool(s)  — your workloads                       │  │    │
│  │  │  Spot Pool · GPU Pool · Memory Pool · General Pool         │  │    │
│  │  └────────────────────────────────────────────────────────────┘  │    │
│  │                                                                  │    │
│  │  Azure Load Balancer · Azure CNI · Azure Disk/File CSI           │    │
│  │  Azure Container Registry · Key Vault · Azure Monitor            │    │
│  └──────────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────────┘
```

#### AKS vs. EKS Comparison

| Feature | AKS | EKS |
|---|---|---|
| Control plane cost | Free | $0.10/hr (~$73/mo) |
| Control plane SLA | 99.95% (Availability Zones) | 99.95% |
| Default network plugin | Azure CNI / Kubenet | AWS VPC CNI |
| Identity federation | Workload Identity (AAD) | IRSA (OIDC + STS) |
| Node OS | Ubuntu 22.04, AzureLinux, Windows | Amazon Linux 2023, Bottlerocket |
| Managed node upgrades | Node image auto-upgrade channels | Managed node group rolling update |
| GitOps integration | Flux CD add-on (native) | No built-in; use Argo CD or Flux |
| Cost model | Pay for nodes only | Pay for nodes + control plane |

---

### 2.2 Node Pools

AKS organizes worker nodes into **node pools** — groups of homogeneous VMs sharing the same VM SKU, OS disk, autoscale configuration, and Kubernetes labels and taints. Every AKS cluster requires exactly one **system node pool** and can have up to 10 **user node pools**.

#### System Node Pool

The system node pool hosts critical Kubernetes system Pods — CoreDNS, metrics-server, the konnectivity agent (which tunnels API server traffic to nodes). It carries the `CriticalAddonsOnly=true:NoSchedule` taint, which prevents user workloads from scheduling on it unless they explicitly tolerate that taint.

```
System node pool requirements:
  - VM SKU: ≥ 2 vCPUs, ≥ 4 GiB RAM (D2s_v5 minimum; D4s_v5 recommended)
  - Minimum node count: 1 (3 recommended for HA)
  - OS: Linux only (system pools cannot run Windows containers)
  - Cannot be deleted while cluster exists
  - Must support Availability Zones for production
```

#### User Node Pools

User node pools host application workloads. You can have specialized pools for different workload profiles — each with its own VM SKU, autoscaling bounds, taints, and labels.

```yaml
# Node pool taint/label pattern for workload isolation
Node pool: gpu-pool
  labels:
    hardware: gpu
    node-type: gpu
  taints:
    - nvidia.com/gpu=present:NoSchedule

Node pool: spot-pool
  labels:
    priority: low
    node-type: spot
  taints:
    - kubernetes.azure.com/scalesetpriority=spot:NoSchedule

Node pool: memory-pool
  labels:
    workload: memory-intensive
  taints:
    - workload=memory-intensive:NoSchedule
```

```yaml
# Workload tolerating the spot taint to run on spot nodes
spec:
  tolerations:
    - key: kubernetes.azure.com/scalesetpriority
      operator: Equal
      value: spot
      effect: NoSchedule
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: node-type
                operator: In
                values: [spot]
```

---

### 2.3 Azure CNI Networking Modes

AKS supports four network plugin configurations. Choosing the right one is one of the most consequential decisions you make at cluster creation time — it cannot be changed without recreating the cluster.

#### Mode 1: Kubenet (Legacy)

Pods receive IPs from a separate, non-routable Pod CIDR. Inter-node Pod traffic is routed via user-defined routes (UDRs). Limited to clusters smaller than 400 nodes (due to UDR limits). Not recommended for new clusters.

#### Mode 2: Azure CNI (Traditional)

Every Pod gets a real Azure VNet IP address — similar to EKS VPC CNI. No overlay, no encapsulation. Pods are directly routable within the VNet.

```
VNet: 10.0.0.0/8
  Node subnet: 10.240.0.0/16
    Node: 10.240.0.5
      Pod A: 10.240.0.6  ← Real VNet IP
      Pod B: 10.240.0.7  ← Real VNet IP
      Pod C: 10.240.0.8  ← Real VNet IP

Tradeoff: IP exhaustion risk (same as EKS VPC CNI)
Requires large, dedicated subnets per node pool
```

#### Mode 3: Azure CNI Overlay (Recommended for new clusters)

Pods get IPs from a private overlay CIDR (`192.168.0.0/16` by default) that is separate from the VNet address space. Traffic between Pods and the VNet is handled transparently.

```
VNet: 10.0.0.0/16 (VNet IPs only used for nodes, not Pods)
  Node: 10.0.1.5 (VNet IP)
    Pod A: 192.168.0.2  ← Overlay IP (not in VNet)
    Pod B: 192.168.0.3  ← Overlay IP
    Pod C: 192.168.0.4  ← Overlay IP

Benefit: No VNet IP exhaustion regardless of Pod count
Benefit: Simpler subnet planning
Tradeoff: Pod IPs are not directly reachable from outside the cluster
```

#### Mode 4: Azure CNI with Cilium (eBPF dataplane)

The newest and most powerful option. Uses Cilium as the CNI with eBPF for data plane processing — replacing iptables entirely. Enables Kubernetes Network Policies plus the full Cilium Network Policy API (L7 HTTP/gRPC policies, DNS-based policies).

```
Azure CNI + Cilium:
  ✅ eBPF dataplane (lower latency, higher throughput than iptables)
  ✅ Full Cilium Network Policy support (L3/L4/L7)
  ✅ Overlay or non-overlay modes
  ✅ Native bandwidth management and egress gateway
  ✅ Hubble for network observability (flow visibility)
  ⚠️ Requires AKS 1.28+ and specific VM SKUs
```

#### Network Mode Comparison

| Mode | Pod IPs | IP Exhaustion Risk | Network Policy | eBPF | Recommended |
|---|---|---|---|---|---|
| Kubenet | Overlay only | Low | Basic | No | Legacy only |
| Azure CNI | Real VNet IPs | High | Basic | No | Small clusters |
| Azure CNI Overlay | Overlay | None | Basic | No | Most new clusters |
| Azure CNI + Cilium | Overlay or VNet | Low/None | Full L7 | Yes | Security-focused |

---

### 2.4 Azure AD Integration and Managed Identities

#### Azure AD-Integrated AKS

When AKS is created with Azure AD integration enabled, the Kubernetes API server uses Azure AD as its identity provider. `kubectl` authentication requires an Azure AD token — no static `kubeconfig` credentials.

```bash
# With AAD integration, kubectl gets a token via device code or az CLI
az aks get-credentials --name my-aks-cluster --resource-group my-rg

# First kubectl command triggers AAD login
kubectl get pods
# To sign in, use a web browser to open the page https://microsoft.com/devicelogin
# and enter the code ABCDEFGH

# For automation (CI/CD), use a service principal or managed identity
# The token is cached and refreshed automatically by kubelogin
```

#### Azure RBAC for Kubernetes (Recommended)

With Azure RBAC enabled, Kubernetes RBAC bindings are replaced by Azure role assignments. You manage access to the cluster through Azure IAM — not `kubectl apply -f rolebinding.yaml`.

```bash
# Grant a user the "Azure Kubernetes Service RBAC Cluster Admin" role
az role assignment create \
  --assignee user@company.com \
  --role "Azure Kubernetes Service RBAC Cluster Admin" \
  --scope /subscriptions/SUB_ID/resourceGroups/my-rg/providers/Microsoft.ContainerService/managedClusters/my-aks

# Grant read-only access to a namespace
az role assignment create \
  --assignee user@company.com \
  --role "Azure Kubernetes Service RBAC Reader" \
  --scope /subscriptions/SUB_ID/resourceGroups/my-rg/providers/Microsoft.ContainerService/managedClusters/my-aks/namespaces/production
```

#### Managed Identities — The AKS Identity Model

AKS uses two types of **Managed Identities** for cluster operations — removing the need for service principal secret rotation:

| Identity | Type | Purpose |
|---|---|---|
| Cluster identity | System-assigned MI | Used by the control plane to manage Azure resources (load balancers, disks, NICs) |
| Kubelet identity | User-assigned MI | Used by nodes to pull from Azure Container Registry, access Key Vault |
| Workload identity | Federated credential | Used by Pods to access Azure services (Key Vault, Storage, Service Bus) |

#### Azure Workload Identity — IRSA Equivalent for AKS

Azure Workload Identity is the AKS equivalent of EKS IRSA. It federates a Kubernetes ServiceAccount with an Azure Managed Identity using OIDC, allowing Pods to assume an Azure identity and call Azure APIs without stored credentials.

```
┌──────────────────────────────────────────────────────────────┐
│  Pod                                                         │
│  serviceAccountName: order-api-sa                            │
│  Azure Workload Identity webhook injects:                    │
│    AZURE_CLIENT_ID    (Managed Identity client ID)           │
│    AZURE_TENANT_ID                                           │
│    AZURE_FEDERATED_TOKEN_FILE  (/var/run/secrets/.../token)  │
└───────────────────────────────┬──────────────────────────────┘
                                │ Token exchange
                                ▼
┌──────────────────────────────────────────────────────────────┐
│  Azure AD (OIDC token validated against AKS OIDC issuer)     │
└───────────────────────────────┬──────────────────────────────┘
                                │ Federated credential matched
                                ▼
┌──────────────────────────────────────────────────────────────┐
│  User-Assigned Managed Identity: order-api-identity          │
│  Role assignments:                                           │
│    Key Vault Secrets User → kv-production                    │
│    Storage Blob Data Reader → sa-order-assets                │
└──────────────────────────────────────────────────────────────┘
```

```bash
# Step 1: Create a User-Assigned Managed Identity
az identity create \
  --name order-api-identity \
  --resource-group my-rg \
  --location eastus

IDENTITY_CLIENT_ID=$(az identity show \
  --name order-api-identity \
  --resource-group my-rg \
  --query clientId -o tsv)

IDENTITY_OBJECT_ID=$(az identity show \
  --name order-api-identity \
  --resource-group my-rg \
  --query principalId -o tsv)

# Step 2: Get the AKS OIDC issuer URL
AKS_OIDC_ISSUER=$(az aks show \
  --name my-aks-cluster \
  --resource-group my-rg \
  --query "oidcIssuerProfile.issuerUrl" -o tsv)

# Step 3: Create the federated credential
az identity federated-credential create \
  --name order-api-federated \
  --identity-name order-api-identity \
  --resource-group my-rg \
  --issuer $AKS_OIDC_ISSUER \
  --subject "system:serviceaccount:production:order-api-sa" \
  --audience api://AzureADTokenExchange

# Step 4: Grant the identity access to Key Vault
az role assignment create \
  --assignee-object-id $IDENTITY_OBJECT_ID \
  --assignee-principal-type ServicePrincipal \
  --role "Key Vault Secrets User" \
  --scope /subscriptions/SUB_ID/resourceGroups/my-rg/providers/Microsoft.KeyVault/vaults/kv-production
```

```yaml
# Step 5: Annotate the Kubernetes ServiceAccount
apiVersion: v1
kind: ServiceAccount
metadata:
  name: order-api-sa
  namespace: production
  annotations:
    azure.workload.identity/client-id: "<IDENTITY_CLIENT_ID>"
  labels:
    azure.workload.identity/use: "true"   # Required label

---
# Step 6: Pod using the ServiceAccount — Azure SDK picks up credentials automatically
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-api
spec:
  template:
    metadata:
      labels:
        azure.workload.identity/use: "true"   # Required label on Pod
    spec:
      serviceAccountName: order-api-sa
      containers:
        - name: api
          image: myacr.azurecr.io/order-api:1.4.2
          # Azure SDK reads AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_FEDERATED_TOKEN_FILE
          # No credentials in the container image or environment
```

---

### 2.5 Azure Disk and File CSI Drivers

#### Azure Disk CSI Driver

Azure Disk CSI driver provisions Azure Managed Disks as Kubernetes PersistentVolumes. Equivalent to EBS CSI in the AWS world.

| Disk Type | IOPS | Throughput | Use Case |
|---|---|---|---|
| Standard HDD (`Standard_LRS`) | Up to 500 | 60 MB/s | Dev/test, backups |
| Standard SSD (`StandardSSD_LRS`) | Up to 6,000 | 750 MB/s | Web servers, light DBs |
| Premium SSD v1 (`Premium_LRS`) | Up to 20,000 | 900 MB/s | Production databases |
| Premium SSD v2 (`PremiumV2_LRS`) | Up to 80,000 | 1,200 MB/s | High-performance DBs |
| Ultra Disk (`UltraSSD_LRS`) | Up to 400,000 | 10,000 MB/s | Most demanding workloads |

```yaml
# Premium SSD v2 StorageClass for production databases
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: premium-ssd-v2
provisioner: disk.csi.azure.com
parameters:
  skuName: PremiumV2_LRS
  cachingMode: None               # Disable caching (write-through unsafe for DBs)
  DiskIOPSReadWrite: "10000"
  DiskMBpsReadWrite: "400"
  networkAccessPolicy: DenyAll    # No public internet access to disk
  publicNetworkAccess: Disabled
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true

---
# Standard SSD for general workloads
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard-ssd
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: disk.csi.azure.com
parameters:
  skuName: StandardSSD_LRS
  cachingMode: ReadOnly
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

#### Azure File CSI Driver

Azure File CSI driver provides SMB and NFS shared filesystems. The NFS protocol option (`nfs`) is strongly preferred over SMB for Linux workloads (better performance, POSIX-compliant).

```yaml
# Azure File NFS StorageClass — ReadWriteMany for shared access
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azurefile-nfs
provisioner: file.csi.azure.com
parameters:
  protocol: nfs                   # NFS 4.1 (preferred over SMB for Linux)
  skuName: Premium_LRS            # Premium required for NFS
  mountOptions: "nconnect=8"      # Multiple TCP connections (throughput improvement)
allowVolumeExpansion: true
reclaimPolicy: Retain
volumeBindingMode: Immediate      # Azure File is globally available — no zone constraint

---
# Azure File SMB StorageClass — Windows containers and legacy apps
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azurefile-smb
provisioner: file.csi.azure.com
parameters:
  skuName: Standard_LRS
  protocol: smb
allowVolumeExpansion: true
reclaimPolicy: Delete
volumeBindingMode: Immediate
```

---

### 2.6 KEDA — Kubernetes Event-Driven Autoscaling

KEDA (Kubernetes Event-Driven Autoscaling) is a CNCF project that originated at Microsoft and integrates particularly deeply with Azure services. While Chapter 3 introduced KEDA conceptually, we cover its Azure-native integrations here in depth.

KEDA extends the Kubernetes HPA to support 60+ event sources. For AKS workloads, the most important Azure scalers are:

| Azure Scaler | Trigger | Common Use Case |
|---|---|---|
| `azure-servicebus` | Queue/topic message count | Async order processing |
| `azure-eventhub` | Consumer group lag | Real-time stream processing |
| `azure-storage-queue` | Queue message count | Background job workers |
| `azure-blob` | Blob count in container | File processing pipelines |
| `azure-monitor` | Any Azure Monitor metric | CPU, memory, custom metrics |
| `azure-pipelines` | Azure DevOps agent pool queue | CI/CD agent autoscaling |
| `http-add-on` | Incoming HTTP request count | Scale-to-zero HTTP services |

#### KEDA with Azure Workload Identity

```bash
# Install KEDA via Helm
helm repo add kedacore https://kedacore.github.io/charts
helm repo update

helm install keda kedacore/keda \
  --namespace keda \
  --create-namespace \
  --set podIdentity.azureWorkload.enabled=true \
  --set resources.operator.requests.cpu=100m \
  --set resources.operator.requests.memory=128Mi \
  --version 2.14.0

kubectl get pods -n keda
# NAME                                      READY   STATUS
# keda-operator-abc123                      1/1     Running
# keda-operator-metrics-apiserver-def456    1/1     Running
```

```yaml
# TriggerAuthentication — tells KEDA to use Workload Identity for Azure API calls
apiVersion: keda.sh/v1alpha1
kind: TriggerAuthentication
metadata:
  name: azure-servicebus-auth
  namespace: production
spec:
  podIdentity:
    provider: azure-workload   # Use AKS Workload Identity — no stored credentials
    identityId: "<IDENTITY_CLIENT_ID>"
```

```yaml
# ScaledObject — scale order-processor based on Service Bus queue depth
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: order-processor-scaler
  namespace: production
spec:
  scaleTargetRef:
    name: order-processor
  minReplicaCount: 0            # Scale to zero when queue is empty
  maxReplicaCount: 50
  pollingInterval: 15           # Check every 15 seconds
  cooldownPeriod: 300           # 5-minute cooldown before scaling to zero
  advanced:
    restoreToOriginalReplicaCount: true  # Restore to pre-KEDA replica count on deletion
    horizontalPodAutoscalerConfig:
      behavior:
        scaleDown:
          stabilizationWindowSeconds: 180
  triggers:
    - type: azure-servicebus
      metadata:
        queueName: order-processing-queue
        namespace: my-servicebus-namespace
        messageCount: "10"       # One replica per 10 messages
        activationMessageCount: "5"  # Start scaling when queue hits 5 messages
      authenticationRef:
        name: azure-servicebus-auth

---
# ScaledObject — scale Event Hub consumer based on partition lag
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: eventhub-processor-scaler
  namespace: production
spec:
  scaleTargetRef:
    name: eventhub-processor
  minReplicaCount: 1
  maxReplicaCount: 20
  triggers:
    - type: azure-eventhub
      metadata:
        eventHubName: telemetry-hub
        eventHubNamespace: my-eventhub-namespace
        consumerGroup: telemetry-processors
        unprocessedEventThreshold: "100"   # One replica per 100 unprocessed events
        activationUnprocessedEventThreshold: "10"
        checkpointStrategy: blobMetadata
        blobContainer: checkpoints
        storageAccountName: mystorageaccount
      authenticationRef:
        name: azure-servicebus-auth

---
# ScaledObject — pre-scale based on Azure Monitor CPU metric (custom scaler)
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: api-gateway-monitor-scaler
  namespace: production
spec:
  scaleTargetRef:
    name: api-gateway
  minReplicaCount: 3
  maxReplicaCount: 30
  triggers:
    - type: azure-monitor
      metadata:
        resourceURI: subscriptions/SUB_ID/resourceGroups/my-rg/providers/Microsoft.Network/applicationGateways/my-agw
        tenantId: TENANT_ID
        subscriptionId: SUB_ID
        resourceGroupName: my-rg
        metricName: CurrentConnections
        metricAggregationType: Average
        metricAggregationInterval: "0:1:0"   # 1-minute aggregation
        targetValue: "200"                    # Scale to handle 200 connections per Pod
        activationTargetValue: "50"
      authenticationRef:
        name: azure-servicebus-auth
```

---

### 2.7 Azure Monitor for Containers

Azure Monitor for containers (now part of **Azure Monitor managed service for Prometheus** + **Container Insights**) provides full-stack observability for AKS.

```
Azure Monitor Observability Stack for AKS:

Metrics:    Azure Monitor managed Prometheus ──▶ Azure Managed Grafana
Logs:       Container Insights (Log Analytics) ──▶ Log Analytics Workspace
Alerts:     Azure Monitor Alerts ──▶ Action Groups (email, PagerDuty, Teams)
Traces:     Azure Monitor Application Insights (OpenTelemetry)
```

---

## 3. Cluster Provisioning with Azure CLI

### 3.1 Prerequisites

```bash
# Install Azure CLI
brew install azure-cli          # macOS
# or
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash   # Ubuntu

# Log in
az login
az account set --subscription "My Production Subscription"

# Install kubectl and kubelogin
az aks install-cli

# Register required resource providers
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.OperationsManagement
az provider register --namespace Microsoft.OperationalInsights
az provider register --namespace Microsoft.Network

# Verify registration
az provider show --namespace Microsoft.ContainerService --query registrationState -o tsv
# Registered
```

### 3.2 Resource Group, VNet, and Supporting Resources

```bash
LOCATION="eastus"
RG="rg-aks-production"
CLUSTER="aks-production"
ACR="acrmycompanyprod"
VNET="vnet-aks-production"
LOG_WORKSPACE="law-aks-production"
GRAFANA="amg-aks-production"

# Resource group
az group create --name $RG --location $LOCATION

# Log Analytics Workspace (for Container Insights)
az monitor log-analytics workspace create \
  --resource-group $RG \
  --workspace-name $LOG_WORKSPACE \
  --retention-time 90

LAW_ID=$(az monitor log-analytics workspace show \
  --resource-group $RG \
  --workspace-name $LOG_WORKSPACE \
  --query id -o tsv)

# Azure Container Registry (for container images)
az acr create \
  --resource-group $RG \
  --name $ACR \
  --sku Premium \
  --zone-redundancy Enabled \
  --admin-enabled false

ACR_ID=$(az acr show --name $ACR --resource-group $RG --query id -o tsv)

# Virtual Network — dedicated subnets per node pool
az network vnet create \
  --resource-group $RG \
  --name $VNET \
  --address-prefix 10.0.0.0/8

az network vnet subnet create \
  --resource-group $RG \
  --vnet-name $VNET \
  --name snet-system-pool \
  --address-prefix 10.240.0.0/19        # /19 = 8,190 addresses for system nodes

az network vnet subnet create \
  --resource-group $RG \
  --vnet-name $VNET \
  --name snet-user-pool \
  --address-prefix 10.241.0.0/16        # /16 for user workloads

az network vnet subnet create \
  --resource-group $RG \
  --vnet-name $VNET \
  --name snet-aks-apigw \
  --address-prefix 10.242.0.0/24        # App Gateway subnet

SYSTEM_SUBNET_ID=$(az network vnet subnet show \
  --resource-group $RG \
  --vnet-name $VNET \
  --name snet-system-pool \
  --query id -o tsv)

USER_SUBNET_ID=$(az network vnet subnet show \
  --resource-group $RG \
  --vnet-name $VNET \
  --name snet-user-pool \
  --query id -o tsv)
```

### 3.3 Create the AKS Cluster

```bash
# Create the AKS cluster with production-grade settings
az aks create \
  --resource-group $RG \
  --name $CLUSTER \
  --kubernetes-version 1.30 \
  --location $LOCATION \
  \
  `# Identity` \
  --enable-managed-identity \
  --enable-oidc-issuer \
  --enable-workload-identity \
  \
  `# Azure AD` \
  --enable-aad \
  --enable-azure-rbac \
  \
  `# System node pool` \
  --node-count 3 \
  --node-vm-size Standard_D4s_v5 \
  --os-sku AzureLinux \
  --node-osdisk-type Ephemeral \
  --node-osdisk-size 128 \
  --zones 1 2 3 \
  --vnet-subnet-id $SYSTEM_SUBNET_ID \
  \
  `# Networking` \
  --network-plugin azure \
  --network-plugin-mode overlay \
  --network-policy cilium \
  --network-dataplane cilium \
  --pod-cidr 192.168.0.0/16 \
  --service-cidr 10.0.0.0/16 \
  --dns-service-ip 10.0.0.10 \
  \
  `# Autoscaling` \
  --enable-cluster-autoscaler \
  --min-count 3 \
  --max-count 10 \
  \
  `# Attach ACR (grants kubelet identity AcrPull)` \
  --attach-acr $ACR_ID \
  \
  `# Monitoring` \
  --enable-addons monitoring \
  --workspace-resource-id $LAW_ID \
  --enable-msi-auth-for-monitoring \
  \
  `# Security` \
  --enable-defender \
  --enable-image-cleaner \
  --image-cleaner-interval-hours 48 \
  \
  `# Upgrade` \
  --auto-upgrade-channel patch \
  --node-os-upgrade-channel NodeImage \
  \
  `# Tags` \
  --tags environment=production team=platform managed-by=azurecli

# Get credentials
az aks get-credentials \
  --resource-group $RG \
  --name $CLUSTER \
  --overwrite-existing

# Verify
kubectl get nodes -o wide
kubectl get pods -A
```

### 3.4 Add User Node Pools

```bash
# General-purpose user node pool
az aks nodepool add \
  --resource-group $RG \
  --cluster-name $CLUSTER \
  --name userpool \
  --node-count 3 \
  --node-vm-size Standard_D8s_v5 \
  --os-sku AzureLinux \
  --node-osdisk-type Ephemeral \
  --zones 1 2 3 \
  --vnet-subnet-id $USER_SUBNET_ID \
  --enable-cluster-autoscaler \
  --min-count 3 \
  --max-count 30 \
  --labels role=general node-type=ondemand \
  --mode User

# Spot node pool for fault-tolerant workloads (up to 90% cheaper)
az aks nodepool add \
  --resource-group $RG \
  --cluster-name $CLUSTER \
  --name spotpool \
  --node-count 0 \
  --node-vm-size Standard_D4s_v5 \
  --priority Spot \
  --eviction-policy Delete \
  --spot-max-price -1 \                # -1 = pay current Spot price
  --zones 1 2 3 \
  --vnet-subnet-id $USER_SUBNET_ID \
  --enable-cluster-autoscaler \
  --min-count 0 \
  --max-count 20 \
  --labels role=spot node-type=spot \
  --node-taints "kubernetes.azure.com/scalesetpriority=spot:NoSchedule" \
  --mode User

# Memory-optimized pool for databases and caches
az aks nodepool add \
  --resource-group $RG \
  --cluster-name $CLUSTER \
  --name mempool \
  --node-count 0 \
  --node-vm-size Standard_E8s_v5 \
  --zones 1 2 3 \
  --vnet-subnet-id $USER_SUBNET_ID \
  --enable-cluster-autoscaler \
  --min-count 0 \
  --max-count 10 \
  --labels role=memory node-type=ondemand \
  --node-taints "workload=memory-intensive:NoSchedule" \
  --mode User
```

---

## 4. Cluster Provisioning with Terraform

### 4.1 Repository Structure

```
aks-infrastructure/
├── environments/
│   ├── production/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars
│   └── staging/
├── modules/
│   ├── aks/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── monitoring/
└── backend.tf
```

### 4.2 Backend and Providers

```hcl
# backend.tf
terraform {
  required_version = ">= 1.7"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.105"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.52"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stterraformstate123"
    container_name       = "tfstate"
    key                  = "aks/production/terraform.tfstate"
    use_oidc             = true   # Use GitHub Actions OIDC or Azure DevOps MI
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }
}
```

### 4.3 Core Infrastructure

```hcl
# environments/production/main.tf
locals {
  location    = "eastus"
  environment = "production"
  cluster_name = "aks-production"
  tags = {
    environment = local.environment
    managed-by  = "terraform"
    project     = "aks-platform"
  }
}

# ── Resource Group ────────────────────────────────────────────────
resource "azurerm_resource_group" "main" {
  name     = "rg-aks-${local.environment}"
  location = local.location
  tags     = local.tags
}

# ── Log Analytics Workspace ───────────────────────────────────────
resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-aks-${local.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = local.location
  sku                 = "PerGB2018"
  retention_in_days   = 90
  tags                = local.tags
}

# ── Azure Container Registry ──────────────────────────────────────
resource "azurerm_container_registry" "main" {
  name                = "acrmycompany${local.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = local.location
  sku                 = "Premium"
  admin_enabled       = false
  zone_redundancy_enabled = true

  georeplications {
    location                = "westus2"
    zone_redundancy_enabled = true
  }

  tags = local.tags
}

# ── Virtual Network ───────────────────────────────────────────────
resource "azurerm_virtual_network" "main" {
  name                = "vnet-aks-${local.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = local.location
  address_space       = ["10.0.0.0/8"]
  tags                = local.tags
}

resource "azurerm_subnet" "system_pool" {
  name                 = "snet-system-pool"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.240.0.0/19"]
}

resource "azurerm_subnet" "user_pool" {
  name                 = "snet-user-pool"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.241.0.0/16"]
}
```

### 4.4 AKS Cluster Resource

```hcl
# ── AKS Cluster ───────────────────────────────────────────────────
resource "azurerm_kubernetes_cluster" "main" {
  name                = local.cluster_name
  resource_group_name = azurerm_resource_group.main.name
  location            = local.location
  kubernetes_version  = "1.30"
  dns_prefix          = local.cluster_name
  sku_tier            = "Standard"        # SLA-backed (99.95%); use Free for dev

  # ── Identity ─────────────────────────────────────────────────
  identity {
    type = "SystemAssigned"
  }

  # Enable OIDC issuer and Workload Identity
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  # ── Azure AD Integration ──────────────────────────────────────
  azure_active_directory_role_based_access_control {
    managed                = true
    azure_rbac_enabled     = true
    # admin_group_object_ids = ["<AAD_GROUP_OBJECT_ID>"]
  }

  # ── System Node Pool ──────────────────────────────────────────
  default_node_pool {
    name                        = "system"
    node_count                  = 3
    vm_size                     = "Standard_D4s_v5"
    os_sku                      = "AzureLinux"
    os_disk_type                = "Ephemeral"
    os_disk_size_gb             = 128
    vnet_subnet_id              = azurerm_subnet.system_pool.id
    zones                       = ["1", "2", "3"]
    auto_scaling_enabled        = true
    min_count                   = 3
    max_count                   = 10
    only_critical_addons_enabled = true  # System pool: system Pods only

    node_labels = {
      "role"      = "system"
      "node-type" = "ondemand"
    }

    upgrade_settings {
      max_surge                     = "33%"
      drain_timeout_in_minutes      = 30
      node_soak_duration_in_minutes = 0
    }
  }

  # ── Networking ────────────────────────────────────────────────
  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "cilium"
    network_dataplane   = "cilium"
    pod_cidr            = "192.168.0.0/16"
    service_cidr        = "10.0.0.0/16"
    dns_service_ip      = "10.0.0.10"
    load_balancer_sku   = "standard"
    outbound_type       = "loadBalancer"
  }

  # ── Add-ons ───────────────────────────────────────────────────
  oms_agent {
    log_analytics_workspace_id      = azurerm_log_analytics_workspace.main.id
    msi_auth_for_monitoring_enabled = true
  }

  azure_policy_enabled             = true
  http_application_routing_enabled = false  # Use AGIC or NGINX instead

  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  # ── Auto-upgrade ──────────────────────────────────────────────
  automatic_upgrade_channel = "patch"
  node_os_upgrade_channel   = "NodeImage"
  maintenance_window_auto_upgrade {
    frequency   = "Weekly"
    interval    = 1
    duration    = 4
    day_of_week = "Sunday"
    start_time  = "02:00"
    utc_offset  = "+00:00"
  }

  # ── Security ──────────────────────────────────────────────────
  microsoft_defender {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  }

  image_cleaner_enabled        = true
  image_cleaner_interval_hours = 48

  # ── Storage ───────────────────────────────────────────────────
  storage_profile {
    blob_driver_enabled         = true
    disk_driver_enabled         = true
    file_driver_enabled         = true
    snapshot_controller_enabled = true
  }

  tags = local.tags

  lifecycle {
    ignore_changes = [
      default_node_pool[0].node_count,   # Managed by Cluster Autoscaler
      kubernetes_version,                 # Managed by auto-upgrade channel
    ]
  }
}

# ── User Node Pools ────────────────────────────────────────────────
resource "azurerm_kubernetes_cluster_node_pool" "user_general" {
  name                  = "userpool"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = "Standard_D8s_v5"
  node_count            = 3
  os_sku                = "AzureLinux"
  os_disk_type          = "Ephemeral"
  vnet_subnet_id        = azurerm_subnet.user_pool.id
  zones                 = ["1", "2", "3"]
  auto_scaling_enabled  = true
  min_count             = 3
  max_count             = 30
  mode                  = "User"

  node_labels = {
    "role"      = "general"
    "node-type" = "ondemand"
  }

  upgrade_settings {
    max_surge = "33%"
  }

  tags = local.tags
}

resource "azurerm_kubernetes_cluster_node_pool" "spot" {
  name                  = "spotpool"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = "Standard_D4s_v5"
  node_count            = 0
  priority              = "Spot"
  eviction_policy       = "Delete"
  spot_max_price        = -1
  vnet_subnet_id        = azurerm_subnet.user_pool.id
  zones                 = ["1", "2", "3"]
  auto_scaling_enabled  = true
  min_count             = 0
  max_count             = 20
  mode                  = "User"

  node_labels = {
    "role"      = "spot"
    "node-type" = "spot"
  }

  node_taints = [
    "kubernetes.azure.com/scalesetpriority=spot:NoSchedule"
  ]

  tags = local.tags
}

# ── Grant AKS kubelet identity AcrPull ────────────────────────────
resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id         = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
  role_definition_name = "AcrPull"
  scope                = azurerm_container_registry.main.id
}

# ── Managed Prometheus + Grafana ──────────────────────────────────
resource "azurerm_monitor_workspace" "main" {
  name                = "amw-aks-${local.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = local.location
}

resource "azurerm_dashboard_grafana" "main" {
  name                              = "amg-aks-${local.environment}"
  resource_group_name               = azurerm_resource_group.main.name
  location                          = local.location
  sku                               = "Standard"
  grafana_major_version             = 10
  zone_redundancy_enabled           = true
  azure_monitor_workspace_integrations {
    resource_id = azurerm_monitor_workspace.main.id
  }
  tags = local.tags
}
```

### 4.5 Outputs

```hcl
# outputs.tf
output "cluster_name" {
  value = azurerm_kubernetes_cluster.main.name
}

output "cluster_id" {
  value = azurerm_kubernetes_cluster.main.id
}

output "oidc_issuer_url" {
  value = azurerm_kubernetes_cluster.main.oidc_issuer_url
}

output "kubelet_identity_object_id" {
  value = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}

output "acr_login_server" {
  value = azurerm_container_registry.main.login_server
}

output "configure_kubectl" {
  value = "az aks get-credentials --name ${azurerm_kubernetes_cluster.main.name} --resource-group ${azurerm_resource_group.main.name}"
}
```

```bash
# Deploy
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# Connect
$(terraform output -raw configure_kubectl)
kubectl get nodes
```

---

## 5. Azure Monitor — Prometheus and Container Insights

### 5.1 Enable Managed Prometheus Scraping

```bash
# Enable Azure Monitor managed Prometheus on existing cluster
az aks update \
  --name $CLUSTER \
  --resource-group $RG \
  --enable-azure-monitor-metrics \
  --azure-monitor-workspace-resource-id \
    "/subscriptions/SUB_ID/resourceGroups/$RG/providers/microsoft.monitor/accounts/amw-aks-production"

# Link Grafana to the Azure Monitor workspace
az grafana update \
  --name $GRAFANA \
  --resource-group $RG

# Browse pre-built AKS dashboards in Azure Managed Grafana
# Dashboards available out-of-the-box:
# - Kubernetes / Compute Resources / Cluster
# - Kubernetes / Compute Resources / Namespace (Pods)
# - Kubernetes / Networking / Cluster
# - Node Exporter / Nodes
```

### 5.2 Custom Prometheus Rules

```yaml
# PrometheusRuleGroup — define recording rules and alerts
apiVersion: azuremonitor.microsoft.com/v1
kind: PrometheusRuleGroup
metadata:
  name: aks-alerts
  namespace: kube-system
spec:
  clusterName: aks-production
  interval: PT1M
  rules:
    # Alert: Pod OOM killed
    - alert: PodOOMKilled
      expr: |
        kube_pod_container_status_last_terminated_reason{reason="OOMKilled"} == 1
      for: PT0S
      severity: 3
      annotations:
        summary: "Pod {{ $labels.namespace }}/{{ $labels.pod }} was OOM killed"
        description: "Container {{ $labels.container }} exceeded its memory limit"

    # Alert: High restart count
    - alert: PodHighRestartCount
      expr: |
        increase(kube_pod_container_status_restarts_total[1h]) > 5
      for: PT5M
      severity: 3
      annotations:
        summary: "Pod {{ $labels.pod }} has restarted {{ $value }} times in 1h"

    # Alert: Deployment replica mismatch
    - alert: DeploymentReplicaMismatch
      expr: |
        kube_deployment_spec_replicas != kube_deployment_status_ready_replicas
      for: PT15M
      severity: 2
      annotations:
        summary: "Deployment {{ $labels.namespace }}/{{ $labels.deployment }} has replica mismatch"

    # Recording rule: request rate per service
    - record: job:http_requests_per_second:rate5m
      expr: |
        sum by (namespace, service) (
          rate(http_requests_total[5m])
        )
```

### 5.3 Container Insights Log Queries

```kusto
// KQL — Top 10 containers by CPU usage in the last hour
KubePodInventory
| where TimeGenerated > ago(1h)
| where ClusterName == "aks-production"
| join kind=inner (
    Perf
    | where ObjectName == "K8SContainer"
    | where CounterName == "cpuUsageNanoCores"
    | summarize AvgCPU = avg(CounterValue) by InstanceName
) on $left.ContainerID == $right.InstanceName
| top 10 by AvgCPU desc
| project Namespace, PodName=Name, ContainerName, AvgCPU

// KQL — Find all OOMKilled events in the last 24h
KubeEvents
| where TimeGenerated > ago(24h)
| where ClusterName == "aks-production"
| where Reason == "OOMKilling"
| project TimeGenerated, Namespace, Name, Message
| order by TimeGenerated desc

// KQL — Container restart anomalies
KubePodInventory
| where TimeGenerated > ago(1h)
| where ClusterName == "aks-production"
| where ContainerRestartCount > 3
| summarize MaxRestarts = max(ContainerRestartCount) by Namespace, PodName = Name, ContainerName
| order by MaxRestarts desc

// KQL — Average request latency per namespace (requires app instrumentation)
AppRequests
| where TimeGenerated > ago(1h)
| summarize P50 = percentile(DurationMs, 50),
            P95 = percentile(DurationMs, 95),
            P99 = percentile(DurationMs, 99),
            RequestCount = count()
  by Cloud_RoleName, bin(TimeGenerated, 5m)
| order by TimeGenerated desc
```

---

## 6. Azure DevOps Pipeline Integration

### 6.1 Pipeline Architecture

```
Developer
  │  git push → feature branch
  ▼
Azure Repos (Git)
  │  Pull Request
  ▼
Azure Pipelines — PR Validation Pipeline
  │  ├── Lint & unit tests
  │  ├── Docker build (multi-stage)
  │  ├── Trivy image scan (block on CRITICAL)
  │  └── Helm chart validation (helm lint + helm template)
  │
  │  Merge to main
  ▼
Azure Pipelines — CI Pipeline
  │  ├── Build & push image → Azure Container Registry
  │  ├── Sign image with Notation (Azure Key Vault)
  │  └── Update Helm values (image tag → GitOps repo)
  │
  ▼
Flux CD (GitOps operator on AKS)
  │  Detect Helm values change in Git
  ▼
AKS — Rolling deployment
  │  Readiness probes gate traffic cutover
  ▼
Azure Monitor — Post-deploy health check alert
```

### 6.2 Azure DevOps Service Connection

```bash
# Create a service connection from Azure DevOps to AKS
# This grants Azure Pipelines permission to deploy to the cluster

# Option 1: Workload Identity Federation (recommended — no secrets)
# In Azure DevOps: Project Settings → Service Connections → New → Azure Resource Manager
# Choose: Workload Identity Federation (automatic)

# Option 2: AKS service connection (creates a service account in the cluster)
# In Azure DevOps: Project Settings → Service Connections → New → Kubernetes
# Choose your AKS cluster from the dropdown

# The pipeline uses the service connection name in YAML:
# - task: KubernetesManifest@1
#   inputs:
#     connectionType: azureResourceManager
#     azureSubscriptionConnection: 'my-azure-service-connection'
#     azureResourceGroup: rg-aks-production
#     kubernetesCluster: aks-production
```

### 6.3 Full Azure DevOps Pipeline YAML

```yaml
# azure-pipelines.yml
# Triggers on every commit to main; PRs run validation only

trigger:
  branches:
    include:
      - main
  paths:
    exclude:
      - docs/**
      - "*.md"

pr:
  branches:
    include:
      - main

variables:
  ACR_NAME: "acrmycompanyprod"
  ACR_LOGIN_SERVER: "acrmycompanyprod.azurecr.io"
  IMAGE_REPO: "order-api"
  HELM_CHART_PATH: "$(Build.SourcesDirectory)/helm/order-api"
  K8S_NAMESPACE: "production"
  AZ_SERVICE_CONNECTION: "aks-production-service-connection"
  AKS_RESOURCE_GROUP: "rg-aks-production"
  AKS_CLUSTER_NAME: "aks-production"

stages:
  # ────────────────────────────────────────────────────────────────
  # Stage 1: Validate (runs on every PR and push)
  # ────────────────────────────────────────────────────────────────
  - stage: Validate
    displayName: "Validate & Test"
    jobs:
      - job: Lint_and_Test
        displayName: "Lint, Unit Tests, and Chart Validation"
        pool:
          vmImage: ubuntu-latest
        steps:
          - checkout: self
            fetchDepth: 0            # Full history for git describe

          - task: NodeTool@0
            displayName: "Install Node.js"
            inputs:
              versionSpec: "20.x"

          - script: |
              npm ci
              npm run lint
              npm run test -- --coverage
            displayName: "Run linting and unit tests"
            workingDirectory: $(Build.SourcesDirectory)

          - task: PublishTestResults@2
            displayName: "Publish test results"
            inputs:
              testResultsFormat: JUnit
              testResultsFiles: "**/test-results.xml"

          - task: PublishCodeCoverageResults@2
            displayName: "Publish code coverage"
            inputs:
              codeCoverageTool: Cobertura
              summaryFileLocation: "**/coverage/cobertura-coverage.xml"

          - script: |
              curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
              helm lint $(HELM_CHART_PATH) \
                --values $(HELM_CHART_PATH)/values.yaml \
                --values $(HELM_CHART_PATH)/values-production.yaml
              helm template order-api $(HELM_CHART_PATH) \
                --values $(HELM_CHART_PATH)/values-production.yaml \
                | kubectl apply --dry-run=client -f -
            displayName: "Helm lint and dry-run"

  # ────────────────────────────────────────────────────────────────
  # Stage 2: Build and Push (main branch only)
  # ────────────────────────────────────────────────────────────────
  - stage: Build
    displayName: "Build and Push Container Image"
    condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
    dependsOn: Validate
    jobs:
      - job: Build_Image
        displayName: "Docker Build, Scan, and Push"
        pool:
          vmImage: ubuntu-latest
        variables:
          IMAGE_TAG: "$(Build.BuildNumber)-$(Build.SourceVersion)"
          FULL_IMAGE: "$(ACR_LOGIN_SERVER)/$(IMAGE_REPO):$(IMAGE_TAG)"

        steps:
          - checkout: self
            fetchDepth: 0

          # Login to ACR using the pipeline's Managed Identity
          - task: AzureCLI@2
            displayName: "Login to Azure Container Registry"
            inputs:
              azureSubscription: $(AZ_SERVICE_CONNECTION)
              scriptType: bash
              scriptLocation: inlineScript
              inlineScript: |
                az acr login --name $(ACR_NAME)

          # Build the multi-stage Docker image
          - task: Docker@2
            displayName: "Build container image"
            inputs:
              command: build
              dockerfile: Dockerfile
              buildContext: $(Build.SourcesDirectory)
              repository: $(ACR_LOGIN_SERVER)/$(IMAGE_REPO)
              tags: |
                $(IMAGE_TAG)
                latest
              arguments: >
                --build-arg BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
                --build-arg GIT_SHA=$(Build.SourceVersion)
                --cache-from $(ACR_LOGIN_SERVER)/$(IMAGE_REPO):latest

          # Scan for vulnerabilities with Trivy
          - script: |
              curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin

              trivy image \
                --exit-code 1 \
                --severity CRITICAL \
                --ignore-unfixed \
                --format table \
                --output $(Build.ArtifactStagingDirectory)/trivy-report.txt \
                $(ACR_LOGIN_SERVER)/$(IMAGE_REPO):$(IMAGE_TAG)
            displayName: "Trivy vulnerability scan (block on CRITICAL)"

          - task: PublishBuildArtifacts@1
            displayName: "Publish Trivy scan report"
            condition: always()
            inputs:
              pathToPublish: $(Build.ArtifactStagingDirectory)/trivy-report.txt
              artifactName: security-reports

          # Push image to ACR
          - task: Docker@2
            displayName: "Push image to ACR"
            inputs:
              command: push
              repository: $(ACR_LOGIN_SERVER)/$(IMAGE_REPO)
              tags: |
                $(IMAGE_TAG)
                latest

          # Export the image tag for downstream stages
          - script: |
              echo "##vso[task.setvariable variable=IMAGE_TAG;isOutput=true]$(IMAGE_TAG)"
              echo "##vso[task.setvariable variable=FULL_IMAGE;isOutput=true]$(FULL_IMAGE)"
            name: export_vars
            displayName: "Export image tag to pipeline"

  # ────────────────────────────────────────────────────────────────
  # Stage 3: Deploy to Staging
  # ────────────────────────────────────────────────────────────────
  - stage: Deploy_Staging
    displayName: "Deploy to Staging"
    condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
    dependsOn: Build
    variables:
      IMAGE_TAG: $[ stageDependencies.Build.Build_Image.outputs['export_vars.IMAGE_TAG'] ]
    jobs:
      - deployment: Deploy_Staging
        displayName: "Helm deploy to staging"
        environment: staging                # Azure DevOps Environment (approval gate)
        pool:
          vmImage: ubuntu-latest
        strategy:
          runOnce:
            deploy:
              steps:
                - task: AzureCLI@2
                  displayName: "Get AKS credentials"
                  inputs:
                    azureSubscription: $(AZ_SERVICE_CONNECTION)
                    scriptType: bash
                    scriptLocation: inlineScript
                    inlineScript: |
                      az aks get-credentials \
                        --resource-group $(AKS_RESOURCE_GROUP) \
                        --name $(AKS_CLUSTER_NAME) \
                        --overwrite-existing

                - script: |
                    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

                    helm upgrade --install order-api $(HELM_CHART_PATH) \
                      --namespace staging \
                      --create-namespace \
                      --values $(HELM_CHART_PATH)/values.yaml \
                      --values $(HELM_CHART_PATH)/values-staging.yaml \
                      --set image.tag=$(IMAGE_TAG) \
                      --set image.repository=$(ACR_LOGIN_SERVER)/$(IMAGE_REPO) \
                      --wait \
                      --timeout 5m \
                      --atomic \
                      --history-max 5
                  displayName: "Helm upgrade (staging)"

                - script: |
                    # Run smoke tests against staging
                    STAGING_URL=$(kubectl get ingress order-api -n staging \
                      -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

                    for endpoint in /health /api/v1/orders; do
                      STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://$STAGING_URL$endpoint)
                      if [ "$STATUS" != "200" ]; then
                        echo "Smoke test FAILED: $endpoint returned $STATUS"
                        exit 1
                      fi
                      echo "Smoke test PASSED: $endpoint returned $STATUS"
                    done
                  displayName: "Run smoke tests"

  # ────────────────────────────────────────────────────────────────
  # Stage 4: Deploy to Production (with approval gate)
  # ────────────────────────────────────────────────────────────────
  - stage: Deploy_Production
    displayName: "Deploy to Production"
    condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
    dependsOn: Deploy_Staging
    variables:
      IMAGE_TAG: $[ stageDependencies.Build.Build_Image.outputs['export_vars.IMAGE_TAG'] ]
    jobs:
      - deployment: Deploy_Production
        displayName: "Helm deploy to production"
        environment: production             # Requires manual approval in Azure DevOps
        pool:
          vmImage: ubuntu-latest
        strategy:
          runOnce:
            deploy:
              steps:
                - task: AzureCLI@2
                  displayName: "Get AKS credentials"
                  inputs:
                    azureSubscription: $(AZ_SERVICE_CONNECTION)
                    scriptType: bash
                    scriptLocation: inlineScript
                    inlineScript: |
                      az aks get-credentials \
                        --resource-group $(AKS_RESOURCE_GROUP) \
                        --name $(AKS_CLUSTER_NAME) \
                        --overwrite-existing

                - script: |
                    helm upgrade --install order-api $(HELM_CHART_PATH) \
                      --namespace $(K8S_NAMESPACE) \
                      --create-namespace \
                      --values $(HELM_CHART_PATH)/values.yaml \
                      --values $(HELM_CHART_PATH)/values-production.yaml \
                      --set image.tag=$(IMAGE_TAG) \
                      --set image.repository=$(ACR_LOGIN_SERVER)/$(IMAGE_REPO) \
                      --wait \
                      --timeout 10m \
                      --atomic \
                      --history-max 5 \
                      --set podAnnotations."deploy-time"="$(date -u +%Y%m%dT%H%M%SZ)"
                  displayName: "Helm upgrade (production)"

                - task: AzureCLI@2
                  displayName: "Post-deploy health verification"
                  inputs:
                    azureSubscription: $(AZ_SERVICE_CONNECTION)
                    scriptType: bash
                    scriptLocation: inlineScript
                    inlineScript: |
                      # Wait for rollout to complete
                      kubectl rollout status deployment/order-api -n $(K8S_NAMESPACE) --timeout=5m

                      # Check all pods are ready
                      READY=$(kubectl get deployment order-api -n $(K8S_NAMESPACE) \
                        -o jsonpath='{.status.readyReplicas}')
                      DESIRED=$(kubectl get deployment order-api -n $(K8S_NAMESPACE) \
                        -o jsonpath='{.spec.replicas}')

                      if [ "$READY" != "$DESIRED" ]; then
                        echo "Deployment FAILED: $READY/$DESIRED replicas ready"
                        kubectl rollout undo deployment/order-api -n $(K8S_NAMESPACE)
                        exit 1
                      fi
                      echo "Deployment SUCCEEDED: $READY/$DESIRED replicas ready"
```

---

## 7. Step-by-Step Hands-on Walkthrough

### 7.1 Deploy KEDA with Azure Service Bus Scaling

```bash
# Create Azure Service Bus namespace and queue
az servicebus namespace create \
  --resource-group $RG \
  --name my-servicebus-ns \
  --location $LOCATION \
  --sku Standard

az servicebus queue create \
  --resource-group $RG \
  --namespace-name my-servicebus-ns \
  --name order-processing-queue

# Get the connection string
SB_CONNECTION=$(az servicebus namespace authorization-rule keys list \
  --resource-group $RG \
  --namespace-name my-servicebus-ns \
  --name RootManageSharedAccessKey \
  --query primaryConnectionString -o tsv)

# Create Kubernetes Secret with the connection string
kubectl create secret generic servicebus-secret \
  --from-literal=connection-string="$SB_CONNECTION" \
  --namespace production
```

```yaml
# keda-servicebus-demo.yaml
---
# The worker Deployment (scales from 0 to N based on queue depth)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-processor
  namespace: production
spec:
  replicas: 0                    # KEDA manages replica count; start at 0
  selector:
    matchLabels:
      app: order-processor
  template:
    metadata:
      labels:
        app: order-processor
    spec:
      containers:
        - name: processor
          image: acrmycompanyprod.azurecr.io/order-processor:latest
          resources:
            requests:
              cpu: 250m
              memory: 256Mi
            limits:
              cpu: 500m
              memory: 512Mi
          env:
            - name: SERVICEBUS_CONNECTION_STRING
              valueFrom:
                secretKeyRef:
                  name: servicebus-secret
                  key: connection-string
            - name: QUEUE_NAME
              value: order-processing-queue

---
# TriggerAuthentication using a stored secret
apiVersion: keda.sh/v1alpha1
kind: TriggerAuthentication
metadata:
  name: servicebus-trigger-auth
  namespace: production
spec:
  secretTargetRef:
    - parameter: connection
      name: servicebus-secret
      key: connection-string

---
# ScaledObject
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: order-processor-scaler
  namespace: production
spec:
  scaleTargetRef:
    name: order-processor
  minReplicaCount: 0
  maxReplicaCount: 30
  pollingInterval: 10
  cooldownPeriod: 120
  triggers:
    - type: azure-servicebus
      metadata:
        queueName: order-processing-queue
        namespace: my-servicebus-ns
        messageCount: "5"
      authenticationRef:
        name: servicebus-trigger-auth
```

```bash
kubectl apply -f keda-servicebus-demo.yaml

# Watch KEDA scale from zero as messages are enqueued
kubectl get scaledobject -n production --watch
# NAME                     SCALETARGETKIND      SCALETARGETNAME    MIN   MAX   READY   ACTIVE
# order-processor-scaler   apps/Deployments     order-processor    0     30    True    False

# Send test messages using Azure CLI (simulates producers)
for i in $(seq 1 50); do
  az servicebus message send \
    --resource-group $RG \
    --namespace-name my-servicebus-ns \
    --queue-name order-processing-queue \
    --body "{\"orderId\": \"order-$i\"}"
done

# Watch the scaler activate and Pods appear
kubectl get pods -n production -l app=order-processor --watch
# (Pods appear from 0 as the queue fills)

kubectl describe scaledobject order-processor-scaler -n production
```

### 7.2 Deploy with Azure File NFS for Shared Config

```bash
# Apply the NFS StorageClass and a shared PVC
kubectl apply -f - <<'EOF'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azurefile-nfs
provisioner: file.csi.azure.com
parameters:
  protocol: nfs
  skuName: Premium_LRS
allowVolumeExpansion: true
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shared-config
  namespace: production
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: azurefile-nfs
  resources:
    requests:
      storage: 100Gi
EOF

# Verify the PVC is bound
kubectl get pvc shared-config -n production
# NAME            STATUS   VOLUME         CAPACITY   ACCESS MODES   STORAGECLASS
# shared-config   Bound    pvc-abc123     100Gi      RWX            azurefile-nfs

# Mount in multiple Pods simultaneously — both read and write to the same share
kubectl run writer --image=alpine --restart=Never -n production \
  --overrides='{"spec":{"volumes":[{"name":"config","persistentVolumeClaim":{"claimName":"shared-config"}}],"containers":[{"name":"writer","image":"alpine","command":["sh","-c","echo hello-from-writer > /config/message.txt && sleep 3600"],"volumeMounts":[{"mountPath":"/config","name":"config"}]}]}}' &

kubectl run reader --image=alpine --restart=Never -n production \
  --overrides='{"spec":{"volumes":[{"name":"config","persistentVolumeClaim":{"claimName":"shared-config"}}],"containers":[{"name":"reader","image":"alpine","command":["sh","-c","sleep 5 && cat /config/message.txt"],"volumeMounts":[{"mountPath":"/config","name":"config"}]}]}}' &

kubectl logs reader -n production
# hello-from-writer
```

---

## 8. Real-World Scenario: Retail Bank Microservices Modernization

### The Problem

Contoso Bank runs 47 microservices on bare-metal VMs spread across two datacenters. They face a mandatory compliance deadline requiring encrypted data at rest, end-to-end mTLS between services, and a full audit trail of all Kubernetes API calls. Their VM-based infrastructure cannot meet these requirements without a 14-month re-architecture project.

### The Architecture

```
Azure AD (Identity for all cluster access)
    │
    ▼
AKS Cluster (Private cluster — no public API endpoint)
    │
    ├── System Node Pool: D4s_v5 × 3 (AZ-spread, CriticalAddonsOnly)
    ├── User Node Pool: D8s_v5 × 5–30 (autoscaling, Azure Linux)
    └── Spot Pool: D4s_v5 × 0–20 (batch, reporting workloads)
    │
    ├── Azure CNI with Cilium (eBPF dataplane + L7 network policies)
    ├── Azure Policy (enforce: no privileged containers, require resource limits)
    ├── Microsoft Defender for Containers (runtime threat detection)
    │
    ├── Workload Identity (each service → dedicated Managed Identity)
    │     ├── payments-svc → Key Vault (certificate access)
    │     ├── ledger-svc → Azure SQL (Managed Identity auth)
    │     └── notification-svc → Service Bus (queue access)
    │
    ├── KEDA (Service Bus scaling for async payment processing)
    ├── Azure Monitor (Prometheus + Grafana + Log Analytics)
    └── Azure DevOps Pipelines (4-stage: validate → build → staging → prod)
```

### Key Compliance Decisions

**Encryption at rest:** All Azure Disk PVCs use Premium SSD v2 with a customer-managed KMS key stored in Azure Key Vault. All ACR images are encrypted with the same key.

**mTLS between services:** Azure CNI with Cilium enforces mutual TLS between all namespaces using CiliumNetworkPolicy with L7 visibility. Cilium Hubble provides audit-quality network flow logs showing every connection between services.

**API audit logging:** AKS control plane audit logs are streamed to Log Analytics. Azure Policy denies any cluster changes that bypass the pipeline (enforced via `AKS-Audit` policy definition).

**Secret management:** Azure Key Vault with the Secrets Store CSI driver mounts secrets directly into Pods as files. No secrets are stored in Kubernetes Secret objects.

### Results

| Requirement | Before | After |
|---|---|---|
| Encrypted data at rest | Partial (some VMs) | Full (all PVCs, all images) |
| mTLS between services | None | Full (Cilium L7 policies) |
| API audit trail | None | Complete (Log Analytics, 2yr retention) |
| Secret rotation | Manual (quarterly) | Automatic (Key Vault, 24hr rotation) |
| Compliance readiness | Failed 6 of 12 controls | Passed all 12 controls |
| Deployment time per service | 3 hours | 12 minutes |

---

## 9. Common Pitfalls & Best Practices

### Pitfall 1: Choosing Azure CNI Traditional Without Planning for IP Exhaustion
Azure CNI traditional allocates real VNet IPs to every Pod. A 50-node cluster with 30 Pods per node needs 1,500 VNet IPs — plus headroom for rolling updates. Teams that start with a `/24` subnet (254 IPs) hit `SubnetIsFull` errors within days. **Use Azure CNI Overlay for new clusters unless you have specific requirements for Pod-level VNet routing. If you must use traditional Azure CNI, provision `/19` or larger subnets per node pool before cluster creation.**

### Pitfall 2: System Node Pool Running User Workloads
Without the `CriticalAddonsOnly=true:NoSchedule` taint on the system pool, user Pods schedule there. Under load, user workloads starve CoreDNS and other system components of resources, breaking DNS resolution cluster-wide. **Always enable `only_critical_addons_enabled = true` on the system node pool in Terraform, or pass `--node-taints CriticalAddonsOnly=true:NoSchedule` in the Azure CLI.**

### Pitfall 3: Skipping Workload Identity for Azure Service Access
Teams frequently store Azure Storage connection strings or Key Vault access keys in Kubernetes Secrets, then rotate them manually. This creates a secret sprawl problem and a credential leakage risk. **Use Azure Workload Identity for every workload that calls an Azure API. The Managed Identity token is rotated automatically by the Azure AD Workload Identity webhook.**

### Pitfall 4: KEDA ScaledObject Without a Fallback minReplicaCount
Setting `minReplicaCount: 0` enables scale-to-zero, which is powerful for batch workloads. But for latency-sensitive services, a cold start (waiting for a Fargate-equivalent micro-VM or for the container image to pull) adds 30–90 seconds to the first request after scale-from-zero. **Set `minReplicaCount: 1` or higher for any service with a latency SLO. Reserve scale-to-zero for truly async, latency-insensitive workloads.**

### Pitfall 5: Deploying to Production Without Azure DevOps Environment Approvals
A pipeline that deploys automatically to production on every merge to `main` — without a human approval gate — is an incident waiting to happen. A bad Helm values file or a misconfigured resource request can silently cause production downtime. **Configure an Azure DevOps Environment with required approver sign-off and a 5-minute delay window before production deployments. Use `--atomic` in `helm upgrade` to auto-rollback on failure.**

### Pitfall 6: Not Enabling Auto-Upgrade Channels
AKS clusters on unsupported Kubernetes versions lose access to security patches and support. Teams forget to upgrade until they are 3-4 minor versions behind, at which point the upgrade path requires multiple intermediate jumps. **Set `auto_upgrade_channel = "patch"` and `node_os_upgrade_channel = "NodeImage"` in Terraform. Patch upgrades are low-risk and handled by AKS with rolling node replacements.**

> **AKS Production Readiness Checklist**
> - [ ] Azure CNI Overlay selected for new clusters (or VNet subnets sized `/19`+)
> - [ ] System node pool has `only_critical_addons_enabled = true`
> - [ ] Availability Zones enabled for all node pools
> - [ ] Cluster Autoscaler enabled with appropriate min/max bounds
> - [ ] OIDC issuer and Workload Identity enabled; no static credentials in Pods
> - [ ] Azure RBAC enabled; access managed via Azure role assignments
> - [ ] ACR attached to cluster (kubelet identity has AcrPull)
> - [ ] Auto-upgrade channel set to `patch`; node OS upgrade to `NodeImage`
> - [ ] Microsoft Defender for Containers enabled
> - [ ] Azure Monitor managed Prometheus + Container Insights enabled
> - [ ] Log Analytics workspace with 90-day retention
> - [ ] KEDA installed for event-driven and scale-to-zero workloads
> - [ ] Azure DevOps pipeline with production approval gate and `--atomic` Helm deploy
> - [ ] PodDisruptionBudgets on all production Deployments

---

## 10. Key Takeaways

1. **AKS's free control plane and tight Azure integration make it the most cost-effective managed Kubernetes option for Azure-native teams.** The zero-cost control plane, combined with built-in Azure AD integration, free Managed Identities, and native Azure Monitor integration, means fewer third-party tools to manage.

2. **Azure CNI Overlay is the right networking choice for most new AKS clusters.** It eliminates VNet IP exhaustion risk entirely, retains full Azure networking capabilities, and supports Cilium eBPF with L7 network policies. Traditional Azure CNI is only necessary when you need Pod IPs directly reachable from on-premise networks.

3. **Azure Workload Identity is the AKS equivalent of EKS IRSA** — and using it consistently is the single highest-impact security improvement you can make. Every Pod that calls Azure APIs should have its own Managed Identity with the minimum required role assignments, with zero stored credentials.

4. **KEDA's Azure-native scalers unlock scale-to-zero patterns that HPA alone cannot achieve.** Service Bus queue depth, Event Hub consumer lag, and Storage Queue length are the most natural scaling dimensions for Azure workloads. KEDA integrates these directly with Kubernetes autoscaling without custom metrics adapters.

5. **Azure DevOps pipelines with Environment approval gates provide the governance layer that prevents "push to prod" accidents.** The combination of Trivy scanning (blocking on CRITICAL), `helm upgrade --atomic` (auto-rollback on failure), staged deployments (staging → production), and required human approval covers the four most common causes of production incidents from deployments.

6. **AKS's node pool architecture separates concerns cleanly.** System workloads on the system pool, general workloads on the user pool, cost-optimized workloads on the spot pool, and database workloads on a memory-optimized pool — each with its own autoscaling policy, VM SKU, and taints. This segmentation prevents one workload type from starving another.

---

## 11. Exercises & Labs

**Exercise 1: AKS Cluster with Terraform**
Using the Terraform configuration from Section 4, provision a development AKS cluster with one system node pool (2 nodes, `Standard_D2s_v5`) and one user node pool (1–5 nodes, `Standard_D4s_v5`). Verify: (a) all system Pods are in `Running` state, (b) the OIDC issuer URL is set (`az aks show --query oidcIssuerProfile`), (c) Cilium is running as the CNI (`kubectl get pods -n kube-system -l app.kubernetes.io/name=cilium`). Destroy the cluster afterward with `terraform destroy`.

**Exercise 2: Workload Identity End-to-End**
Create an Azure Key Vault with one secret (`db-password=testvalue123`). Create a User-Assigned Managed Identity with the `Key Vault Secrets User` role on that vault. Create a federated credential linking it to a Kubernetes ServiceAccount. Deploy a Pod using that ServiceAccount running `azure-cli` and verify it can retrieve the secret with `az keyvault secret show` — without any credentials in the Pod spec.

**Exercise 3: KEDA Service Bus Autoscaling**
Install KEDA on your cluster. Create an Azure Service Bus Standard namespace and a queue. Deploy a minimal worker Deployment with `replicas: 0`. Create a `ScaledObject` targeting 5 messages per replica. Send 25 messages to the queue and observe the Deployment scale to 5 replicas. Then stop sending messages and observe the scale-down cooldown. Document the exact timing of each scale event from `kubectl describe scaledobject`.

**Exercise 4: Azure DevOps Pipeline with AKS Deployment**
Create an Azure DevOps project and connect it to an AKS cluster via a service connection. Fork a sample Node.js application. Write a two-stage pipeline (Build + Deploy) that: (a) builds and pushes a Docker image to ACR, (b) runs `trivy image` and publishes the report as a pipeline artifact, (c) deploys to AKS using `helm upgrade --install --atomic`. Trigger the pipeline and trace the full execution from git push to running Pod.

**Exercise 5: Azure Monitor KQL Dashboard**
Enable Container Insights on your cluster. Generate synthetic load for 10 minutes using a load generator. Navigate to Log Analytics and write KQL queries to: (a) find the top 5 Pods by memory consumption, (b) identify any container that was OOM-killed in the last hour, (c) calculate the 95th percentile CPU utilization per namespace. Pin all three queries as tiles in an Azure Dashboard and share the dashboard link.

---

*End of Chapter 6*

**Next → Chapter 7: Google Kubernetes Engine (GKE)**