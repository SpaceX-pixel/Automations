# Chapter 11 — Packaging and Deploying in Kubernetes

> *Mastering DevOps in Kubernetes*
> Helm · Kustomize · OCI Registries · Argo CD · Flux CD · Multi-Environment GitOps

---

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
