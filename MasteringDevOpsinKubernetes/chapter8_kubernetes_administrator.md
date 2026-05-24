# Chapter 8 — Kubernetes Administrator

> *Mastering DevOps in Kubernetes*
> kubeadm · etcd · Certificates · Node Maintenance · Upgrades · RBAC · Admission Controllers · Troubleshooting

---

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
┌────────────────────────────────────────────────────────────────────────────┐
│  Control Plane Node                                                        │
│                                                                            │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │  kube-apiserver                                                      │  │
│  │  Port: 6443 (HTTPS)                                                  │  │
│  │  The single entry point for all cluster operations.                  │  │
│  │  Authenticates requests → Authorizes (RBAC) → Admission control      │  │
│  │  → Validates → Persists to etcd                                      │  │
│  └───────────────┬───────────────────────┬───────────────────────────────┘ │
│                  │                       │                                 │
│  ┌───────────────▼──────┐  ┌────────────▼──────────────────────────────┐   │
│  │  etcd                │  │  kube-scheduler                            │  │
│  │  Port: 2379 (client) │  │  Watches for Pending Pods.                 │  │
│  │  Port: 2380 (peer)   │  │  Scores nodes, assigns Pod to best fit.    │  │
│  │  Distributed KV      │  │  Writes nodeName to Pod spec via apiserver.│  │
│  │  Raft consensus      │  └────────────────────────────────────────────┘  │
│  │  All cluster state   │                                                  │
│  └──────────────────────┘  ┌────────────────────────────────────────────┐  │
│                             │  kube-controller-manager                   │ │
│                             │  Runs control loops:                       │ │
│                             │  Node Controller: detects node failures    │ │
│                             │  ReplicaSet Controller: maintains counts   │ │
│                             │  Endpoint Controller: updates ep slices    │ │
│                             │  Job Controller: manages Job completion    │ │
│                             └────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────────────┐
│  Worker Node                                                              │
│                                                                           │
│  ┌──────────────────────────────────┐  ┌──────────────────────────────┐   │
│  │  kubelet                         │  │  kube-proxy                  │   │
│  │  Registers node with apiserver.  │  │  Watches Service/Endpoint    │   │
│  │  Ensures Pods match their spec.  │  │  objects. Maintains iptables │   │ 
│  │  Reports node and Pod status.    │  │  or ipvs rules for Service   │   │
│  │  Runs liveness/readiness probes. │  │  routing.                    │   │
│  └──────────────────────────────────┘  └──────────────────────────────┘   │
└───────────────────────────────────────────────────────────────────────────┘
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
┌────────────────────────────────────────────────────────────────────────┐
│                                                                        │
│  Role / ClusterRole                                                    │
│  (defines permissions — "what can be done")                            │
│                                                                        │
│  ┌──────────────────────┐    ┌───────────────────────────────────────┐ │
│  │  Role                │    │  ClusterRole                          │ │
│  │  Namespace-scoped    │    │  Cluster-scoped OR usable across      │ │
│  │  Permissions on      │    │  namespaces via ClusterRoleBinding    │ │
│  │  namespaced resources│    │  Permissions on non-namespaced        │ │
│  └──────────────────────┘    │  resources (nodes, PVs, CRDs)         │ │
│                               └──────────────────────────────────────┘ │
│                                                                        │
│  RoleBinding / ClusterRoleBinding                                      │
│  (grants permissions — "who can do it and where")                      │
│                                                                        │
│  ┌──────────────────────┐    ┌──────────────────────────────────────┐  │
│  │  RoleBinding         │    │  ClusterRoleBinding                  │  │
│  │  Namespace-scoped    │    │  Grants ClusterRole across ALL       │  │
│  │  Can bind: Role or   │    │  namespaces — use with extreme care  │  │
│  │  ClusterRole         │    │                                      │  │
│  └──────────────────────┘    └──────────────────────────────────────┘  │
│                                                                        │
│  Subjects (who receives the permissions)                               │
│  ├── User        (human, authenticated by cert CN or OIDC sub)         │
│  ├── Group       (authenticated by cert O or OIDC groups claim)        │
│  └── ServiceAccount (Pod identity; namespace-scoped)                   │
└────────────────────────────────────────────────────────────────────────┘
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
