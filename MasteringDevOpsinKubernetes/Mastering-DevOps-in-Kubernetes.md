# Mastering DevOps in Kubernetes

> *A comprehensive, practitioner-focused guide to designing, deploying,
> and operating production-grade Kubernetes environments across cloud
> and on-premise infrastructure.*

---

|  |  |
|---|---|
| **Edition** | First Edition |
| **Kubernetes version** | v1.29 + |
| **Authors** | Platform Engineering Team |
| **Chapters** | 13 |
| **Total pages** | ~700 |

---

> **About this book**
>
> *Mastering DevOps in Kubernetes* takes you from first principles to
> production mastery. Starting with DevOps philosophy and container
> fundamentals, you will build real clusters with kubeadm, deploy to
> all three major cloud providers (AWS EKS, Azure AKS, Google GKE),
> harden them with security best practices, instrument them with a full
> observability stack, and deliver software through GitOps pipelines and
> progressive delivery. The final chapter ties everything together with
> Istio service mesh — mTLS, traffic management, and chaos engineering
> for a fully observable, zero-trust microservices platform.
>
> Every chapter includes architecture diagrams, production-grade YAML
> manifests, real-world scenarios, common pitfalls, and hands-on lab
> exercises compatible with Kubernetes v1.29+.

---

*© Mastering DevOps in Kubernetes. All rights reserved.*


# Table of Contents

| Chapter | Title | Topics |
|---|---|---|
| 1 | [DevOps for Kubernetes](#devops-for-kubernetes) | Philosophy · GitOps · 12-Factor · Toolchain |
| 2 | [Container Management with Docker](#container-management-with-docker) | Images · Multi-stage Builds · Registries · CRI |
| 3 | [Speeding Up with Standard Kubernetes Operations](#speeding-up-with-standard-kubernetes-operations) | Pods · Deployments · Services · HPA · kubectl |
| 4 | [Stateful Workloads in Kubernetes](#stateful-workloads-in-kubernetes) | StatefulSets · PVCs · StorageClasses · PostgreSQL · Kafka |
| 5 | [Amazon Elastic Kubernetes Service](#amazon-elastic-kubernetes-service) | EKS · VPC CNI · IRSA · ALB Controller · CloudWatch |
| 6 | [Azure Kubernetes Service](#azure-kubernetes-service) | AKS · Azure CNI · Workload Identity · KEDA · Azure DevOps |
| 7 | [Google Kubernetes Engine](#google-kubernetes-engine) | GKE · Autopilot · Dataplane V2 · Cloud Armor · Cloud Build |
| 8 | [Kubernetes Administrator](#kubernetes-administrator) | kubeadm · etcd · Certificates · RBAC · Admission Controllers · Troubleshooting |
| 9 | [Kubernetes Security](#kubernetes-security) | 4Cs · PSA · NetworkPolicy · Vault · Trivy · Falco · CIS Benchmarks |
| 10 | [Monitoring in Kubernetes](#monitoring-in-kubernetes) | Prometheus · Grafana · Loki · Tempo · Alertmanager · SLOs |
| 11 | [Packaging and Deploying in Kubernetes](#packaging-and-deploying-in-kubernetes) | Helm · Kustomize · OCI Registries · Argo CD · Flux CD |
| 12 | [Continuous Development and Continuous Deployment](#continuous-development-and-continuous-deployment) | GitHub Actions · Jenkins X · Security Gates · Argo Rollouts |
| 13 | [Managing Microservices Using Istio Service Mesh](#managing-microservices-using-istio-service-mesh) | Architecture · mTLS · Traffic Management · Chaos · Multi-Cluster |


---


---

──────────────────────────────────────────────────────────────────────

## Part I: DevOps for Kubernetes

> *Philosophy · GitOps · 12-Factor · Toolchain*

──────────────────────────────────────────────────────────────────────


## 1. Introduction & Learning Objectives

The way we build, ship, and operate software has undergone a fundamental transformation over the last decade. At the center of that transformation stands Kubernetes — the open-source container orchestration platform that has become the de facto operating system of the cloud-native world.

But Kubernetes is not just infrastructure. It is a philosophy made manifest in configuration files, a culture of collaboration encoded in YAML. To wield it effectively, you must first understand DevOps — the set of cultural practices, organizational patterns, and technical workflows that Kubernetes was designed to accelerate.

This chapter builds the conceptual foundation for the entire book. We will trace the evolution from monolithic architectures to containerized microservices, unpack the core tenets of DevOps, and show precisely how Kubernetes embodies each one. By the time you finish this chapter, you will understand not just what Kubernetes does, but why it exists.

> **Learning Objectives**
> - Understand the DevOps philosophy and the cultural shifts it demands.
> - Trace the architectural evolution from monoliths to containers to orchestration.
> - Explain how Kubernetes maps to each pillar of DevOps practice.
> - Apply the 12-Factor App methodology to containerized workloads.
> - Understand GitOps and Infrastructure as Code (IaC) as first-class DevOps practices.
> - Position Kubernetes within the modern DevOps toolchain.

---

## 2. Core Concepts

### 2.1 What Is DevOps?

DevOps is not a tool, a role, or a product — it is a cultural and organizational movement aimed at breaking down the walls between software development (Dev) and IT operations (Ops). The term was coined around 2009 by Patrick Debois and Andrew Shafer, and it described a set of practices that had been quietly emerging in high-performing engineering teams at companies like Amazon, Netflix, and Google.

At its core, DevOps is built on five foundational principles:

- **Culture & Collaboration:** Shared responsibility for the entire software delivery lifecycle, from code commit to production incident. No more throwing code "over the wall" to operations.
- **Lean & Flow:** Eliminate waste in the delivery pipeline. Small, frequent releases beat infrequent, massive deployments. Measure cycle time — the time from idea to production value.
- **Measurement & Feedback:** Instrument everything. Define Service Level Objectives (SLOs), track deployment frequency, lead time, mean time to recovery (MTTR), and change failure rate. Data, not opinion, drives decisions.
- **Automation:** Automate repetitive, error-prone human tasks: testing, building, provisioning, deploying, monitoring. Automation is the force multiplier that lets small teams move at scale.
- **Continuous Improvement:** Run blameless postmortems. Build learning loops. Treat every failure as a system improvement opportunity, not a human failure.

These principles are often quantified using the **DORA Four Key Metrics**:

| Metric | What It Measures |
|---|---|
| Deployment Frequency | How often code is deployed to production |
| Lead Time for Changes | Time from code commit to production release |
| Mean Time to Recovery (MTTR) | How fast you recover from production failures |
| Change Failure Rate | % of deployments that cause a production incident |

---

### 2.2 From Monoliths to Containers: A Brief History

#### The Monolithic Era (2000s)

In the early 2000s, the dominant architecture was the monolith: a single deployable unit containing all application functionality — presentation layer, business logic, and data access — compiled and deployed together. A Java EAR file. A Rails app on a single server. A .NET solution deployed to IIS.

Monoliths are not inherently bad. For small teams and small codebases, they are simple, easy to develop, and straightforward to debug. The problems emerge at scale:

- A single bug in one module can bring down the entire application.
- Scaling requires replicating the entire monolith, even if only one component is under load.
- Deploying any change requires deploying everything, increasing blast radius and deployment fear.
- Technology choices are locked in — changing the database or programming language affects the entire system.
- Teams become tightly coupled, with merge conflicts and coordination overhead dominating engineering time.

#### The Virtual Machine Era (2005–2012)

The advent of cloud computing and hypervisors (VMware, Xen, KVM) brought relief through isolation. Teams could provision a Virtual Machine (VM) per application, achieving separation of concerns at the infrastructure level. Tools like Chef, Puppet, and Ansible automated VM configuration.

But VMs carry significant overhead. Each VM includes a full operating system kernel, hundreds of megabytes of libraries, and a hypervisor tax on CPU and memory. Provisioning a new VM takes minutes. Running 50 application instances meant running 50 full operating systems.

#### The Container Revolution (2013–2016)

In March 2013, Solomon Hykes demonstrated Docker at PyCon. Within 18 months, Docker had transformed how the industry thought about application packaging. Containers offered:

- Process isolation without the overhead of a full OS kernel (containers share the host kernel via Linux namespaces and cgroups).
- Immutable, portable artifacts: build once, run anywhere. The container image is the deployment unit.
- Startup times measured in milliseconds, not minutes.
- Dramatically higher density: a host running 5 VMs could run 50 or 500 containers.

Containers solved the packaging and isolation problem. But they created a new one: once you have hundreds of containers across dozens of hosts, how do you schedule them, network them, recover from failures, roll out updates, and scale them? You need an orchestrator.

#### The Orchestration Era (2014–Present)

Google had been running containers at massive scale internally since 2003, using a system called Borg. In 2014, they open-sourced a redesigned version called Kubernetes (from the Greek for "helmsman" or "pilot"), donating it to the Cloud Native Computing Foundation (CNCF) in 2016.

```
MONOLITH:
  [ Browser ] --> [ Load Balancer ] --> [ App Server (all-in-one) ] --> [ Single DB ]
  Deploy: entire application restarts. Scale: entire application scales.

MICROSERVICES ON KUBERNETES:
  [ Browser ] --> [ Ingress Controller ]
       |--> [ User Service Pod x3 ]      --> [ Users DB (StatefulSet) ]
       |--> [ Order Service Pod x5 ]     --> [ Orders DB (StatefulSet) ]
       |--> [ Payment Service Pod x2 ]   --> [ External Payment API ]
       |--> [ Notification Service Pod ] --> [ Message Queue ]
  Each service: independent deploy, independent scale, independent tech stack.
```

---

### 2.3 Kubernetes Architecture Overview

Kubernetes organizes compute resources into a cluster composed of a control plane and worker nodes.

| Component | Location | Responsibility |
|---|---|---|
| `kube-apiserver` | Control Plane | The cluster's single source of truth; all kubectl commands hit this REST API |
| `etcd` | Control Plane | Distributed key-value store holding all cluster state |
| `kube-scheduler` | Control Plane | Assigns Pods to Nodes based on resource availability and constraints |
| `kube-controller-manager` | Control Plane | Runs control loops: ReplicaSet, Deployment, Node controllers, etc. |
| `cloud-controller-manager` | Control Plane | Integrates with cloud provider APIs (AWS, Azure, GCP) |
| `kubelet` | Worker Node | Agent that ensures containers run as specified by Pod specs |
| `kube-proxy` | Worker Node | Maintains network rules for Service routing |
| Container Runtime | Worker Node | Runs containers (containerd, CRI-O) |

The API server is the heart of the system. Everything in Kubernetes — whether you run `kubectl apply`, a CI/CD pipeline triggers a deployment, or an autoscaler adjusts replica counts — goes through the API server. This design choice is not accidental: it creates a single, auditable, role-protected gate through which all cluster changes flow. That is DevOps thinking at the architectural level.

---

### 2.4 The 12-Factor App Methodology

Before Kubernetes existed, Heroku engineers codified best practices for building modern, scalable, maintainable web applications in the **12-Factor App methodology** (2012). Kubernetes was designed, consciously or not, to enforce and reward 12-factor compliance.

| Factor | Kubernetes Implementation |
|---|---|
| I. Codebase — one codebase, one repo | Each microservice has its own repo, container image, and Deployment |
| II. Dependencies — explicitly declared | Dockerfile declares all dependencies; no host-level library assumptions |
| III. Config — stored in environment | ConfigMaps and Secrets inject config at runtime; no config in images |
| IV. Backing services — treated as attached resources | Services are DNS-addressed resources; swap a DB by changing a ConfigMap |
| V. Build, release, run — strictly separated | CI builds image; CD creates Release (image tag + config); kubelet runs Pods |
| VI. Processes — stateless, share-nothing | Pods are ephemeral; stateful data lives in PVCs or external services |
| VII. Port binding — export via port | Containers expose ports; Kubernetes Services provide stable endpoints |
| VIII. Concurrency — scale via process model | HPA adds Pod replicas; no threading hacks required |
| IX. Disposability — fast startup, graceful shutdown | SIGTERM handling, preStop hooks, liveness/readiness probes enforce this |
| X. Dev/prod parity | Same container image runs in dev (minikube) and prod (EKS/GKE/AKS) |
| XI. Logs — treat as event streams | Pods write to stdout; log collectors (Fluentd, Loki) aggregate centrally |
| XII. Admin processes — one-off tasks | `kubectl exec`, Job, and CronJob resources handle admin tasks cleanly |

> **Production Tip — Factor III (Config)**
> Teams frequently bake environment-specific configuration into container images, creating separate images for dev, staging, and prod. This violates the "build once, run anywhere" principle. The correct pattern: build one image, inject all environment differences via ConfigMaps and Secrets at Pod creation time.

---

### 2.5 GitOps — Git as the Source of Truth

GitOps is an operational framework that applies DevOps best practices — version control, collaboration, compliance, CI/CD — to infrastructure automation. The term was coined by Alexis Richardson of Weaveworks in 2017.

#### Core GitOps Principles

1. **Declarative:** The entire system is described declaratively. Kubernetes YAML manifests, Helm charts, and Kustomize overlays are GitOps-native.
2. **Versioned and Immutable:** The desired state is stored in Git, providing a versioned, immutable history of every cluster change. `git log` is your audit trail.
3. **Pulled Automatically:** Software agents (Argo CD, Flux CD) continuously reconcile the live cluster state with the desired state in Git. You do not push deployments — agents pull them.
4. **Continuously Reconciled:** If the live state drifts from the desired state, the GitOps agent detects the drift and corrects it automatically.

```
GitOps Flow with Argo CD:

Developer         CI Pipeline         Git Repository      Argo CD          Kubernetes
    |                  |                    |                 |                 |
    |--- git push ---> |                    |                 |                 |
    |                  |--- run tests ----> |                 |                 |
    |                  |--- build image --> |                 |                 |
    |                  |--- update tag ---> [main branch] --> |                 |
    |                  |                   |  <-- poll/webhook                  |
    |                  |                   |                 |-- diff live --> |
    |                  |                   |                 |-- apply ------> |
    |                  |                   |                 |<-- sync status  |
```

| Traditional CI/CD (Push) | GitOps (Pull) |
|---|---|
| Pipeline has cluster credentials | Cluster agent has Git credentials only |
| Drift is invisible until next deploy | Drift is detected and auto-corrected |
| Rollback means re-running old pipeline | Rollback is `git revert` + auto-reconcile |
| Audit trail lives in CI pipeline logs | Audit trail is immutable Git history |
| Cluster state is tribal knowledge | Cluster state is documented in Git |

---

### 2.6 Infrastructure as Code (IaC)

Infrastructure as Code is the practice of provisioning and managing infrastructure through machine-readable configuration files rather than through manual processes or interactive tools.

In the Kubernetes ecosystem, IaC operates at two levels:

- **Cluster Provisioning Layer:** Tools like Terraform, Pulumi, `eksctl`, and cloud provider CLIs provision the Kubernetes cluster itself — the control plane, worker node groups, VPCs, IAM roles, and managed services.
- **Workload Configuration Layer:** Kubernetes YAML manifests, Helm charts, and Kustomize overlays define what runs inside the cluster. This is the most common form of IaC that application engineers interact with daily.

A minimal IaC stack for a production Kubernetes environment:

```
infrastructure/
├── terraform/                     # Cluster provisioning (EKS/AKS/GKE)
│   ├── main.tf                    # Cluster definition
│   ├── variables.tf               # Environment-specific inputs
│   └── outputs.tf                 # Exported values (cluster endpoint, etc.)
├── helm/                          # Application packaging
│   └── myapp/
│       ├── Chart.yaml
│       ├── values.yaml            # Default values
│       ├── values-staging.yaml    # Staging overrides
│       └── templates/
│           ├── deployment.yaml
│           ├── service.yaml
│           └── ingress.yaml
└── argocd/                        # GitOps applications
    └── apps/
        ├── staging-app.yaml
        └── production-app.yaml
```

---

### 2.7 Kubernetes and the DevOps Toolchain

| Category | Tools | Role in DevOps |
|---|---|---|
| Source Control | GitHub, GitLab, Bitbucket | Single source of truth for code and configuration |
| CI (Build & Test) | GitHub Actions, GitLab CI, Jenkins, Tekton | Build container images, run tests, push to registry |
| Container Registry | ECR, GCR, ACR, Docker Hub, Harbor | Store and version container images |
| CD / GitOps | Argo CD, Flux CD, Spinnaker | Sync Git state to cluster; handle promotions |
| Infrastructure as Code | Terraform, Pulumi, Crossplane | Provision cloud resources and cluster infrastructure |
| Secret Management | HashiCorp Vault, AWS Secrets Manager, Sealed Secrets | Inject secrets securely at runtime |
| Observability | Prometheus, Grafana, Loki, Jaeger | Metrics, logs, and traces for running workloads |
| Policy & Security | OPA/Gatekeeper, Kyverno, Falco | Enforce compliance; detect runtime threats |
| Service Mesh | Istio, Linkerd, Cilium | mTLS, traffic management, observability for services |
| Developer Experience | Telepresence, Skaffold, Tilt, DevSpace | Local Kubernetes development and hot-reloading |

---

## 3. Step-by-Step Hands-on Walkthrough

### 3.1 Prerequisites

For this chapter's exercises you need the following tools installed locally. All examples are compatible with Kubernetes v1.29+.

```bash
# Install kubectl (macOS via Homebrew)
brew install kubectl

# Install kubectl (Linux)
curl -LO "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/

# Install minikube (local single-node cluster)
brew install minikube            # macOS
# OR
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Verify versions
kubectl version --client         # Should show v1.29+
minikube version                 # Should show v1.32+
```

---

### 3.2 Your First Kubernetes Cluster

Start a local Kubernetes cluster using minikube:

```bash
# Start minikube with 4 CPUs and 8GB RAM
minikube start --cpus=4 --memory=8192 --kubernetes-version=v1.29.0

# Verify the cluster is running
kubectl cluster-info
# Expected output:
# Kubernetes control plane is running at https://192.168.49.2:8443
# CoreDNS is running at https://192.168.49.2:8443/api/v1/...

# Inspect nodes
kubectl get nodes -o wide
# NAME       STATUS   ROLES           AGE   VERSION
# minikube   Ready    control-plane   2m    v1.29.0
```

---

### 3.3 Deploying a 12-Factor Application

#### Step 1: Create the Namespace

```bash
kubectl create namespace devops-demo

# Set as the default namespace for this session
kubectl config set-context --current --namespace=devops-demo
```

#### Step 2: ConfigMap — Externalised Configuration (Factor III)

```yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: demo-config
  namespace: devops-demo
  labels:
    app: demo-web
    environment: development
data:
  APP_ENV: "development"           # Non-sensitive config as plain key-value
  LOG_LEVEL: "info"
  MAX_CONNECTIONS: "100"
  APP_PORT: "8080"
```

#### Step 3: Secret — Sensitive Configuration

```yaml
# secret.yaml
# NOTE: base64 encoding is NOT encryption. Use Sealed Secrets or Vault in production.
# echo -n 'my-db-password' | base64  ->  bXktZGItcGFzc3dvcmQ=
apiVersion: v1
kind: Secret
metadata:
  name: demo-secret
  namespace: devops-demo
type: Opaque
data:
  DB_PASSWORD: bXktZGItcGFzc3dvcmQ=   # base64 encoded value
  API_KEY: c2VjcmV0LWFwaS1rZXk=        # base64 encoded value
```

#### Step 4: Deployment — Stateless Pods

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-web
  namespace: devops-demo
  labels:
    app: demo-web
spec:
  replicas: 3                           # Factor VIII: horizontal scaling
  selector:
    matchLabels:
      app: demo-web                     # Must match template labels
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1                       # Allow 1 extra Pod during update
      maxUnavailable: 0                 # Never reduce below desired count
  template:
    metadata:
      labels:
        app: demo-web
        version: "1.0.0"
    spec:
      containers:
        - name: web
          image: nginx:1.25-alpine       # Immutable, version-pinned image
          ports:
            - containerPort: 80
          envFrom:
            - configMapRef:
                name: demo-config        # Inject all ConfigMap keys as env vars
          env:
            - name: DB_PASSWORD          # Inject individual Secret key
              valueFrom:
                secretKeyRef:
                  name: demo-secret
                  key: DB_PASSWORD
          resources:
            requests:
              memory: "64Mi"            # Scheduler uses requests for placement
              cpu: "100m"               # 100 millicores = 0.1 CPU
            limits:
              memory: "128Mi"           # OOM killer triggers above this
              cpu: "200m"
          readinessProbe:               # Only route traffic when app is ready
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 5
            periodSeconds: 10
          livenessProbe:                # Restart Pod if health check fails
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 15
            periodSeconds: 20
          lifecycle:
            preStop:                    # Factor IX: graceful shutdown
              exec:
                command: ["/bin/sh", "-c", "sleep 5"]
```

#### Step 5: Service — Stable Network Endpoint

```yaml
# service.yaml
apiVersion: v1
kind: Service
metadata:
  name: demo-web-svc
  namespace: devops-demo
spec:
  selector:
    app: demo-web                  # Routes to all Pods with this label
  ports:
    - protocol: TCP
      port: 80                     # Service port (cluster-internal)
      targetPort: 80               # Container port
  type: ClusterIP                  # Internal only; use LoadBalancer for external
```

#### Step 6: Apply All Manifests

```bash
# Apply in dependency order
kubectl apply -f configmap.yaml
kubectl apply -f secret.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml

# Watch Pod rollout
kubectl rollout status deployment/demo-web
# Waiting for deployment "demo-web" rollout to finish: 0 of 3 updated replicas are available...
# deployment "demo-web" successfully rolled out

# Verify running Pods
kubectl get pods -o wide
# NAME                        READY   STATUS    RESTARTS   AGE   IP
# demo-web-7d9b6c8b5f-4xk9p   1/1     Running   0          30s   172.17.0.4
# demo-web-7d9b6c8b5f-8vr2q   1/1     Running   0          30s   172.17.0.5
# demo-web-7d9b6c8b5f-m9t7n   1/1     Running   0          30s   172.17.0.6

# Port-forward to test locally
kubectl port-forward svc/demo-web-svc 8080:80
curl http://localhost:8080          # Should return nginx default page
```

---

### 3.4 Simulating GitOps: Rolling Update via Manifest Change

In a GitOps workflow, you never `kubectl set image` directly. You update the manifest in Git and let the agent reconcile. Simulate this workflow manually:

```bash
# Step 1: Update the image tag in deployment.yaml
# Change:  image: nginx:1.25-alpine
# To:      image: nginx:1.27-alpine

# Step 2: Apply the updated manifest (simulating GitOps reconciliation)
kubectl apply -f deployment.yaml

# Step 3: Watch the rolling update
kubectl rollout status deployment/demo-web --watch

# Step 4: Verify the new image is running
kubectl describe pod -l app=demo-web | grep Image:
# Image: nginx:1.27-alpine

# Step 5: If something goes wrong — rollback
kubectl rollout undo deployment/demo-web
kubectl rollout history deployment/demo-web
```

---

## 4. Real-World Scenario: E-Commerce Platform Migration

### The Problem

RetailCo's application is a classic Java EE monolith deployed to on-premise application servers. Pain points:

- Holiday peak traffic (10x normal load) requires manual VM provisioning two weeks in advance.
- Deployments take 45 minutes and require a maintenance window, limiting releases to bi-weekly.
- A memory leak in the recommendation engine module brings down the entire checkout service.
- The dev environment diverges from production within days, causing weekly "works on my machine" incidents.
- Infrastructure changes are undocumented tribal knowledge held by two senior engineers.

### The DevOps + Kubernetes Solution

Over 18 months, the team executed a phased migration:

1. **Containerization:** Decompose the monolith into 8 microservices (User, Product Catalog, Inventory, Cart, Order, Payment, Notification, Recommendation). Each gets a Dockerfile, a container image, and a Kubernetes Deployment.
2. **IaC Foundation:** Provision an EKS cluster using Terraform. All VPCs, IAM roles, node groups, and managed services are defined in code, reviewed via pull requests, and stored in Git.
3. **GitOps Adoption:** Deploy Argo CD to the cluster. All application deployments and cluster configuration changes flow through Git. Manual `kubectl apply` is prohibited in production.
4. **Observability Stack:** Deploy Prometheus + Grafana for metrics, Loki for logs, and Jaeger for distributed tracing. Define SLOs for checkout (99.9% success rate) and payment (99.95%).
5. **Autoscaling:** Configure HPA on the Order and Product Catalog services. During the next holiday peak, the cluster autoscaler adds nodes automatically within 4 minutes.

### Results After 12 Months

| Metric | Before Kubernetes | After Kubernetes + GitOps |
|---|---|---|
| Deployment frequency | Bi-weekly | Multiple per day |
| Lead time for changes | 3 weeks | 2 hours |
| MTTR | 4 hours | 12 minutes |
| Holiday provisioning | 2 weeks manual | 4 minutes automated |
| Dev/prod parity incidents | Weekly | Near zero |

---

## 5. Common Pitfalls & Best Practices

### Pitfall 1: Lifting and Shifting Monoliths into Containers
Containerizing a monolith without decomposing it gives you the worst of both worlds: the operational overhead of Kubernetes without the resilience and scalability benefits. Before containerizing, identify bounded contexts and decompose at least 2–3 core services. Run the monolith as a single large Pod as a temporary migration step only.

### Pitfall 2: Using `latest` Image Tags
Deploying with `image: myapp:latest` means every Pod restart may pull a different image version, making your deployments non-deterministic and your rollbacks unreliable. Always pin image tags to immutable digests or semantic version tags in production: `image: myapp:1.4.2` or `image: myapp@sha256:<digest>`.

### Pitfall 3: Missing Resource Requests and Limits
Pods without resource requests are scheduled by the kube-scheduler with no information about their actual needs, leading to overcommitted nodes and cascading OOM kills. Always set both `requests` (for scheduling) and `limits` (for isolation) on every container.

### Pitfall 4: Storing Secrets in ConfigMaps
ConfigMaps are stored in etcd unencrypted and visible to anyone with namespace read access. Never put passwords, API keys, or TLS certificates in ConfigMaps. Use the `Secret` type, and in production environments, use Sealed Secrets, External Secrets Operator, or HashiCorp Vault.

### Pitfall 5: Treating Kubernetes as a Black Box
Teams that adopt Kubernetes without understanding its internals are consistently surprised by evictions, node pressure, Pod scheduling failures, and networking issues. `kubectl describe`, `kubectl events`, and `kubectl logs` are your first-line diagnostic tools — learn them deeply.

> **Production Best Practice Checklist**
> - [ ] Pin all image tags to exact versions or SHA digests
> - [ ] Set resource requests and limits on every container
> - [ ] Configure readiness and liveness probes on every container
> - [ ] Store all configuration in ConfigMaps; secrets in Secret objects (or Vault)
> - [ ] Use namespaces to isolate environments and teams
> - [ ] Enable RBAC and apply least-privilege service accounts
> - [ ] All changes flow through Git; no direct `kubectl apply` in production
> - [ ] Define PodDisruptionBudgets for critical services
> - [ ] Set up cluster and namespace resource quotas
> - [ ] Instrument all services with `/health/ready` and `/health/live` endpoints

---

## 6. Key Takeaways

1. **DevOps is a cultural philosophy** — not a tool — centered on collaboration, automation, measurement, and continuous improvement. Kubernetes is infrastructure that embodies these principles.

2. **The architectural evolution** from monoliths → VMs → containers → Kubernetes was driven by the need for faster, safer, more resource-efficient deployments. Each generation solved the packaging and isolation problem of the previous one.

3. **The 12-Factor App methodology** provides a concrete blueprint for building applications that run well on Kubernetes. Factors III (Config), VI (Stateless Processes), IX (Disposability), and XI (Logs) are the most important to get right.

4. **GitOps applies version control discipline** to Kubernetes deployments. Git is the single source of truth; agents continuously reconcile live state with desired state; rollbacks are `git revert`; the audit trail is `git log`.

5. **Infrastructure as Code** at both the cluster provisioning layer (Terraform) and the workload layer (Helm, Kustomize) is essential for reproducibility, auditability, and operational confidence.

6. **Kubernetes is the orchestration layer** at the center of a cloud-native toolchain. Understanding where each tool fits — CI, CD, registry, secrets, observability, service mesh — is as important as knowing Kubernetes itself.

---

## 7. Exercises & Labs

**Exercise 1: Deploy a Multi-Tier Application**
Using only YAML manifests (no Helm), deploy a two-tier application consisting of an nginx frontend and a simple backend API (use `kennethreitz/httpbin` as the backend image). Create separate Deployments, Services, and a ConfigMap that the frontend uses to locate the backend service URL. Verify end-to-end connectivity using `kubectl port-forward` and `curl`.

**Exercise 2: 12-Factor Compliance Audit**
Take an existing application you know (or use a public GitHub repository) and audit it against the 12-Factor methodology. For each factor, classify the application as Compliant, Partially Compliant, or Non-Compliant and document what changes would be required to achieve full compliance on Kubernetes.

**Exercise 3: Simulate GitOps with Git and kubectl**
Create a Git repository containing the YAML manifests from Section 3.3. Simulate a GitOps workflow by: (a) making a change to the ConfigMap in a feature branch, (b) merging it via a pull request, and (c) manually applying the merged state to your minikube cluster. Observe the rolling update. Then practice a rollback using `kubectl rollout undo` and verify the previous configuration is restored.

**Exercise 4: Resource Quota Exploration**
Create a `ResourceQuota` in the `devops-demo` namespace that limits total CPU requests to `500m` and total memory requests to `512Mi`. Then attempt to deploy 10 replicas of the `demo-web` Deployment (each requesting `100m` CPU). Observe what happens. Examine `kubectl describe resourcequota` and explain the eviction and pending Pod behaviour in your own words.

**Exercise 5: DORA Metrics Baseline**
For a software project you are currently working on (or a public open-source project), measure or estimate the four DORA metrics: Deployment Frequency, Lead Time for Changes, MTTR, and Change Failure Rate. Classify the project as Elite, High, Medium, or Low performer using the DORA benchmark thresholds. Write a brief plan (1–2 pages) for how adopting Kubernetes and GitOps could improve the weakest metric.

---

*End of Chapter 1*

**Next → Chapter 2: Container Management with Docker**



---

──────────────────────────────────────────────────────────────────────

## Part II: Container Management with Docker

> *Images · Multi-stage Builds · Registries · CRI*

──────────────────────────────────────────────────────────────────────


## 1. Introduction & Learning Objectives

If Kubernetes is the operating system of the cloud-native world, Docker is the packaging format that made it possible. Every workload you deploy to Kubernetes — every Pod, every Init Container, every sidecar — begins its life as a container image. Understanding how those images are built, optimized, stored, and executed is not optional knowledge for a Kubernetes practitioner. It is the foundation on which everything else rests.

This chapter is a deep, practitioner-focused exploration of Docker and the container ecosystem. We begin with the internals of how Linux containers actually work, build up through Dockerfile authoring and multi-stage build patterns, cover image optimization strategies that directly impact cluster pull latency and security posture, and finish by connecting Docker's concepts to Kubernetes through the Container Runtime Interface (CRI).

By the time you finish this chapter, you will not only be able to write production-grade Dockerfiles — you will understand why they are written the way they are.

> **Learning Objectives**
> - Explain how Linux namespaces and cgroups provide container isolation without a hypervisor.
> - Build, tag, and push container images using Dockerfile best practices.
> - Apply multi-stage build patterns to produce minimal, secure production images.
> - Optimize images for size, layer caching, and security scanning compliance.
> - Use Docker volumes and bind mounts for persistent and shared data.
> - Configure Docker networking for single-host and multi-container communication.
> - Orchestrate multi-service local environments using Docker Compose.
> - Push and pull images from Docker Hub, ECR, GCR, and ACR.
> - Explain how the Container Runtime Interface (CRI) connects Docker concepts to Kubernetes.

---

## 2. Core Concepts

### 2.1 How Linux Containers Actually Work

A common misconception among engineers new to containers is that they are a lightweight version of virtual machines. They are not. Containers are not virtualization — they are isolation. They are regular Linux processes running on the host kernel, constrained and isolated by two Linux kernel features: **namespaces** and **cgroups**.

#### Linux Namespaces

A namespace wraps a global system resource in an abstraction that makes it appear to the processes within the namespace that they have their own isolated instance of that resource. Docker uses six namespaces to create the illusion of an isolated environment:

| Namespace | Isolates | What the Container Sees |
|---|---|---|
| `pid` | Process IDs | Its own PID 1; cannot see host processes |
| `net` | Network interfaces | Its own `eth0`, routing table, and port space |
| `mnt` | Filesystem mount points | Its own root filesystem (the image layers) |
| `uts` | Hostname and domain name | Its own hostname (container ID by default) |
| `ipc` | IPC resources (semaphores, shared memory) | Isolated IPC namespace |
| `user` | User and group IDs | Can map container root to unprivileged host UID |

#### Control Groups (cgroups)

While namespaces provide isolation, cgroups provide **resource enforcement**. They are the mechanism by which Docker (and ultimately Kubernetes) limits how much CPU, memory, network I/O, and disk I/O a container can consume:

```bash
# Inspect the cgroup configuration of a running container
docker run -d --name demo --memory=128m --cpus=0.5 nginx:alpine

# The kernel exposes cgroup limits under:
# /sys/fs/cgroup/memory/docker/<container-id>/memory.limit_in_bytes
# /sys/fs/cgroup/cpu/docker/<container-id>/cpu.cfs_quota_us

docker inspect demo --format '{{.HostConfig.Memory}}'
# 134217728  (128MB in bytes)
```

This maps directly to Kubernetes resource limits. When you write `limits.memory: 128Mi` in a Pod spec, Kubernetes is setting the same underlying cgroup knobs that Docker sets when you pass `--memory=128m`.

#### Union Filesystems and Image Layers

Container images are composed of read-only layers stacked on top of each other using a **union filesystem** (OverlayFS on modern Linux systems). Each instruction in a Dockerfile that modifies the filesystem creates a new layer. When a container runs, a thin writable layer is added on top:

```
┌─────────────────────────────────┐  <- Writable container layer (ephemeral)
├─────────────────────────────────┤  <- RUN npm install (Layer 4)
├─────────────────────────────────┤  <- COPY package.json (Layer 3)
├─────────────────────────────────┤  <- RUN apt-get install (Layer 2)
└─────────────────────────────────┘  <- FROM node:20-alpine (Layer 1, base image)
```

The critical insight: **layers are content-addressed and shared across images**. If ten containers all use `node:20-alpine` as their base, the host only stores that base layer once. This is why image layer caching is so important — both for build speed and for storage efficiency in a Kubernetes node's image cache.

---

### 2.2 Docker Architecture

Docker uses a client-server architecture with three main components:

```
┌──────────────────────────────────────────────────────────────────┐
│  Docker Host                                                      │
│                                                                   │
│  ┌─────────────┐    REST API    ┌──────────────────────────────┐ │
│  │ Docker CLI  │ <-----------> │     dockerd (daemon)          │ │
│  │ (client)    │               │                               │ │
│  └─────────────┘               │  ┌────────────┐  ┌────────┐  │ │
│                                │  │  containerd │  │ Images │  │ │
│  ┌─────────────┐               │  │  (runtime)  │  │ Cache  │  │ │
│  │ Docker      │               │  └──────┬─────┘  └────────┘  │ │
│  │ Compose     │               │         │                     │ │
│  └─────────────┘               │  ┌──────▼─────┐              │ │
│                                │  │  runc       │              │ │
│                                │  │ (OCI runtime)│             │ │
│                                │  └──────┬─────┘              │ │
│                                │         │                     │ │
│                                │  ┌──────▼──────────────────┐ │ │
│                                │  │  Linux Kernel            │ │ │
│                                │  │  (namespaces + cgroups)  │ │ │
│                                │  └─────────────────────────┘ │ │
│                                └──────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
         │
         │  pull/push
         ▼
┌──────────────────┐
│ Container        │
│ Registry         │
│ (Hub/ECR/GCR/ACR)│
└──────────────────┘
```

| Component | Role |
|---|---|
| `docker` CLI | Client that sends commands to the daemon via REST API |
| `dockerd` | Long-running daemon managing images, containers, networks, volumes |
| `containerd` | High-level container runtime; manages container lifecycle |
| `runc` | Low-level OCI-compliant runtime; makes the `clone()` syscalls |
| Container Registry | Remote image store; Docker Hub, ECR, GCR, ACR, Harbor |

> **Important for Kubernetes:** As of Kubernetes 1.24, `dockershim` was removed. Kubernetes no longer uses `dockerd` directly. It communicates with container runtimes via the **Container Runtime Interface (CRI)** — covered in Section 2.9.

---

### 2.3 Images vs. Containers

One of the most important conceptual distinctions in the container world:

| | Image | Container |
|---|---|---|
| **What it is** | Read-only, immutable template | Running (or stopped) instance of an image |
| **Analogy** | Class definition in OOP | Object instance |
| **Storage** | Stored as content-addressed layers on disk | Adds a thin writable layer on top of image layers |
| **Lifecycle** | Created by `docker build`; exists until deleted | Created by `docker run`; ephemeral by design |
| **State** | Stateless — never changes after build | Stateful during runtime; state lost on removal |
| **Portability** | Fully portable — push to registry, pull anywhere | Tied to the host it runs on |

The implications for Kubernetes: a Pod spec references an image. Kubernetes pulls that image to the node and creates a container from it. If the container crashes, Kubernetes creates a new container from the same image — clean slate. Any state that must survive a container restart must be stored outside the container (PersistentVolume, external database, object storage).

---

### 2.4 Dockerfile Deep Dive

A Dockerfile is a text file containing ordered instructions for building a container image. Each instruction that modifies the filesystem creates a new layer. Understanding the performance and security implications of each instruction is essential for writing production-quality Dockerfiles.

#### Dockerfile Instruction Reference

```dockerfile
# FROM — base image (always first; use specific tags, never 'latest')
FROM node:20.11-alpine3.19

# LABEL — image metadata (OCI annotations; useful for automation)
LABEL maintainer="platform-team@company.com" \
      version="1.0.0" \
      description="Demo Node.js API"

# ARG — build-time variables (NOT available at runtime; safe for build secrets)
ARG NODE_ENV=production
ARG BUILD_DATE

# ENV — runtime environment variables (persisted in image; visible to container)
ENV NODE_ENV=${NODE_ENV} \
    PORT=3000 \
    NPM_CONFIG_LOGLEVEL=error

# WORKDIR — sets working directory; creates it if it does not exist
WORKDIR /app

# COPY — preferred over ADD for local files (ADD has URL fetching side effects)
COPY package*.json ./

# RUN — executes a command during build; creates a layer
# Best practice: combine RUN commands with && to minimize layers
RUN npm ci --only=production \
    && npm cache clean --force \
    && rm -rf /tmp/*

# COPY remaining source after installing dependencies (layer cache optimization)
COPY src/ ./src/

# USER — run as non-root (critical for security; required by many K8s policies)
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup && \
    chown -R appuser:appgroup /app
USER appuser

# EXPOSE — documents the port (does not actually publish; informational only)
EXPOSE 3000

# HEALTHCHECK — Docker-level health check (Kubernetes uses probes instead)
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

# CMD vs ENTRYPOINT:
# ENTRYPOINT — the executable that always runs; cannot be overridden by docker run args
# CMD — default arguments to ENTRYPOINT (or the command if no ENTRYPOINT is set)
ENTRYPOINT ["node"]
CMD ["src/server.js"]
```

#### Layer Caching Strategy

Docker rebuilds a layer and all subsequent layers when the layer's input changes. Ordering your instructions to maximize cache reuse is one of the highest-leverage optimizations in Dockerfile authoring:

```dockerfile
# BAD: Copying all source first means ANY code change invalidates the npm install layer
FROM node:20-alpine
WORKDIR /app
COPY . .                        # Cache invalidated on every code change
RUN npm ci                      # Re-runs on every code change — slow

# GOOD: Separate dependency installation from source copying
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./           # Only invalidated when package.json changes
RUN npm ci                      # Cached until dependencies change — fast
COPY src/ ./src/                # Invalidated on code change, but npm ci is cached
```

---

### 2.5 Multi-Stage Builds

Multi-stage builds are the single most impactful Dockerfile technique for producing lean, secure production images. They allow you to use a full build environment (with compilers, build tools, test frameworks) in early stages, then copy only the compiled artifacts into a minimal final image.

#### Why Multi-Stage Builds Matter

| | Without Multi-Stage | With Multi-Stage |
|---|---|---|
| Build tools in production image | Yes | No |
| Source code in production image | Yes | No |
| Typical Node.js image size | 1.2 GB | 85 MB |
| Typical Go binary image size | 1.1 GB | 12 MB |
| Attack surface | Large | Minimal |
| CVE exposure | High | Low |

#### Go Application — Minimal Binary

```dockerfile
# ─── Stage 1: Build ───────────────────────────────────────────────
FROM golang:1.22-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git ca-certificates tzdata

WORKDIR /build

# Cache module downloads separately from source compilation
COPY go.mod go.sum ./
RUN go mod download

# Copy source and compile
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-w -s -X main.version=$(git describe --tags --always)" \
    -o /bin/server \
    ./cmd/server

# ─── Stage 2: Test (optional but recommended) ────────────────────
FROM builder AS tester
RUN go test -v -race -coverprofile=coverage.txt ./...

# ─── Stage 3: Production ─────────────────────────────────────────
# 'scratch' is a completely empty image — no shell, no package manager
# Only the statically compiled binary and required system files
FROM scratch AS production

# Copy CA certificates for HTTPS calls
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
# Copy timezone data
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
# Copy the binary
COPY --from=builder /bin/server /bin/server

# Non-root user in scratch (must use numeric UID — no passwd file)
USER 65534:65534

EXPOSE 8080
ENTRYPOINT ["/bin/server"]
```

#### Node.js Application — Production-Ready

```dockerfile
# ─── Stage 1: Dependencies ────────────────────────────────────────
FROM node:20.11-alpine3.19 AS deps
WORKDIR /app
COPY package*.json ./
# ci is reproducible (uses package-lock.json exactly); only production deps
RUN npm ci --only=production && npm cache clean --force

# ─── Stage 2: Build (TypeScript compile, asset bundling, etc.) ───
FROM node:20.11-alpine3.19 AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci                          # Install ALL deps including devDependencies
COPY tsconfig.json .
COPY src/ ./src/
RUN npm run build                   # Compile TypeScript → dist/

# ─── Stage 3: Test ───────────────────────────────────────────────
FROM builder AS tester
COPY tests/ ./tests/
RUN npm test && npm run lint

# ─── Stage 4: Production ─────────────────────────────────────────
FROM node:20.11-alpine3.19 AS production

# Security hardening
RUN apk add --no-cache dumb-init && \
    addgroup -g 1001 -S nodejs && \
    adduser -S -u 1001 -G nodejs nodejs

WORKDIR /app

# Copy only what production needs
COPY --from=deps --chown=nodejs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nodejs:nodejs /app/dist ./dist
COPY --chown=nodejs:nodejs package.json ./

USER nodejs
EXPOSE 3000

# dumb-init as PID 1: handles SIGTERM properly (Factor IX)
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "dist/server.js"]
```

#### Java / Spring Boot Application

```dockerfile
# ─── Stage 1: Build with Maven ───────────────────────────────────
FROM maven:3.9-eclipse-temurin-21-alpine AS builder
WORKDIR /build

# Cache Maven dependencies — only re-downloaded when pom.xml changes
COPY pom.xml .
RUN mvn dependency:go-offline -B

COPY src/ ./src/
RUN mvn clean package -DskipTests -B

# ─── Stage 2: Extract Spring Boot layers ─────────────────────────
FROM eclipse-temurin:21-jre-alpine AS extractor
WORKDIR /app
COPY --from=builder /build/target/*.jar app.jar
# Spring Boot layertools extracts jar into layers for optimal Docker caching
RUN java -Djarmode=layertools -jar app.jar extract

# ─── Stage 3: Production ─────────────────────────────────────────
FROM eclipse-temurin:21-jre-alpine AS production

RUN addgroup -g 1001 -S spring && adduser -u 1001 -S spring -G spring
WORKDIR /app

# Copy layers in order of change frequency (least → most frequent)
COPY --from=extractor --chown=spring:spring /app/dependencies/ ./
COPY --from=extractor --chown=spring:spring /app/spring-boot-loader/ ./
COPY --from=extractor --chown=spring:spring /app/snapshot-dependencies/ ./
COPY --from=extractor --chown=spring:spring /app/application/ ./

USER spring
EXPOSE 8080

ENTRYPOINT ["java", \
  "-XX:+UseContainerSupport", \
  "-XX:MaxRAMPercentage=75.0", \
  "-Djava.security.egd=file:/dev/./urandom", \
  "org.springframework.boot.loader.JarLauncher"]
```

> **Production Tip — JVM Container Awareness**
> Before JDK 10, the JVM ignored cgroup memory limits and used the host's total RAM to size its heap. A 512Mi container on a 64GB host would default to a 16GB heap and immediately OOM-kill. Always use `-XX:+UseContainerSupport` (default in JDK 11+) and `-XX:MaxRAMPercentage=75.0` to respect the container's memory limit.

---

### 2.6 Image Optimization

Beyond multi-stage builds, several additional techniques reduce image size, improve security posture, and reduce Kubernetes node pull times.

#### Choose the Right Base Image

| Base Image | Size | Use Case |
|---|---|---|
| `ubuntu:24.04` | ~78 MB | General-purpose; full apt ecosystem |
| `debian:bookworm-slim` | ~75 MB | Smaller Debian; good for most compiled apps |
| `alpine:3.19` | ~7 MB | Minimal; musl libc (watch for glibc incompatibilities) |
| `distroless/static` | ~2 MB | No shell, no package manager; compiled binaries only |
| `distroless/base` | ~20 MB | glibc + CA certs; good for Go/Rust binaries |
| `scratch` | 0 MB | Completely empty; statically linked binaries only |

#### .dockerignore — Your First Line of Defence

A missing `.dockerignore` is one of the most common Dockerfile mistakes. Without it, `COPY . .` sends your entire build context — including `.git`, `node_modules`, test fixtures, and local secrets — to the Docker daemon on every build.

```
# .dockerignore
# Version control
.git
.gitignore

# Dependencies (rebuilt inside Docker)
node_modules/
vendor/
target/

# Test artifacts
coverage/
*.test
tests/
__tests__/
spec/

# IDE and OS artifacts
.idea/
.vscode/
.DS_Store
*.swp

# Local environment files (NEVER send to build context)
.env
.env.local
.env.*.local
*.pem
*.key

# Documentation (not needed in production image)
docs/
*.md
README*

# CI/CD configs
.github/
.gitlab-ci.yml
Jenkinsfile
```

#### Image Size Reduction Checklist

```dockerfile
# 1. Remove package manager caches in the same RUN layer
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 2. Use --no-install-recommends to skip suggested packages
# (can reduce install size by 40-60%)

# 3. Remove build-only tools after use
RUN apk add --no-cache --virtual .build-deps \
    gcc musl-dev \
    && pip install --no-cache-dir -r requirements.txt \
    && apk del .build-deps          # Removes gcc, musl-dev but keeps pip output

# 4. Squash intermediate layers (use sparingly — breaks layer sharing)
# Build with: docker build --squash .

# 5. Use COPY --link (BuildKit) for better layer deduplication
COPY --link --chown=app:app src/ ./src/
```

#### Scanning Images for CVEs

Image scanning should be a mandatory gate in your CI pipeline before any image is pushed to production registries:

```bash
# Trivy — open source, fast, comprehensive
trivy image myapp:1.0.0

# Example output:
# myapp:1.0.0 (alpine 3.18.4)
# ===========================
# Total: 3 (CRITICAL: 0, HIGH: 1, MEDIUM: 2, LOW: 0)
#
# ┌──────────────┬────────────┬──────────┬──────────────────────┐
# │  Library     │    CVE     │ Severity │ Installed → Fixed    │
# ├──────────────┼────────────┼──────────┼──────────────────────┤
# │ openssl      │ CVE-2024-X │ HIGH     │ 3.1.3 → 3.1.4        │
# └──────────────┴────────────┴──────────┴──────────────────────┘

# Grype — Anchore's scanner; excellent for compliance workflows
grype myapp:1.0.0 --fail-on high

# Docker Scout (built into Docker Desktop and Docker Hub)
docker scout cves myapp:1.0.0
docker scout recommendations myapp:1.0.0   # Suggests better base images
```

---

### 2.7 Docker Volumes and Storage

Containers are ephemeral. Any data written to the container's writable layer is lost when the container is removed. Docker provides three mechanisms for persisting or sharing data:

| Mechanism | Managed By | Use Case |
|---|---|---|
| Named Volume | Docker daemon | Persistent data; survives container removal; portable |
| Bind Mount | Host filesystem | Local development; sharing host files with container |
| tmpfs Mount | Host memory | Sensitive temporary data; never written to disk |

#### Named Volumes

```bash
# Create a named volume
docker volume create pgdata

# Mount it into a container
docker run -d \
  --name postgres \
  -e POSTGRES_PASSWORD=secret \
  -v pgdata:/var/lib/postgresql/data \
  -p 5432:5432 \
  postgres:16-alpine

# Inspect the volume
docker volume inspect pgdata
# [{"Name": "pgdata", "Mountpoint": "/var/lib/docker/volumes/pgdata/_data", ...}]

# Volume persists after container removal
docker rm -f postgres
docker volume ls                    # pgdata still exists
```

#### Bind Mounts for Local Development

```bash
# Mount the current directory into the container (hot-reload workflows)
docker run -it \
  --name dev-server \
  -v "$(pwd)/src:/app/src:ro" \    # :ro = read-only (prevent container writes)
  -v "$(pwd)/config:/app/config" \
  -p 3000:3000 \
  myapp:dev

# In Dockerfile, use a named volume to prevent node_modules from being overwritten
# by the bind mount (a classic gotcha in Node.js development):
# VOLUME ["/app/node_modules"]
```

#### Volume Drivers for Cloud Storage

```bash
# AWS EFS (NFS-compatible) via the efs driver
docker volume create \
  --driver local \
  --opt type=nfs \
  --opt o=addr=<efs-endpoint>,nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 \
  --opt device=:/ \
  efs-volume
```

> **Kubernetes Mapping:** Docker named volumes map to Kubernetes PersistentVolumeClaims (PVCs). Bind mounts map to `hostPath` volumes (use with caution in production). The concepts are identical; only the API surface differs.

---

### 2.8 Docker Networking

Docker networking is one of the most underappreciated topics among engineers who later struggle with Kubernetes networking. The two systems share the same underlying model — every container gets an IP, containers communicate over virtual networks, and external traffic enters via port mapping or ingress.

#### Docker Network Drivers

| Driver | Scope | Use Case |
|---|---|---|
| `bridge` (default) | Single host | Isolated network for containers on one Docker host |
| `host` | Single host | Container shares host network stack; no isolation |
| `overlay` | Multi-host | Docker Swarm; containers across multiple hosts |
| `macvlan` | Single host | Container needs a MAC address on the physical LAN |
| `none` | Single host | Complete network isolation; no interfaces |

#### Bridge Networks in Detail

```bash
# The default bridge network (docker0) — all containers can talk; no DNS by name
docker run -d --name app1 nginx:alpine
docker run -d --name app2 nginx:alpine
docker exec app2 ping app1          # FAILS — default bridge has no DNS

# Create a user-defined bridge network (has automatic DNS resolution by name)
docker network create --driver bridge app-network

docker run -d --name api     --network app-network myapi:latest
docker run -d --name db      --network app-network postgres:16-alpine
docker run -d --name cache   --network app-network redis:7-alpine

# api can now reach db as 'db:5432' and cache as 'cache:6379' — DNS by container name
docker exec api ping db             # SUCCESS
docker exec api ping cache          # SUCCESS

# Inspect the network
docker network inspect app-network
```

#### Port Mapping

```bash
# Map host port 8080 to container port 3000
docker run -d -p 8080:3000 myapp:latest

# Bind to a specific host interface (security best practice in production)
docker run -d -p 127.0.0.1:8080:3000 myapp:latest   # localhost only

# Random host port (useful in CI to avoid port conflicts)
docker run -d -p 3000 myapp:latest
docker port <container-id>          # Shows the assigned host port

# Multiple port mappings
docker run -d \
  -p 8080:3000 \
  -p 9090:9090 \    # Prometheus metrics endpoint
  myapp:latest
```

#### Network Namespace Sharing (Kubernetes Pods)

In Kubernetes, all containers within a Pod share a single network namespace. This is achieved via a `pause` container (also called the "infra container") that holds the network namespace open for the lifetime of the Pod. This is why containers within a Pod communicate over `localhost` — they share the same network interfaces.

```bash
# Simulate a Kubernetes Pod's network sharing with Docker
# Start the pause container (holds the network namespace)
docker run -d --name pause gcr.io/google-containers/pause:3.9

# Join the pause container's network namespace
docker run -d --name app   --network container:pause myapp:latest
docker run -d --name sidecar --network container:pause envoy:v1.29

# Now 'app' and 'sidecar' share network interfaces
# 'sidecar' can reach 'app' via localhost:3000
```

---

### 2.9 Docker Compose

Docker Compose is a tool for defining and running multi-container applications from a single YAML file. It is the standard tool for local development environments that mirror production microservices architectures.

#### Production-Grade Docker Compose Configuration

```yaml
# docker-compose.yml
# Version is optional for Compose V2 (docker compose, not docker-compose)
services:

  # ── API Service ──────────────────────────────────────────────────
  api:
    build:
      context: .
      dockerfile: Dockerfile
      target: production           # Use the 'production' multi-stage target
      args:
        - NODE_ENV=production
    image: myapp/api:${TAG:-latest}
    container_name: api
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - DATABASE_URL=postgresql://postgres:${DB_PASSWORD}@db:5432/appdb
      - REDIS_URL=redis://cache:6379
    env_file:
      - .env.local                 # Local overrides; gitignored
    depends_on:
      db:
        condition: service_healthy  # Wait for DB health check before starting
      cache:
        condition: service_started
    networks:
      - backend
      - frontend
    volumes:
      - ./logs:/app/logs           # Persist logs outside container
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s
    deploy:
      resources:
        limits:
          cpus: '0.50'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 256M

  # ── Database ─────────────────────────────────────────────────────
  db:
    image: postgres:16-alpine
    container_name: postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: appdb
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: ${DB_PASSWORD:?DB_PASSWORD must be set}
    volumes:
      - pgdata:/var/lib/postgresql/data    # Named volume for persistence
      - ./db/init:/docker-entrypoint-initdb.d:ro  # Init SQL scripts
    networks:
      - backend
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -d appdb"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s

  # ── Redis Cache ──────────────────────────────────────────────────
  cache:
    image: redis:7-alpine
    container_name: redis
    restart: unless-stopped
    command: redis-server --requirepass ${REDIS_PASSWORD} --maxmemory 256mb --maxmemory-policy allkeys-lru
    volumes:
      - redisdata:/data
    networks:
      - backend
    healthcheck:
      test: ["CMD", "redis-cli", "--no-auth-warning", "-a", "${REDIS_PASSWORD}", "ping"]
      interval: 10s
      timeout: 3s
      retries: 3

  # ── Prometheus (observability) ───────────────────────────────────
  prometheus:
    image: prom/prometheus:v2.51.0
    container_name: prometheus
    restart: unless-stopped
    ports:
      - "9090:9090"
    volumes:
      - ./observability/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - promdata:/prometheus
    networks:
      - backend
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.retention.time=15d'

  # ── Nginx Reverse Proxy ──────────────────────────────────────────
  nginx:
    image: nginx:1.25-alpine
    container_name: nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/certs:/etc/nginx/certs:ro
    depends_on:
      - api
    networks:
      - frontend

# ── Networks ──────────────────────────────────────────────────────
networks:
  backend:
    driver: bridge
    internal: true                 # No direct internet access from backend network
  frontend:
    driver: bridge

# ── Volumes ───────────────────────────────────────────────────────
volumes:
  pgdata:
    driver: local
  redisdata:
    driver: local
  promdata:
    driver: local
```

#### Docker Compose Profiles for Environment Variants

```yaml
# Use profiles to selectively start services
services:
  api:
    profiles: ["app", "full"]
    # ... service definition

  db:
    profiles: ["app", "full"]

  prometheus:
    profiles: ["monitoring", "full"]

  jaeger:
    image: jaegertracing/all-in-one:1.55
    profiles: ["monitoring", "full"]
    ports:
      - "16686:16686"   # Jaeger UI
      - "4317:4317"     # OTLP gRPC
```

```bash
# Start only the app services (api + db)
docker compose --profile app up -d

# Start everything including monitoring
docker compose --profile full up -d

# Scale a specific service
docker compose up -d --scale api=3
```

#### Essential Docker Compose Commands

```bash
# Start all services (detached)
docker compose up -d

# Start with a fresh build
docker compose up -d --build

# View service logs (follow mode)
docker compose logs -f api

# View logs from multiple services
docker compose logs -f api db

# Execute a command in a running service
docker compose exec api sh
docker compose exec db psql -U postgres appdb

# Scale a service (for stateless services)
docker compose up -d --scale api=3

# Show running services and their status
docker compose ps

# Stop without removing containers/volumes
docker compose stop

# Stop and remove containers, networks (preserves named volumes)
docker compose down

# Stop and remove EVERYTHING including volumes (careful — deletes data)
docker compose down --volumes --remove-orphans
```

---

### 2.10 Container Registries

A container registry is a content-addressable storage system for container images. Understanding registry architecture — authentication, image tagging strategies, and security features — is essential for operating Kubernetes in production.

#### Image Naming and Tagging

```
registry.hostname/namespace/repository:tag@digest

Examples:
docker.io/library/nginx:1.25-alpine                      # Docker Hub official image
docker.io/myorg/myapp:v1.4.2                             # Docker Hub personal/org
123456789.dkr.ecr.us-east-1.amazonaws.com/myapp:v1.4.2  # AWS ECR
gcr.io/my-project/myapp:v1.4.2                          # Google Container Registry
myregistry.azurecr.io/myapp:v1.4.2                      # Azure Container Registry
ghcr.io/myorg/myapp:v1.4.2                              # GitHub Container Registry
```

#### Tagging Strategy for Kubernetes

```bash
# ── Semantic versioning (production standard) ─────────────────────
docker tag myapp:latest myapp:1.4.2
docker tag myapp:latest myapp:1.4           # Floating minor tag
docker tag myapp:latest myapp:1             # Floating major tag

# ── Git SHA tags (GitOps / Argo CD standard) ─────────────────────
GIT_SHA=$(git rev-parse --short HEAD)
docker build -t myapp:${GIT_SHA} .
docker push myapp:${GIT_SHA}
# In deployment.yaml: image: myapp:a3f9c12

# ── Immutable digest reference (most secure) ─────────────────────
docker pull myapp:1.4.2
docker inspect --format='{{index .RepoDigests 0}}' myapp:1.4.2
# myapp@sha256:3d88c5de8e7f44c6ccdd55e5e1dc90b1b90ad1a4ef3e19e8e56c1b9c3fa8d9ae
# In deployment.yaml: image: myapp@sha256:3d88c5de...
```

#### Docker Hub

```bash
# Authenticate
docker login

# Push an image
docker tag myapp:1.4.2 myorg/myapp:1.4.2
docker push myorg/myapp:1.4.2

# Multi-platform build and push (amd64 + arm64)
docker buildx create --use --name multiarch
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --tag myorg/myapp:1.4.2 \
  --push \
  .
```

#### AWS Elastic Container Registry (ECR)

```bash
# Authenticate (token valid for 12 hours)
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  123456789.dkr.ecr.us-east-1.amazonaws.com

# Create repository (one-time)
aws ecr create-repository \
  --repository-name myapp \
  --image-scanning-configuration scanOnPush=true \
  --encryption-configuration encryptionType=AES256

# Tag and push
docker tag myapp:1.4.2 123456789.dkr.ecr.us-east-1.amazonaws.com/myapp:1.4.2
docker push 123456789.dkr.ecr.us-east-1.amazonaws.com/myapp:1.4.2

# In Kubernetes, use IRSA (IAM Roles for Service Accounts) for ECR auth
# No stored credentials required — kubelet's ECR credential provider handles it
```

#### Google Container Registry / Artifact Registry

```bash
# Authenticate with gcloud
gcloud auth configure-docker us-east1-docker.pkg.dev

# Push to Artifact Registry (the successor to GCR)
docker tag myapp:1.4.2 us-east1-docker.pkg.dev/my-project/my-repo/myapp:1.4.2
docker push us-east1-docker.pkg.dev/my-project/my-repo/myapp:1.4.2
```

#### Azure Container Registry (ACR)

```bash
# Authenticate
az acr login --name myregistry

# Push
docker tag myapp:1.4.2 myregistry.azurecr.io/myapp:1.4.2
docker push myregistry.azurecr.io/myapp:1.4.2

# Enable geo-replication (enterprise feature — replicate images to multiple regions)
az acr replication create --registry myregistry --location eastus
az acr replication create --registry myregistry --location westeurope
```

#### Registry Comparison

| Feature | Docker Hub | AWS ECR | Google AR | Azure ACR |
|---|---|---|---|---|
| Free private repos | 1 | Unlimited (pay per GB) | Pay per GB | 1 (Basic tier) |
| Geo-replication | No (paid) | Yes (multi-region) | Yes (global) | Yes (Premium) |
| Vulnerability scanning | Yes (Scout) | Yes (Inspector) | Yes (Artifact Analysis) | Yes (Defender) |
| K8s auth integration | Pull secret | IRSA / EC2 role | Workload Identity | Managed Identity |
| Image signing | Cosign | Cosign + ECR sign | Cosign | Notation |
| Retention policies | No | Yes (lifecycle) | Yes | Yes |

---

### 2.11 The Container Runtime Interface (CRI)

The Container Runtime Interface is the bridge that connects Kubernetes to the container ecosystem. Understanding CRI explains why Docker knowledge remains relevant even though Kubernetes no longer uses Docker directly.

#### The CRI Architecture

```
┌─────────────────────────────────────────────────┐
│  Kubernetes Control Plane                        │
│                                                  │
│  kube-apiserver → kubelet                        │
└────────────────────┬────────────────────────────┘
                     │ CRI (gRPC)
                     │
          ┌──────────▼──────────┐
          │  CRI Runtime        │
          │  (choose one):      │
          │                     │
          │  ┌───────────────┐  │
          │  │ containerd    │  │  ← Default in most managed K8s (EKS, GKE, AKS)
          │  └───────┬───────┘  │
          │          │ OCI      │
          │  ┌───────▼───────┐  │
          │  │   CRI-O       │  │  ← OpenShift default; strictly Kubernetes-focused
          │  └───────────────┘  │
          └──────────┬──────────┘
                     │ OCI Runtime Spec
                     │
          ┌──────────▼──────────┐
          │  OCI Runtime        │
          │  runc / crun        │  ← Makes the actual syscalls (clone, mount, etc.)
          └─────────────────────┘
```

#### What Happened to dockershim?

In Kubernetes 1.20, `dockershim` was deprecated. In Kubernetes 1.24 (May 2022), it was removed. The `dockershim` was an in-tree shim that let `kubelet` talk to `dockerd` before CRI was standardized. Its removal does not mean Docker is gone:

- Container images built with Docker are OCI-compliant and run on any CRI runtime.
- `containerd` is the runtime at the heart of Docker. Kubernetes using `containerd` directly is more efficient than going through `dockerd`.
- `docker build` and `docker push` are still the dominant image build tools.

```
BEFORE (Kubernetes ≤ 1.23):
kubelet → dockershim → dockerd → containerd → runc

AFTER (Kubernetes ≥ 1.24):
kubelet → CRI → containerd → runc   (one fewer hop; lower latency; less memory)
```

#### crictl — The kubelet-side Debug Tool

Once you are on a Kubernetes node, `docker` CLI is not available (the node runs `containerd`, not `dockerd`). Use `crictl` instead:

```bash
# crictl is the CRI-compatible equivalent of docker CLI for node-level debugging

# List running containers (equivalent to: docker ps)
crictl ps

# List images on this node (equivalent to: docker images)
crictl images

# Pull an image (equivalent to: docker pull)
crictl pull nginx:alpine

# Get container logs (equivalent to: docker logs)
crictl logs <container-id>

# Execute a command in a container (equivalent to: docker exec)
crictl exec -it <container-id> sh

# Inspect a container
crictl inspect <container-id>

# List pods (Kubernetes-specific — no Docker equivalent)
crictl pods

# Node-level image garbage collection status
crictl imagefsinfo
```

#### OCI Standards — Why Image Portability Works

The Open Container Initiative (OCI) defines two specifications that make the container ecosystem interoperable:

| OCI Spec | What It Defines | Ensures |
|---|---|---|
| Image Spec | Image manifest format, layer format, config schema | Images built with Docker run on containerd, CRI-O, or Podman |
| Runtime Spec | Container configuration and execution environment | `runc`, `crun`, `gVisor`, `Kata` all accept the same container config |

---

## 3. Step-by-Step Hands-on Walkthrough

### 3.1 Build a Production-Grade Multi-Stage Image

We will build a production-ready Node.js API image from scratch, applying every technique covered in this chapter.

```bash
# Project structure
mkdir k8s-demo-api && cd k8s-demo-api

cat > package.json << 'EOF'
{
  "name": "k8s-demo-api",
  "version": "1.0.0",
  "scripts": { "start": "node src/server.js" },
  "dependencies": { "express": "^4.18.2" }
}
EOF

mkdir src
cat > src/server.js << 'EOF'
const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

app.get('/health', (req, res) => res.json({ status: 'ok', version: '1.0.0' }));
app.get('/', (req, res) => res.json({ message: 'Hello from Kubernetes!', env: process.env.APP_ENV }));

app.listen(PORT, () => console.log(`Server listening on port ${PORT}`));
EOF
```

```dockerfile
# Dockerfile (multi-stage, production-grade)
# ─── Stage 1: Install dependencies ───────────────────────────────
FROM node:20.11-alpine3.19 AS deps
RUN apk add --no-cache dumb-init
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# ─── Stage 2: Production image ───────────────────────────────────
FROM node:20.11-alpine3.19 AS production

# Security: run as non-root
RUN addgroup -g 1001 -S nodejs && \
    adduser -S -u 1001 -G nodejs nodejs

WORKDIR /app

# Copy dumb-init from deps stage
COPY --from=deps /usr/bin/dumb-init /usr/bin/dumb-init

# Copy only production node_modules
COPY --from=deps --chown=nodejs:nodejs /app/node_modules ./node_modules

# Copy application source
COPY --chown=nodejs:nodejs src/ ./src/
COPY --chown=nodejs:nodejs package.json ./

USER nodejs

EXPOSE 3000

ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "src/server.js"]
```

```bash
# Build the image
docker build -t k8s-demo-api:1.0.0 .

# Verify the image size
docker images k8s-demo-api
# REPOSITORY      TAG     IMAGE ID       SIZE
# k8s-demo-api    1.0.0   a3f9b2c1d4e5   82.1MB

# Inspect the layers
docker history k8s-demo-api:1.0.0

# Scan for vulnerabilities
docker scout cves k8s-demo-api:1.0.0
# OR
trivy image k8s-demo-api:1.0.0

# Run locally to verify
docker run -d \
  --name demo-api \
  -e APP_ENV=development \
  -p 3000:3000 \
  k8s-demo-api:1.0.0

curl http://localhost:3000/health
# {"status":"ok","version":"1.0.0"}

curl http://localhost:3000/
# {"message":"Hello from Kubernetes!","env":"development"}
```

---

### 3.2 Set Up a Full Local Environment with Docker Compose

```yaml
# docker-compose.dev.yml — development overrides
services:
  api:
    build:
      context: .
      target: production
    image: k8s-demo-api:dev
    ports:
      - "3000:3000"
    environment:
      - APP_ENV=development
      - PORT=3000
    volumes:
      - ./src:/app/src:ro          # Mount source for development visibility
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:3000/health"]
      interval: 15s
      timeout: 5s
      retries: 3
      start_period: 5s
```

```bash
# Start the local environment
docker compose -f docker-compose.dev.yml up -d --build

# Verify services are healthy
docker compose ps
# NAME        IMAGE              STATUS          PORTS
# demo-api    k8s-demo-api:dev   Up (healthy)    0.0.0.0:3000->3000/tcp

# Follow logs
docker compose logs -f api

# Clean up
docker compose -f docker-compose.dev.yml down
```

---

### 3.3 Push to a Registry and Pull in Kubernetes

```bash
# Tag for your registry (replace with your actual registry)
docker tag k8s-demo-api:1.0.0 ghcr.io/myorg/k8s-demo-api:1.0.0

# Push
docker push ghcr.io/myorg/k8s-demo-api:1.0.0

# Get the immutable digest
docker inspect --format='{{index .RepoDigests 0}}' ghcr.io/myorg/k8s-demo-api:1.0.0
# ghcr.io/myorg/k8s-demo-api@sha256:3d88c5de...

# Create a Kubernetes imagePullSecret for a private registry
kubectl create secret docker-registry regcred \
  --docker-server=ghcr.io \
  --docker-username=myorg \
  --docker-password=$GITHUB_TOKEN \
  --namespace=devops-demo
```

```yaml
# deployment-with-registry.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: k8s-demo-api
  namespace: devops-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: k8s-demo-api
  template:
    metadata:
      labels:
        app: k8s-demo-api
    spec:
      # Reference the imagePullSecret for private registries
      imagePullSecrets:
        - name: regcred
      containers:
        - name: api
          # Use immutable digest in production (not a mutable tag)
          image: ghcr.io/myorg/k8s-demo-api@sha256:3d88c5de...
          ports:
            - containerPort: 3000
          env:
            - name: APP_ENV
              value: production
          resources:
            requests:
              memory: "64Mi"
              cpu: "100m"
            limits:
              memory: "128Mi"
              cpu: "200m"
          readinessProbe:
            httpGet:
              path: /health
              port: 3000
            initialDelaySeconds: 5
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /health
              port: 3000
            initialDelaySeconds: 15
            periodSeconds: 20
```

```bash
kubectl apply -f deployment-with-registry.yaml
kubectl rollout status deployment/k8s-demo-api
kubectl get pods -l app=k8s-demo-api
```

---

## 4. Real-World Scenario: Migrating a Legacy Java App to Containers

### The Problem

FinCo's core processing service is a Spring Boot 2.7 application deployed to bare metal with manual JAR transfers via SCP. The team has no container experience. The application has three major containerization challenges:

- JVM memory management was tuned for bare metal (fixed 4GB heap on 8GB hosts); in containers this causes OOM kills.
- Configuration is stored in `application.properties` files managed manually per environment.
- The team runs the same JAR on dev laptops and production, but the Ubuntu version differs, causing occasional GLIBC errors.

### The Solution

**Phase 1 — Containerize with multi-stage build:**

```dockerfile
FROM maven:3.9-eclipse-temurin-21-alpine AS builder
WORKDIR /build
COPY pom.xml .
RUN mvn dependency:go-offline -B
COPY src/ ./src/
RUN mvn clean package -DskipTests -B

FROM eclipse-temurin:21-jre-alpine AS production
RUN addgroup -g 1001 -S spring && adduser -u 1001 -S spring -G spring
WORKDIR /app
COPY --from=builder --chown=spring:spring /build/target/*.jar app.jar
USER spring
EXPOSE 8080
ENTRYPOINT ["java", \
  "-XX:+UseContainerSupport", \
  "-XX:MaxRAMPercentage=75.0", \
  "-jar", "app.jar"]
```

**Phase 2 — Externalize configuration:**

Replace hardcoded `application.properties` values with environment variable bindings (`${DB_URL}`), injected via Kubernetes ConfigMaps and Secrets.

**Phase 3 — Validate in Docker Compose before Kubernetes:**

The team writes a `docker-compose.yml` that mirrors the production topology (app + PostgreSQL + Redis), allowing local integration testing before deploying to the cluster.

### Results

| Issue | Before | After |
|---|---|---|
| JVM OOM kills in containers | Constant (heap > limit) | Zero (`MaxRAMPercentage=75.0`) |
| Dev/prod environment parity | Broken (GLIBC differences) | Perfect (same Alpine base) |
| Deploy time | 20 min (manual SCP + restart) | 90 sec (Docker push + kubectl apply) |
| Image size | N/A (JAR only) | 187 MB (JRE + app) |
| Environment config management | 6 hand-edited .properties files | 1 ConfigMap + 1 Secret |

---

## 5. Common Pitfalls & Best Practices

### Pitfall 1: Running as Root Inside Containers
The default user in most base images is root (UID 0). A container escape vulnerability combined with root privileges can compromise the host. Always create and switch to a non-root user. In Kubernetes, enforce this with `runAsNonRoot: true` in the Pod `securityContext`.

### Pitfall 2: Building with `COPY . .` Before Installing Dependencies
This invalidates the dependency layer cache on every code change, turning a 30-second cached build into a 5-minute full rebuild. Always copy dependency manifests (`package.json`, `go.mod`, `pom.xml`) and install dependencies before copying source code.

### Pitfall 3: Storing Secrets in Docker Images
Using `ENV SECRET_KEY=mypassword` or `COPY .env .` bakes secrets permanently into the image layer history. Anyone with `docker history` access can extract them. Inject secrets at runtime via environment variables, Kubernetes Secrets, or a secrets manager.

### Pitfall 4: Ignoring `.dockerignore`
Without a `.dockerignore`, `docker build` sends your entire project directory (including `.git`, `node_modules`, test fixtures, and local `.env` files) to the Docker daemon as build context. This slows builds and risks leaking sensitive files into the image.

### Pitfall 5: Using Mutable Tags in Kubernetes Deployments
Using `image: myapp:latest` in a Kubernetes Deployment means different nodes may pull different versions of the same tag, creating split-brain deployments. Use immutable tags (semantic versions or Git SHAs) or SHA digests in all Kubernetes manifests.

### Pitfall 6: Ignoring Image Vulnerability Scanning
A base image like `node:18` can carry 300+ known CVEs, many HIGH or CRITICAL. Integrate Trivy or Grype into your CI pipeline as a blocking step. Failing on HIGH+ severity CVEs before pushing to your registry is far cheaper than remediating them post-deployment.

> **Best Practice Checklist — Docker for Kubernetes**
> - [ ] Use multi-stage builds for all production images
> - [ ] Run containers as non-root (UID ≥ 1000)
> - [ ] Pin base image tags to exact versions, not `latest`
> - [ ] Add a comprehensive `.dockerignore` to every project
> - [ ] Never store secrets in images (`ENV`, `COPY .env`, `ARG` with secrets)
> - [ ] Scan every image in CI with Trivy or Grype before pushing
> - [ ] Use `dumb-init` or `tini` as PID 1 for proper signal handling
> - [ ] Set `HEALTHCHECK` in Dockerfile (documents intent; Kubernetes uses probes)
> - [ ] Use immutable image tags (semantic version or Git SHA) in K8s manifests
> - [ ] Combine `apt-get update && apt-get install && apt-get clean` in one `RUN`

---

## 6. Key Takeaways

1. **Containers are Linux processes**, not VMs. They achieve isolation through kernel namespaces and resource enforcement through cgroups — the same mechanisms Kubernetes uses under the hood. Understanding this model makes Kubernetes resource limits intuitive, not magical.

2. **Image layers are the fundamental unit of caching and sharing.** Ordering Dockerfile instructions from least-frequently-changed to most-frequently-changed (base → dependencies → source) is the single most impactful build performance optimization.

3. **Multi-stage builds are non-negotiable for production.** They separate build tooling from runtime artifacts, dramatically reduce image size, and minimize the attack surface exposed in production.

4. **`.dockerignore` is not optional.** A missing `.dockerignore` slows builds, increases image size, and risks leaking secrets and local configuration files into your container images.

5. **Docker Hub, ECR, GCR, and ACR all serve the same role** — OCI-compliant image registries — but differ in their authentication model, Kubernetes integration depth, scanning capabilities, and cost. Choose based on your cloud provider and compliance requirements.

6. **Docker is still fully relevant in a Kubernetes world.** The removal of `dockershim` in Kubernetes 1.24 did not remove Docker from the picture — it removed an unnecessary translation layer. OCI-compliant images built with Docker run on `containerd` without modification. On Kubernetes nodes, use `crictl` instead of `docker` for runtime debugging.

---

## 7. Exercises & Labs

**Exercise 1: Multi-Stage Build Comparison**
Build the same Node.js application twice: once using a naive single-stage Dockerfile (`FROM node:20`, `COPY . .`, `RUN npm install`) and once using the multi-stage pattern from Section 3.1. Compare the image sizes using `docker images` and the layer breakdown using `docker history`. Document the size difference and identify which layers account for the savings.

**Exercise 2: Layer Cache Analysis**
Start with the naive Dockerfile from Exercise 1. Make a small change to `src/server.js` (add a comment) and rebuild. Observe how many layers are rebuilt. Then rebuild with the optimized Dockerfile. Compare the number of layers rebuilt and the rebuild times. Write a one-paragraph explanation of why the ordering change has such a large impact.

**Exercise 3: Docker Compose Full Stack**
Using the Docker Compose configuration from Section 2.9 as a template, build a local environment for a three-service application: a Node.js API, a PostgreSQL database, and a Redis cache. Add health checks to all services. Configure the API to depend on the database with `condition: service_healthy`. Verify the startup order is correct by watching `docker compose up` logs.

**Exercise 4: Registry Push and imagePullSecret**
Create a free account on Docker Hub (or use an existing one). Build the `k8s-demo-api` image from Section 3.1, push it to your Docker Hub account, and then deploy it to your minikube cluster using the `imagePullSecret` pattern from Section 3.3. Verify the Pod starts successfully and the correct image is running using `kubectl describe pod`.

**Exercise 5: crictl Node Debugging**
SSH into your minikube node using `minikube ssh`. Use `crictl` to: (a) list all running containers, (b) inspect the Pod sandbox for one of your running Pods, (c) retrieve the last 50 lines of logs from a running container, and (d) execute `env` inside a running container to verify environment variables from a ConfigMap are correctly injected. Write a brief comparison of the `crictl` commands you used versus their `docker` CLI equivalents.

---

*End of Chapter 2*

**Next → Chapter 3: Speeding Up with Standard Kubernetes Operations**



---

──────────────────────────────────────────────────────────────────────

## Part III: Speeding Up with Standard Kubernetes Operations

> *Pods · Deployments · Services · HPA · kubectl*

──────────────────────────────────────────────────────────────────────


## 1. Introduction & Learning Objectives

Kubernetes has a reputation for complexity. Teams new to the platform often feel overwhelmed by the volume of concepts, API resources, and YAML they must understand before they can ship anything. That reputation is not entirely undeserved — but it is mostly front-loaded. Once you deeply understand a small, well-chosen set of core primitives, the rest of Kubernetes becomes recognizable pattern-matching rather than new learning.

This chapter is about those core primitives. Pods, Deployments, ReplicaSets, Services, ConfigMaps, Secrets, Namespaces — these are the building blocks from which every Kubernetes workload is constructed. We will not skim them. We will study them from first principles: how each object is structured, what control loop manages it, what failure modes it has, and how it composes with the other primitives.

We will also cover the operational muscle memory every Kubernetes practitioner needs: `kubectl` productivity patterns, rolling updates and rollbacks, label-based selection, resource quotas, and autoscaling from Pod-level HPA through to cluster-level node autoscaling.

By the end of this chapter you will not just know how to write Kubernetes YAML — you will understand what the cluster is doing with it.

> **Learning Objectives**
> - Understand the Pod lifecycle and the phases a Pod transitions through from creation to termination.
> - Explain the relationship between Pods, ReplicaSets, and Deployments and the control loops that manage them.
> - Configure all four Service types and know when to use each one.
> - Manage application configuration cleanly using ConfigMaps and Secrets.
> - Use namespaces, resource quotas, and LimitRanges to partition and govern cluster resources.
> - Apply labels, annotations, and selectors as a consistent operational language.
> - Execute rolling updates, rollbacks, and blue/green deployments with confidence.
> - Configure Horizontal Pod Autoscaler (HPA) with CPU, memory, and custom metrics.
> - Understand Cluster Autoscaler and KEDA for node-level and event-driven scaling.
> - Build a productive `kubectl` workflow with aliases, plugins, and context management.

---

## 2. Core Concepts

### 2.1 The Kubernetes Object Model

Every resource in Kubernetes — a Pod, a Service, a Namespace, a StorageClass — is a **Kubernetes object**: a persistent record in `etcd` that represents the desired state of some aspect of your cluster. Every object shares the same four top-level fields:

```yaml
apiVersion: apps/v1        # API group and version
kind: Deployment           # Object type
metadata:                  # Identity and metadata
  name: my-deployment
  namespace: production
  labels:
    app: my-app
  annotations:
    deployment.kubernetes.io/revision: "3"
spec:                      # Desired state (what you want)
  replicas: 3
  # ...
# status:                  # Observed state (what the cluster has achieved)
#   readyReplicas: 3       # Written by the control plane — never set this yourself
```

The `spec` is what you declare. The `status` is what the cluster reports back. The gap between them is what **controllers** spend their entire existence trying to close. This declarative model — declare desired state, let the system converge toward it — is the single most important design choice in Kubernetes.

---

### 2.2 Pods — The Atomic Unit of Kubernetes

A Pod is the smallest deployable unit in Kubernetes. It is not a container — it is a wrapper around one or more containers that share:

- **The same network namespace** — all containers in a Pod share an IP address and port space. Container-to-container communication within a Pod happens over `localhost`.
- **The same storage volumes** — any volumes defined in the Pod spec are accessible to all containers.
- **The same lifecycle** — all containers in a Pod are scheduled on the same node and start/stop together.

```
┌──────────────────────────────────────────────────────┐
│  Pod: order-service-7d9b6c8b5f-4xk9p                 │
│  Node: worker-node-1   IP: 172.17.0.8                │
│                                                      │
│  ┌─────────────────┐  ┌────────────────────────┐    │
│  │  Main Container  │  │  Sidecar Container     │    │
│  │  order-api       │  │  envoy-proxy           │    │
│  │  port: 8080      │  │  port: 9090 (metrics)  │    │
│  │                  │  │  port: 15090 (admin)   │    │
│  └────────┬─────────┘  └────────────────────────┘    │
│           │   localhost:9090 (shared network)         │
│  ┌────────▼─────────────────────────────────────┐    │
│  │  Shared Volumes                               │    │
│  │  /var/log (emptyDir)  /config (ConfigMap)     │    │
│  └──────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────┘
```

#### Pod Lifecycle Phases

| Phase | Meaning |
|---|---|
| `Pending` | Pod accepted by the API server; waiting for scheduling or image pull |
| `Running` | Pod bound to a node; at least one container is running |
| `Succeeded` | All containers exited with code 0 (typically for Jobs) |
| `Failed` | All containers have terminated; at least one exited with non-zero code |
| `Unknown` | Pod state cannot be obtained (node communication failure) |

#### Container States Within a Pod

| State | Meaning |
|---|---|
| `Waiting` | Container is not yet running (e.g. pulling image, waiting for init containers) |
| `Running` | Container is executing |
| `Terminated` | Container finished execution (exit code recorded) |

#### Pod Restart Policies

```yaml
spec:
  restartPolicy: Always      # Default; restart on any exit — use for long-running services
  # restartPolicy: OnFailure # Restart only on non-zero exit — use for Jobs
  # restartPolicy: Never     # Never restart — use for one-shot tasks
```

#### Init Containers

Init containers run **sequentially** and **to completion** before any app containers start. They are ideal for setup tasks: waiting for a database to be ready, fetching configuration from a secrets manager, or running database migrations.

```yaml
spec:
  initContainers:
    - name: wait-for-db
      image: busybox:1.36
      command:
        - sh
        - -c
        - |
          until nc -z db-service 5432; do
            echo "Waiting for PostgreSQL..."
            sleep 2
          done
          echo "PostgreSQL is ready"

    - name: run-migrations
      image: myapp/migrations:1.0.0
      env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: url
      command: ["./migrate", "up"]

  containers:
    - name: api
      image: myapp/api:1.0.0
      # Only starts after both init containers complete successfully
```

#### Pod Conditions

Beyond phases, Pods expose fine-grained conditions. These are what readiness gates and Deployment controllers actually watch:

```bash
kubectl describe pod <pod-name> | grep -A 10 "Conditions:"
# Conditions:
#   Type              Status
#   Initialized       True    ← init containers all completed
#   Ready             True    ← all containers passing readiness probes
#   ContainersReady   True    ← all containers running and ready
#   PodScheduled      True    ← scheduler assigned Pod to a node
```

#### Probes

Kubernetes uses three types of probes to manage container health:

| Probe | Purpose | On Failure |
|---|---|---|
| `livenessProbe` | Is the container alive? Should it be restarted? | Container is killed and restarted (per `restartPolicy`) |
| `readinessProbe` | Is the container ready to receive traffic? | Pod is removed from Service endpoints |
| `startupProbe` | Has the container finished its slow startup? | Disables liveness/readiness until startup succeeds |

```yaml
containers:
  - name: api
    image: myapp:1.0.0
    startupProbe:                      # Gives slow-starting apps (JVM) time to initialize
      httpGet:
        path: /health/startup
        port: 8080
      failureThreshold: 30             # Allow up to 30 * 10s = 5 minutes to start
      periodSeconds: 10

    readinessProbe:
      httpGet:
        path: /health/ready
        port: 8080
      initialDelaySeconds: 5
      periodSeconds: 10
      failureThreshold: 3              # Remove from endpoints after 3 consecutive failures
      successThreshold: 1

    livenessProbe:
      httpGet:
        path: /health/live
        port: 8080
      initialDelaySeconds: 30
      periodSeconds: 20
      failureThreshold: 3              # Restart container after 3 consecutive failures
      timeoutSeconds: 5
```

---

### 2.3 ReplicaSets — Desired Count Enforcement

A ReplicaSet ensures that a specified number of identical Pod replicas are running at any given time. Its control loop is simple:

```
observe current state → compare to desired state → create or delete Pods to reconcile
```

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: order-api-rs
spec:
  replicas: 3
  selector:
    matchLabels:
      app: order-api
      version: "1.0.0"
  template:               # Pod template — identical to a Pod spec minus apiVersion/kind
    metadata:
      labels:
        app: order-api
        version: "1.0.0"
    spec:
      containers:
        - name: api
          image: myapp/order-api:1.0.0
```

> **You almost never create ReplicaSets directly.** Deployments create and manage ReplicaSets on your behalf, adding rolling update and rollback capabilities on top. Think of ReplicaSets as an implementation detail of Deployments.

---

### 2.4 Deployments — The Standard Workload Primitive

A Deployment is the standard way to run stateless workloads in Kubernetes. It manages ReplicaSets, which in turn manage Pods. This three-tier ownership model is what enables zero-downtime rolling updates.

```
Deployment
    └── ReplicaSet v1 (old, scaling down)
    │       └── Pod  └── Pod  └── Pod
    └── ReplicaSet v2 (new, scaling up)
            └── Pod  └── Pod  └── Pod
```

#### Full Production Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-api
  namespace: production
  labels:
    app: order-api
    team: platform
    tier: backend
  annotations:
    kubernetes.io/change-cause: "Release v1.4.2: add retry logic to payment client"
spec:
  replicas: 5

  selector:
    matchLabels:
      app: order-api            # Immutable after creation

  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 2               # Allow up to 7 Pods during update (5 + 2)
      maxUnavailable: 0         # Never go below 5 ready Pods (zero-downtime)

  minReadySeconds: 10           # Pod must be Ready for 10s before counted as available
  progressDeadlineSeconds: 300  # Fail the rollout if not complete within 5 minutes
  revisionHistoryLimit: 5       # Keep 5 old ReplicaSets for rollback

  template:
    metadata:
      labels:
        app: order-api
        version: "1.4.2"
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9090"
        prometheus.io/path: "/metrics"
    spec:
      # Spread Pods across availability zones (topology spread)
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app: order-api

      # Anti-affinity: avoid scheduling two replicas on the same node
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    app: order-api
                topologyKey: kubernetes.io/hostname

      # Graceful termination: allow 30s for in-flight requests
      terminationGracePeriodSeconds: 30

      containers:
        - name: api
          image: myapp/order-api:1.4.2
          ports:
            - name: http
              containerPort: 8080
            - name: metrics
              containerPort: 9090

          envFrom:
            - configMapRef:
                name: order-api-config
          env:
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: order-api-secret
                  key: db-password
            - name: POD_NAME           # Inject Pod metadata (useful for logging)
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: POD_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace

          resources:
            requests:
              memory: "256Mi"
              cpu: "250m"
            limits:
              memory: "512Mi"
              cpu: "500m"

          readinessProbe:
            httpGet:
              path: /health/ready
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 10
            failureThreshold: 3

          livenessProbe:
            httpGet:
              path: /health/live
              port: 8080
            initialDelaySeconds: 30
            periodSeconds: 20
            failureThreshold: 3

          lifecycle:
            preStop:
              exec:
                # Delay SIGTERM to allow the load balancer to drain connections
                command: ["/bin/sh", "-c", "sleep 5"]

          volumeMounts:
            - name: config-vol
              mountPath: /app/config
              readOnly: true
            - name: tmp-vol
              mountPath: /tmp

      volumes:
        - name: config-vol
          configMap:
            name: order-api-config
        - name: tmp-vol
          emptyDir: {}           # Ephemeral scratch space; cleared on Pod removal
```

---

### 2.5 Services — Stable Network Endpoints

Pods are ephemeral. Their IP addresses change every time they are scheduled. A **Service** provides a stable virtual IP (called a ClusterIP) and DNS name that always routes to the currently healthy Pods matching its selector.

```
Client → Service (stable ClusterIP: 10.96.45.12, DNS: order-api.production.svc.cluster.local)
              └── kube-proxy (iptables / ipvs rules)
                      ├── Pod 172.17.0.4  (if Ready)
                      ├── Pod 172.17.0.5  (if Ready)
                      └── Pod 172.17.0.6  (if Ready)
```

#### The Four Service Types

**ClusterIP (default) — Internal cluster communication**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: order-api
  namespace: production
spec:
  type: ClusterIP               # Virtual IP only accessible inside the cluster
  selector:
    app: order-api              # Routes to any Pod with this label
  ports:
    - name: http
      port: 80                  # Port clients connect to
      targetPort: 8080          # Port on the container
    - name: metrics
      port: 9090
      targetPort: 9090
```

**NodePort — Expose on a static port on every node**

```yaml
spec:
  type: NodePort
  selector:
    app: order-api
  ports:
    - port: 80
      targetPort: 8080
      nodePort: 30080            # Range: 30000-32767; allocated automatically if omitted
# Access: <any-node-ip>:30080
# Use case: development, on-premise environments without a load balancer
```

**LoadBalancer — Cloud provider load balancer**

```yaml
spec:
  type: LoadBalancer
  selector:
    app: order-api
  ports:
    - port: 443
      targetPort: 8080
  # Cloud-specific annotations
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    service.beta.kubernetes.io/aws-load-balancer-internal: "true"
    service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
# Cloud controller provisions an NLB/ALB/Azure LB; EXTERNAL-IP appears after ~60s
```

**ExternalName — DNS alias to external service**

```yaml
spec:
  type: ExternalName
  externalName: prod-db.us-east-1.rds.amazonaws.com
# Creates a CNAME record; no selector needed
# In-cluster DNS: db.production.svc.cluster.local → prod-db.us-east-1.rds.amazonaws.com
# Use case: abstract external dependencies (RDS, ElastiCache) behind a Kubernetes Service name
# Swap the underlying external service without changing app config
```

#### Headless Services (StatefulSets)

```yaml
spec:
  clusterIP: None               # No virtual IP; DNS returns Pod IPs directly
  selector:
    app: postgres
# DNS: postgres-0.postgres.production.svc.cluster.local → 172.17.0.4 (direct Pod IP)
# Use case: StatefulSets where clients need stable, individual Pod addresses
```

#### Service DNS — How In-Cluster Discovery Works

Kubernetes injects a DNS resolver into every Pod. Services are addressable by several DNS forms:

```
<service-name>                                      # Within same namespace
<service-name>.<namespace>                          # Cross-namespace
<service-name>.<namespace>.svc                      # Explicit svc
<service-name>.<namespace>.svc.cluster.local        # Fully qualified (FQDN)

# Examples:
order-api                                           # From within 'production' namespace
order-api.production                                # From any namespace
order-api.production.svc.cluster.local              # Fully qualified

# Test DNS resolution from inside a Pod:
kubectl run dns-test --image=busybox:1.36 --rm -it --restart=Never -- \
  nslookup order-api.production.svc.cluster.local
```

---

### 2.6 ConfigMaps — Externalizing Configuration

A ConfigMap stores non-sensitive key-value configuration data that can be injected into Pods as environment variables, command-line arguments, or mounted as files.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: order-api-config
  namespace: production
data:
  # Key-value pairs (become environment variables)
  APP_ENV: "production"
  LOG_LEVEL: "info"
  PORT: "8080"
  MAX_CONNECTIONS: "100"
  FEATURE_NEW_CHECKOUT: "true"

  # File-like keys (mounted as files in a volume)
  app.properties: |
    server.port=8080
    spring.datasource.pool.max-size=20
    logging.level.root=INFO

  nginx.conf: |
    server {
        listen 80;
        location / {
            proxy_pass http://localhost:8080;
        }
        location /health {
            access_log off;
            return 200 'ok';
        }
    }
```

#### Consuming ConfigMaps

```yaml
spec:
  containers:
    - name: api
      # Method 1: Inject all keys as environment variables
      envFrom:
        - configMapRef:
            name: order-api-config

      # Method 2: Inject individual keys as named environment variables
      env:
        - name: LOG_LEVEL
          valueFrom:
            configMapKeyRef:
              name: order-api-config
              key: LOG_LEVEL

      volumeMounts:
        # Method 3: Mount as files (each key becomes a file)
        - name: config-files
          mountPath: /app/config
          readOnly: true

        # Method 4: Mount a single key as a specific file path
        - name: nginx-config
          mountPath: /etc/nginx/nginx.conf
          subPath: nginx.conf               # Mount only this key as this file
          readOnly: true

  volumes:
    - name: config-files
      configMap:
        name: order-api-config
    - name: nginx-config
      configMap:
        name: order-api-config
```

> **Important:** When a ConfigMap is updated, mounted volumes are eventually updated (within ~60s). Environment variables from `envFrom` are NOT updated — they require a Pod restart. For configuration hot-reload, always use volume mounts, not environment variables.

---

### 2.7 Secrets — Managing Sensitive Configuration

Secrets are structurally similar to ConfigMaps but intended for sensitive data. By default, Kubernetes stores Secrets as base64-encoded values in `etcd`. Base64 is **not encryption** — it is encoding. In production, always enable `etcd` encryption at rest and use an external secrets solution.

#### Secret Types

| Type | Use Case |
|---|---|
| `Opaque` | Generic key-value secrets (passwords, API keys, connection strings) |
| `kubernetes.io/tls` | TLS certificate and private key pairs |
| `kubernetes.io/dockerconfigjson` | Container registry authentication |
| `kubernetes.io/service-account-token` | Service account tokens (auto-created) |
| `kubernetes.io/ssh-auth` | SSH private keys |

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: order-api-secret
  namespace: production
type: Opaque
# Values must be base64 encoded: echo -n 'value' | base64
data:
  db-password: cGFzc3dvcmQxMjM=          # "password123"
  api-key: c2VjcmV0LWtleS0xMjM=          # "secret-key-123"

# Alternatively, use stringData — Kubernetes encodes it automatically
stringData:
  jwt-secret: "my-jwt-signing-secret-value"
```

#### TLS Secret

```bash
# Create a TLS Secret from certificate files
kubectl create secret tls order-api-tls \
  --cert=tls.crt \
  --key=tls.key \
  --namespace=production

# Or from cert-manager (automatic TLS certificate provisioning)
# cert-manager creates and rotates the Secret automatically
```

#### Registry Pull Secret

```bash
kubectl create secret docker-registry regcred \
  --docker-server=123456789.dkr.ecr.us-east-1.amazonaws.com \
  --docker-username=AWS \
  --docker-password=$(aws ecr get-login-password --region us-east-1) \
  --namespace=production
```

#### Production Secret Management Patterns

```
Basic (dev/staging):     Kubernetes Secrets + etcd encryption at rest
Better (production):     Sealed Secrets (encrypted in Git; decrypted in cluster)
Best (enterprise):       External Secrets Operator + HashiCorp Vault / AWS Secrets Manager
```

```yaml
# External Secrets Operator example
# Syncs a secret from AWS Secrets Manager into a Kubernetes Secret
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: order-api-secret
  namespace: production
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  target:
    name: order-api-secret       # Creates this Kubernetes Secret
  data:
    - secretKey: db-password     # Key in Kubernetes Secret
      remoteRef:
        key: production/order-api/db    # Path in AWS Secrets Manager
        property: password              # JSON field in the secret
```

---

### 2.8 Namespaces — Cluster Partitioning

Namespaces provide a mechanism for isolating groups of resources within a single cluster. They are the primary tool for multi-team, multi-environment cluster sharing.

#### Built-in Namespaces

| Namespace | Purpose |
|---|---|
| `default` | Where resources go when no namespace is specified |
| `kube-system` | Kubernetes system components (CoreDNS, kube-proxy, metrics-server) |
| `kube-public` | Publicly readable; contains cluster info |
| `kube-node-lease` | Node heartbeat lease objects (improves node failure detection) |

#### Namespace Strategy Patterns

```
By Environment (common for small teams):
  ├── development
  ├── staging
  └── production

By Team (common for platform teams):
  ├── team-payments
  ├── team-catalog
  └── team-identity

By Both (common for larger orgs):
  ├── payments-dev
  ├── payments-staging
  ├── payments-production
  ├── catalog-dev
  └── ...
```

```bash
# Create namespaces
kubectl create namespace production
kubectl create namespace staging

# Or declaratively (preferred for GitOps)
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    env: production
    team: platform
EOF

# Set default namespace for your kubectl context
kubectl config set-context --current --namespace=production

# List resources across all namespaces
kubectl get pods --all-namespaces       # or -A
kubectl get pods -A -o wide
```

#### ResourceQuotas — Enforcing Limits Per Namespace

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: production-quota
  namespace: production
spec:
  hard:
    # Compute resources
    requests.cpu: "20"              # Total CPU requests across all Pods
    requests.memory: 40Gi           # Total memory requests
    limits.cpu: "40"
    limits.memory: 80Gi

    # Object counts
    pods: "100"
    services: "20"
    secrets: "50"
    configmaps: "50"
    persistentvolumeclaims: "30"

    # LoadBalancer services (expensive — limit carefully)
    services.loadbalancers: "2"
    services.nodeports: "0"         # Prohibit NodePort services in production
```

#### LimitRange — Default Resource Enforcement

```yaml
# Without a LimitRange, Pods without resource requests are scheduled
# with no resource guarantees — a common cause of node pressure.
apiVersion: v1
kind: LimitRange
metadata:
  name: production-limits
  namespace: production
spec:
  limits:
    - type: Container
      default:                    # Applied when no limits are specified
        cpu: "500m"
        memory: "256Mi"
      defaultRequest:             # Applied when no requests are specified
        cpu: "100m"
        memory: "128Mi"
      max:                        # Hard ceiling; Pods exceeding this are rejected
        cpu: "4"
        memory: "4Gi"
      min:                        # Floor; prevents absurdly small requests
        cpu: "50m"
        memory: "64Mi"
    - type: PersistentVolumeClaim
      max:
        storage: 50Gi
      min:
        storage: 1Gi
```

---

### 2.9 Labels, Annotations, and Selectors

Labels and annotations are key-value pairs attached to Kubernetes objects. They look similar but serve fundamentally different purposes.

| | Labels | Annotations |
|---|---|---|
| **Purpose** | Identity and selection | Non-identifying metadata |
| **Used by** | Selectors, controllers, scheduling | Tooling, humans, external systems |
| **Queryable** | Yes — `kubectl get -l` | No |
| **Size limit** | 63 chars key, 63 chars value | Much larger (kilobytes) |
| **Examples** | `app: order-api`, `env: prod` | `deployment.kubernetes.io/revision: "3"` |

#### Recommended Label Schema

```yaml
metadata:
  labels:
    # Kubernetes recommended labels (https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/)
    app.kubernetes.io/name: order-api
    app.kubernetes.io/instance: order-api-production
    app.kubernetes.io/version: "1.4.2"
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: ecommerce-platform
    app.kubernetes.io/managed-by: argocd

    # Custom operational labels
    team: payments
    env: production
    tier: api
    criticality: high
```

#### Label Selectors — Querying with Precision

```bash
# Equality-based selectors
kubectl get pods -l app=order-api
kubectl get pods -l app=order-api,env=production    # AND condition
kubectl get pods -l env!=development                 # NOT

# Set-based selectors
kubectl get pods -l 'env in (production, staging)'
kubectl get pods -l 'env notin (development)'
kubectl get pods -l 'app.kubernetes.io/version'      # Label exists (any value)
kubectl get pods -l '!deprecated'                    # Label does NOT exist

# Used in Service/Deployment selectors
spec:
  selector:
    matchLabels:                      # AND conditions
      app: order-api
    matchExpressions:                 # More expressive
      - key: env
        operator: In
        values: [production, staging]
      - key: deprecated
        operator: DoesNotExist

# Field selectors (by object properties, not labels)
kubectl get pods --field-selector status.phase=Running
kubectl get pods --field-selector spec.nodeName=worker-node-1
```

---

### 2.10 Rolling Updates and Rollbacks

Kubernetes Deployment rolling updates are the primary mechanism for zero-downtime application releases. Understanding the mechanics — and what can go wrong — is essential operational knowledge.

#### How a Rolling Update Works

```
Initial state: 5 Pods running v1
maxSurge: 2, maxUnavailable: 0

Step 1: Create 2 new v2 Pods (total: 7)     [v1 v1 v1 v1 v1  v2 v2]
Step 2: Wait for 2 v2 Pods to be Ready
Step 3: Terminate 2 v1 Pods (total: 5)      [v1 v1 v1  v2 v2]
Step 4: Create 2 new v2 Pods (total: 7)     [v1 v1 v1  v2 v2 v2 v2]
Step 5: Wait for new Pods to be Ready
Step 6: Terminate remaining v1 Pods (total: 5) [v2 v2 v2 v2 v2]
```

```bash
# Trigger a rolling update by updating the image tag
# Method 1: kubectl set (quick, but bypasses GitOps — use in emergencies only)
kubectl set image deployment/order-api api=myapp/order-api:1.4.3 -n production

# Method 2: Edit manifest and apply (GitOps-correct approach)
# Update image tag in deployment.yaml, then:
kubectl apply -f deployment.yaml

# Method 3: kubectl patch (scriptable)
kubectl patch deployment order-api \
  -p '{"spec":{"template":{"spec":{"containers":[{"name":"api","image":"myapp/order-api:1.4.3"}]}}}}' \
  -n production

# Watch the rollout in real time
kubectl rollout status deployment/order-api -n production --watch
# Waiting for deployment "order-api" rollout to finish: 2 out of 5 new replicas have been updated...
# Waiting for deployment "order-api" rollout to finish: 2 old replicas are pending termination...
# deployment "order-api" successfully rolled out

# Check rollout history
kubectl rollout history deployment/order-api -n production
# REVISION  CHANGE-CAUSE
# 1         Initial deployment v1.0.0
# 2         Release v1.4.1: fix order validation bug
# 3         Release v1.4.2: add retry logic to payment client
# 4         Release v1.4.3: hotfix null pointer in cart service

# View details of a specific revision
kubectl rollout history deployment/order-api --revision=3 -n production
```

#### Rollbacks

```bash
# Rollback to the previous revision (most common)
kubectl rollout undo deployment/order-api -n production

# Rollback to a specific revision
kubectl rollout undo deployment/order-api --to-revision=2 -n production

# Watch rollback complete
kubectl rollout status deployment/order-api -n production --watch

# Pause a rollout (hold mid-way through for canary validation)
kubectl rollout pause deployment/order-api -n production
# ... run smoke tests, check metrics ...
kubectl rollout resume deployment/order-api -n production
```

#### Deployment Strategies Compared

| Strategy | Zero Downtime | Resource Cost | Rollback Speed | Best For |
|---|---|---|---|---|
| Recreate | ❌ | Low | Fast | Dev/staging; breaking schema changes |
| RollingUpdate | ✅ | Medium | Fast | Standard production releases |
| Blue/Green | ✅ | High (2x) | Instant | High-risk releases; instant cutover needed |
| Canary | ✅ | Low | Fast | Risk-sensitive releases; A/B testing |

#### Blue/Green Deployment with Services

```yaml
# Blue deployment (current production)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-api-blue
spec:
  replicas: 5
  selector:
    matchLabels:
      app: order-api
      slot: blue
  template:
    metadata:
      labels:
        app: order-api
        slot: blue
    spec:
      containers:
        - name: api
          image: myapp/order-api:1.4.2

---
# Green deployment (new version, pre-warmed)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-api-green
spec:
  replicas: 5
  selector:
    matchLabels:
      app: order-api
      slot: green
  template:
    metadata:
      labels:
        app: order-api
        slot: green
    spec:
      containers:
        - name: api
          image: myapp/order-api:1.4.3

---
# Service — switch traffic by changing the 'slot' label selector
apiVersion: v1
kind: Service
metadata:
  name: order-api
spec:
  selector:
    app: order-api
    slot: blue              # Change to 'green' for instant cutover
  ports:
    - port: 80
      targetPort: 8080
```

```bash
# Instant cutover from blue to green
kubectl patch service order-api \
  -p '{"spec":{"selector":{"slot":"green"}}}' \
  -n production

# Instant rollback: switch back to blue
kubectl patch service order-api \
  -p '{"spec":{"selector":{"slot":"blue"}}}' \
  -n production
```

---

### 2.11 Horizontal Pod Autoscaler (HPA)

The Horizontal Pod Autoscaler automatically scales the number of Pod replicas in a Deployment (or StatefulSet, ReplicaSet) based on observed metrics. It is a control loop that runs every 15 seconds by default.

```
HPA Control Loop:
  1. Query metrics-server (or custom metrics adapter) for current metric value
  2. Calculate desired replicas:
     desiredReplicas = ceil(currentReplicas × (currentMetricValue / targetMetricValue))
  3. If desiredReplicas != currentReplicas: update Deployment.spec.replicas
```

#### Prerequisites: metrics-server

```bash
# Install metrics-server (required for CPU/memory HPA)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Verify it is running
kubectl top nodes
kubectl top pods -n production
```

#### HPA v2 — CPU and Memory

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: order-api-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: order-api

  minReplicas: 3             # Never scale below 3 (resilience floor)
  maxReplicas: 20            # Never scale above 20 (cost ceiling)

  metrics:
    # Scale on CPU utilization (relative to requests)
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70    # Target 70% of requested CPU

    # Scale on memory utilization
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80

  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60     # Wait 60s before scaling up again
      policies:
        - type: Pods
          value: 4                        # Add at most 4 Pods per scaling event
          periodSeconds: 60
        - type: Percent
          value: 100                      # Or double the count — whichever is larger
          periodSeconds: 60
      selectPolicy: Max

    scaleDown:
      stabilizationWindowSeconds: 300    # Wait 5 minutes before scaling down
      policies:
        - type: Pods
          value: 2                        # Remove at most 2 Pods per scaling event
          periodSeconds: 60
```

#### HPA with Custom Metrics

```yaml
# Scale on application-level metrics (requires Prometheus Adapter or KEDA)
metrics:
  # Custom metric from Prometheus Adapter
  - type: Pods
    pods:
      metric:
        name: http_requests_per_second    # Metric name exposed by Prometheus Adapter
      target:
        type: AverageValue
        averageValue: "1000"              # Target 1000 RPS per Pod

  # External metric (e.g. SQS queue depth)
  - type: External
    external:
      metric:
        name: sqs_queue_depth
        selector:
          matchLabels:
            queue: order-processing
      target:
        type: AverageValue
        averageValue: "100"               # Scale to keep queue depth ≤ 100 per Pod
```

```bash
# Watch HPA in action
kubectl get hpa -n production --watch
# NAME            REFERENCE            TARGETS         MINPODS   MAXPODS   REPLICAS
# order-api-hpa   Deployment/order-api 68%/70%, 0/80%  3         20        5

# Describe for detailed scaling history
kubectl describe hpa order-api-hpa -n production
# ...
# Events:
#   Normal  SuccessfulRescale  2m    horizontal-pod-autoscaler
#     New size: 8; reason: cpu resource utilization (percentage of request) above target
```

---

### 2.12 Cluster Autoscaler and KEDA

HPA scales Pods. But if all nodes are at capacity, new Pods will remain `Pending` indefinitely. The **Cluster Autoscaler** solves this by adding and removing nodes.

#### Cluster Autoscaler

```
Cluster Autoscaler Control Loop:
  Scale Up:  Detect Pending Pods that cannot be scheduled due to insufficient resources
             → Find a node group that could accommodate them
             → Add nodes to that group
             → Wait for nodes to join and Pods to schedule

  Scale Down: Find underutilized nodes (all Pods can be rescheduled elsewhere)
              → Respect PodDisruptionBudgets and safe-to-evict annotations
              → Drain and terminate the node
```

```yaml
# PodDisruptionBudget — prevent Cluster Autoscaler from evicting too many Pods at once
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: order-api-pdb
  namespace: production
spec:
  minAvailable: 3             # At least 3 Pods must remain available during disruptions
  # OR: maxUnavailable: 1    # At most 1 Pod can be unavailable
  selector:
    matchLabels:
      app: order-api
```

```bash
# Check Cluster Autoscaler logs (usually deployed in kube-system)
kubectl logs -n kube-system -l app=cluster-autoscaler -f

# Annotate a node as safe-to-evict (Cluster Autoscaler will consider it for scale-down)
kubectl annotate node worker-node-3 \
  cluster-autoscaler.kubernetes.io/safe-to-evict="true"

# Prevent a specific Pod from being evicted during scale-down
kubectl annotate pod my-critical-pod \
  cluster-autoscaler.kubernetes.io/safe-to-evict="false"
```

#### KEDA — Kubernetes Event-Driven Autoscaling

KEDA extends HPA to support scaling based on external event sources — message queues, databases, HTTP request rates, cron schedules, and more. It is particularly powerful for batch processing and async workloads.

```yaml
# Scale a Deployment based on AWS SQS queue depth
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: order-processor-scaler
  namespace: production
spec:
  scaleTargetRef:
    name: order-processor           # Deployment to scale
  minReplicaCount: 0                # Scale to zero when queue is empty
  maxReplicaCount: 50
  cooldownPeriod: 300               # Wait 5 minutes before scaling to zero
  triggers:
    - type: aws-sqs-queue
      metadata:
        queueURL: https://sqs.us-east-1.amazonaws.com/123456789/orders
        queueLength: "10"           # One replica per 10 messages in queue
        awsRegion: us-east-1
      authenticationRef:
        name: keda-aws-credentials

    # Cron-based scaling (pre-scale before known traffic spikes)
    - type: cron
      metadata:
        timezone: America/New_York
        start: "0 8 * * 1-5"        # Scale up at 8am weekdays
        end: "0 20 * * 1-5"         # Scale down at 8pm weekdays
        desiredReplicas: "10"
```

---

### 2.13 kubectl Productivity

`kubectl` is your primary interface to every Kubernetes cluster you will ever operate. Mastering it pays compound dividends.

#### Essential Aliases

```bash
# Add to ~/.bashrc or ~/.zshrc
alias k='kubectl'
alias kn='kubectl -n'
alias kga='kubectl get all'
alias kgp='kubectl get pods'
alias kgd='kubectl get deployments'
alias kgs='kubectl get services'
alias kgh='kubectl get hpa'
alias kdp='kubectl describe pod'
alias kdd='kubectl describe deployment'
alias kl='kubectl logs'
alias klf='kubectl logs -f'
alias kex='kubectl exec -it'
alias kaf='kubectl apply -f'
alias kdf='kubectl delete -f'
alias kctx='kubectl config use-context'
alias kns='kubectl config set-context --current --namespace'

# Reload aliases
source ~/.bashrc
```

#### Context and Namespace Management

```bash
# List all contexts
kubectl config get-contexts

# Switch context
kubectl config use-context prod-eks-us-east-1

# Install kubectx and kubens (faster context/namespace switching)
# macOS: brew install kubectx
# kubectx: interactive context switcher
kubectx prod-eks-us-east-1
# kubens: interactive namespace switcher
kubens production

# Show current context and namespace
kubectl config current-context
kubectl config view --minify | grep namespace
```

#### Output Formatting

```bash
# Wide output (shows node, IP, etc.)
kubectl get pods -o wide

# YAML output (see full object spec + status)
kubectl get deployment order-api -o yaml

# JSON output (pipe to jq for filtering)
kubectl get pods -o json | jq '.items[].metadata.name'

# JSONPath (extract specific fields)
kubectl get pods -o jsonpath='{.items[*].metadata.name}'
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.podIP}{"\n"}{end}'

# Custom columns
kubectl get pods -o custom-columns=\
NAME:.metadata.name,\
STATUS:.status.phase,\
NODE:.spec.nodeName,\
IP:.status.podIP

# Sort by field
kubectl get pods --sort-by=.metadata.creationTimestamp
kubectl get pods --sort-by='.status.containerStatuses[0].restartCount'
```

#### Debugging Workflows

```bash
# Get events for a namespace (sorted by time — your first stop for debugging)
kubectl get events -n production --sort-by=.lastTimestamp

# Get events for a specific Pod
kubectl get events -n production --field-selector involvedObject.name=order-api-7d9b-4xk9p

# Describe a Pod (full details: events, resource requests, probe status)
kubectl describe pod order-api-7d9b-4xk9p -n production

# Logs — current and previous container instance
kubectl logs order-api-7d9b-4xk9p -n production
kubectl logs order-api-7d9b-4xk9p -n production --previous   # Logs from crashed container
kubectl logs -l app=order-api -n production --tail=100        # All Pods with this label

# Stream logs from all Pods in a Deployment
kubectl logs -f deployment/order-api -n production

# Execute a command in a running Pod
kubectl exec -it order-api-7d9b-4xk9p -n production -- sh
kubectl exec -it order-api-7d9b-4xk9p -n production -- env | grep DB

# Temporary debug container (Kubernetes 1.23+)
kubectl debug -it order-api-7d9b-4xk9p \
  --image=busybox:1.36 \
  --target=api \
  --copy-to=debug-pod \
  -n production

# Port-forward for local testing
kubectl port-forward pod/order-api-7d9b-4xk9p 8080:8080 -n production
kubectl port-forward svc/order-api 8080:80 -n production
kubectl port-forward deployment/order-api 8080:8080 -n production
```

#### Resource Management

```bash
# Apply with dry-run (validate without applying)
kubectl apply -f deployment.yaml --dry-run=client
kubectl apply -f deployment.yaml --dry-run=server    # Server-side validation (better)

# Diff — show what would change before applying
kubectl diff -f deployment.yaml

# Force replace (destructive — use only for immutable fields)
kubectl replace --force -f deployment.yaml

# Delete resources gracefully
kubectl delete pod order-api-7d9b-4xk9p -n production
kubectl delete pod order-api-7d9b-4xk9p -n production --grace-period=0   # Force

# Scale manually (overridden by HPA if configured)
kubectl scale deployment order-api --replicas=10 -n production

# Cordon a node (prevent new Pod scheduling)
kubectl cordon worker-node-3

# Drain a node (evict all Pods; used before node maintenance)
kubectl drain worker-node-3 \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --grace-period=60

# Uncordon after maintenance
kubectl uncordon worker-node-3
```

#### kubectl Plugins — krew

```bash
# Install krew (kubectl plugin manager)
# https://krew.sigs.k8s.io/docs/user-guide/setup/install/

# Essential plugins
kubectl krew install ctx          # Fast context switching
kubectl krew install ns           # Fast namespace switching
kubectl krew install neat         # Clean YAML output (remove managed fields)
kubectl krew install resource-capacity  # Node resource usage
kubectl krew install stern        # Multi-pod log tailing
kubectl krew install tree         # Show object ownership hierarchy
kubectl krew install whoami       # Show current RBAC identity

# Use plugins
kubectl stern order-api -n production     # Tail all order-api Pods
kubectl tree deployment order-api -n production  # Show RS and Pod ownership
kubectl resource-capacity --sort cpu.limit      # Node capacity overview
```

---

## 3. Step-by-Step Hands-on Walkthrough

### 3.1 Build a Complete Microservices Environment

We will deploy a realistic three-service application: an API gateway, an order service, and a notification service — with full configuration management, proper health checks, and autoscaling.

```bash
# Create namespaces
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: shop
  labels:
    env: development
    team: platform
EOF

kubectl config set-context --current --namespace=shop
```

### 3.2 Deploy the Order Service with Full Configuration

```yaml
# --- 1-configmap.yaml ---
apiVersion: v1
kind: ConfigMap
metadata:
  name: order-svc-config
  namespace: shop
data:
  APP_ENV: "development"
  LOG_LEVEL: "debug"
  PORT: "8080"
  MAX_RETRY_COUNT: "3"
  NOTIFICATION_SERVICE_URL: "http://notification-svc:8080"

---
# --- 2-secret.yaml ---
apiVersion: v1
kind: Secret
metadata:
  name: order-svc-secret
  namespace: shop
type: Opaque
stringData:
  db-password: "dev-password-123"
  jwt-secret: "dev-jwt-secret-abc"

---
# --- 3-deployment.yaml ---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-svc
  namespace: shop
  labels:
    app: order-svc
    team: commerce
  annotations:
    kubernetes.io/change-cause: "Initial deployment v1.0.0"
spec:
  replicas: 2
  selector:
    matchLabels:
      app: order-svc
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  revisionHistoryLimit: 5
  template:
    metadata:
      labels:
        app: order-svc
        version: "1.0.0"
    spec:
      terminationGracePeriodSeconds: 30
      containers:
        - name: order-svc
          image: nginx:1.25-alpine       # Placeholder image
          ports:
            - containerPort: 80
          envFrom:
            - configMapRef:
                name: order-svc-config
          env:
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: order-svc-secret
                  key: db-password
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "250m"
              memory: "256Mi"
          readinessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 5
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 15
            periodSeconds: 20
          lifecycle:
            preStop:
              exec:
                command: ["/bin/sh", "-c", "sleep 5"]

---
# --- 4-service.yaml ---
apiVersion: v1
kind: Service
metadata:
  name: order-svc
  namespace: shop
  labels:
    app: order-svc
spec:
  selector:
    app: order-svc
  ports:
    - name: http
      port: 80
      targetPort: 80
  type: ClusterIP
```

```bash
kubectl apply -f 1-configmap.yaml
kubectl apply -f 2-secret.yaml
kubectl apply -f 3-deployment.yaml
kubectl apply -f 4-service.yaml

# Verify
kubectl get all -n shop
kubectl rollout status deployment/order-svc -n shop
```

### 3.3 Configure ResourceQuota and LimitRange

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ResourceQuota
metadata:
  name: shop-quota
  namespace: shop
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 4Gi
    limits.cpu: "8"
    limits.memory: 8Gi
    pods: "20"
    services: "10"
---
apiVersion: v1
kind: LimitRange
metadata:
  name: shop-limits
  namespace: shop
spec:
  limits:
    - type: Container
      default:
        cpu: "250m"
        memory: "256Mi"
      defaultRequest:
        cpu: "100m"
        memory: "128Mi"
      max:
        cpu: "2"
        memory: "2Gi"
EOF

# Verify quota usage
kubectl describe resourcequota shop-quota -n shop
```

### 3.4 Configure HPA and Test Autoscaling

```bash
# Install metrics-server (minikube has an addon)
minikube addons enable metrics-server

# Wait for metrics-server to be ready
kubectl wait --for=condition=ready pod \
  -l k8s-app=metrics-server \
  -n kube-system \
  --timeout=60s

# Apply HPA
kubectl apply -f - <<'EOF'
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: order-svc-hpa
  namespace: shop
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: order-svc
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 30
    scaleDown:
      stabilizationWindowSeconds: 120
EOF

# Watch HPA
kubectl get hpa -n shop --watch

# Generate load to trigger scale-up (in a separate terminal)
kubectl run load-gen \
  --image=busybox:1.36 \
  --restart=Never \
  -n shop \
  -- sh -c "while true; do wget -q -O- http://order-svc/; done"

# Watch Pods scale up
kubectl get pods -n shop --watch

# Clean up load generator
kubectl delete pod load-gen -n shop
```

### 3.5 Rolling Update and Rollback Workflow

```bash
# Simulate a deployment (update image tag)
kubectl set image deployment/order-svc \
  order-svc=nginx:1.27-alpine \
  -n shop \
  --record   # Deprecated but still useful; use --annotation in newer versions

# Annotate the change cause manually (the proper approach)
kubectl annotate deployment/order-svc \
  kubernetes.io/change-cause="Release v1.1.0: upgrade nginx to 1.27" \
  -n shop

# Watch the rollout
kubectl rollout status deployment/order-svc -n shop --watch

# Check history
kubectl rollout history deployment/order-svc -n shop

# Simulate a bad deployment
kubectl set image deployment/order-svc order-svc=nginx:does-not-exist -n shop

# Watch it fail
kubectl get pods -n shop --watch
# order-svc-xxx   0/1   ErrImagePull   0   30s

# Rollback immediately
kubectl rollout undo deployment/order-svc -n shop
kubectl rollout status deployment/order-svc -n shop --watch
# deployment "order-svc" successfully rolled out
```

---

## 4. Real-World Scenario: Scaling a Flash Sale Platform

### The Problem

StyleMart runs a fashion e-commerce platform. Every Tuesday at noon they send a promotional email to 2 million subscribers. Within 60 seconds, traffic spikes from 500 to 50,000 requests per second. Their static provisioning approach (always-on 50 Pods) wastes 95% of compute budget during off-peak hours but still cannot respond fast enough to the spike, causing checkout failures in the first 90 seconds.

### The Architecture

```
Traffic spike → Ingress Controller
                    ↓
             order-svc (HPA: 3→50 replicas on CPU + RPS)
                    ↓
             inventory-svc (HPA: 2→30 replicas on CPU)
                    ↓
             notification-svc (KEDA: 0→20 replicas on SQS queue depth)
                    ↓
             Cluster Autoscaler (adds nodes when Pods pending > 30s)
```

### The Solution

**Phase 1 — HPA with pre-scale (cron trigger via KEDA):**

```yaml
# Pre-scale order-svc to 20 replicas at 11:50 AM on Tuesdays
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: order-svc-flash-sale
  namespace: production
spec:
  scaleTargetRef:
    name: order-svc
  minReplicaCount: 3
  maxReplicaCount: 50
  triggers:
    - type: cron
      metadata:
        timezone: America/New_York
        start: "50 11 * * 2"     # 11:50 AM every Tuesday
        end: "0 15 * * 2"        # 3:00 PM every Tuesday
        desiredReplicas: "20"
    - type: prometheus
      metadata:
        serverAddress: http://prometheus.monitoring:9090
        metricName: http_requests_per_second
        query: |
          sum(rate(http_requests_total{app="order-svc"}[1m]))
        threshold: "2000"         # Add a replica per 2000 RPS
```

**Phase 2 — Cluster Autoscaler configuration (EKS):**

Node group configured with:
- `minSize: 5`, `maxSize: 30`
- `--scale-down-delay-after-add=10m` (don't scale down too fast after a spike)
- Spot instances for burst capacity (70% cost saving)

**Phase 3 — PodDisruptionBudgets:**

```yaml
# Ensure checkout service never drops below 5 replicas during node scale-down
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: order-svc-pdb
spec:
  minAvailable: 5
  selector:
    matchLabels:
      app: order-svc
```

### Results

| Metric | Before | After |
|---|---|---|
| Checkout failures during first 90s of sale | 12-18% | < 0.1% |
| Monthly compute cost | $18,400 (always-on) | $6,200 (autoscaled) |
| Time to full capacity | N/A (always provisioned) | 4 minutes (node) + 45s (Pod) |
| Pre-scale warm-up time | Manual ops call 30 min before | Automated at 11:50 AM |
| P99 latency at peak | 4,200ms | 380ms |

---

## 5. Common Pitfalls & Best Practices

### Pitfall 1: No readinessProbe Means Traffic Before Readiness
A Pod without a readiness probe is marked Ready immediately when its containers start — before the application inside has finished initializing. This causes 502 errors during rolling updates as traffic is routed to Pods that are still loading configuration or establishing database connections. **Always define a readinessProbe. It is not optional.**

### Pitfall 2: Forgetting terminationGracePeriodSeconds
When Kubernetes terminates a Pod, it sends SIGTERM and then waits `terminationGracePeriodSeconds` (default: 30) before sending SIGKILL. If your application takes longer than 30 seconds to drain in-flight requests, those requests are killed mid-flight. For long-running request handlers or connection pools, increase `terminationGracePeriodSeconds` appropriately.

### Pitfall 3: Using the Default Namespace in Production
The `default` namespace has no resource quotas, no RBAC restrictions, and no separation from developer testing. Never run production workloads in `default`. Use dedicated namespaces with ResourceQuotas and RBAC policies.

### Pitfall 4: HPA and Manual Scaling Conflict
If you manually `kubectl scale deployment` while HPA is configured, HPA will immediately revert your change on its next evaluation cycle (every 15 seconds). To temporarily override HPA, either delete it or set `minReplicas` and `maxReplicas` to your desired value. Never fight the controller — work with it.

### Pitfall 5: Selectors Are Immutable
A Deployment's `spec.selector` is immutable after creation. If you need to change the selector (for example, to add a new label), you must delete and recreate the Deployment. Plan your label schema carefully before going to production.

### Pitfall 6: No PodDisruptionBudget
Without a PDB, the Cluster Autoscaler, node drains, and rolling cluster upgrades can evict all Pods of a Deployment simultaneously. For any service with `minReplicas > 1`, define a PDB with either `minAvailable` or `maxUnavailable`.

> **Production Readiness Checklist**
> - [ ] Every Deployment has a `readinessProbe` and a `livenessProbe`
> - [ ] `terminationGracePeriodSeconds` matches your application's drain time
> - [ ] Every container has `resources.requests` and `resources.limits` set
> - [ ] Every production namespace has a `ResourceQuota` and `LimitRange`
> - [ ] Every scalable service has an HPA with sane `minReplicas` and `maxReplicas`
> - [ ] Every multi-replica service has a `PodDisruptionBudget`
> - [ ] Deployment `revisionHistoryLimit` is set (5 is a reasonable default)
> - [ ] `kubernetes.io/change-cause` annotation is set on every deployment
> - [ ] Labels follow a consistent schema across all workloads
> - [ ] Services use ClusterIP internally; LoadBalancer only at the edge

---

## 6. Key Takeaways

1. **The declarative model is Kubernetes' most important design principle.** You declare desired state in a `spec`; the cluster's control loops converge toward it. Understanding that the `status` is what the cluster reports — not what you write — unlocks your mental model of how every Kubernetes operation works.

2. **Pods are the unit of scheduling, not the unit of management.** You almost never create Pods directly. Deployments create ReplicaSets which create Pods. The three-tier ownership model is what enables rolling updates, rollback, and self-healing.

3. **Services decouple consumers from Pod lifecycles.** Without Services, every consumer of a microservice would need to track Pod IP churn. The ClusterIP + DNS model gives services a stable network identity that survives rolling updates, crashes, and reschedules.

4. **ConfigMaps and Secrets are not just for 12-Factor compliance — they are operational levers.** The ability to change configuration without rebuilding images (and roll it out safely) is one of the most powerful operational patterns in Kubernetes. In production, back Secrets with Vault or External Secrets Operator.

5. **Rolling updates are safe only when readiness probes are correctly configured.** The entire zero-downtime guarantee rests on the assumption that the readiness probe accurately reflects application readiness. A lying probe (one that returns 200 before the app is ready) silently breaks your deployment strategy.

6. **Autoscaling is a system, not a feature.** HPA, Cluster Autoscaler, and KEDA must be configured and tuned together. HPA scales Pods; Cluster Autoscaler scales nodes; KEDA enables event-driven and scale-to-zero patterns. PodDisruptionBudgets protect availability during scale-down. All four are required for a production-grade autoscaling posture.

---

## 7. Exercises & Labs

**Exercise 1: Deployment Lifecycle Deep Dive**
Deploy the `order-svc` from Section 3.2 and then perform the following sequence: (a) scale from 2 to 5 replicas manually, (b) trigger a rolling update by changing the image tag, (c) watch the rollout with `kubectl rollout status --watch`, (d) introduce a bad image tag to trigger a failed rollout, (e) perform a rollback. At each step, use `kubectl get rs -n shop` to observe the ReplicaSet state and document what changes and why.

**Exercise 2: Service DNS Resolution Map**
Deploy three services in the `shop` namespace: `order-svc`, `inventory-svc`, and `notification-svc`. Deploy a `busybox` Pod in the same namespace. From inside the busybox Pod, resolve each service using all four DNS forms (short name, `name.namespace`, `name.namespace.svc`, FQDN). Then deploy the same busybox in a different namespace and verify cross-namespace DNS resolution. Document which forms work and why.

**Exercise 3: ResourceQuota Enforcement**
Create a namespace `quota-test` with a `ResourceQuota` limiting total CPU requests to `500m`. Deploy a Deployment requesting `100m` CPU per Pod. Scale it from 1 to 6 replicas and observe what happens at 5 replicas. Examine `kubectl describe resourcequota` and `kubectl get events` to understand the enforcement mechanism. Then increase the quota and observe the pending Pods schedule.

**Exercise 4: HPA Under Load**
Install `metrics-server` on your minikube cluster. Deploy the `order-svc` with CPU `requests: 100m`. Apply the HPA from Section 3.4 targeting 50% CPU utilization. Run the `load-gen` Pod to generate traffic. Using `kubectl get hpa --watch` and `kubectl get pods --watch` in two separate terminals, observe the scale-up event. Stop the load generator and observe the scale-down stabilization window delay.

**Exercise 5: Full kubectl Productivity Setup**
Set up a productive `kubectl` environment: (a) install `krew` and the `stern`, `neat`, `tree`, and `ctx` plugins, (b) add the aliases from Section 2.13 to your shell profile, (c) use `kubectl stern` to tail logs from all Pods in your `shop` namespace simultaneously, (d) use `kubectl tree` to visualize the Deployment → ReplicaSet → Pod ownership hierarchy, (e) use `kubectl neat` to export a clean version of your Deployment YAML with all managed fields stripped.

---

*End of Chapter 3*

**Next → Chapter 4: Stateful Workloads in Kubernetes**



---

──────────────────────────────────────────────────────────────────────

## Part IV: Stateful Workloads in Kubernetes

> *StatefulSets · PVCs · StorageClasses · PostgreSQL · Kafka*

──────────────────────────────────────────────────────────────────────


## 1. Introduction & Learning Objectives

For the first three chapters of this book, we have worked almost exclusively with stateless workloads — applications that treat every request as independent, hold no durable data, and can be killed and rescheduled without consequence. Kubernetes was architecturally optimized for exactly this kind of workload, and it handles it beautifully.

Real production systems, however, are never fully stateless. Behind every stateless API tier sits a database, a message broker, a distributed cache, or an object store. These components are stateful — they own data, they have identities, they form clusters where member order and membership stability matter. Running them in Kubernetes requires a fundamentally different mental model than running a web server.

This chapter is about that different mental model. We will start with a clear-eyed analysis of why state is hard in distributed systems, then build up the Kubernetes primitives that address those challenges: PersistentVolumes, PersistentVolumeClaims, StorageClasses, and StatefulSets. We will then apply these primitives to two canonical stateful workloads — a PostgreSQL cluster and an Apache Kafka cluster — and examine the failure modes, data protection strategies, and operational runbooks that production deployments require.

> **Learning Objectives**
> - Articulate the specific challenges that make stateful workloads harder than stateless ones in Kubernetes.
> - Explain the PersistentVolume subsystem: PVs, PVCs, StorageClasses, and the binding lifecycle.
> - Configure dynamic volume provisioning for the three major cloud providers.
> - Understand how StatefulSets provide stable identity, ordered deployment, and per-Pod storage.
> - Deploy a production-grade PostgreSQL cluster with streaming replication, automated failover, and backup.
> - Deploy an Apache Kafka cluster with durable storage, rack-aware partition replication, and topic management.
> - Design and execute data backup, restore, and disaster recovery procedures for stateful Kubernetes workloads.
> - Apply the correct failure mitigation patterns: PodDisruptionBudgets, anti-affinity rules, and storage topology constraints.

---

## 2. Core Concepts

### 2.1 Why State Is Hard in Distributed Systems

Before we examine solutions, we must be precise about the problems. Stateful workloads fail in Kubernetes in ways that stateless workloads simply do not, and those failures have a distinct character.

#### Problem 1: Identity Instability

Stateless Pods are interchangeable. Pod `order-api-7d9b-4xk9p` is functionally identical to `order-api-7d9b-8vr2q`. You can kill either one and the system is unaffected. But a database cluster member is not interchangeable. `postgres-0` is the primary. `postgres-1` and `postgres-2` are replicas streaming from `postgres-0`. If you restart `postgres-0` and it comes back with a new IP and a new hostname, the replicas lose their replication connection and the cluster is broken.

Stateful systems require **stable network identities** — predictable hostnames and DNS names that survive Pod restarts.

#### Problem 2: Storage Is Not Portable

A stateless Pod can be rescheduled to any node without consequence. If `order-api` moves from `worker-1` to `worker-3`, nothing changes. But if a PostgreSQL Pod moves from `worker-1` to `worker-3`, and its data directory (`/var/lib/postgresql/data`) is a `hostPath` volume on `worker-1`, it arrives at `worker-3` with an empty data directory and immediately diverges from the cluster. Or worse — it tries to start as a primary when a primary already exists.

Stateful systems require **portable, durable storage** — volumes that follow the Pod across rescheduling events.

#### Problem 3: Ordered Operations

Stateless Pods can start in any order. The third replica of `order-api` does not need to wait for the first and second. But a database cluster must bootstrap in order: the primary initializes first, then replicas connect to it. Kafka brokers must all be registered with ZooKeeper (or KRaft) before topics can be created. Cassandra nodes must be seeded from existing cluster members.

Stateful systems require **ordered, sequential operations** for startup, scaling, and shutdown.

#### Problem 4: Data Gravity

Stateless workloads are footloose. They go where the scheduler sends them. Stateful workloads have data gravity — their storage is tied to a specific availability zone, or even a specific node. A 10TB PostgreSQL volume provisioned in `us-east-1a` cannot be attached to a Pod scheduled in `us-east-1b` unless the storage backend explicitly supports multi-AZ attachment.

Stateful systems require **topology-aware scheduling** — ensuring Pods are scheduled in the same zone as their volumes.

#### The Fundamental Tradeoff

```
Kubernetes excels at:
  ✅  Ephemeral workloads       ← Stateless Pods, Jobs, CronJobs
  ✅  Horizontal scaling        ← HPA, ReplicaSets
  ✅  Self-healing              ← Liveness probes, restart policies
  ✅  Rolling updates           ← Deployments with zero-downtime strategy

Kubernetes requires extra care for:
  ⚠️  Data durability           ← PersistentVolumes, backup strategies
  ⚠️  Network identity          ← StatefulSets with stable DNS
  ⚠️  Ordered lifecycle         ← StatefulSet ordinal ordering
  ⚠️  Data topology             ← StorageClass zone constraints, PVC binding
```

---

### 2.2 PersistentVolumes — The Storage Abstraction Layer

A **PersistentVolume (PV)** is a piece of storage in the cluster that has been provisioned by an administrator or dynamically by a StorageClass. It exists independently of any Pod that uses it. Like a node is a cluster resource for compute, a PV is a cluster resource for storage.

The PersistentVolume subsystem decouples how storage is provisioned from how it is consumed:

```
┌─────────────────────────────────────────────────────────────────────┐
│  Storage Backend                                                     │
│  AWS EBS · GCE PD · Azure Disk · NFS · Ceph · Local SSD             │
└──────────────────────────────┬──────────────────────────────────────┘
                               │  CSI Driver
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│  PersistentVolume (PV)                                               │
│  Cluster-scoped resource                                             │
│  capacity: 100Gi   accessMode: ReadWriteOnce   reclaim: Retain       │
└──────────────────────────────┬──────────────────────────────────────┘
                               │  Binding (1:1)
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│  PersistentVolumeClaim (PVC)                                         │
│  Namespace-scoped resource                                           │
│  requests: 100Gi   accessMode: ReadWriteOnce   storageClass: gp3    │
└──────────────────────────────┬──────────────────────────────────────┘
                               │  volumeMount
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Pod                                                                 │
│  container: postgres   mountPath: /var/lib/postgresql/data           │
└─────────────────────────────────────────────────────────────────────┘
```

#### Access Modes

| Mode | Abbreviation | Meaning | Typical Backend |
|---|---|---|---|
| `ReadWriteOnce` | RWO | Mounted read/write by a single node | EBS, Azure Disk, GCE PD |
| `ReadOnlyMany` | ROX | Mounted read-only by many nodes simultaneously | NFS, CephFS |
| `ReadWriteMany` | RWX | Mounted read/write by many nodes simultaneously | NFS, CephFS, EFS, Azure Files |
| `ReadWriteOncePod` | RWOP | Mounted read/write by a single Pod (K8s 1.22+) | CSI volumes |

> **Critical for databases:** Most block storage backends (EBS, Azure Disk, GCE PD) support only `ReadWriteOnce`. This means only one node can mount the volume at a time — which is exactly what you want for a database primary. Shared filesystems (NFS, EFS) support `ReadWriteMany` but have higher latency and are inappropriate for transactional databases.

#### Reclaim Policies

| Policy | Behavior When PVC is Deleted |
|---|---|
| `Retain` | PV is kept; data is preserved; admin must manually reclaim |
| `Delete` | PV and the underlying storage asset are deleted |
| `Recycle` | (**Deprecated**) Basic scrub (`rm -rf /volume/*`) then made available |

**In production, always use `Retain` for databases.** `Delete` is convenient for ephemeral test environments but catastrophic if a PVC is accidentally deleted in production.

#### Manually Provisioned PersistentVolume

```yaml
# Rarely done manually in cloud environments (use StorageClasses instead)
# Most common for on-premise NFS or local SSD provisioning
apiVersion: v1
kind: PersistentVolume
metadata:
  name: postgres-pv-az1
  labels:
    type: local-ssd
    zone: us-east-1a
spec:
  capacity:
    storage: 500Gi
  volumeMode: Filesystem          # or Block (raw block device)
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-ssd     # Must match PVC storageClassName
  local:                          # Local SSD (much higher IOPS than network storage)
    path: /mnt/disks/ssd1
  nodeAffinity:                   # Local volumes require node affinity
    required:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values:
                - worker-node-az1a
```

---

### 2.3 PersistentVolumeClaims — Requesting Storage

A **PersistentVolumeClaim (PVC)** is a request for storage by a user or a StatefulSet. It is to storage what a Pod is to compute — a consumption request that the system fulfills by binding to an available PV (or dynamically provisioning one via a StorageClass).

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-data
  namespace: databases
spec:
  accessModes:
    - ReadWriteOnce
  volumeMode: Filesystem
  resources:
    requests:
      storage: 500Gi
  storageClassName: gp3-encrypted    # References a StorageClass
  # selector:                        # Optional: bind to a specific PV by label
  #   matchLabels:
  #     type: local-ssd
```

#### PVC Binding Lifecycle

```
PVC Created
    │
    ▼
Pending ──── Does a matching PV exist? ──── Yes ──→ Bound (immediate binding)
    │                                                     │
    │ No                                                   ▼
    │                                            PVC ↔ PV bound (1:1)
    │                                            Volume mounted into Pod
    ▼
Does StorageClass have WaitForFirstConsumer? ── No → Provision PV immediately
    │                                                    │
    │ Yes                                                 ▼
    ▼                                           PV created and PVC bound
Wait until Pod using PVC is scheduled
    │
    ▼
Provision PV in same AZ as scheduled node → Bound
```

The `WaitForFirstConsumer` binding mode (also called `VolumeBindingMode: WaitForFirstConsumer`) is critical for multi-AZ clusters. Without it, a PV might be provisioned in `us-east-1a` while the Pod gets scheduled in `us-east-1b`, resulting in a `VolumeNodeAffinityConflict` and a permanently pending Pod.

#### Expanding a PVC

```bash
# Resize a PVC (StorageClass must have allowVolumeExpansion: true)
kubectl patch pvc postgres-data -n databases \
  -p '{"spec":{"resources":{"requests":{"storage":"750Gi"}}}}'

# Watch the resize event
kubectl get pvc postgres-data -n databases --watch
# NAME            STATUS   VOLUME        CAPACITY   ACCESS MODES
# postgres-data   Bound    pvc-abc123    500Gi      RWO          ← before
# postgres-data   Bound    pvc-abc123    750Gi      RWO          ← after resize

# Note: The filesystem inside the volume is expanded automatically
# for most CSI drivers. Verify with: kubectl exec <pod> -- df -h /data
```

---

### 2.4 StorageClasses — Dynamic Provisioning

A **StorageClass** defines a "class" of storage, describing the provisioner (which CSI driver creates volumes), reclaim policy, volume binding mode, and backend-specific parameters. When a PVC references a StorageClass, Kubernetes dynamically provisions a PV automatically — no admin intervention required.

```yaml
# Production StorageClass: AWS EBS gp3 with encryption
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3-encrypted
  annotations:
    storageclass.kubernetes.io/is-default-class: "false"  # Do NOT make this default silently
parameters:
  type: gp3                         # EBS volume type
  iops: "6000"                      # Baseline IOPS (gp3: 3000-16000)
  throughput: "250"                  # MB/s (gp3: 125-1000)
  encrypted: "true"                  # AES-256 encryption at rest
  kmsKeyId: "arn:aws:kms:us-east-1:123456789:key/mrk-abc123"
provisioner: ebs.csi.aws.com        # AWS EBS CSI driver
reclaimPolicy: Retain               # NEVER delete in production
volumeBindingMode: WaitForFirstConsumer  # Provision in same AZ as Pod
allowVolumeExpansion: true          # Allow PVC resize without data loss
mountOptions:
  - noatime                         # Reduce write amplification on SSDs
```

#### StorageClass Examples per Cloud Provider

```yaml
# ── AWS EBS io2 (high-IOPS, for demanding databases) ─────────────
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: io2-high-iops
provisioner: ebs.csi.aws.com
parameters:
  type: io2
  iops: "64000"                     # Maximum IOPS for io2
  encrypted: "true"
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true

---
# ── Google Cloud Persistent Disk SSD ─────────────────────────────
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: pd-ssd
provisioner: pd.csi.storage.gke.io
parameters:
  type: pd-ssd
  replication-type: regional-pd     # Regional disk: survives AZ failure
  disk-encryption-key: projects/my-proj/locations/us-east1/keyRings/kr/cryptoKeys/ck
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true

---
# ── Azure Premium SSD v2 ─────────────────────────────────────────
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: premium-ssd-v2
provisioner: disk.csi.azure.com
parameters:
  skuName: PremiumV2_LRS
  DiskIOPSReadWrite: "40000"
  DiskMBpsReadWrite: "1000"
  cachingMode: None                 # Disable caching for databases (write safety)
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true

---
# ── On-premise: Local NVMe SSD (highest IOPS, no redundancy) ─────
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-nvme
provisioner: kubernetes.io/no-provisioner  # Manual provisioning required
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Retain
```

#### Volume Snapshots (Kubernetes 1.20+)

```yaml
# VolumeSnapshotClass — defines how snapshots are taken
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: ebs-snapshot-class
  annotations:
    snapshot.storage.kubernetes.io/is-default-class: "true"
driver: ebs.csi.aws.com
deletionPolicy: Retain             # Keep underlying snapshot even if object is deleted

---
# Take a snapshot of a PVC
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: postgres-data-snapshot-20240315
  namespace: databases
spec:
  volumeSnapshotClassName: ebs-snapshot-class
  source:
    persistentVolumeClaimName: postgres-data-postgres-0   # PVC to snapshot

---
# Restore from snapshot: create a new PVC from the snapshot
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-data-restored
  namespace: databases
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 500Gi
  storageClassName: gp3-encrypted
  dataSource:
    name: postgres-data-snapshot-20240315
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
```

---

### 2.5 StatefulSets — Identity-Stable Workloads

A **StatefulSet** is the Kubernetes workload API designed specifically for stateful applications. It provides three guarantees that Deployments cannot:

1. **Stable, unique network identifiers** — each Pod gets a persistent DNS name that survives rescheduling
2. **Stable, persistent storage** — each Pod gets its own PVC via a `volumeClaimTemplate`, retained even if the Pod is rescheduled
3. **Ordered, graceful deployment and scaling** — Pods are created, updated, and deleted in ordinal order (0, 1, 2...)

#### StatefulSet Identity Model

```
StatefulSet name: postgres
Replicas: 3

Pod Names (stable, ordinal):
  postgres-0   ← Always the first Pod created; typically the primary
  postgres-1
  postgres-2

Headless Service name: postgres-headless

DNS for each Pod (stable, survives rescheduling):
  postgres-0.postgres-headless.databases.svc.cluster.local → Pod IP of postgres-0
  postgres-1.postgres-headless.databases.svc.cluster.local → Pod IP of postgres-1
  postgres-2.postgres-headless.databases.svc.cluster.local → Pod IP of postgres-2

PVCs (per-Pod, retained across restarts):
  postgres-data-postgres-0   ← Only ever mounted by postgres-0
  postgres-data-postgres-1   ← Only ever mounted by postgres-1
  postgres-data-postgres-2   ← Only ever mounted by postgres-2
```

Even if `postgres-1` is killed and rescheduled to a different node, it:
- Gets the same Pod name (`postgres-1`)
- Gets the same DNS name (`postgres-1.postgres-headless.databases.svc.cluster.local`)
- Remounts the same PVC (`postgres-data-postgres-1`)
- Rejoins the cluster as the same member

This is the identity stability that distributed databases require.

#### StatefulSet Manifest — Annotated

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: databases
spec:
  serviceName: postgres-headless    # REQUIRED: must match headless Service name
  replicas: 3
  selector:
    matchLabels:
      app: postgres

  # Update strategy: OnDelete = manual Pod deletion triggers update
  # (safer than RollingUpdate for databases — gives you control)
  updateStrategy:
    type: RollingUpdate             # or OnDelete for manual control
    rollingUpdate:
      partition: 0                  # Update Pods with ordinal >= partition first
                                    # Set to 2 to update only postgres-2 initially (canary)

  podManagementPolicy: OrderedReady # Default: 0 → 1 → 2 (each waits for previous to be Ready)
  # podManagementPolicy: Parallel   # All Pods start simultaneously (for independent stateful apps)

  template:
    metadata:
      labels:
        app: postgres
    spec:
      # CRITICAL: Pods must not be on the same node (data + compute colocation for HA)
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchLabels:
                  app: postgres
              topologyKey: kubernetes.io/hostname  # Hard: one postgres Pod per node

      terminationGracePeriodSeconds: 60            # Allow WAL flush on shutdown

      containers:
        - name: postgres
          image: postgres:16.2-alpine3.19
          ports:
            - name: postgres
              containerPort: 5432
          resources:
            requests:
              memory: "2Gi"
              cpu: "500m"
            limits:
              memory: "4Gi"
              cpu: "2"
          volumeMounts:
            - name: postgres-data
              mountPath: /var/lib/postgresql/data
            - name: postgres-config
              mountPath: /etc/postgresql/postgresql.conf
              subPath: postgresql.conf
          env:
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: postgres-secret
                  key: postgres-password
            - name: PGDATA
              value: /var/lib/postgresql/data/pgdata  # Subdirectory avoids lost+found issues
          readinessProbe:
            exec:
              command: ["pg_isready", "-U", "postgres", "-d", "postgres"]
            initialDelaySeconds: 15
            periodSeconds: 10
            failureThreshold: 3
          livenessProbe:
            exec:
              command: ["pg_isready", "-U", "postgres", "-d", "postgres"]
            initialDelaySeconds: 30
            periodSeconds: 20
            failureThreshold: 6     # Higher threshold for databases (slow recovery)

      volumes:
        - name: postgres-config
          configMap:
            name: postgres-config

  # volumeClaimTemplates: Kubernetes creates one PVC per Pod automatically
  volumeClaimTemplates:
    - metadata:
        name: postgres-data         # PVC name: postgres-data-postgres-{0,1,2}
        labels:
          app: postgres
      spec:
        accessModes:
          - ReadWriteOnce
        storageClassName: gp3-encrypted
        resources:
          requests:
            storage: 500Gi
```

#### StatefulSet Scaling Behavior

```bash
# Scale up: creates postgres-3, then postgres-4 (ordered)
kubectl scale statefulset postgres --replicas=5 -n databases

# Scale down: deletes postgres-4, then postgres-3 (reverse order)
kubectl scale statefulset postgres --replicas=3 -n databases
# WARNING: PVCs are NOT deleted on scale-down
# postgres-data-postgres-3 and postgres-data-postgres-4 remain
# This is intentional — prevents accidental data loss

# Manually delete orphaned PVCs after confirming they are safe to remove
kubectl delete pvc postgres-data-postgres-4 -n databases

# Update image (rolling, respects partition)
kubectl set image statefulset/postgres postgres=postgres:16.3-alpine3.19 -n databases
kubectl rollout status statefulset/postgres -n databases

# Restart a single Pod (e.g. to reconnect a replica)
kubectl delete pod postgres-1 -n databases
# StatefulSet controller immediately recreates postgres-1 with the same identity
```

---

### 2.6 The Headless Service

StatefulSets require a **headless Service** (`clusterIP: None`) to provide stable DNS records per Pod. Unlike a regular ClusterIP Service (which load-balances across all Pods), a headless Service creates individual DNS A records for each Pod.

```yaml
# Headless Service — required for StatefulSet DNS
apiVersion: v1
kind: Service
metadata:
  name: postgres-headless
  namespace: databases
  labels:
    app: postgres
spec:
  clusterIP: None                   # Makes it headless — no VIP, no load balancing
  selector:
    app: postgres
  ports:
    - name: postgres
      port: 5432
      targetPort: 5432
  publishNotReadyAddresses: true    # Include not-yet-ready Pods in DNS
                                    # Required for cluster bootstrap (peer discovery)

---
# Regular ClusterIP Service — for application clients connecting to primary
apiVersion: v1
kind: Service
metadata:
  name: postgres-primary
  namespace: databases
spec:
  selector:
    app: postgres
    role: primary                   # Only routes to the Pod labeled as primary
  ports:
    - port: 5432
      targetPort: 5432
  type: ClusterIP

---
# Read replica Service — route read-only queries to replicas
apiVersion: v1
kind: Service
metadata:
  name: postgres-replica
  namespace: databases
spec:
  selector:
    app: postgres
    role: replica
  ports:
    - port: 5432
      targetPort: 5432
  type: ClusterIP
```

---

## 3. Production Workload: PostgreSQL with High Availability

### 3.1 Architecture Overview

We will deploy a production-grade PostgreSQL cluster using the **CloudNativePG operator** — the CNCF-recommended operator for PostgreSQL on Kubernetes. Operators encode operational knowledge (backup, failover, replication management) as code, replacing manual runbooks with automated reconciliation loops.

```
┌────────────────────────────────────────────────────────────────────┐
│  Kubernetes Cluster                                                 │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  namespace: databases                                         │  │
│  │                                                               │  │
│  │  ┌──────────────────┐         ┌──────────────────────────┐  │  │
│  │  │  postgres-1       │────────▶│  postgres-2               │  │  │
│  │  │  PRIMARY          │         │  REPLICA (sync)           │  │  │
│  │  │  WAL streaming    │         └──────────────────────────┘  │  │
│  │  │  PVC: 500Gi       │────────▶┌──────────────────────────┐  │  │
│  │  └──────────────────┘         │  postgres-3               │  │  │
│  │           │                   │  REPLICA (async)          │  │  │
│  │           │                   └──────────────────────────┘  │  │
│  │  ┌────────▼──────────────────────────────────────────────┐  │  │
│  │  │  CloudNativePG Operator                                │  │  │
│  │  │  Manages: replication, failover, backup, certs, TLS   │  │  │
│  │  └───────────────────────────────────────────────────────┘  │  │
│  │                                                               │  │
│  │  ┌──────────────────┐  ┌──────────────────────────────────┐  │  │
│  │  │  pg-backup-pvc   │  │  S3/GCS Backup Store             │  │  │
│  │  │  (WAL archive)   │  │  (daily base backups via Barman) │  │  │
│  │  └──────────────────┘  └──────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────┘
```

### 3.2 Deploy CloudNativePG Operator

```bash
# Install CloudNativePG operator via kubectl (or Helm)
kubectl apply --server-side -f \
  https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.23/releases/cnpg-1.23.0.yaml

# Verify the operator is running
kubectl get pods -n cnpg-system
# NAME                                      READY   STATUS    RESTARTS
# cnpg-controller-manager-6d4f8b9c7-xk9p2  1/1     Running   0

# Install the cnpg kubectl plugin (operational tooling)
kubectl krew install cnpg
```

### 3.3 Namespace, RBAC, and Secrets

```bash
kubectl create namespace databases

kubectl apply -f - <<'EOF'
# Backup credentials (S3)
apiVersion: v1
kind: Secret
metadata:
  name: aws-backup-creds
  namespace: databases
type: Opaque
stringData:
  ACCESS_KEY_ID: "AKIAIOSFODNN7EXAMPLE"
  ACCESS_SECRET_KEY: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
---
# PostgreSQL superuser and application credentials
apiVersion: v1
kind: Secret
metadata:
  name: postgres-app-secret
  namespace: databases
type: kubernetes.io/basic-auth
stringData:
  username: appuser
  password: "$(openssl rand -base64 32)"
EOF
```

### 3.4 PostgreSQL Cluster — Full Production Manifest

```yaml
# postgres-cluster.yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: postgres-prod
  namespace: databases
  labels:
    app: postgres
    tier: database
    env: production
spec:
  # ── Cluster size and image ────────────────────────────────────
  instances: 3                          # 1 primary + 2 replicas
  imageName: ghcr.io/cloudnative-pg/postgresql:16.2

  # ── Primary update strategy ───────────────────────────────────
  primaryUpdateStrategy: unsupervised   # Automatic failover during updates
  # primaryUpdateStrategy: supervised   # Manual promotion required (safer for prod)

  # ── PostgreSQL configuration ──────────────────────────────────
  postgresql:
    parameters:
      max_connections: "200"
      shared_buffers: "512MB"           # ~25% of container memory limit
      effective_cache_size: "1536MB"    # ~75% of container memory limit
      maintenance_work_mem: "128MB"
      checkpoint_completion_target: "0.9"
      wal_buffers: "16MB"
      default_statistics_target: "100"
      random_page_cost: "1.1"           # SSD: lower than spinning disk default (4.0)
      effective_io_concurrency: "200"   # SSDs handle concurrent I/O well
      max_wal_size: "2GB"
      min_wal_size: "512MB"
      wal_compression: "lz4"
      log_min_duration_statement: "1000"  # Log queries > 1s
      log_checkpoints: "on"
      log_connections: "on"
      log_lock_waits: "on"
      log_temp_files: "0"               # Log all temp file creation
      track_io_timing: "on"
    pg_hba:
      - "host all all 10.0.0.0/8 scram-sha-256"   # Allow cluster network

  # ── Bootstrap ─────────────────────────────────────────────────
  bootstrap:
    initdb:
      database: appdb
      owner: appuser
      secret:
        name: postgres-app-secret
      encoding: UTF8
      localeCType: C
      localeCollate: C

  # ── Superuser secret ─────────────────────────────────────────
  superuserSecret:
    name: postgres-superuser-secret

  # ── TLS (CloudNativePG manages certificates automatically) ────
  certificates:
    serverTLSSecret: ""     # Auto-generated if empty
    serverCASecret: ""

  # ── Storage ───────────────────────────────────────────────────
  storage:
    size: 500Gi
    storageClass: gp3-encrypted
    pvcTemplate:
      accessModes:
        - ReadWriteOnce
      resources:
        requests:
          storage: 500Gi

  walStorage:                           # Separate WAL volume (isolation improves recovery)
    size: 50Gi
    storageClass: gp3-encrypted

  # ── Resources ────────────────────────────────────────────────
  resources:
    requests:
      memory: "2Gi"
      cpu: "500m"
    limits:
      memory: "4Gi"
      cpu: "4"

  # ── High availability ─────────────────────────────────────────
  affinity:
    enablePodAntiAffinity: true
    topologyKey: kubernetes.io/hostname   # One replica per node
    podAntiAffinityType: required         # Hard requirement

  topologySpreadConstraints:
    - maxSkew: 1
      topologyKey: topology.kubernetes.io/zone
      whenUnsatisfiable: DoNotSchedule
      labelSelector:
        matchLabels:
          cnpg.io/cluster: postgres-prod

  # ── Backup configuration ──────────────────────────────────────
  backup:
    retentionPolicy: "30d"              # Keep 30 days of backups
    barmanObjectStore:
      destinationPath: s3://my-pg-backups/postgres-prod
      s3Credentials:
        accessKeyId:
          name: aws-backup-creds
          key: ACCESS_KEY_ID
        secretAccessKey:
          name: aws-backup-creds
          key: ACCESS_SECRET_KEY
      wal:
        compression: gzip
        maxParallel: 8                  # Parallel WAL upload workers
      data:
        compression: gzip
        immediateCheckpoint: true       # Ensure clean base backup
        jobs: 4

  # ── Monitoring ───────────────────────────────────────────────
  monitoring:
    enablePodMonitor: true              # Creates a Prometheus PodMonitor

  # ── Scheduled backup ─────────────────────────────────────────
  # Defined as a separate ScheduledBackup resource (see below)
```

### 3.5 Scheduled Backups

```yaml
# scheduled-backup.yaml
apiVersion: postgresql.cnpg.io/v1
kind: ScheduledBackup
metadata:
  name: postgres-prod-daily
  namespace: databases
spec:
  schedule: "0 2 * * *"               # Daily at 2 AM UTC
  backupOwnerReference: self
  cluster:
    name: postgres-prod
  target: primary                     # Always backup from primary

---
# Point-in-time recovery backup (continuous WAL archiving is automatic)
# To restore to a specific timestamp:
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: postgres-restored
  namespace: databases
spec:
  instances: 1
  bootstrap:
    recovery:
      source: postgres-prod
      recoveryTarget:
        targetTime: "2024-03-15 14:30:00.000000+00"  # PITR target
  externalClusters:
    - name: postgres-prod
      barmanObjectStore:
        destinationPath: s3://my-pg-backups/postgres-prod
        s3Credentials:
          accessKeyId:
            name: aws-backup-creds
            key: ACCESS_KEY_ID
          secretAccessKey:
            name: aws-backup-creds
            key: ACCESS_SECRET_KEY
  storage:
    size: 500Gi
    storageClass: gp3-encrypted
```

### 3.6 Operating the PostgreSQL Cluster

```bash
# Apply the cluster
kubectl apply -f postgres-cluster.yaml
kubectl apply -f scheduled-backup.yaml

# Watch cluster bootstrap (takes 3-5 minutes)
kubectl get cluster postgres-prod -n databases --watch
# NAME            AGE   INSTANCES   READY   STATUS                   PRIMARY
# postgres-prod   10s   3           0       Setting up primary        
# postgres-prod   2m    3           1       Creating replica 1-2      
# postgres-prod   4m    3           3       Cluster in healthy state   postgres-prod-1

# Get the status of all cluster instances
kubectl cnpg status postgres-prod -n databases
# Cluster Summary
# Name: postgres-prod     Namespace: databases     PostgreSQL Image: ... 16.2
# Instances: 3           Ready: 3                  Status: Cluster in healthy state
# Primary instance: postgres-prod-1
#
# Instances status
# Name               Database Size  Current LSN  Replication Lag  Status  Node
# postgres-prod-1    2.3 GB         0/7E000000   -                Primary  worker-1
# postgres-prod-2    2.3 GB         0/7E000000   0.00s            Standby  worker-2
# postgres-prod-3    2.3 GB         0/7DFFF000   0.10s            Standby  worker-3

# Trigger a manual failover (promote postgres-prod-2 to primary)
kubectl cnpg promote postgres-prod postgres-prod-2 -n databases
# Waiting for postgres-prod-2 to be promoted...
# postgres-prod-2 is now the primary instance

# Run a psql session against the primary
kubectl cnpg psql postgres-prod -n databases
# psql (16.2)
# Type "help" for help.
# postgres=#

# Trigger an immediate backup
kubectl cnpg backup postgres-prod -n databases
kubectl get backup -n databases

# Check replication lag
kubectl exec -n databases postgres-prod-1 -- \
  psql -U postgres -c "SELECT application_name, state, sent_lsn, write_lsn, flush_lsn, replay_lsn, sync_state FROM pg_stat_replication;"
```

### 3.7 PodDisruptionBudget for PostgreSQL

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: postgres-prod-pdb
  namespace: databases
spec:
  # Never allow more than 1 PostgreSQL Pod to be unavailable simultaneously
  # This ensures the cluster always has quorum (at least 2 of 3 running)
  maxUnavailable: 1
  selector:
    matchLabels:
      cnpg.io/cluster: postgres-prod
```

---

## 4. Production Workload: Apache Kafka with Durable Storage

### 4.1 Architecture Overview

Apache Kafka is one of the most demanding stateful workloads to run in Kubernetes. It combines the identity stability requirements of a database with the throughput requirements of a streaming platform. Each Kafka broker:

- Owns specific topic partitions and their replicas
- Has a stable broker ID that persists across restarts
- Stores gigabytes to terabytes of data on local disk
- Communicates with other brokers and clients using its stable hostname

We will use the **Strimzi operator** — the CNCF-graduated project for Kafka on Kubernetes — which automates broker management, topic provisioning, user management, TLS, and rolling upgrades.

```
┌──────────────────────────────────────────────────────────────────────┐
│  namespace: kafka                                                     │
│                                                                       │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  Kafka Cluster (KRaft mode — no ZooKeeper dependency)         │   │
│  │                                                                │   │
│  │  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐     │   │
│  │  │  kafka-0       │  │  kafka-1       │  │  kafka-2       │     │   │
│  │  │  Broker+Ctrl  │  │  Broker+Ctrl  │  │  Broker+Ctrl  │     │   │
│  │  │  PVC: 1Ti      │  │  PVC: 1Ti      │  │  PVC: 1Ti      │     │   │
│  │  │  AZ: us-east-1a│  │  AZ: us-east-1b│  │  AZ: us-east-1c│     │   │
│  │  └───────────────┘  └───────────────┘  └───────────────┘     │   │
│  │                                                                │   │
│  │  Replication Factor: 3   Min In-Sync Replicas: 2              │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                       │
│  ┌──────────────────┐   ┌─────────────────────────────────────────┐ │
│  │  Strimzi Operator│   │  Schema Registry · Kafka Connect         │ │
│  └──────────────────┘   └─────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────┘
```

### 4.2 Install Strimzi Operator

```bash
kubectl create namespace kafka

# Install Strimzi operator
kubectl create -f https://strimzi.io/install/latest?namespace=kafka -n kafka

# Wait for operator
kubectl wait --for=condition=ready pod \
  -l name=strimzi-cluster-operator \
  -n kafka \
  --timeout=120s
```

### 4.3 Kafka Cluster — Full Production Manifest

```yaml
# kafka-cluster.yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: kafka-prod
  namespace: kafka
spec:
  kafka:
    version: 3.7.0
    replicas: 3

    # ── KRaft mode (no ZooKeeper) ─────────────────────────────
    # KRaft is production-ready from Kafka 3.3+
    # Eliminates ZooKeeper operational complexity

    # ── Listeners ────────────────────────────────────────────
    listeners:
      - name: plain
        port: 9092
        type: internal
        tls: false
      - name: tls
        port: 9093
        type: internal
        tls: true
        authentication:
          type: tls
      - name: external
        port: 9094
        type: loadbalancer
        tls: true
        authentication:
          type: tls
        configuration:
          bootstrap:
            annotations:
              service.beta.kubernetes.io/aws-load-balancer-type: nlb

    # ── Authentication and authorization ─────────────────────
    authorization:
      type: simple                      # ACL-based authorization

    # ── Kafka configuration ───────────────────────────────────
    config:
      # Replication and durability
      offsets.topic.replication.factor: 3
      transaction.state.log.replication.factor: 3
      transaction.state.log.min.isr: 2
      default.replication.factor: 3
      min.insync.replicas: 2            # Must have 2 in-sync replicas for acks=all

      # Performance
      num.network.threads: 8
      num.io.threads: 16
      socket.send.buffer.bytes: 102400
      socket.receive.buffer.bytes: 102400
      socket.request.max.bytes: 104857600
      num.partitions: 6                 # Default partitions per topic
      num.recovery.threads.per.data.dir: 4

      # Retention
      log.retention.hours: 168          # 7-day default retention
      log.segment.bytes: 1073741824     # 1GB segment files
      log.retention.check.interval.ms: 300000
      log.cleanup.policy: delete

      # Compression
      compression.type: lz4

    # ── Storage ───────────────────────────────────────────────
    storage:
      type: persistent-claim
      size: 1Ti
      class: gp3-encrypted
      deleteClaim: false               # NEVER delete PVC when Kafka is deleted
      kraftMetadata: shared            # KRaft metadata stored on same volume

    # ── Resources ─────────────────────────────────────────────
    resources:
      requests:
        memory: 8Gi
        cpu: "2"
      limits:
        memory: 16Gi
        cpu: "8"

    # ── JVM tuning ────────────────────────────────────────────
    jvmOptions:
      -Xms: 4096m
      -Xmx: 8192m                      # 50% of container memory limit
      -XX:
        UseG1GC: true
        MaxGCPauseMillis: 20
        InitiatingHeapOccupancyPercent: 35
        ExplicitGCInvokesConcurrent: true

    # ── Rack awareness (one broker per AZ) ───────────────────
    rack:
      topologyKey: topology.kubernetes.io/zone

    # ── Anti-affinity ─────────────────────────────────────────
    template:
      pod:
        affinity:
          podAntiAffinity:
            requiredDuringSchedulingIgnoredDuringExecution:
              - labelSelector:
                  matchLabels:
                    strimzi.io/name: kafka-prod-kafka
                topologyKey: kubernetes.io/hostname
        terminationGracePeriodSeconds: 120   # Allow leader re-election before SIGKILL

    # ── Metrics ───────────────────────────────────────────────
    metricsConfig:
      type: jmxPrometheusExporter
      valueFrom:
        configMapKeyRef:
          name: kafka-metrics
          key: kafka-metrics-config.yml

  # ── Entity operator (manages Topics and Users) ─────────────
  entityOperator:
    topicOperator:
      resources:
        requests:
          memory: 256Mi
          cpu: "100m"
        limits:
          memory: 512Mi
          cpu: "500m"
    userOperator:
      resources:
        requests:
          memory: 256Mi
          cpu: "100m"
        limits:
          memory: 512Mi
          cpu: "500m"
```

### 4.4 Topic and User Management via Operators

```yaml
# orders-topic.yaml — manage topics declaratively
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: orders
  namespace: kafka
  labels:
    strimzi.io/cluster: kafka-prod
spec:
  partitions: 12                  # 12 partitions = 12 maximum parallel consumers
  replicas: 3                     # Replicate to all 3 brokers
  config:
    retention.ms: "604800000"     # 7 days in milliseconds
    retention.bytes: "10737418240"   # 10GB per partition max
    min.insync.replicas: "2"      # Require 2 ISR for producer acks=all
    cleanup.policy: delete
    compression.type: lz4
    max.message.bytes: "1048576"  # 1MB max message size

---
# payments-topic.yaml — longer retention, smaller messages
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: payments
  namespace: kafka
  labels:
    strimzi.io/cluster: kafka-prod
spec:
  partitions: 6
  replicas: 3
  config:
    retention.ms: "2592000000"    # 30 days (compliance requirement)
    min.insync.replicas: "2"
    compression.type: gzip        # Higher compression for archival
    cleanup.policy: compact       # Log compaction: keep latest value per key

---
# order-processor-user.yaml — fine-grained ACLs
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaUser
metadata:
  name: order-processor
  namespace: kafka
  labels:
    strimzi.io/cluster: kafka-prod
spec:
  authentication:
    type: tls                     # mTLS authentication; cert auto-provisioned
  authorization:
    type: simple
    acls:
      - resource:
          type: topic
          name: orders
          patternType: literal
        operations: [Read, Describe]
        host: "*"
      - resource:
          type: group
          name: order-processor-group
          patternType: prefix
        operations: [Read]
        host: "*"
      - resource:
          type: topic
          name: payments
          patternType: literal
        operations: [Write, Describe]
        host: "*"
```

### 4.5 PodDisruptionBudget for Kafka

```yaml
# Ensure at most 1 Kafka broker is unavailable at a time
# This preserves min.insync.replicas=2 guarantee during cluster operations
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: kafka-prod-pdb
  namespace: kafka
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      strimzi.io/name: kafka-prod-kafka
```

### 4.6 Operating the Kafka Cluster

```bash
# Apply the cluster
kubectl apply -f kafka-cluster.yaml
kubectl apply -f orders-topic.yaml
kubectl apply -f payments-topic.yaml
kubectl apply -f order-processor-user.yaml

# Watch cluster bootstrap (5-10 minutes)
kubectl get kafka kafka-prod -n kafka --watch
# NAME         DESIRED KAFKA REPLICAS  READY KAFKA REPLICAS   ...  READY
# kafka-prod   3                       3                            True

# Check broker status
kubectl get pods -n kafka -l strimzi.io/name=kafka-prod-kafka
# NAME               READY   STATUS    RESTARTS   AGE
# kafka-prod-kafka-0 1/1     Running   0          10m
# kafka-prod-kafka-1 1/1     Running   0          8m
# kafka-prod-kafka-2 1/1     Running   0          6m

# Produce test messages (using the Strimzi kafka-producer tool)
kubectl run kafka-producer -it \
  --image=quay.io/strimzi/kafka:0.40.0-kafka-3.7.0 \
  --restart=Never \
  -n kafka \
  -- bin/kafka-console-producer.sh \
  --bootstrap-server kafka-prod-kafka-bootstrap:9092 \
  --topic orders

# Consume test messages
kubectl run kafka-consumer -it \
  --image=quay.io/strimzi/kafka:0.40.0-kafka-3.7.0 \
  --restart=Never \
  -n kafka \
  -- bin/kafka-console-consumer.sh \
  --bootstrap-server kafka-prod-kafka-bootstrap:9092 \
  --topic orders \
  --from-beginning \
  --max-messages 10

# Describe topic (partition assignment and replication)
kubectl exec -n kafka kafka-prod-kafka-0 -- \
  bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --describe \
  --topic orders
# Topic: orders  PartitionCount: 12  ReplicationFactor: 3
# Partition: 0   Leader: 2   Replicas: 2,0,1   Isr: 2,0,1
# Partition: 1   Leader: 0   Replicas: 0,1,2   Isr: 0,1,2
# ...

# Check consumer group lag (how far behind a consumer is)
kubectl exec -n kafka kafka-prod-kafka-0 -- \
  bin/kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 \
  --describe \
  --group order-processor-group
# GROUP                  TOPIC   PARTITION  CURRENT-OFFSET  LOG-END-OFFSET  LAG
# order-processor-group  orders  0          1024            1025            1
# order-processor-group  orders  1          2048            2048            0
```

---

## 5. Step-by-Step Hands-on Walkthrough

### 5.1 Deploy a StatefulSet with Persistent Storage (minikube)

```bash
# Enable the CSI driver addon in minikube
minikube addons enable csi-hostpath-driver
minikube addons enable volumesnapshots

# Verify storage classes
kubectl get storageclass
# NAME                  PROVISIONER
# standard (default)    k8s.io/minikube-hostpath
# csi-hostpath-sc       hostpath.csi.k8s.io

# Create namespace
kubectl create namespace stateful-demo
kubectl config set-context --current --namespace=stateful-demo
```

```yaml
# redis-statefulset.yaml — Redis as a simple, demonstrable stateful workload
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: redis-config
  namespace: stateful-demo
data:
  redis.conf: |
    appendonly yes
    appendfsync everysec
    save 900 1
    save 300 10
    save 60 10000
    maxmemory 256mb
    maxmemory-policy allkeys-lru
    bind 0.0.0.0
    protected-mode no

---
apiVersion: v1
kind: Service
metadata:
  name: redis-headless
  namespace: stateful-demo
spec:
  clusterIP: None
  selector:
    app: redis
  ports:
    - port: 6379
      targetPort: 6379
  publishNotReadyAddresses: true

---
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: stateful-demo
spec:
  selector:
    app: redis
    role: primary
  ports:
    - port: 6379
      targetPort: 6379

---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis
  namespace: stateful-demo
spec:
  serviceName: redis-headless
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
        role: primary
    spec:
      terminationGracePeriodSeconds: 30
      containers:
        - name: redis
          image: redis:7.2-alpine
          command: ["redis-server", "/etc/redis/redis.conf"]
          ports:
            - containerPort: 6379
          resources:
            requests:
              memory: "128Mi"
              cpu: "100m"
            limits:
              memory: "256Mi"
              cpu: "250m"
          volumeMounts:
            - name: redis-data
              mountPath: /data
            - name: redis-config
              mountPath: /etc/redis
          readinessProbe:
            exec:
              command: ["redis-cli", "ping"]
            initialDelaySeconds: 5
            periodSeconds: 10
          livenessProbe:
            exec:
              command: ["redis-cli", "ping"]
            initialDelaySeconds: 15
            periodSeconds: 20
      volumes:
        - name: redis-config
          configMap:
            name: redis-config
  volumeClaimTemplates:
    - metadata:
        name: redis-data
      spec:
        accessModes: [ReadWriteOnce]
        storageClassName: standard
        resources:
          requests:
            storage: 5Gi
```

```bash
kubectl apply -f redis-statefulset.yaml

# Watch the StatefulSet bootstrap
kubectl get pods -n stateful-demo --watch
# NAME      READY   STATUS              RESTARTS
# redis-0   0/1     ContainerCreating   0
# redis-0   1/1     Running             0

# Verify PVC was created
kubectl get pvc -n stateful-demo
# NAME               STATUS   VOLUME     CAPACITY   ACCESS MODES   STORAGECLASS
# redis-data-redis-0 Bound    pvc-abc123 5Gi        RWO            standard

# Write data to Redis
kubectl exec -n stateful-demo redis-0 -- redis-cli set greeting "Hello, Kubernetes!"
kubectl exec -n stateful-demo redis-0 -- redis-cli get greeting
# "Hello, Kubernetes!"

# Delete the Pod — simulates a crash/reschedule
kubectl delete pod redis-0 -n stateful-demo

# StatefulSet immediately recreates it
kubectl get pods -n stateful-demo --watch
# redis-0   0/1   Terminating   0   5m
# redis-0   0/1   Pending       0   1s
# redis-0   0/1   ContainerCreating  0   2s
# redis-0   1/1   Running       0   8s

# Verify data persisted (PVC remounted)
kubectl exec -n stateful-demo redis-0 -- redis-cli get greeting
# "Hello, Kubernetes!"   ← Data survived Pod restart
```

### 5.2 Test PVC Persistence Through Pod Deletion

```bash
# Verify the PVC is still bound even if we delete the StatefulSet
kubectl delete statefulset redis -n stateful-demo --cascade=orphan
# Pod is orphaned, StatefulSet is gone
# PVC is still present

kubectl get pvc -n stateful-demo
# NAME                STATUS   VOLUME      CAPACITY   ACCESS MODES
# redis-data-redis-0  Bound    pvc-abc123  5Gi        RWO         ← Still exists

# Recreate the StatefulSet — it will reuse the existing PVC
kubectl apply -f redis-statefulset.yaml

kubectl exec -n stateful-demo redis-0 -- redis-cli get greeting
# "Hello, Kubernetes!"   ← Data survived StatefulSet deletion and recreation
```

### 5.3 Volume Snapshot and Restore

```bash
# Take a snapshot
kubectl apply -f - <<'EOF'
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: redis-data-snapshot
  namespace: stateful-demo
spec:
  volumeSnapshotClassName: csi-hostpath-snapclass
  source:
    persistentVolumeClaimName: redis-data-redis-0
EOF

kubectl get volumesnapshot -n stateful-demo --watch
# NAME                  READYTOUSE   SOURCEPVC            AGE
# redis-data-snapshot   true         redis-data-redis-0   30s

# Restore from snapshot (creates a new PVC)
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: redis-data-restored
  namespace: stateful-demo
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 5Gi
  storageClassName: csi-hostpath-sc
  dataSource:
    name: redis-data-snapshot
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
EOF

# Mount the restored PVC in a temporary Pod to verify contents
kubectl run restore-verify \
  --image=redis:7.2-alpine \
  --rm -it \
  --restart=Never \
  -n stateful-demo \
  --overrides='{"spec":{"volumes":[{"name":"data","persistentVolumeClaim":{"claimName":"redis-data-restored"}}],"containers":[{"name":"restore-verify","image":"redis:7.2-alpine","command":["redis-server","--appendonly","yes"],"volumeMounts":[{"mountPath":"/data","name":"data"}]}]}}' \
  -- redis-cli get greeting
```

---

## 6. Real-World Scenario: Financial Services Event Sourcing Platform

### The Problem

FinStream, a fintech company, runs an event-sourcing architecture where every financial transaction is written to Kafka and then projected into PostgreSQL read models. Their current on-premise setup has three pain points:

- Kafka rebalances take 8-12 minutes when a broker host is patched, causing consumer lag spikes and downstream SLA violations.
- PostgreSQL failover requires a 4-minute manual process (phone call to DBA, SSH, `pg_ctl promote`), violating their 2-minute RTO SLA.
- Storage allocation is manual — adding disk to Kafka brokers requires a weekend maintenance window.

### The Architecture

```
Producers (Trading Systems)
    │
    ▼
Kafka Cluster (3 brokers, KRaft, Strimzi)
    │
    ├─── Kafka Connect (CDC from legacy Oracle DB)
    │
    ▼
Order Processor Service (consumer group, 12 instances)
    │
    ▼
PostgreSQL (CloudNativePG, 1 primary + 2 replicas)
    │
    ├─── postgres-primary:5432 (writes)
    └─── postgres-replica:5432 (reads, reporting)
```

### Key Design Decisions

**Kafka broker restart strategy:** Strimzi uses rolling updates with a `maxUnavailable: 1` constraint and waits for all partition replicas to re-sync (ISR == RF) before proceeding to the next broker. Rebalance time is now under 90 seconds.

**PostgreSQL automatic failover:** CloudNativePG monitors replication lag with a configurable `primaryMaxSwitchoverDelay`. When the primary becomes unhealthy, the operator promotes the most up-to-date replica within 30 seconds — well within the 2-minute RTO.

**Dynamic storage expansion:** When Kafka partition count grows and storage utilization exceeds 80%, an alert fires. The operator patches the `volumeClaimTemplate` storage size. The EBS CSI driver resizes the volume without Pod restart.

### Results

| Metric | On-Premise | Kubernetes |
|---|---|---|
| Kafka broker patch time | 8-12 min consumer lag spike | < 90 sec (rolling, ISR-aware) |
| PostgreSQL failover time | 4 min manual | 30 sec automated |
| Storage expansion | Weekend maintenance window | Online, zero-downtime |
| Backup verification frequency | Monthly (manual) | Daily (automated PITR test) |
| Infrastructure cost | $42,000/month (bare metal) | $18,500/month (spot + reserved) |

---

## 7. Common Pitfalls & Best Practices

### Pitfall 1: Using Deployments for Stateful Workloads
A Deployment with a PVC can work for a single-replica database in development, but it does not provide stable Pod identity and will create conflicting mounts if you ever scale beyond one replica. For any stateful application, use a StatefulSet — even for single-replica deployments.

### Pitfall 2: Forgetting PGDATA Subdirectory
When mounting a PVC at `/var/lib/postgresql/data`, PostgreSQL refuses to initialize if the directory contains anything other than its own files. Newly created EBS volumes formatted with ext4 contain a `lost+found` directory. Fix: set `PGDATA=/var/lib/postgresql/data/pgdata` to use a subdirectory as the actual data directory.

### Pitfall 3: Using Delete Reclaim Policy in Production
`reclaimPolicy: Delete` means that deleting a PVC — which a team member may do accidentally, or an automation script may do during a namespace cleanup — permanently deletes the underlying EBS volume and all data on it. In production, always use `Retain`. Implement a separate data lifecycle management process for manual volume cleanup.

### Pitfall 4: No PodDisruptionBudget on Database Clusters
Without a PDB, a `kubectl drain` during cluster maintenance or an autoscaler scale-down can evict multiple database Pods simultaneously, reducing the cluster below quorum. For a 3-node cluster with `min.insync.replicas=2`, losing 2 brokers simultaneously stops all writes. Always set `maxUnavailable: 1` on stateful clusters.

### Pitfall 5: Single-AZ Storage for Multi-AZ Clusters
Provisioning all Kafka PVCs in `us-east-1a` while pods are spread across three AZs means that if `us-east-1a` has an outage, you lose not just `kafka-0` but also prevent `kafka-1` and `kafka-2` from mounting replacement volumes. Use `WaitForFirstConsumer` binding mode and topology spread constraints to ensure each broker's PVC is in the same AZ as its Pod.

### Pitfall 6: Skipping Backup Verification
Teams frequently implement backup jobs but never test restores. A backup that has never been restored is not a backup — it is an untested assumption. Implement automated daily restore verification: restore the latest backup to a temporary namespace, run a data integrity check, and alert if the restore fails or takes longer than expected.

> **Stateful Workloads Production Checklist**
> - [ ] All stateful workloads use StatefulSets, not Deployments
> - [ ] Every PV has `reclaimPolicy: Retain`
> - [ ] StorageClass uses `WaitForFirstConsumer` binding mode in multi-AZ clusters
> - [ ] StatefulSet Pods have `podAntiAffinity` requiring one Pod per node
> - [ ] Topology spread constraints ensure Pods are distributed across AZs
> - [ ] PodDisruptionBudgets protect clusters during node maintenance
> - [ ] Automated backups are scheduled and alerts fire on failure
> - [ ] Restore procedure is tested and documented with measured RTO
> - [ ] PVC expansion is enabled (`allowVolumeExpansion: true`) on StorageClass
> - [ ] Separate WAL/log volumes from data volumes for performance isolation
> - [ ] Database Pods have higher `terminationGracePeriodSeconds` (60-120s)
> - [ ] Storage utilization alerts fire at 70% (not 90%) to allow time for expansion

---

## 8. Key Takeaways

1. **State is hard because it breaks Kubernetes' core assumptions.** Stateless Pods are interchangeable, portable, and disposable. Stateful Pods require identity stability, portable storage, and ordered lifecycle — properties that require dedicated primitives: StatefulSets, PersistentVolumes, and StorageClasses.

2. **The PV/PVC abstraction cleanly separates provisioning from consumption.** Administrators or StorageClasses provision PVs. Applications request storage via PVCs. This decoupling means application manifests do not need to know about the underlying storage backend — only the StorageClass name.

3. **`WaitForFirstConsumer` is mandatory for multi-AZ production clusters.** Immediate volume binding in a multi-AZ cluster leads to cross-AZ volume-to-Pod mismatches that result in permanently pending Pods. Always use `WaitForFirstConsumer` for database workloads in cloud environments.

4. **StatefulSets provide the three guarantees that distributed databases need:** stable network identity (predictable hostnames), stable storage (per-Pod PVCs that survive rescheduling), and ordered lifecycle (sequential create/delete). These map directly to the failure modes described in Section 2.1.

5. **Operators are the production-grade approach for complex stateful workloads.** Manually managing PostgreSQL streaming replication or Kafka broker replacement in Kubernetes is fragile and operationally expensive. Operators like CloudNativePG and Strimzi encode years of operational knowledge — failover logic, backup orchestration, rolling upgrades — as automated reconciliation loops.

6. **Backup and restore strategy must be designed before deployment, not after.** The questions "How do I back this up?", "How do I restore it?", and "What is my RTO/RPO?" must be answered before a stateful workload goes to production. Snapshot-based backups, WAL archiving for PITR, and automated restore verification are the three legs of a production data protection strategy.

---

## 9. Exercises & Labs

**Exercise 1: StatefulSet Identity Experiment**
Deploy the Redis StatefulSet from Section 5.1. Write a known key-value pair to `redis-0`. Then: (a) delete `redis-0` and observe the StatefulSet recreate it with the same identity, (b) verify the data survived the restart via the remounted PVC, (c) scale the StatefulSet to 3 replicas and observe the ordered creation of `redis-1` and `redis-2`, (d) scale back to 1 and observe that the PVCs for `redis-1` and `redis-2` are retained. Document the PVC names at each step.

**Exercise 2: StorageClass Deep Dive**
On your minikube cluster, create two StorageClasses: one with `reclaimPolicy: Retain` and one with `reclaimPolicy: Delete`. Create a PVC from each. Write data to a Pod using each PVC. Then delete both PVCs. Observe what happens to each PV. Try to manually rebind the `Retain`-policy PV to a new PVC by removing its `claimRef`. Document the full lifecycle including the manual reclaim steps.

**Exercise 3: Volume Snapshot and Point-in-Time Restore**
Using the snapshot workflow from Section 5.3: (a) write 100 keys to Redis with timestamps as values, (b) take a VolumeSnapshot, (c) write 100 more keys, (d) restore from the snapshot to a new PVC, (e) mount the restored PVC in a temporary Pod and verify that only the first 100 keys exist. This simulates a PITR restore scenario.

**Exercise 4: PodDisruptionBudget Enforcement**
Deploy a StatefulSet with 3 replicas. Create a PDB with `maxUnavailable: 1`. Then attempt to `kubectl drain` two nodes simultaneously. Observe that the second drain is blocked by the PDB. Check `kubectl get pdb` and `kubectl describe pdb` to understand the enforcement mechanism. Clean up by completing the drain sequentially.

**Exercise 5: Kafka Topic Operations with Strimzi**
If you have access to a cloud cluster: install Strimzi and deploy the Kafka cluster from Section 4.3 with 3 brokers. Create the `orders` topic declaratively using the `KafkaTopic` resource. Produce 1,000 messages using the kafka-console-producer. Run a consumer group and observe the partition assignment. Then delete `kafka-prod-kafka-1` (simulating a broker failure) and observe: (a) partition leader re-election, (b) how Strimzi automatically recreates the broker Pod, (c) how ISR recovers after the broker rejoins. Use `kafka-topics.sh --describe` to document the ISR state at each step.

---

*End of Chapter 4*

**Next → Chapter 5: Amazon Elastic Kubernetes Service (EKS)**



---

──────────────────────────────────────────────────────────────────────

## Part V: Amazon Elastic Kubernetes Service

> *EKS · VPC CNI · IRSA · ALB Controller · CloudWatch*

──────────────────────────────────────────────────────────────────────


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



---

──────────────────────────────────────────────────────────────────────

## Part VI: Azure Kubernetes Service

> *AKS · Azure CNI · Workload Identity · KEDA · Azure DevOps*

──────────────────────────────────────────────────────────────────────


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
│                                                                           │
│  ┌──────────────────────────────────────────────┐                        │
│  │  AKS Control Plane (Multi-region, managed)   │                        │
│  │                                              │                        │
│  │  kube-apiserver  etcd  Scheduler  Controller │                        │
│  │                                              │                        │
│  │  ✅ Free — no hourly control plane charge     │                        │
│  │  ✅ Auto-patched, SLA-backed (99.95% Uptime)  │                        │
│  │  ✅ Automatic etcd backups                    │                        │
│  └──────────────────────────────────────────────┘                        │
│                         │  Kubernetes API                                 │
│  ┌──────────────────────▼───────────────────────────────────────────┐   │
│  │  Your Azure Virtual Network                                       │   │
│  │                                                                   │   │
│  │  ┌────────────────────────────────────────────────────────────┐  │   │
│  │  │  System Node Pool (CriticalAddonsOnly taint)               │  │   │
│  │  │  Hosts: CoreDNS, metrics-server, konnectivity-agent        │  │   │
│  │  │  Recommended: D4s_v5 × 3 nodes, across 3 AZs              │  │   │
│  │  └────────────────────────────────────────────────────────────┘  │   │
│  │                                                                   │   │
│  │  ┌────────────────────────────────────────────────────────────┐  │   │
│  │  │  User Node Pool(s)  — your workloads                       │  │   │
│  │  │  Spot Pool · GPU Pool · Memory Pool · General Pool         │  │   │
│  │  └────────────────────────────────────────────────────────────┘  │   │
│  │                                                                   │   │
│  │  Azure Load Balancer · Azure CNI · Azure Disk/File CSI            │   │
│  │  Azure Container Registry · Key Vault · Azure Monitor            │   │
│  └───────────────────────────────────────────────────────────────────┘  │
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
│  Pod                                                          │
│  serviceAccountName: order-api-sa                             │
│  Azure Workload Identity webhook injects:                     │
│    AZURE_CLIENT_ID    (Managed Identity client ID)            │
│    AZURE_TENANT_ID                                            │
│    AZURE_FEDERATED_TOKEN_FILE  (/var/run/secrets/.../token)   │
└───────────────────────────────┬──────────────────────────────┘
                                │ Token exchange
                                ▼
┌──────────────────────────────────────────────────────────────┐
│  Azure AD (OIDC token validated against AKS OIDC issuer)     │
└───────────────────────────────┬──────────────────────────────┘
                                │ Federated credential matched
                                ▼
┌──────────────────────────────────────────────────────────────┐
│  User-Assigned Managed Identity: order-api-identity           │
│  Role assignments:                                            │
│    Key Vault Secrets User → kv-production                     │
│    Storage Blob Data Reader → sa-order-assets                 │
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



---

──────────────────────────────────────────────────────────────────────

## Part VII: Google Kubernetes Engine

> *GKE · Autopilot · Dataplane V2 · Cloud Armor · Cloud Build*

──────────────────────────────────────────────────────────────────────


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
┌─────────────────────────────────────────────────────────────────────────┐
│  GKE Standard                       GKE Autopilot                       │
│  ─────────────────────────────────────────────────────────────────────  │
│                                                                          │
│  You manage:                        Google manages:                      │
│  ├── Node pools                     ├── Node pools (fully managed)       │
│  ├── Node sizes and counts          ├── Node sizes (auto-selected)       │
│  ├── Node OS and image              ├── Node OS (Container-Optimized OS) │
│  ├── Cluster autoscaling            ├── Autoscaling (always on)          │
│  └── System component tuning        └── All system components            │
│                                                                          │
│  Billing: per node (VM hours)       Billing: per Pod (vCPU + memory)    │
│  Idle nodes: you pay                Idle Pods: you pay (minimal)         │
│  Node access: SSH possible          Node access: not permitted           │
│  DaemonSets: supported              DaemonSets: not supported            │
│  Host networking: supported         Host networking: not supported       │
│  Privileged Pods: supported         Privileged Pods: not supported       │
│                                                                          │
│  Best for:                          Best for:                            │
│  ├── Custom node configurations     ├── Teams wanting zero node mgmt     │
│  ├── GPU and TPU workloads          ├── Variable, spiky workloads        │
│  ├── Stateful workloads             ├── Startups and small platform teams │
│  └── DaemonSet-based tooling        └── Cost optimization at variable load│
└─────────────────────────────────────────────────────────────────────────┘
```

#### GKE Standard Architecture

```
┌──────────────────────────────────────────────────────────────────────────┐
│  Google-Managed Control Plane (free for 1 zonal cluster; $0.10/hr rest) │
│                                                                           │
│  kube-apiserver · etcd · Scheduler · Controller Manager                  │
│  (Multi-zone for regional clusters; single-zone for zonal)               │
└───────────────────────────────┬──────────────────────────────────────────┘
                                │
┌───────────────────────────────▼──────────────────────────────────────────┐
│  Your GCP Project — VPC-native network                                    │
│                                                                           │
│  us-east1-b            us-east1-c            us-east1-d                  │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐          │
│  │  Node Pool:     │  │  Node Pool:     │  │  Node Pool:     │          │
│  │  n2-standard-4  │  │  n2-standard-4  │  │  n2-standard-4  │          │
│  │  Pods: /24 alias│  │  Pods: /24 alias│  │  Pods: /24 alias│          │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘          │
│                                                                           │
│  Cloud Load Balancing · Cloud Armor · Artifact Registry                  │
│  Cloud Operations · Cloud Build · Workload Identity                      │
└──────────────────────────────────────────────────────────────────────────┘
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
│  Pod                                                              │
│  serviceAccountName: order-api-ksa                               │
│                                                                   │
│  GKE Metadata Server (runs on node, intercepts metadata calls):  │
│  http://169.254.169.254/computeMetadata/v1/...                   │
│  Returns short-lived token for the bound Google SA               │
└───────────────────────────────┬──────────────────────────────────┘
                                │ Token exchange (OIDC)
                                ▼
┌──────────────────────────────────────────────────────────────────┐
│  Google STS (Security Token Service)                             │
│  Validates: KSA token signed by GKE's OIDC provider             │
│  Checks:    KSA → GSA binding (iam.workloadIdentityUser role)    │
└───────────────────────────────┬──────────────────────────────────┘
                                │ Impersonation granted
                                ▼
┌──────────────────────────────────────────────────────────────────┐
│  Google Service Account (GSA): order-api@my-project.iam.gserviceaccount.com
│  IAM roles:                                                      │
│    roles/storage.objectViewer → gs://order-assets               │
│    roles/pubsub.publisher → projects/my-project/topics/orders   │
│    roles/cloudsql.client → my-project:us-east1:orders-db        │
└──────────────────────────────────────────────────────────────────┘
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



---

──────────────────────────────────────────────────────────────────────

## Part VIII: Kubernetes Administrator

> *kubeadm · etcd · Certificates · RBAC · Admission Controllers · Troubleshooting*

──────────────────────────────────────────────────────────────────────


## 1. Introduction & Learning Objectives

The previous three chapters examined Kubernetes as delivered by cloud providers — managed control planes, automated node upgrades, integrated storage and networking. That abstraction is valuable, but it hides the machinery underneath. When things go wrong at 3 AM on a managed cluster, or when your organisation runs Kubernetes on bare metal, or when you are preparing for the Certified Kubernetes Administrator (CKA) examination, you need to understand that machinery from first principles.

This chapter is about the operational depth that separates a Kubernetes user from a Kubernetes administrator. We will bootstrap a production-grade cluster from scratch using `kubeadm`, understand the etcd distributed store that holds every byte of cluster state, back it up and restore it under failure conditions, rotate the TLS certificates that secure every component-to-component connection, and execute zero-downtime Kubernetes version upgrades across a multi-node cluster.

We then go deep on two topics that experienced administrators consistently identify as the most underinvested areas in production clusters: RBAC (where one overly broad ClusterRoleBinding has caused countless real-world security incidents) and Admission Controllers (where policy enforcement lives, long before a workload ever runs). We close with a systematic troubleshooting methodology for the failure patterns that appear most frequently in production clusters.

> **Learning Objectives**
> - Bootstrap a production-grade multi-node Kubernetes cluster using `kubeadm`, with a highly available control plane.
> - Understand etcd's role as the cluster's single source of truth and execute backup and restore procedures under controlled and emergency conditions.
> - Rotate Kubernetes TLS certificates before and after expiry, and interpret certificate health using `kubeadm` and `openssl`.
> - Execute planned node maintenance using cordon and drain, and handle unplanned node failures with confidence.
> - Perform a zero-downtime Kubernetes version upgrade across control plane and worker nodes.
> - Design and audit a production RBAC model using Roles, ClusterRoles, bindings, and ServiceAccounts.
> - Understand the Admission Controller pipeline: validating and mutating webhooks, OPA Gatekeeper, and Kyverno.
> - Apply a systematic diagnostic methodology for the most common Kubernetes failure categories: scheduling failures, networking failures, storage failures, and control plane failures.

---

## 2. Core Concepts

### 2.1 The Kubernetes Control Plane — Component by Component

Before administering a cluster, you must understand precisely what each control plane component does, how it communicates, and what breaks when it fails. Every component communicates over TLS using certificates stored in `/etc/kubernetes/pki/`.

```
┌───────────────────────────────────────────────────────────────────────────┐
│  Control Plane Node                                                        │
│                                                                            │
│  ┌──────────────────────────────────────────────────────────────────────┐ │
│  │  kube-apiserver                                                       │ │
│  │  Port: 6443 (HTTPS)                                                  │ │
│  │  The single entry point for all cluster operations.                  │ │
│  │  Authenticates requests → Authorizes (RBAC) → Admission control      │ │
│  │  → Validates → Persists to etcd                                      │ │
│  └───────────────┬───────────────────────┬───────────────────────────────┘ │
│                  │                       │                                  │
│  ┌───────────────▼──────┐  ┌────────────▼──────────────────────────────┐ │
│  │  etcd                │  │  kube-scheduler                            │ │
│  │  Port: 2379 (client) │  │  Watches for Pending Pods.                 │ │
│  │  Port: 2380 (peer)   │  │  Scores nodes, assigns Pod to best fit.    │ │
│  │  Distributed KV      │  │  Writes nodeName to Pod spec via apiserver.│ │
│  │  Raft consensus      │  └────────────────────────────────────────────┘ │
│  │  All cluster state   │                                                  │
│  └──────────────────────┘  ┌────────────────────────────────────────────┐ │
│                             │  kube-controller-manager                   │ │
│                             │  Runs control loops:                       │ │
│                             │  Node Controller: detects node failures    │ │
│                             │  ReplicaSet Controller: maintains counts   │ │
│                             │  Endpoint Controller: updates ep slices    │ │
│                             │  Job Controller: manages Job completion    │ │
│                             └────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────────────┐
│  Worker Node                                                               │
│                                                                            │
│  ┌──────────────────────────────────┐  ┌──────────────────────────────┐  │
│  │  kubelet                         │  │  kube-proxy                  │  │
│  │  Registers node with apiserver.  │  │  Watches Service/Endpoint    │  │
│  │  Ensures Pods match their spec.  │  │  objects. Maintains iptables │  │
│  │  Reports node and Pod status.    │  │  or ipvs rules for Service   │  │
│  │  Runs liveness/readiness probes. │  │  routing.                    │  │
│  └──────────────────────────────────┘  └──────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────────┘
```

#### Certificate Map

Every control plane component authenticates with the API server using a TLS client certificate. Understanding this map is essential for troubleshooting and rotation.

| Certificate / Key | Location | Used By | CN / O |
|---|---|---|---|
| `ca.crt` / `ca.key` | `/etc/kubernetes/pki/` | Root CA for all K8s certs | `kubernetes` |
| `apiserver.crt` | `/etc/kubernetes/pki/` | API server TLS server cert | `kube-apiserver` |
| `apiserver-kubelet-client.crt` | `/etc/kubernetes/pki/` | API server → kubelet | `O=system:masters` |
| `apiserver-etcd-client.crt` | `/etc/kubernetes/pki/` | API server → etcd client | `kube-apiserver-etcd-client` |
| `etcd/ca.crt` | `/etc/kubernetes/pki/etcd/` | etcd root CA | `etcd-ca` |
| `etcd/server.crt` | `/etc/kubernetes/pki/etcd/` | etcd server TLS cert | `etcd-server` |
| `etcd/peer.crt` | `/etc/kubernetes/pki/etcd/` | etcd peer-to-peer TLS | `etcd-peer` |
| `front-proxy-ca.crt` | `/etc/kubernetes/pki/` | API aggregation CA | `front-proxy-ca` |
| `kubelet.crt` | `/var/lib/kubelet/pki/` | kubelet server cert | node hostname |
| kubeconfig (admin) | `/etc/kubernetes/admin.conf` | kubectl admin auth | `O=system:masters` |
| kubeconfig (scheduler) | `/etc/kubernetes/scheduler.conf` | scheduler auth | `system:kube-scheduler` |
| kubeconfig (controller) | `/etc/kubernetes/controller-manager.conf` | controller-manager auth | `system:kube-controller-manager` |

---

### 2.2 etcd — The Cluster's Single Source of Truth

etcd is a distributed, strongly consistent key-value store built on the Raft consensus algorithm. Every Kubernetes object — every Pod spec, every Secret, every ConfigMap, every RBAC binding — exists as a key-value entry in etcd. If etcd loses its data, the cluster loses its entire desired and observed state.

#### etcd Raft and Quorum

etcd uses Raft consensus. A cluster of `n` members can tolerate `(n-1)/2` failures while remaining operational. This determines the minimum cluster size for fault tolerance:

| Cluster Size | Quorum Required | Tolerated Failures |
|---|---|---|
| 1 | 1 | 0 (no fault tolerance) |
| 2 | 2 | 0 (both must be available) |
| 3 | 2 | 1 ← minimum for HA |
| 5 | 3 | 2 ← recommended for production |
| 7 | 4 | 3 (rarely needed; adds latency) |

> **Production rule:** Run 3 etcd members for standard HA. Run 5 for critical clusters where you want to tolerate 2 simultaneous member failures. Never run an even number — a 4-member cluster offers no better fault tolerance than 3 (both require quorum of 3) but adds complexity.

#### etcd Key Layout

```bash
# etcd stores all Kubernetes objects under /registry/<resource>/<namespace>/<name>
# Keys are binary — use etcdctl to read them

# List all keys (shows the full registry layout)
ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get / --prefix --keys-only | head -40

# Output:
# /registry/apiextensions.k8s.io/customresourcedefinitions/prometheuses.monitoring.coreos.com
# /registry/clusterrolebindings/cluster-admin
# /registry/configmaps/kube-system/kube-proxy
# /registry/deployments/production/order-api
# /registry/pods/production/order-api-7d9b-4xk9p
# /registry/secrets/production/order-api-secret
# /registry/services/production/order-api

# Read a specific key (binary protobuf — pipe through kubectl decode or base64)
ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/production/order-api-secret | strings

# Check etcd cluster health and member status
ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  endpoint health --cluster

# Output:
# https://10.0.1.5:2379 is healthy: successfully committed proposal: took = 2.3ms
# https://10.0.1.6:2379 is healthy: successfully committed proposal: took = 1.9ms
# https://10.0.1.7:2379 is healthy: successfully committed proposal: took = 2.1ms

ETCDCTL_API=3 etcdctl \
  --endpoints=https://10.0.1.5:2379,https://10.0.1.6:2379,https://10.0.1.7:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  member list -w table

# Output:
# +------------------+---------+-------+-------------------------+-------------------------+
# | ID               | STATUS  | NAME  | PEER ADDRS              | CLIENT ADDRS            |
# +------------------+---------+-------+-------------------------+-------------------------+
# | 8e9e05c52164694d | started | cp-1  | https://10.0.1.5:2380   | https://10.0.1.5:2379   |
# | a54726e462b1da4c | started | cp-2  | https://10.0.1.6:2380   | https://10.0.1.6:2379   |
# | c74fce86028af6c9 | started | cp-3  | https://10.0.1.7:2380   | https://10.0.1.7:2379   |
# +------------------+---------+-------+-------------------------+-------------------------+
```

---

### 2.3 RBAC — Role-Based Access Control Deep Dive

RBAC is the authorisation layer that determines what authenticated subjects (users, groups, ServiceAccounts) are permitted to do with Kubernetes API resources. It is composed of four object types that compose in a specific way:

```
┌──────────────────────────────────────────────────────────────────────┐
│                                                                       │
│  Role / ClusterRole                                                   │
│  (defines permissions — "what can be done")                          │
│                                                                       │
│  ┌──────────────────────┐    ┌──────────────────────────────────────┐│
│  │  Role                │    │  ClusterRole                         ││
│  │  Namespace-scoped    │    │  Cluster-scoped OR usable across     ││
│  │  Permissions on      │    │  namespaces via ClusterRoleBinding   ││
│  │  namespaced resources│    │  Permissions on non-namespaced       ││
│  └──────────────────────┘    │  resources (nodes, PVs, CRDs)       ││
│                               └──────────────────────────────────────┘│
│                                                                       │
│  RoleBinding / ClusterRoleBinding                                     │
│  (grants permissions — "who can do it and where")                    │
│                                                                       │
│  ┌──────────────────────┐    ┌──────────────────────────────────────┐│
│  │  RoleBinding         │    │  ClusterRoleBinding                  ││
│  │  Namespace-scoped    │    │  Grants ClusterRole across ALL       ││
│  │  Can bind: Role or   │    │  namespaces — use with extreme care  ││
│  │  ClusterRole         │    │                                      ││
│  └──────────────────────┘    └──────────────────────────────────────┘│
│                                                                       │
│  Subjects (who receives the permissions)                              │
│  ├── User        (human, authenticated by cert CN or OIDC sub)       │
│  ├── Group       (authenticated by cert O or OIDC groups claim)      │
│  └── ServiceAccount (Pod identity; namespace-scoped)                 │
└──────────────────────────────────────────────────────────────────────┘
```

#### RBAC Verbs and Resources

```yaml
# Full verb set
verbs: ["get", "list", "watch", "create", "update", "patch", "delete", "deletecollection"]

# Common patterns
verbs: ["get", "list", "watch"]           # read-only
verbs: ["create", "update", "patch"]       # write
verbs: ["delete", "deletecollection"]      # destructive

# Resource subresources
resources: ["pods", "pods/log", "pods/exec", "pods/portforward", "pods/status"]
# "pods/exec" allows kubectl exec — separate from "pods" verb permissions
# A common RBAC mistake: giving someone "pods" read access but forgetting
# that "pods/exec" gives shell access to any Pod they can read
```

#### Production RBAC Patterns

```yaml
# ── Pattern 1: Namespace-scoped developer role ─────────────────
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer
  namespace: production
rules:
  # Read workloads
  - apiGroups: ["apps"]
    resources: ["deployments", "replicasets", "statefulsets", "daemonsets"]
    verbs: ["get", "list", "watch"]
  # Read and manage Pods (not create/delete — that goes through Deployments)
  - apiGroups: [""]
    resources: ["pods", "pods/log", "pods/status"]
    verbs: ["get", "list", "watch"]
  # Allow port-forward for local debugging
  - apiGroups: [""]
    resources: ["pods/portforward"]
    verbs: ["create"]
  # Read Services and Ingress
  - apiGroups: [""]
    resources: ["services", "endpoints", "configmaps"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["networking.k8s.io"]
    resources: ["ingresses"]
    verbs: ["get", "list", "watch"]
  # Read (not decode) Secrets — prevents credential harvesting
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["list"]     # list only: can see names, not values
  # Read events (critical for debugging)
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["get", "list", "watch"]
  # Read HPAs
  - apiGroups: ["autoscaling"]
    resources: ["horizontalpodautoscalers"]
    verbs: ["get", "list", "watch"]

---
# ── Pattern 2: CI/CD deploy role (least privilege) ─────────────
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: cicd-deployer
  namespace: production
rules:
  # Deploy new versions — update image, replicas, env
  - apiGroups: ["apps"]
    resources: ["deployments", "statefulsets"]
    verbs: ["get", "list", "watch", "update", "patch"]
  # Manage ConfigMaps for config updates
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
  # Manage Services for new service creation
  - apiGroups: [""]
    resources: ["services"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
  # Manage Ingress resources
  - apiGroups: ["networking.k8s.io"]
    resources: ["ingresses"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
  # Watch rollout status
  - apiGroups: [""]
    resources: ["pods", "pods/log"]
    verbs: ["get", "list", "watch"]

---
# ── Pattern 3: Monitoring / read-all ClusterRole ────────────────
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: monitoring-viewer
rules:
  - apiGroups: [""]
    resources:
      - nodes
      - nodes/stats
      - nodes/metrics
      - pods
      - services
      - endpoints
      - namespaces
      - persistentvolumes
      - persistentvolumeclaims
      - resourcequotas
      - limitranges
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps"]
    resources: ["deployments", "replicasets", "statefulsets", "daemonsets"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["metrics.k8s.io"]
    resources: ["nodes", "pods"]
    verbs: ["get", "list", "watch"]
  # Note: NO secrets access — monitoring should never read secret values

---
# ── Pattern 4: Bind roles to subjects ───────────────────────────
# RoleBinding: developer team gets developer role in production namespace
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developer-binding
  namespace: production
subjects:
  - kind: Group
    name: "engineering-team"    # Maps to OIDC group or cert O= field
    apiGroup: rbac.authorization.k8s.io
  - kind: User
    name: "alice@company.com"
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: developer
  apiGroup: rbac.authorization.k8s.io

---
# ClusterRoleBinding: monitoring SA gets cluster-wide read access
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: prometheus-monitoring
subjects:
  - kind: ServiceAccount
    name: prometheus
    namespace: monitoring
roleRef:
  kind: ClusterRole
  name: monitoring-viewer
  apiGroup: rbac.authorization.k8s.io
```

#### RBAC Audit Commands

```bash
# Check what a user can do in a namespace
kubectl auth can-i --list \
  --as=alice@company.com \
  --namespace=production

# Check a specific permission
kubectl auth can-i create deployments \
  --as=alice@company.com \
  --namespace=production
# yes

kubectl auth can-i delete secrets \
  --as=alice@company.com \
  --namespace=production
# no

# Check permissions for a ServiceAccount
kubectl auth can-i list pods \
  --as=system:serviceaccount:production:order-api-sa \
  --namespace=production

# Find all ClusterRoleBindings to the cluster-admin role (security audit)
kubectl get clusterrolebindings -o json | \
  jq -r '.items[] |
    select(.roleRef.name=="cluster-admin") |
    "Binding: \(.metadata.name) → Subjects: \(.subjects // [] | map(.name) | join(", "))"'

# Find all Roles/ClusterRoles that allow secrets access
kubectl get clusterroles -o json | \
  jq -r '.items[] |
    select(.rules[]?.resources[]? == "secrets") |
    .metadata.name'

# Install kubectl-who-can plugin (krew) for richer RBAC auditing
kubectl krew install who-can
kubectl who-can create deployments --namespace=production
kubectl who-can delete secrets --all-namespaces
```

---

### 2.4 Admission Controllers

The Admission Controller pipeline sits between the API server's authentication/authorisation layer and the persistence layer (etcd). Every API request that creates, updates, or deletes an object passes through the enabled admission controllers before being written.

```
kubectl apply -f deployment.yaml
    │
    ▼
kube-apiserver
    │
    ├── 1. Authentication (who are you?)
    │      TLS client cert, Bearer token, OIDC
    │
    ├── 2. Authorisation (are you allowed?)
    │      RBAC check
    │
    ├── 3. Admission Controllers ← THIS SECTION
    │      ├── Mutating Admission Webhooks
    │      │      Modify the object (inject sidecars, set defaults)
    │      │      Run in parallel; all run before validating
    │      │
    │      ├── Object Schema Validation
    │      │      Validate the mutated object against its OpenAPI schema
    │      │
    │      └── Validating Admission Webhooks
    │             Accept or reject the (mutated) object
    │             Run in parallel; any rejection blocks the request
    │
    └── 4. Persist to etcd (if all controllers pass)
```

#### Built-in Admission Controllers

| Controller | Type | What It Does |
|---|---|---|
| `NamespaceLifecycle` | Validating | Prevents creating resources in terminating namespaces |
| `LimitRanger` | Mutating + Validating | Applies LimitRange defaults; validates against LimitRange |
| `ServiceAccount` | Mutating | Auto-mounts service account tokens into Pods |
| `DefaultStorageClass` | Mutating | Assigns default StorageClass to PVCs without one |
| `ResourceQuota` | Validating | Enforces ResourceQuota limits per namespace |
| `PodSecurity` | Validating | Enforces Pod Security Standards (privileged/baseline/restricted) |
| `MutatingAdmissionWebhook` | Mutating | Delegates to external webhook servers |
| `ValidatingAdmissionWebhook` | Validating | Delegates to external webhook servers |

#### Pod Security Admission (PSA)

PSA replaced the deprecated PodSecurityPolicy in Kubernetes 1.25. It enforces three security profiles per namespace:

```yaml
# Label namespaces to enforce Pod Security Standards
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    # enforce: reject Pods that violate the policy
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: v1.30
    # audit: log violations without rejecting
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/audit-version: v1.30
    # warn: send warnings to kubectl output without rejecting
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/warn-version: v1.30
```

```
PSA Security Levels:
  privileged  — No restrictions (use only for trusted system namespaces)
  baseline    — Prevents known privilege escalation (no hostPID, hostNetwork, privilege)
  restricted  — Hardened (must run as non-root, read-only rootfs, drop all capabilities)
```

```yaml
# Pod that satisfies the 'restricted' PSA profile
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1001
    runAsGroup: 1001
    fsGroup: 1001
    seccompProfile:
      type: RuntimeDefault      # Use the container runtime's default seccomp profile
  containers:
    - name: api
      image: myapp:1.0.0
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop: ["ALL"]          # Drop every Linux capability
          # add: ["NET_BIND_SERVICE"]  # Only add what's strictly needed
      volumeMounts:
        - name: tmp
          mountPath: /tmp        # App needs a writable /tmp despite read-only rootfs
  volumes:
    - name: tmp
      emptyDir: {}
```

#### OPA Gatekeeper — Policy as Code

Open Policy Agent (OPA) Gatekeeper is a validating admission webhook that enforces custom policies written in the Rego policy language. It is widely used for compliance requirements that PSA cannot express.

```yaml
# ConstraintTemplate — defines the policy logic in Rego
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: requiredlabels
spec:
  crd:
    spec:
      names:
        kind: RequiredLabels
      validation:
        openAPIV3Schema:
          properties:
            labels:
              type: array
              items:
                type: string
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package requiredlabels

        violation[{"msg": msg}] {
          provided := {label | input.review.object.metadata.labels[label]}
          required := {label | label := input.parameters.labels[_]}
          missing := required - provided
          count(missing) > 0
          msg := sprintf("Missing required labels: %v", [missing])
        }

---
# Constraint — instantiates the template with specific parameters
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: RequiredLabels
metadata:
  name: must-have-team-and-env-labels
spec:
  match:
    kinds:
      - apiGroups: ["apps"]
        kinds: ["Deployment"]
    namespaces: ["production", "staging"]
  parameters:
    labels: ["team", "env"]

---
# Constraint — enforce image registry restriction
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: AllowedRepos
metadata:
  name: prod-registry-only
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
    namespaces: ["production"]
  parameters:
    repos:
      - "123456789.dkr.ecr.us-east-1.amazonaws.com/"
      - "gcr.io/my-project/"
      - "myregistry.azurecr.io/"
```

#### Kyverno — Kubernetes-Native Policy Engine

Kyverno is an alternative to OPA/Gatekeeper that uses Kubernetes YAML syntax for policies — no Rego required.

```yaml
# Kyverno ClusterPolicy — require resource limits on all containers
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-resource-limits
  annotations:
    policies.kyverno.io/description: >
      All containers must have CPU and memory limits defined.
spec:
  validationFailureAction: Enforce     # Enforce = reject; Audit = log only
  background: true                      # Apply to existing resources
  rules:
    - name: check-resource-limits
      match:
        any:
          - resources:
              kinds: ["Pod"]
      validate:
        message: "CPU and memory limits are required for all containers."
        pattern:
          spec:
            containers:
              - name: "*"
                resources:
                  limits:
                    cpu: "?*"
                    memory: "?*"

---
# Kyverno ClusterPolicy — mutate: inject labels automatically
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: inject-managed-by-label
spec:
  rules:
    - name: add-managed-by-label
      match:
        any:
          - resources:
              kinds: ["Deployment", "StatefulSet", "DaemonSet"]
      mutate:
        patchStrategicMerge:
          metadata:
            labels:
              managed-by: kyverno   # Auto-injected on every workload resource

---
# Kyverno ClusterPolicy — generate: create a NetworkPolicy for every new namespace
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: default-deny-networkpolicy
spec:
  rules:
    - name: generate-default-deny
      match:
        any:
          - resources:
              kinds: ["Namespace"]
      generate:
        kind: NetworkPolicy
        name: default-deny-all
        namespace: "{{request.object.metadata.name}}"
        synchronize: true
        data:
          spec:
            podSelector: {}
            policyTypes: ["Ingress", "Egress"]
            # No ingress or egress rules = deny all by default
```

---

## 3. Cluster Bootstrapping with kubeadm

### 3.1 Architecture — HA Control Plane

```
                        ┌──────────────────┐
                        │  External Load   │
                        │  Balancer (L4)   │
                        │  VIP: 10.0.1.100 │
                        │  Port: 6443      │
                        └────────┬─────────┘
                                 │
           ┌─────────────────────┼─────────────────────┐
           ▼                     ▼                     ▼
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│  Control Plane 1 │  │  Control Plane 2 │  │  Control Plane 3 │
│  10.0.1.5        │  │  10.0.1.6        │  │  10.0.1.7        │
│  kube-apiserver  │  │  kube-apiserver  │  │  kube-apiserver  │
│  etcd (leader)   │  │  etcd (follower) │  │  etcd (follower) │
│  scheduler       │  │  scheduler       │  │  scheduler       │
│  controller-mgr  │  │  controller-mgr  │  │  controller-mgr  │
└──────────────────┘  └──────────────────┘  └──────────────────┘
           ▲                                           ▲
           └──────── etcd Raft consensus ──────────────┘

┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│  Worker Node 1   │  │  Worker Node 2   │  │  Worker Node 3   │
│  10.0.2.5        │  │  10.0.2.6        │  │  10.0.2.7        │
│  kubelet         │  │  kubelet         │  │  kubelet         │
│  kube-proxy      │  │  kube-proxy      │  │  kube-proxy      │
└──────────────────┘  └──────────────────┘  └──────────────────┘
```

### 3.2 Pre-flight: Node Preparation

```bash
# Run on ALL nodes (control plane and workers)

# Disable swap (Kubernetes requires swap to be off)
swapoff -a
sed -i '/swap/d' /etc/fstab

# Load required kernel modules
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

# Set required sysctl params
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system

# Install containerd (container runtime)
apt-get update
apt-get install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list

apt-get update
apt-get install -y containerd.io

# Configure containerd to use systemd cgroup driver (required for kubeadm)
containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

# Install kubeadm, kubelet, kubectl
KUBE_VERSION="1.30.0"
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | \
  gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
  https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | \
  tee /etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install -y kubelet=${KUBE_VERSION}-1.1 \
                   kubeadm=${KUBE_VERSION}-1.1 \
                   kubectl=${KUBE_VERSION}-1.1

# Pin versions to prevent unintended upgrades
apt-mark hold kubelet kubeadm kubectl

systemctl enable kubelet
```

### 3.3 Bootstrap the First Control Plane Node

```yaml
# kubeadm-config.yaml — declarative cluster configuration
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: "10.0.1.5"       # This node's IP
  bindPort: 6443
nodeRegistration:
  criSocket: unix:///run/containerd/containerd.sock
  name: "cp-1"
  taints:
    - effect: NoSchedule
      key: node-role.kubernetes.io/control-plane

---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
clusterName: "production-cluster"
kubernetesVersion: "1.30.0"

# HA load balancer VIP — all kubeconfigs point to this
controlPlaneEndpoint: "10.0.1.100:6443"

# etcd configuration (stacked — etcd runs on control plane nodes)
etcd:
  local:
    dataDir: /var/lib/etcd
    extraArgs:
      # Tuning for production
      heartbeat-interval: "100"
      election-timeout: "1000"
      snapshot-count: "10000"
      quota-backend-bytes: "8589934592"   # 8 GiB etcd database size limit
      auto-compaction-retention: "1"       # Compact every 1 hour

# API server configuration
apiServer:
  certSANs:
    - "10.0.1.100"      # Load balancer VIP
    - "10.0.1.5"        # cp-1
    - "10.0.1.6"        # cp-2
    - "10.0.1.7"        # cp-3
    - "kubernetes"
    - "kubernetes.default"
    - "kubernetes.default.svc"
    - "kubernetes.default.svc.cluster.local"
  extraArgs:
    audit-log-path: /var/log/kubernetes/audit.log
    audit-log-maxage: "30"
    audit-log-maxbackup: "10"
    audit-log-maxsize: "100"
    audit-policy-file: /etc/kubernetes/audit-policy.yaml
    enable-admission-plugins: >-
      NodeRestriction,
      PodSecurity,
      ResourceQuota,
      LimitRanger
    encryption-provider-config: /etc/kubernetes/encryption-config.yaml  # etcd encryption at rest
  extraVolumes:
    - name: audit-policy
      hostPath: /etc/kubernetes/audit-policy.yaml
      mountPath: /etc/kubernetes/audit-policy.yaml
      readOnly: true
    - name: audit-log
      hostPath: /var/log/kubernetes
      mountPath: /var/log/kubernetes

# Controller manager
controllerManager:
  extraArgs:
    bind-address: "0.0.0.0"
    node-cidr-mask-size: "24"     # Each node gets a /24 Pod CIDR

# Scheduler
scheduler:
  extraArgs:
    bind-address: "0.0.0.0"

# Networking
networking:
  podSubnet: "10.244.0.0/16"     # Flannel / Calico Pod CIDR
  serviceSubnet: "10.96.0.0/12"  # Service ClusterIP CIDR
  dnsDomain: "cluster.local"

---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd             # Must match containerd cgroup driver
serverTLSBootstrap: true
rotateCertificates: true          # Auto-rotate kubelet serving certificates
```

```bash
# Bootstrap the first control plane node
kubeadm init --config=kubeadm-config.yaml --upload-certs

# Output includes:
# kubeadm join 10.0.1.100:6443 \
#   --token abcdef.0123456789abcdef \
#   --discovery-token-ca-cert-hash sha256:... \
#   --control-plane \
#   --certificate-key <key>       ← for joining additional control plane nodes

# Configure kubectl
mkdir -p $HOME/.kube
cp /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

# Install a CNI plugin (Calico shown)
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.3/manifests/calico.yaml

# Wait for all control plane Pods to be Running
kubectl get pods -n kube-system --watch
```

### 3.4 Join Additional Control Plane Nodes

```bash
# Run on cp-2 and cp-3 (use the join command from kubeadm init output)
# Certificate key expires after 2 hours; re-upload if needed:
# kubeadm init phase upload-certs --upload-certs

kubeadm join 10.0.1.100:6443 \
  --token abcdef.0123456789abcdef \
  --discovery-token-ca-cert-hash sha256:abc123... \
  --control-plane \
  --certificate-key <certificate-key> \
  --apiserver-advertise-address=10.0.1.6    # This node's IP

# Join worker nodes (no --control-plane flag)
kubeadm join 10.0.1.100:6443 \
  --token abcdef.0123456789abcdef \
  --discovery-token-ca-cert-hash sha256:abc123...

# Generate a new token if the original expired (24h TTL)
kubeadm token create --print-join-command
```

---

## 4. etcd Backup and Restore

### 4.1 Scheduled Backup Procedure

```bash
# ── Snapshot backup ───────────────────────────────────────────────────
# Run on a control plane node (or any host with etcdctl and access to certs)

BACKUP_DIR="/backup/etcd"
BACKUP_FILE="etcd-snapshot-$(date +%Y%m%d-%H%M%S).db"
ETCD_ENDPOINTS="https://127.0.0.1:2379"

mkdir -p $BACKUP_DIR

ETCDCTL_API=3 etcdctl snapshot save $BACKUP_DIR/$BACKUP_FILE \
  --endpoints=$ETCD_ENDPOINTS \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Verify the snapshot is valid
ETCDCTL_API=3 etcdctl snapshot status $BACKUP_DIR/$BACKUP_FILE \
  --write-out=table

# Output:
# +----------+----------+------------+------------+
# |   HASH   | REVISION | TOTAL KEYS | TOTAL SIZE |
# +----------+----------+------------+------------+
# | 2da60db6 | 1234567  | 42103      | 128 MB     |
# +----------+----------+------------+------------+

# Upload to offsite storage (S3, GCS, Azure Blob)
aws s3 cp $BACKUP_DIR/$BACKUP_FILE \
  s3://my-cluster-backups/etcd/$BACKUP_FILE \
  --sse aws:kms

# ── Automate with a CronJob on the control plane ────────────────────
# Create a systemd timer (preferred over cron for Linux services)
cat > /etc/systemd/system/etcd-backup.service << 'EOF'
[Unit]
Description=etcd backup
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/etcd-backup.sh
EOF

cat > /etc/systemd/system/etcd-backup.timer << 'EOF'
[Unit]
Description=Run etcd backup every 6 hours

[Timer]
OnCalendar=*-*-* 00,06,12,18:00:00
RandomizedDelaySec=300
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl enable --now etcd-backup.timer
```

### 4.2 etcd Restore Procedure

```bash
# ── EMERGENCY RESTORE ─────────────────────────────────────────────────
# Scenario: etcd data directory corrupted; cluster state lost.
# Restore from the most recent snapshot.

# Step 1: Stop the API server and etcd on ALL control plane nodes
# (etcd must be stopped before restore to prevent data conflicts)
# For kubeadm clusters, move static Pod manifests out of the manifests dir:
mkdir -p /etc/kubernetes/manifests.bak
mv /etc/kubernetes/manifests/etcd.yaml /etc/kubernetes/manifests.bak/
mv /etc/kubernetes/manifests/kube-apiserver.yaml /etc/kubernetes/manifests.bak/
mv /etc/kubernetes/manifests/kube-controller-manager.yaml /etc/kubernetes/manifests.bak/
mv /etc/kubernetes/manifests/kube-scheduler.yaml /etc/kubernetes/manifests.bak/

# Wait for containers to stop
crictl pods --namespace kube-system
# Should show no kube-system Pods

# Step 2: Download the snapshot from backup storage
aws s3 cp s3://my-cluster-backups/etcd/etcd-snapshot-20240315-020000.db \
  /tmp/etcd-snapshot.db

# Step 3: Restore etcd data on EACH control plane node
# Use different --name and --initial-advertise-peer-urls per node

# On cp-1:
ETCDCTL_API=3 etcdctl snapshot restore /tmp/etcd-snapshot.db \
  --name=cp-1 \
  --initial-cluster="cp-1=https://10.0.1.5:2380,cp-2=https://10.0.1.6:2380,cp-3=https://10.0.1.7:2380" \
  --initial-cluster-token=etcd-cluster-1 \
  --initial-advertise-peer-urls=https://10.0.1.5:2380 \
  --data-dir=/var/lib/etcd-restored

# On cp-2:
ETCDCTL_API=3 etcdctl snapshot restore /tmp/etcd-snapshot.db \
  --name=cp-2 \
  --initial-cluster="cp-1=https://10.0.1.5:2380,cp-2=https://10.0.1.6:2380,cp-3=https://10.0.1.7:2380" \
  --initial-cluster-token=etcd-cluster-1 \
  --initial-advertise-peer-urls=https://10.0.1.6:2380 \
  --data-dir=/var/lib/etcd-restored

# On cp-3 (similar pattern)

# Step 4: Update etcd.yaml to point to the restored data directory
# Edit /etc/kubernetes/manifests.bak/etcd.yaml:
# Change: --data-dir=/var/lib/etcd
# To:     --data-dir=/var/lib/etcd-restored
# And update the hostPath volumes accordingly

# Step 5: Restore static Pod manifests
mv /etc/kubernetes/manifests.bak/*.yaml /etc/kubernetes/manifests/

# Step 6: Wait for control plane to recover
watch crictl pods --namespace kube-system
# All control-plane Pods should return to Running state

kubectl get nodes
kubectl get pods -A

# Step 7: Verify cluster state matches the backup point
kubectl get deployments -A
kubectl get services -A
```

---

## 5. Certificate Management

### 5.1 Check Certificate Expiry

```bash
# Check all certificates managed by kubeadm
kubeadm certs check-expiration

# Output:
# CERTIFICATE                EXPIRES                  RESIDUAL TIME   CERTIFICATE AUTHORITY   EXTERNALLY MANAGED
# admin.conf                 Mar 15, 2025 02:00 UTC   364d            ca                      no
# apiserver                  Mar 15, 2025 02:00 UTC   364d            ca                      no
# apiserver-etcd-client      Mar 15, 2025 02:00 UTC   364d            etcd-ca                 no
# apiserver-kubelet-client   Mar 15, 2025 02:00 UTC   364d            ca                      no
# controller-manager.conf    Mar 15, 2025 02:00 UTC   364d            ca                      no
# etcd-healthcheck-client    Mar 15, 2025 02:00 UTC   364d            etcd-ca                 no
# etcd-peer                  Mar 15, 2025 02:00 UTC   364d            etcd-ca                 no
# etcd-server                Mar 15, 2025 02:00 UTC   364d            etcd-ca                 no
# front-proxy-client         Mar 15, 2025 02:00 UTC   364d            front-proxy-ca          no
# scheduler.conf             Mar 15, 2025 02:00 UTC   364d            ca                      no

# Inspect individual certificates with openssl
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -text | \
  grep -A 2 "Not Before\|Not After\|Subject:\|DNS:"

# Check certificate validity with openssl
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -dates
# notBefore=Mar 15 02:00:00 2024 GMT
# notAfter=Mar 15 02:00:00 2025 GMT
```

### 5.2 Certificate Rotation

```bash
# ── Renew all certificates (run on each control plane node) ──────────
# Best practice: rotate 30-60 days before expiry during a maintenance window

# Renew all certificates at once
kubeadm certs renew all

# Or renew individual certificates
kubeadm certs renew apiserver
kubeadm certs renew apiserver-etcd-client
kubeadm certs renew apiserver-kubelet-client

# Restart control plane components to pick up new certificates
# For static Pod manifests, kill the containers (kubelet restarts them)
crictl pods --namespace kube-system --name kube-apiserver -q | \
  xargs crictl stopp
crictl pods --namespace kube-system --name kube-controller-manager -q | \
  xargs crictl stopp
crictl pods --namespace kube-system --name kube-scheduler -q | \
  xargs crictl stopp
crictl pods --namespace kube-system --name etcd -q | \
  xargs crictl stopp

# Wait for them to restart (kubelet detects missing containers and recreates)
watch crictl pods --namespace kube-system

# Verify new expiry
kubeadm certs check-expiration | head -5

# Update kubeconfig with new credentials
kubeadm kubeconfig user --client-name admin > ~/.kube/config
# or for managed clusters: copy /etc/kubernetes/admin.conf

# ── Auto-rotation via kubelet ─────────────────────────────────────────
# With rotateCertificates: true in KubeletConfiguration,
# kubelet automatically rotates its client certificate before expiry.
# No manual intervention required for kubelet certs after initial setup.

# Check kubelet cert rotation status
kubectl get csr
# NAME        AGE    SIGNERNAME                                    REQUESTOR              CONDITION
# csr-abc123  5m     kubernetes.io/kube-apiserver-client-kubelet   system:node:worker-1   Approved,Issued
```

---

## 6. Node Maintenance and Upgrades

### 6.1 Planned Node Maintenance (Drain and Cordon)

```bash
# ── Cordon: prevent new Pods from being scheduled on the node ────────
kubectl cordon worker-1
# node/worker-1 cordoned

kubectl get nodes
# NAME       STATUS                     ROLES    AGE
# cp-1       Ready                      control-plane  5d
# worker-1   Ready,SchedulingDisabled   <none>   5d   ← Cordoned
# worker-2   Ready                      <none>   5d
# worker-3   Ready                      <none>   5d

# ── Drain: evict all Pods from the node ──────────────────────────────
kubectl drain worker-1 \
  --ignore-daemonsets \         # Don't evict DaemonSet Pods (they can't be rescheduled)
  --delete-emptydir-data \      # Evict Pods using emptyDir volumes (data will be lost)
  --grace-period=60 \           # Allow 60s for graceful Pod termination
  --timeout=300s                # Give up after 5 minutes

# kubectl drain respects PodDisruptionBudgets
# If evicting a Pod would violate a PDB, drain will wait and retry

# If drain is stuck (PDB violation), investigate:
kubectl get pdb -A
kubectl describe pdb <pdb-name> -n <namespace>

# Force eviction only if absolutely necessary (bypasses PDBs):
kubectl drain worker-1 \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --force   # WARNING: data loss possible; bypasses PDBs

# ── Perform maintenance ───────────────────────────────────────────────
# Now safe to: patch OS, replace hardware, upgrade kernel, etc.
apt-get update && apt-get upgrade -y
systemctl reboot

# ── Return node to service ────────────────────────────────────────────
kubectl uncordon worker-1
kubectl get nodes
# NAME       STATUS   ROLES    AGE
# worker-1   Ready    <none>   5d   ← Back in service; Pods can schedule here again
```

### 6.2 Zero-Downtime Kubernetes Version Upgrade

Kubernetes supports upgrading one minor version at a time (e.g. 1.29 → 1.30; not 1.29 → 1.31). Always upgrade control plane nodes before worker nodes.

```bash
# ─────────────────────────────────────────────────────────────────────
# PHASE 1: Upgrade the first control plane node
# ─────────────────────────────────────────────────────────────────────

# Check available versions
apt-cache madison kubeadm | grep 1.30

# Unpin and upgrade kubeadm
apt-mark unhold kubeadm
apt-get update
apt-get install -y kubeadm=1.30.3-1.1
apt-mark hold kubeadm

# Verify the new version
kubeadm version

# Check what the upgrade will change
kubeadm upgrade plan 1.30.3

# Apply the upgrade to the first control plane node
kubeadm upgrade apply v1.30.3

# Output (abbreviated):
# [upgrade] Upgrading your Static Pod-hosted control plane...
# [upgrade/staticpods] Moved new manifest to "/etc/kubernetes/manifests/kube-apiserver.yaml"
# [upgrade/staticpods] Waiting for the kubelet to restart the component
# [upgrade] Upgraded the cluster to version v1.30.3

# Drain this control plane node (to upgrade kubelet)
kubectl drain cp-1 --ignore-daemonsets --delete-emptydir-data

# Upgrade kubelet and kubectl on this node
apt-mark unhold kubelet kubectl
apt-get install -y kubelet=1.30.3-1.1 kubectl=1.30.3-1.1
apt-mark hold kubelet kubectl

systemctl daemon-reload
systemctl restart kubelet

# Return to service
kubectl uncordon cp-1

# Verify
kubectl get nodes
# NAME   STATUS   ROLES           VERSION
# cp-1   Ready    control-plane   v1.30.3   ← Upgraded
# cp-2   Ready    control-plane   v1.29.7   ← Not yet upgraded
# cp-3   Ready    control-plane   v1.29.7
# w-1    Ready    <none>          v1.29.7
# w-2    Ready    <none>          v1.29.7

# ─────────────────────────────────────────────────────────────────────
# PHASE 2: Upgrade remaining control plane nodes
# ─────────────────────────────────────────────────────────────────────
# On cp-2 and cp-3, use 'kubeadm upgrade node' (not 'apply')

# (on cp-2)
apt-mark unhold kubeadm
apt-get install -y kubeadm=1.30.3-1.1
apt-mark hold kubeadm
kubeadm upgrade node          # Note: 'node' not 'apply' for non-first control planes

kubectl drain cp-2 --ignore-daemonsets --delete-emptydir-data

apt-mark unhold kubelet kubectl
apt-get install -y kubelet=1.30.3-1.1 kubectl=1.30.3-1.1
apt-mark hold kubelet kubectl
systemctl daemon-reload && systemctl restart kubelet

kubectl uncordon cp-2
# Repeat for cp-3

# ─────────────────────────────────────────────────────────────────────
# PHASE 3: Upgrade worker nodes (one at a time for zero downtime)
# ─────────────────────────────────────────────────────────────────────
# For each worker node (repeat for w-1, w-2, w-3...):

# Drain the worker
kubectl drain w-1 --ignore-daemonsets --delete-emptydir-data

# SSH to the worker node
ssh w-1

# Upgrade kubeadm, then run 'upgrade node'
apt-mark unhold kubeadm
apt-get install -y kubeadm=1.30.3-1.1
apt-mark hold kubeadm
kubeadm upgrade node

# Upgrade kubelet and kubectl
apt-mark unhold kubelet kubectl
apt-get install -y kubelet=1.30.3-1.1 kubectl=1.30.3-1.1
apt-mark hold kubelet kubectl
systemctl daemon-reload && systemctl restart kubelet

# Return to controller and uncordon
exit
kubectl uncordon w-1

# Wait for node to be Ready before upgrading next node
kubectl get nodes --watch | grep w-1

# Repeat for w-2, w-3, etc.

# ── Verify the upgrade ────────────────────────────────────────────────
kubectl get nodes
# All nodes should show v1.30.3 with STATUS=Ready

kubectl get pods -n kube-system
# All system Pods should be Running

kubectl version
# Client: v1.30.3  Server: v1.30.3
```

---

## 7. Step-by-Step Hands-on Walkthrough

### 7.1 RBAC Audit and Hardening Lab

```bash
# Simulate an over-privileged cluster and harden it

# Step 1: Find all ClusterRoleBindings granting cluster-admin
kubectl get clusterrolebindings -o json | jq -r '
  .items[] |
  select(.roleRef.name=="cluster-admin") |
  "\(.metadata.name) → \(.subjects // [] | map("\(.kind)/\(.name)") | join(", "))"
'
# system:masters binding → Group/system:masters    (expected)
# jenkins-admin → ServiceAccount/jenkins/default    (OVERPRIVILEGED! CI/CD SA should not be cluster-admin)
# developer-access → User/alice@company.com         (review if intentional)

# Step 2: Replace the cluster-admin SA binding with a scoped role
# Delete overprivileged binding
kubectl delete clusterrolebinding jenkins-admin

# Create a least-privilege deployer role for the jenkins namespace
kubectl apply -f - <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: cicd-deployer
  namespace: production
rules:
  - apiGroups: ["apps"]
    resources: ["deployments", "statefulsets"]
    verbs: ["get", "list", "watch", "update", "patch"]
  - apiGroups: [""]
    resources: ["configmaps", "services"]
    verbs: ["get", "list", "create", "update", "patch"]
  - apiGroups: [""]
    resources: ["pods", "pods/log"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: jenkins-deployer
  namespace: production
subjects:
  - kind: ServiceAccount
    name: default
    namespace: jenkins
roleRef:
  kind: Role
  name: cicd-deployer
  apiGroup: rbac.authorization.k8s.io
EOF

# Step 3: Verify the SA can now deploy but not delete namespaces
kubectl auth can-i update deployments \
  --as=system:serviceaccount:jenkins:default \
  --namespace=production
# yes

kubectl auth can-i delete namespaces \
  --as=system:serviceaccount:jenkins:default
# no
```

### 7.2 Admission Controller — Kyverno Policy Enforcement

```bash
# Install Kyverno
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update
helm install kyverno kyverno/kyverno \
  --namespace kyverno \
  --create-namespace \
  --set replicaCount=3 \
  --version 3.2.0

kubectl get pods -n kyverno --watch

# Apply a policy requiring resource limits
kubectl apply -f - <<'EOF'
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-resource-limits
spec:
  validationFailureAction: Enforce
  rules:
    - name: check-resource-limits
      match:
        any:
          - resources:
              kinds: ["Pod"]
              namespaces: ["production", "staging"]
      validate:
        message: "CPU and memory limits are required."
        pattern:
          spec:
            containers:
              - name: "*"
                resources:
                  limits:
                    cpu: "?*"
                    memory: "?*"
EOF

# Test: try to deploy a Pod without resource limits
kubectl apply -f - <<'EOF' 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: no-limits-pod
  namespace: production
spec:
  containers:
    - name: nginx
      image: nginx:alpine
EOF
# Error from server: admission webhook "validate.kyverno.svc-fail" denied the request:
# CPU and memory limits are required.

# Test: deploy a Pod WITH resource limits (should succeed)
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: with-limits-pod
  namespace: production
spec:
  containers:
    - name: nginx
      image: nginx:alpine
      resources:
        requests:
          cpu: 100m
          memory: 128Mi
        limits:
          cpu: 200m
          memory: 256Mi
EOF
# pod/with-limits-pod created

# View policy reports
kubectl get policyreport -A
kubectl describe clusterpolicyreport
```

---

## 8. Troubleshooting Methodology

### 8.1 The Five-Layer Diagnostic Framework

When a Kubernetes issue is reported, work through these five layers in order. Most problems manifest at one layer but are caused by a failure in a layer below it.

```
Layer 5: Application         Pod logs, probe failures, application errors
Layer 4: Workload/Controller Deployment status, ReplicaSet events, HPA behaviour
Layer 3: Scheduling          Pending Pods, node taints, resource pressure
Layer 2: Networking          Service DNS, kube-proxy rules, CNI connectivity
Layer 1: Control Plane       etcd health, API server errors, component status
```

### 8.2 Scheduling Failures

```bash
# Symptom: Pod stuck in Pending state

# Step 1: Describe the Pod — events section is the key
kubectl describe pod <pod-name> -n <namespace>
# Look for events like:
# 0/3 nodes are available: 3 Insufficient cpu, 3 Insufficient memory.
# 0/3 nodes are available: 1 node(s) had untolerated taint {node-role.kubernetes.io/control-plane:NoSchedule}
# 0/3 nodes are available: 3 node(s) didn't match Pod's node affinity/selector

# Step 2: Check node resource availability
kubectl describe nodes | grep -A 5 "Allocated resources"
# Allocated resources:
#   cpu: 3750m/4000m   ← 93.75% allocated — near capacity
#   memory: 7500Mi/8000Mi   ← also near capacity

# Step 3: Check node conditions
kubectl get nodes -o wide
kubectl describe node <node-name> | grep -A 10 "Conditions:"

# Common Conditions:
# MemoryPressure=True  → Node is low on memory; Kubelet evicting Pods
# DiskPressure=True    → Node is low on disk; check /var/lib/kubelet
# PIDPressure=True     → Node is low on PIDs (ulimits)
# Ready=False          → Node is not healthy; check kubelet status

# Step 4: Check taints and tolerations
kubectl get nodes -o custom-columns=\
NAME:.metadata.name,\
TAINTS:.spec.taints

# If Pod needs to run on a tainted node, verify tolerations match exactly
# A toleration for key=value:NoSchedule does NOT match key=value:NoExecute

# Step 5: Resource quota exhaustion
kubectl describe resourcequota -n <namespace>
# If "Used" equals "Hard" for cpu or memory, the namespace is at capacity
```

### 8.3 Networking Failures

```bash
# ── Scenario 1: Pod cannot resolve a Service DNS name ─────────────────
# Symptom: "connection refused" or "no such host" when connecting to other services

# Step 1: Test DNS resolution from inside a Pod
kubectl run dns-debug \
  --image=busybox:1.36 \
  --rm -it --restart=Never \
  -- nslookup order-svc.production.svc.cluster.local

# Step 2: Check CoreDNS Pods are running
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Step 3: Check CoreDNS logs for errors
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=50

# Step 4: Verify the Service exists and has endpoints
kubectl get service order-svc -n production
kubectl get endpoints order-svc -n production
# If ENDPOINTS shows <none>: the Service selector does not match any Pod labels

# Step 5: Verify Pod labels match Service selector
kubectl get pods -n production --show-labels | grep order-svc
kubectl get service order-svc -n production -o yaml | grep -A 3 selector

# ── Scenario 2: Pod cannot reach another Pod directly ─────────────────
# Symptom: curl to Pod IP fails; Service works; NetworkPolicy suspected

# Step 1: Check NetworkPolicies that apply to the destination Pod
kubectl get networkpolicies -n production
kubectl describe networkpolicy <policy-name> -n production

# Step 2: Test connectivity from source Pod (install nc or curl)
kubectl exec -n production <source-pod> -- nc -zv <dest-pod-ip> 8080
# nc: connect to 10.244.1.5 port 8080 (tcp) failed: Connection refused
# → Port wrong or NetworkPolicy blocking

# Step 3: Verify kube-proxy / iptables rules (standard clusters)
# SSH to the node where the source Pod runs:
iptables-save | grep <service-cluster-ip>
# If no rules: kube-proxy may not be running or failing to sync

kubectl get pods -n kube-system -l k8s-app=kube-proxy
kubectl logs -n kube-system -l k8s-app=kube-proxy --tail=30

# ── Scenario 3: External traffic not reaching the cluster ─────────────
# Check Ingress controller Pods
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=50

# Check Ingress resource status
kubectl describe ingress <ingress-name> -n production
# Events section shows ALB/NLB provisioning status

# Verify the Service backend is healthy
kubectl get endpoints <backend-service> -n production
```

### 8.4 Storage Failures

```bash
# ── Scenario 1: PVC stuck in Pending ─────────────────────────────────
kubectl describe pvc <pvc-name> -n <namespace>
# Events show the reason:

# "no persistent volumes available for this claim"
# → No matching PV exists; check StorageClass and if provisioner is running:
kubectl get pods -n kube-system | grep csi
kubectl logs -n kube-system <csi-controller-pod> --tail=50

# "waiting for first consumer to be created before binding"
# → WaitForFirstConsumer binding mode; normal — PVC binds when Pod is scheduled

# "ProvisioningFailed: failed to create volume... InvalidParameterValue"
# → AWS/GCP/Azure provisioner error; check CSI driver logs for details

# ── Scenario 2: Pod stuck in ContainerCreating with volume errors ──────
kubectl describe pod <pod-name> -n <namespace>
# Events:
# "AttachVolume.Attach failed: volume is already used by another node"
# → RWO volume attached to a different node; old Pod not cleanly terminated
# Fix: Force-delete the old Pod:
kubectl delete pod <old-pod> -n <namespace> --grace-period=0 --force
# Then wait for the new Pod to attach the volume

# "MountVolume.MountDevice failed: waiting for volume to be available"
# → Cloud provider volume detachment in progress; wait 1-2 minutes

# ── Scenario 3: Disk pressure causing Pod evictions ────────────────────
# Check node disk usage
kubectl describe node <node-name> | grep -A 5 "DiskPressure"
kubectl get node <node-name> -o json | jq '.status.conditions[] | select(.type=="DiskPressure")'

# SSH to node and check disk usage
ssh <node>
df -h
du -sh /var/lib/kubelet/*
du -sh /var/lib/containerd/*

# Remove unused container images (safe to run on any node)
crictl rmi --prune
```

### 8.5 Control Plane Failures

```bash
# ── API server not responding ─────────────────────────────────────────
# If kubectl commands hang or return "connection refused":

# Check if the API server container is running on the control plane node
ssh cp-1
crictl ps -a | grep kube-apiserver

# Check API server logs
crictl logs <apiserver-container-id> --tail=100 2>&1 | grep -E "error|fatal|panic"

# Common causes:
# 1. etcd not reachable — check etcd status:
ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  endpoint health

# 2. Certificate expired:
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -dates

# 3. etcd disk quota exceeded (database too large):
ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  endpoint status -w table
# Check DB SIZE — if near quota (default 2GiB), compact and defragment:

# Compact etcd (remove old revisions)
REV=$(ETCDCTL_API=3 etcdctl endpoint status \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  --write-out json | jq .[].Status.header.revision)

ETCDCTL_API=3 etcdctl compact $REV \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Defragment etcd (reclaim disk space after compaction)
ETCDCTL_API=3 etcdctl defrag \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# ── Node not joining / NotReady ───────────────────────────────────────
# Check kubelet status on the worker node
ssh worker-1
systemctl status kubelet
journalctl -u kubelet --since "10 minutes ago" | tail -50

# Common kubelet error patterns:
# "failed to get node info: nodes "worker-1" not found"
# → kubeconfig wrong; node hasn't joined yet; check kubeadm join output

# "Failed to create pod sandbox: rpc error: ... failed to start container"
# → containerd problem; check containerd service

systemctl status containerd
journalctl -u containerd --since "10 minutes ago" | tail -50

# "tls: failed to verify certificate"
# → Cluster CA cert changed or expired; rejoin the node

# ── Crashlooping control plane component ─────────────────────────────
kubectl get pods -n kube-system
# kube-controller-manager-cp-1   0/1   CrashLoopBackOff   15   45m

kubectl logs -n kube-system kube-controller-manager-cp-1 --previous | tail -30
# Look for certificate errors, unreachable API server, or config errors

# For static Pod-based control plane (kubeadm), check the manifest:
cat /etc/kubernetes/manifests/kube-controller-manager.yaml
# Verify --kubeconfig path exists and cert files exist
ls -la /etc/kubernetes/controller-manager.conf
ls -la /etc/kubernetes/pki/
```

---

## 9. Real-World Scenario: Emergency etcd Recovery at 3 AM

### The Incident

A senior engineer at FinServ Corp accidentally runs `kubectl delete ns production` while logged into the wrong cluster context. The production namespace — containing 47 Deployments, 200+ ConfigMaps, 80 Secrets, and 12 StatefulSets — is deleted within 4 seconds. The on-call alert fires as the monitoring stack loses its targets.

### The Runbook

**T+0:00 — Alert fires. On-call engineer is paged.**

```bash
# Confirm the context — it is production
kubectl config current-context
# production-cluster

# Confirm the namespace is gone
kubectl get ns production
# Error from server (NotFound): namespaces "production" not found

# Immediately check if the deletion is still propagating
kubectl get pods -A | grep production   # None — complete deletion
```

**T+0:03 — Decide on recovery strategy.**

The last etcd snapshot was taken 2 hours ago (automated every 2 hours). A full restore will revert the cluster to its state 2 hours prior — acceptable for this incident.

**T+0:05 — Begin restore procedure.**

```bash
# Download the most recent snapshot
aws s3 cp \
  s3://finserv-cluster-backups/etcd/etcd-snapshot-20240315-020000.db \
  /tmp/etcd-snapshot.db

# Verify the snapshot
ETCDCTL_API=3 etcdctl snapshot status /tmp/etcd-snapshot.db --write-out=table
# HASH         REVISION  TOTAL KEYS  TOTAL SIZE
# 3a5f8b9c     1847293   91,443      2.1 GB
```

**T+0:10 — Stop control plane on all three nodes, restore etcd, restart.**

Full restore procedure from Section 4.2.

**T+0:35 — Cluster restored. Verify integrity.**

```bash
kubectl get ns production          # Exists
kubectl get pods -n production     # All 47 Deployments recovering
kubectl get deployments -n production | wc -l   # 47

# Services are back but IPs may have changed — check Ingress status
kubectl get ingress -n production
```

**T+0:50 — Full service restored. 47 minutes of production downtime.**

### Post-Incident Changes

1. **Context guard:** All engineers must use `kubectx` aliases that colour-code production contexts red and require an explicit `KUBECTL_ALLOW_PROD=true` env var for destructive commands.
2. **Namespace protection:** Apply the `kubernetes.io/protected: "true"` annotation check via a Kyverno `ClusterPolicy` that prevents deletion of the production namespace without an explicit override label.
3. **etcd backup frequency:** Increased from every 2 hours to every 15 minutes. RPO reduced from 2 hours to 15 minutes.
4. **Restore drills:** Monthly restore drill to a staging cluster, measuring and verifying RTO.

---

## 10. Common Pitfalls & Best Practices

### Pitfall 1: Running kubeadm Clusters with Default Certificate Validity
kubeadm generates certificates with a 1-year validity. Many teams discover this when the cluster suddenly stops working exactly 365 days after creation. Set a calendar reminder 60 days before expiry and run `kubeadm certs renew all` during a maintenance window. With auto-renewal configured for kubelet (`rotateCertificates: true`), only the control plane certificates require manual rotation.

### Pitfall 2: No etcd Backup = No Cluster Recovery
The etcd data directory is the entire cluster. Without a backup, a corrupt etcd volume or an accidental `kubectl delete ns` cannot be recovered. Implement automated etcd snapshots every 15-30 minutes, store them in an offsite location (S3, GCS, Azure Blob), and test restores monthly. "A backup you have never tested is not a backup."

### Pitfall 3: ClusterRoleBindings to `cluster-admin` for CI/CD Systems
Every CI/CD pipeline that deploys to Kubernetes gets a ServiceAccount. The easiest path — giving that SA `cluster-admin` — means a compromised build pipeline can delete all cluster resources, exfiltrate all Secrets, and escalate to any workload. Apply least-privilege Role bindings per namespace. A deployment pipeline needs `update` on Deployments in one namespace, not `delete` on everything.

### Pitfall 4: Draining Nodes Without Checking PodDisruptionBudgets
`kubectl drain` respects PDBs by default, but engineers under time pressure sometimes add `--force` or `--disable-eviction` to push through a drain. If a service has `minAvailable: 3` and you force-drain the node running 2 of its 3 Pods, you cause an availability incident. Always investigate why a drain is blocked before overriding it.

### Pitfall 5: Upgrading More Than One Minor Version at a Time
Kubernetes only supports upgrading one minor version at a time. Attempting to upgrade from 1.28 directly to 1.30 with `kubeadm upgrade apply v1.30.0` will fail. Each minor version upgrade must be applied and validated before the next. Plan a 30-60 minute maintenance window per minor version upgrade, plus rollback time.

### Pitfall 6: Ignoring Admission Controller Failures
When an admission webhook is unreachable or returns an error, the API server behaviour depends on the webhook's `failurePolicy`: `Ignore` (allow through) or `Fail` (reject the request). A webhook with `failurePolicy: Fail` that crashes will block all Pod creation in the cluster. Monitor webhook response latency and error rates; set `failurePolicy: Ignore` for non-critical policy webhooks with a clear understanding of the security implications.

> **Kubernetes Administrator Production Checklist**
> - [ ] HA control plane: 3 or 5 control plane nodes across availability zones
> - [ ] etcd snapshots every 15 minutes; stored offsite; restore tested monthly
> - [ ] Certificate expiry monitored; renewal scheduled 60 days before expiry
> - [ ] `rotateCertificates: true` in KubeletConfiguration for automatic kubelet cert rotation
> - [ ] RBAC audit: no ServiceAccounts with `cluster-admin` except system components
> - [ ] Pod Security Admission enforced at `restricted` level in production namespaces
> - [ ] Admission webhook failure policies reviewed; critical webhooks monitored
> - [ ] Node upgrade procedure documented and tested in staging first
> - [ ] PodDisruptionBudgets on all stateful and HA workloads
> - [ ] Kubernetes version within 2 minor versions of current stable release
> - [ ] API server audit logging enabled and shipped to centralised log store
> - [ ] etcd quota-backend-bytes configured (default 2GiB is often too small)
> - [ ] Cluster context guard in place (colour-coded or requires explicit confirmation)
> - [ ] Troubleshooting runbooks documented for: Pending Pods, DNS failures, etcd issues

---

## 11. Key Takeaways

1. **The Kubernetes control plane is a set of cooperating processes communicating over mTLS.** Every component has its own certificate and kubeconfig. Understanding this certificate map is the foundation of both security hardening and incident response — most "cluster is broken" incidents come down to a certificate, a connection, or an etcd issue.

2. **etcd is the cluster's single source of truth and its single point of failure.** A healthy cluster with a corrupt etcd is unrecoverable without a backup. Treat etcd backups with the same urgency as database backups: automated, frequent, offsite, and tested.

3. **Certificate rotation is a maintenance task, not an emergency.** kubeadm-managed clusters require manual certificate rotation once per year. Build it into your operational calendar. Automated kubelet certificate rotation (`rotateCertificates: true`) eliminates the most frequent certificate issue for worker nodes.

4. **RBAC is the most under-audited security control in most Kubernetes clusters.** A single `ClusterRoleBinding` to `cluster-admin` for a CI/CD ServiceAccount can undo every other security control in the cluster. Audit RBAC quarterly using `kubectl auth can-i --list` and the `who-can` plugin. Apply the principle of least privilege at every binding.

5. **Admission Controllers are the enforcement layer that makes policy real.** PSA prevents privileged containers. Kyverno and OPA/Gatekeeper enforce custom compliance rules. Mutating webhooks inject sidecars, default labels, and security contexts. Together they form a defence-in-depth layer that catches misconfigurations before they reach production.

6. **Troubleshooting Kubernetes is a layered process.** Start with the symptom, work down through workload → scheduling → networking → storage → control plane layers. `kubectl describe`, `kubectl get events`, `kubectl logs --previous`, and component log inspection via `crictl logs` cover 90% of production incidents.

---

## 12. Exercises & Labs

**Exercise 1: kubeadm Cluster Bootstrap**
Using three VMs or cloud instances, bootstrap a Kubernetes cluster with one control plane node and two worker nodes using the `ClusterConfiguration` from Section 3.3. Install Calico as the CNI. Verify: (a) all nodes are `Ready`, (b) CoreDNS Pods are running, (c) a test Deployment schedules across both worker nodes. Then cordon one worker node and verify new Pods are not scheduled there.

**Exercise 2: etcd Backup and Restore Drill**
On your kubeadm cluster, create a test namespace with 10 Deployments and 5 ConfigMaps. Take an etcd snapshot with `etcdctl snapshot save`. Delete the namespace. Perform a full etcd restore from the snapshot following Section 4.2. Verify the namespace and all its resources are restored. Measure and record the total time from backup to restored service.

**Exercise 3: Certificate Expiry Simulation**
Run `kubeadm certs check-expiration` and record all expiry dates. Manually set the system clock forward 11 months (do this in a test environment only). Verify `kubeadm certs check-expiration` shows certificates as near-expiry. Run `kubeadm certs renew all`, restart the control plane Pods, and verify the cluster recovers and all certificates have new expiry dates.

**Exercise 4: RBAC Hardening Audit**
On a test cluster, deliberately create an overprivileged scenario: bind a `default` ServiceAccount to `cluster-admin`. Then: (a) use `kubectl auth can-i --list --as=system:serviceaccount:default:default` to document all permissions, (b) delete the binding, (c) create a minimal Role with only `get/list/watch` on Pods in one namespace, (d) create a RoleBinding, (e) verify the SA can read Pods but cannot delete them or create Deployments.

**Exercise 5: Zero-Downtime Upgrade**
Starting from Kubernetes 1.29 on a 3-node kubeadm cluster (1 control plane, 2 workers), perform a full upgrade to 1.30 following Section 6.2. Before each drain, verify the application under test is still serving requests (use `curl` in a loop or `hey` for load testing). After the upgrade, confirm: (a) all nodes show `v1.30.x`, (b) no requests were dropped during the rolling upgrade, (c) `kubectl get pods -A` shows all system Pods healthy.

---

*End of Chapter 8*

**Next → Chapter 9: Kubernetes Security**



---

──────────────────────────────────────────────────────────────────────

## Part IX: Kubernetes Security

> *4Cs · PSA · NetworkPolicy · Vault · Trivy · Falco · CIS Benchmarks*

──────────────────────────────────────────────────────────────────────


## 1. Introduction & Learning Objectives

Security is not a feature you add to a Kubernetes cluster after it is built. It is an architectural property woven through every layer of the system — from the cloud provider's IAM policies down to the code your application executes. A single misconfigured admission webhook, an overly permissive NetworkPolicy, or a container running as root can unravel years of investment in application reliability and data protection.

The Kubernetes security landscape is wide. This chapter organises it using the **4Cs framework** — Cloud, Cluster, Container, Code — which maps each security control to the layer where it is most effectively enforced. We then deep-dive into the most operationally important controls: Pod Security Admission for workload isolation, NetworkPolicies for network segmentation, secrets management patterns from Kubernetes-native Secrets through HashiCorp Vault, image scanning with Trivy and Snyk, runtime threat detection with Falco, and the CIS Kubernetes Benchmark as an audit framework for assessing and improving cluster security posture.

This chapter is not theoretical. Every control is demonstrated with the exact configuration, tooling, and operational pattern used in production environments.

> **Learning Objectives**
> - Apply the 4Cs framework to map security controls to the correct enforcement layer.
> - Configure Pod Security Admission at the `restricted` profile across production namespaces.
> - Design and implement NetworkPolicies that enforce a default-deny posture with explicit allow rules.
> - Choose the right secrets management pattern for your threat model: Kubernetes Secrets, Sealed Secrets, External Secrets Operator, or HashiCorp Vault.
> - Integrate Trivy and Snyk into CI/CD pipelines as blocking security gates.
> - Deploy Falco for real-time runtime threat detection and alert on container escape attempts, privilege escalation, and sensitive file access.
> - Run the CIS Kubernetes Benchmark using `kube-bench` and interpret the findings by severity.
> - Implement a defence-in-depth security model that reduces blast radius when any single control fails.

---

## 2. Core Concepts

### 2.1 The 4Cs of Cloud-Native Security

The 4Cs model was established by the CNCF to communicate that cloud-native security is not a single control but a set of nested, mutually reinforcing layers. A vulnerability that bypasses the Code layer still faces the Container layer. One that bypasses the Container layer still faces the Cluster layer. Defence in depth is not redundancy — it is the recognition that no single layer is impenetrable.

```
┌──────────────────────────────────────────────────────────────────────┐
│  CLOUD                                                                │
│  IAM policies · VPC/security groups · KMS encryption · audit logs   │
│  Provider-managed control plane security · Node OS hardening        │
│                                                                       │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │  CLUSTER                                                        │  │
│  │  RBAC · Admission Controllers · NetworkPolicy · etcd at-rest  │  │
│  │  encryption · API server audit · Pod Security Admission        │  │
│  │  Certificate rotation · CIS Benchmark compliance               │  │
│  │                                                                 │  │
│  │  ┌──────────────────────────────────────────────────────────┐  │  │
│  │  │  CONTAINER                                                │  │  │
│  │  │  Image scanning · Minimal base images · Non-root user    │  │  │
│  │  │  Read-only filesystem · Dropped capabilities             │  │  │
│  │  │  Runtime security (Falco) · seccomp · AppArmor           │  │  │
│  │  │                                                           │  │  │
│  │  │  ┌────────────────────────────────────────────────────┐  │  │  │
│  │  │  │  CODE                                              │  │  │  │
│  │  │  │  SAST/DAST · Dependency scanning · SBOM           │  │  │  │
│  │  │  │  Secret detection in source · mTLS in transit     │  │  │  │
│  │  │  │  Input validation · Secure coding standards       │  │  │  │
│  │  │  └────────────────────────────────────────────────────┘  │  │  │
│  │  └──────────────────────────────────────────────────────────┘  │  │
│  └────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────┘
```

#### Security Controls by Layer

| Layer | Primary Controls | Failure Mode if Missing |
|---|---|---|
| Cloud | IAM least privilege, VPC isolation, KMS encryption, provider audit logs | Node compromise grants access to all cloud resources |
| Cluster | RBAC, PSA, NetworkPolicy, etcd encryption, admission controllers | Any authenticated user can escalate to full cluster access |
| Container | Non-root, read-only FS, capability drop, image scanning, seccomp | Container breakout → node compromise |
| Code | Dependency scanning, secret scanning, mTLS, input validation | Application vulnerability → data exfiltration |

---

### 2.2 Pod Security Admission — Deep Dive

Pod Security Admission (PSA) is the built-in Kubernetes admission controller that enforces the **Pod Security Standards** — three progressively restrictive security profiles for Pod specifications.

#### The Three Pod Security Profiles

```
privileged  → No restrictions. Use only for trusted system components
              (kube-system, monitoring, CNI DaemonSets).
              Example: Falco, node-exporter, CSI driver Pods.

baseline    → Prevents known privilege escalations.
              Blocks: hostPID, hostIPC, hostNetwork, hostPorts,
                      privileged containers, unsafe sysctls,
                      host path volumes (most paths),
                      non-default AppArmor profiles.
              Allows: Running as root, writable filesystem.
              Example: web servers, APIs, most application workloads.

restricted  → Fully hardened. Includes everything in baseline plus:
              Requires: runAsNonRoot, seccompProfile RuntimeDefault/Localhost,
                        drop ALL capabilities, no privilege escalation,
                        no /proc mount type other than Default.
              Example: PCI-DSS, HIPAA, financial workloads.
```

#### Namespace Labels for PSA

PSA operates through namespace labels. Each namespace can have three modes — `enforce`, `audit`, and `warn` — applied independently to any profile level.

```yaml
# Strategy: Start with warn+audit, then promote to enforce once violations resolved
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    # Enforce: reject Pods violating 'restricted' profile
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: v1.30

    # Audit: log violations in the API server audit log
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/audit-version: v1.30

    # Warn: send warnings in kubectl output (non-blocking)
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/warn-version: v1.30
```

```yaml
# Namespace strategy by environment
# dev: warn only — developers see issues but aren't blocked
# staging: audit + warn — violations logged and visible
# production: enforce + audit + warn — violations rejected

apiVersion: v1
kind: Namespace
metadata:
  name: development
  labels:
    pod-security.kubernetes.io/warn: baseline
    pod-security.kubernetes.io/warn-version: v1.30
---
apiVersion: v1
kind: Namespace
metadata:
  name: staging
  labels:
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/audit-version: v1.30
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/warn-version: v1.30
---
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: v1.30
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/audit-version: v1.30
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/warn-version: v1.30
```

#### Fully PSA-Compliant Pod Specification

```yaml
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
  template:
    metadata:
      labels:
        app: order-api
    spec:
      # Pod-level security context
      securityContext:
        runAsNonRoot: true              # Required by 'restricted'
        runAsUser: 10001                # Non-root UID
        runAsGroup: 10001
        fsGroup: 10001
        fsGroupChangePolicy: OnRootMismatch  # Only change ownership if needed
        seccompProfile:
          type: RuntimeDefault          # Required by 'restricted'

      # No service account token mounting if not needed
      automountServiceAccountToken: false

      containers:
        - name: api
          image: myapp/order-api:1.4.2@sha256:3d88c5de...
          ports:
            - containerPort: 8080

          # Container-level security context
          securityContext:
            allowPrivilegeEscalation: false   # Required by 'restricted'
            readOnlyRootFilesystem: true        # Required by 'restricted'
            runAsNonRoot: true
            runAsUser: 10001
            capabilities:
              drop:
                - ALL                          # Required by 'restricted'
              # Only add back if absolutely necessary:
              # add: ["NET_BIND_SERVICE"]       # If binding to port < 1024

          resources:
            requests:
              cpu: "250m"
              memory: "256Mi"
            limits:
              cpu: "500m"
              memory: "512Mi"

          # App needs to write — use dedicated writable volumes, not rootfs
          volumeMounts:
            - name: tmp-dir
              mountPath: /tmp
            - name: app-cache
              mountPath: /app/cache
            - name: app-logs
              mountPath: /app/logs

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

      volumes:
        - name: tmp-dir
          emptyDir: {}        # Writable scratch space
        - name: app-cache
          emptyDir: {}
        - name: app-logs
          emptyDir: {}
```

```bash
# Check if existing workloads violate the 'restricted' profile (dry-run)
# Before labelling production namespace with 'enforce: restricted':
kubectl label namespace production \
  pod-security.kubernetes.io/warn=restricted \
  pod-security.kubernetes.io/warn-version=v1.30 \
  --dry-run=server

# Find all Pods in production that would be rejected
kubectl get pods -n production -o json | \
  kubectl-convert --output-version=v1 - | \
  kubectl apply --dry-run=server \
    --validate=true \
    -f - 2>&1 | grep "Warning:"
```

---

### 2.3 NetworkPolicies — Zero-Trust Network Segmentation

By default, Kubernetes allows all Pod-to-Pod communication — any Pod can reach any other Pod across any namespace. NetworkPolicies are the mechanism for restricting this. Critically, **NetworkPolicies are additive**: a Pod with no NetworkPolicy has unrestricted ingress and egress. A Pod with any NetworkPolicy has all traffic blocked except what the policy explicitly allows.

#### Default-Deny Foundation

```yaml
# Apply to every namespace as the first policy — deny everything,
# then explicitly allow only required traffic.

---
# Default deny all ingress
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: production
spec:
  podSelector: {}        # Applies to ALL Pods in the namespace
  policyTypes:
    - Ingress
  # No ingress rules = deny all ingress

---
# Default deny all egress
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-egress
  namespace: production
spec:
  podSelector: {}
  policyTypes:
    - Egress
  # No egress rules = deny all egress

---
# Allow DNS egress for all Pods (DNS is required for name resolution)
# Always add this alongside default-deny-egress
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-egress
  namespace: production
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
```

#### Service-Specific NetworkPolicies

```yaml
# Allow ingress to order-api from api-gateway only
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: order-api-ingress
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: order-api
  policyTypes:
    - Ingress
  ingress:
    # From api-gateway Pods in the same namespace
    - from:
        - podSelector:
            matchLabels:
              app: api-gateway
      ports:
        - protocol: TCP
          port: 8080
    # From Prometheus scraping metrics
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: monitoring
          podSelector:
            matchLabels:
              app: prometheus
      ports:
        - protocol: TCP
          port: 9090

---
# Allow egress from order-api to postgres and redis only
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: order-api-egress
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: order-api
  policyTypes:
    - Egress
  egress:
    # To PostgreSQL
    - to:
        - podSelector:
            matchLabels:
              app: postgres
      ports:
        - protocol: TCP
          port: 5432
    # To Redis
    - to:
        - podSelector:
            matchLabels:
              app: redis
      ports:
        - protocol: TCP
          port: 6379
    # To notification-service (different namespace)
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: messaging
          podSelector:
            matchLabels:
              app: notification-svc
      ports:
        - protocol: TCP
          port: 8080
    # To external payment gateway (specific CIDR)
    - to:
        - ipBlock:
            cidr: 192.0.2.0/24      # Payment gateway IP range
      ports:
        - protocol: TCP
          port: 443

---
# Allow metrics scraping from monitoring namespace to all Pods
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-prometheus-scrape
  namespace: production
spec:
  podSelector: {}         # All Pods in production
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: monitoring
          podSelector:
            matchLabels:
              app: prometheus
      ports:
        - protocol: TCP
          port: 9090
```

```bash
# Test NetworkPolicy enforcement
# Deploy a debug Pod and try to reach a blocked service
kubectl run netpol-test \
  --image=nicolaka/netshoot \
  --restart=Never \
  --namespace=production \
  -it --rm \
  -- curl -v --connect-timeout 5 http://postgres:5432
# Should timeout — test Pod doesn't have label 'app: order-api'

# Test from an allowed source
kubectl exec -n production deploy/order-api -- \
  nc -zv postgres 5432
# Connection to postgres 5432 port [tcp/postgresql] succeeded!

# Verify with network policy audit tools
# Install netassert or network-policy-explorer:
kubectl krew install np-viewer
kubectl np-viewer -n production
# Shows a visual map of allowed connections between Pods
```

---

### 2.4 Secrets Management

Kubernetes Secrets provide a basic abstraction for sensitive data, but their default implementation has significant security limitations that must be understood before choosing a secrets management strategy.

#### Kubernetes Secrets — Default Limitations

```
Default Kubernetes Secrets:
  ├── Stored in etcd as base64-encoded strings (NOT encrypted by default)
  ├── Anyone with 'get secrets' RBAC permission can read all values
  ├── Projected into Pods as environment variables or files
  ├── No audit trail of who accessed which secret value
  └── No automatic rotation mechanism

Minimum production hardening:
  ├── Enable etcd encryption at rest (EncryptionConfiguration)
  ├── Restrict RBAC: no 'get secrets' except for specific SAs
  └── Never use 'list secrets' permissions (returns all values)
```

#### etcd Encryption at Rest

```yaml
# /etc/kubernetes/encryption-config.yaml
# Reference this in kube-apiserver with: --encryption-provider-config
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
      - configmaps          # Optionally encrypt ConfigMaps too
    providers:
      # AES-GCM with a 256-bit key (recommended)
      - aescbc:
          keys:
            - name: key1
              # Generate: head -c 32 /dev/urandom | base64
              secret: <base64-encoded-32-byte-key>
      # Identity = no encryption (fallback for reading old unencrypted secrets)
      - identity: {}

# After applying this config, existing Secrets are NOT retroactively encrypted.
# Force re-encrypt all existing Secrets:
# kubectl get secrets -A -o json | kubectl replace -f -
```

#### Sealed Secrets — GitOps-Safe Encryption

Sealed Secrets is a Bitnami project that solves the GitOps dilemma: how do you store secrets in Git (which is your source of truth) without storing plaintext secrets in Git?

```
Architecture:
  kubeseal CLI + SealedSecret CRD + Sealed Secrets Controller

  Developer:  plaintext Secret → kubeseal → SealedSecret (encrypted)
  Git:        SealedSecret YAML committed safely
  Cluster:    Controller decrypts SealedSecret → creates Kubernetes Secret
  Only the controller inside the cluster can decrypt it.
```

```bash
# Install Sealed Secrets controller
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm repo update
helm install sealed-secrets sealed-secrets/sealed-secrets \
  --namespace kube-system \
  --version 2.16.0

# Install kubeseal CLI
brew install kubeseal   # macOS
# or download binary from GitHub releases

# Create a SealedSecret from an existing Secret
kubectl create secret generic db-creds \
  --from-literal=username=myuser \
  --from-literal=password=supersecret \
  --dry-run=client \
  -o yaml | \
  kubeseal \
    --controller-name=sealed-secrets \
    --controller-namespace=kube-system \
    --format=yaml \
  > db-creds-sealed.yaml

# db-creds-sealed.yaml is now safe to commit to Git
cat db-creds-sealed.yaml
# apiVersion: bitnami.com/v1alpha1
# kind: SealedSecret
# metadata:
#   name: db-creds
#   namespace: production
# spec:
#   encryptedData:
#     username: AgB3...   ← asymmetrically encrypted with controller's public key
#     password: AgA9...

# Apply to cluster — controller decrypts and creates the real Secret
kubectl apply -f db-creds-sealed.yaml

# Verify the real Secret was created
kubectl get secret db-creds -n production

# IMPORTANT: Backup the sealing key pair (controller generates it on install)
# Loss of the sealing key means all SealedSecrets are permanently undecryptable
kubectl get secret -n kube-system \
  -l sealedsecrets.bitnami.com/sealed-secrets-key \
  -o yaml > sealing-key-backup.yaml
# Store this in a secure vault (Vault, AWS Secrets Manager, Azure Key Vault)
```

#### External Secrets Operator — Cloud-Native Secret Sync

The External Secrets Operator (ESO) syncs secrets from external secret stores (AWS Secrets Manager, Azure Key Vault, GCP Secret Manager, HashiCorp Vault) into Kubernetes Secrets, with automatic rotation support.

```bash
# Install External Secrets Operator
helm repo add external-secrets https://charts.external-secrets.io
helm repo update
helm install external-secrets external-secrets/external-secrets \
  --namespace external-secrets \
  --create-namespace \
  --version 0.9.19
```

```yaml
# ClusterSecretStore — defines the connection to the external secret backend
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: aws-secrets-manager
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        # Use IRSA (EKS) — no static credentials
        jwt:
          serviceAccountRef:
            name: external-secrets-sa
            namespace: external-secrets

---
# ExternalSecret — declares which secret to sync and how
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: order-api-db-creds
  namespace: production
spec:
  refreshInterval: 1h               # Re-sync every hour (picks up rotations)
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  target:
    name: order-api-db-creds        # Creates this Kubernetes Secret
    creationPolicy: Owner           # ESO owns the Secret; deletes it when ExternalSecret is deleted
    template:
      type: Opaque
      data:
        # Transform the external secret values into the format your app expects
        DATABASE_URL: "postgresql://{{ .username }}:{{ .password }}@postgres:5432/orders"
  data:
    - secretKey: username
      remoteRef:
        key: production/order-api/database    # Path in AWS Secrets Manager
        property: username                    # JSON field in the secret value
    - secretKey: password
      remoteRef:
        key: production/order-api/database
        property: password

---
# ExternalSecret — sync all fields from a single Secrets Manager secret
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: order-api-all-creds
  namespace: production
spec:
  refreshInterval: 30m
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  target:
    name: order-api-all-creds
  dataFrom:
    - extract:
        key: production/order-api/all-secrets   # All JSON fields become K8s Secret keys
```

#### HashiCorp Vault with Kubernetes Auth

HashiCorp Vault is the most powerful secrets management solution — supporting dynamic secrets, fine-grained policies, full audit trail, and automatic rotation.

```bash
# Install Vault with the Vault Agent Injector (sidecar-based injection)
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

helm install vault hashicorp/vault \
  --namespace vault \
  --create-namespace \
  --set "server.ha.enabled=true" \
  --set "server.ha.replicas=3" \
  --set "injector.enabled=true" \
  --version 0.28.0

# Initialize and unseal Vault (first-time setup)
kubectl exec -n vault vault-0 -- vault operator init \
  -key-shares=5 \
  -key-threshold=3 \
  -format=json > vault-init.json
# STORE vault-init.json SECURELY — contains unseal keys and root token

# Unseal (requires 3 of 5 keys)
kubectl exec -n vault vault-0 -- vault operator unseal $(jq -r .unseal_keys_b64[0] vault-init.json)
kubectl exec -n vault vault-0 -- vault operator unseal $(jq -r .unseal_keys_b64[1] vault-init.json)
kubectl exec -n vault vault-0 -- vault operator unseal $(jq -r .unseal_keys_b64[2] vault-init.json)

# Enable Kubernetes authentication method
VAULT_TOKEN=$(jq -r .root_token vault-init.json)
kubectl exec -n vault vault-0 -- vault auth enable kubernetes

# Configure the Kubernetes auth method
kubectl exec -n vault vault-0 -- vault write auth/kubernetes/config \
  kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443"

# Create a Vault policy for order-api
kubectl exec -n vault vault-0 -- vault policy write order-api-policy - <<'EOF'
path "secret/data/production/order-api/*" {
  capabilities = ["read"]
}
path "database/creds/order-api-role" {
  capabilities = ["read"]     # Dynamic database credentials
}
EOF

# Create a Vault role binding the K8s SA to the policy
kubectl exec -n vault vault-0 -- vault write auth/kubernetes/role/order-api \
  bound_service_account_names=order-api-sa \
  bound_service_account_namespaces=production \
  policies=order-api-policy \
  ttl=1h

# Store a secret in Vault
kubectl exec -n vault vault-0 -- vault kv put \
  secret/production/order-api/database \
  username=myuser \
  password=supersecret
```

```yaml
# Vault Agent Injector — inject secrets as sidecar without app code changes
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-api
  namespace: production
spec:
  template:
    metadata:
      annotations:
        # Tell the Vault Agent Injector to inject secrets into this Pod
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/role: "order-api"

        # Inject secret as a file: /vault/secrets/database-config.txt
        vault.hashicorp.com/agent-inject-secret-database-config.txt: >
          secret/data/production/order-api/database

        # Template the secret into a specific format
        vault.hashicorp.com/agent-inject-template-database-config.txt: |
          {{- with secret "secret/data/production/order-api/database" -}}
          DATABASE_URL=postgresql://{{ .Data.data.username }}:{{ .Data.data.password }}@postgres:5432/orders
          {{- end }}

        # Dynamic database credentials (Vault generates short-lived DB passwords)
        vault.hashicorp.com/agent-inject-secret-db-creds.txt: >
          database/creds/order-api-role
        vault.hashicorp.com/agent-inject-template-db-creds.txt: |
          {{- with secret "database/creds/order-api-role" -}}
          DB_USER={{ .Data.username }}
          DB_PASS={{ .Data.password }}
          {{- end }}

    spec:
      serviceAccountName: order-api-sa
      containers:
        - name: api
          image: myapp/order-api:1.4.2
          # App reads secrets from /vault/secrets/ — no env vars, no Kubernetes Secrets
          command: ["/bin/sh", "-c"]
          args:
            - source /vault/secrets/database-config.txt && exec /app/server
```

---

### 2.5 Image Scanning — Shifting Security Left

Container image vulnerabilities are one of the most common entry points for container-level attacks. Image scanning should be a non-optional, blocking gate in every CI/CD pipeline.

#### Trivy — Comprehensive Open-Source Scanner

```bash
# Install Trivy
brew install aquasecurity/trivy/trivy   # macOS
# or
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
  | sh -s -- -b /usr/local/bin

# ── Basic image scan ──────────────────────────────────────────────────
trivy image nginx:1.25-alpine

# ── Production CI gate: fail on CRITICAL/HIGH, ignore unfixed ─────────
trivy image \
  --exit-code 1 \
  --severity CRITICAL,HIGH \
  --ignore-unfixed \
  --format table \
  myapp/order-api:1.4.2

# ── Full scan with SBOM and JSON output ────────────────────────────────
trivy image \
  --format json \
  --output trivy-report.json \
  --list-all-pkgs \
  myapp/order-api:1.4.2

# Parse results
cat trivy-report.json | jq '
  .Results[] |
  select(.Vulnerabilities != null) |
  {
    Target: .Target,
    Critical: [.Vulnerabilities[] | select(.Severity=="CRITICAL")] | length,
    High: [.Vulnerabilities[] | select(.Severity=="HIGH")] | length
  }
'

# ── Scan a Kubernetes cluster in-place (all running images) ───────────
trivy k8s --report=summary cluster

# ── Scan IaC files (Kubernetes YAML, Dockerfile, Terraform) ───────────
trivy config ./k8s/
# Checks for:
# - Containers running as root
# - Missing resource limits
# - Privileged containers
# - Missing readiness probes
# - Secrets in environment variables
# - Missing network policies

# ── Generate SBOM (Software Bill of Materials) ────────────────────────
trivy image \
  --format cyclonedx \
  --output sbom.json \
  myapp/order-api:1.4.2

# ── Trivy in GitHub Actions ───────────────────────────────────────────
# .github/workflows/security.yml extract:
# - name: Run Trivy vulnerability scanner
#   uses: aquasecurity/trivy-action@master
#   with:
#     image-ref: ${{ env.IMAGE }}
#     format: sarif
#     output: trivy-results.sarif
#     severity: CRITICAL,HIGH
#     exit-code: 1
#     ignore-unfixed: true
# - name: Upload Trivy scan results to GitHub Security tab
#   uses: github/codeql-action/upload-sarif@v3
#   with:
#     sarif_file: trivy-results.sarif
```

#### Trivy as a Kubernetes Admission Controller (Trivy Operator)

```bash
# Install Trivy Operator — continuously scans running workloads
helm repo add aqua https://aquasecurity.github.io/helm-charts/
helm repo update
helm install trivy-operator aqua/trivy-operator \
  --namespace trivy-system \
  --create-namespace \
  --set="trivy.ignoreUnfixed=true" \
  --version 0.23.0

# Trivy Operator creates VulnerabilityReport and ConfigAuditReport CRDs
# automatically for every workload

# View vulnerability reports
kubectl get vulnerabilityreports -n production
kubectl describe vulnerabilityreport \
  replicaset-order-api-7d9b-order-api \
  -n production

# View config audit reports (security misconfigurations)
kubectl get configauditreports -n production -o table
```

#### Snyk — Developer-First Security Platform

```bash
# Install Snyk CLI
npm install -g snyk
snyk auth   # Authenticate with your Snyk account

# Scan container image
snyk container test myapp/order-api:1.4.2 \
  --severity-threshold=high \
  --file=Dockerfile

# Monitor image in Snyk (sends results to Snyk dashboard for ongoing tracking)
snyk container monitor myapp/order-api:1.4.2 \
  --project-name=order-api-production

# Scan application dependencies (in addition to OS packages)
snyk test \
  --severity-threshold=high \
  --json \
  > snyk-report.json

# Scan Kubernetes manifests for misconfigurations
snyk iac test k8s/ \
  --severity-threshold=medium \
  --report

# Snyk in CI/CD (GitHub Actions):
# - name: Run Snyk to check for vulnerabilities
#   uses: snyk/actions/node@master
#   env:
#     SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
#   with:
#     args: --severity-threshold=high
```

#### Image Policy with Kyverno

```yaml
# Kyverno policy: require images from approved registries only
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: restrict-image-registries
spec:
  validationFailureAction: Enforce
  background: true
  rules:
    - name: validate-registry
      match:
        any:
          - resources:
              kinds: ["Pod"]
              namespaces: ["production", "staging"]
      validate:
        message: "Images must come from approved registries."
        pattern:
          spec:
            containers:
              - name: "*"
                image: "123456789.dkr.ecr.us-east-1.amazonaws.com/* | \
                        gcr.io/my-project/* | \
                        myregistry.azurecr.io/*"

---
# Kyverno policy: prohibit images with :latest tag
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-latest-tag
spec:
  validationFailureAction: Enforce
  rules:
    - name: require-image-tag
      match:
        any:
          - resources:
              kinds: ["Pod"]
      validate:
        message: "Image tag 'latest' is not allowed. Use a specific version."
        pattern:
          spec:
            containers:
              - name: "*"
                image: "!*:latest"
            initContainers:
              - name: "*"
                image: "!*:latest"
```

---

### 2.6 Runtime Security with Falco

Falco is a CNCF-graduated runtime security tool that detects anomalous behaviour in running containers using kernel-level system call tracing (via eBPF or a kernel module). While image scanning catches known vulnerabilities before deployment, Falco catches exploitation attempts at runtime — when an attacker is already inside a container.

```
Falco detection model:

  Linux kernel → syscall events (open, execve, connect, clone, ...)
       │
       ▼
  Falco rules engine
       │
       ├── Rule: "shell spawned in container" → ALERT
       ├── Rule: "sensitive file read (/etc/shadow)" → ALERT
       ├── Rule: "container namespace escape attempt" → CRITICAL
       ├── Rule: "unexpected outbound connection" → WARNING
       └── Rule: "package manager run in container" → WARNING
       │
       ▼
  Falco outputs:
  ├── stdout (structured JSON)
  ├── syslog
  ├── HTTP webhook (→ SIEM, Slack, PagerDuty)
  └── gRPC API (→ Falcosidekick)
```

```bash
# Install Falco via Helm (eBPF mode — no kernel module required)
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update

helm install falco falcosecurity/falco \
  --namespace falco \
  --create-namespace \
  --set driver.kind=ebpf \
  --set collectors.kubernetes.enabled=true \
  --set falcosidekick.enabled=true \
  --set falcosidekick.webui.enabled=true \
  --set falco.grpc.enabled=true \
  --set falco.grpcOutput.enabled=true \
  --version 4.2.0

kubectl get pods -n falco
# NAME                       READY   STATUS    RESTARTS
# falco-abcde                1/1     Running   0       (DaemonSet — one per node)
# falco-falcosidekick-xyz    1/1     Running   0
```

#### Falco Rules — Production Ruleset

```yaml
# /etc/falco/falco_rules.local.yaml — custom rules (override defaults)

# Rule 1: Detect shell spawned inside a container
# (Attackers often spawn /bin/bash or /bin/sh after initial compromise)
- rule: Shell Spawned in Container
  desc: A shell was spawned in a container
  condition: >
    spawned_process and
    container and
    not container.image.repository in (known_shell_spawn_images) and
    proc.name in (shell_binaries)
  output: >
    Shell spawned in container
    (user=%user.name user_loginuid=%user.loginuid
     container_id=%container.id container_name=%container.name
     image=%container.image.repository:%container.image.tag
     shell=%proc.name parent=%proc.pname cmdline=%proc.cmdline)
  priority: WARNING
  tags: [container, shell, mitre_execution]

# Rule 2: Detect write to sensitive directories
- rule: Write to Sensitive Directory
  desc: An attempt to write to a sensitive path outside expected app dirs
  condition: >
    open_write and
    container and
    not proc.name in (allowed_writers) and
    fd.directory in (/etc, /usr/bin, /usr/sbin, /bin, /sbin, /boot, /lib)
  output: >
    Write to sensitive directory
    (user=%user.name command=%proc.cmdline
     file=%fd.name container=%container.name
     image=%container.image.repository)
  priority: ERROR
  tags: [filesystem, mitre_persistence]

# Rule 3: Detect unexpected outbound connections
- rule: Unexpected Outbound Connection
  desc: A container made an outbound connection to an unexpected destination
  condition: >
    outbound and
    container and
    not fd.sip in (allowed_external_ips) and
    not fd.sport in (80, 443, 5432, 6379, 9090) and
    container.name != "falco"
  output: >
    Unexpected outbound network connection
    (user=%user.name command=%proc.cmdline
     connection=%fd.name container=%container.name)
  priority: WARNING
  tags: [network, mitre_exfiltration]

# Rule 4: Detect privilege escalation (setuid binary run)
- rule: Setuid Binary Execution
  desc: A setuid binary was executed in a container
  condition: >
    spawned_process and
    container and
    proc.is_suid_exe=true
  output: >
    Setuid binary execution in container
    (user=%user.name binary=%proc.exepath
     container=%container.name image=%container.image.repository)
  priority: CRITICAL
  tags: [process, privilege_escalation, mitre_privilege_escalation]

# Rule 5: Detect package manager usage (attacker installing tools)
- rule: Package Manager in Container
  desc: A package manager was run inside a container at runtime
  condition: >
    spawned_process and
    container and
    proc.name in (package_mgmt_binaries)
  output: >
    Package manager run in container
    (user=%user.name command=%proc.cmdline
     container=%container.name image=%container.image.repository)
  priority: ERROR
  tags: [process, mitre_persistence]

# Macro: define allowed external IPs (customize per environment)
- macro: allowed_external_ips
  condition: >
    fd.sip in ("10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16",
               "203.0.113.100")   # Payment gateway
```

#### Falcosidekick — Alert Routing

```yaml
# falcosidekick-config.yaml — route Falco alerts to Slack and PagerDuty
apiVersion: v1
kind: ConfigMap
metadata:
  name: falcosidekick-config
  namespace: falco
data:
  config.yaml: |
    listenport: 2801
    debug: false

    slack:
      webhookurl: "https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXX"
      channel: "#security-alerts"
      username: "Falco"
      minimumpriority: "warning"
      messageformat: |
        :rotating_light: *Falco Alert*
        *Priority*: {{ .Priority }}
        *Rule*: {{ .Rule }}
        *Container*: {{ index .OutputFields "container.name" }}
        *Image*: {{ index .OutputFields "container.image.repository" }}
        *Command*: {{ index .OutputFields "proc.cmdline" }}

    pagerduty:
      routingkey: "PAGERDUTY_ROUTING_KEY"
      minimumpriority: "error"

    webhook:
      address: "http://my-siem.internal:8080/falco"
      minimumpriority: "warning"
      customHeaders:
        Authorization: "Bearer my-siem-token"
```

---

### 2.7 CIS Kubernetes Benchmark

The Center for Internet Security (CIS) Kubernetes Benchmark is a community-developed set of security configuration recommendations for Kubernetes clusters. It covers API server flags, etcd configuration, kubelet configuration, RBAC posture, and network policies.

#### kube-bench — Automated CIS Benchmark Assessment

```bash
# Install kube-bench
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml

# Wait for the job to complete
kubectl wait --for=condition=complete job/kube-bench --timeout=120s

# View results
kubectl logs job/kube-bench | head -100

# Output structure:
# [INFO] 1 Control Plane Security Configuration
# [INFO] 1.1 Control Plane Node Configuration Files
# [PASS] 1.1.1 Ensure that the API server pod specification file permissions are set to 600 or more restrictive (Automated)
# [PASS] 1.1.2 Ensure that the API server pod specification file ownership is set to root:root (Automated)
# [FAIL] 1.2.5 Ensure that the --kubelet-certificate-authority argument is set as appropriate (Automated)
# [FAIL] 1.2.9 Ensure that the admission control plugin EventRateLimit is set (Automated)
# [WARN] 1.2.14 Ensure that the admission control plugin ServiceAccount is set (Automated)
# [PASS] 1.2.20 Ensure that the --secure-port argument is not set to 0 (Automated)
#
# == Summary ==
# 43 checks PASS
#  8 checks FAIL
# 10 checks WARN
#  0 checks INFO
```

```bash
# Run kube-bench targeting specific sections
# Useful for focused remediation sprints

# Run on a control plane node directly (no cluster access needed)
kube-bench run --targets master \
  --benchmark cis-1.9 \
  --outputfile kube-bench-master.json \
  --json

# Run on a worker node
kube-bench run --targets node \
  --benchmark cis-1.9 \
  --outputfile kube-bench-node.json \
  --json

# Parse JSON results for FAIL items only
cat kube-bench-master.json | jq '
  .Controls[] |
  .tests[] |
  .results[] |
  select(.status=="FAIL") |
  {
    test_number: .test_number,
    description: .test_desc,
    remediation: .remediation
  }
'
```

#### High-Priority CIS Benchmark Remediations

```bash
# ── CIS 1.2.9: EventRateLimit admission plugin ────────────────────────
# Prevents API server DoS via excessive request rates
# Add to kube-apiserver manifest:
# --enable-admission-plugins=EventRateLimit
# --admission-control-config-file=/etc/kubernetes/admission-config.yaml

# /etc/kubernetes/admission-config.yaml:
cat > /etc/kubernetes/admission-config.yaml << 'EOF'
apiVersion: eventratelimit.admission.k8s.io/v1alpha1
kind: Configuration
limits:
  - type: Namespace
    qps: 50
    burst: 100
    cacheSize: 2000
  - type: User
    qps: 10
    burst: 50
EOF

# ── CIS 1.2.22: audit-log-path set ───────────────────────────────────
# Already covered in Chapter 8 kubeadm config — verify it's set:
ps aux | grep kube-apiserver | grep audit-log-path

# ── CIS 2.1: etcd TLS configuration ──────────────────────────────────
# Verify etcd is using TLS (should already be set by kubeadm):
ps aux | grep etcd | grep -E "cert-file|key-file|client-cert-auth"

# ── CIS 3.2: kubelet authentication not anonymous ─────────────────────
# /var/lib/kubelet/config.yaml should have:
grep "anonymous" /var/lib/kubelet/config.yaml
# authentication:
#   anonymous:
#     enabled: false     ← Must be false

# ── CIS 4.2.6: kubelet certificate rotation ───────────────────────────
grep "rotateCertificates" /var/lib/kubelet/config.yaml
# rotateCertificates: true   ← Must be true

# ── CIS 5.1.1: Cluster-admin not used unnecessarily ───────────────────
kubectl get clusterrolebindings -o json | jq -r '
  .items[] |
  select(.roleRef.name=="cluster-admin") |
  select(.metadata.name != "cluster-admin") |    # exclude the default binding
  .metadata.name
'
# Any output here should be reviewed and likely removed

# ── CIS 5.7.2: Seccomp profile applied to Pods ───────────────────────
# Check Pods without seccomp profiles
kubectl get pods -A -o json | jq '
  .items[] |
  select(
    .spec.securityContext.seccompProfile == null and
    (.spec.containers[] | .securityContext.seccompProfile == null)
  ) |
  "\(.metadata.namespace)/\(.metadata.name)"
'
```

---

## 3. Step-by-Step Hands-on Walkthrough

### 3.1 Build a Defence-in-Depth Security Posture

```bash
# ── Step 1: Label namespaces with Pod Security Standards ─────────────
kubectl label namespace production \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=v1.30 \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/warn=restricted

# ── Step 2: Apply default-deny NetworkPolicies ────────────────────────
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: production
spec:
  podSelector: {}
  policyTypes: [Egress]
  egress:
    - ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
EOF

# ── Step 3: Deploy a security-hardened workload ───────────────────────
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-api
  namespace: production
spec:
  replicas: 2
  selector:
    matchLabels:
      app: secure-api
  template:
    metadata:
      labels:
        app: secure-api
    spec:
      automountServiceAccountToken: false
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        fsGroup: 10001
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: api
          image: nginx:1.25-alpine
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: ["ALL"]
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 200m
              memory: 256Mi
          volumeMounts:
            - name: tmp
              mountPath: /tmp
            - name: cache
              mountPath: /var/cache/nginx
            - name: run
              mountPath: /var/run
      volumes:
        - name: tmp
          emptyDir: {}
        - name: cache
          emptyDir: {}
        - name: run
          emptyDir: {}
EOF

# ── Step 4: Verify PSA compliance ─────────────────────────────────────
kubectl get pods -n production
# secure-api-xxx   2/2   Running   ← Passes restricted profile

# Try deploying a non-compliant Pod (should be rejected)
kubectl run bad-pod \
  --image=nginx \
  --namespace=production \
  --overrides='{"spec":{"containers":[{"name":"nginx","image":"nginx","securityContext":{"runAsUser":0}}]}}' 2>&1
# Error from server (Forbidden): pods "bad-pod" is forbidden:
# violates PodSecurity "restricted:v1.30": ...
```

### 3.2 Install and Test Falco

```bash
# Install Falco (eBPF mode)
helm install falco falcosecurity/falco \
  --namespace falco \
  --create-namespace \
  --set driver.kind=ebpf \
  --set collectors.kubernetes.enabled=true

# Wait for DaemonSet
kubectl rollout status daemonset/falco -n falco

# Trigger a Falco alert: spawn a shell in a running container
kubectl exec -n production deploy/secure-api -- sh -c "echo test"
# (Even though the command succeeds, Falco detects and logs the shell spawn)

# Check Falco logs for the alert
kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=20 | \
  grep -i "shell\|exec"
# 09:15:32.123456789: Warning Shell spawned in container
# (user=root container_id=abc123 image=nginx:1.25-alpine shell=sh ...)

# Trigger a more serious alert: read /etc/shadow (sensitive file)
kubectl exec -n production deploy/secure-api -- cat /etc/shadow 2>/dev/null || true
kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=10
# 09:15:45.987654321: Error Read sensitive file
# (user=root command=cat /etc/shadow container=secure-api ...)
```

### 3.3 Run kube-bench and Remediate Findings

```bash
# Run kube-bench
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml
kubectl wait --for=condition=complete job/kube-bench --timeout=120s
kubectl logs job/kube-bench > kube-bench-results.txt

# Count results by status
grep -c "^\[PASS\]" kube-bench-results.txt
grep -c "^\[FAIL\]" kube-bench-results.txt
grep -c "^\[WARN\]" kube-bench-results.txt

# Extract all FAIL items with their remediation
grep -A 3 "^\[FAIL\]" kube-bench-results.txt

# Example remediation: CIS 5.2.2 — No privileged containers
# Finding: some Pods use privileged: true
# Remediation: Apply PSA 'restricted' profile (done in step 3.1)
# Verify:
kubectl get pods -A -o json | jq '
  [.items[] |
   select(.spec.containers[].securityContext.privileged == true) |
   "\(.metadata.namespace)/\(.metadata.name)"]
'

# Clean up kube-bench job
kubectl delete job kube-bench
```

---

## 4. Real-World Scenario: Financial Services Security Hardening

### The Problem

Meridian Bank's Kubernetes platform failed an external security audit with 23 critical findings. The key issues:

- 14 Deployments running containers as root (UID 0)
- 3 CI/CD ServiceAccounts with `cluster-admin` ClusterRoleBindings
- No NetworkPolicies — any Pod can reach any other Pod, including the etcd proxy
- Secrets stored in environment variables (visible in `kubectl describe pod`)
- No runtime threat detection — zero visibility into container behaviour post-deploy
- etcd not encrypted at rest — Secrets readable in plain base64 from etcd backup

### The Remediation Plan

**Week 1 — Foundation**

```bash
# Enable etcd encryption at rest (Section 2.4)
# Apply to kube-apiserver: --encryption-provider-config
# Force re-encrypt existing Secrets:
kubectl get secrets -A -o json | kubectl replace -f -

# Label all namespaces with PSA warn+audit (non-breaking first)
for ns in production staging development; do
  kubectl label namespace $ns \
    pod-security.kubernetes.io/warn=restricted \
    pod-security.kubernetes.io/audit=restricted
done
```

**Week 2 — RBAC Hardening**

```bash
# Identify and remove cluster-admin bindings for CI/CD SAs
kubectl get clusterrolebindings -o json | jq -r '
  .items[] |
  select(.subjects[]?.kind=="ServiceAccount") |
  select(.roleRef.name=="cluster-admin") |
  .metadata.name
' | while read binding; do
  echo "Removing cluster-admin binding: $binding"
  kubectl delete clusterrolebinding $binding
done

# Create scoped deploy roles per namespace (Chapter 8 RBAC patterns)
```

**Week 3 — Network Segmentation**

Apply default-deny NetworkPolicies to all namespaces, then add explicit allow rules for each service's required communication paths. This took 3 engineers 4 days to map all service dependencies.

**Week 4 — Secrets Migration**

```bash
# Migrate from env var Secrets to Vault Agent Injector
# Each Deployment is updated: remove secretKeyRef env vars,
# add vault.hashicorp.com/agent-inject annotations

# Validate no Secrets in env vars remain
kubectl get pods -A -o json | jq '
  .items[] |
  select(.spec.containers[].env[]?.valueFrom.secretKeyRef != null) |
  "\(.metadata.namespace)/\(.metadata.name): still using secretKeyRef env vars"
'
```

**Week 5 — Runtime Security + PSA Enforcement**

```bash
# Deploy Falco
# Promote PSA from warn/audit to enforce in production
kubectl label namespace production \
  pod-security.kubernetes.io/enforce=restricted \
  --overwrite

# Fix remaining non-compliant Pods (add securityContext to Deployments)
```

**Week 6 — CIS Benchmark Re-Assessment**

```bash
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml
kubectl logs job/kube-bench | grep -c "^\[FAIL\]"
# Before: 23 FAIL
# After:   4 FAIL (remaining items require kernel-level changes, scheduled for next quarter)
```

### Results

| Control | Before | After |
|---|---|---|
| Containers running as root | 14 Deployments | 0 |
| Cluster-admin SA bindings | 3 (CI/CD) | 0 |
| NetworkPolicy coverage | 0% namespaces | 100% namespaces |
| Secrets in environment vars | 47 Deployments | 0 (Vault) |
| etcd encryption at rest | Disabled | AES-GCM 256-bit |
| Runtime threat detection | None | Falco (7 nodes) |
| CIS Benchmark FAIL items | 23 | 4 |
| Audit finding status | Critical: 23 | Critical: 0, Medium: 4 |

---

## 5. Common Pitfalls & Best Practices

### Pitfall 1: Starting PSA Enforcement Without Auditing First
Immediately labelling a namespace with `enforce: restricted` without first using `warn` and `audit` modes breaks running workloads instantly. The correct migration path is always: add `warn` first (developers see warnings in kubectl output), then `audit` (violations appear in API server audit log), then `enforce` only after all violations are resolved. This migration can take days to weeks for large codebases.

### Pitfall 2: NetworkPolicy `podSelector: {}` Applies to ALL Pods
A common NetworkPolicy mistake is writing a policy intended for one Pod but accidentally applying it cluster-wide. `podSelector: {}` (empty selector) matches ALL Pods in the namespace — it is not a wildcard that means "no Pods". When writing the default-deny policy, this is intentional. When writing a service-specific policy, always specify explicit `matchLabels`.

### Pitfall 3: Sealing Key Loss = Permanent Secret Loss
Sealed Secrets encrypts secrets with an asymmetric key generated by the controller. If the Sealed Secrets controller is deleted and recreated without restoring the sealing key, all existing `SealedSecret` resources become permanently undecryptable — they cannot be rotated or replaced without knowing the plaintext values. **Backup the sealing key to an external vault immediately after installation and before every key rotation.**

### Pitfall 4: Falco Generating Excessive Alert Noise
A default Falco installation generates hundreds of alerts per hour from legitimate cluster operations — kubeadm running shells, CNI plugins writing files, metrics collection tools reading `/proc`. Teams that do not tune Falco before production receive so many alerts that they start ignoring them entirely. **Start with only high-priority rules enabled. Tune macros like `known_shell_spawn_images` and `allowed_writers` before enabling lower-priority rules.**

### Pitfall 5: Image Scanning in CI but Not at Runtime
Teams scan images before push but then run those images for months while new CVEs are published against their dependencies. A clean image in January may have 10 CRITICAL CVEs by March due to newly discovered vulnerabilities in libraries. **Use Trivy Operator or a registry scanning service to continuously scan running workloads, not just images at build time.**

### Pitfall 6: `cluster-admin` for Monitoring and Logging Tools
Prometheus, Fluentd, and other observability tools request `cluster-admin` in their default Helm chart values because it is the easiest way to make their examples work. In production, they need specific, limited read access to metrics endpoints and logs — not the ability to delete namespaces. **Always review and reduce the RBAC permissions of third-party Helm charts before installing into production.**

> **Security Production Readiness Checklist**
> - [ ] All production namespaces labelled with `pod-security.kubernetes.io/enforce: restricted`
> - [ ] Default-deny NetworkPolicies applied to all namespaces, with explicit allow rules
> - [ ] etcd encryption at rest enabled (EncryptionConfiguration with AES-GCM)
> - [ ] No ServiceAccounts with `cluster-admin` except approved system components
> - [ ] Secrets managed via Sealed Secrets, ESO, or Vault — not hardcoded env vars
> - [ ] Trivy or Snyk integrated as a blocking CI gate on CRITICAL/HIGH CVEs
> - [ ] Trivy Operator or equivalent scanning running workloads continuously
> - [ ] Falco deployed in eBPF mode with tuned rules and alert routing configured
> - [ ] kube-bench CIS Benchmark run quarterly; FAIL items tracked as security debt
> - [ ] API server audit logging enabled and shipped to a SIEM or log aggregator
> - [ ] Image registry allowlist enforced via Kyverno or OPA/Gatekeeper
> - [ ] `latest` image tag forbidden via admission policy
> - [ ] All containers drop ALL capabilities; add back only what is strictly required
> - [ ] `readOnlyRootFilesystem: true` on all containers; writable dirs use emptyDir volumes

---

## 6. Key Takeaways

1. **The 4Cs framework — Cloud, Cluster, Container, Code — organises security controls so that no single layer failure is catastrophic.** An attacker who exploits a code vulnerability still faces container isolation. A container breakout still faces cluster RBAC and NetworkPolicies. A cluster compromise still faces cloud IAM and audit logging. Defence in depth is not redundancy — it is resilience.

2. **Pod Security Admission is your first line of container isolation enforcement.** The `restricted` profile — non-root, read-only filesystem, ALL capabilities dropped, RuntimeDefault seccomp — eliminates an entire class of container breakout techniques. Migrate namespaces using the warn → audit → enforce progression to avoid breaking running workloads.

3. **NetworkPolicies must start with default-deny.** Without a default-deny policy, a compromised Pod can reach every other Pod in the cluster — including the etcd proxy, the Kubernetes API server, and database StatefulSets. Default-deny plus explicit allow rules implements zero-trust networking at the Kubernetes layer.

4. **Secrets management is a spectrum, and the right choice depends on your threat model.** Kubernetes Secrets with etcd encryption at rest are acceptable for low-sensitivity data. Sealed Secrets is the right choice for GitOps workflows that need secrets in Git. External Secrets Operator integrates naturally with cloud-native secret stores. HashiCorp Vault provides the highest security with dynamic secrets, full audit trail, and automatic rotation.

5. **Falco provides detection where prevention is impossible.** No matter how hardened your container images and cluster configuration are, a zero-day vulnerability or a misconfigured container can still be exploited. Falco's kernel-level syscall monitoring detects the *behaviour* of an attack — shell spawning, file writes, unexpected network connections — regardless of the specific vulnerability used.

6. **The CIS Kubernetes Benchmark is a structured, prioritised security checklist.** Running `kube-bench` quarterly and tracking FAIL items as security debt gives you an objective, auditable measure of your cluster's security posture. Most critical CIS findings can be addressed at cluster creation time by using the correct `kubeadm` configuration — the cost of fixing them post-creation is 10-100x higher.

---

## 7. Exercises & Labs

**Exercise 1: PSA Migration Simulation**
Create a namespace with 5 Deployments, some compliant with the `restricted` profile and some not (running as root, writable filesystem, missing seccomp). Apply `warn` mode first and observe the kubectl warnings. Apply `audit` mode and check the API server audit log for violations. Fix each violation in the non-compliant Deployments. Finally apply `enforce` mode and verify all Pods start successfully. Document every violation you encountered and how you resolved it.

**Exercise 2: NetworkPolicy Zero-Trust Build-Out**
Deploy a three-tier application: frontend, API, and database. Apply default-deny-all to the namespace. Add only the NetworkPolicies required for the application to function: frontend → API on port 8080, API → database on port 5432, monitoring namespace → all Pods on port 9090, and DNS egress. Use `kubectl exec` to verify that: (a) frontend can reach API, (b) frontend cannot reach database directly, (c) API can reach database, (d) database cannot initiate any outbound connections.

**Exercise 3: Sealed Secrets GitOps Workflow**
Install Sealed Secrets. Create a Secret with a database password. Seal it with `kubeseal`. Commit the SealedSecret to a Git repository. Apply it to the cluster and verify the real Secret is created. Then simulate key loss: delete the Sealed Secrets controller and recreate it (new key generated). Try to apply the old SealedSecret and observe the decryption failure. Restore the original sealing key from backup and verify it decrypts successfully again.

**Exercise 4: Falco Threat Detection Lab**
Install Falco on your cluster. Trigger each of the following scenarios and verify Falco generates an alert in its logs: (a) spawn a shell inside a running container (`kubectl exec -- sh`), (b) read `/etc/shadow` from inside a container, (c) run `apt-get` or `apk add` inside a container, (d) write to `/etc` from inside a container. For each alert, document the exact Falco rule that triggered, the priority level, and the fields captured in the output.

**Exercise 5: CIS Benchmark Remediation Sprint**
Run `kube-bench` on your cluster. Export all FAIL items. Select the five highest-priority FAIL items. For each: research the remediation in the CIS Benchmark documentation, apply the fix (modifying kube-apiserver flags, kubelet config, or RBAC), re-run kube-bench to verify the item now shows PASS, and document the exact change made and its security impact. Track the before/after FAIL count.

---

*End of Chapter 9*

**Next → Chapter 10: Monitoring in Kubernetes**



---

──────────────────────────────────────────────────────────────────────

## Part X: Monitoring in Kubernetes

> *Prometheus · Grafana · Loki · Tempo · Alertmanager · SLOs*

──────────────────────────────────────────────────────────────────────


## 1. Introduction & Learning Objectives

Observability is the property of a system that allows you to understand its internal state from its external outputs. In Kubernetes — where hundreds of ephemeral containers across dozens of nodes are continuously creating, failing, and rescheduling — observability is not a luxury. It is the operational foundation that separates teams that can diagnose a production incident in minutes from teams that spend hours guessing at root causes.

The modern Kubernetes observability stack has three pillars: **metrics** (what is happening numerically over time), **logs** (what events occurred and why), and **traces** (how a single request flowed through the system). Each pillar answers different questions, and all three are required for complete production visibility.

This chapter builds a production-grade, fully integrated observability stack from scratch using the **kube-prometheus-stack** (Prometheus Operator, Grafana, Alertmanager, kube-state-metrics, node-exporter), **Loki** for log aggregation, **Tempo** for distributed tracing, and the **OpenTelemetry Collector** as the unified telemetry pipeline. We then build SLO/SLA dashboards that connect technical metrics to business reliability commitments.

> **Learning Objectives**
> - Understand the three pillars of observability — metrics, logs, and traces — and when each is the right tool.
> - Deploy and configure the kube-prometheus-stack using the Prometheus Operator pattern.
> - Write PromQL queries for cluster health, workload performance, and saturation metrics.
> - Configure `ServiceMonitor` and `PodMonitor` resources for automatic Prometheus scrape discovery.
> - Write `PrometheusRule` resources for alerting rules and recording rules.
> - Configure Alertmanager with routing trees, inhibition rules, and multi-channel notification.
> - Deploy Loki with Promtail for log collection and write LogQL queries for production debugging.
> - Deploy Grafana Tempo for distributed tracing and configure OpenTelemetry instrumentation.
> - Build SLO dashboards using error budget burn rate alerts and multi-window alerting.
> - Construct a production-grade Grafana dashboard for a microservices application.

---

## 2. Core Concepts

### 2.1 The Three Pillars of Observability

The three pillars model was established by Cindy Sridharan's influential 2017 work and has become the standard mental model for production observability.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    The Three Pillars of Observability                    │
│                                                                          │
│  METRICS              LOGS                   TRACES                      │
│  ─────────────────    ─────────────────       ─────────────────          │
│                                                                          │
│  Numerical time       Discrete timestamped    End-to-end request        │
│  series data          event records           execution paths            │
│                                                                          │
│  "What is the         "What happened          "Why did this             │
│   request rate?"       and when?"              request take 4s?"        │
│                                                                          │
│  Tool: Prometheus     Tool: Loki              Tool: Tempo/Jaeger        │
│                                                                          │
│  Cardinality:         Volume:                  Sampling:                │
│  Low (labels)         High (all events)        High overhead            │
│  Fast queries         Slow full-text           (head sampling           │
│  Aggregatable         search                    or tail sampling)       │
│                                                                          │
│  Best for:            Best for:               Best for:                 │
│  Alerting, trends,    Debugging specific      Request debugging,        │
│  capacity planning    error messages,          latency analysis,        │
│  SLO tracking         audit trails            dependency mapping        │
└─────────────────────────────────────────────────────────────────────────┘
```

#### The Four Golden Signals (Google SRE)

The four golden signals define the minimum viable metrics for any production service:

| Signal | What It Measures | Example PromQL |
|---|---|---|
| **Latency** | Time to serve a request (distinguish success vs error latency) | `histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))` |
| **Traffic** | Demand on the system (requests per second) | `sum(rate(http_requests_total[5m]))` |
| **Errors** | Rate of failed requests | `rate(http_requests_total{status=~"5.."}[5m])` |
| **Saturation** | How full the service is (CPU, memory, queue depth) | `container_memory_working_set_bytes / container_spec_memory_limit_bytes` |

#### USE Method (Brendan Gregg) — For Infrastructure

| Component | Utilisation | Saturation | Errors |
|---|---|---|---|
| CPU | `rate(cpu_usage[5m])` | Run queue length | Throttled CPU |
| Memory | `working_set / limit` | OOM kills | Page faults |
| Disk | IOPS / max IOPS | I/O queue depth | Disk errors |
| Network | Bytes/s / capacity | Drop rate | TCP retransmits |

---

### 2.2 Prometheus Architecture

Prometheus uses a pull model — it scrapes HTTP endpoints (`/metrics`) on a configured schedule, rather than waiting for metrics to be pushed to it. This design makes the scrape configuration the source of truth for what is monitored.

```
┌──────────────────────────────────────────────────────────────────────┐
│  Prometheus Server                                                    │
│                                                                       │
│  ┌────────────────────┐   ┌─────────────────────────────────────┐   │
│  │  Service Discovery  │   │  Storage (TSDB)                     │   │
│  │  ├── Kubernetes API │   │  Local: 15-day retention default    │   │
│  │  ├── ServiceMonitor │   │  Remote write → Thanos/Cortex/Mimir │   │
│  │  └── PodMonitor     │   │  for long-term storage              │   │
│  └────────┬────────────┘   └─────────────────────────────────────┘   │
│           │                                                            │
│  ┌────────▼────────────────────────────────────────────────────────┐ │
│  │  Scrape Engine (pull model)                                      │ │
│  │  GET /metrics every 15-30s from discovered targets              │ │
│  └────────┬────────────────────────────────────────────────────────┘ │
│           │                                                            │
│  ┌────────▼────────┐   ┌──────────────────────────────────────────┐ │
│  │  Rule Evaluation│   │  Alertmanager                            │ │
│  │  Recording rules│──▶│  Route → deduplicate → inhibit → silence │ │
│  │  Alerting rules │   │  Notify → Slack/PagerDuty/Email/webhook  │ │
│  └─────────────────┘   └──────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────┘
        ▲              ▲              ▲              ▲
        │              │              │              │
  node-exporter   kube-state-    Application    cAdvisor
  (host metrics)  metrics        /metrics       (container
                  (K8s object    endpoint       metrics)
                  state)
```

#### Prometheus Operator Pattern

The Prometheus Operator (part of kube-prometheus-stack) extends Kubernetes with custom resources that manage Prometheus configuration declaratively:

| CRD | Purpose |
|---|---|
| `Prometheus` | Deploys and configures a Prometheus instance |
| `Alertmanager` | Deploys and configures an Alertmanager instance |
| `ServiceMonitor` | Tells Prometheus which Services to scrape |
| `PodMonitor` | Tells Prometheus which Pods to scrape (without a Service) |
| `PrometheusRule` | Defines alerting and recording rules |
| `AlertmanagerConfig` | Defines per-namespace alerting routes and receivers |
| `ThanosRuler` | Manages Thanos Ruler for long-term rule evaluation |

---

### 2.3 Key Metric Sources

#### kube-state-metrics

kube-state-metrics (KSM) watches the Kubernetes API and exports metrics about the state of Kubernetes objects — not resource usage, but object state: number of replicas, Pod phase, Deployment conditions, resource requests and limits.

```
kube-state-metrics exposes:
  kube_deployment_status_replicas_available     → How many replicas are ready
  kube_pod_status_phase                         → Pod phase (Running/Pending/Failed)
  kube_pod_container_status_restarts_total      → Restart counts
  kube_node_status_condition                    → Node Ready/DiskPressure/MemoryPressure
  kube_resourcequota                            → Quota usage vs limits
  kube_horizontalpodautoscaler_status_*         → HPA current vs desired replicas
  kube_persistentvolumeclaim_status_phase       → PVC Bound/Pending/Lost
```

#### node-exporter

node-exporter runs as a DaemonSet and exposes host-level metrics from every node: CPU, memory, disk I/O, network, filesystem usage, system load.

```
node-exporter key metrics:
  node_cpu_seconds_total                        → CPU time per mode (idle/user/sys/iowait)
  node_memory_MemAvailable_bytes                → Available memory
  node_filesystem_avail_bytes                   → Free disk per mount
  node_disk_io_time_seconds_total               → Disk I/O saturation
  node_network_receive_bytes_total              → Network throughput
  node_load1 / node_load5 / node_load15         → System load averages
```

#### cAdvisor (Container Advisor)

cAdvisor is embedded in the kubelet and exposes per-container resource usage metrics:

```
container_cpu_usage_seconds_total               → Container CPU usage
container_memory_working_set_bytes              → Container memory (non-evictable)
container_network_receive_bytes_total           → Container network I/O
container_fs_usage_bytes                        → Container ephemeral storage
```

---

### 2.4 PromQL — Prometheus Query Language

PromQL is the query language for Prometheus. Understanding its data model and key functions is essential for writing useful alerts and dashboards.

#### PromQL Data Types

```
Instant vector:    A set of time series, each with a single sample at a given time
                   http_requests_total{job="order-api"}
                   → {job="order-api",status="200"} 47291
                   → {job="order-api",status="500"} 123

Range vector:      A set of time series, each with a range of samples
                   http_requests_total[5m]
                   → last 5 minutes of samples per time series

Scalar:            A single numeric value
                   42

String:            A string value (rarely used)
```

#### Essential PromQL Functions

```promql
# rate() — per-second average rate of increase over a range
# Use for counters (always-increasing values like request counts)
rate(http_requests_total[5m])

# irate() — per-second instant rate (last two samples)
# More responsive to spikes; noisier than rate()
irate(http_requests_total[2m])

# increase() — total increase over a range
increase(http_requests_total[1h])

# sum() — aggregate across label dimensions
sum(rate(http_requests_total[5m])) by (service)

# histogram_quantile() — calculate percentiles from histograms
# P99 latency:
histogram_quantile(0.99,
  sum(rate(http_request_duration_seconds_bucket[5m])) by (le, service)
)

# topk() — top N time series by value
topk(5, sum(rate(http_requests_total[5m])) by (pod))

# absent() — true when no time series match (for "missing metric" alerts)
absent(up{job="order-api"})

# predict_linear() — predict future value (for capacity planning)
predict_linear(node_filesystem_avail_bytes[6h], 4 * 3600)
# "Will this disk run out in the next 4 hours?"

# changes() — number of times a value changed
changes(kube_pod_container_status_restarts_total[30m]) > 3
```

#### Production PromQL Queries

```promql
# ── Request rate (RPS) per service ────────────────────────────────────
sum(rate(http_requests_total[5m])) by (service)

# ── Error rate (%) per service ─────────────────────────────────────────
100 * sum(rate(http_requests_total{status=~"5.."}[5m])) by (service) /
      sum(rate(http_requests_total[5m])) by (service)

# ── P99 request latency per service ───────────────────────────────────
histogram_quantile(0.99,
  sum(rate(http_request_duration_seconds_bucket[5m])) by (le, service)
)

# ── Pod CPU utilisation (% of request) ────────────────────────────────
100 * sum(rate(container_cpu_usage_seconds_total{container!=""}[5m])) by (pod, namespace) /
      sum(kube_pod_container_resource_requests{resource="cpu"}) by (pod, namespace)

# ── Pod memory utilisation (% of limit) ───────────────────────────────
100 * sum(container_memory_working_set_bytes{container!=""}) by (pod, namespace) /
      sum(kube_pod_container_resource_limits{resource="memory"}) by (pod, namespace)

# ── Node disk will fill in < 4 hours ──────────────────────────────────
(predict_linear(node_filesystem_avail_bytes{fstype!~"tmpfs|fuse.lxcfs"}[1h], 4 * 3600) < 0)
and
(node_filesystem_avail_bytes / node_filesystem_size_bytes < 0.15)

# ── Deployment rollout progress ───────────────────────────────────────
kube_deployment_status_replicas_updated /
kube_deployment_spec_replicas

# ── PVC usage above 85% ───────────────────────────────────────────────
(
  kubelet_volume_stats_used_bytes /
  kubelet_volume_stats_capacity_bytes
) > 0.85

# ── kube-state-metrics: Pods not running ──────────────────────────────
count by (namespace, pod) (
  kube_pod_status_phase{phase=~"Pending|Unknown|Failed"}
) > 0

# ── HPA at maximum replicas (potential scalability ceiling) ───────────
kube_horizontalpodautoscaler_status_current_replicas ==
kube_horizontalpodautoscaler_spec_max_replicas
```

---

### 2.5 Alertmanager — Alert Routing and Notification

Alertmanager receives alerts from Prometheus and handles deduplication, grouping, silencing, inhibition, and routing to the correct notification channel.

```
Prometheus fires alert
    │
    ▼
Alertmanager
    │
    ├── 1. Deduplication: same alert from multiple Prometheus → sent once
    │
    ├── 2. Grouping: alerts with same labels → single notification
    │       group_by: [alertname, namespace, severity]
    │       group_wait: 30s (wait for more alerts before first notification)
    │       group_interval: 5m (wait before re-notifying about a group)
    │       repeat_interval: 4h (re-notify about ongoing alerts)
    │
    ├── 3. Inhibition: suppress lower-priority alerts when higher-priority fires
    │       "If cluster is down, don't alert about individual Pods down"
    │
    ├── 4. Silencing: time-bounded suppression of matching alerts
    │       "Silence all alerts during Saturday maintenance window"
    │
    └── 5. Routing: match alerts to receivers by label
            severity=critical → PagerDuty (24/7 on-call)
            severity=warning  → Slack #alerts-warning
            team=payments     → Slack #payments-oncall
            environment=dev   → /dev/null (suppress dev alerts)
```

---

### 2.6 Loki Architecture

Grafana Loki is a horizontally scalable log aggregation system designed to be cost-efficient by indexing only metadata labels (not full log content). It stores compressed log chunks in object storage (S3, GCS, Azure Blob).

```
┌──────────────────────────────────────────────────────────────────────┐
│  Log Collection                                                       │
│                                                                       │
│  Promtail (DaemonSet)  ─────▶  Loki Distributor                     │
│  (tails /var/log/containers)          │                              │
│                                       ▼                              │
│  OpenTelemetry Collector ──▶  Loki Ingester (in-memory buffer)      │
│                                       │                              │
│  Fluentd / Fluent Bit ──────▶         ▼                              │
│                              Object Storage (S3/GCS/ABS)             │
│                              Compressed chunks + index               │
│                                       │                              │
│                              Loki Querier ◄── LogQL query            │
│                              Loki Query Frontend (cache + split)     │
│                                       │                              │
│                              Grafana Explore / Dashboard             │
└──────────────────────────────────────────────────────────────────────┘
```

#### LogQL — Loki Query Language

```logql
# ── Basic log stream selector ─────────────────────────────────────────
# Select logs by label (the only indexed fields)
{namespace="production", app="order-api"}

# ── Filter by content ─────────────────────────────────────────────────
{namespace="production", app="order-api"} |= "error"          # Contains
{namespace="production", app="order-api"} != "health"          # Not contains
{namespace="production"} |~ "(?i)(error|exception|panic)"      # Regex match

# ── Parse structured logs (JSON) ──────────────────────────────────────
{namespace="production"} | json
  | level="error"
  | line_format "{{.timestamp}} {{.service}}: {{.message}}"

# ── Parse key=value logs ───────────────────────────────────────────────
{app="order-api"} | logfmt
  | status >= 500
  | latency_ms > 1000

# ── Metric queries: rate of log lines ─────────────────────────────────
# Error rate per service (log volume per second)
sum(rate({namespace="production"} |= "level=error" [5m])) by (app)

# Count of 5xx errors per minute
sum(count_over_time(
  {namespace="production", app="order-api"} |= "\"status\":5" [1m]
)) by (pod)

# P99 latency from structured logs (requires json parser)
quantile_over_time(0.99,
  {namespace="production", app="order-api"}
  | json
  | unwrap latency_ms [5m]
) by (pod)
```

---

### 2.7 Distributed Tracing with Tempo

**Grafana Tempo** is a high-scale distributed tracing backend compatible with the OpenTelemetry protocol, Jaeger, and Zipkin. Like Loki, it stores traces in object storage rather than a traditional time-series database, making it extremely cost-efficient at scale.

```
Application (instrumented with OpenTelemetry SDK)
    │
    │  Traces (OTLP gRPC/HTTP)
    ▼
OpenTelemetry Collector (DaemonSet or Deployment)
    │
    ├── Metrics → Prometheus
    ├── Logs    → Loki
    └── Traces  → Tempo
                    │
                    ├── Distributor (receives traces)
                    ├── Ingester (buffers in memory)
                    └── Object Storage (S3/GCS/ABS)
                              │
                    Querier (serves TraceQL queries)
                              │
                    Grafana (visualise traces, correlate with metrics and logs)
```

#### TraceQL — Tempo's Query Language

```
# Find all traces with errors in the order-api service
{resource.service.name="order-api" && status=error}

# Find traces slower than 2 seconds
{resource.service.name="order-api" && duration > 2s}

# Find traces with a specific HTTP status
{span.http.status_code=500}

# Find traces spanning multiple services (distributed)
{resource.service.name=~"order.*|payment.*"} >> {status=error}

# Find traces where the payment span was slow
{resource.service.name="payment-api" && span.name="ProcessPayment" && duration > 500ms}
```

---

### 2.8 SLOs and Error Budgets

A **Service Level Objective (SLO)** is a target value for a service level indicator (SLI) measured over a time window. The gap between 100% and the SLO target is the **error budget** — the allowed margin for unreliability.

```
SLI: The metric being measured
     Example: "ratio of successful HTTP requests to total requests"

SLO: The target value for the SLI over a time window
     Example: "99.9% of requests succeed over a rolling 30-day window"

Error budget: 100% - SLO target
     Example: 100% - 99.9% = 0.1% = 43.2 minutes of allowed downtime per 30 days

Error budget burn rate: How fast the error budget is being consumed
     1x = consuming exactly as fast as the budget allows
     2x = consuming twice as fast; will exhaust budget in 15 days
     14.4x = will exhaust the entire monthly budget in 2 hours (critical alert)
```

#### Multi-Window, Multi-Burn-Rate Alerting

The Google SRE book recommends a four-alert pattern for SLO alerting that catches both fast-burning (high-severity, short-window) and slow-burning (low-severity, long-window) issues:

```
Alert 1 (Page immediately):
  Burn rate > 14.4x for 1 hour  AND  Burn rate > 14.4x for 5 minutes
  → Will exhaust 30-day budget in 2 hours
  → Severity: critical → PagerDuty

Alert 2 (Page soon):
  Burn rate > 6x for 6 hours   AND  Burn rate > 6x for 30 minutes
  → Will exhaust 30-day budget in 5 days
  → Severity: critical → PagerDuty

Alert 3 (Ticket):
  Burn rate > 3x for 3 days    AND  Burn rate > 3x for 6 hours
  → Will exhaust 30-day budget in 10 days
  → Severity: warning → Slack

Alert 4 (Trend):
  Burn rate > 1x for 30 days
  → Consuming budget faster than it replenishes
  → Severity: info → Weekly review
```

---

## 3. Full Stack Deployment

### 3.1 kube-prometheus-stack Installation

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Create monitoring namespace
kubectl create namespace monitoring
kubectl label namespace monitoring \
  pod-security.kubernetes.io/enforce=baseline

# Install kube-prometheus-stack
# This installs: Prometheus Operator, Prometheus, Alertmanager,
#                Grafana, kube-state-metrics, node-exporter, blackbox-exporter
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --version 60.3.0 \
  --values - <<'EOF'
# ── Prometheus configuration ─────────────────────────────────────────
prometheus:
  prometheusSpec:
    # Retention and storage
    retention: 30d
    retentionSize: 50GB
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: gp3
          accessModes: [ReadWriteOnce]
          resources:
            requests:
              storage: 50Gi

    # Resource limits
    resources:
      requests:
        cpu: 500m
        memory: 2Gi
      limits:
        cpu: 2
        memory: 8Gi

    # Replicas for HA (with Thanos for deduplication)
    replicas: 2

    # Allow Prometheus to pick up ServiceMonitors from all namespaces
    serviceMonitorSelectorNilUsesHelmValues: false
    podMonitorSelectorNilUsesHelmValues: false
    ruleSelectorNilUsesHelmValues: false
    probeSelectorNilUsesHelmValues: false

    # Scrape interval
    scrapeInterval: 30s
    evaluationInterval: 30s

    # External labels (for federation and remote write)
    externalLabels:
      cluster: production-eks
      region: us-east-1

    # Remote write to long-term storage (Thanos/Mimir/Cortex)
    remoteWrite:
      - url: http://thanos-receive:19291/api/v1/receive

    # Additional scrape configs for targets not using ServiceMonitors
    additionalScrapeConfigs:
      - job_name: blackbox-http
        metrics_path: /probe
        params:
          module: [http_2xx]
        static_configs:
          - targets:
              - https://api.mycompany.com/health
              - https://api.mycompany.com/api/v1/orders
        relabel_configs:
          - source_labels: [__address__]
            target_label: __param_target
          - source_labels: [__param_target]
            target_label: instance
          - target_label: __address__
            replacement: blackbox-exporter:9115

# ── Alertmanager configuration ────────────────────────────────────────
alertmanager:
  alertmanagerSpec:
    replicas: 3                      # HA cluster
    storage:
      volumeClaimTemplate:
        spec:
          storageClassName: gp3
          resources:
            requests:
              storage: 10Gi
    resources:
      requests:
        cpu: 100m
        memory: 256Mi
      limits:
        cpu: 500m
        memory: 512Mi

# ── Grafana configuration ─────────────────────────────────────────────
grafana:
  enabled: true
  replicas: 2
  persistence:
    enabled: true
    storageClassName: gp3
    size: 10Gi

  # Default dashboards from kube-prometheus-stack
  defaultDashboardsEnabled: true
  defaultDashboardsTimezone: UTC

  # Admin credentials (use a Secret in production)
  adminPassword: "change-me-in-production"

  resources:
    requests:
      cpu: 250m
      memory: 512Mi
    limits:
      cpu: 1
      memory: 1Gi

  # Datasources (auto-provisioned)
  additionalDataSources:
    - name: Loki
      type: loki
      url: http://loki-gateway.monitoring:80
      access: proxy
      jsonData:
        derivedFields:
          - name: TraceID
            matcherRegex: '"trace_id":"(\w+)"'
            url: '$${__value.raw}'
            datasourceUid: tempo
    - name: Tempo
      type: tempo
      url: http://tempo.monitoring:3100
      access: proxy
      jsonData:
        tracesToLogsV2:
          datasourceUid: loki
          filterByTraceID: true
          filterBySpanID: false
        tracesToMetrics:
          datasourceUid: prometheus
        serviceMap:
          datasourceUid: prometheus
        nodeGraph:
          enabled: true

# ── kube-state-metrics ────────────────────────────────────────────────
kube-state-metrics:
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 250m
      memory: 256Mi
  extraArgs:
    - --metric-labels-allowlist=pods=[*],deployments=[app,team,env]

# ── node-exporter ─────────────────────────────────────────────────────
prometheus-node-exporter:
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 250m
      memory: 128Mi
  hostRootFsMount:
    enabled: true
    mountPropagation: HostToContainer
EOF

# Verify all components are running
kubectl get pods -n monitoring
kubectl get servicemonitors -n monitoring
```

### 3.2 ServiceMonitor and PodMonitor Configuration

```yaml
# ServiceMonitor for the order-api service
# Prometheus Operator uses this to configure Prometheus scraping
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: order-api-monitor
  namespace: production
  labels:
    # This label must match Prometheus' serviceMonitorSelector
    release: kube-prometheus-stack
spec:
  selector:
    matchLabels:
      app: order-api              # Matches the Service with this label
  endpoints:
    - port: metrics               # Named port on the Service
      path: /metrics
      interval: 30s
      scrapeTimeout: 10s
      # Relabelling: add a cluster label to all metrics from this service
      relabelings:
        - sourceLabels: [__meta_kubernetes_namespace]
          targetLabel: namespace
        - sourceLabels: [__meta_kubernetes_pod_name]
          targetLabel: pod
      # Metric relabelling: drop high-cardinality metrics
      metricRelabelings:
        - sourceLabels: [__name__]
          regex: go_.*                  # Drop Go runtime internal metrics
          action: drop
  namespaceSelector:
    matchNames:
      - production
      - staging

---
# PodMonitor for workloads without a Service (e.g. batch Jobs, Spark executors)
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: order-worker-monitor
  namespace: production
  labels:
    release: kube-prometheus-stack
spec:
  selector:
    matchLabels:
      app: order-worker
  podMetricsEndpoints:
    - port: metrics
      path: /metrics
      interval: 60s
  namespaceSelector:
    matchNames:
      - production
```

### 3.3 PrometheusRules — Alerting and Recording Rules

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: order-api-rules
  namespace: production
  labels:
    release: kube-prometheus-stack
spec:
  groups:
    # ── Recording rules (pre-compute expensive queries) ──────────────
    - name: order-api.recording
      interval: 30s
      rules:
        # Pre-compute request rate (used in multiple dashboards and alerts)
        - record: job:http_requests:rate5m
          expr: |
            sum(rate(http_requests_total[5m])) by (job, namespace, status)

        # Pre-compute error ratio
        - record: job:http_error_ratio:rate5m
          expr: |
            sum(rate(http_requests_total{status=~"5.."}[5m])) by (job, namespace) /
            sum(rate(http_requests_total[5m])) by (job, namespace)

        # Pre-compute P99 latency
        - record: job:http_request_duration_p99:rate5m
          expr: |
            histogram_quantile(0.99,
              sum(rate(http_request_duration_seconds_bucket[5m]))
              by (le, job, namespace)
            )

    # ── Infrastructure alerting rules ─────────────────────────────────
    - name: kubernetes.pods
      rules:
        - alert: PodCrashLooping
          expr: |
            rate(kube_pod_container_status_restarts_total[15m]) * 60 * 5 > 0
          for: 15m
          labels:
            severity: warning
            team: platform
          annotations:
            summary: "Pod {{ $labels.namespace }}/{{ $labels.pod }} is crash looping"
            description: >
              Pod {{ $labels.pod }} in namespace {{ $labels.namespace }}
              has restarted {{ $value | humanize }} times in the last 15 minutes.
            runbook: "https://wiki.internal/runbooks/pod-crash-loop"

        - alert: PodNotReady
          expr: |
            sum by (namespace, pod) (
              max by (namespace, pod) (
                kube_pod_status_phase{phase=~"Pending|Unknown|Failed"}
              ) * on(namespace, pod) group_left(owner_kind) topk by (namespace, pod) (
                1, max by (namespace, pod, owner_kind) (kube_pod_owner{owner_kind!="Job"})
              )
            ) > 0
          for: 15m
          labels:
            severity: warning
          annotations:
            summary: "Pod {{ $labels.namespace }}/{{ $labels.pod }} has been non-ready for 15 minutes"

        - alert: PodOOMKilled
          expr: |
            kube_pod_container_status_last_terminated_reason{reason="OOMKilled"} == 1
          for: 0m
          labels:
            severity: warning
            team: "{{ $labels.label_team }}"
          annotations:
            summary: "Container {{ $labels.container }} in pod {{ $labels.pod }} was OOM killed"
            description: >
              Increase the memory limit for this container or investigate
              memory leaks in the application.

    - name: kubernetes.deployment
      rules:
        - alert: DeploymentReplicasMismatch
          expr: |
            (
              kube_deployment_spec_replicas !=
              kube_deployment_status_replicas_available
            ) and (
              changes(kube_deployment_status_replicas_updated[10m]) == 0
            )
          for: 15m
          labels:
            severity: warning
          annotations:
            summary: >
              Deployment {{ $labels.namespace }}/{{ $labels.deployment }}
              has been unavailable for 15 minutes
            description: >
              Desired: {{ $labels.kube_deployment_spec_replicas }}
              Available: {{ $labels.kube_deployment_status_replicas_available }}

        - alert: HpaAtMaxCapacity
          expr: |
            kube_horizontalpodautoscaler_status_current_replicas ==
            kube_horizontalpodautoscaler_spec_max_replicas
          for: 30m
          labels:
            severity: warning
          annotations:
            summary: "HPA {{ $labels.namespace }}/{{ $labels.horizontalpodautoscaler }} is at max replicas"
            description: "The HPA has been at its maximum replica count for 30 minutes. Consider increasing maxReplicas."

    - name: kubernetes.nodes
      rules:
        - alert: NodeMemoryPressure
          expr: kube_node_status_condition{condition="MemoryPressure",status="true"} == 1
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "Node {{ $labels.node }} is under memory pressure"

        - alert: NodeDiskPressure
          expr: kube_node_status_condition{condition="DiskPressure",status="true"} == 1
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "Node {{ $labels.node }} is under disk pressure"

        - alert: NodeFilesystemAlmostFull
          expr: |
            (
              node_filesystem_avail_bytes{fstype!~"tmpfs|fuse.lxcfs"}
              / node_filesystem_size_bytes{fstype!~"tmpfs|fuse.lxcfs"}
            ) < 0.15
          for: 1h
          labels:
            severity: warning
          annotations:
            summary: "Node {{ $labels.instance }} filesystem almost full"
            description: "Filesystem {{ $labels.mountpoint }} has less than 15% free space."

    # ── Application SLO alerting rules ────────────────────────────────
    - name: order-api.slo
      rules:
        # SLO: 99.9% of order-api requests succeed over 30 days
        # Error budget = 0.1% = 43.2 minutes/month

        # Fast burn (page immediately): > 14.4x burn rate
        - alert: OrderApiErrorBudgetBurnRateCritical
          expr: |
            (
              sum(rate(http_requests_total{job="order-api",status=~"5.."}[1h])) /
              sum(rate(http_requests_total{job="order-api"}[1h]))
            ) > (14.4 * 0.001)
            and
            (
              sum(rate(http_requests_total{job="order-api",status=~"5.."}[5m])) /
              sum(rate(http_requests_total{job="order-api"}[5m]))
            ) > (14.4 * 0.001)
          for: 0m
          labels:
            severity: critical
            slo: order-api-availability
          annotations:
            summary: "Order API error budget burning too fast (critical)"
            description: >
              Error budget is burning at >14.4x the allowed rate.
              Monthly budget will be exhausted in approximately 2 hours.
              Current error rate: {{ $value | humanizePercentage }}

        # Slow burn (ticket): > 3x burn rate over 3 days
        - alert: OrderApiErrorBudgetBurnRateWarning
          expr: |
            (
              sum(rate(http_requests_total{job="order-api",status=~"5.."}[6h])) /
              sum(rate(http_requests_total{job="order-api"}[6h]))
            ) > (3 * 0.001)
            and
            (
              sum(rate(http_requests_total{job="order-api",status=~"5.."}[30m])) /
              sum(rate(http_requests_total{job="order-api"}[30m]))
            ) > (3 * 0.001)
          for: 0m
          labels:
            severity: warning
            slo: order-api-availability
          annotations:
            summary: "Order API error budget burning above sustainable rate"
            description: >
              Error budget is burning at >3x the allowed rate.
              Monthly budget will be exhausted in approximately 10 days.
```

### 3.4 Alertmanager Configuration

```yaml
# alertmanager-config.yaml
apiVersion: monitoring.coreos.com/v1alpha1
kind: AlertmanagerConfig
metadata:
  name: global-alerting
  namespace: monitoring
  labels:
    alertmanagerConfig: global
spec:
  route:
    receiver: default-receiver
    groupBy: [alertname, namespace, severity]
    groupWait: 30s
    groupInterval: 5m
    repeatInterval: 4h
    routes:
      # Critical alerts → PagerDuty (page the on-call)
      - matchers:
          - name: severity
            value: critical
        receiver: pagerduty-critical
        groupWait: 0s               # No wait for critical — page immediately
        repeatInterval: 1h

      # SLO breach → PagerDuty with SLO context
      - matchers:
          - name: slo
            matchType: =~
            value: ".+"
          - name: severity
            value: critical
        receiver: pagerduty-slo
        groupWait: 0s

      # Warning alerts → Slack
      - matchers:
          - name: severity
            value: warning
        receiver: slack-warnings
        repeatInterval: 8h

      # Platform team alerts → dedicated Slack channel
      - matchers:
          - name: team
            value: platform
        receiver: slack-platform
        continue: true              # Also route to default receiver

      # Suppress all alerts from dev namespace
      - matchers:
          - name: namespace
            value: development
        receiver: dev-null

  receivers:
    - name: default-receiver
      slackConfigs:
        - apiURL:
            name: alertmanager-slack-secret
            key: webhook-url
          channel: "#alerts-general"
          sendResolved: true
          title: >-
            [{{ .Status | toUpper }}{{ if eq .Status "firing" }}:{{ .Alerts.Firing | len }}{{ end }}]
            {{ .CommonLabels.alertname }}
          text: |
            {{ range .Alerts }}
            *Alert:* {{ .Annotations.summary }}
            *Namespace:* {{ .Labels.namespace }}
            *Severity:* {{ .Labels.severity }}
            *Description:* {{ .Annotations.description }}
            *Runbook:* {{ .Annotations.runbook }}
            {{ end }}

    - name: pagerduty-critical
      pagerdutyConfigs:
        - routingKey:
            name: alertmanager-pagerduty-secret
            key: routing-key
          severity: critical
          description: "{{ .CommonAnnotations.summary }}"
          details:
            namespace: "{{ .CommonLabels.namespace }}"
            runbook: "{{ .CommonAnnotations.runbook }}"
          links:
            - href: "https://grafana.mycompany.com/d/k8s-cluster?var-namespace={{ .CommonLabels.namespace }}"
              text: "Grafana Dashboard"

    - name: pagerduty-slo
      pagerdutyConfigs:
        - routingKey:
            name: alertmanager-pagerduty-secret
            key: routing-key-slo
          severity: critical
          description: "SLO Breach: {{ .CommonAnnotations.summary }}"
          details:
            slo: "{{ .CommonLabels.slo }}"
            description: "{{ .CommonAnnotations.description }}"

    - name: slack-warnings
      slackConfigs:
        - apiURL:
            name: alertmanager-slack-secret
            key: webhook-url
          channel: "#alerts-warning"
          sendResolved: true
          title: "⚠️ {{ .CommonLabels.alertname }}"
          text: |
            {{ range .Alerts }}
            *Summary:* {{ .Annotations.summary }}
            *Namespace:* {{ .Labels.namespace }}
            {{ end }}

    - name: slack-platform
      slackConfigs:
        - apiURL:
            name: alertmanager-slack-secret
            key: webhook-url
          channel: "#platform-oncall"
          sendResolved: true

    - name: dev-null
      # Empty receiver — silently discard

  inhibitRules:
    # If cluster is down, suppress individual node alerts
    - sourceMatchers:
        - name: alertname
          value: ClusterDown
      targetMatchers:
        - name: alertname
          matchType: =~
          value: "Node.*"
      equal: [cluster]

    # If node is down, suppress Pod alerts on that node
    - sourceMatchers:
        - name: alertname
          value: NodeNotReady
      targetMatchers:
        - name: alertname
          matchType: =~
          value: "Pod.*"
      equal: [node]

    # Suppress warning if critical is already firing for same alert
    - sourceMatchers:
        - name: severity
          value: critical
      targetMatchers:
        - name: severity
          value: warning
      equal: [alertname, namespace]
```

### 3.5 Loki Installation

```bash
# Install Loki in simple-scalable mode (recommended for production)
helm install loki grafana/loki \
  --namespace monitoring \
  --version 6.6.2 \
  --values - <<'EOF'
loki:
  # Loki configuration
  commonConfig:
    replication_factor: 3

  schemaConfig:
    configs:
      - from: 2024-01-01
        store: tsdb
        object_store: s3
        schema: v13
        index:
          prefix: loki_index_
          period: 24h

  storage:
    type: s3
    s3:
      region: us-east-1
      bucketnames: my-loki-chunks
      s3forcepathstyle: false

  # Retention
  limits_config:
    retention_period: 30d
    ingestion_rate_mb: 16
    ingestion_burst_size_mb: 32
    per_stream_rate_limit: 5MB
    per_stream_rate_limit_burst: 20MB

# Ingester (buffers writes to object storage)
ingester:
  replicas: 3
  persistence:
    enabled: true
    storageClass: gp3
    size: 10Gi

# Distributor (receives log writes)
distributor:
  replicas: 2

# Querier (serves read requests)
querier:
  replicas: 2

# Query frontend (cache and fan-out queries)
queryFrontend:
  replicas: 2
EOF

# Install Promtail (DaemonSet that ships container logs to Loki)
helm install promtail grafana/promtail \
  --namespace monitoring \
  --version 6.16.1 \
  --values - <<'EOF'
config:
  clients:
    - url: http://loki-gateway.monitoring/loki/api/v1/push

  snippets:
    # Add Kubernetes metadata to all log streams
    pipelineStages:
      - cri: {}      # Parse CRI log format (containerd)

      # Parse JSON structured logs
      - match:
          selector: '{app=~".+"}'
          stages:
            - json:
                expressions:
                  level: level
                  trace_id: trace_id
                  service: service
            - labels:
                level:
                trace_id:

      # Drop health check logs (high volume, low value)
      - drop:
          expression: '.*GET /health.*'
          drop_counter_reason: healthcheck

      # Add cluster label
      - static_labels:
          cluster: production-eks

resources:
  requests:
    cpu: 50m
    memory: 128Mi
  limits:
    cpu: 200m
    memory: 256Mi
EOF

kubectl get pods -n monitoring -l app.kubernetes.io/name=promtail
# Should show one Pod per node (DaemonSet)
```

### 3.6 Grafana Tempo Installation

```bash
# Install Tempo in distributed mode
helm install tempo grafana/tempo-distributed \
  --namespace monitoring \
  --version 1.9.10 \
  --values - <<'EOF'
storage:
  trace:
    backend: s3
    s3:
      bucket: my-tempo-traces
      region: us-east-1
      endpoint: s3.us-east-1.amazonaws.com

traces:
  otlp:
    grpc:
      enabled: true     # Receive OTLP traces on gRPC port 4317
    http:
      enabled: true     # Receive OTLP traces on HTTP port 4318
  jaeger:
    grpc:
      enabled: true     # Also accept Jaeger format

distributor:
  replicas: 2
ingester:
  replicas: 3
  persistence:
    enabled: true
    storageClass: gp3
    size: 10Gi
querier:
  replicas: 2
queryFrontend:
  replicas: 2
compactor:
  replicas: 1
  config:
    compaction:
      block_retention: 720h   # 30 days
EOF

# Install OpenTelemetry Collector (receives app telemetry, ships to backends)
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

helm install otel-collector open-telemetry/opentelemetry-collector \
  --namespace monitoring \
  --version 0.90.0 \
  --values - <<'EOF'
mode: deployment
replicaCount: 2

config:
  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: 0.0.0.0:4317
        http:
          endpoint: 0.0.0.0:4318
    prometheus:
      config:
        scrape_configs:
          - job_name: otel-collector
            static_configs:
              - targets: [localhost:8888]

  processors:
    batch:
      timeout: 10s
      send_batch_size: 8192
    memory_limiter:
      limit_mib: 400
      spike_limit_mib: 100
      check_interval: 5s
    # Add Kubernetes attributes (namespace, pod, node, etc.)
    k8sattributes:
      extract:
        metadata:
          - k8s.namespace.name
          - k8s.pod.name
          - k8s.node.name
          - k8s.deployment.name

  exporters:
    prometheusremotewrite:
      endpoint: http://kube-prometheus-stack-prometheus:9090/api/v1/write
    loki:
      endpoint: http://loki-gateway.monitoring/loki/api/v1/push
    otlp:
      endpoint: tempo-distributor:4317
      tls:
        insecure: true

  service:
    pipelines:
      traces:
        receivers: [otlp]
        processors: [memory_limiter, k8sattributes, batch]
        exporters: [otlp]
      metrics:
        receivers: [otlp, prometheus]
        processors: [memory_limiter, batch]
        exporters: [prometheusremotewrite]
      logs:
        receivers: [otlp]
        processors: [memory_limiter, k8sattributes, batch]
        exporters: [loki]
EOF
```

---

## 4. Grafana Dashboard — Production SLO Dashboard

### 4.1 SLO Dashboard as Code (Grafonnet / JSON)

```json
{
  "title": "Order API — SLO Dashboard",
  "uid": "order-api-slo",
  "tags": ["slo", "order-api", "production"],
  "time": {"from": "now-30d", "to": "now"},
  "refresh": "1m",
  "panels": [
    {
      "title": "Availability SLO (30-day rolling)",
      "type": "stat",
      "gridPos": {"h": 4, "w": 6, "x": 0, "y": 0},
      "options": {
        "reduceOptions": {"calcs": ["lastNotNull"]},
        "thresholds": {
          "steps": [
            {"color": "red", "value": 0},
            {"color": "yellow", "value": 0.998},
            {"color": "green", "value": 0.999}
          ]
        }
      },
      "targets": [{
        "expr": "1 - (sum(increase(http_requests_total{job=\"order-api\",status=~\"5..\"}[30d])) / sum(increase(http_requests_total{job=\"order-api\"}[30d])))",
        "legendFormat": "Availability"
      }]
    },
    {
      "title": "Error Budget Remaining",
      "type": "gauge",
      "gridPos": {"h": 4, "w": 6, "x": 6, "y": 0},
      "options": {
        "minValue": 0,
        "maxValue": 100,
        "thresholds": {
          "steps": [
            {"color": "red", "value": 0},
            {"color": "yellow", "value": 25},
            {"color": "green", "value": 50}
          ]
        }
      },
      "targets": [{
        "expr": "100 * (1 - (sum(increase(http_requests_total{job=\"order-api\",status=~\"5..\"}[30d])) / sum(increase(http_requests_total{job=\"order-api\"}[30d]))) - 0.999) / (1 - 0.999)",
        "legendFormat": "Budget remaining %"
      }]
    },
    {
      "title": "Request Rate (RPS)",
      "type": "timeseries",
      "gridPos": {"h": 8, "w": 12, "x": 0, "y": 4},
      "targets": [
        {
          "expr": "sum(rate(http_requests_total{job=\"order-api\",status!~\"5..\"}[5m]))",
          "legendFormat": "Success"
        },
        {
          "expr": "sum(rate(http_requests_total{job=\"order-api\",status=~\"5..\"}[5m]))",
          "legendFormat": "Errors"
        }
      ]
    },
    {
      "title": "Latency Percentiles",
      "type": "timeseries",
      "gridPos": {"h": 8, "w": 12, "x": 12, "y": 4},
      "targets": [
        {
          "expr": "histogram_quantile(0.50, sum(rate(http_request_duration_seconds_bucket{job=\"order-api\"}[5m])) by (le))",
          "legendFormat": "P50"
        },
        {
          "expr": "histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{job=\"order-api\"}[5m])) by (le))",
          "legendFormat": "P95"
        },
        {
          "expr": "histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket{job=\"order-api\"}[5m])) by (le))",
          "legendFormat": "P99"
        }
      ]
    }
  ]
}
```

### 4.2 Import Dashboard and Add Loki Correlation

```bash
# Access Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Or expose via Ingress
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana-ingress
  namespace: monitoring
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/auth-type: basic
    nginx.ingress.kubernetes.io/auth-secret: grafana-basic-auth
spec:
  tls:
    - hosts: [grafana.mycompany.com]
      secretName: grafana-tls
  rules:
    - host: grafana.mycompany.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: kube-prometheus-stack-grafana
                port:
                  number: 80
EOF

# Import the kube-prometheus-stack default dashboards
# These are automatically available:
# - Kubernetes / Compute Resources / Cluster
# - Kubernetes / Compute Resources / Namespace (Pods)
# - Kubernetes / Compute Resources / Node (Pods)
# - Kubernetes / Networking / Cluster
# - Kubernetes / Persistent Volumes
# - Node Exporter / Nodes

# List all available dashboards
kubectl get configmaps -n monitoring -l grafana_dashboard=1 | head -20
```

---

## 5. Step-by-Step Hands-on Walkthrough

### 5.1 Application Instrumentation with OpenTelemetry

```javascript
// Node.js application — OpenTelemetry instrumentation
// tracing.js (loaded before any other module)

const { NodeSDK } = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-grpc');
const { OTLPMetricExporter } = require('@opentelemetry/exporter-metrics-otlp-grpc');
const { PeriodicExportingMetricReader } = require('@opentelemetry/sdk-metrics');
const { Resource } = require('@opentelemetry/resources');
const { SemanticResourceAttributes } = require('@opentelemetry/semantic-conventions');

const sdk = new NodeSDK({
  resource: new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: process.env.SERVICE_NAME || 'order-api',
    [SemanticResourceAttributes.SERVICE_VERSION]: process.env.APP_VERSION || '1.0.0',
    [SemanticResourceAttributes.DEPLOYMENT_ENVIRONMENT]: process.env.APP_ENV || 'production',
  }),

  // Send traces to the OTel Collector (which forwards to Tempo)
  traceExporter: new OTLPTraceExporter({
    url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://otel-collector:4317',
  }),

  // Send metrics to the OTel Collector (which forwards to Prometheus)
  metricReader: new PeriodicExportingMetricReader({
    exporter: new OTLPMetricExporter({
      url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://otel-collector:4317',
    }),
    exportIntervalMillis: 30000,
  }),

  // Auto-instrument HTTP, Express, PostgreSQL, Redis, gRPC
  instrumentations: [getNodeAutoInstrumentations({
    '@opentelemetry/instrumentation-fs': { enabled: false },  // Too noisy
  })],
});

sdk.start();

process.on('SIGTERM', () => {
  sdk.shutdown().then(() => process.exit(0));
});
```

```yaml
# Deployment with OTel environment variables
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-api
  namespace: production
spec:
  template:
    spec:
      containers:
        - name: api
          image: myapp/order-api:1.4.2
          env:
            - name: SERVICE_NAME
              value: order-api
            - name: APP_VERSION
              value: "1.4.2"
            - name: APP_ENV
              value: production
            - name: OTEL_EXPORTER_OTLP_ENDPOINT
              value: http://otel-collector.monitoring:4317
            - name: OTEL_RESOURCE_ATTRIBUTES
              value: "k8s.pod.name=$(POD_NAME),k8s.namespace.name=$(NAMESPACE)"
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
```

### 5.2 End-to-End Observability Verification

```bash
# Generate test traffic to produce metrics, logs, and traces
kubectl run load-gen \
  --image=busybox:1.36 \
  --restart=Never \
  -n production \
  -- sh -c "
    for i in \$(seq 1 100); do
      wget -qO- http://order-api-svc/api/v1/orders > /dev/null 2>&1
      sleep 0.1
    done
    echo 'Load generation complete'
  "

# ── Verify Prometheus is scraping ────────────────────────────────────
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090 &

# Open http://localhost:9090 → Status → Targets
# All ServiceMonitors should show green

# Query via CLI
curl -s "http://localhost:9090/api/v1/query?query=sum(rate(http_requests_total[5m]))" | \
  jq '.data.result[] | {metric: .metric, value: .value[1]}'

# ── Verify Loki is receiving logs ─────────────────────────────────────
kubectl port-forward -n monitoring svc/loki-gateway 3100:80 &

curl -s \
  "http://localhost:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={namespace="production",app="order-api"}' \
  --data-urlencode 'limit=10' | \
  jq '.data.result[0].values[] | .[1]'

# ── Verify Tempo is receiving traces ──────────────────────────────────
kubectl port-forward -n monitoring svc/tempo 3200:3100 &

# Query for recent traces
curl -s "http://localhost:3200/api/search?limit=5" | \
  jq '.traces[] | {traceID: .traceID, rootServiceName: .rootServiceName, duration: .durationMs}'

# ── Check Alertmanager status ─────────────────────────────────────────
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093 &

curl -s http://localhost:9093/api/v2/alerts | \
  jq '.[] | {name: .labels.alertname, state: .status.state, severity: .labels.severity}'
```

---

## 6. Real-World Scenario: MTTD Reduction at E-Commerce Company

### The Problem

ShopFast, a mid-sized e-commerce platform, was experiencing a recurring issue: a subtle memory leak in their checkout service would accumulate over 72 hours, eventually causing OOMKills and checkout failures. The mean time to detect (MTTD) was 4+ hours because:

- Metrics existed but no alerts were configured for gradual memory increase
- Logs contained the stack trace but engineers had to manually search across 12 services
- No distributed tracing — when checkout failed, it was unclear whether the fault was in the checkout service, the payment gateway client, or the inventory check

### The Observability Stack

```
Order placed → checkout-api → payment-api → inventory-api
                    │               │              │
                    ├── OTel SDK    ├── OTel SDK   ├── OTel SDK
                    └───────────────┴──────────────┘
                                   │
                              OTel Collector
                           ┌────────┴─────────┐
                         Tempo              Prometheus
                        (traces)             (metrics)
                                              │
                                         PrometheusRule
                                         (memory trend alert)
                                              │
                                         Alertmanager
                                              │
                                         PagerDuty (at 72% memory)
                                         Slack (at 60% memory)
```

### The Solution

**Memory trend alert** using `predict_linear()`:

```yaml
- alert: CheckoutApiMemoryLeakDetected
  expr: |
    predict_linear(
      container_memory_working_set_bytes{
        namespace="production",
        pod=~"checkout-api-.*",
        container="checkout-api"
      }[6h], 24 * 3600
    ) > container_spec_memory_limit_bytes{
        namespace="production",
        container="checkout-api"
      }
  for: 30m
  labels:
    severity: warning
  annotations:
    summary: "Checkout API memory will exceed limit in <24h"
    description: >
      Based on the 6-hour memory growth trend, container {{ $labels.pod }}
      will reach its memory limit in approximately
      {{ printf "%.0f" (($value / 1024 / 1024) | float64) }}MB
      within 24 hours. Investigate for memory leaks.
```

**Distributed trace correlation**: When the alert fires, the on-call engineer opens Grafana, finds the affected Pod in the alert, navigates to the Loki logs panel (showing OOMKill stack traces), and clicks the `trace_id` field to jump directly to the Tempo trace showing the exact request chain where memory was allocated.

### Results

| Metric | Before | After |
|---|---|---|
| MTTD (memory leak) | 4+ hours (customer reports) | 23 minutes (predictive alert) |
| MTTD (checkout errors) | 45 minutes (log search) | 8 minutes (trace → log correlation) |
| Alert noise (false positives/week) | 340 (no deduplication) | 12 (grouped + inhibited) |
| Dashboard load time (1-year data) | 8 seconds | 0.3 seconds (recording rules) |
| On-call engineer context switching | 3-4 tools per incident | 1 tool (Grafana, correlated) |

---

## 7. Common Pitfalls & Best Practices

### Pitfall 1: High-Cardinality Labels Breaking Prometheus
Prometheus stores one time series per unique combination of label values. Using high-cardinality fields like `user_id`, `order_id`, `session_id`, or `request_id` as Prometheus labels will create millions of time series, exhausting memory and degrading query performance. **Never use unbounded fields as Prometheus labels. Use logs and traces for per-request data; use Prometheus for aggregate metrics.**

### Pitfall 2: Missing `for` Duration on Alerting Rules
An alerting rule without a `for` clause fires immediately on the first evaluation where the condition is true. A transient spike lasting 15 seconds will page the on-call engineer. Most infrastructure alerts should have a `for: 5m` or `for: 15m` duration to filter out transient conditions. The exception is SLO burn rate alerts, where a high burn rate is itself a timed concept.

### Pitfall 3: Prometheus Without Remote Storage Running Out of Local Disk
The default Prometheus retention is 15 days with no size limit. In a busy cluster, TSDB can grow to hundreds of gigabytes. **Always set both `--storage.tsdb.retention.time` and `--storage.tsdb.retention.size`. For production, configure remote write to a long-term storage backend (Thanos, Mimir, Cortex) and keep only 7-15 days of local data.**

### Pitfall 4: Not Pre-Computing Expensive Queries with Recording Rules
PromQL queries that aggregate across hundreds of time series (especially histogram quantile calculations) can take seconds to execute. When used in Grafana dashboards, they re-run on every panel refresh across every concurrent user. **Pre-compute expensive queries as recording rules. Recording rules execute once per evaluation interval and store the result as a new metric — dashboards then query the pre-computed result in milliseconds.**

### Pitfall 5: Loki Log Volume Exhausting Object Storage Budget
Without per-stream rate limits, a single misbehaving application (infinite error loop, debug logging left on in production) can flood Loki with millions of log lines per second, exhausting the storage budget for the entire cluster. **Configure `per_stream_rate_limit` in Loki's `limits_config` and add Promtail `drop` pipeline stages for high-volume, low-value logs like health check endpoints.**

### Pitfall 6: Alert Routing Without Inhibition Rules
When a node fails, Kubernetes will fire alerts for every Pod that was running on that node: PodNotReady, DeploymentReplicaMismatch, HPAAtMaxCapacity, etc. Without inhibition rules, an on-call engineer receives 50 separate alerts from a single node failure. **Configure Alertmanager inhibition rules that suppress downstream alerts when an upstream cause is firing.**

> **Observability Production Readiness Checklist**
> - [ ] kube-prometheus-stack installed with persistent storage for Prometheus and Alertmanager
> - [ ] ServiceMonitors created for all production workloads
> - [ ] PrometheusRules defined for the four golden signals per service
> - [ ] SLO burn rate alerts configured (fast burn and slow burn windows)
> - [ ] Alertmanager routing configured: critical → PagerDuty, warning → Slack
> - [ ] Alertmanager inhibition rules configured (cluster → node → pod cascade)
> - [ ] Recording rules pre-computing all dashboard-used aggregations
> - [ ] Loki installed with S3/GCS backend; Promtail DaemonSet running
> - [ ] Per-stream rate limits configured to prevent log floods
> - [ ] Tempo installed; applications instrumented with OpenTelemetry SDK
> - [ ] Grafana datasources linked: Prometheus, Loki, Tempo with trace-to-log correlation
> - [ ] Grafana dashboards for: cluster overview, namespace resources, SLO status
> - [ ] Remote write configured to long-term storage for >15 days metric retention
> - [ ] kube-state-metrics deployed; node-exporter DaemonSet running

---

## 8. Key Takeaways

1. **The three pillars — metrics, logs, and traces — are complementary, not redundant.** Metrics tell you something is wrong. Logs tell you what happened. Traces tell you where in the request lifecycle it happened. All three are required for production-grade observability; any single pillar is insufficient for incident response.

2. **The Prometheus Operator pattern — ServiceMonitors, PodMonitors, and PrometheusRules — makes scrape configuration and alerting rules version-controlled, reviewable, and deployable alongside application code.** Scrape targets are discovered automatically; no manual Prometheus configuration editing is required.

3. **SLO-based alerting with error budget burn rates is more actionable than threshold-based alerting.** A 5xx error rate of 1% means nothing without knowing the SLO target and how much of the monthly error budget remains. Multi-window burn rate alerts catch both sudden spikes (1-hour window) and slow degradation (6-hour window) with calibrated urgency.

4. **Recording rules are mandatory for production dashboards.** Pre-computing expensive histogram quantile and multi-dimensional aggregation queries eliminates the most common cause of slow Grafana dashboards. Recording rules run once per evaluation interval; dashboards query the pre-computed result instantly.

5. **Alertmanager grouping, inhibition, and routing are not optional configuration.** Without them, a single node failure generates dozens of simultaneous alerts that exhaust on-call attention. With them, the same event generates one grouped, prioritised alert with clear context.

6. **Log, metric, and trace correlation in Grafana is the force-multiplier that reduces MTTD.** Linking a trace ID in a Loki log entry to a Tempo trace, and correlating that trace's timestamp with a Prometheus metric spike, collapses what used to be 3-4 context switches across different tools into a single investigation flow.

---

## 9. Exercises & Labs

**Exercise 1: Deploy the Full Observability Stack**
Install kube-prometheus-stack, Loki with Promtail, and Tempo on a test cluster. Deploy a sample Node.js application instrumented with OpenTelemetry. Verify: (a) Prometheus is scraping the application's `/metrics` endpoint via a ServiceMonitor, (b) Loki is receiving structured JSON logs from Promtail, (c) Tempo is receiving traces from the OTel Collector. In Grafana Explore, write one PromQL query, one LogQL query, and view one trace end-to-end.

**Exercise 2: PrometheusRule Authoring**
Write a PrometheusRule resource containing: (a) a recording rule that pre-computes the per-service error ratio over 5 minutes, (b) an alerting rule that fires when any Pod has restarted more than 5 times in 30 minutes with a `for: 15m` stabilisation window, (c) an SLO burn rate alert for a 99.5% availability SLO (calculate the threshold for a 14.4x fast-burn). Apply the rules and verify they appear in the Prometheus UI under Status → Rules.

**Exercise 3: Alertmanager Routing and Inhibition**
Configure Alertmanager with: (a) a route that sends `severity=critical` alerts to a test webhook (use `webhook.site` for testing), (b) a route that sends `severity=warning` alerts to a Slack channel (or mock endpoint), (c) an inhibition rule that suppresses `PodNotReady` alerts when `NodeNotReady` is firing for the same node. Trigger both `NodeNotReady` (by stopping kubelet on a worker) and observe that Pod alerts are suppressed.

**Exercise 4: LogQL Investigation Drill**
Deploy an application that periodically logs errors at a rate you can control. Write LogQL queries to: (a) count the number of error log lines per minute over the last hour using `count_over_time`, (b) extract the `error_code` field from JSON logs and group counts by error code, (c) calculate the P95 response latency from a `response_time_ms` field in structured logs using `quantile_over_time` with `unwrap`. Visualise all three as Grafana panels.

**Exercise 5: SLO Dashboard Build**
For a service of your choice, define: an SLI (successful HTTP request ratio), an SLO (pick a target: 99.9%, 99.5%, etc.), and calculate the 30-day error budget in minutes. Build a Grafana dashboard with four panels: (a) current SLO compliance (stat panel), (b) error budget remaining as a percentage (gauge), (c) error budget burn rate over the last 24 hours (timeseries), (d) the request rate vs error rate on the same panel (timeseries with two y-axes). Set panel thresholds so the dashboard turns red when the error budget drops below 25%.

---

*End of Chapter 10*

**Next → Chapter 11: Packaging and Deploying in Kubernetes**



---

──────────────────────────────────────────────────────────────────────

## Part XI: Packaging and Deploying in Kubernetes

> *Helm · Kustomize · OCI Registries · Argo CD · Flux CD*

──────────────────────────────────────────────────────────────────────


## 1. Introduction & Learning Objectives

You have built your application, containerised it, secured it, and instrumented it for observability. Now you face the challenge that every production Kubernetes team eventually hits: how do you package, version, and deploy that application — consistently, repeatably, and safely — across development, staging, and production environments?

The Kubernetes ecosystem has converged on two complementary approaches. **Helm** treats deployment packages like software releases — versioned, templated, parameterisable charts that can be shared, discovered, and installed with a single command. **Kustomize** treats environment differences as a structured patch layer on top of a common base — no templating, just plain Kubernetes YAML augmented by a principled overlay system. Most mature platforms use both: Helm for third-party dependencies, Kustomize for first-party application configuration.

Underpinning both is **GitOps** — the operational model where Git is the single source of truth for cluster state and a software agent continuously reconciles the live cluster toward that state. **Argo CD** and **Flux CD** are the two dominant GitOps platforms, and this chapter covers both in enough depth to make an informed production choice.

This chapter builds a complete multi-environment delivery pipeline: Helm chart authoring from scratch, Kustomize overlays for dev/staging/production, OCI artifact storage for both chart and container images, and full GitOps promotion workflows with Argo CD and Flux CD.

> **Learning Objectives**
> - Author a production-grade Helm chart from scratch, including templating, helpers, hooks, and tests.
> - Manage chart dependencies, use sub-charts, and publish charts to OCI registries.
> - Build a Kustomize configuration with a DRY base and environment-specific overlays using strategic merge patches and JSON patches.
> - Choose the right tool for the right job: Helm vs Kustomize vs both.
> - Understand the GitOps principles and how Argo CD and Flux CD implement them differently.
> - Deploy multi-environment promotion workflows with Argo CD ApplicationSets.
> - Configure Flux CD with HelmRelease, Kustomization, and ImageUpdateAutomation resources.
> - Implement progressive delivery patterns: canary, blue/green, and traffic splitting with Argo Rollouts.

---

## 2. Core Concepts

### 2.1 Helm — The Kubernetes Package Manager

Helm solves three problems simultaneously: **packaging** (bundling all Kubernetes manifests for an application into a single, versioned artifact), **configuration** (parameterising the manifests so the same chart installs differently in dev and prod), and **lifecycle management** (tracking what is installed, upgrading it, and rolling it back).

```
Helm Terminology:

  Chart        The package — a directory of templates + values + metadata
  Repository   A collection of charts (HTTP server or OCI registry)
  Release      A deployed instance of a chart in a namespace
  Revision     A numbered history entry for a release (upgrade = new revision)
  Values       Configuration injected into templates at render time

Helm workflow:
  helm install  → Chart + Values → Rendered YAML → kubectl apply → Release created
  helm upgrade  → Chart + Values → Rendered YAML → kubectl apply → New revision
  helm rollback → Previous revision → kubectl apply → Release reverted
  helm test     → Run test Pods defined in chart → Pass/Fail
```

#### Chart Structure

```
order-api/
├── Chart.yaml              ← Chart metadata (name, version, appVersion, dependencies)
├── values.yaml             ← Default values (developer-facing API of the chart)
├── values-staging.yaml     ← Staging overrides (convention, not built-in)
├── values-production.yaml  ← Production overrides
├── .helmignore             ← Files to exclude from chart packaging
├── charts/                 ← Unpacked sub-chart dependencies
├── crds/                   ← CRDs to install before rendering templates
└── templates/
    ├── NOTES.txt           ← Post-install instructions (printed to user)
    ├── _helpers.tpl        ← Template helpers (named templates, shared functions)
    ├── deployment.yaml
    ├── service.yaml
    ├── ingress.yaml
    ├── configmap.yaml
    ├── serviceaccount.yaml
    ├── hpa.yaml
    ├── pdb.yaml
    ├── networkpolicy.yaml
    └── tests/
        └── test-connection.yaml
```

---

### 2.2 Kustomize — Configuration Management Without Templating

Kustomize takes a fundamentally different approach: instead of parameterising templates with variables, it applies structured patches to plain Kubernetes YAML. There are no `{{ .Values.image.tag }}` expressions — only Kubernetes objects that are modified by overlays.

```
Kustomize Terminology:

  Base       Shared Kubernetes manifests that work everywhere
  Overlay    Environment-specific changes layered on top of a base
  Patch      A strategic merge or JSON patch that modifies a resource
  Generator  Produces ConfigMaps or Secrets from files or literals
  Transformer Modifies resources (add labels, change namespaces, etc.)

Kustomize mental model:
  Base manifests + Overlay patches = Final manifests
  (no variables, no conditionals, just YAML transformations)
```

#### Directory Structure

```
k8s/
├── base/
│   ├── kustomization.yaml        ← Lists all resources in the base
│   ├── deployment.yaml           ← Common deployment spec
│   ├── service.yaml
│   ├── configmap.yaml
│   └── serviceaccount.yaml
└── overlays/
    ├── development/
    │   ├── kustomization.yaml    ← Base + dev patches
    │   ├── replica-patch.yaml    ← 1 replica in dev
    │   └── config-patch.yaml     ← Dev-specific config
    ├── staging/
    │   ├── kustomization.yaml
    │   ├── replica-patch.yaml    ← 3 replicas in staging
    │   └── ingress.yaml          ← Staging-specific Ingress
    └── production/
        ├── kustomization.yaml
        ├── replica-patch.yaml    ← 5 replicas in production
        ├── hpa.yaml              ← HPA only in production
        ├── pdb.yaml              ← PDB only in production
        └── ingress.yaml
```

---

### 2.3 Helm vs Kustomize — When to Use Which

The Helm vs Kustomize debate is a false dichotomy in mature organisations. Both tools solve real problems; the right question is which is better suited for each use case.

| Dimension | Helm | Kustomize |
|---|---|---|
| **Packaging for distribution** | ✅ Versioned, shareable charts | ❌ Not designed for distribution |
| **Third-party software** | ✅ Community charts available | ✅ Use Helm chart then kustomize output |
| **Configuration variance** | ✅ Values files per environment | ✅ Overlays per environment |
| **Readability** | ⚠️ Templates can be complex | ✅ Plain YAML, easy to review |
| **Dynamic logic** | ✅ `if/else`, `range`, `default` | ❌ No conditionals; use patches |
| **GitOps friendliness** | ✅ via HelmRelease CRD | ✅ Native — just YAML in Git |
| **Secret management** | ⚠️ Values can contain secrets | ✅ generators + Sealed Secrets |
| **Kubernetes API awareness** | ❌ Strings until `helm install` | ✅ Strategic merge understands K8s |
| **Diffing changes** | ⚠️ `helm diff` plugin needed | ✅ `kubectl diff` natively |
| **Learning curve** | Moderate (Go templates) | Low (just YAML patches) |

```
Decision guide:

Use Helm when:
  ├── Distributing software (open source project, internal platform team)
  ├── Packaging complex apps with many configurable parameters
  ├── Dynamic manifest generation (e.g. create N resources based on a list)
  └── Installing community charts (databases, monitoring, cert-manager)

Use Kustomize when:
  ├── Managing your own application across multiple environments
  ├── Adding overlays to third-party Helm chart outputs
  ├── GitOps workflows where reviewers need to read diffs clearly
  └── You want zero templating complexity in your manifests

Use both when (most common production pattern):
  Helm for third-party software (PostgreSQL, Kafka, Prometheus)
  Kustomize for your own application configuration on top
```

---

### 2.4 GitOps — Git as the Operational Control Plane

GitOps (coined by Alexis Richardson, Weaveworks, 2017) formalises the following operational model:

```
The Four GitOps Principles (OpenGitOps specification):

  1. Declarative:    The entire system state is described declaratively.
                     Helm charts + values, Kustomize overlays, plain YAML — all valid.

  2. Versioned:      The desired state is stored in Git (or an immutable OCI artifact).
                     Every change has a commit hash, an author, and a timestamp.

  3. Pulled:         Software agents pull the desired state from Git.
                     No push-based deployments; no CI pipeline with cluster credentials.

  4. Reconciled:     Agents continuously compare desired vs actual state.
                     Drift is detected and corrected automatically.
```

#### Argo CD vs Flux CD Architecture Comparison

```
┌──────────────────────────────────────────────────────────────────────┐
│  ARGO CD                              FLUX CD                         │
│  ──────────────────────────────────── ────────────────────────────── │
│                                                                       │
│  Architecture: Centralised            Architecture: Distributed       │
│  ├── One Argo CD per cluster or       ├── Flux installed per cluster  │
│  │   managing many clusters           ├── Pull-only model             │
│  └── Push model to remote clusters    └── Cluster manages itself      │
│                                                                       │
│  UI: Rich web UI + CLI                UI: CLI only (+ VS Code ext)    │
│                                                                       │
│  Config: Application CRD              Config: Kustomization +         │
│          ApplicationSet CRD                   HelmRelease CRDs        │
│                                                                       │
│  Multi-tenancy: Projects +            Multi-tenancy: Tenants +        │
│                 AppProjects                       RBAC policies        │
│                                                                       │
│  Sync strategy: Manual or auto        Sync strategy: Always auto      │
│  Prune: Optional                      Prune: Optional                 │
│                                                                       │
│  Best for:                            Best for:                       │
│  ├── Teams wanting a visual UI        ├── Teams preferring CLI/GitOps │
│  ├── Multi-cluster management         ├── Single or many clusters     │
│  ├── Approval workflows               ├── Native Kubernetes CRD feel  │
│  └── App-of-apps patterns             └── Image update automation     │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 3. Helm — Deep Dive

### 3.1 Chart.yaml and values.yaml

```yaml
# Chart.yaml — chart metadata
apiVersion: v2            # Helm 3 (always v2)
name: order-api
description: >
  The Order API service — handles order creation, validation,
  and lifecycle management for the e-commerce platform.
type: application         # application (deployed) or library (helper templates)
version: 1.4.2            # Chart version (semantic versioning)
appVersion: "2.1.0"       # Application version (informational, shown in helm list)
keywords:
  - order
  - api
  - ecommerce
home: https://github.com/myorg/order-api
sources:
  - https://github.com/myorg/order-api
maintainers:
  - name: Platform Team
    email: platform@mycompany.com

# Chart dependencies (sub-charts)
dependencies:
  - name: postgresql
    version: "~15.5.0"    # Tilde: patch-level flexibility
    repository: oci://registry-1.docker.io/bitnamicharts
    condition: postgresql.enabled    # Only install if this value is true
  - name: redis
    version: "~19.5.0"
    repository: oci://registry-1.docker.io/bitnamicharts
    condition: redis.enabled
```

```yaml
# values.yaml — the developer-facing API of the chart
# Every value should be documented with a comment.

# ── Image configuration ───────────────────────────────────────────────
image:
  repository: myapp/order-api
  tag: ""                          # Defaults to chart appVersion if empty
  pullPolicy: IfNotPresent
  pullSecrets: []

# ── Replica and scaling configuration ────────────────────────────────
replicaCount: 2

autoscaling:
  enabled: false
  minReplicas: 2
  maxReplicas: 20
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

# ── Resource limits ───────────────────────────────────────────────────
resources:
  requests:
    cpu: 250m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi

# ── Service configuration ─────────────────────────────────────────────
service:
  type: ClusterIP
  port: 80
  targetPort: 8080
  annotations: {}

# ── Ingress configuration ─────────────────────────────────────────────
ingress:
  enabled: false
  className: nginx
  annotations: {}
  hosts:
    - host: order-api.example.com
      paths:
        - path: /
          pathType: Prefix
  tls: []

# ── Application configuration ─────────────────────────────────────────
config:
  env: production
  logLevel: info
  port: "8080"
  maxConnections: "100"
  metricsPath: /metrics
  healthPath: /health

# ── Secret references ─────────────────────────────────────────────────
secrets:
  existingSecret: ""       # Name of an existing Secret to use
  databaseUrlKey: DATABASE_URL
  apiKeyKey: API_KEY

# ── Persistence (for sessions or cache) ───────────────────────────────
persistence:
  enabled: false
  storageClass: ""
  size: 1Gi
  accessMode: ReadWriteOnce

# ── Health probes ─────────────────────────────────────────────────────
probes:
  readiness:
    path: /health/ready
    initialDelaySeconds: 5
    periodSeconds: 10
    failureThreshold: 3
  liveness:
    path: /health/live
    initialDelaySeconds: 30
    periodSeconds: 20
    failureThreshold: 3

# ── Pod disruption budget ─────────────────────────────────────────────
podDisruptionBudget:
  enabled: false
  minAvailable: 1

# ── ServiceAccount ────────────────────────────────────────────────────
serviceAccount:
  create: true
  name: ""
  annotations: {}    # For IRSA: eks.amazonaws.com/role-arn: ...
  automountToken: false

# ── Pod security context ──────────────────────────────────────────────
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 10001
  fsGroup: 10001
  seccompProfile:
    type: RuntimeDefault

containerSecurityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop: ["ALL"]

# ── Affinity and topology ──────────────────────────────────────────────
affinity: {}
nodeSelector: {}
tolerations: []
topologySpreadConstraints: []

# ── PostgreSQL sub-chart ──────────────────────────────────────────────
postgresql:
  enabled: false         # Disabled by default; enable for dev environments

redis:
  enabled: false
```

### 3.2 Template Files

```yaml
# templates/_helpers.tpl — named templates (reusable functions)
{{/*
Expand the name of the chart.
Uses .Values.nameOverride if set, otherwise uses .Chart.Name
*/}}
{{- define "order-api.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
Truncates to 63 chars (Kubernetes label value limit).
*/}}
{{- define "order-api.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Common labels — applied to every resource.
*/}}
{{- define "order-api.labels" -}}
helm.sh/chart: {{ include "order-api.chart" . }}
{{ include "order-api.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels — used in matchLabels and Service selector.
Must be stable across upgrades; never include mutable values like image tag.
*/}}
{{- define "order-api.selectorLabels" -}}
app.kubernetes.io/name: {{ include "order-api.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
ServiceAccount name resolution.
*/}}
{{- define "order-api.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "order-api.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Image reference — combines repository, tag (or appVersion), and digest.
*/}}
{{- define "order-api.image" -}}
{{- $tag := .Values.image.tag | default .Chart.AppVersion }}
{{- printf "%s:%s" .Values.image.repository $tag }}
{{- end }}
```

```yaml
# templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "order-api.fullname" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "order-api.labels" . | nindent 4 }}
  annotations:
    # Record the values checksum so changes to values trigger a rolling restart
    checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "order-api.selectorLabels" . | nindent 6 }}
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        {{- include "order-api.labels" . | nindent 8 }}
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
        {{- with .Values.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
    spec:
      {{- with .Values.image.pullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "order-api.serviceAccountName" . }}
      automountServiceAccountToken: {{ .Values.serviceAccount.automountToken }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      {{- with .Values.topologySpreadConstraints }}
      topologySpreadConstraints:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      containers:
        - name: {{ .Chart.Name }}
          image: {{ include "order-api.image" . }}
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          securityContext:
            {{- toYaml .Values.containerSecurityContext | nindent 12 }}
          ports:
            - name: http
              containerPort: {{ .Values.config.port | int }}
              protocol: TCP
            - name: metrics
              containerPort: 9090
              protocol: TCP
          envFrom:
            - configMapRef:
                name: {{ include "order-api.fullname" . }}
          env:
            {{- if .Values.secrets.existingSecret }}
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: {{ .Values.secrets.existingSecret }}
                  key: {{ .Values.secrets.databaseUrlKey }}
            - name: API_KEY
              valueFrom:
                secretKeyRef:
                  name: {{ .Values.secrets.existingSecret }}
                  key: {{ .Values.secrets.apiKeyKey }}
            {{- end }}
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          readinessProbe:
            httpGet:
              path: {{ .Values.probes.readiness.path }}
              port: http
            initialDelaySeconds: {{ .Values.probes.readiness.initialDelaySeconds }}
            periodSeconds: {{ .Values.probes.readiness.periodSeconds }}
            failureThreshold: {{ .Values.probes.readiness.failureThreshold }}
          livenessProbe:
            httpGet:
              path: {{ .Values.probes.liveness.path }}
              port: http
            initialDelaySeconds: {{ .Values.probes.liveness.initialDelaySeconds }}
            periodSeconds: {{ .Values.probes.liveness.periodSeconds }}
            failureThreshold: {{ .Values.probes.liveness.failureThreshold }}
          volumeMounts:
            - name: tmp
              mountPath: /tmp
            - name: cache
              mountPath: /app/cache
      volumes:
        - name: tmp
          emptyDir: {}
        - name: cache
          emptyDir: {}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
```

```yaml
# templates/hpa.yaml — conditional HPA
{{- if .Values.autoscaling.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "order-api.fullname" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "order-api.labels" . | nindent 4 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "order-api.fullname" . }}
  minReplicas: {{ .Values.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas }}
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage }}
    {{- if .Values.autoscaling.targetMemoryUtilizationPercentage }}
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetMemoryUtilizationPercentage }}
    {{- end }}
{{- end }}
```

### 3.3 Helm Hooks

Hooks are special templates that run at specific points in the release lifecycle: before install, after install, before upgrade, after upgrade, before delete, and after delete. Common uses: database migrations, secret rotation, pre-flight validation.

```yaml
# templates/hooks/pre-upgrade-migration.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "order-api.fullname" . }}-migration
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "order-api.labels" . | nindent 4 }}
  annotations:
    # Hook declarations
    "helm.sh/hook": pre-upgrade,pre-install
    "helm.sh/hook-weight": "-5"          # Lower weight runs first
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
    # before-hook-creation: delete old job before creating new one
    # hook-succeeded: delete job after successful completion
spec:
  ttlSecondsAfterFinished: 300           # Auto-cleanup 5 minutes after completion
  backoffLimit: 3
  template:
    metadata:
      labels:
        {{- include "order-api.selectorLabels" . | nindent 8 }}
        hook: pre-upgrade-migration
    spec:
      restartPolicy: OnFailure
      serviceAccountName: {{ include "order-api.serviceAccountName" . }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      containers:
        - name: migration
          image: {{ include "order-api.image" . }}
          command: ["/app/migrate", "up"]
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: {{ .Values.secrets.existingSecret }}
                  key: {{ .Values.secrets.databaseUrlKey }}
          securityContext:
            {{- toYaml .Values.containerSecurityContext | nindent 12 }}
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 256Mi
```

### 3.4 Helm Tests

```yaml
# templates/tests/test-connection.yaml
apiVersion: v1
kind: Pod
metadata:
  name: {{ include "order-api.fullname" . }}-test
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "order-api.labels" . | nindent 4 }}
  annotations:
    "helm.sh/hook": test
    "helm.sh/hook-delete-policy": hook-succeeded,hook-failed
spec:
  restartPolicy: Never
  containers:
    - name: test-health
      image: curlimages/curl:8.7.1
      command:
        - sh
        - -c
        - |
          set -e
          echo "Testing health endpoint..."
          curl -sf http://{{ include "order-api.fullname" . }}:{{ .Values.service.port }}/health/ready
          echo "Testing metrics endpoint..."
          curl -sf http://{{ include "order-api.fullname" . }}:{{ .Values.service.port }}/metrics | grep http_requests_total
          echo "All tests passed!"
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop: ["ALL"]
      resources:
        requests:
          cpu: 10m
          memory: 16Mi
```

```bash
# Run chart tests
helm test order-api -n production
# NAME: order-api
# LAST DEPLOYED: Mon Mar 18 10:00:00 2024
# NAMESPACE: production
# STATUS: deployed
# REVISION: 3
# TEST SUITE:     order-api-test
# Last Started:   Mon Mar 18 10:01:00 2024
# Last Completed: Mon Mar 18 10:01:12 2024
# Phase:          Succeeded
```

### 3.5 OCI Registry for Charts

```bash
# Push a Helm chart to an OCI registry
# OCI registries (Docker Hub, ECR, GCR, ACR, GHCR) store Helm charts
# alongside container images using the same content-addressable storage.

# Package the chart
helm package order-api/ --destination ./dist
# Successfully packaged chart and saved it to: ./dist/order-api-1.4.2.tgz

# Login to OCI registry
helm registry login ghcr.io --username myorg --password $GITHUB_TOKEN
helm registry login 123456789.dkr.ecr.us-east-1.amazonaws.com \
  --username AWS \
  --password $(aws ecr get-login-password --region us-east-1)

# Push to OCI registry
helm push ./dist/order-api-1.4.2.tgz oci://ghcr.io/myorg/helm-charts
# Pushed: ghcr.io/myorg/helm-charts/order-api:1.4.2
# Digest: sha256:3d88c5de...

# Install directly from OCI registry
helm install order-api oci://ghcr.io/myorg/helm-charts/order-api \
  --version 1.4.2 \
  --namespace production \
  --values values-production.yaml

# Search OCI-hosted chart versions (experimental)
helm show chart oci://ghcr.io/myorg/helm-charts/order-api --version 1.4.2
```

### 3.6 Helm Deployment Commands

```bash
# ── Install ────────────────────────────────────────────────────────────
helm install order-api ./order-api \
  --namespace production \
  --create-namespace \
  --values ./order-api/values-production.yaml \
  --set image.tag=1.4.2 \
  --set secrets.existingSecret=order-api-db-secret \
  --wait \
  --timeout 5m \
  --atomic                     # Rollback automatically on failure

# ── Upgrade ───────────────────────────────────────────────────────────
helm upgrade order-api ./order-api \
  --namespace production \
  --values ./order-api/values-production.yaml \
  --set image.tag=1.4.3 \
  --wait \
  --timeout 5m \
  --atomic \
  --history-max 10             # Keep last 10 revisions for rollback

# ── Diff before upgrading (requires helm-diff plugin) ─────────────────
helm plugin install https://github.com/databus23/helm-diff
helm diff upgrade order-api ./order-api \
  --namespace production \
  --values ./order-api/values-production.yaml \
  --set image.tag=1.4.3

# ── Rollback ──────────────────────────────────────────────────────────
helm rollback order-api 2 --namespace production

# ── List all releases ─────────────────────────────────────────────────
helm list -A
helm history order-api -n production

# ── Dry run (render templates without applying) ───────────────────────
helm install order-api ./order-api \
  --dry-run \
  --debug \
  --generate-name

# ── Template (render to stdout) ───────────────────────────────────────
helm template order-api ./order-api \
  --values values-production.yaml \
  --set image.tag=1.4.3 \
  | kubectl apply --dry-run=server -f -
```

---

## 4. Kustomize — Deep Dive

### 4.1 Base Configuration

```yaml
# k8s/base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

# Resources to include in this base
resources:
  - deployment.yaml
  - service.yaml
  - serviceaccount.yaml
  - configmap.yaml

# Common labels added to ALL resources
commonLabels:
  app.kubernetes.io/name: order-api
  app.kubernetes.io/managed-by: kustomize

# Common annotations added to ALL resources
commonAnnotations:
  app.kubernetes.io/part-of: ecommerce-platform

# Image transformer — update all images matching a name
images:
  - name: myapp/order-api
    newTag: latest                # Overridden per overlay
```

```yaml
# k8s/base/deployment.yaml — plain Kubernetes YAML, no templating
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-api                 # No namespacing — overlay sets namespace
spec:
  replicas: 1                     # Override in overlays
  selector:
    matchLabels:
      app.kubernetes.io/name: order-api
  template:
    metadata:
      labels:
        app.kubernetes.io/name: order-api
    spec:
      automountServiceAccountToken: false
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        fsGroup: 10001
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: order-api
          image: myapp/order-api:latest    # Tag overridden by images transformer
          ports:
            - containerPort: 8080
          envFrom:
            - configMapRef:
                name: order-api-config
          resources:
            requests:
              cpu: 250m
              memory: 256Mi
            limits:
              cpu: 500m
              memory: 512Mi
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: ["ALL"]
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
          volumeMounts:
            - name: tmp
              mountPath: /tmp
      volumes:
        - name: tmp
          emptyDir: {}
```

### 4.2 Environment Overlays

```yaml
# k8s/overlays/development/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: development

bases:
  - ../../base

# Override image tag for dev
images:
  - name: myapp/order-api
    newTag: dev-latest

# Strategic merge patch — partially override the base Deployment
patchesStrategicMerge:
  - replica-patch.yaml
  - resources-patch.yaml

# Generate ConfigMap from files/literals
configMapGenerator:
  - name: order-api-config
    behavior: merge              # Merge with base ConfigMap
    literals:
      - APP_ENV=development
      - LOG_LEVEL=debug
      - MAX_CONNECTIONS=10

# Secret generator (for dev only — production uses Vault/ESO)
secretGenerator:
  - name: order-api-db-secret
    literals:
      - DATABASE_URL=postgresql://postgres:devpassword@postgres:5432/orders_dev
    type: Opaque
```

```yaml
# k8s/overlays/development/replica-patch.yaml
# Strategic merge patch: only overrides specified fields
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-api
spec:
  replicas: 1           # 1 replica in dev
```

```yaml
# k8s/overlays/production/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: production

bases:
  - ../../base

images:
  - name: myapp/order-api
    newTag: "1.4.2"              # Pin exact version in production
    # Or use digest for immutability:
    # digest: sha256:3d88c5de...

patchesStrategicMerge:
  - replica-patch.yaml
  - resources-patch.yaml

# JSON patch — more precise targeting than strategic merge
patches:
  - path: ingress-patch.yaml
    target:
      kind: Ingress
      name: order-api

  # Inline patch using target + patch
  - target:
      kind: Deployment
      name: order-api
    patch: |-
      - op: add
        path: /spec/template/spec/topologySpreadConstraints
        value:
          - maxSkew: 1
            topologyKey: topology.kubernetes.io/zone
            whenUnsatisfiable: DoNotSchedule
            labelSelector:
              matchLabels:
                app.kubernetes.io/name: order-api

# Resources only present in production
resources:
  - hpa.yaml
  - pdb.yaml
  - networkpolicy.yaml

configMapGenerator:
  - name: order-api-config
    behavior: merge
    literals:
      - APP_ENV=production
      - LOG_LEVEL=info
      - MAX_CONNECTIONS=100

# Add production-specific labels via transformer
labels:
  - pairs:
      env: production
      tier: backend
    includeSelectors: false
    includeTemplates: true
```

```yaml
# k8s/overlays/production/replica-patch.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-api
spec:
  replicas: 5
  template:
    spec:
      containers:
        - name: order-api
          resources:             # Override resources for production
            requests:
              cpu: 500m
              memory: 512Mi
            limits:
              cpu: "2"
              memory: 1Gi
```

```yaml
# k8s/overlays/production/pdb.yaml — only deployed in production
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: order-api-pdb
spec:
  minAvailable: 3
  selector:
    matchLabels:
      app.kubernetes.io/name: order-api
```

```bash
# Build and preview what Kustomize will produce
kubectl kustomize k8s/overlays/production

# Apply a specific overlay
kubectl apply -k k8s/overlays/production

# Diff before applying
kubectl diff -k k8s/overlays/production

# Build and pipe to kubectl for remote dry-run validation
kubectl kustomize k8s/overlays/production | \
  kubectl apply --dry-run=server -f -
```

### 4.3 Kustomize Components (Reusable Mixins)

```yaml
# k8s/components/monitoring/kustomization.yaml
# A Component is a reusable, optional bundle of resources and patches
# Applied by overlays that need it (e.g. staging + production, not dev)
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component

resources:
  - servicemonitor.yaml
  - prometheusrule.yaml

# Applied when this component is included
patches:
  - target:
      kind: Deployment
      name: order-api
    patch: |-
      - op: add
        path: /spec/template/metadata/annotations
        value:
          prometheus.io/scrape: "true"
          prometheus.io/port: "9090"
          prometheus.io/path: "/metrics"
```

```yaml
# k8s/overlays/production/kustomization.yaml (with components)
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

bases:
  - ../../base

# Include reusable components
components:
  - ../../components/monitoring       # Add Prometheus monitoring
  - ../../components/vault-sidecar    # Add Vault agent sidecar injection
  - ../../components/network-policy   # Add default-deny NetworkPolicy
```

---

## 5. GitOps with Argo CD

### 5.1 Argo CD Installation

```bash
kubectl create namespace argocd

kubectl apply -n argocd -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for Argo CD to be ready
kubectl wait --for=condition=available deployment \
  -l app.kubernetes.io/name=argocd-server \
  -n argocd \
  --timeout=120s

# Get initial admin password
argocd admin initial-password -n argocd

# Port-forward to access the UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Login via CLI
argocd login localhost:8080 \
  --username admin \
  --password <initial-password> \
  --insecure

# Change admin password immediately
argocd account update-password
```

### 5.2 Application Resource

```yaml
# argocd/apps/order-api-production.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: order-api-production
  namespace: argocd
  finalizers:
    # Ensures resources are deleted from cluster when this Application is deleted
    - resources-finalizer.argocd.argoproj.io
  labels:
    app: order-api
    env: production
spec:
  project: production-project

  source:
    repoURL: https://github.com/myorg/k8s-config
    targetRevision: main
    path: apps/order-api/overlays/production

  destination:
    server: https://kubernetes.default.svc
    namespace: production

  syncPolicy:
    automated:
      prune: true               # Delete resources removed from Git
      selfHeal: true            # Re-apply if someone manually changes cluster state
      allowEmpty: false         # Prevent syncing an empty directory (safety)
    syncOptions:
      - CreateNamespace=true    # Create namespace if it doesn't exist
      - PrunePropagationPolicy=foreground
      - PruneLast=true          # Delete old resources after new ones are healthy
      - ApplyOutOfSyncOnly=true # Only apply resources that have drifted
      - ServerSideApply=true    # Use server-side apply (better for CRDs)
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m

  ignoreDifferences:
    # Ignore fields managed by other controllers
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas         # HPA manages replicas; Argo CD should not revert
    - group: autoscaling
      kind: HorizontalPodAutoscaler
      jqPathExpressions:
        - .status

  revisionHistoryLimit: 10
```

### 5.3 AppProject — Multi-Tenant Isolation

```yaml
# argocd/projects/production-project.yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: production-project
  namespace: argocd
spec:
  description: Production environment applications

  # Allowed source repositories
  sourceRepos:
    - https://github.com/myorg/k8s-config
    - https://github.com/myorg/helm-charts
    - oci://ghcr.io/myorg/helm-charts

  # Allowed destination clusters and namespaces
  destinations:
    - server: https://kubernetes.default.svc
      namespace: production
    - server: https://kubernetes.default.svc
      namespace: monitoring

  # Forbidden resource types (prevent privilege escalation via Argo CD)
  namespaceResourceBlacklist:
    - group: ""
      kind: ResourceQuota
    - group: ""
      kind: LimitRange

  # Allowed cluster-scoped resources
  clusterResourceWhitelist:
    - group: ""
      kind: Namespace
    - group: networking.k8s.io
      kind: IngressClass

  # RBAC: who can manage apps in this project
  roles:
    - name: production-admin
      description: Full access to production apps
      policies:
        - p, proj:production-project:production-admin, applications, *, production-project/*, allow
      groups:
        - platform-team

    - name: production-deployer
      description: Can sync but not delete production apps
      policies:
        - p, proj:production-project:production-deployer, applications, get, production-project/*, allow
        - p, proj:production-project:production-deployer, applications, sync, production-project/*, allow
      groups:
        - engineering-team

  # Sync windows: restrict when syncs can occur
  syncWindows:
    - kind: deny
      schedule: "0 22 * * 1-5"   # No deployments between 10 PM - 8 AM weekdays
      duration: 10h
      applications: ["*"]
      namespaces: ["production"]
    - kind: allow
      schedule: "0 8 * * 1-5"    # Allow deployments during business hours
      duration: 14h
      applications: ["*"]
      namespaces: ["production"]
      manualSync: true            # Always allow manual sync overrides
```

### 5.4 ApplicationSet — Multi-Environment Promotion

ApplicationSet generates multiple Application resources from a single template, enabling multi-environment deployment patterns.

```yaml
# argocd/appsets/order-api-environments.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: order-api-environments
  namespace: argocd
spec:
  # Generate one Application per environment
  generators:
    - list:
        elements:
          - env: development
            namespace: development
            revision: HEAD            # Dev tracks HEAD of main
            autosync: true
            project: development-project
            values:
              replicaCount: "1"

          - env: staging
            namespace: staging
            revision: HEAD
            autosync: true
            project: staging-project
            values:
              replicaCount: "3"

          - env: production
            namespace: production
            revision: "v1.4.2"        # Production pins to a tag
            autosync: false           # Manual sync for production
            project: production-project
            values:
              replicaCount: "5"

  template:
    metadata:
      name: "order-api-{{env}}"
      namespace: argocd
      labels:
        app: order-api
        env: "{{env}}"
    spec:
      project: "{{project}}"
      source:
        repoURL: https://github.com/myorg/k8s-config
        targetRevision: "{{revision}}"
        path: "apps/order-api/overlays/{{env}}"
      destination:
        server: https://kubernetes.default.svc
        namespace: "{{namespace}}"
      syncPolicy:
        automated:
          prune: true
          selfHeal: "{{autosync}}"
        syncOptions:
          - CreateNamespace=true
          - ServerSideApply=true

---
# Git generator — one Application per directory that has a kustomization.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: all-services
  namespace: argocd
spec:
  generators:
    - git:
        repoURL: https://github.com/myorg/k8s-config
        revision: main
        directories:
          - path: apps/*/overlays/production
  template:
    metadata:
      name: "{{path.basename}}-production"
    spec:
      project: production-project
      source:
        repoURL: https://github.com/myorg/k8s-config
        targetRevision: main
        path: "{{path}}"
      destination:
        server: https://kubernetes.default.svc
        namespace: production
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

### 5.5 Argo Rollouts — Progressive Delivery

```bash
# Install Argo Rollouts
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f \
  https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

kubectl plugin install argo-rollouts  # kubectl plugin
```

```yaml
# Replace Deployment with Rollout for progressive delivery
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: order-api
  namespace: production
spec:
  replicas: 10
  selector:
    matchLabels:
      app: order-api
  template:
    metadata:
      labels:
        app: order-api
    spec:
      # Same Pod spec as a Deployment
      containers:
        - name: order-api
          image: myapp/order-api:1.4.3
          # ... (same as Deployment)

  strategy:
    canary:
      # Traffic shifting using the canary Service
      canaryService: order-api-canary
      stableService: order-api-stable

      steps:
        # Step 1: Send 5% of traffic to new version
        - setWeight: 5
        # Step 2: Pause for 5 minutes and run automated analysis
        - pause: {duration: 5m}
        # Step 3: Automated analysis — check error rate
        - analysis:
            templates:
              - templateName: success-rate
        # Step 4: If analysis passed, increase to 20%
        - setWeight: 20
        - pause: {duration: 10m}
        # Step 5: Increase to 50%
        - setWeight: 50
        - pause: {}              # Indefinite pause — requires manual promotion
        # Step 6: 100% (complete rollout)

      # AnalysisTemplate defines what metrics to check
      analysis:
        startingStep: 2          # Start analysis at step 2 (after first pause)

---
# AnalysisTemplate — defines success criteria for canary analysis
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate
  namespace: production
spec:
  metrics:
    - name: success-rate
      interval: 1m
      successCondition: result[0] >= 0.99
      failureLimit: 3
      provider:
        prometheus:
          address: http://kube-prometheus-stack-prometheus.monitoring:9090
          query: |
            sum(
              rate(http_requests_total{job="order-api",status!~"5.."}[5m])
            ) /
            sum(
              rate(http_requests_total{job="order-api"}[5m])
            )

    - name: error-rate
      interval: 1m
      successCondition: result[0] <= 0.01
      provider:
        prometheus:
          address: http://kube-prometheus-stack-prometheus.monitoring:9090
          query: |
            sum(rate(http_requests_total{job="order-api",status=~"5.."}[5m])) /
            sum(rate(http_requests_total{job="order-api"}[5m]))
```

```bash
# Monitor a rollout
kubectl argo rollouts get rollout order-api -n production --watch

# Promote a paused rollout to 100%
kubectl argo rollouts promote order-api -n production

# Abort and rollback
kubectl argo rollouts abort order-api -n production
kubectl argo rollouts undo order-api -n production
```

---

## 6. GitOps with Flux CD

### 6.1 Flux CD Installation

```bash
# Install Flux CLI
brew install fluxcd/tap/flux      # macOS
# or
curl -s https://fluxcd.io/install.sh | sudo bash

# Bootstrap Flux on the cluster (uses GitHub here)
flux bootstrap github \
  --owner=myorg \
  --repository=k8s-config \
  --branch=main \
  --path=clusters/production \
  --personal \
  --token-auth

# Flux creates and maintains a GitOps repository structure:
# clusters/production/
#   └── flux-system/
#       ├── gotk-components.yaml     ← Flux controllers
#       ├── gotk-sync.yaml           ← Sync configuration
#       └── kustomization.yaml
```

### 6.2 GitRepository and Kustomization Sources

```yaml
# clusters/production/order-api/gitrepository.yaml
# Defines the Git source Flux watches
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: k8s-config
  namespace: flux-system
spec:
  interval: 1m                   # Check for new commits every minute
  url: https://github.com/myorg/k8s-config
  ref:
    branch: main
  secretRef:
    name: git-credentials         # SSH key or token for private repos
  ignore: |
    # Ignore files that don't affect Kubernetes state
    *.md
    docs/
    .github/

---
# clusters/production/order-api/kustomization.yaml
# Tells Flux which path in the GitRepository to deploy
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: order-api-production
  namespace: flux-system
spec:
  interval: 5m                   # Re-apply every 5 minutes (self-healing)
  path: ./apps/order-api/overlays/production
  prune: true                    # Delete resources removed from Git
  sourceRef:
    kind: GitRepository
    name: k8s-config
  targetNamespace: production
  healthChecks:
    - apiVersion: apps/v1
      kind: Deployment
      name: order-api
      namespace: production
  timeout: 5m
  wait: true                     # Wait for health checks before marking complete
  postBuild:
    substitute:
      CLUSTER_NAME: production-eks
      REGION: us-east-1
    substituteFrom:
      - kind: ConfigMap
        name: cluster-vars
```

### 6.3 HelmRelease — Helm via Flux

```yaml
# clusters/production/infrastructure/helmrelease-prometheus.yaml
# Flux HelmRelease manages Helm charts in a GitOps way
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: kube-prometheus-stack
  namespace: monitoring
spec:
  interval: 1h                   # Re-reconcile every hour
  releaseName: kube-prometheus-stack
  chart:
    spec:
      chart: kube-prometheus-stack
      version: ">=60.0.0 <61.0.0"   # Semver range
      sourceRef:
        kind: HelmRepository
        name: prometheus-community
        namespace: flux-system
      interval: 12h              # Check for new chart versions every 12h

  # Values from inline or external sources
  values:
    prometheus:
      prometheusSpec:
        retention: 30d
        storageSpec:
          volumeClaimTemplate:
            spec:
              storageClassName: gp3
              resources:
                requests:
                  storage: 50Gi

  # Values from a Kubernetes Secret (for sensitive values)
  valuesFrom:
    - kind: Secret
      name: prometheus-additional-values
      valuesKey: values.yaml

  install:
    createNamespace: true
    remediation:
      retries: 3
  upgrade:
    remediation:
      retries: 3
      remediateLastFailure: true
    cleanupOnFail: true
  rollback:
    timeout: 5m
    cleanupOnFail: true

---
# HelmRepository — defines where to find Helm charts
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: prometheus-community
  namespace: flux-system
spec:
  interval: 12h
  url: https://prometheus-community.github.io/helm-charts
```

### 6.4 ImageUpdateAutomation — Automatic Image Updates

Flux's Image Automation is a unique capability: it watches a container registry for new image tags, updates the Git repository with the new tag, and lets GitOps reconciliation handle the deployment.

```yaml
# clusters/production/order-api/imagerepository.yaml
# Watch ACR for new tags of the order-api image
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImageRepository
metadata:
  name: order-api
  namespace: flux-system
spec:
  image: myregistry.azurecr.io/order-api
  interval: 5m
  secretRef:
    name: acr-credentials

---
# ImagePolicy — define which tags are acceptable
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImagePolicy
metadata:
  name: order-api
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: order-api
  policy:
    semver:
      range: ">=1.4.0 <2.0.0"   # Only 1.x.x releases

---
# ImageUpdateAutomation — write new tag to Git automatically
apiVersion: image.toolkit.fluxcd.io/v1beta1
kind: ImageUpdateAutomation
metadata:
  name: order-api-automation
  namespace: flux-system
spec:
  interval: 5m
  sourceRef:
    kind: GitRepository
    name: k8s-config
  git:
    checkout:
      ref:
        branch: main
    commit:
      author:
        email: flux@mycompany.com
        name: Flux Bot
      messageTemplate: |
        feat(auto): update order-api to {{ range .Updated.Images -}}
        {{ .NewTag }}
        {{- end }}
    push:
      branch: main
  update:
    strategy: Setters            # Updates YAML files with markers
    path: ./apps/order-api/overlays/production
```

```yaml
# apps/order-api/overlays/production/kustomization.yaml
# Image tag is updated by Flux automatically
images:
  - name: myregistry.azurecr.io/order-api
    newTag: 1.4.2 # {"$imagepolicy": "flux-system:order-api:tag"}
    # The comment above is the Flux "setter" marker
    # Flux will replace "1.4.2" with the latest tag from ImagePolicy
```

```bash
# Monitor Flux reconciliation
flux get all -n flux-system

# Watch image automation
flux get images all

# Force a reconciliation
flux reconcile kustomization order-api-production

# Get the diff of what Flux would apply
flux diff kustomization order-api-production

# Suspend reconciliation (during maintenance)
flux suspend kustomization order-api-production
flux resume kustomization order-api-production
```

---

## 7. Multi-Environment Promotion Workflow

### 7.1 The Promotion Pattern

```
Developer pushes feature branch
    │
    ▼
Pull Request → CI runs:
  ├── Unit tests
  ├── Integration tests
  ├── Helm chart lint + template validation
  ├── Trivy scan (block on CRITICAL)
  └── kubectl diff on staging overlay

PR merged to main
    │
    ▼
CI Pipeline:
  ├── Build container image
  ├── Push to registry with SHA tag: myapp:abc1234
  └── Open automated PR: "Update order-api dev to abc1234"
    │
    ▼ (Argo CD auto-sync OR Flux ImageUpdateAutomation)

Development namespace
  └── order-api:abc1234 deployed automatically
    │
    │ (automated smoke tests pass)
    ▼

Staging promotion PR (automated or manual):
  "Update order-api staging to abc1234"
  ├── Opened automatically by CI when dev smoke tests pass
  ├── Requires: 1 approval from platform team
  └── After merge → Argo CD auto-sync to staging
    │
    │ (staging integration tests pass)
    ▼

Production promotion PR (manual):
  "Release order-api v1.4.3 to production"
  ├── Tag created: git tag v1.4.3 && git push origin v1.4.3
  ├── Updates production overlay image tag to v1.4.3
  ├── Requires: 2 approvals (tech lead + on-call)
  └── After merge → Argo CD manual sync (or auto with sync window)
```

### 7.2 Promotion Automation Script

```bash
#!/usr/bin/env bash
# promote.sh — promote an image tag from one environment to another

set -euo pipefail

IMAGE_TAG=$1        # e.g. abc1234 or 1.4.3
FROM_ENV=$2         # e.g. staging
TO_ENV=$3           # e.g. production
REPO_DIR=${REPO_DIR:-/tmp/k8s-config}

# Clone the GitOps repo
git clone https://github.com/myorg/k8s-config $REPO_DIR
cd $REPO_DIR

# Create a promotion branch
BRANCH="promote-order-api-${IMAGE_TAG}-to-${TO_ENV}"
git checkout -b $BRANCH

# Update the image tag in the target overlay
# For Kustomize
sed -i "s|newTag: .*|newTag: \"${IMAGE_TAG}\"|" \
  apps/order-api/overlays/${TO_ENV}/kustomization.yaml

# For Helm values file
# yq e ".image.tag = \"${IMAGE_TAG}\"" -i \
#   apps/order-api/helm-values/${TO_ENV}-values.yaml

# Verify the change looks correct
kubectl kustomize apps/order-api/overlays/${TO_ENV} | \
  grep -A2 "image:"

# Commit and push
git add -A
git commit -m "feat(order-api): promote ${IMAGE_TAG} to ${TO_ENV}

Promoted from ${FROM_ENV} after successful smoke tests.
Image: myapp/order-api:${IMAGE_TAG}
Promoted-by: CI automation"

git push origin $BRANCH

# Open a Pull Request using GitHub CLI
gh pr create \
  --title "feat: promote order-api ${IMAGE_TAG} to ${TO_ENV}" \
  --body "## Promotion Details

**Image:** \`myapp/order-api:${IMAGE_TAG}\`
**From:** ${FROM_ENV}
**To:** ${TO_ENV}

### Checklist
- [ ] Smoke tests passed in ${FROM_ENV}
- [ ] No open severity:critical issues
- [ ] Runbook reviewed if this is a behaviour change

/cc @platform-team" \
  --base main \
  --head $BRANCH

cd / && rm -rf $REPO_DIR
```

---

## 8. Step-by-Step Hands-on Walkthrough

### 8.1 Full Pipeline: Helm Chart → OCI Registry → Argo CD

```bash
# Step 1: Create the chart
helm create order-api
cd order-api

# Step 2: Customise Chart.yaml and values.yaml (as in Section 3.1)

# Step 3: Lint the chart
helm lint .
helm lint . --values values-production.yaml

# Step 4: Run template rendering validation
helm template order-api . \
  --values values-production.yaml \
  | kubectl apply --dry-run=server -f -

# Step 5: Package
helm package . --version 1.4.2 --app-version "2.1.0"

# Step 6: Push to OCI registry
helm push order-api-1.4.2.tgz oci://ghcr.io/myorg/helm-charts
echo $?  # Should be 0

# Step 7: Create an Argo CD Application pointing at the OCI chart
kubectl apply -f - <<'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: order-api-production
  namespace: argocd
spec:
  project: default
  source:
    repoURL: oci://ghcr.io/myorg/helm-charts
    chart: order-api
    targetRevision: 1.4.2
    helm:
      releaseName: order-api
      values: |
        replicaCount: 5
        image:
          tag: "2.1.0"
        autoscaling:
          enabled: true
          minReplicas: 5
          maxReplicas: 20
        secrets:
          existingSecret: order-api-db-secret
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
EOF

# Step 8: Sync and verify
argocd app sync order-api-production
argocd app get order-api-production

# Step 9: Run Helm tests through Argo CD
argocd app run-job order-api-production --job test
```

### 8.2 Kustomize Multi-Environment Deploy

```bash
# Verify each overlay renders correctly
for env in development staging production; do
  echo "=== Rendering $env ==="
  kubectl kustomize k8s/overlays/$env | \
    grep -E "replicas:|image:|namespace:" | head -10
  echo ""
done

# Apply development
kubectl apply -k k8s/overlays/development
kubectl rollout status deployment/order-api -n development

# Diff staging before applying
kubectl diff -k k8s/overlays/staging

# Apply staging
kubectl apply -k k8s/overlays/staging
kubectl rollout status deployment/order-api -n staging

# Production — via PR + Argo CD sync (never direct kubectl apply)
```

---

## 9. Real-World Scenario: Platform Team Standardising 47 Services

### The Problem

ShipCo's platform team supports 12 engineering squads building 47 microservices. Each squad has developed their own deployment patterns: some use raw `kubectl apply`, some use Helm with inconsistent chart structures, some have hand-rolled Bash scripts. When a new security policy mandated that all Pods must run as non-root, the platform team estimated 3 weeks of work across all squads to update 47 different deployment configurations.

### The Solution

**Standardised Helm chart library:**

The platform team created an internal `base-service` Helm chart that all application charts extend via library chart pattern. Security context, resource limits, health probes, and network policies are enforced at the library level. Squads override only application-specific values.

```yaml
# Chart.yaml — application chart uses base-service as library
dependencies:
  - name: base-service
    version: "~2.0.0"
    repository: oci://myregistry.azurecr.io/platform-charts
    alias: base
```

**Kustomize for environment differences:**

Each service has a base Kustomize layer (maintained by the squad) and a `components/` layer (maintained by the platform team) that enforces PSA compliance, default NetworkPolicies, and Prometheus ServiceMonitors.

**Argo CD ApplicationSet with Git generator:**

```yaml
# One ApplicationSet generates 47 Applications automatically
# Any new service directory in k8s-config/apps/ is auto-deployed
generators:
  - git:
      repoURL: https://github.com/myorg/k8s-config
      directories:
        - path: apps/*/overlays/production
```

**The security update:**

When the non-root mandate was issued, the platform team updated the `base-service` chart's security context template once. All 47 services inherited the change on their next Helm upgrade — triggered automatically by Flux HelmRelease version bumping from the chart registry.

### Results

| Metric | Before | After |
|---|---|---|
| Time to enforce security policy across 47 services | 3 weeks (estimated) | 4 hours (chart update + Flux reconcile) |
| Time to onboard a new service | 2-3 days (copy-paste existing configs) | 45 minutes (scaffold from base chart) |
| Deployment configuration drift | Common (no enforcement) | None (Argo CD self-healing) |
| Rollback time on bad deployment | 15-30 min (find old config, re-apply) | 90 seconds (`argocd app rollback`) |
| PRs for production deploys per week | 0 (push-based, no review) | 47 (one per service, reviewed) |

---

## 10. Common Pitfalls & Best Practices

### Pitfall 1: Helm Values Containing Secrets
Storing passwords, API keys, or TLS certificates in Helm values files means they end up in `helm get values <release>` output, in CI logs, and potentially in Git history. Use `secrets.existingSecret` patterns that reference pre-existing Kubernetes Secrets (managed by Vault, Sealed Secrets, or ESO). Never pass secrets via `--set password=plaintext` in CI pipelines.

### Pitfall 2: Editing Cluster State Outside GitOps
When engineers `kubectl apply` directly to a production cluster managed by Argo CD or Flux, their changes are reverted within minutes by the GitOps reconciler — and worse, they leave no audit trail. Enable `selfHeal: true` in Argo CD and configure it to alert when out-of-sync state is detected. Document clearly that Git is the only write path to production.

### Pitfall 3: Using Argo CD `selfHeal: true` Without `ignoreDifferences`
The HPA controller constantly updates `status.currentReplicas` on Deployments; cert-manager updates certificate secrets; the Cluster Autoscaler modifies replica counts. Without `ignoreDifferences`, Argo CD will fight these controllers — reverting their changes every 3 minutes. Configure `ignoreDifferences` for all fields managed by in-cluster controllers.

### Pitfall 4: Kustomize `images:` Transformer vs `patchesStrategicMerge` for Image Tags
Using `patchesStrategicMerge` to change image tags requires a separate patch file per environment. The `images:` transformer in `kustomization.yaml` changes image tags across all matching resources in one line and is the correct tool for this purpose. Use `images:` for version tracking; use patches for structural resource changes.

### Pitfall 5: Argo CD ApplicationSet With No Sync Windows in Production
ApplicationSets with `automated.selfHeal: true` deployed to production with no sync window will apply Git changes at any time of day, including 3 AM. A developer merging a configuration change at midnight will trigger an immediate production deployment. Configure Argo CD sync windows to restrict automated syncs to business hours; keep manual sync available for emergency fixes.

### Pitfall 6: Forgetting `helm dependency update` Before CI Builds
Charts with external dependencies listed in `Chart.yaml` require running `helm dependency update` to download the sub-charts to the `charts/` directory before packaging. CI pipelines that `helm package` without running dependency update will produce a broken chart. Always run `helm dependency update` as the first step in the chart build pipeline.

> **Packaging and Deployment Production Readiness Checklist**
> - [ ] Helm chart passes `helm lint --strict` with no warnings
> - [ ] Chart templates validate against Kubernetes API via `helm template | kubectl apply --dry-run=server`
> - [ ] `values.yaml` documents every configurable field with a comment
> - [ ] Charts use `existingSecret` pattern — no secrets in values files
> - [ ] Helm hooks use `hook-delete-policy: before-hook-creation,hook-succeeded`
> - [ ] Chart tests defined and passing with `helm test`
> - [ ] Charts pushed to OCI registry with semantic versioning
> - [ ] Kustomize base uses no environment-specific values
> - [ ] All overlays pass `kubectl kustomize | kubectl apply --dry-run=server`
> - [ ] Argo CD / Flux installed with HA replicas (≥2) in the cluster
> - [ ] `ignoreDifferences` configured for HPA, cert-manager, and Cluster Autoscaler fields
> - [ ] Production Applications require manual sync or approved PRs (no fully automated production deploys)
> - [ ] Sync windows configured to prevent off-hours automated production deployments
> - [ ] Promotion workflow documented and scripted

---

## 11. Key Takeaways

1. **Helm and Kustomize are complementary, not competing.** Helm excels at packaging versioned, distributable, parameterised applications — especially third-party software. Kustomize excels at managing environment-specific overlays on top of a DRY base. The most mature platforms use Helm for external dependencies and Kustomize for internal application configuration, often layering them.

2. **The Helm chart API is its `values.yaml`.** A well-designed `values.yaml` hides Kubernetes complexity behind a clean, documented configuration surface. Engineers consuming the chart should not need to know Kubernetes to use it; they interact with named, documented values. Treat backward compatibility of `values.yaml` keys as seriously as an API contract.

3. **GitOps eliminates the "cluster as a snowflake" problem.** Every cluster state change is a Git commit — reviewed, timestamped, and authored. Drift is detected and corrected within minutes. Rollback is `git revert` followed by automatic reconciliation. The cluster always reflects what is in Git; there is no hidden state.

4. **Argo CD and Flux solve the same GitOps problem with different UX philosophies.** Argo CD provides a rich visual UI and a centralised application management model — excellent for teams that deploy to many clusters from one control point. Flux is fully CLI-native and Kubernetes CRD-native, with unique image automation capabilities. Both are production-grade; choose based on your team's workflow preferences.

5. **Progressive delivery with Argo Rollouts adds the safety net that `RollingUpdate` cannot provide.** `RollingUpdate` replaces Pods but cannot shift traffic weights or run automated analysis before proceeding. Argo Rollouts canary deployments send a small percentage of traffic to the new version, run PromQL-backed analysis checks, and only proceed to 100% if the checks pass — turning a binary deploy/rollback decision into a data-driven process.

6. **Multi-environment promotion workflows belong in Git, not in CI pipeline scripts.** When environment configuration is in CI variables and shell scripts, it is invisible to reviewers, undiffable, and hard to audit. When it is in Git as Kustomize overlays or Helm values files, every environment change is a pull request — reviewed, approved, and tracked.

---

## 12. Exercises & Labs

**Exercise 1: Helm Chart from Scratch**
Create a Helm chart for a three-tier application (frontend, API, database). The chart must include: a `_helpers.tpl` with `fullname`, `labels`, and `selectorLabels` named templates; conditional HPA (`autoscaling.enabled`); a pre-upgrade migration hook with `hook-delete-policy`; a chart test that verifies the health endpoint; and a `values.yaml` with every field documented. Lint the chart with `helm lint --strict` and validate against the Kubernetes API with `helm template | kubectl apply --dry-run=server`.

**Exercise 2: Kustomize Multi-Environment**
Build a Kustomize configuration for the same application with three overlays: dev (1 replica, debug logging, in-cluster PostgreSQL via sub-chart), staging (3 replicas, info logging, shared database), and production (5 replicas, info logging, HPA, PDB, PodAntiAffinity, and topology spread constraints). Apply each overlay to separate namespaces on a local cluster. Verify the differences by running `kubectl get deployment -o yaml` and comparing resource fields between environments.

**Exercise 3: Argo CD GitOps Workflow**
Install Argo CD on a test cluster. Create an Application pointing at your Kustomize overlays repository. Verify auto-sync by pushing a change to the Git repository and watching Argo CD detect and apply it within 3 minutes. Then manually edit a Kubernetes resource directly with `kubectl` and verify that Argo CD detects and reverts the drift within the sync interval. Configure `ignoreDifferences` for the HPA replica count field.

**Exercise 4: Flux Image Automation**
Install Flux CD on a cluster. Create an `ImageRepository` watching a container registry you control. Create an `ImagePolicy` with a semver range. Push a new image tag that satisfies the policy. Observe Flux create a Git commit updating the image tag in your Kustomize overlay. Then trigger a Flux reconciliation and observe the deployment update. Check the Git commit history to see the automated commit message.

**Exercise 5: Argo Rollouts Canary Deployment**
Install Argo Rollouts. Convert a Deployment to a Rollout with a 5-step canary strategy: 10% → pause 2 min → Prometheus analysis (error rate <1%) → 50% → pause (manual) → 100%. Deploy version 1.0.0. Then upgrade to 1.1.0 and watch the canary steps proceed. Simulate a failure by artificially increasing the error rate past 1% and observe the Rollout automatically abort and roll back.

---

*End of Chapter 11*

**Next → Chapter 12: Continuous Development and Continuous Deployment**



---

──────────────────────────────────────────────────────────────────────

## Part XII: Continuous Development and Continuous Deployment

> *GitHub Actions · Jenkins X · Security Gates · Argo Rollouts*

──────────────────────────────────────────────────────────────────────


## 1. Introduction & Learning Objectives

Continuous Integration and Continuous Deployment are the operational heartbeat of any high-performing engineering organisation. In the Kubernetes world, CI/CD is not just about automating `kubectl apply` — it is about building a complete delivery system that takes code from a developer's laptop to production with confidence, speed, and auditability. Every pipeline stage is a quality gate; every gate that passes is an assertion that the software is safe to move to the next environment.

The modern Kubernetes CI/CD pipeline must do far more than compile code and push images. It must prove the software is correct (unit and integration tests), prove it is secure (SAST, dependency scanning, image scanning), prove it meets operational requirements (resource limits, security contexts, policy compliance), and then deploy it in a way that allows early detection of regressions before the full user base is affected (canary deployments, traffic shifting, automated analysis).

This chapter builds three complete, production-grade CI/CD systems — one with GitHub Actions (the most widely used developer-facing CI platform), one with Jenkins X (the Kubernetes-native GitOps CI/CD platform), and one revisiting the Azure DevOps pipeline from Chapter 6 with deeper coverage of multi-stage deployment strategies. We then deep-dive progressive delivery patterns using Argo Rollouts: canary with automated analysis, blue/green with manual promotion gates, and traffic mirroring for zero-risk validation.

> **Learning Objectives**
> - Design a CI/CD pipeline that separates concerns cleanly across build, test, scan, publish, and deploy stages.
> - Build a production-grade GitHub Actions workflow with reusable workflows, composite actions, and OIDC authentication.
> - Implement a Jenkins X pipeline with Tekton-based build packs and automated environment promotion.
> - Integrate security scanning gates: SAST with CodeQL, dependency scanning with Dependabot and Snyk, image scanning with Trivy, and Kubernetes manifest validation with Polaris.
> - Implement automated test stages: unit, integration with testcontainers, and post-deploy smoke tests.
> - Design canary and blue/green deployment strategies using Argo Rollouts with Prometheus-based automated analysis.
> - Configure traffic mirroring (shadow mode) for zero-risk production validation.
> - Build a complete end-to-end pipeline from `git push` to production with every quality gate instrumented and observable.

---

## 2. Core Concepts

### 2.1 CI/CD Pipeline Architecture for Kubernetes

A well-designed Kubernetes CI/CD pipeline has a clear separation of concerns across three domains: **CI** (build, test, scan, publish), **CD** (deploy to environments, run post-deploy tests), and **delivery** (control how traffic reaches the new version).

```
┌──────────────────────────────────────────────────────────────────────────┐
│  CONTINUOUS INTEGRATION              CONTINUOUS DEPLOYMENT               │
│  (triggered by git push)             (triggered by CI success)           │
│                                                                           │
│  ┌─────────────────────────────┐    ┌────────────────────────────────┐  │
│  │  1. Source                  │    │  4. Deploy — Development        │  │
│  │     Checkout, lint, SAST    │    │     kubectl / Argo CD / Flux    │  │
│  │     dependency audit        │    │     Smoke tests                 │  │
│  │                             │    │                                  │  │
│  │  2. Build                   │    │  5. Deploy — Staging            │  │
│  │     Docker multi-stage      │    │     Integration tests           │  │
│  │     Layer cache optimisation│    │     Performance baseline        │  │
│  │                             │    │                                  │  │
│  │  3. Verify                  │    │  6. Deploy — Production         │  │
│  │     Unit tests              │    │     Progressive delivery        │  │
│  │     Integration tests       │    │     ┌── Canary (5%→20%→100%)  │  │
│  │     Image scan (Trivy)      │    │     ├── Blue/Green (instant)   │  │
│  │     SBOM generation         │    │     └── Traffic mirror          │  │
│  │     Manifest validation     │    │     Automated analysis          │  │
│  │     Push to registry        │    │     Rollback on failure         │  │
│  └─────────────────────────────┘    └────────────────────────────────┘  │
│                                                                           │
│  QUALITY GATES (each gate is a pass/fail assertion)                      │
│  ─────────────────────────────────────────────────────────────────────   │
│  ✓ All tests pass    ✓ No CRITICAL CVEs    ✓ Policy compliant            │
│  ✓ Coverage >80%     ✓ No secrets in code  ✓ Signed image                │
│  ✓ Lint clean        ✓ SBOM generated      ✓ Canary analysis pass        │
└──────────────────────────────────────────────────────────────────────────┘
```

#### The Twelve Principles of Kubernetes CI/CD

1. **Immutable artifacts** — build once, deploy the same binary everywhere. No environment-specific builds.
2. **Fail fast** — cheap gates (lint, compile) run first; expensive gates (integration, scan) run after.
3. **Every pipeline run is reproducible** — pinned tool versions, hermetic builds, no network calls during tests.
4. **Security is not a final gate** — scanning runs in the inner loop (on every PR), not just before release.
5. **Test coverage is a first-class metric** — coverage gates block merges, not just report.
6. **Images are signed** — every production image has a cryptographic attestation.
7. **No `latest` tags** — every image reference in manifests is an immutable tag or digest.
8. **GitOps for deployment** — pipelines write to Git; agents deploy from Git.
9. **Every deployment is observable** — Prometheus metrics gate progressive delivery.
10. **Every deployment is reversible** — rollback takes under 2 minutes.
11. **Secrets never appear in logs or environment variables** — use OIDC, Workload Identity, or mounted files.
12. **Pipeline configuration is code** — pipeline YAML lives in the same repo as the application code.

---

### 2.2 Progressive Delivery Strategies

Before building the pipelines, we must be precise about the deployment strategies they implement.

```
Strategy         Traffic distribution     Rollback speed    Complexity
─────────────────────────────────────────────────────────────────────────
Recreate         0% → 100% (hard switch)  Full redeploy      Low
                 ↳ Downtime during switch
                 ↳ Use only for breaking changes in dev

RollingUpdate    Old Pods replaced        kubectl rollout    Low
                 incrementally            undo (seconds)
                 ↳ Default K8s strategy
                 ↳ No traffic control

Blue/Green       100% blue → 100% green   Service selector   Medium
                 (instant cutover)        flip (seconds)
                 ↳ Need 2x resources
                 ↳ Instant rollback

Canary           5% → 20% → 50% → 100%   Weight back to 0   Medium
                 (gradual traffic shift)  (seconds)
                 ↳ Real traffic validation
                 ↳ Automated Prometheus analysis

Traffic Mirror   100% to stable           N/A — mirror only  High
                 + shadow copy to canary  no rollback needed
                 ↳ Zero-risk validation
                 ↳ Canary gets real requests, responses ignored
```

---

### 2.3 Argo Rollouts Architecture

Argo Rollouts replaces the Kubernetes Deployment resource with a `Rollout` resource that understands traffic shifting, progressive delivery, and automated metric analysis.

```
┌──────────────────────────────────────────────────────────────────────┐
│  Argo Rollouts Controller                                             │
│                                                                       │
│  Rollout resource → manages:                                          │
│  ├── ReplicaSet (stable)    ← current version, receives most traffic  │
│  ├── ReplicaSet (canary)    ← new version, receives canary traffic    │
│  │                                                                    │
│  └── Traffic management:                                              │
│       ├── Weighted Services (native K8s, coarse-grained)             │
│       ├── NGINX Ingress annotations                                   │
│       ├── Istio VirtualService (precise % splitting)                 │
│       ├── AWS Load Balancer Controller (ALB weighted target groups)  │
│       └── Gateway API (SMI-compatible)                               │
│                                                                       │
│  AnalysisRun → evaluates:                                             │
│  ├── Prometheus queries (error rate, latency, business metrics)      │
│  ├── Datadog metrics                                                  │
│  ├── CloudWatch metrics                                              │
│  ├── Web hook checks (external validation services)                  │
│  └── Job-based analysis (custom scripts)                             │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 3. GitHub Actions — Complete CI/CD Pipeline

### 3.1 Repository Structure

```
.github/
├── workflows/
│   ├── ci.yml                    ← Main CI pipeline (PR + main branch)
│   ├── cd-staging.yml            ← Deploy to staging on main merge
│   ├── cd-production.yml         ← Deploy to production (manual trigger)
│   ├── security-scan.yml         ← Scheduled security scans
│   └── dependency-update.yml     ← Auto dependency PRs
├── actions/
│   ├── build-push/
│   │   └── action.yml            ← Composite action: build + push image
│   ├── helm-deploy/
│   │   └── action.yml            ← Composite action: helm upgrade
│   └── smoke-test/
│       └── action.yml            ← Composite action: run smoke tests
└── CODEOWNERS                    ← Require platform team approval for pipeline changes
```

### 3.2 Reusable Workflow — Build and Scan

```yaml
# .github/workflows/ci.yml
name: CI Pipeline

on:
  push:
    branches: [main, 'release/**']
  pull_request:
    branches: [main]
  workflow_dispatch:

# Cancel in-progress runs when a newer commit is pushed
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository_owner }}/order-api
  NODE_VERSION: "20"
  HELM_VERSION: "3.15.0"

jobs:
  # ────────────────────────────────────────────────────────────────────
  # Job 1: Lint and Static Analysis
  # Fast — runs in parallel with nothing, blocks everything else
  # ────────────────────────────────────────────────────────────────────
  lint-and-sast:
    name: Lint and Static Analysis
    runs-on: ubuntu-latest
    timeout-minutes: 10
    permissions:
      security-events: write    # For uploading SARIF to GitHub Security
      contents: read
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0          # Full history for better diff analysis

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: npm

      - name: Install dependencies
        run: npm ci

      - name: Lint (ESLint)
        run: npm run lint -- --format=@microsoft/eslint-formatter-sarif \
               --output-file eslint-results.sarif
        continue-on-error: true

      - name: Upload ESLint SARIF
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: eslint-results.sarif
          category: eslint

      - name: CodeQL Analysis (SAST)
        uses: github/codeql-action/init@v3
        with:
          languages: javascript
          queries: security-and-quality

      - name: Perform CodeQL Analysis
        uses: github/codeql-action/analyze@v3
        with:
          category: codeql-javascript
          upload: true

      - name: Gitleaks — Secret Scanning
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          GITLEAKS_LICENSE: ${{ secrets.GITLEAKS_LICENSE }}

      - name: Validate Kubernetes manifests (Helm template + Polaris)
        run: |
          # Install tools
          curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
            | DESIRED_VERSION=v${HELM_VERSION} bash
          curl -fsSL https://github.com/FairwindsOps/polaris/releases/latest/download/polaris_linux_amd64.tar.gz \
            | tar xz && mv polaris /usr/local/bin/

          # Render Helm templates for all environments
          for env in development staging production; do
            echo "=== Validating $env ==="
            helm template order-api ./helm/order-api \
              --values ./helm/order-api/values.yaml \
              --values ./helm/order-api/values-${env}.yaml \
              | polaris audit \
                  --audit-path /dev/stdin \
                  --format score \
                  --set-exit-code-below-score 75
          done

  # ────────────────────────────────────────────────────────────────────
  # Job 2: Unit Tests with Coverage
  # ────────────────────────────────────────────────────────────────────
  unit-tests:
    name: Unit Tests
    runs-on: ubuntu-latest
    timeout-minutes: 15
    needs: lint-and-sast
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: npm

      - name: Install dependencies
        run: npm ci

      - name: Run unit tests with coverage
        run: |
          npm run test:unit -- \
            --coverage \
            --coverageReporters=lcov \
            --coverageReporters=json-summary \
            --forceExit
        env:
          NODE_ENV: test

      - name: Coverage gate (minimum 80%)
        run: |
          COVERAGE=$(cat coverage/coverage-summary.json | \
            jq '.total.lines.pct')
          echo "Line coverage: ${COVERAGE}%"
          if (( $(echo "$COVERAGE < 80" | bc -l) )); then
            echo "::error::Coverage ${COVERAGE}% is below the 80% threshold"
            exit 1
          fi

      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v4
        with:
          files: ./coverage/lcov.info
          fail_ci_if_error: true
          token: ${{ secrets.CODECOV_TOKEN }}

      - name: Publish test results
        uses: dorny/test-reporter@v1
        if: always()
        with:
          name: Unit Test Results
          path: test-results/junit.xml
          reporter: jest-junit

  # ────────────────────────────────────────────────────────────────────
  # Job 3: Integration Tests (with testcontainers)
  # ────────────────────────────────────────────────────────────────────
  integration-tests:
    name: Integration Tests
    runs-on: ubuntu-latest
    timeout-minutes: 20
    needs: unit-tests
    services:
      # GitHub Actions services run as Docker containers alongside the job
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_DB: orders_test
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: testpassword
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
      redis:
        image: redis:7-alpine
        ports:
          - 6379:6379
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-retries 5

    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: npm

      - name: Install dependencies
        run: npm ci

      - name: Run database migrations
        run: npm run migrate:up
        env:
          DATABASE_URL: postgresql://postgres:testpassword@localhost:5432/orders_test

      - name: Run integration tests
        run: npm run test:integration
        env:
          DATABASE_URL: postgresql://postgres:testpassword@localhost:5432/orders_test
          REDIS_URL: redis://localhost:6379
          NODE_ENV: test

      - name: Publish integration test results
        uses: dorny/test-reporter@v1
        if: always()
        with:
          name: Integration Test Results
          path: test-results/integration-junit.xml
          reporter: jest-junit

  # ────────────────────────────────────────────────────────────────────
  # Job 4: Build and Push Container Image
  # Only runs on push to main or release branches
  # ────────────────────────────────────────────────────────────────────
  build-and-push:
    name: Build and Push Image
    runs-on: ubuntu-latest
    timeout-minutes: 20
    needs: integration-tests
    if: github.event_name == 'push'
    permissions:
      contents: read
      packages: write
      id-token: write       # Required for OIDC (keyless signing)
      security-events: write
    outputs:
      image-digest: ${{ steps.build.outputs.digest }}
      image-tag: ${{ steps.meta.outputs.version }}
      full-image: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ steps.meta.outputs.version }}

    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3
        with:
          install: true

      - name: Log in to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract image metadata (tags, labels)
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            # Tag with short commit SHA (always)
            type=sha,prefix=,format=short
            # Tag with branch name (sanitised)
            type=ref,event=branch
            # Tag with semantic version if pushed as tag
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
          labels: |
            org.opencontainers.image.title=Order API
            org.opencontainers.image.vendor=MyCompany
            org.opencontainers.image.source=${{ github.server_url }}/${{ github.repository }}

      - name: Build and push image
        id: build
        uses: docker/build-push-action@v5
        with:
          context: .
          file: Dockerfile
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: |
            type=registry,ref=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:cache
            type=registry,ref=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:main
          cache-to: type=registry,ref=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:cache,mode=max
          # Multi-platform build
          platforms: linux/amd64,linux/arm64
          provenance: true         # Generate SLSA provenance attestation
          sbom: true               # Generate SBOM attestation

      - name: Scan image with Trivy
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}@${{ steps.build.outputs.digest }}
          format: sarif
          output: trivy-results.sarif
          severity: CRITICAL,HIGH
          exit-code: 1
          ignore-unfixed: true

      - name: Upload Trivy scan results
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: trivy-results.sarif
          category: trivy

      - name: Sign image with Cosign (keyless OIDC)
        uses: sigstore/cosign-installer@v3

      - name: Sign and attest the image
        run: |
          # Sign the image (keyless, using GitHub OIDC)
          cosign sign \
            --yes \
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}@${{ steps.build.outputs.digest }}

          # Attach the Trivy vulnerability scan as an attestation
          cosign attest \
            --yes \
            --predicate trivy-results.sarif \
            --type vuln \
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}@${{ steps.build.outputs.digest }}

      - name: Verify the signature
        run: |
          cosign verify \
            --certificate-identity-regexp="https://github.com/${{ github.repository }}/*" \
            --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}@${{ steps.build.outputs.digest }}

  # ────────────────────────────────────────────────────────────────────
  # Job 5: Dependency Audit
  # Runs in parallel with integration tests
  # ────────────────────────────────────────────────────────────────────
  dependency-audit:
    name: Dependency Audit
    runs-on: ubuntu-latest
    timeout-minutes: 10
    needs: lint-and-sast
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: npm

      - name: npm audit (block on high/critical)
        run: npm audit --audit-level=high

      - name: Snyk dependency scan
        uses: snyk/actions/node@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
        with:
          args: --severity-threshold=high --fail-on=all

      - name: License compliance check
        run: |
          npx license-checker \
            --production \
            --excludePrivatePackages \
            --failOn "GPL-2.0;GPL-3.0;AGPL-3.0"  # Block copyleft licenses
```

### 3.3 CD Workflow — Staging Deploy

```yaml
# .github/workflows/cd-staging.yml
name: CD — Staging Deployment

on:
  workflow_run:
    workflows: ["CI Pipeline"]
    types: [completed]
    branches: [main]

jobs:
  deploy-staging:
    name: Deploy to Staging
    runs-on: ubuntu-latest
    timeout-minutes: 15
    if: ${{ github.event.workflow_run.conclusion == 'success' }}
    environment:
      name: staging
      url: https://staging.api.mycompany.com

    permissions:
      contents: read
      id-token: write     # OIDC for cloud authentication

    steps:
      - uses: actions/checkout@v4

      - name: Download CI artifacts (image digest)
        uses: actions/download-artifact@v4
        with:
          name: image-metadata
          github-token: ${{ secrets.GITHUB_TOKEN }}
          run-id: ${{ github.event.workflow_run.id }}

      - name: Read image digest
        id: image
        run: |
          DIGEST=$(cat image-digest.txt)
          TAG=$(cat image-tag.txt)
          echo "digest=$DIGEST" >> $GITHUB_OUTPUT
          echo "tag=$TAG" >> $GITHUB_OUTPUT

      # Authenticate to cloud using OIDC — no stored credentials
      - name: Configure AWS credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789:role/github-actions-staging
          aws-region: us-east-1

      - name: Update kubeconfig for staging EKS
        run: |
          aws eks update-kubeconfig \
            --name staging-eks \
            --region us-east-1

      - name: Install Helm
        uses: azure/setup-helm@v4
        with:
          version: ${{ env.HELM_VERSION }}

      - name: Helm upgrade (staging)
        run: |
          helm upgrade --install order-api \
            oci://ghcr.io/${{ github.repository_owner }}/helm-charts/order-api \
            --version 1.4.2 \
            --namespace staging \
            --create-namespace \
            --values helm/order-api/values.yaml \
            --values helm/order-api/values-staging.yaml \
            --set image.repository=ghcr.io/${{ env.IMAGE_NAME }} \
            --set image.digest=${{ steps.image.outputs.digest }} \
            --set image.tag="" \
            --wait \
            --timeout 5m \
            --atomic \
            --history-max 5

      - name: Run smoke tests
        run: |
          # Wait for Ingress to be ready
          kubectl wait ingress/order-api \
            --for=jsonpath='{.status.loadBalancer.ingress[0].hostname}' \
            --namespace staging \
            --timeout=120s

          STAGING_URL=$(kubectl get ingress order-api \
            -n staging \
            -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

          # Run smoke test suite
          SMOKE_BASE_URL="https://${STAGING_URL}" npm run test:smoke

      - name: Post deployment summary
        if: always()
        run: |
          echo "## Staging Deployment Summary" >> $GITHUB_STEP_SUMMARY
          echo "| Field | Value |" >> $GITHUB_STEP_SUMMARY
          echo "|-------|-------|" >> $GITHUB_STEP_SUMMARY
          echo "| Image | \`${{ steps.image.outputs.tag }}\` |" >> $GITHUB_STEP_SUMMARY
          echo "| Digest | \`${{ steps.image.outputs.digest }}\` |" >> $GITHUB_STEP_SUMMARY
          echo "| Environment | staging |" >> $GITHUB_STEP_SUMMARY
          echo "| Status | ${{ job.status }} |" >> $GITHUB_STEP_SUMMARY
```

### 3.4 CD Workflow — Production with Progressive Delivery

```yaml
# .github/workflows/cd-production.yml
name: CD — Production Deployment

on:
  workflow_dispatch:
    inputs:
      image_tag:
        description: "Image tag to deploy (from CI pipeline)"
        required: true
        type: string
      deployment_strategy:
        description: "Deployment strategy"
        required: true
        type: choice
        options: [canary, blue-green, rolling]
        default: canary
      canary_steps:
        description: "Comma-separated canary weights (e.g. 5,20,50,100)"
        required: false
        default: "5,20,50,100"

jobs:
  deploy-production:
    name: Deploy to Production
    runs-on: ubuntu-latest
    timeout-minutes: 30
    environment:
      name: production
      url: https://api.mycompany.com
    # Requires 2 approvals (configured in GitHub Environment settings)

    permissions:
      contents: read
      id-token: write

    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789:role/github-actions-production
          aws-region: us-east-1

      - name: Update kubeconfig for production EKS
        run: |
          aws eks update-kubeconfig \
            --name production-eks \
            --region us-east-1

      - name: Verify image signature before production deploy
        run: |
          cosign verify \
            --certificate-identity-regexp="https://github.com/${{ github.repository }}/*" \
            --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
            ghcr.io/${{ env.IMAGE_NAME }}:${{ inputs.image_tag }}
          echo "Image signature verified ✓"

      - name: Install kubectl-argo-rollouts plugin
        run: |
          curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64
          chmod +x kubectl-argo-rollouts-linux-amd64
          sudo mv kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts

      - name: Deploy with canary strategy (Argo Rollouts)
        if: inputs.deployment_strategy == 'canary'
        run: |
          # Update the Rollout image
          kubectl argo rollouts set image order-api \
            order-api=ghcr.io/${{ env.IMAGE_NAME }}:${{ inputs.image_tag }} \
            -n production

          # Watch the rollout progress
          kubectl argo rollouts status order-api \
            -n production \
            --timeout 20m

      - name: Deploy with blue/green strategy
        if: inputs.deployment_strategy == 'blue-green'
        run: |
          kubectl argo rollouts set image order-api \
            order-api=ghcr.io/${{ env.IMAGE_NAME }}:${{ inputs.image_tag }} \
            -n production

          # Wait for preview environment to be ready
          kubectl argo rollouts status order-api \
            -n production \
            --timeout 10m

          echo "Blue/green preview ready. Awaiting manual promotion..."
          echo "Promote with: kubectl argo rollouts promote order-api -n production"

      - name: Post-deploy health verification
        run: |
          # Wait for all Pods to be ready
          kubectl rollout status deployment/order-api \
            -n production \
            --timeout 10m 2>/dev/null || \
          kubectl argo rollouts status order-api \
            -n production \
            --timeout 10m

          # Verify metrics are healthy post-deploy
          PROD_URL="https://api.mycompany.com"

          # Check health endpoint
          HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
            --retry 5 --retry-delay 10 \
            "${PROD_URL}/health/ready")

          if [ "$HTTP_STATUS" != "200" ]; then
            echo "::error::Health check failed with status $HTTP_STATUS"
            exit 1
          fi

      - name: Create GitHub Release
        if: success()
        uses: actions/create-release@v1
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        with:
          tag_name: ${{ inputs.image_tag }}
          release_name: "Release ${{ inputs.image_tag }}"
          body: |
            ## Deployment Summary
            - **Image:** `ghcr.io/${{ env.IMAGE_NAME }}:${{ inputs.image_tag }}`
            - **Strategy:** ${{ inputs.deployment_strategy }}
            - **Deployed by:** @${{ github.actor }}
            - **Deployed at:** ${{ github.event.head_commit.timestamp }}
          draft: false
          prerelease: false

      - name: Notify on failure
        if: failure()
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": ":rotating_light: Production deployment failed!",
              "attachments": [{
                "color": "danger",
                "fields": [
                  {"title": "Image", "value": "${{ inputs.image_tag }}", "short": true},
                  {"title": "Actor", "value": "${{ github.actor }}", "short": true},
                  {"title": "Run URL", "value": "${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}"}
                ]
              }]
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

### 3.5 Composite Action — Build and Push

```yaml
# .github/actions/build-push/action.yml
# Reusable composite action for building and pushing images
# Used across multiple workflows to avoid duplication

name: Build and Push Container Image
description: Builds a Docker image with caching and pushes to registry

inputs:
  image-name:
    description: Full image name (e.g. ghcr.io/myorg/myapp)
    required: true
  dockerfile:
    description: Path to Dockerfile
    default: Dockerfile
  context:
    description: Docker build context
    default: .
  push:
    description: Whether to push the image
    default: 'true'
  registry-username:
    description: Registry username
    required: true
  registry-password:
    description: Registry password or token
    required: true

outputs:
  digest:
    description: Image digest
    value: ${{ steps.build.outputs.digest }}
  tags:
    description: Image tags
    value: ${{ steps.meta.outputs.tags }}

runs:
  using: composite
  steps:
    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v3
      with:
        install: true

    - name: Login to registry
      uses: docker/login-action@v3
      with:
        registry: ${{ fromJSON(inputs.image-name).registry || 'docker.io' }}
        username: ${{ inputs.registry-username }}
        password: ${{ inputs.registry-password }}

    - name: Extract metadata
      id: meta
      uses: docker/metadata-action@v5
      with:
        images: ${{ inputs.image-name }}
        tags: |
          type=sha,prefix=,format=short
          type=ref,event=branch
          type=semver,pattern={{version}}

    - name: Build and push
      id: build
      uses: docker/build-push-action@v5
      with:
        context: ${{ inputs.context }}
        file: ${{ inputs.dockerfile }}
        push: ${{ inputs.push }}
        tags: ${{ steps.meta.outputs.tags }}
        labels: ${{ steps.meta.outputs.labels }}
        cache-from: type=registry,ref=${{ inputs.image-name }}:cache
        cache-to: type=registry,ref=${{ inputs.image-name }}:cache,mode=max
        platforms: linux/amd64,linux/arm64
        provenance: true
        sbom: true
```

---

## 4. Jenkins X — Kubernetes-Native CI/CD

### 4.1 Jenkins X Architecture

Jenkins X is a cloud-native CI/CD platform built entirely on Kubernetes. Unlike traditional Jenkins, it uses **Tekton** as the pipeline execution engine, **Argo CD** or **Flux** for GitOps, and **Lighthouse** for Git webhook handling.

```
Developer pushes code
    │
    ▼
Lighthouse (webhook handler)
    │ Creates PipelineRun
    ▼
Tekton Pipeline (runs in Kubernetes as Pods)
    ├── clone-source     (git clone)
    ├── run-tests        (npm test)
    ├── build-image      (kaniko — no Docker daemon)
    ├── scan-image       (trivy)
    ├── push-image       (to registry)
    └── promote          (PR to environment repo)
    │
    ▼
Environment Repository (GitOps repo)
    │ Pull Request opened/merged
    ▼
Argo CD / Flux (reconciles cluster to Git state)
    │
    ▼
Kubernetes Cluster
    └── Application deployed
```

### 4.2 Jenkins X Installation

```bash
# Install jx CLI
brew tap jenkins-x/jx
brew install jx

# Install Jenkins X on an existing Kubernetes cluster
# Jenkins X uses a GitOps approach — all config stored in Git
jx operator install

# Or bootstrap Jenkins X with a new Git repository
jx project create \
  --git-provider-url=https://github.com \
  --git-owner=myorg \
  --git-repo-name=jx-cluster-config \
  --env-git-owner=myorg \
  --cluster my-eks-cluster \
  --domain mycompany.com

# Create a new application with build pack
jx project create \
  --pack=javascript \
  --name=order-api \
  --org=myorg

# Jenkins X creates:
# - Application repository with Dockerfile, charts/, Makefile
# - Jenkinsfile (jenkins-x.yml) with pipeline definition
# - Environment repositories for staging and production
```

### 4.3 Jenkins X Pipeline (jenkins-x.yml)

```yaml
# jenkins-x.yml — Jenkins X pipeline definition (Tekton under the hood)
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: order-api-pipeline
spec:
  tasks:
    # ── PR pipeline (runs on every Pull Request) ─────────────────────
    - name: pr-pipeline
      taskRef:
        name: jx-pipeline
      params:
        - name: pipeline-kind
          value: pullrequest

---
# jenkins-x-overrides.yml — customise the build pack pipeline
apiVersion: jenkins.io/v1
kind: Scheduler
metadata:
  name: order-api-scheduler
spec:
  pipeline:
    pullRequests:
      pipeline:
        stages:
          - name: ci
            steps:
              - name: install-deps
                image: node:20-alpine
                command: npm ci

              - name: lint
                image: node:20-alpine
                command: npm run lint

              - name: unit-test
                image: node:20-alpine
                command: npm run test:unit -- --coverage
                env:
                  - name: NODE_ENV
                    value: test

              - name: coverage-gate
                image: node:20-alpine
                command: |
                  COVERAGE=$(cat coverage/coverage-summary.json | jq '.total.lines.pct')
                  [ $(echo "$COVERAGE >= 80" | bc) -eq 1 ] || exit 1

              - name: build-image
                image: gcr.io/kaniko-project/executor:v1.21.0
                command: /kaniko/executor
                args:
                  - --context=/workspace/source
                  - --dockerfile=/workspace/source/Dockerfile
                  - --destination=$(inputs.params.DOCKER_REGISTRY)/$(inputs.params.APP_NAME):$(inputs.params.VERSION)
                  - --cache=true
                  - --cache-repo=$(inputs.params.DOCKER_REGISTRY)/$(inputs.params.APP_NAME)/cache

              - name: scan-image
                image: aquasec/trivy:latest
                command: trivy image
                args:
                  - --exit-code=1
                  - --severity=CRITICAL
                  - --ignore-unfixed
                  - $(inputs.params.DOCKER_REGISTRY)/$(inputs.params.APP_NAME):$(inputs.params.VERSION)

    release:
      pipeline:
        stages:
          - name: ci-build
            steps:
              - name: install-deps
                image: node:20-alpine
                command: npm ci

              - name: test-all
                image: node:20-alpine
                command: npm run test:ci
                env:
                  - name: DATABASE_URL
                    valueFrom:
                      secretKeyRef:
                        name: order-api-test-db
                        key: url

              - name: build-and-push
                image: gcr.io/kaniko-project/executor:v1.21.0
                command: /kaniko/executor
                args:
                  - --context=/workspace/source
                  - --dockerfile=/workspace/source/Dockerfile
                  - --destination=$(inputs.params.DOCKER_REGISTRY)/$(inputs.params.APP_NAME):$(inputs.params.VERSION)
                  - --destination=$(inputs.params.DOCKER_REGISTRY)/$(inputs.params.APP_NAME):latest
                  - --cache=true

          - name: promote-staging
            options:
              volumes:
                - name: jx-pipeline-git-github-gh
                  secret:
                    secretName: jx-pipeline-git-github-gh
            steps:
              - name: jx-promote
                image: gcr.io/jenkinsxio/jx-cli:latest
                command: jx promote
                args:
                  - --all-auto
                  - --env=staging
                  - --version=$(inputs.params.VERSION)
                  - --batch-mode
```

### 4.4 Jenkins X Environment Promotion

```bash
# Jenkins X environments are Git repositories
# Promoting to staging = opening a PR in the staging environment repo

# List environments
jx get environments
# NAME        KIND        NAMESPACE    GIT CLONE URL
# dev         Development dev          https://github.com/myorg/jx-env-dev
# staging     Staging     jx-staging   https://github.com/myorg/jx-env-staging
# production  Production  jx-prod      https://github.com/myorg/jx-env-production

# Manually promote to staging
jx promote order-api \
  --env staging \
  --version 1.4.2 \
  --batch-mode

# Promote to production with PR (requires review)
jx promote order-api \
  --env production \
  --version 1.4.2

# Watch promotion activity
jx get activity -f order-api -w

# Jenkins X environment pipeline configuration
cat > jx/environment/production/Makefile << 'EOF'
# Validate before Argo CD applies
validate:
  helm lint charts/order-api
  kubectl apply --dry-run=server -f environments/production/
EOF
```

---

## 5. Progressive Delivery with Argo Rollouts — Deep Dive

### 5.1 Installation and Setup

```bash
# Install Argo Rollouts
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts \
  -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

# Install kubectl plugin
curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64
chmod +x kubectl-argo-rollouts-linux-amd64
sudo mv kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts

# Verify
kubectl argo rollouts version
kubectl get pods -n argo-rollouts
```

### 5.2 Canary Rollout with Automated Analysis

```yaml
# rollout-canary.yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: order-api
  namespace: production
  annotations:
    # Link to Argo CD for GitOps management
    argocd.argoproj.io/managed-by: argocd
spec:
  replicas: 10
  revisionHistoryLimit: 3
  selector:
    matchLabels:
      app: order-api
  template:
    metadata:
      labels:
        app: order-api
    spec:
      automountServiceAccountToken: false
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        fsGroup: 10001
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: order-api
          image: ghcr.io/myorg/order-api:1.4.2
          ports:
            - name: http
              containerPort: 8080
            - name: metrics
              containerPort: 9090
          resources:
            requests:
              cpu: 250m
              memory: 256Mi
            limits:
              cpu: 500m
              memory: 512Mi
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: ["ALL"]
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
          volumeMounts:
            - name: tmp
              mountPath: /tmp
      volumes:
        - name: tmp
          emptyDir: {}

  strategy:
    canary:
      # The stable and canary Services for traffic splitting
      stableService: order-api-stable
      canaryService: order-api-canary

      # Traffic provider (Istio VirtualService for precise splitting)
      trafficRouting:
        istio:
          virtualService:
            name: order-api-vsvc
            routes:
              - primary
          destinationRule:
            name: order-api-destrule
            canarySubsetName: canary
            stableSubsetName: stable

      steps:
        # Step 1: 5% canary traffic
        - setWeight: 5
        # Step 2: Run analysis for 10 minutes at 5%
        - pause: {duration: 10m}
        - analysis:
            templates:
              - templateName: success-rate-check
              - templateName: latency-check
            args:
              - name: service-name
                value: order-api
        # Step 3: Increase to 20%
        - setWeight: 20
        - pause: {duration: 10m}
        - analysis:
            templates:
              - templateName: success-rate-check
              - templateName: latency-check
            args:
              - name: service-name
                value: order-api
        # Step 4: Increase to 50% — pause for human review
        - setWeight: 50
        - pause: {}              # Indefinite pause; promoted manually or via CI
        # Step 5: Full rollout
        - setWeight: 100

      # Anti-affinity: don't schedule canary and stable on same node
      antiAffinity:
        requiredDuringSchedulingIgnoredDuringExecution: {}
        preferredDuringSchedulingIgnoredDuringExecution:
          weight: 1

---
# AnalysisTemplate — success rate check
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate-check
  namespace: production
spec:
  args:
    - name: service-name
  metrics:
    - name: success-rate
      interval: 1m
      count: 5                   # Run 5 times (5 minutes)
      successCondition: result[0] >= 0.995   # 99.5% success rate
      failureLimit: 1            # Fail after 1 unsuccessful measurement
      provider:
        prometheus:
          address: http://kube-prometheus-stack-prometheus.monitoring:9090
          query: |
            sum(
              rate(http_requests_total{
                job="{{ args.service-name }}",
                status!~"5.."
              }[1m])
            ) /
            sum(
              rate(http_requests_total{
                job="{{ args.service-name }}"
              }[1m])
            )

---
# AnalysisTemplate — P99 latency check
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: latency-check
  namespace: production
spec:
  args:
    - name: service-name
  metrics:
    - name: p99-latency
      interval: 1m
      count: 5
      successCondition: result[0] <= 0.5     # P99 must be ≤ 500ms
      failureLimit: 2
      provider:
        prometheus:
          address: http://kube-prometheus-stack-prometheus.monitoring:9090
          query: |
            histogram_quantile(0.99,
              sum(
                rate(http_request_duration_seconds_bucket{
                  job="{{ args.service-name }}"
                }[1m])
              ) by (le)
            )

---
# AnalysisTemplate — business metric check
# Canary must not reduce the order conversion rate
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: conversion-rate-check
  namespace: production
spec:
  metrics:
    - name: order-conversion-rate
      interval: 5m
      count: 3
      # The canary conversion rate must be within 5% of stable
      successCondition: >
        result[0] >= (
          scalar(
            sum(rate(orders_completed_total{version="stable"}[5m])) /
            sum(rate(checkout_started_total{version="stable"}[5m]))
          ) * 0.95
        )
      provider:
        prometheus:
          address: http://kube-prometheus-stack-prometheus.monitoring:9090
          query: |
            sum(rate(orders_completed_total{version="canary"}[5m])) /
            sum(rate(checkout_started_total{version="canary"}[5m]))
```

### 5.3 Istio VirtualService for Traffic Splitting

```yaml
# Istio VirtualService — managed by Argo Rollouts controller
# Do NOT apply manually; Argo Rollouts updates the weights automatically
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: order-api-vsvc
  namespace: production
spec:
  hosts:
    - order-api
  http:
    - name: primary
      route:
        - destination:
            host: order-api-stable
            port:
              number: 80
          weight: 100           # Argo Rollouts modifies these weights
        - destination:
            host: order-api-canary
            port:
              number: 80
          weight: 0

---
# DestinationRule — defines stable and canary subsets
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: order-api-destrule
  namespace: production
spec:
  host: order-api
  subsets:
    - name: stable
      labels:
        rollouts-pod-template-hash: stable    # Managed by Argo Rollouts
    - name: canary
      labels:
        rollouts-pod-template-hash: canary

---
# Stable Service — routes to stable ReplicaSet
apiVersion: v1
kind: Service
metadata:
  name: order-api-stable
  namespace: production
spec:
  selector:
    app: order-api
    # rollouts-pod-template-hash selector injected by Argo Rollouts
  ports:
    - port: 80
      targetPort: 8080

---
# Canary Service — routes to canary ReplicaSet
apiVersion: v1
kind: Service
metadata:
  name: order-api-canary
  namespace: production
spec:
  selector:
    app: order-api
    # rollouts-pod-template-hash selector injected by Argo Rollouts
  ports:
    - port: 80
      targetPort: 8080
```

### 5.4 Blue/Green Rollout

```yaml
# rollout-blue-green.yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: payment-api
  namespace: production
spec:
  replicas: 5
  selector:
    matchLabels:
      app: payment-api
  template:
    metadata:
      labels:
        app: payment-api
    spec:
      containers:
        - name: payment-api
          image: ghcr.io/myorg/payment-api:2.0.0
          resources:
            requests:
              cpu: 500m
              memory: 512Mi
            limits:
              cpu: "2"
              memory: 1Gi

  strategy:
    blueGreen:
      # Active Service: receives 100% of production traffic
      activeService: payment-api-active

      # Preview Service: points to the new (green) Pods — for testing only
      previewService: payment-api-preview

      # Auto-promotion disabled — require human approval
      autoPromotionEnabled: false

      # Wait 5 minutes after new Pods are ready before allowing promotion
      # Gives time for metrics to stabilise
      autoPromotionSeconds: 0     # 0 = manual promotion only

      # Run analysis on the preview environment before promoting
      prePromotionAnalysis:
        templates:
          - templateName: success-rate-check
        args:
          - name: service-name
            value: payment-api-preview

      # Run analysis for 10 minutes post-promotion (auto-rollback on failure)
      postPromotionAnalysis:
        templates:
          - templateName: success-rate-check
          - templateName: latency-check
        args:
          - name: service-name
            value: payment-api

      # Scale down old ReplicaSet after this delay (keep for quick rollback)
      scaleDownDelaySeconds: 600   # 10 minutes after promotion

---
# Active Service (production traffic)
apiVersion: v1
kind: Service
metadata:
  name: payment-api-active
  namespace: production
spec:
  selector:
    app: payment-api
  ports:
    - port: 80
      targetPort: 8080

---
# Preview Service (testing the green version)
apiVersion: v1
kind: Service
metadata:
  name: payment-api-preview
  namespace: production
spec:
  selector:
    app: payment-api
  ports:
    - port: 80
      targetPort: 8080
```

```bash
# Monitor blue/green rollout
kubectl argo rollouts get rollout payment-api -n production

# Output:
# Name:            payment-api
# Namespace:       production
# Status:          ॥ Paused
# Message:         BlueGreenPause
# Strategy:        BlueGreen
# Active Service:  payment-api-active
# Preview Service: payment-api-preview
#
# REVISION  STATUS   STABLE  CANARY  WEIGHT  INFO
# 3         Healthy  true
# 4         Healthy          true           preview

# Validate the preview environment before promoting
curl https://preview.api.mycompany.com/health/ready
# {"status":"ok","version":"2.0.0"}

# Run regression tests against preview
PAYMENT_API_URL=https://preview.api.mycompany.com npm run test:regression

# Promote green to active (blue/green cutover — instant, no traffic interruption)
kubectl argo rollouts promote payment-api -n production

# Output:
# rollout 'payment-api' promoted

# If something goes wrong — instant rollback to blue
kubectl argo rollouts undo payment-api -n production
```

### 5.5 Traffic Mirroring (Shadow Mode)

```yaml
# Traffic mirroring sends a copy of production traffic to the canary
# without affecting the response seen by users.
# Zero risk: if the canary crashes, users never see it.

apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: search-api
  namespace: production
spec:
  replicas: 5
  selector:
    matchLabels:
      app: search-api
  template:
    metadata:
      labels:
        app: search-api
    spec:
      containers:
        - name: search-api
          image: ghcr.io/myorg/search-api:3.0.0-rc1

  strategy:
    canary:
      stableService: search-api-stable
      canaryService: search-api-canary
      trafficRouting:
        istio:
          virtualService:
            name: search-api-vsvc
            routes:
              - primary

      steps:
        # Step 1: Mirror 100% of production traffic to canary
        # Users still only see stable responses
        - setMirrorRoute:
            name: mirror-route
            percentage: 100
            match:
              - method:
                  exact: GET
                path:
                  prefix: /api/v1/search
        # Step 2: Observe mirrored traffic for 30 minutes
        - pause: {duration: 30m}
        # Step 3: Run analysis on canary performance under real traffic
        - analysis:
            templates:
              - templateName: success-rate-check
              - templateName: latency-check
        # Step 4: If analysis passes, start real traffic shift
        - setMirrorRoute:
            name: mirror-route           # Remove mirror
            percentage: 0
        - setWeight: 10
        - pause: {duration: 10m}
        - setWeight: 50
        - pause: {}
        - setWeight: 100
```

### 5.6 Rollout Observability

```bash
# Real-time rollout dashboard in the terminal
kubectl argo rollouts dashboard -n production
# Opens a terminal UI showing all Rollouts, their status,
# current weights, AnalysisRun results, and event history

# Get detailed rollout information
kubectl argo rollouts get rollout order-api -n production --watch

# View analysis runs
kubectl argo rollouts list analysisruns -n production

# Get analysis run details
kubectl describe analysisrun order-api-abc123 -n production

# Abort a running analysis (and rollback)
kubectl argo rollouts abort order-api -n production

# Retry a failed rollout (if you've fixed the issue)
kubectl argo rollouts retry rollout order-api -n production

# Set a new image directly (triggers a new rollout)
kubectl argo rollouts set image order-api \
  order-api=ghcr.io/myorg/order-api:1.4.4 \
  -n production

# Pause all rollouts in a namespace (e.g. during an incident)
kubectl argo rollouts pause order-api -n production

# Resume
kubectl argo rollouts resume order-api -n production
```

---

## 6. Security Gates — Integrated Pipeline Security

### 6.1 Complete Security Gate Sequence

```
PR opened:
  ├── Gitleaks: no secrets in committed code              [SAST]
  ├── CodeQL: no known vulnerability patterns             [SAST]
  ├── npm audit / pip check: no vulnerable dependencies   [SCA]
  ├── Snyk: deeper dependency analysis                    [SCA]
  ├── Polaris: Helm manifests meet security standards     [Config]
  └── License check: no GPL/AGPL dependencies            [Legal]

On merge to main:
  ├── Trivy image scan: no CRITICAL/HIGH CVEs             [Image]
  ├── Cosign sign: image cryptographically signed         [Supply chain]
  ├── SBOM generated: full software bill of materials     [Compliance]
  └── Attestation: build provenance recorded              [Supply chain]

Pre-production deploy:
  ├── Cosign verify: signature matches expected issuer    [Supply chain]
  ├── Kyverno/OPA: image from allowed registry            [Policy]
  └── Kyverno/OPA: image has valid signature              [Policy]
```

### 6.2 Kyverno Policy — Require Signed Images

```yaml
# Enforce that all production Pods use signed images
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-signed-images
spec:
  validationFailureAction: Enforce
  background: false
  rules:
    - name: check-image-signature
      match:
        any:
          - resources:
              kinds: ["Pod"]
              namespaces: ["production"]
      verifyImages:
        - imageReferences:
            - "ghcr.io/myorg/*"
          attestors:
            - count: 1
              entries:
                - keyless:
                    subject: "https://github.com/myorg/*"
                    issuer: "https://token.actions.githubusercontent.com"
                    rekor:
                      url: https://rekor.sigstore.dev
          mutateDigest: true       # Mutate :tag → @sha256:digest for immutability
          verifyDigest: true
          required: true
```

### 6.3 Tekton Pipeline Security Step

```yaml
# A reusable Tekton Task for security scanning
# Used by Jenkins X and standalone Tekton pipelines
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: security-scan
  namespace: tekton-pipelines
spec:
  params:
    - name: image-url
      description: Full image URL to scan
    - name: fail-on-severity
      default: CRITICAL
    - name: output-format
      default: sarif

  results:
    - name: scan-result
      description: "PASS or FAIL"

  steps:
    - name: trivy-scan
      image: aquasec/trivy:0.51.1
      script: |
        #!/usr/bin/env sh
        set -e

        trivy image \
          --exit-code 0 \
          --severity $(params.fail-on-severity) \
          --ignore-unfixed \
          --format $(params.output-format) \
          --output /workspace/trivy-report.sarif \
          $(params.image-url)

        VULN_COUNT=$(trivy image \
          --exit-code 0 \
          --severity $(params.fail-on-severity) \
          --ignore-unfixed \
          --format json \
          $(params.image-url) | \
          jq '[.Results[].Vulnerabilities // [] | .[] | select(.Severity == "CRITICAL")] | length')

        echo "Found ${VULN_COUNT} CRITICAL vulnerabilities"

        if [ "$VULN_COUNT" -gt 0 ]; then
          echo -n "FAIL" > $(results.scan-result.path)
          echo "::error::Trivy found ${VULN_COUNT} CRITICAL vulnerabilities"
          exit 1
        else
          echo -n "PASS" > $(results.scan-result.path)
          echo "No CRITICAL vulnerabilities found"
        fi
```

---

## 7. Step-by-Step Hands-on Walkthrough

### 7.1 End-to-End Pipeline Test

```bash
# Step 1: Fork/clone the sample repository
git clone https://github.com/myorg/order-api
cd order-api

# Step 2: Create a feature branch
git checkout -b feature/add-order-validation

# Step 3: Make a change, commit, push
echo "// Added order validation" >> src/validation.js
git add -A
git commit -m "feat: add order quantity validation"
git push origin feature/add-order-validation

# Step 4: Open a PR — CI pipeline triggers automatically
# Observe in GitHub Actions:
# ✓ lint-and-sast (2m 15s)
# ✓ unit-tests (1m 48s)
# ✓ integration-tests (3m 22s)
# ✓ dependency-audit (1m 05s)

# Step 5: PR is merged to main
# CD pipeline triggers:
# ✓ build-and-push (4m 33s) — image built and pushed to ghcr.io
# ✓ trivy-scan (1m 22s) — no CRITICAL CVEs
# ✓ cosign-sign (15s) — image signed

# Step 6: Staging deploy triggers automatically
# ✓ helm-upgrade-staging (2m 15s)
# ✓ smoke-tests-staging (45s)

# Step 7: Trigger production deploy (manual)
gh workflow run cd-production.yml \
  --field image_tag=$(git rev-parse --short HEAD) \
  --field deployment_strategy=canary
```

### 7.2 Simulate Canary Rollback

```bash
# Verify the rollout has started
kubectl argo rollouts get rollout order-api -n production

# Simulate a bug in the canary (for demonstration)
# In a test environment, artificially inject errors:
kubectl exec -n production deploy/order-api-canary -- \
  sh -c "kill -SIGSTOP 1"  # Pause the process to cause health check failures

# Watch the analysis fail and rollback trigger
kubectl argo rollouts get rollout order-api -n production --watch
# Status: ✖ Degraded
# Message: AnalysisRun "order-api-abc123" failed: "success-rate" assessed Error
#          for metric: Prometheus query returned less than successCondition

# The rollout automatically aborts and rolls back
# Canary weight returns to 0%, all traffic to stable

# View the failed AnalysisRun
kubectl argo rollouts list analysisruns -n production
kubectl describe analysisrun order-api-abc123 -n production
```

---

## 8. Real-World Scenario: Zero-Downtime Migration at FinTech Startup

### The Problem

ClearPay, a payment processing startup, deployed a major refactoring of their payment API that introduced a subtle regression in the retry logic for declined cards. The bug only manifested under production load patterns. Their previous push-based CI/CD (GitHub Actions directly calling `kubectl apply`) meant the entire fleet of 30 Pods was updated before anyone noticed the regression.

**Impact:** 8 minutes of elevated payment decline rates, 2,400 failed transactions, $180,000 in lost revenue.

**Root cause of delayed detection:** No automated analysis on deployments, no traffic splitting, no canary.

### The New Architecture

```
PR merged
    │
    ▼
GitHub Actions CI:
  ├── Unit tests (payment retry logic covered)
  ├── Integration tests (testcontainers + payment simulator)
  ├── Trivy scan (no CVEs)
  └── Push image with git SHA tag: payment-api:abc1234
    │
    ▼
GitOps: Update image tag in Git → Argo CD detects change
    │
    ▼
Argo Rollouts — Canary Strategy:
  Step 1: 5% canary traffic
  Step 2: AnalysisRun — check:
          - payment_success_rate >= 99.5%        ← Key business metric
          - card_decline_rate_change < 1%         ← Detects retry regression
          - p99_latency < 800ms
  Step 3: If analysis passes → 20% → analysis → 50% → manual approval → 100%
  Step 4: If analysis fails → automatic abort → 0% canary → alert fired
```

### The Key AnalysisTemplate (business-metric aware)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: payment-business-metrics
  namespace: production
spec:
  metrics:
    - name: payment-success-rate
      interval: 2m
      count: 3
      successCondition: result[0] >= 0.995
      failureLimit: 1
      provider:
        prometheus:
          address: http://prometheus.monitoring:9090
          query: |
            sum(rate(payment_transactions_total{
              status="success",
              version="canary"
            }[2m])) /
            sum(rate(payment_transactions_total{
              version="canary"
            }[2m]))

    - name: card-decline-rate-delta
      interval: 2m
      count: 3
      # Canary decline rate must not be more than 1% higher than stable
      successCondition: |
        result[0] <= (
          scalar(
            sum(rate(payment_transactions_total{status="declined",version="stable"}[2m])) /
            sum(rate(payment_transactions_total{version="stable"}[2m]))
          ) + 0.01
        )
      provider:
        prometheus:
          address: http://prometheus.monitoring:9090
          query: |
            sum(rate(payment_transactions_total{
              status="declined",
              version="canary"
            }[2m])) /
            sum(rate(payment_transactions_total{
              version="canary"
            }[2m]))
```

### Results

| Incident | Before (push deploy) | After (canary + analysis) |
|---|---|---|
| Same retry regression introduced | 8 min impact, 2,400 failed txns | Caught at 5% canary, 0 impact |
| Deploy-time detection | Post-deploy alert (too late) | AnalysisRun failure at step 2 |
| Rollback time | 12 minutes (redeploy old image) | 45 seconds (automatic abort) |
| Production deployments per week | 2 (fear of change) | 14 (confidence from automation) |
| MTTR for deploy-caused incidents | 18 minutes | 45 seconds |

---

## 9. Common Pitfalls & Best Practices

### Pitfall 1: Treating CI and CD as a Single Pipeline
Many teams build a single pipeline that goes from `git push` to production in one uninterrupted run. This creates a false sense of speed: if the production deploy fails, the entire pipeline re-runs from scratch. **Separate CI (build, test, scan, publish) from CD (deploy, smoke test, promote). CI produces a versioned artifact; CD consumes it. Each stage is independently retryable.**

### Pitfall 2: Long-Lived Feature Branches Destroying CI Value
Continuous Integration means integrating continuously — ideally multiple times per day. A team with 10-day feature branches is not doing CI; they are doing periodic integration. When the branch merges, the conflict resolution and test failures from 10 days of divergence arrive simultaneously. **Enforce short-lived branches (1-3 days max). Use feature flags to merge incomplete features to main without exposing them to users.**

### Pitfall 3: Canary Without Traffic Splitting (Fake Canary)
A common "canary" anti-pattern is updating a single Pod in a Deployment while leaving the rest on the old version. This is not traffic splitting — the load balancer distributes traffic randomly, and the fraction hitting the new Pod depends entirely on Pod count. At 10 replicas, you cannot get 5% traffic to the new Pod; you get 10%. **Use Argo Rollouts with an Istio VirtualService, NGINX Ingress annotations, or AWS ALB weighted target groups for precise traffic weight control.**

### Pitfall 4: AnalysisTemplate Success Conditions That Always Pass
Teams configure AnalysisTemplates with success conditions that are trivially true: `result[0] >= 0.0` (any success rate passes). This provides zero protection — the analysis succeeds even if the canary has a 50% error rate. **Set meaningful thresholds: success rate ≥ 99.5%, P99 latency ≤ 500ms. For critical services, add business metrics like conversion rate or transaction success rate.**

### Pitfall 5: GitHub Actions Storing Cloud Credentials as Secrets
Using long-lived AWS access keys or service account JSON keys as GitHub Actions secrets creates a persistent credential that, if leaked, grants long-term cloud access. **Use OIDC federation (GitHub Actions OIDC → AWS IAM, GCP Workload Identity, Azure Managed Identity). The credential is a short-lived token issued per pipeline run — no rotation required, no long-term exposure.**

### Pitfall 6: Skipping Smoke Tests After Staging Deploy
Teams run exhaustive tests in CI but skip post-deploy smoke tests in staging, assuming "if it passed CI, it will work in staging". Environmental differences (different database versions, different network topology, different secret values) cause failures that only manifest post-deploy. **Always run a lightweight smoke test suite after every environment deploy. Smoke tests should verify the three to five most critical user-facing flows.**

> **CI/CD Production Readiness Checklist**
> - [ ] CI pipeline separates lint/SAST, unit tests, integration tests, and build into distinct jobs
> - [ ] Integration tests run against real dependencies (testcontainers or services blocks)
> - [ ] Code coverage gate enforced (≥80% line coverage blocks merge)
> - [ ] SAST (CodeQL) and secret scanning (Gitleaks) run on every PR
> - [ ] Dependency audit (npm audit / Snyk) runs on every PR
> - [ ] Trivy image scan blocks on CRITICAL/HIGH CVEs before push
> - [ ] Images signed with Cosign using keyless OIDC signing
> - [ ] SBOM generated and attached as OCI attestation
> - [ ] Cloud credentials use OIDC federation — no long-lived keys stored as secrets
> - [ ] Production deploys require manual trigger with image signature verification
> - [ ] Argo Rollouts configured with Prometheus-backed AnalysisTemplates
> - [ ] Canary AnalysisTemplate includes at least one business metric
> - [ ] Blue/green rollouts use post-promotion analysis window
> - [ ] Rollback verified to complete in under 2 minutes
> - [ ] Pipeline failure notifications sent to dedicated Slack channel

---

## 10. Key Takeaways

1. **A Kubernetes CI/CD pipeline is a quality gate system, not just automation.** Each stage is an assertion: tests assert correctness, scans assert security, manifest validation asserts operational compliance, and progressive delivery asserts production behaviour. A pipeline that bypasses any gate is not faster — it is a false economy that defers the failure to a worse time.

2. **GitHub Actions OIDC federation eliminates the biggest CI/CD security risk.** Storing long-lived cloud credentials as GitHub Secrets is a lateral movement risk if the repository is compromised. OIDC-based short-lived tokens are scoped to a specific job, expire within minutes, and require no rotation. Migrate all CI/CD cloud authentication to OIDC.

3. **Jenkins X makes CI/CD a first-class Kubernetes citizen.** By running pipelines as Tekton Pods, using Kaniko for daemon-less builds, and automating GitOps environment promotion, Jenkins X eliminates the impedance mismatch between CI/CD tooling and Kubernetes operations. For teams fully committed to Kubernetes-native workflows, it reduces the number of external tool integrations significantly.

4. **Progressive delivery with Argo Rollouts is the production-grade alternative to RollingUpdate.** RollingUpdate replaces Pods but cannot control traffic distribution or evaluate business metrics. Argo Rollouts canary with Prometheus-backed AnalysisTemplates catches regressions before they affect the full user base — using real production traffic as the test signal.

5. **Traffic mirroring (shadow mode) provides zero-risk production validation.** For high-risk deployments where even 5% canary exposure is unacceptable, traffic mirroring sends a copy of all production traffic to the new version while discarding its responses. The new version is validated under real load with zero user-facing risk.

6. **Image signing with Cosign and policy enforcement with Kyverno closes the supply chain loop.** Signing images in CI and verifying signatures at admission time ensures that no unsigned image — whether from a compromised registry, a misconfigured pipeline, or a direct namespace injection — can run in production. The trust chain is: approved repository → CI pipeline → signed image → Kyverno admission check → running Pod.

---

## 11. Exercises & Labs

**Exercise 1: GitHub Actions CI Pipeline**
Create a GitHub repository with a Node.js application. Build a three-job CI pipeline: (a) lint + CodeQL SAST, (b) unit tests with coverage gate (≥80%), (c) Docker build + Trivy scan (block on CRITICAL). Use job dependencies so jobs run sequentially. Verify: push a commit with a known vulnerability (old `lodash` version) and confirm the Trivy gate blocks the pipeline.

**Exercise 2: OIDC Cloud Authentication**
Replace any stored AWS/GCP/Azure credentials in your GitHub Actions workflow with OIDC federation. For AWS: create an IAM OIDC identity provider for `token.actions.githubusercontent.com`, create a role with a trust policy restricting to your repository, and use `aws-actions/configure-aws-credentials@v4` with `role-to-assume`. Verify: delete the old secret, run the pipeline, and confirm it authenticates successfully.

**Exercise 3: Argo Rollouts Canary with Analysis**
On a test cluster, install Argo Rollouts and convert a Deployment to a Rollout with a 4-step canary: 10% → pause 5m → AnalysisRun (success rate ≥ 99%) → 50% → pause → 100%. Deploy an initial version. Then deploy a new version and observe the canary progressing through steps. Simulate a failure (inject artificial 500 errors), verify the AnalysisRun detects the failure, and observe the automatic rollback to 0% canary weight.

**Exercise 4: Blue/Green with Pre-Promotion Analysis**
Configure a blue/green Rollout with `autoPromotionEnabled: false` and a `prePromotionAnalysis` block. Deploy a new version and verify: (a) the preview Service receives no traffic initially, (b) the AnalysisRun runs against the preview Service, (c) only after the analysis passes can you run `kubectl argo rollouts promote`. Then verify that `kubectl argo rollouts undo` performs an instant rollback.

**Exercise 5: Full Pipeline with GitOps Promotion**
Build a complete end-to-end pipeline: (a) GitHub Actions CI builds and pushes an image on merge to main, (b) CI writes the new image tag to a GitOps repository (update `kustomization.yaml`), (c) Argo CD detects the change and deploys to staging, (d) a smoke test runs against staging, (e) on smoke test success, a PR is automatically opened to update the production overlay, (f) after the PR is merged (manually), Argo CD deploys to production using a Rollout with canary strategy. Time the entire pipeline from `git push` to production canary start.

---

*End of Chapter 12*

**Next → Chapter 13: Managing Microservices Using Istio Service Mesh**



---

──────────────────────────────────────────────────────────────────────

## Part XIII: Managing Microservices Using Istio Service Mesh

> *Architecture · mTLS · Traffic Management · Chaos · Multi-Cluster*

──────────────────────────────────────────────────────────────────────


## 1. Introduction & Learning Objectives

A microservices architecture solves the problem of monolithic coupling by decomposing a system into independently deployable services. In doing so, it trades one set of problems for another: how do services discover each other reliably, how do you encrypt inter-service communication without changing application code, how do you control traffic between service versions, and how do you understand the behaviour of a distributed system when a single user request fans out across twelve services?

These are not application problems. They are infrastructure concerns — cross-cutting concerns that every service would need to solve individually if the platform did not solve them once. A **service mesh** is that platform layer. It moves networking logic — load balancing, retries, timeouts, circuit breaking, mTLS, telemetry — out of application code and into a dedicated infrastructure layer, making it consistent, configurable, and observable across every service in the mesh without a single line of application code change.

**Istio** is the most widely deployed, most feature-complete service mesh in the Kubernetes ecosystem. It is a CNCF graduated project originally developed by Google and IBM, and it underpins some of the largest microservices deployments in production. This final chapter covers Istio from first principles — its architecture, its installation, its traffic management API, and its security model — and then applies all of it to real-world scenarios: zero-downtime traffic shifting, chaos engineering with fault injection, mutual TLS enforcement across the entire mesh, and multi-cluster federation for global service availability.

> **Learning Objectives**
> - Explain the Istio architecture: control plane (Istiod) and data plane (Envoy proxies), and how they interact.
> - Install Istio on a production cluster with the correct configuration profile and resource settings.
> - Configure automatic sidecar injection and understand what the Envoy proxy intercepts.
> - Use VirtualService, DestinationRule, and Gateway resources to implement advanced traffic management.
> - Enforce mutual TLS (mTLS) cluster-wide and verify end-to-end encryption between all services.
> - Use Kiali for service mesh topology visualisation and Jaeger/Tempo for distributed tracing.
> - Inject faults (delays, aborts) for chaos engineering to validate service resilience.
> - Configure Istio for multi-cluster federation with failover and load balancing across clusters.
> - Implement circuit breaking, retry policies, and outlier detection to build resilient microservice communication.

---

## 2. Core Concepts

### 2.1 The Service Mesh Problem Space

Before Istio, each microservice was responsible for implementing networking concerns itself — usually via a language-specific library (Netflix Hystrix for circuit breaking, Spring Retry for retries, a custom TLS initialisation routine). This approach has three fundamental problems:

```
Problem 1: Language fragmentation
  Java service uses Hystrix for circuit breaking
  Python service uses tenacity for retries
  Go service uses custom retry logic
  → Inconsistent behaviour, different configuration APIs, different observability

Problem 2: Application-infrastructure coupling
  Retry logic in application code means:
  → Changing retry behaviour requires code changes + tests + deployment
  → Infrastructure operators cannot tune service networking without developer involvement

Problem 3: Invisible inter-service communication
  Service A calls Service B. Service B calls Service C.
  → No visibility into latency at each hop
  → No insight into which requests succeed or fail
  → No way to enforce security policies (encryption, auth) uniformly

Service mesh solution:
  Move ALL networking concerns into a sidecar proxy (Envoy)
  → Consistent behaviour across all languages and runtimes
  → Configuration via Kubernetes CRDs (no code changes)
  → Full telemetry from every network hop, automatically
```

### 2.2 Istio Architecture

Istio is divided into two planes: the **control plane** (Istiod — a single binary that manages configuration) and the **data plane** (Envoy sidecar proxies — one per Pod, handling all inbound and outbound network traffic).

```
┌──────────────────────────────────────────────────────────────────────────┐
│  ISTIO CONTROL PLANE                                                      │
│                                                                           │
│  ┌───────────────────────────────────────────────────────────────────┐   │
│  │  Istiod (single binary, replaces Pilot + Mixer + Citadel + Galley)│   │
│  │                                                                    │   │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐   │   │
│  │  │  Pilot           │  │  Citadel         │  │  Galley          │   │   │
│  │  │  Service         │  │  Certificate     │  │  Configuration   │   │   │
│  │  │  Discovery       │  │  Authority (CA)  │  │  Validation      │   │   │
│  │  │  Traffic mgmt    │  │  mTLS certs      │  │  CRD webhooks    │   │   │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────┘   │   │
│  └───────────────────────────────────────────────────────────────────┘   │
│                │ xDS API (gRPC streaming)                                 │
│                │ (Listener, Route, Cluster, Endpoint Discovery Service)   │
└────────────────┼─────────────────────────────────────────────────────────┘
                 │
┌────────────────┼─────────────────────────────────────────────────────────┐
│  DATA PLANE    │                                                          │
│                ▼                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐    │
│  │  Pod: order-api                                                   │    │
│  │                                                                   │    │
│  │  ┌──────────────────────────┐   ┌────────────────────────────┐  │    │
│  │  │  istio-proxy (Envoy)      │   │  order-api container        │  │    │
│  │  │                          │   │                             │  │    │
│  │  │  Inbound: port 15006     │   │  Only sees localhost        │  │    │
│  │  │  Outbound: port 15001    │   │  Envoy is transparent       │  │    │
│  │  │  Admin: port 15000       │   │  to the application         │  │    │
│  │  │  Health: port 15020      │   │                             │  │    │
│  │  │                          │   │  Listens on: 8080           │  │    │
│  │  │  mTLS termination        │   │                             │  │    │
│  │  │  Telemetry collection    │◄──│  Speaks plain HTTP          │  │    │
│  │  │  Retry / timeout         │   │  Envoy handles TLS          │  │    │
│  │  │  Circuit breaking        │   │                             │  │    │
│  │  │  Load balancing          │   │                             │  │    │
│  │  └──────────────────────────┘   └────────────────────────────┘  │    │
│  │     iptables rules redirect all traffic through Envoy             │    │
│  └──────────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────────┘
```

#### xDS API — How Istiod Configures Envoy

Istiod pushes configuration to Envoy proxies via the xDS (Discovery Service) API — a set of gRPC streaming APIs:

| xDS API | Controls | Corresponds to Istio Resource |
|---|---|---|
| LDS (Listener) | Which ports Envoy listens on | VirtualService, Gateway |
| RDS (Route) | How to route requests by path/header | VirtualService |
| CDS (Cluster) | Upstream service definitions | DestinationRule |
| EDS (Endpoint) | Individual endpoint (Pod) addresses | Service, ServiceEntry |
| SDS (Secret) | TLS certificates | PeerAuthentication, mTLS certs |

#### Traffic Flow Through the Mesh

```
Client Pod (order-api)     Network           Server Pod (payment-api)
──────────────────────     ───────           ───────────────────────
App code calls             encrypted         Envoy receives
payment-api:8080 ─────────▶ mTLS ──────────▶ inbound request
     │                                              │
     │ iptables                                     │ iptables
     ▼ intercept                                    ▼ intercept
Envoy (outbound)                              Envoy (inbound)
     │                                              │
     │ Applies:                                     │ Applies:
     │ ├── Routing rules                            │ ├── mTLS validation
     │ ├── Retry policy                             │ ├── Authz policy
     │ ├── Timeout                                  │ └── Telemetry
     │ ├── Circuit breaker
     │ └── mTLS origination
     │
     └── Strips: x-forwarded-for, injects trace headers
```

---

### 2.3 Sidecar Injection

Istio injects the `istio-proxy` (Envoy) sidecar container into Pods automatically using a **MutatingAdmissionWebhook**. When a Pod is created in a namespace with the injection label, the webhook intercepts the creation request and adds:

1. The `istio-proxy` sidecar container
2. An `istio-init` init container (sets up iptables rules to intercept traffic)
3. The Envoy configuration volume mounts

```yaml
# Enable automatic sidecar injection for a namespace
kubectl label namespace production istio-injection=enabled

# Verify the label
kubectl get namespace production --show-labels
# NAME         STATUS   LABELS
# production   Active   istio-injection=enabled,kubernetes.io/metadata.name=production

# Disable injection for a specific Pod (e.g. database Pods that don't need the mesh)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: production
spec:
  template:
    metadata:
      annotations:
        sidecar.istio.io/inject: "false"    # Opt out of injection

# Verify sidecar is injected (Pod should show 2 containers: app + istio-proxy)
kubectl get pods -n production
# NAME                         READY   STATUS    RESTARTS
# order-api-7d9b-4xk9p         2/2     Running   0   ← 2 containers: app + proxy
# postgres-0                   1/1     Running   0   ← No sidecar (opted out)

# Inspect the injected proxy
kubectl describe pod order-api-7d9b-4xk9p -n production | grep -A 20 "istio-proxy"

# Check proxy configuration and bootstrap
kubectl exec -n production order-api-7d9b-4xk9p -c istio-proxy -- \
  pilot-agent request GET config_dump | jq '.configs[0]'

# Check proxy synchronisation with Istiod
istioctl proxy-status -n production
# NAME                         CLUSTER  CDS    LDS    EDS    RDS    ISTIOD          VERSION
# order-api-7d9b-4xk9p.prod   Kubernetes SYNCED SYNCED SYNCED SYNCED istiod-abc-123   1.21.0
```

---

### 2.4 Traffic Management — The Core API

Istio's traffic management is expressed through four core resources:

| Resource | Layer | Controls |
|---|---|---|
| `Gateway` | L4-L6 | Entry point for external traffic; configures the ingress gateway |
| `VirtualService` | L7 | How requests are routed to services (by header, path, weight) |
| `DestinationRule` | L4-L6 | How traffic behaves once routed (load balancing, mTLS, circuit breaking) |
| `ServiceEntry` | L3-L4 | Registers external services in the mesh (e.g. external APIs, databases) |

#### Gateway — Ingress Entry Point

```yaml
# Gateway configures the Istio ingress gateway (an Envoy proxy running as a Service)
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: ecommerce-gateway
  namespace: production
spec:
  selector:
    istio: ingressgateway       # Targets the default Istio ingress gateway Pod
  servers:
    # HTTP — redirect to HTTPS
    - port:
        number: 80
        name: http
        protocol: HTTP
      hosts:
        - "api.mycompany.com"
        - "*.mycompany.com"
      tls:
        httpsRedirect: true     # 301 redirect all HTTP to HTTPS

    # HTTPS — TLS termination at the gateway
    - port:
        number: 443
        name: https
        protocol: HTTPS
      hosts:
        - "api.mycompany.com"
        - "admin.mycompany.com"
      tls:
        mode: SIMPLE            # TLS termination (MUTUAL for client certs)
        credentialName: ecommerce-tls-cert   # References a Kubernetes Secret with TLS cert
```

#### VirtualService — Advanced Traffic Routing

```yaml
# VirtualService: route requests for api.mycompany.com to order-api or payment-api
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: api-routing
  namespace: production
spec:
  hosts:
    - "api.mycompany.com"
    - order-api              # Also matches internal mesh traffic to this host
  gateways:
    - ecommerce-gateway      # Applies to external traffic through this gateway
    - mesh                   # Also applies to internal mesh traffic (pod-to-pod)
  http:
    # Route /api/v1/orders to order-api
    - match:
        - uri:
            prefix: /api/v1/orders
      route:
        - destination:
            host: order-api
            port:
              number: 80
      # Timeout for this route
      timeout: 30s
      # Retry policy for this route
      retries:
        attempts: 3
        perTryTimeout: 10s
        retryOn: "gateway-error,connect-failure,retriable-4xx"

    # Route /api/v1/payments to payment-api with canary splitting
    - match:
        - uri:
            prefix: /api/v1/payments
      route:
        - destination:
            host: payment-api
            subset: stable         # 95% to stable
          weight: 95
        - destination:
            host: payment-api
            subset: canary         # 5% to canary
          weight: 5

    # Route based on header (dark launch for internal testing)
    - match:
        - uri:
            prefix: /api/v1/search
          headers:
            x-beta-user:
              exact: "true"
      route:
        - destination:
            host: search-api
            subset: v2-beta

    # Default route — everything else
    - route:
        - destination:
            host: api-gateway
            port:
              number: 80
```

#### DestinationRule — Traffic Behaviour

```yaml
# DestinationRule: defines subsets (for canary) and circuit breaking for payment-api
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: payment-api-dr
  namespace: production
spec:
  host: payment-api
  # TLS mode for connections to this service (auto-detected with mTLS, but explicit is safer)
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL      # Use Istio-managed mTLS certificates

    # Load balancing algorithm for all subsets
    loadBalancer:
      simple: LEAST_CONN      # Least connections (better than round-robin for variable request times)

    # Connection pool settings (circuit breaker at connection level)
    connectionPool:
      tcp:
        maxConnections: 100   # Max simultaneous TCP connections
        connectTimeout: 30ms
      http:
        h2UpgradePolicy: UPGRADE   # Use HTTP/2 if available
        http1MaxPendingRequests: 100
        http2MaxRequests: 1000
        maxRequestsPerConnection: 10  # Close connection after 10 requests (avoid hot connections)

    # Outlier detection (circuit breaker at host level)
    outlierDetection:
      consecutive5xxErrors: 5         # Eject after 5 consecutive 5xx errors
      interval: 30s                   # Scan interval
      baseEjectionTime: 30s           # How long to eject the host
      maxEjectionPercent: 50          # Eject at most 50% of hosts simultaneously
      minHealthPercent: 50            # Keep at least 50% healthy hosts in pool

  # Version subsets (referenced by VirtualService)
  subsets:
    - name: stable
      labels:
        version: stable              # Matches Pods with this label
      trafficPolicy:
        loadBalancer:
          simple: ROUND_ROBIN

    - name: canary
      labels:
        version: canary
      trafficPolicy:
        connectionPool:
          http:
            http1MaxPendingRequests: 50   # Lower limit for canary (reduce blast radius)
```

#### ServiceEntry — External Services in the Mesh

```yaml
# Register an external payment gateway so Istio can apply policies to outbound calls
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: external-payment-gateway
  namespace: production
spec:
  hosts:
    - api.stripe.com
    - api.paypal.com
  ports:
    - number: 443
      name: https
      protocol: HTTPS
  location: MESH_EXTERNAL    # External service, not in the mesh
  resolution: DNS

---
# WorkloadEntry — register a VM workload (legacy system) in the mesh
# Allows a non-Kubernetes workload to participate in the service mesh
apiVersion: networking.istio.io/v1beta1
kind: WorkloadEntry
metadata:
  name: legacy-billing-vm
  namespace: production
spec:
  address: 10.0.10.50          # VM IP address
  ports:
    billing: 8080
  labels:
    app: billing
    version: legacy
  serviceAccount: billing-sa
```

---

### 2.5 Mutual TLS (mTLS)

Mutual TLS is the cornerstone of Istio's zero-trust security model. In standard TLS, only the server presents a certificate (the client verifies the server). In mTLS, both sides present certificates — the server authenticates the client, and the client authenticates the server. This enables service-to-service authentication without any application code changes.

```
Without mTLS:
  order-api ─── plain HTTP ──▶ payment-api
  Anyone on the cluster network can send requests to payment-api

With Istio mTLS:
  order-api ──▶ Envoy proxy ─── mTLS (cert: order-api.production.svc.cluster.local) ───▶
  ──▶ Envoy proxy ─── validates cert ──▶ payment-api
  Only services with valid Istio-issued certificates can communicate
  Certificate identity = SPIFFE URI: spiffe://cluster.local/ns/production/sa/order-api-sa
```

#### Istio Certificate Infrastructure

```
Istiod (Certificate Authority)
    │
    │ Issues short-lived X.509 certificates (24h default)
    │ to each Pod's Envoy proxy via SDS (Secret Discovery Service)
    │
    ├── order-api Pod → cert: spiffe://cluster.local/ns/production/sa/order-api-sa
    ├── payment-api Pod → cert: spiffe://cluster.local/ns/production/sa/payment-api-sa
    └── notification-svc Pod → cert: spiffe://cluster.local/ns/production/sa/notification-sa

Certificate rotation: automatic, transparent to applications
Certificate identity: SPIFFE format (Secure Production Identity Framework for Everyone)
```

```yaml
# PeerAuthentication — enforce mTLS for all services in a namespace
# STRICT mode: reject any plaintext (non-mTLS) connections
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: production
spec:
  mtls:
    mode: STRICT    # STRICT: mTLS required; PERMISSIVE: accept both; DISABLE: plaintext only

---
# Mesh-wide mTLS enforcement (applies to all namespaces)
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: mesh-wide-mtls
  namespace: istio-system      # istio-system namespace = mesh-wide scope
spec:
  mtls:
    mode: STRICT

---
# Port-level exception: allow plaintext on metrics port (Prometheus scraping)
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: order-api-mtls
  namespace: production
spec:
  selector:
    matchLabels:
      app: order-api
  mtls:
    mode: STRICT             # Default for all ports
  portLevelMtls:
    9090:
      mode: PERMISSIVE       # Allow plaintext on metrics port (Prometheus)
    15020:
      mode: PERMISSIVE       # Istio health check port
```

#### AuthorizationPolicy — Service-Level Access Control

```yaml
# Deny all traffic by default (zero-trust baseline)
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: production
spec:
  {}   # Empty spec = deny everything

---
# Allow order-api to call payment-api on specific paths only
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-order-to-payment
  namespace: production
spec:
  selector:
    matchLabels:
      app: payment-api
  action: ALLOW
  rules:
    - from:
        - source:
            # Only allow traffic from the order-api ServiceAccount
            principals:
              - "cluster.local/ns/production/sa/order-api-sa"
      to:
        - operation:
            methods: ["POST"]
            paths: ["/api/v1/payments", "/api/v1/refunds"]
      when:
        - key: request.headers[x-request-id]
          notValues: [""]    # Require a request ID (tracing)

---
# Allow Prometheus to scrape metrics from all services
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-prometheus-scrape
  namespace: production
spec:
  action: ALLOW
  rules:
    - from:
        - source:
            principals:
              - "cluster.local/ns/monitoring/sa/prometheus"
      to:
        - operation:
            methods: ["GET"]
            paths: ["/metrics", "/healthz", "/ready"]

---
# JWT authentication: require valid JWT for external API calls
apiVersion: security.istio.io/v1beta1
kind: RequestAuthentication
metadata:
  name: jwt-validation
  namespace: production
spec:
  selector:
    matchLabels:
      app: api-gateway
  jwtRules:
    - issuer: "https://auth.mycompany.com"
      jwksUri: "https://auth.mycompany.com/.well-known/jwks.json"
      audiences:
        - "api.mycompany.com"
      forwardOriginalToken: true

---
# Require JWT for all requests except health checks
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: require-jwt
  namespace: production
spec:
  selector:
    matchLabels:
      app: api-gateway
  action: ALLOW
  rules:
    - from:
        - source:
            requestPrincipals: ["*"]   # Any valid JWT
      to:
        - operation:
            notPaths: ["/health/*"]    # Except health endpoints
```

---

### 2.6 Resilience Patterns

#### Retry Policy

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: inventory-api-vs
  namespace: production
spec:
  hosts:
    - inventory-api
  http:
    - route:
        - destination:
            host: inventory-api
      # Retry configuration
      retries:
        attempts: 3                        # Retry up to 3 times
        perTryTimeout: 5s                  # Each attempt has 5s timeout
        retryOn: >-
          gateway-error,
          connect-failure,
          retriable-4xx,
          reset,
          refused-stream
        retryRemoteLocalities: true        # Retry on a different Pod

      # Overall timeout (must be > attempts × perTryTimeout)
      timeout: 20s
```

#### Circuit Breaker

```yaml
# DestinationRule circuit breaker for the inventory API
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: inventory-api-dr
  namespace: production
spec:
  host: inventory-api
  trafficPolicy:
    outlierDetection:
      # Eject a host from the load balancing pool when:
      consecutive5xxErrors: 3          # 3 consecutive 5xx responses
      consecutiveGatewayErrors: 3      # OR 3 consecutive gateway errors
      interval: 10s                    # Evaluate every 10s
      baseEjectionTime: 30s            # Eject for minimum 30s
      maxEjectionPercent: 100          # Allow ejecting all hosts if all are unhealthy
      # (With 100%, the circuit breaker "opens" completely)
      splitExternalLocalOriginErrors: true
      consecutiveLocalOriginFailures: 3
```

#### Fault Injection — Chaos Engineering

```yaml
# Inject a 5-second delay into 10% of requests to test timeout handling
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: recommendation-api-vs
  namespace: production
spec:
  hosts:
    - recommendation-api
  http:
    - fault:
        delay:
          percentage:
            value: 10.0          # Affect 10% of requests
          fixedDelay: 5s         # Inject 5-second delay

        # Also inject HTTP 503 errors for 2% of requests
        abort:
          percentage:
            value: 2.0
          httpStatus: 503

      route:
        - destination:
            host: recommendation-api

---
# Fault injection scoped to a specific user (header-based)
# Useful for targeted chaos testing without affecting real users
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: cart-api-vs
  namespace: production
spec:
  hosts:
    - cart-api
  http:
    # Inject fault only for requests with x-chaos-user header
    - match:
        - headers:
            x-chaos-user:
              exact: "test-user-chaos"
      fault:
        abort:
          httpStatus: 500
          percentage:
            value: 100.0         # 100% fault for this user
      route:
        - destination:
            host: cart-api

    # Normal traffic for all other users
    - route:
        - destination:
            host: cart-api
```

---

### 2.7 Observability — Kiali and Jaeger

#### Kiali — Service Mesh Topology Visualisation

Kiali provides a real-time graph of the service mesh — which services are communicating with which, the traffic rates and error rates on each connection, and the health of each service. It is the observability control plane for Istio.

```bash
# Install Kiali via Helm
helm repo add kiali https://kiali.org/helm-charts
helm repo update

helm install kiali-server kiali/kiali-server \
  --namespace istio-system \
  --version 1.86.0 \
  --set auth.strategy=anonymous \   # Use 'openid' in production
  --set external_services.prometheus.url=http://kube-prometheus-stack-prometheus.monitoring:9090 \
  --set external_services.tracing.in_cluster_url=http://tracing.istio-system:16685 \
  --set external_services.grafana.in_cluster_url=http://kube-prometheus-stack-grafana.monitoring:80

# Port-forward to access Kiali UI
kubectl port-forward svc/kiali -n istio-system 20001:20001
# Open: http://localhost:20001/kiali
```

```yaml
# KialiConfig — production Kiali configuration
apiVersion: kiali.io/v1alpha1
kind: Kiali
metadata:
  name: kiali
  namespace: istio-system
spec:
  auth:
    strategy: openid
    openid:
      client_id: kiali
      issuer_uri: https://auth.mycompany.com
      username_claim: email
      scopes: [openid, profile, email]

  external_services:
    prometheus:
      url: http://kube-prometheus-stack-prometheus.monitoring:9090
    grafana:
      enabled: true
      in_cluster_url: http://kube-prometheus-stack-grafana.monitoring:80
      url: https://grafana.mycompany.com
    tracing:
      enabled: true
      in_cluster_url: http://tempo.monitoring:16685
      use_grpc: true

  server:
    metrics_enabled: true
    metrics_port: 9090

  deployment:
    accessible_namespaces: ["production", "staging", "development"]
    replicas: 2                    # HA Kiali
    resources:
      requests:
        cpu: "100m"
        memory: "256Mi"
      limits:
        cpu: "500m"
        memory: "512Mi"
```

#### Istio Telemetry — Metrics, Tracing, Access Logs

```yaml
# Telemetry resource — configure metrics and tracing for the mesh
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: mesh-telemetry
  namespace: istio-system      # Mesh-wide configuration
spec:
  # Distributed tracing configuration
  tracing:
    - providers:
        - name: tempo           # Send traces to Tempo via OpenTelemetry
      randomSamplingPercentage: 1.0   # 1% sampling (adjust per traffic volume)
      disableSpanReporting: false
      customTags:
        cluster:
          literal:
            value: "production-eks"
        env:
          environment:
            name: APP_ENV
            defaultValue: "production"

  # Access log configuration
  accessLogging:
    - providers:
        - name: envoy
      disabled: false

  # Prometheus metrics
  metrics:
    - providers:
        - name: prometheus
      overrides:
        - match:
            metric: REQUEST_COUNT
            mode: CLIENT_AND_SERVER
          tagOverrides:
            # Remove high-cardinality labels that can cause prometheus memory issues
            destination_principal:
              operation: REMOVE
            source_principal:
              operation: REMOVE

---
# EnvoyFilter — customise Envoy configuration at a low level
# Use sparingly — requires deep Envoy knowledge
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: compress-response
  namespace: production
spec:
  workloadSelector:
    labels:
      app: order-api
  configPatches:
    - applyTo: HTTP_FILTER
      match:
        context: SIDECAR_INBOUND
        listener:
          portNumber: 8080
          filterChain:
            filter:
              name: "envoy.filters.network.http_connection_manager"
      patch:
        operation: INSERT_BEFORE
        value:
          name: envoy.filters.http.compressor
          typed_config:
            "@type": type.googleapis.com/envoy.extensions.filters.http.compressor.v3.Compressor
            response_direction_config:
              common_config:
                min_content_length: 1024
                content_type:
                  - application/json
              disable_on_etag_header: true
            compressor_library:
              name: gzip
              typed_config:
                "@type": type.googleapis.com/envoy.extensions.compression.gzip.compressor.v3.Gzip
```

---

### 2.8 Multi-Cluster Service Mesh

Istio supports multi-cluster federation — extending the service mesh across multiple Kubernetes clusters. This enables cross-cluster service discovery, failover, and load balancing.

```
Multi-Cluster Topology Options:

Primary-Remote (single control plane):
  Cluster 1 (primary):   Istiod control plane + workloads
  Cluster 2 (remote):    Only workloads (no Istiod)
  Cluster 1 Istiod manages both clusters
  Use case: Simple setup, single team managing multiple clusters

Multi-Primary (multiple control planes):
  Cluster 1 (primary):   Istiod + workloads
  Cluster 2 (primary):   Istiod + workloads
  Both Istiods are aware of each other's services
  Use case: HA, multi-region, independent clusters with shared mesh

External control plane:
  Control plane cluster:  Only Istiod (no workloads)
  Workload clusters:      Only workloads
  Use case: Centralised mesh management across many clusters
```

---

## 3. Istio Installation

### 3.1 Installation with istioctl

```bash
# Install istioctl
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.21.0 sh -
export PATH=$PWD/istio-1.21.0/bin:$PATH

# Verify compatibility
istioctl x precheck

# Install with the production profile (no demo add-ons)
# The 'default' profile enables: istiod + ingress gateway
istioctl install \
  --set profile=default \
  --set values.pilot.resources.requests.cpu=500m \
  --set values.pilot.resources.requests.memory=2048Mi \
  --set values.pilot.resources.limits.cpu=2000m \
  --set values.pilot.resources.limits.memory=4096Mi \
  --set values.pilot.replicaCount=2 \
  --set values.global.proxy.resources.requests.cpu=100m \
  --set values.global.proxy.resources.requests.memory=128Mi \
  --set values.global.proxy.resources.limits.cpu=500m \
  --set values.global.proxy.resources.limits.memory=256Mi \
  -y

# Verify installation
istioctl verify-install
kubectl get pods -n istio-system
# NAME                                     READY   STATUS    RESTARTS
# istio-ingressgateway-5d4f8b9c7-xk9p2    1/1     Running   0
# istio-ingressgateway-5d4f8b9c7-8vr2q    1/1     Running   0
# istiod-6d4f8b9c7-m9t7n                  1/1     Running   0
# istiod-6d4f8b9c7-4xk9p                  1/1     Running   0
```

### 3.2 Production IstioOperator Manifest

```yaml
# istio-production.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: production-istio
  namespace: istio-system
spec:
  profile: default
  hub: docker.io/istio
  tag: 1.21.0

  meshConfig:
    # Enable access logging to stdout (collected by Promtail/Fluentd)
    accessLogFile: /dev/stdout
    accessLogFormat: |
      {"start_time":"%START_TIME%","method":"%REQ(:METHOD)%","path":"%REQ(X-ENVOY-ORIGINAL-PATH?:PATH)%",
       "protocol":"%PROTOCOL%","response_code":"%RESPONSE_CODE%","duration_ms":"%DURATION%",
       "upstream_host":"%UPSTREAM_HOST%","x_forwarded_for":"%REQ(X-FORWARDED-FOR)%",
       "trace_id":"%REQ(X-B3-TRACEID)%","service":"%REQ(:AUTHORITY)%"}

    # Default proxy configuration
    defaultConfig:
      # Zipkin/Jaeger tracing endpoint
      tracing:
        sampling: 1.0          # 1% (increase for debugging, reduce for high-traffic prod)
        zipkin:
          address: tempo.monitoring:9411

      # Proxy access log format
      proxyMetadata:
        ISTIO_META_DNS_CAPTURE: "true"    # DNS-based service discovery (improves ServiceEntry reliability)
        ISTIO_META_PROXY_XDS_VIA_AGENT: "true"

    # mTLS mode for the mesh
    enableAutoMtls: true

    # Outbound traffic policy (REGISTRY_ONLY = block unknown external hosts)
    outboundTrafficPolicy:
      mode: REGISTRY_ONLY     # Only allow traffic to registered ServiceEntries
      # Use ALLOW_ANY during migration; REGISTRY_ONLY for strict zero-trust

    # Enable extensions
    extensionProviders:
      - name: tempo
        opentelemetry:
          service: opentelemetry-collector.monitoring
          port: 4317

  components:
    # Istiod (control plane)
    pilot:
      k8s:
        replicaCount: 2
        resources:
          requests:
            cpu: 500m
            memory: 2Gi
          limits:
            cpu: 2000m
            memory: 4Gi
        hpaSpec:
          maxReplicas: 5
          minReplicas: 2
          metrics:
            - type: Resource
              resource:
                name: cpu
                target:
                  type: Utilization
                  averageUtilization: 80
        podDisruptionBudget:
          minAvailable: 1

    # Ingress gateway
    ingressGateways:
      - name: istio-ingressgateway
        enabled: true
        k8s:
          replicaCount: 2
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 2000m
              memory: 1Gi
          hpaSpec:
            maxReplicas: 10
            minReplicas: 2
          service:
            type: LoadBalancer
            ports:
              - port: 15021
                targetPort: 15021
                name: status-port
              - port: 80
                targetPort: 8080
                name: http2
              - port: 443
                targetPort: 8443
                name: https

    # Egress gateway (optional — for controlled external access)
    egressGateways:
      - name: istio-egressgateway
        enabled: true
        k8s:
          replicaCount: 1
          resources:
            requests:
              cpu: 100m
              memory: 128Mi

  values:
    # Global sidecar proxy resource configuration
    global:
      proxy:
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 256Mi
        # Holddown period for graceful termination
        lifecycle:
          postStart:
            exec:
              command:
                - pilot-agent
                - wait
          preStop:
            exec:
              command:
                - /bin/sh
                - -c
                - sleep 5
      # Trust domain for SPIFFE certificates
      trustDomain: cluster.local
```

```bash
# Apply the production configuration
istioctl install -f istio-production.yaml -y

# Upgrade Istio to a new version (canary upgrade)
# Install new control plane alongside old
istioctl install \
  --set profile=default \
  --set revision=1-21-1    # Install as a new revision

# Migrate namespaces to new revision gradually
kubectl label namespace staging istio.io/rev=1-21-1 --overwrite
kubectl rollout restart deployment -n staging  # Restart to pick up new sidecar

# Verify all proxies on new version in staging
istioctl proxy-status -n staging | grep "1.21.1"

# Complete migration to production namespace
kubectl label namespace production istio.io/rev=1-21-1 --overwrite
kubectl rollout restart deployment -n production

# Remove old revision after migration
istioctl uninstall --revision=1-21-0 -y
```

---

## 4. Full Application Configuration

### 4.1 Complete E-Commerce Service Mesh

```yaml
# Complete Istio configuration for an e-commerce platform
# Services: api-gateway, order-api, payment-api, inventory-api, notification-svc

---
# ── Gateway ─────────────────────────────────────────────────────────
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: ecommerce-gw
  namespace: production
spec:
  selector:
    istio: ingressgateway
  servers:
    - port: {number: 80, name: http, protocol: HTTP}
      hosts: ["api.mycompany.com"]
      tls:
        httpsRedirect: true
    - port: {number: 443, name: https, protocol: HTTPS}
      hosts: ["api.mycompany.com"]
      tls:
        mode: SIMPLE
        credentialName: api-tls-cert

---
# ── VirtualService: api-gateway (main entry point) ─────────────────
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: api-gateway-vs
  namespace: production
spec:
  hosts:
    - "api.mycompany.com"
    - api-gateway
  gateways:
    - ecommerce-gw
    - mesh
  http:
    - match:
        - uri: {prefix: /api/v1/orders}
      route:
        - destination: {host: order-api, port: {number: 80}}
      timeout: 30s
      retries:
        attempts: 3
        perTryTimeout: 10s
        retryOn: "5xx,reset,connect-failure"

    - match:
        - uri: {prefix: /api/v1/payments}
      route:
        - destination:
            host: payment-api
            subset: stable
          weight: 100

    - match:
        - uri: {prefix: /api/v1/inventory}
      route:
        - destination: {host: inventory-api, port: {number: 80}}
      timeout: 10s

    - route:
        - destination: {host: api-gateway, port: {number: 80}}

---
# ── DestinationRule: order-api ──────────────────────────────────────
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: order-api-dr
  namespace: production
spec:
  host: order-api
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
    loadBalancer:
      simple: LEAST_CONN
    connectionPool:
      tcp: {maxConnections: 100}
      http: {http2MaxRequests: 500, maxRequestsPerConnection: 5}
    outlierDetection:
      consecutive5xxErrors: 5
      interval: 30s
      baseEjectionTime: 30s
      maxEjectionPercent: 50

---
# ── DestinationRule: payment-api with subsets ───────────────────────
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: payment-api-dr
  namespace: production
spec:
  host: payment-api
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
    loadBalancer:
      simple: LEAST_CONN
    connectionPool:
      tcp: {maxConnections: 50, connectTimeout: 30ms}
      http: {http2MaxRequests: 200}
    outlierDetection:
      consecutive5xxErrors: 3
      interval: 10s
      baseEjectionTime: 60s
      maxEjectionPercent: 100   # Open circuit completely on failures
  subsets:
    - name: stable
      labels: {version: stable}
    - name: canary
      labels: {version: canary}
      trafficPolicy:
        connectionPool:
          http: {http2MaxRequests: 50}

---
# ── ServiceEntry: external Stripe API ──────────────────────────────
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: stripe-api
  namespace: production
spec:
  hosts: [api.stripe.com]
  ports:
    - {number: 443, name: https, protocol: HTTPS}
  location: MESH_EXTERNAL
  resolution: DNS

---
# Egress VirtualService: apply retry and timeout to Stripe calls
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: stripe-egress-vs
  namespace: production
spec:
  hosts: [api.stripe.com]
  http:
    - route:
        - destination: {host: api.stripe.com, port: {number: 443}}
      timeout: 30s
      retries:
        attempts: 2
        perTryTimeout: 15s
        retryOn: "5xx,reset"

---
# ── mTLS Enforcement ────────────────────────────────────────────────
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: production
spec:
  mtls:
    mode: STRICT

---
# ── AuthorizationPolicies ───────────────────────────────────────────
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: production
spec: {}

---
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-ingress-to-api-gateway
  namespace: production
spec:
  selector:
    matchLabels:
      app: api-gateway
  action: ALLOW
  rules:
    - from:
        - source:
            principals: ["cluster.local/ns/istio-system/sa/istio-ingressgateway-service-account"]

---
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-api-gateway-to-services
  namespace: production
spec:
  action: ALLOW
  rules:
    - from:
        - source:
            principals: ["cluster.local/ns/production/sa/api-gateway-sa"]
      to:
        - operation:
            methods: ["GET", "POST", "PUT", "DELETE"]
```

---

## 5. Step-by-Step Hands-on Walkthrough

### 5.1 Deploy and Verify the Full Stack

```bash
# Step 1: Install Istio and enable injection
istioctl install -f istio-production.yaml -y
kubectl label namespace production istio-injection=enabled

# Step 2: Deploy the application
kubectl apply -k k8s/overlays/production

# Verify sidecars are injected (all pods should show 2/2 READY)
kubectl get pods -n production
# NAME                           READY   STATUS
# api-gateway-abc-123            2/2     Running
# order-api-def-456              2/2     Running
# payment-api-ghi-789            2/2     Running

# Step 3: Apply Istio configuration
kubectl apply -f istio/gateway.yaml
kubectl apply -f istio/virtualservices.yaml
kubectl apply -f istio/destinationrules.yaml
kubectl apply -f istio/security.yaml

# Step 4: Verify proxy status
istioctl proxy-status -n production
# All proxies should show SYNCED for CDS, LDS, EDS, RDS

# Step 5: Get the ingress gateway external IP
kubectl get svc istio-ingressgateway -n istio-system
GATEWAY_IP=$(kubectl get svc istio-ingressgateway -n istio-system \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Step 6: Test the application
curl -H "Host: api.mycompany.com" http://$GATEWAY_IP/api/v1/orders
```

### 5.2 Verify mTLS is Enforced

```bash
# Check mTLS status for all services
istioctl authn tls-check -n production

# Output:
# HOST:PORT                                STATUS  SERVER    CLIENT
# api-gateway.production:80               OK      mTLS      mTLS
# order-api.production:80                 OK      mTLS      mTLS
# payment-api.production:80               OK      mTLS      mTLS

# Verify a specific connection
istioctl authn tls-check \
  order-api-def-456.production \
  payment-api.production

# Try to connect without mTLS (should fail in STRICT mode)
kubectl run plaintext-test \
  --image=curlimages/curl \
  --restart=Never \
  --annotations="sidecar.istio.io/inject=false" \
  -n production \
  -- curl -v http://payment-api:80/health
# curl: (35) OpenSSL SSL_connect: Connection reset by peer
# ← Connection refused without valid mTLS cert

# Test connection FROM a properly meshed Pod (should work)
kubectl exec -n production deploy/order-api \
  -- curl -s http://payment-api/health
# {"status":"ok"} ← Works because Envoy handles mTLS automatically

# Inspect the certificate Envoy is using
kubectl exec -n production order-api-def-456 \
  -c istio-proxy \
  -- openssl s_client \
    -connect payment-api:80 \
    -showcerts 2>/dev/null | \
  openssl x509 -noout -subject -issuer
# subject=URI:spiffe://cluster.local/ns/production/sa/order-api-sa
# issuer=O=cluster.local
```

### 5.3 Traffic Shifting — Canary Deployment

```bash
# Initial state: 100% traffic to stable
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: payment-api-vs
  namespace: production
spec:
  hosts:
    - payment-api
  http:
    - route:
        - destination:
            host: payment-api
            subset: stable
          weight: 100
        - destination:
            host: payment-api
            subset: canary
          weight: 0
EOF

# Deploy canary version (add version: canary label to some pods)
kubectl set image deployment/payment-api-canary \
  payment-api=ghcr.io/myorg/payment-api:2.1.0-rc1 \
  -n production

# Shift 5% of traffic to canary
kubectl patch virtualservice payment-api-vs -n production \
  --type=merge \
  -p '{"spec":{"http":[{"route":[{"destination":{"host":"payment-api","subset":"stable"},"weight":95},{"destination":{"host":"payment-api","subset":"canary"},"weight":5}]}]}}'

# Monitor error rates in real time
watch -n 5 "kubectl exec -n production deploy/api-gateway \
  -- curl -s http://payment-api/metrics | \
  grep 'http_requests_total'"

# Check Kiali for the traffic split visualisation
kubectl port-forward svc/kiali -n istio-system 20001:20001 &
open http://localhost:20001/kiali/console/graph/namespaces/

# Progressively shift more traffic
for WEIGHT in 10 20 50 100; do
  STABLE=$((100 - WEIGHT))
  kubectl patch virtualservice payment-api-vs -n production \
    --type=json \
    -p "[
      {\"op\":\"replace\",\"path\":\"/spec/http/0/route/0/weight\",\"value\":$STABLE},
      {\"op\":\"replace\",\"path\":\"/spec/http/0/route/1/weight\",\"value\":$WEIGHT}
    ]"
  echo "Shifted to $WEIGHT% canary"
  sleep 300    # Wait 5 minutes between steps
done
```

### 5.4 Chaos Engineering — Fault Injection

```bash
# Experiment 1: Inject a 3-second delay into 50% of requests to inventory-api
# Goal: Verify that order-api handles inventory timeouts gracefully
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: inventory-chaos-vs
  namespace: production
spec:
  hosts:
    - inventory-api
  http:
    - fault:
        delay:
          percentage:
            value: 50.0
          fixedDelay: 3s
      route:
        - destination:
            host: inventory-api
EOF

# Run requests and observe the impact
kubectl run chaos-test \
  --image=curlimages/curl \
  --restart=Never \
  -n production \
  -- sh -c "
    for i in \$(seq 1 20); do
      START=\$(date +%s%3N)
      STATUS=\$(curl -s -o /dev/null -w '%{http_code}' http://order-api/api/v1/orders)
      END=\$(date +%s%3N)
      echo \"Request \$i: status=\$STATUS time=\$((END-START))ms\"
    done
  "

# Observe in Grafana: P99 latency should spike for inventory calls
# Observe in Kiali: connection health between order-api and inventory-api degrades
# Verify: order-api should timeout gracefully (not cascade the failure)

# Clean up fault injection
kubectl delete virtualservice inventory-chaos-vs -n production

# Experiment 2: Inject 503 errors to test circuit breaker
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: notification-chaos-vs
  namespace: production
spec:
  hosts:
    - notification-svc
  http:
    - fault:
        abort:
          percentage:
            value: 80.0
          httpStatus: 503
      route:
        - destination:
            host: notification-svc
EOF

# Watch the circuit breaker open in the DestinationRule outlier detection
# After 3 consecutive 503s, notification-svc should be ejected from the pool
# Order-api should continue working (notifications are async)

kubectl exec -n production deploy/order-api \
  -c istio-proxy \
  -- pilot-agent request GET stats | \
  grep "outlier_detection.ejections_active"
# cluster.outbound|80||notification-svc.production.svc.cluster.local.outlier_detection.ejections_active: 1

kubectl delete virtualservice notification-chaos-vs -n production
```

---

## 6. Multi-Cluster Service Mesh

### 6.1 Multi-Primary Multi-Network Setup

```bash
# Scenario: Two EKS clusters (us-east-1, eu-west-1)
# Each has its own Istiod control plane
# Services can call each other across clusters transparently

# ── Cluster 1 (us-east-1) setup ──────────────────────────────────────
# Set context for cluster 1
kubectl config use-context eks-us-east-1

# Install Istio as primary cluster
cat > cluster1.yaml << 'EOF'
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  values:
    global:
      meshID: mesh1
      multiCluster:
        clusterName: cluster1-us-east-1
      network: network1
EOF

istioctl install -f cluster1.yaml --context eks-us-east-1 -y

# Install east-west gateway (handles cross-cluster traffic)
istioctl install \
  --set profile=empty \
  --set values.gateways.istio-ingressgateway.name=istio-eastwestgateway \
  --set values.global.meshID=mesh1 \
  --set values.global.multiCluster.clusterName=cluster1-us-east-1 \
  --set values.global.network=network1 \
  --context eks-us-east-1 \
  -y

# Expose all services via the east-west gateway
kubectl apply -n istio-system \
  -f https://raw.githubusercontent.com/istio/istio/release-1.21/samples/multicluster/expose-services.yaml \
  --context eks-us-east-1

# ── Cluster 2 (eu-west-1) setup ──────────────────────────────────────
kubectl config use-context eks-eu-west-1

cat > cluster2.yaml << 'EOF'
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  values:
    global:
      meshID: mesh1
      multiCluster:
        clusterName: cluster2-eu-west-1
      network: network2
EOF

istioctl install -f cluster2.yaml --context eks-eu-west-1 -y

istioctl install \
  --set profile=empty \
  --set values.gateways.istio-ingressgateway.name=istio-eastwestgateway \
  --set values.global.meshID=mesh1 \
  --set values.global.multiCluster.clusterName=cluster2-eu-west-1 \
  --set values.global.network=network2 \
  --context eks-eu-west-1 \
  -y

kubectl apply -n istio-system \
  -f https://raw.githubusercontent.com/istio/istio/release-1.21/samples/multicluster/expose-services.yaml \
  --context eks-eu-west-1

# ── Enable endpoint discovery between clusters ──────────────────────
# Create remote secrets (allows each Istiod to discover endpoints in the other cluster)
istioctl create-remote-secret \
  --context eks-us-east-1 \
  --name cluster1-us-east-1 | \
  kubectl apply -f - --context eks-eu-west-1

istioctl create-remote-secret \
  --context eks-eu-west-1 \
  --name cluster2-eu-west-1 | \
  kubectl apply -f - --context eks-us-east-1
```

### 6.2 Cross-Cluster Failover

```yaml
# DestinationRule with locality-weighted load balancing and failover
# Primary: serve from local cluster; Failover: route to remote cluster
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: order-api-multicluster
  namespace: production
spec:
  host: order-api
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
    loadBalancer:
      # Distribute load based on cluster locality
      localityLbSetting:
        enabled: true
        # Distribute within region first, fail over to other region
        distribute:
          - from: "us-east-1/*"
            to:
              "us-east-1/*": 90        # 90% to local us-east-1 instances
              "eu-west-1/*": 10        # 10% to eu-west-1 (warm standby)
          - from: "eu-west-1/*"
            to:
              "eu-west-1/*": 90
              "us-east-1/*": 10
        failover:
          - from: us-east-1            # If us-east-1 is unavailable
            to: eu-west-1             # Fail over to eu-west-1
          - from: eu-west-1
            to: us-east-1
    outlierDetection:
      consecutive5xxErrors: 3
      interval: 10s
      baseEjectionTime: 30s

---
# VirtualService with cross-cluster header injection for observability
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: order-api-multicluster-vs
  namespace: production
spec:
  hosts:
    - order-api
  http:
    - route:
        - destination:
            host: order-api
      headers:
        request:
          set:
            x-served-by-cluster: "{{cluster_name}}"
      retries:
        attempts: 3
        perTryTimeout: 10s
        retryOn: "5xx,reset,connect-failure"
```

---

## 7. Observability Deep Dive

### 7.1 Istio Metrics — The Standard Dashboard

```bash
# Istio automatically generates metrics for every proxied connection
# Key metrics exposed by the Envoy proxy:

# Request rate per service
istio_requests_total{reporter="destination", destination_service_name="order-api"}

# P99 latency
histogram_quantile(0.99,
  sum(irate(istio_request_duration_milliseconds_bucket{
    destination_service_name="order-api",
    response_code!~"5.."
  }[1m])) by (le)
)

# Error rate per service pair
sum(irate(istio_requests_total{
  reporter="source",
  destination_service_name="payment-api",
  response_code=~"5.."
}[5m])) /
sum(irate(istio_requests_total{
  reporter="source",
  destination_service_name="payment-api"
}[5m]))

# Active TCP connections
sum(istio_tcp_connections_opened_total) by (destination_service_name)

# Monitor mTLS enforcement
sum(istio_requests_total{
  connection_security_policy="mutual_tls"
}) /
sum(istio_requests_total) * 100
# Should be 100% when STRICT mTLS is enforced
```

### 7.2 Kiali Service Graph Queries

```bash
# Port-forward Kiali
kubectl port-forward svc/kiali -n istio-system 20001:20001

# Kiali REST API for programmatic access
# Get service topology
curl -s "http://localhost:20001/kiali/api/namespaces/production/graph" \
  -H "Content-Type: application/json" | \
  jq '.elements.nodes[] | select(.data.nodeType=="service") | .data.service'

# Check health of all services
curl -s "http://localhost:20001/kiali/api/namespaces/production/health" | \
  jq '.workloadStatuses | to_entries[] | {service: .key, health: .value}'
```

### 7.3 Debugging with istioctl

```bash
# Analyse the mesh configuration for issues
istioctl analyze -n production
# Checking 12 objects across 1 namespaces and cluster scoped resources...
# ✔ No validation issues found when analyzing namespace: production.

# Trace a specific request through the mesh
istioctl x injected-envoy-config \
  order-api-def-456.production \
  -o json | \
  jq '.dynamicActiveListeners[] | .listener.address'

# Check what routes Envoy knows about
istioctl proxy-config routes order-api-def-456.production

# Check what clusters (upstream services) are configured
istioctl proxy-config clusters order-api-def-456.production

# Check current endpoints for the payment-api cluster
istioctl proxy-config endpoints order-api-def-456.production \
  --cluster "outbound|80||payment-api.production.svc.cluster.local"

# Log level adjustment for debugging (temporary)
istioctl proxy-config log order-api-def-456.production \
  --level debug

# Restore normal log level
istioctl proxy-config log order-api-def-456.production \
  --level warning
```

---

## 8. Real-World Scenario: Global E-Commerce Platform with Istio

### The Problem

MegaShop operates a global e-commerce platform with 200+ microservices across three AWS regions. Their architecture evolved organically over 5 years, resulting in:

- **No service-to-service encryption**: an internal security audit found 47 service pairs communicating over plain HTTP, including the payment service calling the fraud detection API
- **Inconsistent resilience**: 12 services had their own retry logic implemented differently; 6 services had no timeout configuration at all, causing cascading failures during Black Friday
- **Invisible service graph**: 23 engineers were asked to map service dependencies; they produced 23 different diagrams
- **Fragile deployments**: new service versions were deployed as Deployment updates; a bad payment-api deploy in November brought down checkout for 14 minutes

### The Istio Migration Path

**Phase 1 (Weeks 1-2): Install and observe, inject nothing**

```bash
# Install Istio in ambient mode observation first
# (ambient mode = no sidecars, just L4 monitoring)
istioctl install --set profile=ambient -y

# Instrument namespace for L4 observation
kubectl label namespace production istio.io/dataplane-mode=ambient

# Observe traffic patterns for 2 weeks before any policy changes
# This produced the "authoritative" service dependency map MegaShop never had
```

**Phase 2 (Weeks 3-4): Enable sidecar injection, PERMISSIVE mTLS**

```bash
kubectl label namespace production istio-injection=enabled
kubectl rollout restart deployment -n production

# Apply PERMISSIVE mTLS first (accepts both plain and mTLS)
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: production
spec:
  mtls:
    mode: PERMISSIVE
EOF
```

**Phase 3 (Week 5): Validate, then enforce STRICT mTLS**

```bash
# Verify 100% of traffic is using mTLS (via Kiali metrics)
# Before switching to STRICT
MTLS_PCT=$(kubectl exec -n monitoring deploy/prometheus \
  -- promtool query instant \
  'sum(istio_requests_total{connection_security_policy="mutual_tls",reporter="destination",namespace="production"}) / sum(istio_requests_total{reporter="destination",namespace="production"}) * 100' | \
  jq -r '.[0].value[1]')

echo "mTLS percentage: $MTLS_PCT%"
# Should be 100.0% before proceeding

kubectl patch peerauthentication default -n production \
  --type=merge \
  -p '{"spec":{"mtls":{"mode":"STRICT"}}}'
```

**Phase 4 (Week 6): Progressive delivery with Argo Rollouts + Istio**

All Deployments converted to Rollouts with Istio VirtualService traffic splitting (Chapter 12 canary pattern). The Black Friday deploy that would have taken 14 minutes to roll back now takes 45 seconds.

### Results

| Problem | Before Istio | After Istio |
|---|---|---|
| Service-to-service encryption | 0% (plain HTTP everywhere) | 100% mTLS (STRICT) |
| Consistency of retry logic | 12 different implementations | 1 (VirtualService, uniform) |
| Services with no timeout | 6 | 0 |
| Time to generate service dependency map | 1 week, 23 different answers | 5 seconds (Kiali) |
| Deployment rollback time (bad deploy) | 14 minutes | 45 seconds |
| Black Friday cascading failure incidents | 3 in previous year | 0 |
| Certificate rotation operational burden | Manual, quarterly | Automatic, daily |

---

## 9. Common Pitfalls & Best Practices

### Pitfall 1: Starting with STRICT mTLS on Day One
Enabling STRICT mTLS immediately means any service without a sidecar (DaemonSets, Jobs, external services) immediately loses connectivity. The migration path must always be PERMISSIVE first, validate 100% mTLS coverage via metrics, then switch to STRICT. Rushing to STRICT breaks production.

### Pitfall 2: No `outboundTrafficPolicy: REGISTRY_ONLY`
By default, Istio allows Pods to call any external address not in the mesh (`ALLOW_ANY`). This means a compromised container can exfiltrate data to any IP. Setting `outboundTrafficPolicy: REGISTRY_ONLY` blocks all outbound traffic except to registered ServiceEntries — implementing network egress control at the mesh level.

### Pitfall 3: Sidecar Resource Starvation
Each Envoy sidecar consumes CPU and memory from the node. In a cluster with 500 Pods, that is 500 additional containers. Without resource requests/limits on the sidecar proxy, Pods can be scheduled onto nodes that appear to have capacity but run out of resources when the sidecars are injected. Always configure `global.proxy.resources.requests` and `limits` in the IstioOperator.

### Pitfall 4: VirtualService Without a Corresponding DestinationRule
A VirtualService that references a `subset` (e.g. `subset: canary`) without a corresponding DestinationRule that defines that subset will result in `503 No healthy upstream` errors. Every subset referenced in a VirtualService must be defined in the DestinationRule for the same host.

### Pitfall 5: Fault Injection Left On in Production
Fault injection (`VirtualService.http.fault`) is a chaos engineering tool for testing. Teams occasionally leave delay or abort faults active after testing, causing degraded service or elevated error rates. Treat fault injection resources as temporary — use Git PR reviews and auto-expiring annotations to prevent them from lingering in production.

### Pitfall 6: Ignoring Proxy Synchronisation Lag
When Istiod pushes configuration changes, Envoy proxies receive updates asynchronously. During a canary deployment, there can be a brief window where some proxies have the new routing rules and some do not, leading to inconsistent traffic distribution. Use `istioctl proxy-status` to verify all proxies are SYNCED before declaring a traffic shift complete.

> **Istio Production Readiness Checklist**
> - [ ] Istio installed with production profile (HA Istiod: ≥2 replicas)
> - [ ] Sidecar resource requests and limits configured
> - [ ] Namespace injection enabled only for namespaces that need the mesh
> - [ ] mTLS migration: PERMISSIVE → validate → STRICT
> - [ ] `outboundTrafficPolicy: REGISTRY_ONLY` enabled; all external hosts registered as ServiceEntries
> - [ ] AuthorizationPolicy `deny-all` in production namespaces; explicit allows for each connection
> - [ ] VirtualService timeouts configured for every external-facing service
> - [ ] Retry policies configured; `perTryTimeout < timeout / attempts`
> - [ ] DestinationRule outlier detection configured for all services
> - [ ] All subsets in VirtualServices have matching DestinationRule definitions
> - [ ] Kiali deployed with Prometheus and Tempo datasources linked
> - [ ] Telemetry resource configured with appropriate sampling rate
> - [ ] Canary Rollouts use Istio VirtualService for precise traffic splitting
> - [ ] Fault injection tests documented; automated cleanup enforced via CI
> - [ ] `istioctl analyze` runs in CI pipeline to catch configuration errors

---

## 10. Key Takeaways

1. **Istio moves networking logic from application code to infrastructure.** Retries, timeouts, circuit breaking, mTLS, and traffic splitting are now Kubernetes CRD configurations applied by platform engineers — not library code embedded in each service by developers. This makes networking behaviour consistent across all services, languages, and runtimes.

2. **The xDS API is the mechanism that makes Istio work.** Istiod continuously pushes Listener, Route, Cluster, and Endpoint configuration to Envoy proxies via gRPC streaming. Understanding this model explains why configuration changes take a few seconds to propagate, why `istioctl proxy-status` shows SYNCED/STALE states, and why proxy synchronisation must be verified after changes.

3. **mTLS with AuthorizationPolicies implements zero-trust networking.** With STRICT mTLS and deny-all AuthorizationPolicies, every service connection requires a valid Istio certificate (proving identity) and an explicit allow rule (proving authorisation). This eliminates entire attack vectors — a compromised container cannot reach the payment service without an explicit policy allowing it.

4. **Fault injection is a first-class Istio feature, not a hack.** The ability to inject delays and HTTP errors via VirtualService resources enables systematic chaos engineering — validating that timeouts are configured correctly, that circuit breakers open when expected, and that degraded dependencies do not cascade into full system failures.

5. **Kiali's service graph is the authoritative source of truth for service dependencies.** Built from real traffic data rather than documentation, the Kiali topology graph shows which services are actually communicating, at what rate, with what error rate — something no amount of architecture documentation can match in accuracy.

6. **Multi-cluster federation extends the zero-trust security model across regions.** With multi-primary Istio, a service in us-east-1 calling a service in eu-west-1 uses the same mTLS certificate infrastructure, the same AuthorizationPolicies, and the same traffic management rules. Geographic distribution becomes a configuration detail, not an architectural discontinuity.

---

## 11. Exercises & Labs

**Exercise 1: Istio Installation and Sidecar Injection**
Install Istio on a test cluster using the `default` profile. Enable sidecar injection for a namespace. Deploy a two-service application (a frontend and an API backend). Verify: (a) both Pods show 2/2 READY, (b) `istioctl proxy-status` shows all proxies SYNCED, (c) `istioctl analyze` reports no errors. Run a request from the frontend to the backend and observe the trace in Jaeger/Tempo.

**Exercise 2: Traffic Shifting with Canary**
Deploy two versions of a service with `version: stable` and `version: canary` labels. Create a DestinationRule with two subsets. Create a VirtualService that starts with 100% stable. Gradually shift traffic to 10%, 30%, 50%, and 100% canary by updating the VirtualService weights. After each shift, use Kiali to visualise the traffic distribution and verify it matches the configured weights.

**Exercise 3: mTLS End-to-End**
Apply a PERMISSIVE PeerAuthentication to your namespace. Verify both mTLS and plain-text requests succeed. Then switch to STRICT. Verify: (a) mTLS requests from meshed Pods still work, (b) plain-text requests from a non-meshed Pod (sidecar.istio.io/inject: "false") are rejected with a connection error. Use `istioctl authn tls-check` to confirm all connections show `mTLS`.

**Exercise 4: Fault Injection Chaos Test**
Deploy a three-service chain (A → B → C). Configure service A with a 3-second timeout on calls to B. Inject a 5-second delay into 100% of requests to B using a VirtualService fault. Verify that: (a) service A returns a 504 timeout error rather than waiting indefinitely, (b) the error is visible in the Kiali service graph as increased latency on the A→B edge, (c) removing the fault injection returns latency to normal. Document the circuit breaker behaviour.

**Exercise 5: AuthorizationPolicy Zero-Trust Rollout**
In a test namespace, apply a `deny-all` AuthorizationPolicy. Verify all inter-service communication breaks. Then add explicit allow policies one connection at a time (frontend → API, API → database, monitoring → all services on `/metrics`). Verify each connection works after its policy is applied. Use `kubectl auth can-i` (Kubernetes RBAC) and Istio `authz check` (`istioctl x authz check <pod>`) to audit the final policy set.

---

## Appendix: Book Completion Summary

You have reached the end of **Mastering DevOps in Kubernetes**. Across thirteen chapters, this book has built a complete, production-grade understanding of the entire Kubernetes ecosystem:

| Chapter | Core Skill |
|---|---|
| 1 | DevOps philosophy, GitOps principles, the 12-Factor App |
| 2 | Docker internals, multi-stage builds, OCI registries, CRI |
| 3 | Core Kubernetes objects, autoscaling, kubectl mastery |
| 4 | Stateful workloads, PVCs, StorageClasses, PostgreSQL, Kafka |
| 5 | Amazon EKS, VPC CNI, IRSA, ALB Controller, CloudWatch |
| 6 | Azure AKS, Azure CNI, Workload Identity, KEDA, Azure DevOps |
| 7 | Google GKE, Autopilot, Dataplane V2, Cloud Armor, Cloud Build |
| 8 | kubeadm, etcd backup/restore, RBAC, Admission Controllers, troubleshooting |
| 9 | 4Cs security, PSA, NetworkPolicy, Vault, Trivy, Falco, CIS Benchmark |
| 10 | Prometheus, Grafana, Loki, Tempo, Alertmanager, SLO dashboards |
| 11 | Helm, Kustomize, Argo CD, Flux CD, progressive delivery |
| 12 | GitHub Actions, Jenkins X, CI/CD pipelines, Argo Rollouts |
| 13 | Istio architecture, mTLS, traffic management, chaos engineering, multi-cluster |

---

*End of Chapter 13 — End of Book*

*Thank you for reading Mastering DevOps in Kubernetes.*



---

# Appendix — Book Summary

## Chapter Reference

| Ch | Title | Key Technologies |
|---|---|---|
| 1 | DevOps for Kubernetes | DevOps philosophy, GitOps, 12-Factor App, IaC |
| 2 | Container Management with Docker | Docker, multi-stage builds, OCI, containerd, CRI |
| 3 | Standard Kubernetes Operations | Pods, Deployments, Services, HPA, KEDA, kubectl |
| 4 | Stateful Workloads | StatefulSets, PV/PVC, StorageClasses, PostgreSQL, Kafka |
| 5 | Amazon EKS | EKS, VPC CNI, IRSA, ALB Controller, EBS/EFS CSI, CloudWatch |
| 6 | Azure AKS | AKS, Azure CNI, Workload Identity, KEDA, Azure DevOps |
| 7 | Google GKE | GKE, Autopilot, NAP, Dataplane V2, Cloud Armor, Cloud Build |
| 8 | Kubernetes Administrator | kubeadm, etcd, certificates, RBAC, Admission Controllers |
| 9 | Kubernetes Security | PSA, NetworkPolicy, Vault, Sealed Secrets, Trivy, Falco |
| 10 | Monitoring | Prometheus, Grafana, Loki, Tempo, Alertmanager, SLOs |
| 11 | Packaging and Deploying | Helm, Kustomize, Argo CD, Flux CD, Argo Rollouts |
| 12 | CI/CD | GitHub Actions, Jenkins X, Cosign, Argo Rollouts, canary |
| 13 | Istio Service Mesh | Istio, Envoy, mTLS, VirtualService, Kiali, multi-cluster |

## Key Tools Reference

| Tool | Category | Chapter |
|---|---|---|
| `kubectl` | CLI / cluster management | 3, 8 |
| `kubeadm` | Cluster bootstrapping | 8 |
| `helm` | Package manager | 11 |
| `kustomize` | Configuration management | 11 |
| `eksctl` | EKS provisioning | 5 |
| `istioctl` | Istio management | 13 |
| Argo CD | GitOps controller | 11, 12 |
| Flux CD | GitOps controller | 11 |
| Argo Rollouts | Progressive delivery | 11, 12 |
| Prometheus | Metrics | 10 |
| Grafana | Dashboards | 10 |
| Loki | Log aggregation | 10 |
| Grafana Tempo | Distributed tracing | 10 |
| Falco | Runtime security | 9 |
| Trivy | Image scanning | 9, 12 |
| HashiCorp Vault | Secrets management | 9 |
| Sealed Secrets | GitOps secrets | 9, 11 |
| External Secrets Operator | Secrets sync | 9 |
| cert-manager | TLS automation | 5, 6 |
| CloudNativePG | PostgreSQL operator | 4 |
| Strimzi | Kafka operator | 4 |
| KEDA | Event-driven autoscaling | 3, 6 |
| kube-bench | CIS benchmark | 9 |
| Kyverno | Policy engine | 9, 11, 12 |
| OPA Gatekeeper | Policy engine | 8, 9 |
| OpenTelemetry | Telemetry SDK | 10, 13 |
| Cosign | Image signing | 12 |
| Kiali | Service mesh UI | 13 |

---

*End of Mastering DevOps in Kubernetes*
