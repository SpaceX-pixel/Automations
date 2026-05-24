# Chapter 3 — Speeding Up with Standard Kubernetes Operations

> *Mastering DevOps in Kubernetes*
> Pods · Deployments · Services · Config · Autoscaling · kubectl Mastery

---

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
