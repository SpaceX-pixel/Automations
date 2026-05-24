# Chapter 5 — Amazon Elastic Kubernetes Service (EKS)

> *Mastering DevOps in Kubernetes*
> Architecture · Managed Nodes · Fargate · IRSA · VPC CNI · Add-ons · Terraform

---

## 1. Introduction & Learning Objectives

Amazon Elastic Kubernetes Service (EKS) is the most widely deployed managed Kubernetes platform in production. It handles the operational burden of running the Kubernetes control plane — etcd, the API server, the scheduler, and the controller manager — leaving you responsible for the worker nodes, networking, storage, and the workloads that run on them.

But EKS is not simply "Kubernetes in AWS." It is a deeply AWS-native platform with its own opinions about networking (VPC CNI), identity (IRSA), node management (managed node groups, Fargate), storage (EBS and EFS CSI drivers), and observability (CloudWatch Container Insights). To run EKS well in production, you must understand both layers: the Kubernetes primitives from the preceding chapters and the AWS-specific integrations that make those primitives work at cloud scale.

This chapter builds a complete, production-grade EKS cluster from scratch — first with `eksctl` for rapid prototyping, then with Terraform for GitOps-compliant infrastructure management. We then layer on every essential integration: the AWS Load Balancer Controller for Ingress, the EBS and EFS CSI drivers for storage, IRSA for fine-grained AWS API access, and CloudWatch Container Insights for observability.

> **Learning Objectives**
> - Explain the EKS control plane architecture and the shared responsibility model between AWS and the cluster operator.
> - Create and manage EKS clusters using both `eksctl` and Terraform.
> - Configure managed node groups, self-managed node groups, and Fargate profiles for different workload types.
> - Implement IAM Roles for Service Accounts (IRSA) to grant fine-grained AWS API access to Pods.
> - Understand VPC CNI networking: how Pods get VPC-native IP addresses and the implications for subnet sizing.
> - Install and configure EKS Add-ons: VPC CNI, CoreDNS, kube-proxy, and EBS CSI driver.
> - Deploy the AWS Load Balancer Controller to provision ALBs and NLBs from Ingress and Service resources.
> - Configure the EBS CSI driver for dynamic block storage provisioning and the EFS CSI driver for shared storage.
> - Enable CloudWatch Container Insights for cluster, node, Pod, and container-level metrics and logs.

---

## 2. Core Concepts

### 2.1 EKS Architecture and Shared Responsibility

EKS splits the Kubernetes control plane from the data plane (worker nodes), and the boundary between AWS's responsibility and yours is precisely that split.

```
┌─────────────────────────────────────────────────────────────────────────┐
│  AWS Managed (EKS Control Plane)                  YOUR ACCOUNT          │
│  ─────────────────────────────────────────────────────────────────────  │
│                                                                          │
│  ┌──────────────────────────────────────────────┐                       │
│  │  EKS Control Plane (Multi-AZ, AWS-managed)   │                       │
│  │                                              │                       │
│  │  ┌──────────────┐   ┌──────────────────────┐ │                       │
│  │  │ kube-apiserver│   │ etcd (3-node cluster)│ │                       │
│  │  └──────────────┘   └──────────────────────┘ │                       │
│  │  ┌──────────────┐   ┌──────────────────────┐ │                       │
│  │  │  Scheduler   │   │ Controller Manager   │ │                       │
│  │  └──────────────┘   └──────────────────────┘ │                       │
│  │                                              │                       │
│  │  SLA: 99.95% uptime  Auto-patched by AWS     │                       │
│  └──────────────────────────────────────────────┘                       │
│                          │  Kubernetes API (HTTPS)                       │
│  ┌───────────────────────▼──────────────────────────────────────────┐  │
│  │  Your VPC                                                         │  │
│  │                                                                   │  │
│  │  AZ: us-east-1a          AZ: us-east-1b        AZ: us-east-1c   │  │
│  │  ┌───────────────┐   ┌───────────────┐   ┌───────────────┐      │  │
│  │  │  Worker Node  │   │  Worker Node  │   │  Worker Node  │      │  │
│  │  │  (EC2)        │   │  (EC2)        │   │  (EC2)        │      │  │
│  │  │  kubelet      │   │  kubelet      │   │  kubelet      │      │  │
│  │  │  Pods         │   │  Pods         │   │  Pods         │      │  │
│  │  │  VPC CNI ENI  │   │  VPC CNI ENI  │   │  VPC CNI ENI  │      │  │
│  │  └───────────────┘   └───────────────┘   └───────────────┘      │  │
│  │                                                                   │  │
│  │  ┌───────────────────────────────────────────────────────────┐   │  │
│  │  │  AWS Load Balancer Controller (ALB/NLB)                   │   │  │
│  │  │  EBS CSI Driver · EFS CSI Driver · Cluster Autoscaler     │   │  │
│  │  └───────────────────────────────────────────────────────────┘   │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

**AWS manages:** Control plane availability, etcd backups, control plane security patching, API server scaling, cross-AZ control plane redundancy.

**You manage:** Worker node OS patching, worker node security groups, VPC networking, IAM policies, storage provisioning, add-on upgrades, Kubernetes version upgrades (with AWS tooling).

#### EKS Pricing Model

| Component | Cost |
|---|---|
| EKS Control Plane | $0.10/hour per cluster (~$73/month) |
| Managed Node Groups (EC2) | Standard EC2 instance pricing |
| Fargate Pods | Per vCPU-second and per GB-second |
| EKS Add-ons | No additional charge (underlying resource costs apply) |
| Data Transfer | Standard AWS data transfer rates |

---

### 2.2 Node Group Types

EKS supports three fundamentally different ways to run worker nodes:

#### Managed Node Groups

AWS provisions, registers, and manages EC2 instances as Kubernetes worker nodes. AMIs are maintained by AWS with automatic security patches. Rolling node upgrades are handled by EKS with awareness of PodDisruptionBudgets.

```
Managed Node Group:
  ✅  AWS-managed AMIs (Amazon Linux 2, Bottlerocket, Ubuntu)
  ✅  Automatic node registration with the cluster
  ✅  Lifecycle managed by AWS Auto Scaling Group
  ✅  Respects PodDisruptionBudgets during upgrades
  ✅  Spot instance support (mixed instance types)
  ⚠️  Less control over node configuration than self-managed
```

#### Self-Managed Node Groups

You manage the EC2 instances, Launch Templates, Auto Scaling Groups, and AMI updates yourself. Full control, full responsibility.

```
Self-Managed Node Group:
  ✅  Full control over AMI, instance configuration, bootstrap scripts
  ✅  Can use custom AMIs (GPU drivers, specialized kernel modules)
  ✅  Spot Fleet support
  ⚠️  You own AMI patching and node lifecycle management
  ⚠️  Must manually cordon/drain nodes during upgrades
```

#### AWS Fargate

Fully serverless Kubernetes worker nodes. No EC2 instances to manage. Each Pod runs in its own isolated compute environment. AWS provisions and manages the underlying infrastructure.

```
Fargate:
  ✅  Zero node management — no patching, no capacity planning
  ✅  Per-Pod isolation (each Pod is a micro-VM)
  ✅  Automatic right-sizing (you specify CPU/memory in Pod spec)
  ⚠️  No support for DaemonSets
  ⚠️  No GPU support
  ⚠️  No hostPath volumes, no privileged containers
  ⚠️  Higher cost per compute unit vs equivalent EC2
  ⚠️  Cold start latency (~30-60s for first Pod on a profile)
```

| | Managed Node Groups | Self-Managed | Fargate |
|---|---|---|---|
| Node management | AWS | You | AWS (serverless) |
| AMI patching | AWS | You | N/A |
| Spot support | Yes | Yes | No |
| DaemonSets | Yes | Yes | No |
| Custom AMI | Limited | Full | No |
| GPU workloads | Yes | Yes | No |
| Stateful workloads | Yes | Yes | Limited |
| Best for | Standard workloads | Specialized needs | Burst / serverless |

---

### 2.3 VPC CNI — Native Pod Networking

The **Amazon VPC CNI plugin** (`aws-node`) is EKS's default network plugin. Unlike overlay network plugins (Flannel, Calico in VXLAN mode) that add a virtual network layer on top of the VPC, VPC CNI assigns actual VPC IP addresses directly to Pods. Every Pod has a real VPC IP — routable, directly accessible, and subject to VPC security group rules.

```
Traditional overlay networking:
  Node IP: 10.0.1.5
  Pod IPs: 192.168.0.0/24 (virtual network, encapsulated)
  External access: must traverse NAT/tunnel

VPC CNI (EKS):
  Node IP: 10.0.1.5 (eth0 — primary ENI)
  Pod IPs: 10.0.1.6, 10.0.1.7, 10.0.1.8 (secondary IPs on eth0 or secondary ENIs)
  External access: direct VPC routing — no overlay, no encapsulation
```

#### How VPC CNI Works

Each EC2 instance has one or more **Elastic Network Interfaces (ENIs)**. Each ENI can hold multiple private IP addresses. VPC CNI pre-allocates secondary IP addresses on node ENIs and assigns them to Pods as they are scheduled.

```
┌──────────────────────────────────────────────────────────────────┐
│  EC2 Node: m5.xlarge  (Node IP: 10.0.1.5)                        │
│                                                                   │
│  eth0 (primary ENI)           eth1 (secondary ENI)               │
│  Primary IP: 10.0.1.5         Primary IP: 10.0.1.20              │
│  Secondary IPs:               Secondary IPs:                      │
│    10.0.1.6  → Pod A           10.0.1.21 → Pod D                 │
│    10.0.1.7  → Pod B           10.0.1.22 → Pod E                 │
│    10.0.1.8  → Pod C           10.0.1.23 → Pod F                 │
│                                                                   │
│  Max Pods = (max ENIs × IPs per ENI) - 1 (node primary IP)       │
│  m5.xlarge: 4 ENIs × 15 IPs = 60 - 4 = 58 max Pods              │
└──────────────────────────────────────────────────────────────────┘
```

#### Subnet Sizing — The Most Common EKS Mistake

Because every Pod consumes a real VPC IP, subnet sizing is critical. Running out of IP addresses in a subnet causes Pod scheduling failures with cryptic errors like `failed to assign an IP address to container`.

```
Planning rule of thumb:
  Max concurrent Pods per node × Max nodes + headroom

Example: 50 m5.xlarge nodes × 58 Pods = 2,900 Pod IPs needed
         Add headroom for rolling updates: 2,900 × 1.25 = ~3,625

Subnet sizing:
  /20 = 4,096 IPs  ← barely enough (use separate subnets per AZ)
  /19 = 8,192 IPs  ← comfortable
  /18 = 16,384 IPs ← recommended for large clusters

Best practice: Use dedicated /19 or larger private subnets for EKS worker
nodes, separate from subnets used by other AWS resources.
```

#### Security Groups for Pods (SGP)

VPC CNI also supports **Security Groups for Pods** — assigning VPC security groups directly to individual Pods, rather than to the entire node. This enables fine-grained network policies at the Pod level using native AWS tooling.

```yaml
# SecurityGroupPolicy — assign an SG to Pods matching a selector
apiVersion: vpcresources.k8s.aws/v1beta1
kind: SecurityGroupPolicy
metadata:
  name: payment-service-sgp
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: payment-service
  securityGroups:
    groupIds:
      - sg-0a1b2c3d4e5f67890   # SG allowing outbound to RDS and Payment gateway
```

---

### 2.4 IAM Roles for Service Accounts (IRSA)

IRSA is the mechanism by which Kubernetes Pods running on EKS can assume AWS IAM roles and call AWS APIs — without storing static credentials anywhere in the cluster.

#### The Problem IRSA Solves

Before IRSA, granting a Pod access to S3, DynamoDB, or any other AWS service required one of:
- Storing AWS access keys in Kubernetes Secrets (credential leakage risk)
- Assigning IAM policies to the EC2 node's instance role (overly broad — all Pods on the node inherit the permission)

IRSA solves both problems by binding an IAM role to a Kubernetes Service Account using **OpenID Connect (OIDC) federation**.

#### How IRSA Works

```
┌────────────────────────────────────────────────────────────────────┐
│  Pod                                                                │
│  serviceAccountName: order-api-sa                                  │
│                                                                     │
│  Kubernetes injects a projected ServiceAccount token into the Pod:  │
│  /var/run/secrets/eks.amazonaws.com/serviceaccount/token            │
│  (JWT with audience: sts.amazonaws.com, sub: system:serviceaccount  │
│   :production:order-api-sa)                                         │
└──────────────────────────────┬─────────────────────────────────────┘
                               │  AssumeRoleWithWebIdentity
                               ▼
┌────────────────────────────────────────────────────────────────────┐
│  AWS STS (Security Token Service)                                   │
│                                                                     │
│  Validates the JWT against the OIDC provider endpoint               │
│  (oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1AF)     │
│  Checks trust policy: does this OIDC subject match the role?        │
└──────────────────────────────┬─────────────────────────────────────┘
                               │  Temporary credentials (15min TTL)
                               ▼
┌────────────────────────────────────────────────────────────────────┐
│  IAM Role: arn:aws:iam::123456789:role/order-api-prod               │
│  Policies attached: s3:GetObject on order-assets bucket             │
│                     dynamodb:PutItem on orders table                │
└────────────────────────────────────────────────────────────────────┘
```

#### IRSA Setup Workflow

```bash
# Step 1: Create the OIDC provider for your cluster
eksctl utils associate-iam-oidc-provider \
  --cluster my-eks-cluster \
  --region us-east-1 \
  --approve

# Get the OIDC issuer URL
aws eks describe-cluster \
  --name my-eks-cluster \
  --region us-east-1 \
  --query "cluster.identity.oidc.issuer" \
  --output text
# https://oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1AF
```

```json
// Step 2: Create an IAM role with a trust policy referencing the OIDC provider
// trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1AF"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1AF:sub":
            "system:serviceaccount:production:order-api-sa",
          "oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1AF:aud":
            "sts.amazonaws.com"
        }
      }
    }
  ]
}
```

```bash
# Create the IAM role
aws iam create-role \
  --role-name order-api-prod-role \
  --assume-role-policy-document file://trust-policy.json

# Attach a permissions policy
aws iam attach-role-policy \
  --role-name order-api-prod-role \
  --policy-arn arn:aws:iam::123456789012:policy/OrderApiS3Policy
```

```yaml
# Step 3: Create a Kubernetes ServiceAccount with the role ARN annotation
apiVersion: v1
kind: ServiceAccount
metadata:
  name: order-api-sa
  namespace: production
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/order-api-prod-role
    eks.amazonaws.com/token-expiration: "86400"    # Token TTL in seconds (default: 86400)

---
# Step 4: Reference the ServiceAccount in the Pod spec
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-api
  namespace: production
spec:
  template:
    spec:
      serviceAccountName: order-api-sa   # Pod assumes the IAM role
      containers:
        - name: api
          image: myapp/order-api:1.4.2
          # AWS SDK in the container automatically picks up IRSA credentials
          # via the AWS_WEB_IDENTITY_TOKEN_FILE and AWS_ROLE_ARN env vars
          # injected by the EKS Pod Identity Webhook
```

---

### 2.5 EKS Add-ons

EKS Add-ons are AWS-managed, version-tracked Kubernetes components that run on your cluster. AWS tests add-on versions against EKS Kubernetes versions and manages their lifecycle through the EKS API.

| Add-on | Purpose | Required |
|---|---|---|
| `vpc-cni` | Pod networking (VPC IP assignment) | Yes |
| `coredns` | In-cluster DNS resolution | Yes |
| `kube-proxy` | Service networking (iptables/ipvs rules) | Yes |
| `aws-ebs-csi-driver` | Dynamic EBS volume provisioning | For stateful workloads |
| `aws-efs-csi-driver` | EFS shared filesystem access | For shared storage |
| `eks-pod-identity-agent` | EKS Pod Identity (newer alternative to IRSA) | Optional |
| `amazon-cloudwatch-observability` | CloudWatch metrics and logs | Recommended |
| `aws-guardduty-agent` | EKS runtime threat detection | Security |
| `adot` | AWS Distro for OpenTelemetry | Tracing |

```bash
# List available add-ons and their versions
aws eks describe-addon-versions \
  --kubernetes-version 1.30 \
  --region us-east-1 \
  --query "addons[].{Name:addonName,Versions:addonVersions[0].addonVersion}" \
  --output table

# Check the status of installed add-ons
aws eks list-addons --cluster-name my-eks-cluster --region us-east-1
aws eks describe-addon --cluster-name my-eks-cluster --addon-name vpc-cni --region us-east-1

# Update an add-on to the latest version
aws eks update-addon \
  --cluster-name my-eks-cluster \
  --addon-name vpc-cni \
  --addon-version v1.18.1-eksbuild.3 \
  --resolve-conflicts OVERWRITE \
  --region us-east-1
```

---

## 3. Cluster Creation with eksctl

`eksctl` is the official CLI for creating and managing EKS clusters. It provisions all required AWS resources — VPC, subnets, security groups, IAM roles, the EKS cluster, and node groups — from a single declarative YAML file.

### 3.1 Install Prerequisites

```bash
# Install eksctl
# macOS
brew tap weaveworks/tap
brew install weaveworks/tap/eksctl

# Linux
ARCH=amd64
PLATFORM=$(uname -s)_$ARCH
curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_${PLATFORM}.tar.gz"
tar -xzf eksctl_${PLATFORM}.tar.gz -C /tmp && sudo mv /tmp/eksctl /usr/local/bin

# Verify
eksctl version   # Should show v0.180+

# Install AWS CLI v2
brew install awscli   # macOS
# or follow https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html

# Configure AWS credentials
aws configure
# AWS Access Key ID: AKIAIOSFODNN7EXAMPLE
# AWS Secret Access Key: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
# Default region name: us-east-1
# Default output format: json
```

### 3.2 Full Production eksctl ClusterConfig

```yaml
# eks-cluster.yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: production-eks
  region: us-east-1
  version: "1.30"
  tags:
    environment: production
    team: platform
    managed-by: eksctl

# ── IAM ──────────────────────────────────────────────────────────
iam:
  withOIDC: true                    # Enable IRSA (creates OIDC provider)
  serviceAccounts:
    # AWS Load Balancer Controller SA
    - metadata:
        name: aws-load-balancer-controller
        namespace: kube-system
      wellKnownPolicies:
        awsLoadBalancerController: true
    # EBS CSI Driver SA
    - metadata:
        name: ebs-csi-controller-sa
        namespace: kube-system
      wellKnownPolicies:
        ebsCSIController: true
    # Cluster Autoscaler SA
    - metadata:
        name: cluster-autoscaler
        namespace: kube-system
      wellKnownPolicies:
        autoScaler: true
    # CloudWatch agent SA
    - metadata:
        name: cloudwatch-agent
        namespace: amazon-cloudwatch
      attachPolicyARNs:
        - arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy

# ── VPC ──────────────────────────────────────────────────────────
vpc:
  cidr: 10.0.0.0/16
  clusterEndpoints:
    privateAccess: true             # Control plane accessible from within VPC
    publicAccess: true              # Also accessible from internet (restrict in production)
  publicAccessCIDRs:
    - "203.0.113.0/24"             # Restrict to your corporate IP range
  nat:
    gateway: HighlyAvailable        # One NAT GW per AZ (not single point of failure)

# ── Add-ons ──────────────────────────────────────────────────────
addons:
  - name: vpc-cni
    version: latest
    attachPolicyARNs:
      - arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
    configurationValues: |-
      enableNetworkPolicy: "true"
  - name: coredns
    version: latest
  - name: kube-proxy
    version: latest
  - name: aws-ebs-csi-driver
    version: latest
    wellKnownPolicies:
      ebsCSIController: true
  - name: amazon-cloudwatch-observability
    version: latest

# ── Managed Node Groups ───────────────────────────────────────────
managedNodeGroups:
  # General-purpose node group (on-demand)
  - name: general-ondemand
    instanceType: m5.xlarge
    minSize: 3
    maxSize: 20
    desiredCapacity: 6
    volumeSize: 100
    volumeType: gp3
    volumeEncrypted: true
    amiFamily: AmazonLinux2023
    labels:
      role: general
      node-type: on-demand
    tags:
      k8s.io/cluster-autoscaler/enabled: "true"
      k8s.io/cluster-autoscaler/production-eks: "owned"
    iam:
      attachPolicyARNs:
        - arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
        - arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
        - arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
        - arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy
    updateConfig:
      maxUnavailable: 1             # Rolling node upgrades
    privateNetworking: true         # Nodes in private subnets

  # Spot instance node group (for fault-tolerant workloads)
  - name: spot-mixed
    instanceTypes:
      - m5.xlarge
      - m5.2xlarge
      - m5a.xlarge
      - m5a.2xlarge
      - m4.xlarge
    spot: true
    minSize: 0
    maxSize: 30
    desiredCapacity: 0
    volumeSize: 100
    volumeType: gp3
    volumeEncrypted: true
    labels:
      role: spot
      node-type: spot
    taints:
      - key: spot
        value: "true"
        effect: NoSchedule          # Only Pods tolerating 'spot' run here
    tags:
      k8s.io/cluster-autoscaler/enabled: "true"
      k8s.io/cluster-autoscaler/production-eks: "owned"
    iam:
      attachPolicyARNs:
        - arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
        - arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
        - arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly

  # Memory-optimized node group (for databases, caches)
  - name: memory-optimized
    instanceType: r5.2xlarge
    minSize: 0
    maxSize: 10
    desiredCapacity: 3
    volumeSize: 200
    volumeType: gp3
    volumeEncrypted: true
    labels:
      role: memory
      node-type: on-demand
    taints:
      - key: workload
        value: memory-intensive
        effect: NoSchedule
    privateNetworking: true

# ── Fargate Profiles ─────────────────────────────────────────────
fargateProfiles:
  - name: serverless-jobs
    selectors:
      - namespace: batch-jobs       # All Pods in batch-jobs namespace → Fargate
      - namespace: kube-system
        labels:
          k8s-app: kube-dns         # CoreDNS on Fargate (optional)

# ── CloudWatch Logging ────────────────────────────────────────────
cloudWatch:
  clusterLogging:
    enableTypes:
      - api                         # API server audit logs
      - audit                       # Kubernetes audit logs
      - authenticator                # AWS IAM authenticator logs
      - controllerManager           # Controller manager logs
      - scheduler                   # Scheduler logs
    logRetentionInDays: 90
```

```bash
# Create the cluster (15-25 minutes)
eksctl create cluster -f eks-cluster.yaml

# Verify the cluster is healthy
kubectl get nodes -o wide
kubectl get pods -A

# Update kubeconfig to use the new cluster
aws eks update-kubeconfig \
  --name production-eks \
  --region us-east-1

# Check add-on status
eksctl get addon --cluster production-eks --region us-east-1
```

---

## 4. Cluster Creation with Terraform

For production environments managed via GitOps, Terraform is the standard IaC tool for EKS cluster provisioning. The `terraform-aws-eks` module is the community-maintained, battle-tested module for EKS.

### 4.1 Repository Structure

```
eks-infrastructure/
├── environments/
│   ├── production/
│   │   ├── main.tf             # Cluster configuration
│   │   ├── variables.tf        # Input variables
│   │   ├── outputs.tf          # Exported values
│   │   └── terraform.tfvars    # Production-specific values
│   └── staging/
│       └── ...
├── modules/
│   └── eks-addons/             # Custom add-on configuration module
└── backend.tf                  # S3 remote state configuration
```

### 4.2 Backend Configuration

```hcl
# backend.tf
terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
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

  backend "s3" {
    bucket         = "my-terraform-state-123456789"
    key            = "eks/production/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"   # DynamoDB table for state locking
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "terraform"
      Project     = "eks-platform"
    }
  }
}
```

### 4.3 VPC Configuration

```hcl
# environments/production/main.tf

locals {
  cluster_name    = "production-eks"
  cluster_version = "1.30"
  region          = "us-east-1"

  # AZs to use
  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    cluster     = local.cluster_name
    environment = "production"
  }
}

data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# ── VPC ──────────────────────────────────────────────────────────
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.cluster_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = local.azs
  private_subnets = ["10.0.1.0/19", "10.0.33.0/19", "10.0.65.0/19"]   # /19 per AZ
  public_subnets  = ["10.0.128.0/24", "10.0.129.0/24", "10.0.130.0/24"]
  intra_subnets   = ["10.0.131.0/24", "10.0.132.0/24", "10.0.133.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = false         # One NAT GW per AZ (HA)
  one_nat_gateway_per_az = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Tags required for EKS to discover subnets
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1                              # Public subnets for ALBs
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1                    # Private subnets for internal ALBs
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  tags = local.tags
}
```

### 4.4 EKS Cluster and Node Groups

```hcl
# ── EKS Cluster ──────────────────────────────────────────────────
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.cluster_name
  cluster_version = local.cluster_version

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access_cidrs = ["203.0.113.0/24"]  # Your corporate IP

  cluster_addons = {
    coredns = {
      most_recent = true
      configuration_values = jsonencode({
        replicaCount = 3
        resources = {
          limits   = { cpu = "200m", memory = "256Mi" }
          requests = { cpu = "100m", memory = "128Mi" }
        }
      })
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent              = true
      before_compute           = true   # Install CNI before nodes join
      service_account_role_arn = module.vpc_cni_irsa.iam_role_arn
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"   # More IPs per node
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_irsa.iam_role_arn
    }
  }

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.intra_subnets

  # Enable IRSA
  enable_irsa = true

  # Cluster access (EKS access entries — replaces aws-auth ConfigMap)
  enable_cluster_creator_admin_permissions = true

  # Control plane logging
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # ── EKS Managed Node Groups ─────────────────────────────────
  eks_managed_node_groups = {

    # General-purpose on-demand nodes
    general_ondemand = {
      name           = "general-ondemand"
      instance_types = ["m5.xlarge"]

      min_size     = 3
      max_size     = 20
      desired_size = 6

      ami_type       = "AL2023_x86_64_STANDARD"
      capacity_type  = "ON_DEMAND"

      disk_size = 100

      labels = {
        role       = "general"
        node-type  = "on-demand"
      }

      taints = {}

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 100
            volume_type           = "gp3"
            iops                  = 3000
            throughput            = 125
            encrypted             = true
            delete_on_termination = true
          }
        }
      }

      # Cluster Autoscaler tags
      tags = merge(local.tags, {
        "k8s.io/cluster-autoscaler/enabled"                    = "true"
        "k8s.io/cluster-autoscaler/${local.cluster_name}"      = "owned"
      })

      update_config = {
        max_unavailable_percentage = 25
      }
    }

    # Spot instances for fault-tolerant workloads
    spot_mixed = {
      name           = "spot-mixed"
      instance_types = ["m5.xlarge", "m5.2xlarge", "m5a.xlarge", "m5a.2xlarge"]

      min_size     = 0
      max_size     = 30
      desired_size = 0

      capacity_type = "SPOT"

      labels = {
        role      = "spot"
        node-type = "spot"
      }

      taints = {
        spot = {
          key    = "spot"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }

      tags = merge(local.tags, {
        "k8s.io/cluster-autoscaler/enabled"               = "true"
        "k8s.io/cluster-autoscaler/${local.cluster_name}" = "owned"
      })
    }

    # Memory-optimized for stateful workloads
    memory_optimized = {
      name           = "memory-optimized"
      instance_types = ["r5.2xlarge"]

      min_size     = 0
      max_size     = 10
      desired_size = 3

      capacity_type = "ON_DEMAND"
      disk_size     = 200

      labels = {
        role      = "memory"
        node-type = "on-demand"
      }

      taints = {
        memory = {
          key    = "workload"
          value  = "memory-intensive"
          effect = "NO_SCHEDULE"
        }
      }

      tags = local.tags
    }
  }

  tags = local.tags
}

# ── IRSA roles for add-ons ────────────────────────────────────────
module "vpc_cni_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39"

  role_name             = "${local.cluster_name}-vpc-cni"
  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }
}

module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39"

  role_name             = "${local.cluster_name}-ebs-csi"
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

module "lb_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39"

  role_name                              = "${local.cluster_name}-lb-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}
```

### 4.5 Outputs

```hcl
# outputs.tf
output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value     = module.eks.cluster_endpoint
  sensitive = true
}

output "cluster_certificate_authority_data" {
  value     = module.eks.cluster_certificate_authority_data
  sensitive = true
}

output "oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "lb_controller_role_arn" {
  value = module.lb_controller_irsa.iam_role_arn
}

output "ebs_csi_role_arn" {
  value = module.ebs_csi_irsa.iam_role_arn
}

output "configure_kubectl" {
  value = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${local.region}"
}
```

```bash
# Deploy the infrastructure
cd environments/production
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# Configure kubectl
$(terraform output -raw configure_kubectl)

# Verify cluster
kubectl get nodes
kubectl get pods -A
```

---

## 5. AWS Load Balancer Controller

The AWS Load Balancer Controller is an EKS-specific controller that provisions AWS Application Load Balancers (ALBs) from Kubernetes Ingress resources and Network Load Balancers (NLBs) from Service resources of type `LoadBalancer`.

### 5.1 Installation via Helm

```bash
# Add the Helm repository
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Install the AWS Load Balancer Controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --namespace kube-system \
  --set clusterName=production-eks \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=\
    arn:aws:iam::123456789012:role/production-eks-lb-controller \
  --set replicaCount=2 \
  --set podDisruptionBudget.maxUnavailable=1 \
  --set resources.requests.cpu=100m \
  --set resources.requests.memory=128Mi \
  --set resources.limits.cpu=200m \
  --set resources.limits.memory=256Mi

# Verify
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
# NAME                                           READY   STATUS    RESTARTS
# aws-load-balancer-controller-5d4f8b9c7-xk9p2  1/1     Running   0
# aws-load-balancer-controller-5d4f8b9c7-8vr2q  1/1     Running   0
```

### 5.2 Ingress with ALB — HTTP/HTTPS

```yaml
# ingress-alb.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: order-api-ingress
  namespace: production
  annotations:
    # ALB configuration
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing      # or internal
    alb.ingress.kubernetes.io/target-type: ip              # ip = Pod IPs; instance = node ports
    alb.ingress.kubernetes.io/load-balancer-name: production-api-alb

    # HTTPS and TLS termination
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80},{"HTTPS":443}]'
    alb.ingress.kubernetes.io/ssl-redirect: "443"          # Redirect HTTP → HTTPS
    alb.ingress.kubernetes.io/certificate-arn: >
      arn:aws:acm:us-east-1:123456789012:certificate/abc123

    # Health checks
    alb.ingress.kubernetes.io/healthcheck-path: /health/ready
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: "15"
    alb.ingress.kubernetes.io/healthcheck-timeout-seconds: "5"
    alb.ingress.kubernetes.io/healthy-threshold-count: "2"
    alb.ingress.kubernetes.io/unhealthy-threshold-count: "3"

    # Access logging
    alb.ingress.kubernetes.io/load-balancer-attributes: >
      access_logs.s3.enabled=true,
      access_logs.s3.bucket=my-alb-access-logs,
      access_logs.s3.prefix=production-api-alb,
      idle_timeout.timeout_seconds=60

    # WAF integration
    alb.ingress.kubernetes.io/wafv2-acl-arn: >
      arn:aws:wafv2:us-east-1:123456789012:regional/webacl/production-waf/abc123

    # Target group attributes
    alb.ingress.kubernetes.io/target-group-attributes: >
      deregistration_delay.timeout_seconds=30,
      slow_start.duration_seconds=60

spec:
  ingressClassName: alb
  rules:
    - host: api.mycompany.com
      http:
        paths:
          - path: /orders
            pathType: Prefix
            backend:
              service:
                name: order-svc
                port:
                  number: 80
          - path: /payments
            pathType: Prefix
            backend:
              service:
                name: payment-svc
                port:
                  number: 80
          - path: /
            pathType: Prefix
            backend:
              service:
                name: api-gateway-svc
                port:
                  number: 80
    - host: admin.mycompany.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: admin-svc
                port:
                  number: 80
```

### 5.3 Internal NLB for Service-to-Service Communication

```yaml
# nlb-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: order-svc-nlb
  namespace: production
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "external"
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "ip"
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internal"
    service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-path: "/health/ready"
    # Preserve client IP (NLBs support this; ALBs do not without X-Forwarded-For)
    service.beta.kubernetes.io/aws-load-balancer-target-group-attributes: >
      preserve_client_ip.enabled=true
spec:
  type: LoadBalancer
  selector:
    app: order-svc
  ports:
    - name: http
      port: 80
      targetPort: 8080
      protocol: TCP
```

---

## 6. Storage: EBS and EFS CSI Drivers

### 6.1 EBS CSI Driver — Block Storage

The EBS CSI driver enables dynamic provisioning of EBS volumes as PersistentVolumes. It replaces the deprecated in-tree `kubernetes.io/aws-ebs` provisioner.

```yaml
# Storage classes for different workload profiles
---
# General-purpose SSD (balanced IOPS/cost)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
  encrypted: "true"
reclaimPolicy: Delete              # Use Retain for production databases
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true

---
# High-performance SSD (databases, high-throughput workloads)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3-high-perf
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iops: "16000"
  throughput: "1000"
  encrypted: "true"
  kmsKeyId: "arn:aws:kms:us-east-1:123456789012:alias/eks-ebs-key"
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true

---
# Provisioned IOPS io2 (mission-critical databases)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: io2-extreme
provisioner: ebs.csi.aws.com
parameters:
  type: io2
  iops: "64000"
  encrypted: "true"
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

```bash
# Verify the EBS CSI driver is running
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-ebs-csi-driver

# Test dynamic provisioning
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ebs-test-pvc
  namespace: default
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: gp3
  resources:
    requests:
      storage: 10Gi
EOF

kubectl get pvc ebs-test-pvc --watch
# NAME           STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   AGE
# ebs-test-pvc   Pending                                      gp3            2s
# ebs-test-pvc   Bound     pvc-xxx  10Gi       RWO            gp3            8s
# (Bound once a Pod consuming it is scheduled — WaitForFirstConsumer)
```

### 6.2 EFS CSI Driver — Shared Filesystem

The EFS CSI driver provides access to Amazon Elastic File System — a fully managed, serverless, elastic NFS filesystem that can be mounted simultaneously by multiple Pods across multiple AZs.

```bash
# Install EFS CSI driver (if not installed as EKS add-on)
helm repo add aws-efs-csi-driver https://kubernetes-sigs.github.io/aws-efs-csi-driver/
helm repo update

helm install aws-efs-csi-driver aws-efs-csi-driver/aws-efs-csi-driver \
  --namespace kube-system \
  --set controller.serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=\
    arn:aws:iam::123456789012:role/production-eks-efs-csi

# Create the EFS filesystem (Terraform or AWS CLI)
aws efs create-file-system \
  --performance-mode generalPurpose \
  --throughput-mode elastic \
  --encrypted \
  --tags Key=Name,Value=eks-shared-storage \
  --region us-east-1

# Create mount targets in each private subnet
EFS_ID=fs-0a1b2c3d4e5f67890
for SUBNET in subnet-abc1 subnet-abc2 subnet-abc3; do
  aws efs create-mount-target \
    --file-system-id $EFS_ID \
    --subnet-id $SUBNET \
    --security-groups sg-0a1b2c3d4e5f67890 \
    --region us-east-1
done
```

```yaml
# EFS StorageClass — dynamic provisioning with access points
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: efs-shared
provisioner: efs.csi.aws.com
parameters:
  provisioningMode: efs-ap          # Use EFS access points (isolation per PVC)
  fileSystemId: fs-0a1b2c3d4e5f67890
  directoryPerms: "700"
  gidRangeStart: "1000"
  gidRangeEnd: "2000"
  basePath: "/dynamic_provisioning"
reclaimPolicy: Retain
volumeBindingMode: Immediate        # EFS is multi-AZ; no zone constraint
allowVolumeExpansion: false         # EFS is elastic; no resize needed

---
# Example: Shared configuration files for a multi-Pod deployment
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shared-config-pvc
  namespace: production
spec:
  accessModes:
    - ReadWriteMany                  # Multiple Pods across multiple nodes
  storageClassName: efs-shared
  resources:
    requests:
      storage: 10Gi                  # EFS is elastic; this is a soft limit only
```

---

## 7. CloudWatch Container Insights

CloudWatch Container Insights collects, aggregates, and summarizes metrics and logs from Kubernetes clusters — including cluster, node, Pod, and container-level telemetry — into CloudWatch dashboards and alarms.

### 7.1 Enable via EKS Add-on

```bash
# Install via EKS add-on (preferred — AWS manages updates)
aws eks create-addon \
  --cluster-name production-eks \
  --addon-name amazon-cloudwatch-observability \
  --service-account-role-arn arn:aws:iam::123456789012:role/production-eks-cloudwatch \
  --region us-east-1

# Verify the add-on and DaemonSets are running
kubectl get pods -n amazon-cloudwatch
# NAME                                        READY   STATUS
# cloudwatch-agent-abc12                      1/1     Running   ← Per-node DaemonSet
# cloudwatch-agent-def34                      1/1     Running
# fluent-bit-xyz89                            1/1     Running   ← Log forwarding DaemonSet
# fluent-bit-uvw67                            1/1     Running
```

### 7.2 Fluent Bit Log Configuration

```yaml
# Custom Fluent Bit ConfigMap for structured log routing
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-config
  namespace: amazon-cloudwatch
data:
  fluent-bit.conf: |
    [SERVICE]
        Flush         5
        Grace         30
        Log_Level     info
        Daemon        off
        Parsers_File  parsers.conf

    # Tail all container logs
    [INPUT]
        Name              tail
        Tag               kube.*
        Path              /var/log/containers/*.log
        Parser            docker
        DB                /var/fluent-bit/state/flb_kube.db
        Mem_Buf_Limit     50MB
        Skip_Long_Lines   On
        Refresh_Interval  10

    # Enrich with Kubernetes metadata
    [FILTER]
        Name                kubernetes
        Match               kube.*
        Kube_URL            https://kubernetes.default.svc:443
        Kube_CA_File        /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        Kube_Token_File     /var/run/secrets/kubernetes.io/serviceaccount/token
        Merge_Log           On
        Keep_Log            Off
        K8S-Logging.Parser  On
        K8S-Logging.Exclude On

    # Route application logs to dedicated log group
    [OUTPUT]
        Name                cloudwatch_logs
        Match               kube.*
        region              us-east-1
        log_group_name      /eks/production-eks/application
        log_stream_prefix   ${HOSTNAME}-
        auto_create_group   true
        log_retention_days  30

    # Route system logs separately
    [OUTPUT]
        Name                cloudwatch_logs
        Match               host.*
        region              us-east-1
        log_group_name      /eks/production-eks/host
        log_stream_prefix   ${HOSTNAME}-
        auto_create_group   true
        log_retention_days  90
```

### 7.3 CloudWatch Alarms and Dashboards

```bash
# Create a CloudWatch alarm for high Pod CPU utilization
aws cloudwatch put-metric-alarm \
  --alarm-name "eks-pod-high-cpu-production" \
  --alarm-description "Alert when any Pod exceeds 80% CPU for 5 minutes" \
  --metric-name pod_cpu_utilization \
  --namespace ContainerInsights \
  --dimensions Name=ClusterName,Value=production-eks \
  --statistic Average \
  --period 300 \
  --evaluation-periods 2 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --alarm-actions arn:aws:sns:us-east-1:123456789012:eks-alerts \
  --region us-east-1

# Create alarm for node memory pressure
aws cloudwatch put-metric-alarm \
  --alarm-name "eks-node-memory-pressure-production" \
  --alarm-description "Alert when node memory utilization exceeds 85%" \
  --metric-name node_memory_utilization \
  --namespace ContainerInsights \
  --dimensions Name=ClusterName,Value=production-eks \
  --statistic Average \
  --period 300 \
  --evaluation-periods 3 \
  --threshold 85 \
  --comparison-operator GreaterThanThreshold \
  --alarm-actions arn:aws:sns:us-east-1:123456789012:eks-alerts \
  --region us-east-1

# Query Container Insights logs with CloudWatch Insights
aws logs start-query \
  --log-group-name /aws/eks/production-eks/cluster \
  --start-time $(date -d '1 hour ago' +%s) \
  --end-time $(date +%s) \
  --query-string '
    fields @timestamp, @message
    | filter @logStream like /kube-apiserver/
    | filter @message like /error/
    | sort @timestamp desc
    | limit 50
  '
```

---

## 8. Step-by-Step Hands-on Walkthrough

### 8.1 Deploy a Complete Application on EKS

This walkthrough assumes you have deployed the cluster using either `eksctl` or Terraform from Sections 3 and 4.

```bash
# Confirm kubectl is connected to the right cluster
kubectl config current-context
# arn:aws:eks:us-east-1:123456789012:cluster/production-eks

kubectl get nodes -o wide
# NAME                          STATUS   ROLES    AGE   VERSION         INSTANCE-TYPE
# ip-10-0-1-45.ec2.internal     Ready    <none>   10m   v1.30.0-eks     m5.xlarge
# ip-10-0-33-102.ec2.internal   Ready    <none>   10m   v1.30.0-eks     m5.xlarge
# ip-10-0-65-78.ec2.internal    Ready    <none>   10m   v1.30.0-eks     m5.xlarge
```

### 8.2 IRSA in Practice — S3 Access Without Credentials

```bash
# Create an IAM policy for S3 read access
aws iam create-policy \
  --policy-name eks-s3-read-policy \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::my-app-assets",
        "arn:aws:s3:::my-app-assets/*"
      ]
    }]
  }'

# Create the IRSA role using eksctl (simplest method)
eksctl create iamserviceaccount \
  --name s3-reader-sa \
  --namespace production \
  --cluster production-eks \
  --region us-east-1 \
  --attach-policy-arn arn:aws:iam::123456789012:policy/eks-s3-read-policy \
  --approve \
  --override-existing-serviceaccounts

# Verify the ServiceAccount has the role annotation
kubectl get sa s3-reader-sa -n production -o yaml | grep role-arn
# eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/...

# Test the IRSA credentials in a Pod
kubectl run irsa-test \
  --image=amazon/aws-cli:latest \
  --restart=Never \
  --serviceaccount=s3-reader-sa \
  --namespace=production \
  -it --rm \
  -- s3 ls s3://my-app-assets/
# (Lists bucket contents — no credentials configured in the Pod)
```

### 8.3 Deploy with ALB Ingress

```bash
# Create a test namespace and deploy
kubectl create namespace demo

kubectl create deployment demo-app \
  --image=nginx:alpine \
  --replicas=3 \
  --namespace=demo

kubectl expose deployment demo-app \
  --port=80 \
  --target-port=80 \
  --namespace=demo

# Create the ALB Ingress
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: demo-ingress
  namespace: demo
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: demo-app
                port:
                  number: 80
EOF

# Watch for the ALB to be provisioned (2-3 minutes)
kubectl get ingress demo-ingress -n demo --watch
# NAME           CLASS   HOSTS   ADDRESS                                          PORTS
# demo-ingress   alb     *       k8s-demo-xxx.us-east-1.elb.amazonaws.com         80

# Test
ALB_URL=$(kubectl get ingress demo-ingress -n demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl http://$ALB_URL
```

---

## 9. Real-World Scenario: Multi-Tenant SaaS Platform on EKS

### The Problem

CloudOps, a B2B SaaS company, serves 200 enterprise customers from a single application deployed on VMs. Each customer requires data isolation, the ability to scale their tier independently, and a 99.9% uptime SLA. Managing 200 separate VM deployments is operationally unsustainable.

### The Architecture

```
Route 53 (per-customer subdomain routing)
    │
    ▼
ALB (AWS Load Balancer Controller, multi-host Ingress)
    │
    ├─── tenant-a.cloudops.io ──▶ namespace: tenant-a
    │                                  ├── api Deployment (3 replicas, HPA)
    │                                  └── postgres StatefulSet (CloudNativePG)
    │
    ├─── tenant-b.cloudops.io ──▶ namespace: tenant-b
    │                                  └── ...
    │
    └─── tenant-c.cloudops.io ──▶ namespace: tenant-c
                                       └── ...

Each namespace:
  - ResourceQuota enforcing per-tenant compute limits
  - NetworkPolicy isolating tenant traffic
  - IRSA ServiceAccount for tenant-specific S3 bucket access
  - CloudWatch log group per tenant namespace
```

### Key EKS Integration Points

**IRSA per tenant:** Each tenant namespace has its own Kubernetes ServiceAccount with an IAM role that grants access only to that tenant's S3 bucket and DynamoDB table. No tenant can access another tenant's AWS resources.

**Fargate for batch jobs:** Each tenant can trigger data export jobs. These run in a Fargate profile (`batch-jobs` namespace) — zero node management, complete isolation, billed per second.

**ALB multi-host Ingress:** A single ALB with host-based routing serves all 200 tenants. The AWS Load Balancer Controller reconciles the Ingress across all tenant namespaces into a single ALB listener with 200 routing rules.

**CloudWatch log groups per namespace:** Fluent Bit routes logs from each tenant namespace to a dedicated CloudWatch log group (`/eks/production/tenant-a`, `/eks/production/tenant-b`), providing per-tenant log isolation for compliance.

### Results

| Metric | Before (VMs) | After (EKS) |
|---|---|---|
| Operational overhead per new tenant | 4 hours | 8 minutes (Helm chart apply) |
| Infra cost per tenant per month | $340 (2 VMs) | $85 (shared node pool) |
| Tenant onboarding time | 1 business day | < 15 minutes |
| P99 API latency | 420ms | 95ms |
| Uptime (rolling 90 days) | 99.6% | 99.97% |

---

## 10. Common Pitfalls & Best Practices

### Pitfall 1: Exhausting VPC IP Space
The single most common EKS operational crisis is running out of IP addresses. A team provisions a `/24` subnet (254 IPs) for an EKS node group expecting 10 nodes with 20 Pods each — but immediately runs out. **Plan for peak Pod count plus 25% headroom. Use `/19` or larger subnets per AZ dedicated to EKS worker nodes.** Enable prefix delegation (`ENABLE_PREFIX_DELEGATION=true`) on the VPC CNI to get 16x more IPs per ENI attachment.

### Pitfall 2: Using EC2 Instance Role Instead of IRSA
Attaching IAM policies to the EC2 node role gives every Pod on every node those permissions. One compromised Pod gets access to your entire S3 bucket, all DynamoDB tables, and any other resource the node role can reach. **Use IRSA for every workload that needs AWS API access.** The node role should have only the minimum policies required for node operation (ECR read, EBS CSI, VPC CNI).

### Pitfall 3: Not Restricting API Server Public Access
By default, the EKS API server endpoint is public and reachable from any IP. Combined with a misconfigured RBAC or a leaked `kubeconfig`, this is a direct cluster compromise path. **Restrict `cluster_endpoint_public_access_cidrs` to your corporate NAT IPs or VPN egress, or disable public access entirely and use a VPN or AWS Direct Connect.**

### Pitfall 4: Skipping PodDisruptionBudgets with Managed Node Groups
EKS managed node group upgrades respect PodDisruptionBudgets — but only if they are configured. Without PDBs, a node upgrade can drain all Pods of a deployment simultaneously, causing downtime. **Define PDBs for every production Deployment before enabling automated node upgrades.**

### Pitfall 5: ALB Target Type `instance` vs `ip`
Using `target-type: instance` routes traffic to the NodePort of each node, adding a hop and disabling connection draining at the Pod level. **Use `target-type: ip` for all new ALB configurations.** It routes directly to Pod IPs, enables per-Pod health checks, and works correctly with VPC CNI security groups for Pods.

### Pitfall 6: Forgetting to Tag Subnets for the Load Balancer Controller
The AWS Load Balancer Controller discovers subnets by tag. Without the correct tags (`kubernetes.io/role/elb=1` for public subnets, `kubernetes.io/role/internal-elb=1` for private), the controller cannot provision ALBs and the Ingress remains in a perpetual pending state. **Apply subnet tags before deploying the controller.**

> **EKS Production Readiness Checklist**
> - [ ] Dedicated `/19`+ private subnets per AZ for EKS nodes
> - [ ] Subnet tags applied for ELB discovery
> - [ ] OIDC provider enabled; all workloads use IRSA (no static IAM keys)
> - [ ] API server public access restricted to known CIDRs or disabled
> - [ ] Managed node groups use `AL2023` or Bottlerocket AMIs
> - [ ] Node group Cluster Autoscaler tags applied
> - [ ] EBS CSI driver installed with `reclaimPolicy: Retain` StorageClasses
> - [ ] AWS Load Balancer Controller installed with `target-type: ip`
> - [ ] ACM certificates provisioned and attached to ALB Ingress
> - [ ] CloudWatch Container Insights enabled with 30-day log retention
> - [ ] CloudWatch alarms on node CPU, memory, Pod failures
> - [ ] PodDisruptionBudgets on all production Deployments
> - [ ] Control plane logging enabled for all five log types
> - [ ] EKS cluster version within 2 minor versions of latest

---

## 11. Key Takeaways

1. **EKS offloads the hardest part of Kubernetes operations — control plane management.** AWS handles etcd, API server availability, control plane patching, and cross-AZ redundancy. Your operational focus shifts to the data plane: nodes, networking, storage, and workloads.

2. **VPC CNI makes EKS networking both simpler and more constrained than overlay networks.** Pods get real VPC IPs — routing is native, latency is lower, and security groups work at the Pod level. The constraint is subnet capacity: plan `/19` or larger per AZ, and enable prefix delegation for high-density clusters.

3. **IRSA is the cornerstone of EKS security.** It eliminates the need for static AWS credentials anywhere in the cluster. Every workload that calls an AWS API should have its own Service Account with its own IRSA role with the minimum required permissions. The node instance role should be nearly empty.

4. **EKS Add-ons simplify lifecycle management for cluster components.** The VPC CNI, EBS CSI driver, CoreDNS, and kube-proxy are installed, updated, and version-tested by AWS through the add-on API. Use add-ons rather than self-managed Helm charts for these components.

5. **The AWS Load Balancer Controller bridges Kubernetes and AWS networking.** ALB Ingress with `target-type: ip` provides native integration between Kubernetes Services and AWS load balancers — including WAF, ACM certificate termination, access logging, and host-based routing — without any extra proxying layer.

6. **Terraform + the `terraform-aws-eks` module is the production standard for EKS cluster provisioning.** It manages the full dependency graph — VPC, subnets, IAM roles, IRSA associations, node groups, and add-ons — in a version-controlled, reviewable, reproducible way that `eksctl` (while excellent for prototyping) cannot match at scale.

---

## 12. Exercises & Labs

**Exercise 1: Cluster Provisioning with eksctl**
Using the `ClusterConfig` from Section 3.2 as a base, provision a development EKS cluster with one managed node group (`t3.medium`, 2-5 nodes). Verify: (a) all system Pods are running, (b) the OIDC provider was created (`aws iam list-open-id-connect-providers`), (c) the EBS CSI add-on is functional by creating a `PersistentVolumeClaim` and mounting it in a Pod. After validation, delete the cluster with `eksctl delete cluster` to avoid unnecessary costs.

**Exercise 2: IRSA End-to-End**
Create an S3 bucket and a KMS key. Write an IAM policy granting `s3:PutObject` to the bucket. Create an IRSA role using `eksctl create iamserviceaccount`. Deploy a Pod using that ServiceAccount and verify it can write to S3 without any credentials configured. Then deploy a second Pod without the ServiceAccount and verify the S3 write is denied. Document the exact error message for the denied access attempt.

**Exercise 3: ALB Ingress with TLS**
Install the AWS Load Balancer Controller on your cluster. Request an ACM certificate for a test domain you control (or use a self-signed cert). Deploy two Services (`app-a` and `app-b`). Create an ALB Ingress with host-based routing: `app-a.yourdomain.com` → `app-a`, `app-b.yourdomain.com` → `app-b`. Configure TLS termination at the ALB. Verify both paths work and HTTP redirects to HTTPS.

**Exercise 4: Fargate Profile**
Create a Fargate profile for the `batch-jobs` namespace. Deploy a Kubernetes `Job` in that namespace and observe it running on Fargate (node names will start with `fargate-`). Compare the Pod startup time with a Pod on a managed node group. Attempt to deploy a `DaemonSet` in the `batch-jobs` namespace and document why it fails.

**Exercise 5: CloudWatch Insights Query**
Enable CloudWatch Container Insights on your cluster. Generate some application logs from a running Pod (`kubectl exec <pod> -- sh -c "for i in $(seq 1 100); do echo 'test log line $i'; done"`). Navigate to CloudWatch Logs Insights and write queries to: (a) count log lines per container in the last hour, (b) find any log lines containing the word "error", (c) chart the log volume over time per namespace. Export one query as a CloudWatch dashboard widget.

---

*End of Chapter 5*

**Next → Chapter 6: Azure Kubernetes Service (AKS)**
