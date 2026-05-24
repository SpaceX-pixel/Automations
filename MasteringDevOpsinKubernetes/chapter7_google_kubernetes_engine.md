# Chapter 7 — Google Kubernetes Engine (GKE)

> *Mastering DevOps in Kubernetes*
> Standard vs Autopilot · Workload Identity · VPC-native · Dataplane V2 · Cloud Build · Cloud Operations

---

## 1. Introduction & Learning Objectives

Google Kubernetes Engine occupies a unique position in the managed Kubernetes landscape. Kubernetes was originally designed at Google, modelled directly on Borg — Google's internal container orchestration system that has run production workloads at planetary scale since 2003. GKE is not just a managed Kubernetes service that happens to run on Google Cloud. It is the platform built by the people who invented Kubernetes, running on the same global infrastructure that Google uses for Search, YouTube, and Gmail.

That heritage shows in the product. GKE introduced several features — the Cluster Autoscaler, node auto-provisioning, Binary Authorization, Workload Identity, and Autopilot — that later influenced or were adopted by the broader Kubernetes ecosystem. It runs on Google's custom networking stack (Andromeda), its custom silicon (TPUs for ML workloads), and integrates with a set of developer tools — Cloud Build, Artifact Registry, and Cloud Operations Suite — that together form a complete software delivery platform.

This chapter builds a production-grade GKE environment from first principles. We cover both GKE Standard (where you manage node pools) and GKE Autopilot (where Google manages the entire data plane). We explore VPC-native networking, Dataplane V2 (GKE's eBPF-powered network stack built on Cilium), Workload Identity federation for secure access to Google Cloud APIs, Cloud Armor for DDoS and WAF protection, and full integration with Cloud Build, Artifact Registry, and Cloud Operations Suite for end-to-end observability.

> **Learning Objectives**
> - Distinguish GKE Standard and Autopilot modes and select the right one for a given workload profile.
> - Provision VPC-native GKE clusters using `gcloud` CLI and Terraform.
> - Understand GKE Dataplane V2 (eBPF via Cilium) and its advantages over the iptables dataplane.
> - Configure Workload Identity to grant Pods access to Google Cloud APIs without service account key files.
> - Integrate Cloud Armor with GKE Ingress for DDoS protection and WAF policies.
> - Implement GKE Autopilot for serverless Kubernetes with cost-optimized bin-packing.
> - Build CI/CD pipelines using Cloud Build with Artifact Registry and automated GKE deployments.
> - Enable Cloud Operations Suite for unified metrics, logs, and traces across GKE workloads.
> - Apply GKE-specific cost optimization strategies: Spot VMs, node auto-provisioning, and Autopilot.

---

## 2. Core Concepts

### 2.1 GKE Architecture and the Two Modes

GKE organizes its offering into two fundamentally different operating models. Understanding the distinction is the first and most important decision you make when adopting GKE.

```
┌───────────────────────────────────────────────────────────────────────────┐
│  GKE Standard                       GKE Autopilot                         │
│  ─────────────────────────────────────────────────────────────────────    │
│                                                                           │
│  You manage:                        Google manages:                       │
│  ├── Node pools                     ├── Node pools (fully managed)        │
│  ├── Node sizes and counts          ├── Node sizes (auto-selected)        │
│  ├── Node OS and image              ├── Node OS (Container-Optimized OS)  │
│  ├── Cluster autoscaling            ├── Autoscaling (always on)           │
│  └── System component tuning        └── All system components             │
│                                                                           │
│  Billing: per node (VM hours)       Billing: per Pod (vCPU + memory)      │
│  Idle nodes: you pay                Idle Pods: you pay (minimal)          │
│  Node access: SSH possible          Node access: not permitted            │
│  DaemonSets: supported              DaemonSets: not supported             │
│  Host networking: supported         Host networking: not supported        │
│  Privileged Pods: supported         Privileged Pods: not supported        │
│                                                                           │
│  Best for:                          Best for:                             │
│  ├── Custom node configurations     ├── Teams wanting zero node mgmt      │
│  ├── GPU and TPU workloads          ├── Variable, spiky workloads         │
│  ├── Stateful workloads             ├── Startups and small platform teams │
│  └── DaemonSet-based tooling        └── Cost optimization at variable load│
└───────────────────────────────────────────────────────────────────────────┘
```

#### GKE Standard Architecture

```
┌───────────────────────────────────────────────────────────────────────────┐
│  Google-Managed Control Plane (free for 1 zonal cluster; $0.10/hr rest)   │
│                                                                           │
│  kube-apiserver · etcd · Scheduler · Controller Manager                   │
│  (Multi-zone for regional clusters; single-zone for zonal)                │
└───────────────────────────────┬───────────────────────────────────────────┘
                                │
┌───────────────────────────────▼───────────────────────────────────────────┐
│  Your GCP Project — VPC-native network                                    │
│                                                                           │
│  us-east1-b            us-east1-c            us-east1-d                   │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐            │
│  │  Node Pool:     │  │  Node Pool:     │  │  Node Pool:     │            │
│  │  n2-standard-4  │  │  n2-standard-4  │  │  n2-standard-4  │            │
│  │  Pods: /24 alias│  │  Pods: /24 alias│  │  Pods: /24 alias│            │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘            │
│                                                                           │
│  Cloud Load Balancing · Cloud Armor · Artifact Registry                   │
│  Cloud Operations · Cloud Build · Workload Identity                       │
└───────────────────────────────────────────────────────────────────────────┘
```

#### GKE vs. EKS vs. AKS at a Glance

| Feature | GKE | EKS | AKS |
|---|---|---|---|
| Control plane cost | Free (1 zonal) / $0.10/hr | $0.10/hr always | Free always |
| Autopilot / Serverless mode | GKE Autopilot | AWS Fargate (partial) | Virtual Nodes (partial) |
| Default network plugin | VPC-native (Alias IPs) | VPC CNI | Azure CNI / Overlay |
| eBPF dataplane | Dataplane V2 (Cilium-based) | Self-managed Cilium | Azure CNI + Cilium |
| Workload identity | Workload Identity (OIDC) | IRSA (OIDC + STS) | Workload Identity (AAD) |
| Node auto-provisioning | Yes (NAP) | No (manual node groups) | No (manual node pools) |
| Binary Authorization | Yes (native) | Via 3rd-party | Via Azure Policy |
| Kubernetes origin | Built by Kubernetes creators | AWS-managed | Microsoft-managed |

---

### 2.2 VPC-Native Clusters and Alias IPs

GKE's VPC-native clusters assign Pod IPs from a secondary IP range attached to the node subnet — called **Alias IP ranges**. Like EKS VPC CNI and AKS Azure CNI, Pods get real VPC IPs. Unlike both, GKE does this via secondary IP ranges rather than ENIs, which avoids the per-ENI attachment limit that constrains Pod density on AWS.

```
VPC: 10.0.0.0/8
  Node subnet: 10.0.0.0/20       (primary range — node IPs)
    Secondary range: 10.4.0.0/14 (Pod CIDR — all Pods in the cluster)
    Secondary range: 10.8.0.0/20 (Services CIDR)

Node: 10.0.0.5  (node IP from primary range)
  Pod A: 10.4.0.2   ← real VPC IP from secondary range
  Pod B: 10.4.0.3   ← real VPC IP from secondary range
  Pod C: 10.4.0.4   ← real VPC IP from secondary range

Each node gets a /24 alias block (256 IPs) from the Pod CIDR.
Max Pods per node: 110 (GKE default cap, configurable to 256 with DPv2)
```

#### Benefits of VPC-Native over Routes-Based Clusters

```
Routes-based (legacy):
  Each node installs VPC routes for its Pod CIDR
  GCP limits: 250 routes per VPC → max ~250 nodes per cluster
  Pod IPs: not directly reachable without the route

VPC-native (Alias IPs):
  No custom routes needed — Pod IPs are aliases on the node NIC
  No 250-node limit from routing constraints
  Pod IPs directly reachable from any VPC-connected resource
  Required for: Dataplane V2, Cloud Armor, VPC firewall rules on Pods
```

#### Subnet Sizing for GKE

```
Recommended secondary range sizes:

Pods:     /14 = 262,144 IPs → supports ~1,000 nodes (each gets /24 = 256 pod IPs)
Services: /20 = 4,096 service IPs → supports up to 4,096 ClusterIP services

For large clusters:
Pods:     /12 = 1,048,576 IPs → supports ~4,000 nodes

Note: GKE secondary ranges are immutable after cluster creation.
Undersize them and you must recreate the cluster.
Always provision larger than you think you need.
```

---

### 2.3 GKE Dataplane V2 — eBPF-Powered Networking

**GKE Dataplane V2** (DPv2) replaces the traditional iptables dataplane with an eBPF-based implementation built on Cilium. It is enabled by default on new GKE clusters running Kubernetes 1.28+.

```
Traditional GKE dataplane (kube-proxy + iptables):
  Service request → iptables DNAT → Pod
  iptables rules: O(n) with number of services — degrades at scale
  Network Policy: evaluated by iptables (limited visibility)
  Observability: none at the packet level

GKE Dataplane V2 (eBPF, no kube-proxy):
  Service request → eBPF socket map → Pod (single syscall)
  eBPF programs: O(1) regardless of service count
  Network Policy: enforced in kernel with full L4 visibility
  Observability: GKE Network Policy Logging, Hubble-compatible flow data
```

#### DPv2 Features

| Feature | iptables | Dataplane V2 (eBPF) |
|---|---|---|
| kube-proxy required | Yes | No — replaced by eBPF |
| Service routing performance | O(n) rules | O(1) hash map |
| Network Policy enforcement | iptables rules | eBPF programs in kernel |
| Network Policy logging | No | Yes (GKE Policy Logging) |
| Maximum services | ~10,000 (degrades) | 100,000+ |
| FQDN-based network policy | No | Yes (with Cilium) |
| Bandwidth management | Limited | Yes (eBPF TC) |
| Multi-cluster networking | Manual | Yes (GKE Fleet) |

```bash
# Verify Dataplane V2 is enabled on your cluster
kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.kubeProxyVersion}'
# v0.0.0-master+$Format:%h$   ← kube-proxy absent; DPv2 active

# Check DPv2 Pods (anetd = Anthos Networking Daemon, GKE's Cilium fork)
kubectl get pods -n kube-system -l k8s-app=cilium
# NAME           READY   STATUS    RESTARTS   AGE
# cilium-4xk9p   1/1     Running   0          2d
# cilium-8vr2q   1/1     Running   0          2d
# cilium-m9t7n   1/1     Running   0          2d

# Network Policy with logging (DPv2 exclusive feature)
# Each NetworkPolicy rule can log allowed/denied connections to Cloud Logging
```

```yaml
# NetworkPolicy with DPv2 logging enabled
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: order-api-netpol
  namespace: production
  annotations:
    # GKE DPv2: log all connections that hit this policy
    networking.gke.io/network-policy-logging: "true"
spec:
  podSelector:
    matchLabels:
      app: order-api
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: production
          podSelector:
            matchLabels:
              role: api-gateway
      ports:
        - protocol: TCP
          port: 8080
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: databases
      ports:
        - protocol: TCP
          port: 5432
    - to:   # Allow DNS
        - namespaceSelector: {}
      ports:
        - protocol: UDP
          port: 53
```

---

### 2.4 Workload Identity — GKE's Credential-Free IAM

**Workload Identity** is GKE's mechanism for granting Pods access to Google Cloud APIs (Cloud Storage, Pub/Sub, Cloud SQL, Secret Manager, etc.) without service account key files. It is the Google equivalent of EKS IRSA and AKS Workload Identity.

```
┌──────────────────────────────────────────────────────────────────┐
│  Pod                                                             │
│  serviceAccountName: order-api-ksa                               │
│                                                                  │
│  GKE Metadata Server (runs on node, intercepts metadata calls):  │
│  http://169.254.169.254/computeMetadata/v1/...                   │
│  Returns short-lived token for the bound Google SA               │
└───────────────────────────────┬──────────────────────────────────┘
                                │ Token exchange (OIDC)
                                ▼
┌──────────────────────────────────────────────────────────────────┐
│  Google STS (Security Token Service)                             │
│  Validates: KSA token signed by GKE's OIDC provider              │
│  Checks:    KSA → GSA binding (iam.workloadIdentityUser role)    │
└───────────────────────────────┬──────────────────────────────────┘
                                │ Impersonation granted
                                ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│  Google Service Account (GSA): order-api@my-project.iam.gserviceaccount.com  |
│  IAM roles:                                                                  │
│    roles/storage.objectViewer → gs://order-assets                            │
│    roles/pubsub.publisher → projects/my-project/topics/orders                │
│    roles/cloudsql.client → my-project:us-east1:orders-db                     │
└──────────────────────────────────────────────────────────────────────────────┘
```

```bash
# Step 1: Enable Workload Identity on the cluster (or at creation time)
gcloud container clusters update my-cluster \
  --workload-pool=my-project.svc.id.goog \
  --region=us-east1

# Step 2: Create a Google Service Account (GSA)
gcloud iam service-accounts create order-api-gsa \
  --display-name="Order API GKE Workload Identity" \
  --project=my-project

# Step 3: Grant the GSA permissions to GCP resources
gcloud projects add-iam-policy-binding my-project \
  --member="serviceAccount:order-api-gsa@my-project.iam.gserviceaccount.com" \
  --role="roles/storage.objectViewer"

gcloud projects add-iam-policy-binding my-project \
  --member="serviceAccount:order-api-gsa@my-project.iam.gserviceaccount.com" \
  --role="roles/pubsub.publisher"

# Step 4: Allow the Kubernetes SA to impersonate the GSA
gcloud iam service-accounts add-iam-policy-binding \
  order-api-gsa@my-project.iam.gserviceaccount.com \
  --role=roles/iam.workloadIdentityUser \
  --member="serviceAccount:my-project.svc.id.goog[production/order-api-ksa]"
```

```yaml
# Step 5: Create the Kubernetes SA with the GSA annotation
apiVersion: v1
kind: ServiceAccount
metadata:
  name: order-api-ksa
  namespace: production
  annotations:
    iam.gke.io/gcp-service-account: order-api-gsa@my-project.iam.gserviceaccount.com

---
# Step 6: Reference in the Pod spec
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-api
  namespace: production
spec:
  template:
    spec:
      serviceAccountName: order-api-ksa   # GKE injects the token automatically
      containers:
        - name: api
          image: us-east1-docker.pkg.dev/my-project/my-repo/order-api:v1.4.2
          # Google Cloud SDKs pick up credentials automatically via ADC
          # No GOOGLE_APPLICATION_CREDENTIALS, no key files, no secrets
```

---

### 2.5 Cloud Armor — DDoS Protection and WAF

**Cloud Armor** is Google Cloud's DDoS mitigation and Web Application Firewall service. When integrated with GKE, Cloud Armor policies attach to GKE Ingress (backed by a Global External Application Load Balancer), providing:

- **Adaptive Protection:** ML-based volumetric DDoS detection and automatic rule suggestions
- **WAF rules:** Pre-configured OWASP Top 10 protection (SQLi, XSS, LFI, RFI, RCE)
- **IP allowlists and denylists:** Block known malicious ranges or restrict access to corporate IPs
- **Rate limiting:** Per-client request rate enforcement at the load balancer edge
- **Geo-based blocking:** Restrict traffic by country

```
Internet
    │
    ▼
Cloud Armor Security Policy
  ├── Rule 1: Block IP 198.51.100.0/24 (known attacker)
  ├── Rule 2: Rate limit to 1000 RPS per client IP
  ├── Rule 3: WAF — OWASP SQLi (preconfigured rule set)
  ├── Rule 4: WAF — OWASP XSS (preconfigured rule set)
  ├── Rule 5: Allow US + EU only (geo-based)
  └── Default: Allow (or Deny all for allowlist model)
    │
    ▼
Global External Application Load Balancer
  (provisioned by GKE Ingress + BackendConfig)
    │
    ▼
GKE Pod IPs (VPC-native routing — no NodePort hop)
```

```yaml
# BackendConfig — attaches Cloud Armor policy to a GKE Service
apiVersion: cloud.google.com/v1
kind: BackendConfig
metadata:
  name: order-api-backend-config
  namespace: production
spec:
  # Cloud Armor security policy
  securityPolicy:
    name: production-waf-policy       # Name of the Cloud Armor policy

  # Connection draining (graceful backend removal)
  connectionDraining:
    drainingTimeoutSec: 60

  # Health check configuration
  healthCheck:
    checkIntervalSec: 15
    timeoutSec: 5
    healthyThreshold: 1
    unhealthyThreshold: 2
    type: HTTP
    requestPath: /health/ready
    port: 8080

  # Session affinity (for stateful HTTP sessions)
  sessionAffinity:
    affinityType: GENERATED_COOKIE
    affinityCookieTtlSec: 3600

  # Custom response headers
  customResponseHeaders:
    headers:
      - name: X-Frame-Options
        value: DENY
      - name: Strict-Transport-Security
        value: "max-age=31536000; includeSubDomains"

---
# Service — references the BackendConfig
apiVersion: v1
kind: Service
metadata:
  name: order-api-svc
  namespace: production
  annotations:
    cloud.google.com/backend-config: '{"default":"order-api-backend-config"}'
    cloud.google.com/neg: '{"ingress":true}'  # Network Endpoint Group (required for ip-target)
spec:
  selector:
    app: order-api
  ports:
    - port: 80
      targetPort: 8080
  type: ClusterIP

---
# Ingress — provisions Global HTTPS Load Balancer with Cloud Armor
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: order-api-ingress
  namespace: production
  annotations:
    kubernetes.io/ingress.class: "gce"
    kubernetes.io/ingress.global-static-ip-name: "order-api-global-ip"
    networking.gke.io/managed-certificates: "order-api-managed-cert"
    kubernetes.io/ingress.allow-http: "false"    # Force HTTPS only
spec:
  rules:
    - host: api.mycompany.com
      http:
        paths:
          - path: /*
            pathType: ImplementationSpecific
            backend:
              service:
                name: order-api-svc
                port:
                  number: 80
```

```bash
# Create the Cloud Armor security policy
gcloud compute security-policies create production-waf-policy \
  --description="Production WAF policy" \
  --project=my-project

# Add OWASP SQLi protection (pre-configured rule)
gcloud compute security-policies rules create 1000 \
  --security-policy=production-waf-policy \
  --expression="evaluatePreconfiguredExpr('sqli-v33-stable')" \
  --action=deny-403 \
  --description="Block SQL injection"

# Add OWASP XSS protection
gcloud compute security-policies rules create 1001 \
  --security-policy=production-waf-policy \
  --expression="evaluatePreconfiguredExpr('xss-v33-stable')" \
  --action=deny-403 \
  --description="Block XSS"

# Rate limiting: 1000 requests/min per IP, then throttle
gcloud compute security-policies rules create 2000 \
  --security-policy=production-waf-policy \
  --expression="true" \
  --action=rate-based-ban \
  --rate-limit-threshold-count=1000 \
  --rate-limit-threshold-interval-sec=60 \
  --ban-duration-sec=600 \
  --conform-action=allow \
  --exceed-action=deny-429 \
  --enforce-on-key=IP \
  --description="Rate limit per client IP"

# Enable Adaptive Protection (ML-based DDoS detection)
gcloud compute security-policies update production-waf-policy \
  --enable-layer7-ddos-defense \
  --project=my-project
```

---

### 2.6 GKE Autopilot — Serverless Kubernetes

GKE Autopilot is a managed mode where Google provisions, scales, and manages all node infrastructure. You only interact with Kubernetes objects — no nodes, no node pools, no VMs.

#### How Autopilot Works

```
You apply:          Kubernetes manifests (Deployments, StatefulSets, Jobs)

GKE Autopilot:
  ├── Selects the right node size for each Pod (based on requests)
  ├── Provisions nodes on demand (scale from 0)
  ├── Bins-packs Pods efficiently (higher utilization than manual node groups)
  ├── Patches node OS automatically (COS, always up to date)
  ├── Enforces security baseline (no privileged containers, read-only rootfs encouraged)
  └── Bills per Pod (not per node) — you pay for what your Pods consume

You never:
  ├── SSH into nodes
  ├── Choose VM SKUs
  ├── Configure autoscaling
  └── Patch node OS
```

#### Autopilot Billing Model

```
Autopilot billing = sum of all Pod resource requests × per-unit price

Example Pod:
  requests.cpu: 500m
  requests.memory: 512Mi
  running for: 1 hour

Cost = (0.5 vCPU × $0.0595/vCPU-hour) + (0.5 GiB × $0.0065/GiB-hour)
     = $0.02975 + $0.00325 = $0.033/hour per Pod

Contrast with Standard:
  n2-standard-4 node: $0.19/hour regardless of Pod utilization
  If utilization is 30%: effective cost = $0.19/0.3 = $0.63/hour of actual work
  Autopilot efficiency: up to 65% cost reduction for spiky workloads
```

#### Autopilot Compute Classes

```yaml
# Default compute class (general-purpose, balanced price/performance)
spec:
  nodeSelector:
    cloud.google.com/compute-class: general-purpose

# Balanced compute class (newest Tau T2D VMs, best price/performance)
spec:
  nodeSelector:
    cloud.google.com/compute-class: balanced

# Scale-Out compute class (high Pod density, lower per-Pod cost)
spec:
  nodeSelector:
    cloud.google.com/compute-class: scale-out

# Performance compute class (C3 VMs, highest single-thread performance)
spec:
  nodeSelector:
    cloud.google.com/compute-class: performance

# Accelerator class (GPUs — T4, L4, A100)
spec:
  nodeSelector:
    cloud.google.com/compute-class: accelerator
  resources:
    limits:
      nvidia.com/gpu: "1"
```

#### Autopilot Resource Limits

```yaml
# Autopilot enforces minimum resource requests
# Pods below the minimum are automatically bumped up:
# min CPU request: 250m   min memory request: 512Mi

# Autopilot also enforces maximums per Pod:
# max CPU request: 96 vCPU   max memory request: 624 GiB (on large compute classes)

# Correct Autopilot Pod spec (always set requests = limits for predictable billing)
spec:
  containers:
    - name: api
      resources:
        requests:
          cpu: "1"
          memory: "1Gi"
        limits:
          cpu: "1"         # Autopilot recommends requests == limits
          memory: "1Gi"    # Burstable Pods may be evicted during bin-packing
```

---

### 2.7 Node Auto-Provisioning (NAP)

Node Auto-Provisioning automatically creates and deletes node pools based on pending Pod requirements. Rather than the Cluster Autoscaler adding nodes to an existing pool, NAP creates entirely new node pools with the right machine type for the pending Pod's resource requests.

```
Standard Cluster Autoscaler:
  Pending Pod (needs 8 vCPU) → adds node to existing n2-standard-4 pool
  BUT: n2-standard-4 has 4 vCPUs; can never fit an 8-vCPU Pod
  Result: Pod stays Pending forever

Node Auto-Provisioning:
  Pending Pod (needs 8 vCPU) → NAP creates a new n2-standard-8 node pool
  Nodes auto-provisioned with the exact right size
  When all Pods on that pool finish: pool is automatically deleted
```

```yaml
# NAP is configured at cluster level in Terraform
resource "google_container_cluster" "main" {
  # ...
  cluster_autoscaling {
    enabled = true                      # Enable NAP
    autoscaling_profile = "OPTIMIZE_UTILIZATION"  # More aggressive bin-packing

    resource_limits {
      resource_type = "cpu"
      minimum       = 4
      maximum       = 500              # Max vCPUs across all auto-provisioned nodes
    }

    resource_limits {
      resource_type = "memory"
      minimum       = 8
      maximum       = 2000             # Max GiB across all auto-provisioned nodes
    }

    auto_provisioning_defaults {
      service_account = google_service_account.gke_node_sa.email
      oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

      management {
        auto_repair  = true
        auto_upgrade = true
      }

      upgrade_settings {
        max_surge       = 1
        max_unavailable = 0
      }

      disk_size = 100
      disk_type = "pd-ssd"
      image_type = "COS_CONTAINERD"
      shielded_instance_config {
        enable_secure_boot          = true
        enable_integrity_monitoring = true
      }
    }
  }
}
```

---

## 3. Cluster Provisioning with gcloud CLI

### 3.1 Prerequisites

```bash
# Install Google Cloud SDK
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
gcloud init

# Authenticate
gcloud auth login
gcloud auth application-default login

# Set project and region
PROJECT_ID="my-gke-project"
REGION="us-east1"
CLUSTER="gke-production"

gcloud config set project $PROJECT_ID
gcloud config set compute/region $REGION

# Enable required APIs
gcloud services enable \
  container.googleapis.com \
  compute.googleapis.com \
  artifactregistry.googleapis.com \
  cloudbuild.googleapis.com \
  cloudkms.googleapis.com \
  secretmanager.googleapis.com \
  monitoring.googleapis.com \
  logging.googleapis.com \
  cloudtrace.googleapis.com

# Install gke-gcloud-auth-plugin (required for kubectl auth)
gcloud components install gke-gcloud-auth-plugin
```

### 3.2 VPC and Subnet Setup

```bash
# Create dedicated VPC
gcloud compute networks create gke-vpc \
  --subnet-mode=custom \
  --bgp-routing-mode=regional \
  --project=$PROJECT_ID

# Create subnet with secondary ranges for Pods and Services
gcloud compute networks subnets create gke-nodes-subnet \
  --network=gke-vpc \
  --region=$REGION \
  --range=10.0.0.0/20 \
  --secondary-range pods=10.4.0.0/14,services=10.8.0.0/20 \
  --enable-private-ip-google-access \
  --project=$PROJECT_ID

# Reserve a global static IP for the Ingress
gcloud compute addresses create order-api-global-ip \
  --global \
  --project=$PROJECT_ID

# Create a Cloud Router and NAT for private nodes
gcloud compute routers create gke-router \
  --network=gke-vpc \
  --region=$REGION \
  --project=$PROJECT_ID

gcloud compute routers nats create gke-nat \
  --router=gke-router \
  --region=$REGION \
  --auto-allocate-nat-external-ips \
  --nat-all-subnet-ip-ranges \
  --project=$PROJECT_ID
```

### 3.3 Create GKE Standard Cluster

```bash
gcloud container clusters create $CLUSTER \
  --project=$PROJECT_ID \
  --region=$REGION \
  \
  `# Kubernetes version` \
  --release-channel=regular \
  \
  `# Node pool (system + default)` \
  --machine-type=n2-standard-4 \
  --num-nodes=1 \
  --min-nodes=1 \
  --max-nodes=5 \
  --enable-autoscaling \
  \
  `# Networking` \
  --network=gke-vpc \
  --subnetwork=gke-nodes-subnet \
  --cluster-secondary-range-name=pods \
  --services-secondary-range-name=services \
  --enable-ip-alias \
  --enable-private-nodes \
  --master-ipv4-cidr=172.16.0.0/28 \
  \
  `# Dataplane V2 (eBPF)` \
  --enable-dataplane-v2 \
  --enable-network-policy \
  \
  `# Workload Identity` \
  --workload-pool=${PROJECT_ID}.svc.id.goog \
  \
  `# Security` \
  --enable-shielded-nodes \
  --shielded-secure-boot \
  --shielded-integrity-monitoring \
  --enable-workload-vulnerability-scanning \
  \
  `# Node OS` \
  --image-type=COS_CONTAINERD \
  --disk-type=pd-ssd \
  --disk-size=100 \
  \
  `# Logging and monitoring` \
  --enable-managed-prometheus \
  --logging=SYSTEM,WORKLOAD \
  --monitoring=SYSTEM,WORKLOAD,API_SERVER,SCHEDULER,CONTROLLER_MANAGER \
  \
  `# Auto-upgrade` \
  --enable-autorepair \
  --enable-autoupgrade \
  \
  `# Tags` \
  --labels=env=production,team=platform,managed-by=gcloud

# Get credentials
gcloud container clusters get-credentials $CLUSTER \
  --region=$REGION \
  --project=$PROJECT_ID

kubectl get nodes -o wide
```

### 3.4 Add Specialized Node Pools

```bash
# High-memory pool for databases and caches
gcloud container node-pools create memory-pool \
  --cluster=$CLUSTER \
  --region=$REGION \
  --machine-type=n2-highmem-8 \
  --num-nodes=0 \
  --min-nodes=0 \
  --max-nodes=10 \
  --enable-autoscaling \
  --node-labels=role=memory,node-type=ondemand \
  --node-taints=workload=memory-intensive:NoSchedule \
  --disk-type=pd-ssd \
  --disk-size=200 \
  --image-type=COS_CONTAINERD \
  --enable-autorepair \
  --enable-autoupgrade

# Spot VM pool (up to 91% cheaper, preemptible)
gcloud container node-pools create spot-pool \
  --cluster=$CLUSTER \
  --region=$REGION \
  --machine-type=n2-standard-4 \
  --num-nodes=0 \
  --min-nodes=0 \
  --max-nodes=30 \
  --enable-autoscaling \
  --spot \
  --node-labels=role=spot,node-type=spot \
  --node-taints=cloud.google.com/gke-spot=true:NoSchedule \
  --disk-type=pd-balanced \
  --disk-size=100 \
  --image-type=COS_CONTAINERD

# GPU pool for ML workloads
gcloud container node-pools create gpu-pool \
  --cluster=$CLUSTER \
  --region=$REGION \
  --machine-type=n1-standard-8 \
  --accelerator=type=nvidia-l4,count=1,gpu-driver-version=default \
  --num-nodes=0 \
  --min-nodes=0 \
  --max-nodes=5 \
  --enable-autoscaling \
  --node-labels=role=gpu,hardware=gpu \
  --node-taints=nvidia.com/gpu=present:NoSchedule \
  --disk-type=pd-ssd \
  --disk-size=200
```

---

## 4. Cluster Provisioning with Terraform

### 4.1 Backend and Providers

```hcl
# backend.tf
terraform {
  required_version = ">= 1.7"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.30"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.30"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31"
    }
  }

  backend "gcs" {
    bucket = "my-terraform-state-bucket"
    prefix = "gke/production"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}
```

### 4.2 VPC and Supporting Resources

```hcl
locals {
  cluster_name = "gke-production"
  region       = "us-east1"
  project_id   = var.project_id

  tags = {
    env        = "production"
    managed-by = "terraform"
    project    = "gke-platform"
  }
}

# ── VPC ──────────────────────────────────────────────────────────
resource "google_compute_network" "main" {
  name                    = "gke-vpc"
  auto_create_subnetworks = false
  project                 = local.project_id
}

resource "google_compute_subnetwork" "nodes" {
  name          = "gke-nodes-subnet"
  network       = google_compute_network.main.id
  region        = local.region
  ip_cidr_range = "10.0.0.0/20"

  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.4.0.0/14"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.8.0.0/20"
  }
}

# Cloud Router + NAT for private nodes
resource "google_compute_router" "main" {
  name    = "gke-router"
  network = google_compute_network.main.id
  region  = local.region
}

resource "google_compute_router_nat" "main" {
  name                               = "gke-nat"
  router                             = google_compute_router.main.name
  region                             = local.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# ── Artifact Registry ─────────────────────────────────────────────
resource "google_artifact_registry_repository" "main" {
  repository_id = "production-images"
  location      = local.region
  format        = "DOCKER"
  description   = "Production container images"
  project       = local.project_id

  cleanup_policies {
    id     = "keep-minimum-versions"
    action = "KEEP"
    most_recent_versions {
      keep_count = 10
    }
  }
}

# ── Node Service Account (least privilege) ────────────────────────
resource "google_service_account" "gke_node_sa" {
  account_id   = "gke-node-sa"
  display_name = "GKE Node Service Account"
  project      = local.project_id
}

resource "google_project_iam_member" "node_sa_log_writer" {
  project = local.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_node_sa.email}"
}

resource "google_project_iam_member" "node_sa_metric_writer" {
  project = local.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_node_sa.email}"
}

resource "google_project_iam_member" "node_sa_ar_reader" {
  project = local.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.gke_node_sa.email}"
}
```

### 4.3 GKE Cluster Resource

```hcl
# ── GKE Cluster ───────────────────────────────────────────────────
resource "google_container_cluster" "main" {
  provider = google-beta               # Some features require beta provider

  name     = local.cluster_name
  project  = local.project_id
  location = local.region              # Regional cluster: nodes in all zones

  # Remove default node pool; we manage node pools separately
  remove_default_node_pool = true
  initial_node_count       = 1

  # ── Networking ────────────────────────────────────────────────
  network    = google_compute_network.main.name
  subnetwork = google_compute_subnetwork.nodes.name

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false      # Public endpoint with authorized networks
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "203.0.113.0/24"   # Corporate IP
      display_name = "Corporate VPN"
    }
  }

  # ── Dataplane V2 ──────────────────────────────────────────────
  datapath_provider = "ADVANCED_DATAPATH"   # Dataplane V2

  network_policy {
    enabled  = true
    provider = "CALICO"    # Note: set to CALICO even when using DPv2
  }

  # ── Workload Identity ─────────────────────────────────────────
  workload_identity_config {
    workload_pool = "${local.project_id}.svc.id.goog"
  }

  # ── Release channel ───────────────────────────────────────────
  release_channel {
    channel = "REGULAR"   # Regular: tested, stable updates ~monthly
  }

  # ── Logging and monitoring ────────────────────────────────────
  logging_config {
    enable_components = [
      "SYSTEM_COMPONENTS",
      "WORKLOADS",
      "API_SERVER",
      "SCHEDULER",
      "CONTROLLER_MANAGER",
    ]
  }

  monitoring_config {
    enable_components = [
      "SYSTEM_COMPONENTS",
      "APISERVER",
      "SCHEDULER",
      "CONTROLLER_MANAGER",
      "STORAGE",
      "POD",
      "DAEMONSET",
      "DEPLOYMENT",
      "STATEFULSET",
    ]
    managed_prometheus {
      enabled = true
    }
  }

  # ── Security ──────────────────────────────────────────────────
  enable_shielded_nodes = true

  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  workload_vulnerability_mode = "WORKLOAD_VULNERABILITY_SCANNING"

  # ── Node Auto-Provisioning ────────────────────────────────────
  cluster_autoscaling {
    enabled             = true
    autoscaling_profile = "OPTIMIZE_UTILIZATION"

    resource_limits {
      resource_type = "cpu"
      minimum       = 4
      maximum       = 500
    }
    resource_limits {
      resource_type = "memory"
      minimum       = 8
      maximum       = 2000
    }

    auto_provisioning_defaults {
      service_account = google_service_account.gke_node_sa.email
      oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

      management {
        auto_repair  = true
        auto_upgrade = true
      }

      shielded_instance_config {
        enable_secure_boot          = true
        enable_integrity_monitoring = true
      }
    }
  }

  resource_labels = local.tags

  lifecycle {
    ignore_changes = [
      initial_node_count,
    ]
  }
}

# ── System Node Pool ──────────────────────────────────────────────
resource "google_container_node_pool" "system" {
  name     = "system-pool"
  cluster  = google_container_cluster.main.name
  project  = local.project_id
  location = local.region

  initial_node_count = 1

  autoscaling {
    min_node_count = 1
    max_node_count = 5
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }

  node_config {
    machine_type    = "n2-standard-4"
    disk_type       = "pd-ssd"
    disk_size_gb    = 100
    image_type      = "COS_CONTAINERD"
    service_account = google_service_account.gke_node_sa.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    workload_metadata_config {
      mode = "GKE_METADATA"          # Required for Workload Identity
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    taint {
      key    = "CriticalAddonsOnly"  # Matches system Pod tolerations
      value  = "true"
      effect = "NO_SCHEDULE"
    }

    labels = {
      role      = "system"
      node-type = "ondemand"
    }
  }
}

# ── General User Node Pool ────────────────────────────────────────
resource "google_container_node_pool" "general" {
  name     = "general-pool"
  cluster  = google_container_cluster.main.name
  project  = local.project_id
  location = local.region

  initial_node_count = 3

  autoscaling {
    min_node_count = 3
    max_node_count = 30
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge       = 2
    max_unavailable = 0
  }

  node_config {
    machine_type    = "n2-standard-8"
    disk_type       = "pd-ssd"
    disk_size_gb    = 100
    image_type      = "COS_CONTAINERD"
    service_account = google_service_account.gke_node_sa.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    labels = {
      role      = "general"
      node-type = "ondemand"
    }
  }
}

# ── Spot VM Node Pool ─────────────────────────────────────────────
resource "google_container_node_pool" "spot" {
  name     = "spot-pool"
  cluster  = google_container_cluster.main.name
  project  = local.project_id
  location = local.region

  initial_node_count = 0

  autoscaling {
    min_node_count = 0
    max_node_count = 30
  }

  node_config {
    machine_type    = "n2-standard-4"
    disk_type       = "pd-balanced"
    disk_size_gb    = 100
    image_type      = "COS_CONTAINERD"
    service_account = google_service_account.gke_node_sa.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    spot            = true              # Spot VMs — up to 91% cheaper

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    taint {
      key    = "cloud.google.com/gke-spot"
      value  = "true"
      effect = "NO_SCHEDULE"
    }

    labels = {
      role      = "spot"
      node-type = "spot"
    }
  }
}
```

---

## 5. Cloud Build and Artifact Registry

### 5.1 Cloud Build Pipeline

Cloud Build is Google Cloud's fully managed CI/CD platform. Builds run in Docker containers, defined in a `cloudbuild.yaml` file. Each step runs in sequence (or in parallel with `waitFor`).

```yaml
# cloudbuild.yaml — Full CI/CD pipeline for GKE
substitutions:
  _REGION: us-east1
  _PROJECT_ID: my-gke-project
  _REPO: production-images
  _IMAGE: order-api
  _CLUSTER: gke-production
  _NAMESPACE: production
  _HELM_CHART: helm/order-api

steps:
  # ── Step 1: Run unit tests ──────────────────────────────────────
  - id: unit-tests
    name: node:20-alpine
    entrypoint: sh
    args:
      - -c
      - |
        npm ci
        npm run lint
        npm run test -- --coverage --reporters=default --reporters=jest-junit
    env:
      - NODE_ENV=test

  # ── Step 2: Build the container image ──────────────────────────
  - id: docker-build
    name: gcr.io/cloud-builders/docker
    waitFor: [unit-tests]
    args:
      - build
      - --file=Dockerfile
      - --tag=$_REGION-docker.pkg.dev/$_PROJECT_ID/$_REPO/$_IMAGE:$SHORT_SHA
      - --tag=$_REGION-docker.pkg.dev/$_PROJECT_ID/$_REPO/$_IMAGE:latest
      - --cache-from=$_REGION-docker.pkg.dev/$_PROJECT_ID/$_REPO/$_IMAGE:latest
      - --build-arg=GIT_SHA=$SHORT_SHA
      - --build-arg=BUILD_DATE=$_BUILD_DATE
      - .

  # ── Step 3: Scan for vulnerabilities ───────────────────────────
  - id: trivy-scan
    name: aquasec/trivy:latest
    waitFor: [docker-build]
    args:
      - image
      - --exit-code=1
      - --severity=CRITICAL
      - --ignore-unfixed
      - --format=sarif
      - --output=/workspace/trivy-results.sarif
      - $_REGION-docker.pkg.dev/$_PROJECT_ID/$_REPO/$_IMAGE:$SHORT_SHA

  # ── Step 4: Push to Artifact Registry ──────────────────────────
  - id: docker-push
    name: gcr.io/cloud-builders/docker
    waitFor: [trivy-scan]
    args:
      - push
      - --all-tags
      - $_REGION-docker.pkg.dev/$_PROJECT_ID/$_REPO/$_IMAGE

  # ── Step 5: Sign the image (Binary Authorization) ───────────────
  - id: sign-image
    name: gcr.io/google.com/cloudsdktool/cloud-sdk:slim
    waitFor: [docker-push]
    entrypoint: bash
    args:
      - -c
      - |
        # Get the full image digest (immutable reference)
        IMAGE_DIGEST=$(gcloud artifacts docker images describe \
          $_REGION-docker.pkg.dev/$_PROJECT_ID/$_REPO/$_IMAGE:$SHORT_SHA \
          --format='get(image_summary.digest)')

        # Create a Binary Authorization attestation
        gcloud beta container binauthz attestations sign-and-create \
          --artifact-url="$_REGION-docker.pkg.dev/$_PROJECT_ID/$_REPO/$_IMAGE@$IMAGE_DIGEST" \
          --attestor=projects/$_PROJECT_ID/attestors/build-attestor \
          --attestor-project=$_PROJECT_ID \
          --keyversion-project=$_PROJECT_ID \
          --keyversion-location=global \
          --keyversion-keyring=binauthz-keyring \
          --keyversion-key=build-signer \
          --keyversion=1

        # Store digest for downstream steps
        echo $IMAGE_DIGEST > /workspace/image_digest.txt

  # ── Step 6: Helm lint and template validation ───────────────────
  - id: helm-validate
    name: alpine/helm:3.15.0
    waitFor: ["-"]            # Run in parallel with build steps
    args:
      - lint
      - $_HELM_CHART
      - --values=$_HELM_CHART/values.yaml
      - --values=$_HELM_CHART/values-production.yaml
      - --strict

  # ── Step 7: Deploy to staging ──────────────────────────────────
  - id: deploy-staging
    name: gcr.io/google.com/cloudsdktool/cloud-sdk:slim
    waitFor: [sign-image, helm-validate]
    entrypoint: bash
    args:
      - -c
      - |
        IMAGE_DIGEST=$(cat /workspace/image_digest.txt)

        # Get GKE credentials
        gcloud container clusters get-credentials $_CLUSTER \
          --region=$_REGION --project=$_PROJECT_ID

        # Deploy with Helm using the immutable digest
        helm upgrade --install order-api $_HELM_CHART \
          --namespace staging \
          --create-namespace \
          --values $_HELM_CHART/values.yaml \
          --values $_HELM_CHART/values-staging.yaml \
          --set image.repository=$_REGION-docker.pkg.dev/$_PROJECT_ID/$_REPO/$_IMAGE \
          --set image.digest=$IMAGE_DIGEST \
          --wait \
          --timeout 5m \
          --atomic

  # ── Step 8: Run integration tests against staging ───────────────
  - id: integration-tests
    name: node:20-alpine
    waitFor: [deploy-staging]
    entrypoint: sh
    args:
      - -c
      - |
        npm ci
        STAGING_URL=$(kubectl get ingress order-api -n staging \
          -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
        API_BASE_URL=http://$STAGING_URL npm run test:integration

  # ── Step 9: Deploy to production ───────────────────────────────
  - id: deploy-production
    name: gcr.io/google.com/cloudsdktool/cloud-sdk:slim
    waitFor: [integration-tests]
    entrypoint: bash
    args:
      - -c
      - |
        IMAGE_DIGEST=$(cat /workspace/image_digest.txt)

        gcloud container clusters get-credentials $_CLUSTER \
          --region=$_REGION --project=$_PROJECT_ID

        helm upgrade --install order-api $_HELM_CHART \
          --namespace production \
          --create-namespace \
          --values $_HELM_CHART/values.yaml \
          --values $_HELM_CHART/values-production.yaml \
          --set image.repository=$_REGION-docker.pkg.dev/$_PROJECT_ID/$_REPO/$_IMAGE \
          --set image.digest=$IMAGE_DIGEST \
          --wait \
          --timeout 10m \
          --atomic

# Store build artifacts
artifacts:
  objects:
    location: gs://my-build-artifacts/cloudbuild/$BUILD_ID
    paths:
      - trivy-results.sarif
      - /workspace/image_digest.txt

# Build options
options:
  machineType: E2_HIGHCPU_8          # 8-vCPU build machine
  logging: CLOUD_LOGGING_ONLY
  dynamic_substitutions: true
  env:
    - _BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Build timeout
timeout: 1800s                       # 30-minute max build time
```

### 5.2 Cloud Build Trigger Configuration

```bash
# Create a build trigger on push to main
gcloud builds triggers create github \
  --project=$PROJECT_ID \
  --name=order-api-main-trigger \
  --repo-name=order-api \
  --repo-owner=myorg \
  --branch-pattern=^main$ \
  --build-config=cloudbuild.yaml \
  --description="CI/CD pipeline for order-api service" \
  --service-account=projects/$PROJECT_ID/serviceAccounts/cloudbuild-sa@$PROJECT_ID.iam.gserviceaccount.com

# Create a PR validation trigger (no deploy steps)
gcloud builds triggers create github \
  --project=$PROJECT_ID \
  --name=order-api-pr-trigger \
  --repo-name=order-api \
  --repo-owner=myorg \
  --pull-request-pattern=^main$ \
  --build-config=cloudbuild-pr.yaml \
  --description="PR validation for order-api"

# Grant Cloud Build SA permissions to deploy to GKE
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:cloudbuild-sa@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/container.developer"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:cloudbuild-sa@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.writer"
```

---

## 6. Cloud Operations Suite

### 6.1 Managed Prometheus — Metrics Collection

GKE Managed Prometheus (GMP) is a fully managed Prometheus-compatible metrics service. It runs a stripped-down Prometheus agent on each node (rather than a full server), forwarding metrics to Google's globally distributed Monarch time-series database.

```yaml
# PodMonitoring — scrape a specific Deployment's metrics
apiVersion: monitoring.googleapis.com/v1
kind: PodMonitoring
metadata:
  name: order-api-monitoring
  namespace: production
spec:
  selector:
    matchLabels:
      app: order-api
  endpoints:
    - port: metrics             # Container port name
      interval: 30s
      path: /metrics
      timeout: 10s

---
# ClusterPodMonitoring — scrape across all namespaces
apiVersion: monitoring.googleapis.com/v1
kind: ClusterPodMonitoring
metadata:
  name: all-services-monitoring
spec:
  selector:
    matchLabels:
      prometheus.io/scrape: "true"
  endpoints:
    - port: metrics
      interval: 30s
```

```yaml
# Rules — alerting rules managed by GMP
apiVersion: monitoring.googleapis.com/v1
kind: Rules
metadata:
  name: gke-production-alerts
  namespace: production
spec:
  groups:
    - name: pod-health
      interval: 1m
      rules:
        - alert: PodCrashLooping
          expr: |
            rate(kube_pod_container_status_restarts_total[15m]) > 0
          for: 15m
          labels:
            severity: warning
          annotations:
            summary: "Pod {{ $labels.namespace }}/{{ $labels.pod }} crash looping"
            runbook: "https://wiki.internal/runbooks/pod-crash-loop"

        - alert: DeploymentAvailabilityLow
          expr: |
            kube_deployment_status_replicas_available /
            kube_deployment_spec_replicas < 0.5
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "Deployment {{ $labels.namespace }}/{{ $labels.deployment }} below 50% availability"

        - alert: HighPodMemoryUsage
          expr: |
            container_memory_working_set_bytes /
            container_spec_memory_limit_bytes > 0.9
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Container {{ $labels.container }} using >90% of memory limit"
```

### 6.2 Cloud Logging — Structured Log Queries

```bash
# Query application logs using Cloud Logging's log explorer CLI
# Find all ERROR logs in the production namespace in the last hour
gcloud logging read \
  'resource.type="k8s_container"
   resource.labels.cluster_name="gke-production"
   resource.labels.namespace_name="production"
   severity>=ERROR
   timestamp>="2024-03-15T10:00:00Z"' \
  --project=$PROJECT_ID \
  --limit=100 \
  --format=json | jq '.[] | {time: .timestamp, msg: .textPayload, pod: .resource.labels.pod_name}'

# Find OOMKilled events
gcloud logging read \
  'resource.type="k8s_node"
   log_id("events")
   jsonPayload.reason="OOMKilling"' \
  --project=$PROJECT_ID \
  --limit=20

# Find all slow HTTP requests (>1s) using structured logs
gcloud logging read \
  'resource.type="k8s_container"
   resource.labels.namespace_name="production"
   jsonPayload.latency_ms>1000' \
  --project=$PROJECT_ID \
  --limit=50

# Create a log-based metric (count of 5xx errors per service)
gcloud logging metrics create http-5xx-errors \
  --project=$PROJECT_ID \
  --description="Count of HTTP 5xx errors per service" \
  --log-filter='
    resource.type="k8s_container"
    resource.labels.namespace_name="production"
    jsonPayload.status_code>=500' \
  --metric-descriptor-type=DELTA \
  --value-extractor='EXTRACT(jsonPayload.status_code)'
```

### 6.3 Cloud Trace — Distributed Tracing

```yaml
# OpenTelemetry Collector DaemonSet — forward traces to Cloud Trace
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: otel-collector
  namespace: kube-system
spec:
  selector:
    matchLabels:
      app: otel-collector
  template:
    metadata:
      labels:
        app: otel-collector
    spec:
      serviceAccountName: otel-collector-sa   # Needs Workload Identity with cloudtrace.agent role
      containers:
        - name: otel-collector
          image: otel/opentelemetry-collector-contrib:0.100.0
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 512Mi
          volumeMounts:
            - name: config
              mountPath: /conf
      volumes:
        - name: config
          configMap:
            name: otel-collector-config

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: otel-collector-config
  namespace: kube-system
data:
  config.yaml: |
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318

    processors:
      batch:
        timeout: 10s
        send_batch_size: 1024
      memory_limiter:
        limit_mib: 400
        spike_limit_mib: 100
        check_interval: 5s
      resourcedetection:
        detectors: [gke]        # Auto-detect GKE resource attributes

    exporters:
      googlecloud:
        project: my-gke-project
        log:
          default_log_name: opentelemetry.io/collector-exported-log

    service:
      pipelines:
        traces:
          receivers: [otlp]
          processors: [memory_limiter, resourcedetection, batch]
          exporters: [googlecloud]
        metrics:
          receivers: [otlp]
          processors: [memory_limiter, resourcedetection, batch]
          exporters: [googlecloud]
```

---

## 7. GKE Autopilot — Hands-on

### 7.1 Create an Autopilot Cluster

```bash
# Create a GKE Autopilot cluster
gcloud container clusters create-auto autopilot-production \
  --project=$PROJECT_ID \
  --region=$REGION \
  --release-channel=regular \
  --network=gke-vpc \
  --subnetwork=gke-nodes-subnet \
  --cluster-secondary-range-name=pods \
  --services-secondary-range-name=services \
  --workload-pool=${PROJECT_ID}.svc.id.goog \
  --enable-managed-prometheus \
  --security-posture=standard \
  --workload-vulnerability-scanning=standard

# Get credentials
gcloud container clusters get-credentials autopilot-production \
  --region=$REGION --project=$PROJECT_ID

# Notice: no nodes visible (Google manages them)
kubectl get nodes
# NAME                                                STATUS   ROLES    AGE   VERSION
# gk3-autopilot-production-nap-xxxxxx-xxxxxxxxxxx    Ready    <none>   45s   v1.30.x
# (Nodes appear on demand as Pods are scheduled)
```

### 7.2 Autopilot Cost Optimization Patterns

```yaml
# Pattern 1: Spot Pods for fault-tolerant batch jobs
# Autopilot Spot Pods cost up to 91% less than on-demand
apiVersion: batch/v1
kind: Job
metadata:
  name: data-export-job
  namespace: batch-jobs
spec:
  parallelism: 10
  completions: 100
  template:
    metadata:
      labels:
        app: data-export
    spec:
      # Request Spot VMs for this job
      nodeSelector:
        cloud.google.com/gke-spot: "true"
      tolerations:
        - key: cloud.google.com/gke-spot
          operator: Equal
          value: "true"
          effect: NoSchedule
      restartPolicy: OnFailure
      containers:
        - name: exporter
          image: us-east1-docker.pkg.dev/my-project/production-images/data-exporter:latest
          resources:
            requests:
              cpu: "1"
              memory: "2Gi"
            limits:
              cpu: "1"
              memory: "2Gi"

---
# Pattern 2: Right-size with VPA recommendations before setting requests
# Autopilot bills on requests — over-requesting wastes money
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: order-api-vpa
  namespace: production
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: order-api
  updatePolicy:
    updateMode: "Off"          # Recommend only — don't auto-apply in Autopilot
  resourcePolicy:
    containerPolicies:
      - containerName: api
        minAllowed:
          cpu: 250m
          memory: 512Mi
        maxAllowed:
          cpu: "4"
          memory: 8Gi

---
# Pattern 3: Scale-to-zero with KEDA on Autopilot
# Autopilot + KEDA = true serverless (pay only when queue has messages)
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: report-generator-scaler
  namespace: batch-jobs
spec:
  scaleTargetRef:
    name: report-generator
  minReplicaCount: 0           # Zero pods = zero cost when idle
  maxReplicaCount: 20
  cooldownPeriod: 600          # 10 minutes before scaling to zero
  triggers:
    - type: gcp-pubsub
      metadata:
        subscriptionName: projects/my-project/subscriptions/report-requests-sub
        activationValue: "0"
        mode: SubscriptionSize
```

### 7.3 Full Application Deployment on GKE Standard

```bash
# Apply Workload Identity and deploy the order-api service
kubectl apply -f - <<'EOF'
---
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    env: production
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: order-api-ksa
  namespace: production
  annotations:
    iam.gke.io/gcp-service-account: order-api-gsa@my-gke-project.iam.gserviceaccount.com
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-api
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: order-api
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: order-api
    spec:
      serviceAccountName: order-api-ksa
      containers:
        - name: api
          image: us-east1-docker.pkg.dev/my-gke-project/production-images/order-api:latest
          ports:
            - name: http
              containerPort: 8080
            - name: metrics
              containerPort: 9090
          resources:
            requests:
              cpu: 250m
              memory: 512Mi
            limits:
              cpu: 500m
              memory: 1Gi
          readinessProbe:
            httpGet:
              path: /health/ready
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /health/live
              port: 8080
            initialDelaySeconds: 30
            periodSeconds: 20
---
apiVersion: v1
kind: Service
metadata:
  name: order-api-svc
  namespace: production
  annotations:
    cloud.google.com/backend-config: '{"default":"order-api-backend-config"}'
    cloud.google.com/neg: '{"ingress":true}'
spec:
  selector:
    app: order-api
  ports:
    - port: 80
      targetPort: 8080
EOF

# Verify Workload Identity token injection
kubectl exec -n production deployment/order-api -- \
  curl -s -H "Metadata-Flavor: Google" \
  "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email"
# order-api-gsa@my-gke-project.iam.gserviceaccount.com
```

---

## 8. Real-World Scenario: Global Media Streaming Platform

### The Problem

StreamCo operates a video streaming platform serving 80 million monthly active users across 6 regions. Their current infrastructure is a mix of bare-metal in two datacenters and regional VMs managed manually. They face three operational crises simultaneously:

- **Flash crowd events** (sports finals, award shows) spike inbound traffic by 50x in under 2 minutes. Their manual scale-out process takes 20 minutes.
- **DDoS attacks** of 200+ Gbps targeting their recommendation API have caused 4 outages in the past 6 months.
- **ML inference costs** for their recommendation engine account for 41% of their total infrastructure bill.

### The Architecture

```
Global: Cloud CDN + Cloud Armor (DDoS + WAF at the edge)
    │
    ▼
Regional GKE Standard clusters (us-east1, eu-west1, asia-east1)
    │
    ├── Stream API (HPA: 10→500 replicas, 60s scale-up)
    │     └── Workload Identity → Cloud Storage (video segments)
    │
    ├── Recommendation Engine (Autopilot, GPU compute class)
    │     └── Workload Identity → BigQuery (user behaviour data)
    │
    ├── Transcoding Jobs (Spot VMs via NAP, KEDA Pub/Sub trigger)
    │     └── Workload Identity → Cloud Storage (source/output buckets)
    │
    └── Analytics Pipeline (Spot VMs, Dataplane V2 network policy)
          └── Workload Identity → BigQuery + Pub/Sub
```

### Key GKE Design Decisions

**Cloud Armor Adaptive Protection:** Automatically detects and mitigates DDoS attacks by building a per-service traffic baseline and generating blocking rules in under 60 seconds. The 200 Gbps attacks are now absorbed at the Cloud Armor edge layer, never reaching the GKE cluster.

**GKE Autopilot for inference:** The recommendation engine runs on Autopilot with `cloud.google.com/compute-class: accelerator` and `nvidia.com/gpu: "1"`. Autopilot provisions GPU nodes on demand and bins-packs inference Pods tightly. Idle hours cost zero.

**Node Auto-Provisioning for transcoding:** Transcoding jobs are queued in Pub/Sub. KEDA scales the Deployment from 0 to 200 workers. NAP provisions `c2-standard-60` Compute-Optimized VMs — the best price/performance for FFmpeg — only when there is work to do.

**Dataplane V2 network policies:** Production network policies block all inter-namespace traffic except explicitly permitted paths. DPv2 network policy logging provides audit-quality evidence of every inter-service connection.

### Results

| Metric | Before | After |
|---|---|---|
| Flash crowd response time | 20 min manual | 90 sec automated (HPA + NAP) |
| DDoS incidents (6-month rolling) | 4 (caused outages) | 0 (absorbed by Cloud Armor) |
| ML inference cost (monthly) | $380,000 | $94,000 (Autopilot + Spot GPU) |
| Transcoding cost per 1,000 hours | $840 (always-on VMs) | $210 (KEDA + Spot NAP) |
| Deployment frequency | Monthly (fear of change) | Multiple per day per service |

---

## 9. Common Pitfalls & Best Practices

### Pitfall 1: Undersizing Secondary IP Ranges
GKE secondary ranges for Pods are immutable after cluster creation. A team that provisions a `/20` Pod range (4,096 IPs) for a cluster they expect to have 100 nodes runs out of Alias IPs when they reach ~16 nodes (each gets a /24 = 256 IPs). Recreating a GKE cluster to resize secondary ranges requires migrating all workloads. **Always provision a `/14` or larger Pod secondary range. The IPs are not "used" by default — they are reserved address space that costs nothing.**

### Pitfall 2: Not Enabling Workload Identity on Node Pools
Workload Identity must be enabled at both the cluster level (`--workload-pool`) AND on each node pool (`mode = "GKE_METADATA"`). A node pool created without `GKE_METADATA` falls back to the node's service account — granting all Pods on that node all permissions held by the node SA. **Always set `workload_metadata_config.mode = "GKE_METADATA"` on every node pool in Terraform.**

### Pitfall 3: Using Routes-Based Clusters
Routes-based clusters hit a hard limit of 250 VPC routes per VPC, limiting you to ~250 nodes. Teams that start small with routes-based clusters and grow past this limit face a full cluster recreation. **Always use `--enable-ip-alias` (VPC-native) for new clusters. There is no valid reason to use routes-based clusters for new workloads.**

### Pitfall 4: Autopilot Pods Without Matching Requests and Limits
In Autopilot, billing is based on Pod requests. A Pod with `requests.cpu: 250m, limits.cpu: 2` will have its requests automatically bumped to `limits.cpu: 2` by Autopilot — you pay for 2 vCPUs even if the Pod uses 250m. **In Autopilot, always set `requests == limits` (Guaranteed QoS class). Use VPA in recommendation mode to right-size requests before going live.**

### Pitfall 5: Deploying Cloud Build Without a Dedicated Service Account
By default, Cloud Build uses the default Compute Engine service account — which has Editor permissions on your entire project. A compromised build could modify any GCP resource. **Create a dedicated Cloud Build service account with the minimum required roles: `roles/container.developer`, `roles/artifactregistry.writer`, and `roles/cloudkms.cryptoKeyEncrypterDecrypter` for image signing.**

### Pitfall 6: Skipping DPv2 Network Policy Logging
Teams that enable Dataplane V2 but do not configure network policy logging miss the most valuable security feature it offers. When a security incident occurs — a compromised Pod attempting lateral movement — DPv2 network policy logs provide an exact record of which Pod tried to connect to which other service, at which time, and whether it was allowed or denied. **Enable `networking.gke.io/network-policy-logging: "true"` on all NetworkPolicies in production.**

> **GKE Production Readiness Checklist**
> - [ ] VPC-native cluster with `/14`+ Pod secondary range per cluster
> - [ ] Dataplane V2 enabled (`--enable-dataplane-v2`)
> - [ ] Workload Identity enabled at cluster and node pool level (`GKE_METADATA`)
> - [ ] Private nodes with Cloud NAT for egress
> - [ ] Shielded nodes with Secure Boot and Integrity Monitoring
> - [ ] Binary Authorization policy enforced on all production images
> - [ ] Node Auto-Provisioning enabled with resource limits
> - [ ] Release channel set to `REGULAR` (not `RAPID` for production)
> - [ ] Managed Prometheus enabled with PodMonitoring resources
> - [ ] Cloud Armor policy attached to all external-facing Ingress resources
> - [ ] Network Policies with DPv2 logging on all production namespaces
> - [ ] Cloud Build using dedicated SA (not default Compute SA)
> - [ ] Artifact Registry cleanup policies (retain last N versions)
> - [ ] Spot VM node pool for fault-tolerant batch and stateless workloads

---

## 10. Key Takeaways

1. **GKE Autopilot eliminates node management entirely but changes the cost model from per-node to per-Pod.** For teams with variable, spiky workloads — especially those with significant idle time overnight or on weekends — Autopilot can reduce infrastructure costs by 40–65% compared to manually-managed Standard clusters with static node pools.

2. **VPC-native clusters with Alias IPs are mandatory for production GKE.** Routes-based clusters hit a hard 250-node limit and do not support Dataplane V2, Cloud Armor NEG integration, or VPC firewall rules on Pods. Always provision `/14`+ Pod secondary ranges — they are address space reservations, not allocations, and cost nothing.

3. **Dataplane V2 replaces iptables with eBPF for O(1) service routing and kernel-level network policy enforcement.** At scale (10,000+ Services), iptables degrades measurably. DPv2 maintains constant performance and adds network policy logging — critical for security audit trails.

4. **Workload Identity is GKE's answer to credential sprawl.** Every Pod that calls a Google Cloud API should use Workload Identity — no key files, no Secrets containing JSON credentials, no service account keys to rotate. The GKE Metadata Server handles token exchange transparently to application code.

5. **Cloud Armor at the Global Load Balancer edge is the most efficient place to absorb DDoS and filter malicious traffic.** By attaching Cloud Armor policies to GKE Ingress BackendConfigs, you filter traffic before it reaches the cluster network — saving both compute and network costs during attack events.

6. **Cloud Build + Artifact Registry + Cloud Operations Suite form a complete GCP-native software delivery platform.** Cloud Build executes CI steps without managing CI servers, Artifact Registry stores and scans images with cleanup policies, and Cloud Operations provides unified metrics (Managed Prometheus), logs (Cloud Logging), and traces (Cloud Trace) without installing or operating a separate observability stack.

---

## 11. Exercises & Labs

**Exercise 1: GKE Standard vs. Autopilot Cost Comparison**
Provision one GKE Standard cluster (`n2-standard-4`, 3 nodes) and one Autopilot cluster in the same region. Deploy the same Deployment (3 replicas, `requests.cpu: 500m, requests.memory: 512Mi`) to both. Use the GCP Billing export to Cloud BigQuery (or the Pricing Calculator) to estimate the monthly cost of each. Then simulate a night-time scale-down (reduce Standard replicas to 0; observe Autopilot behavior). Document the cost difference and explain why Autopilot may win or lose for your specific workload pattern.

**Exercise 2: Workload Identity End-to-End**
Create a Cloud Storage bucket with a test file. Create a GCP service account with `roles/storage.objectViewer` on the bucket. Configure the Workload Identity binding between the KSA and GSA. Deploy a Pod with the KSA and verify it can read the file using `gsutil` or the Python Cloud Storage SDK — without any `GOOGLE_APPLICATION_CREDENTIALS` environment variable. Then remove the IAM binding and verify access is denied.

**Exercise 3: Cloud Armor WAF in Action**
Create a Cloud Armor security policy with the OWASP SQLi preconfigured rule. Attach it to a GKE Ingress via a BackendConfig. Deploy a simple echo server. Send a normal HTTP request — verify it succeeds. Send a request with a SQL injection payload (e.g. `?id=1' OR '1'='1`) — verify Cloud Armor returns a 403. Check the Cloud Armor logs in Cloud Logging to find the blocked request and its matched rule.

**Exercise 4: Cloud Build Pipeline**
Create a Cloud Build pipeline that: (a) runs `npm test`, (b) builds and pushes a Docker image to Artifact Registry, (c) runs `trivy image --exit-code 1 --severity CRITICAL` on the pushed image, (d) deploys to a GKE namespace using `kubectl apply`. Trigger the build by pushing a commit. Then intentionally introduce a CRITICAL CVE by using an old base image — verify the pipeline fails at the Trivy step and the deployment does not proceed.

**Exercise 5: Node Auto-Provisioning with Spot VMs**
Enable NAP on a GKE Standard cluster with a CPU limit of 100 vCPUs. Submit a Job that requires 20 Pods, each requesting `4 vCPU / 8Gi`, with the Spot VM node selector. Observe NAP automatically create a new Spot node pool with the right machine type. Watch the Pods schedule and the job complete. After the job finishes, observe NAP scale the node pool back to zero and delete it. Document the node pool names created, the machine types selected, and the timeline.

---

*End of Chapter 7*

**Next → Chapter 8: Kubernetes Administrator**
