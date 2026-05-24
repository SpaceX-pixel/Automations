# Chapter 4 — Stateful Workloads in Kubernetes

> *Mastering DevOps in Kubernetes*
> StatefulSets · Persistent Volumes · StorageClasses · PostgreSQL · Kafka

---

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
