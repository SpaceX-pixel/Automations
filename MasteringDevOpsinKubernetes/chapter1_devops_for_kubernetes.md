# Chapter 1 — DevOps for Kubernetes

> *Mastering DevOps in Kubernetes*
> Philosophy · Principles · Toolchain

---

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
