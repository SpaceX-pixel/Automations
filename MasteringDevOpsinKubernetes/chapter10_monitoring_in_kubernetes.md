# Chapter 10 — Monitoring in Kubernetes

> *Mastering DevOps in Kubernetes*
> Prometheus · Grafana · Loki · Tempo · Alertmanager · kube-state-metrics · SLO/SLA

---

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
│                    The Three Pillars of Observability                   │
│                                                                         │
│  METRICS              LOGS                   TRACES                     │
│  ─────────────────    ─────────────────       ─────────────────         │
│                                                                         │
│  Numerical time       Discrete timestamped    End-to-end request        │
│  series data          event records           execution paths           │
│                                                                         │
│  "What is the         "What happened          "Why did this             │
│   request rate?"       and when?"              request take 4s?"        │
│                                                                         │
│  Tool: Prometheus     Tool: Loki              Tool: Tempo/Jaeger        │
│                                                                         │
│  Cardinality:         Volume:                  Sampling:                │
│  Low (labels)         High (all events)        High overhead            │
│  Fast queries         Slow full-text           (head sampling           │
│  Aggregatable         search                    or tail sampling)       │
│                                                                         │
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
│  Prometheus Server                                                   │
│                                                                      │
│  ┌────────────────────┐   ┌──────────────────────────────────────┐   │
│  │  Service Discovery  │   │  Storage (TSDB)                     │   │
│  │  ├── Kubernetes API │   │  Local: 15-day retention default    │   │
│  │  ├── ServiceMonitor │   │  Remote write → Thanos/Cortex/Mimir │   │
│  │  └── PodMonitor     │   │  for long-term storage              │   │
│  └────────┬────────────┘   └─────────────────────────────────────┘   │
│           │                                                          │
│  ┌────────▼────────────────────────────────────────────────────────┐ │
│  │  Scrape Engine (pull model)                                     │ │
│  │  GET /metrics every 15-30s from discovered targets              │ │
│  └────────┬────────────────────────────────────────────────────────┘ │
│           │                                                          │
│  ┌────────▼────────┐   ┌──────────────────────────────────────────┐  │
│  │  Rule Evaluation│   │  Alertmanager                            │  │
│  │  Recording rules│──▶│  Route → deduplicate → inhibit → silence │  │
│  │  Alerting rules │   │  Notify → Slack/PagerDuty/Email/webhook  │  │
│  └─────────────────┘   └──────────────────────────────────────────┘  │
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
│  Log Collection                                                      │
│                                                                      │
│  Promtail (DaemonSet)  ─────▶  Loki Distributor                      │
│  (tails /var/log/containers)          │                              │
│                                       ▼                              │
│  OpenTelemetry Collector ──▶  Loki Ingester (in-memory buffer)       │
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
