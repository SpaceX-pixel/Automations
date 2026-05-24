# Chapter 9 — Kubernetes Security

> *Mastering DevOps in Kubernetes*
> 4Cs · Pod Security · NetworkPolicy · Secrets Management · Image Scanning · Runtime Security · CIS Benchmarks

---

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
