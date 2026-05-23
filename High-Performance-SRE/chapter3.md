

# Chapter 3 — Monitoring

---

## Table of Contents

- [Learning Objectives](#learning-objectives)
- [Core Concepts](#core-concepts)
  - [3.1 Monitoring vs Observability — The Crucial Distinction](#31-monitoring-vs-observability)
  - [3.2 The Three Pillars of Observability](#32-three-pillars)
  - [3.3 The Four Golden Signals](#33-four-golden-signals)
  - [3.4 The USE Method](#34-use-method)
  - [3.5 The RED Method](#35-red-method)
  - [3.6 Choosing the Right Method](#36-choosing-the-right-method)
  - [3.7 Alerting Philosophy — Alerting on Symptoms, Not Causes](#37-alerting-philosophy)
  - [3.8 Dashboard Design for SREs](#38-dashboard-design)
  - [3.9 Prometheus — The SRE Metrics Engine](#39-prometheus)
  - [3.10 Grafana — Visualization and SLO Dashboards](#310-grafana)
  - [3.11 OpenTelemetry — The Unified Observability Standard](#311-opentelemetry)
  - [3.12 Datadog — Enterprise Observability at Scale](#312-datadog)
  - [3.13 Building an Observability Strategy](#313-observability-strategy)
- [Key Principles & Best Practices](#key-principles)
- [Tools & Technologies](#tools)
- [Hands-on Exercises / Labs](#labs)
- [Common Pitfalls & Anti-patterns](#pitfalls)
- [Interview Questions](#interview-questions)
- [Further Reading & Resources](#further-reading)
- [Key Takeaways](#key-takeaways)

---

## Learning Objectives {#learning-objectives}

By the end of this chapter, you will be able to:

- Distinguish between monitoring and observability, and explain why the difference matters when debugging novel production failures.
- Apply the Four Golden Signals, USE method, and RED method to instrument any system — and know which method to apply to which layer.
- Design an alerting strategy grounded in symptom-based, SLO-driven paging that minimizes alert fatigue and maximizes signal quality.
- Build a production-grade Prometheus + Grafana monitoring stack with SLO dashboards using PromQL.
- Instrument an application with OpenTelemetry and describe how metrics, logs, and traces complement each other during an incident.

---

## Core Concepts {#core-concepts}

### 3.1 Monitoring vs Observability — The Crucial Distinction {#31-monitoring-vs-observability}

These terms are frequently conflated. The distinction is not semantic — it determines whether your team can debug a novel production failure at 3am or spends three hours staring at dashboards that tell you *something* is wrong but not *why*.

**Monitoring** is the practice of collecting, processing, and alerting on a predefined set of signals. You decide in advance what to measure, and you watch those measurements for anomalies. Monitoring answers questions you *anticipated*.

**Observability** is the property of a system that allows you to understand its internal state from its external outputs. An observable system can answer questions you *didn't anticipate* — questions that emerge only when something novel breaks in production.

The distinction originates from control theory: a system is observable if its internal state can be inferred from its inputs and outputs over time.

```
Monitoring                          Observability
────────────────────────────────────────────────────────
Pre-defined questions               Exploratory questions
"Is error rate above 1%?"           "Why is this one user's
                                     request 10× slower?"
Dashboard-driven                    Query-driven
Known failure modes                 Unknown failure modes
Alerts when threshold crossed       Correlate signals freely
Good for: operational health        Good for: debugging novel issues
```

**A concrete example:** During the Facebook outage of October 2021, the root cause was a BGP routing misconfiguration that made Facebook's internal DNS servers unreachable. Standard monitoring would alert on "site is down" — but wouldn't tell you *why* every service was failing simultaneously, why the outage was so total, or why it couldn't be fixed remotely (engineers couldn't even access internal tools because those tools depended on the same broken DNS). Observability — specifically, the ability to correlate network traces, BGP route withdrawal logs, and DNS resolution failures across the stack — was required to diagnose and remediate.

**The goal:** Build monitoring for operational health. Build observability for debugging. Most mature SRE teams need both.

---

### 3.2 The Three Pillars of Observability {#32-three-pillars}

The observability literature identifies three primary signal types. Each reveals a different dimension of system behavior.

```
┌─────────────────────────────────────────────────────────────────┐
│                  The Three Pillars                              │
│                                                                 │
│   METRICS          LOGS              TRACES                     │
│   ───────          ────              ──────                     │
│   Numeric          Textual           Request                    │
│   aggregates       event records     flow maps                  │
│                                                                 │
│   "What is         "What happened    "Where did                 │
│    happening?"      and when?"        the time go?"             │
│                                                                 │
│   Low cost         Medium cost       High cost                  │
│   High cardinality Low cardinality   High cardinality           │
│   (by time)        (by text)         (by request)               │
│                                                                 │
│   Alert on         Debug specific    Trace slow                 │
│   trends           events            requests                   │
└─────────────────────────────────────────────────────────────────┘
```

#### Metrics

Metrics are numeric measurements aggregated over time. They are cheap to store, fast to query, and ideal for trending and alerting. Their weakness: they tell you *that* something changed, not *why*.

```
# Example metric: HTTP request duration histogram
http_request_duration_seconds_bucket{
  service="checkout",
  method="POST",
  route="/api/orders",
  status_code="200",
  le="0.3"
} 94821

# This tells you: 94,821 requests completed in < 300ms
# It does NOT tell you which requests were slow or why
```

**Types of metrics:**
- **Counters:** Monotonically increasing. `http_requests_total`, `errors_total`. Use `rate()` to get per-second values.
- **Gauges:** Point-in-time snapshot. `memory_usage_bytes`, `active_connections`. Use directly.
- **Histograms:** Distribution of values across configurable buckets. `http_request_duration_seconds`. Use for latency percentiles.
- **Summaries:** Pre-computed percentiles. Less flexible than histograms for aggregation. Avoid in distributed systems.

#### Logs

Logs are timestamped records of discrete events. They are the most human-readable signal type and the most expensive at scale. The key to useful logs is **structure** — logs that can be machine-parsed are infinitely more valuable than free-text strings.

```python
# ❌ Unstructured log — grep-able but not queryable
logger.info(f"User 1234 placed order 5678 for $99.99 at 2024-01-15T10:23:45Z")

# ✅ Structured log — queryable, filterable, joinable with traces
import structlog
logger = structlog.get_logger()

logger.info(
    "order_placed",
    user_id=1234,
    order_id=5678,
    amount_usd=99.99,
    trace_id="4bf92f3577b34da6",   # Links to distributed trace
    span_id="00f067aa0ba902b7",
    environment="production",
    service="checkout",
    version="v2.4.1"
)
```

**Structured log output (JSON):**
```json
{
  "event": "order_placed",
  "user_id": 1234,
  "order_id": 5678,
  "amount_usd": 99.99,
  "trace_id": "4bf92f3577b34da6",
  "span_id": "00f067aa0ba902b7",
  "environment": "production",
  "service": "checkout",
  "version": "v2.4.1",
  "timestamp": "2024-01-15T10:23:45.123Z",
  "level": "info"
}
```

**Log levels discipline:**
| Level | Use For | Alert? |
|-------|---------|--------|
| `DEBUG` | Development only. Never in production. | No |
| `INFO` | Normal business events (order placed, user login) | No |
| `WARN` | Unexpected but recoverable (retry succeeded, fallback used) | Sometimes |
| `ERROR` | Failure requiring investigation (request failed, dependency down) | Yes |
| `FATAL` | Process cannot continue | Yes — immediate |

**Rule:** Every `ERROR` log in production should be actionable. If you can't act on it, downgrade it to `WARN`. Alert fatigue from noisy error logs is as damaging as missing a real alert.

#### Traces

Distributed traces map the journey of a single request across every service, process, and database it touches. In a microservices architecture, a single user action might fan out across 20 services. Without tracing, a slow request is nearly impossible to diagnose.

```
User Request: POST /api/checkout  (total: 847ms)
│
├─ API Gateway                     12ms
│
├─ Checkout Service                823ms  ◄── WHERE IS THE TIME?
│   ├─ Auth Service (gRPC)          8ms
│   ├─ Cart Service (gRPC)         14ms
│   ├─ Inventory Service (gRPC)   782ms  ◄── HERE
│   │   └─ PostgreSQL query        771ms  ◄── AND HERE (missing index?)
│   └─ Payment Service (gRPC)       9ms
│
└─ Response                         12ms
```

Traces use a **span** model: each operation is a span with a start time, duration, parent span ID, and arbitrary key-value attributes. Spans sharing a `trace_id` are assembled into a waterfall view.

**The power of correlated signals:**
When all three pillars share a `trace_id`:
1. Alert fires: checkout p99 latency > 500ms (metric)
2. SRE queries traces filtered by `duration > 500ms` → sees `inventory_service` spans are slow
3. SRE queries logs for `service=inventory AND trace_id=4bf92f...` → finds `"cache_miss"` event
4. Root cause: Redis eviction policy causing cache stampede, loading PostgreSQL

This three-pillar correlation compresses a 30-minute debug session into 3 minutes.

---

### 3.3 The Four Golden Signals {#33-four-golden-signals}

Introduced in the Google SRE book, the **Four Golden Signals** are the minimum viable instrumentation for any user-facing service. If you can only measure four things, measure these.

```
┌────────────────────────────────────────────────────────────────┐
│                  The Four Golden Signals                       │
│                                                                │
│   LATENCY        TRAFFIC        ERRORS         SATURATION      │
│   ───────        ───────        ──────         ──────────      │
│   How long?      How much?      How broken?    How full?       │
│                                                                │
│   Response       Requests/sec   Error rate     Resource        │
│   time           QPS/TPS        HTTP 5xx %     utilization %   │
│                                                                │
│   Successful     User demand    Request         Headroom        │
│   AND failed     on the         failures        before          │
│   separately     system         by type         degradation     │
└────────────────────────────────────────────────────────────────┘
```

#### Signal 1: Latency

Latency is the time it takes to service a request. The critical nuance: **measure successful and failed requests separately.**

Failed requests often complete faster than successful ones (fail fast, return 500 immediately) — averaging them together creates a misleadingly healthy latency metric while the service is on fire.

```promql
# P99 latency for successful requests only
histogram_quantile(
  0.99,
  sum(
    rate(http_request_duration_seconds_bucket{
      service="checkout",
      status_code!~"5.."
    }[5m])
  ) by (le)
)

# P99 latency for failed requests (often tells a different story)
histogram_quantile(
  0.99,
  sum(
    rate(http_request_duration_seconds_bucket{
      service="checkout",
      status_code=~"5.."
    }[5m])
  ) by (le)
)
```

**Latency percentiles and what they mean:**
| Percentile | Meaning | Use Case |
|---|---|---|
| P50 (median) | Half of requests are faster than this | Baseline "typical" experience |
| P95 | 95% of requests are faster | Most users' experience |
| P99 | 99% of requests are faster | Tail latency — the worst 1% |
| P99.9 | 99.9% faster | High-value transaction latency |

> **SRE principle:** Always set SLOs on P99, not P50. Averages hide the worst user experiences. A service with P50=50ms and P99=30,000ms has a serious reliability problem that averages conceal.

#### Signal 2: Traffic

Traffic measures the demand placed on the system. It provides the denominator for error rate calculations and the context for saturation interpretation.

```promql
# Requests per second — overall
sum(rate(http_requests_total{service="checkout"}[1m]))

# Requests per second — broken down by endpoint
sum by (route) (
  rate(http_requests_total{service="checkout"}[1m])
)

# Traffic compared to same time last week (useful for anomaly detection)
sum(rate(http_requests_total{service="checkout"}[5m]))
/
sum(rate(http_requests_total{service="checkout"}[5m] offset 7d))
```

Traffic alone is not alarming — but sudden drops are often the first sign of an upstream failure (your service isn't receiving traffic because something broke upstream), and sudden spikes explain saturation and latency degradation.

#### Signal 3: Errors

Errors measure the rate of failed requests. "Failure" must be defined precisely — not just HTTP 5xx responses, but also wrong content (200 responses with empty bodies), timeouts, and business-logic failures (failed payments).

```promql
# HTTP error rate — 5xx as a fraction of all requests
sum(rate(http_requests_total{service="checkout", status_code=~"5.."}[5m]))
/
sum(rate(http_requests_total{service="checkout"}[5m]))

# SLO compliance: fraction of requests completing successfully within 300ms
# (combining error and latency into a single availability metric)
(
  sum(rate(http_requests_total{
    service="checkout",
    status_code!~"5..",
  }[5m]))
  -
  sum(rate(http_request_duration_seconds_count{
    service="checkout",
    status_code!~"5..",
    duration_bucket="slow"
  }[5m]))
)
/
sum(rate(http_requests_total{service="checkout"}[5m]))
```

**Error classification:**
```python
# Not all errors are created equal — classify by impact
ERROR_CATEGORIES = {
    "user_error":    ["400", "401", "403", "404"],  # Client caused — don't alert
    "service_error": ["500", "502", "503"],         # We caused — alert
    "dependency":    ["504"],                       # Upstream caused — alert + context
    "business":      ["200_empty_cart",             # Logic failures — alert
                      "200_payment_declined"],
}
```

#### Signal 4: Saturation

Saturation measures how "full" a resource is — the proportion of capacity currently being used. Saturation is a leading indicator: it predicts degradation before it occurs.

```promql
# CPU saturation across all pods in a service
1 - avg by (pod) (
  rate(container_cpu_usage_seconds_total{
    namespace="production",
    container="checkout"
  }[5m])
)

# Memory saturation
container_memory_working_set_bytes{container="checkout"}
/
container_spec_memory_limit_bytes{container="checkout"}

# Database connection pool saturation — leading indicator of latency spikes
pg_stat_activity_count{state="active"}
/
pg_settings_max_connections
```

**Saturation thresholds by resource:**
| Resource | Warning | Critical |
|---|---|---|
| CPU | 70% | 85% |
| Memory | 80% | 90% |
| Disk I/O | 60% | 80% |
| DB connections | 70% | 85% |
| Network bandwidth | 60% | 80% |

> **Key insight:** Alert on saturation *before* it impacts latency and errors. If your database connection pool hits 85% utilization, you have ~15 minutes before requests start queuing and latency explodes — that's your remediation window.

---

### 3.4 The USE Method {#34-use-method}

Developed by Brendan Gregg (Netflix), the **USE Method** is designed for **infrastructure and resource monitoring**: CPUs, memory, disks, network interfaces, storage controllers.

**USE = Utilization + Saturation + Errors**

For every resource, ask:
- **Utilization:** What percentage of the resource's capacity is being used? (time-based or count-based)
- **Saturation:** Is work queuing up because the resource is overloaded?
- **Errors:** Are there hardware or software errors occurring on this resource?

```
USE Method Applied — Linux Server Example
──────────────────────────────────────────────────────────────
Resource         Utilization           Saturation        Errors
──────────────────────────────────────────────────────────────
CPU              mpstat %usr + %sys    run queue length  perf hw cache misses
Memory           used/total %          major page faults  ECC memory errors
Disk (per disk)  iostat %util          await queue depth  smartctl errors
Network (NIC)    bytes/max bandwidth   drops/retransmits  ifconfig errors
──────────────────────────────────────────────────────────────
```

```bash
#!/bin/bash
# USE Method quick audit script for Linux
echo "=== CPU Utilization ==="
mpstat 1 3 | awk 'NR==4{print "User:"$3"% System:"$5"% Idle:"$12"%"}'

echo "=== CPU Saturation (run queue) ==="
vmstat 1 3 | awk 'NR>2{print "Run queue:"$1" Blocked:"$2}'

echo "=== Memory Utilization ==="
free -h | awk 'NR==2{printf "Used: %s / Total: %s (%.1f%%)\n", $3,$2,$3/$2*100}'

echo "=== Memory Saturation (page faults) ==="
vmstat 1 3 | awk 'NR>2{print "Major faults/s:"$7}'

echo "=== Disk Utilization ==="
iostat -x 1 2 | awk '/^sd|^nvme/{print $1" util:"$NF"%"}'

echo "=== Network Utilization ==="
sar -n DEV 1 3 | awk '/eth0/{print "RX:"$5"KB/s TX:"$6"KB/s"}'
```

**When to use USE:** For any performance investigation that starts with "the server feels slow." USE gives you a systematic checklist that finds the bottleneck resource within minutes rather than hours of guessing.

---

### 3.5 The RED Method {#35-red-method}

Developed by Tom Wilkie (Grafana Labs), the **RED Method** is designed for **microservices and request-driven systems**. It focuses on the service's behavior from the perspective of the requests it processes.

**RED = Rate + Errors + Duration**

For every service, ask:
- **Rate:** How many requests per second is the service handling?
- **Errors:** What fraction of those requests are failing?
- **Duration:** How long are requests taking (distribution — P50, P95, P99)?

```promql
# RED Method — complete PromQL dashboard queries for a microservice

# Rate: requests per second
sum(rate(http_requests_total{service="$service"}[5m])) by (route)

# Errors: error rate by route
sum(rate(http_requests_total{service="$service", status_code=~"5.."}[5m])) by (route)
/
sum(rate(http_requests_total{service="$service"}[5m])) by (route)

# Duration: P50, P95, P99
histogram_quantile(0.50, sum(rate(http_request_duration_seconds_bucket{service="$service"}[5m])) by (le, route))
histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{service="$service"}[5m])) by (le, route))
histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket{service="$service"}[5m])) by (le, route))
```

RED is simpler than the Four Golden Signals (no saturation) and simpler than USE (no resource focus) — making it ideal for a **per-service overview dashboard** that covers every microservice in a uniform way.

---

### 3.6 Choosing the Right Method {#36-choosing-the-right-method}

```
Decision Tree: Which Method to Apply?
──────────────────────────────────────────────────────────────
Is this a user-facing service?
  └─► YES → Four Golden Signals (latency, traffic, errors, saturation)
             Add RED for per-service microservice dashboards

Is this an infrastructure resource? (CPU, memory, disk, NIC)
  └─► YES → USE Method (utilization, saturation, errors)

Is this a background worker / batch job?
  └─► Adapt RED: Rate = jobs/sec, Errors = failed jobs, Duration = job runtime

Is this a database?
  └─► USE for resources (connections, disk I/O) +
      RED for queries (query rate, failed queries, query duration)

Are you building a service dashboard for a team that owns 20+ microservices?
  └─► RED — uniform, simple, scales across many services
```

In practice, mature SRE teams use **all three methods at different layers:**
- RED at the service layer (request-driven)
- USE at the infrastructure layer (resource-driven)
- Four Golden Signals at the SLO layer (user-experience-driven)

---

### 3.7 Alerting Philosophy — Alerting on Symptoms, Not Causes {#37-alerting-philosophy}

The most important principle in SRE alerting is: **page on symptoms, not causes.**

A symptom is something the user experiences. A cause is what produced the symptom. Causes are interesting for debugging; symptoms are what demand immediate action.

```
Cause-based alert (WRONG)                Symptom-based alert (RIGHT)
──────────────────────────────────────────────────────────────────────
"CPU > 80% on web-01"                    "P99 checkout latency > 500ms"
"Memory usage > 90%"                     "Error rate > 1% on checkout"
"Database connections > 500"             "SLO burn rate > 14.4× over 1h"
"Disk I/O wait > 40%"                    "Checkout availability < 99.5%"
──────────────────────────────────────────────────────────────────────
```

**Why cause-based alerts fail:**
- CPU at 80% may never produce user impact (well-optimized service)
- CPU at 30% may produce user impact (runaway goroutine, not CPU-bound)
- You'll page engineers for causes that don't matter
- You'll miss user-impacting failures that don't trigger resource thresholds

#### The Alerting Pyramid

Not all alerts should page an engineer at 3am. Structure alerts in layers:

```
                    ▲
                   /P1\
                  / SLO \         ← Wake someone up NOW
                 / BREACH \         (user impact confirmed)
                ────────────
               /   P2 BURN  \
              /  RATE WARNING \    ← Ticket + Slack (investigate soon)
             /  (fast burn <1h)\
            ─────────────────────
           /  INFRA / CAPACITY   \
          /   (saturation >70%,   \ ← Dashboard + ticket (plan capacity)
         /    disk >80%)           \
        ───────────────────────────────
       /    DEBUG / DIAGNOSTIC       \  ← Logs / traces only
      /  (noisy, low-signal events)   \ (never alert)
     ─────────────────────────────────────
```

#### SLO-Based Burn Rate Alerting

The most rigorous alerting strategy links every page directly to SLO consumption. Rather than alerting on instantaneous error rates, alert when the *rate at which you're consuming error budget* is dangerously high.

**Burn rate concept:**
- If your SLO is 99.9% (0.1% error budget per month)
- And your current error rate is 1% (10× the budget)
- Your budget will be exhausted in: 30 days / 10 = 3 days
- Burn rate = 10×

```
Burn Rate Alerting Thresholds (Google's recommendation)
──────────────────────────────────────────────────────────────
Window    Burn Rate    Consumes Budget In    Severity   Action
──────────────────────────────────────────────────────────────
1h        14.4×        ~2 days               PAGE       Wake on-call now
6h         6×          ~5 days               PAGE       Urgent investigation
3d (72h)   1×          Exactly 30 days       TICKET     Schedule fix
──────────────────────────────────────────────────────────────
```

```yaml
# Prometheus alerting rules — SLO-based burn rate alerts
# For a service with 99.9% availability SLO

groups:
  - name: slo_checkout_availability
    rules:

      # P1: Fast burn — page immediately
      # Error rate is 14.4× normal over 1h AND 6h (double window reduces false positives)
      - alert: CheckoutAvailabilityCritical
        expr: |
          (
            job:slo_errors:rate1h{job="checkout"} > (14.4 * 0.001)
            and
            job:slo_errors:rate5m{job="checkout"} > (14.4 * 0.001)
          )
        for: 2m
        labels:
          severity: page
          team: checkout
        annotations:
          summary: "Checkout SLO burning fast — P1"
          description: |
            Checkout service error rate {{ $value | humanizePercentage }}
            Budget will be exhausted in ~2 days at current rate.
            Runbook: https://runbooks.internal/checkout/high-error-rate

      # P2: Slow burn — ticket + Slack
      - alert: CheckoutAvailabilityWarning
        expr: |
          job:slo_errors:rate6h{job="checkout"} > (6 * 0.001)
          and
          job:slo_errors:rate30m{job="checkout"} > (6 * 0.001)
        for: 15m
        labels:
          severity: ticket
          team: checkout
        annotations:
          summary: "Checkout SLO burning — investigate this week"
          description: |
            Checkout error rate elevated. Budget consumed in ~5 days.
            Investigate: https://grafana.internal/d/checkout-slo
```

#### Alert Quality Metrics

Alert quality degrades silently if not measured. Track these metrics for your alerting system:

| Metric | Target | Warning |
|---|---|---|
| Alert-to-incident ratio | > 80% | < 60% (too many false alarms) |
| Mean time to alert (MTTA) | < 5 min | > 15 min (too slow) |
| Alert noise ratio (no action taken) | < 20% | > 40% (alert fatigue risk) |
| On-call pages per week per engineer | < 5 | > 10 (burnout risk) |

---

### 3.8 Dashboard Design for SREs {#38-dashboard-design}

A dashboard that no one understands during an incident is worse than no dashboard — it consumes attention without providing value. SRE dashboards are operational tools, not art projects.

#### The Dashboard Hierarchy

Design dashboards at three levels, each answering a different question:

```
Level 1: Executive / SLO Dashboard
  ├── Answer: "Are we meeting our reliability commitments?"
  ├── Audience: Engineering leadership, product managers
  ├── Signals: SLO compliance %, error budget remaining, 28-day trend
  └── Update frequency: 5-minute resolution, 28-day window

Level 2: Service Health Dashboard (per service)
  ├── Answer: "Is this service healthy right now?"
  ├── Audience: On-call SRE, service owners
  ├── Signals: Four Golden Signals, active alerts, deployment markers
  └── Update frequency: 30-second resolution, 3-hour window

Level 3: Deep-Dive Dashboard (per component)
  ├── Answer: "Where exactly is the problem?"
  ├── Audience: SRE debugging an active incident
  ├── Signals: Detailed metrics, DB query times, cache hit rates, queue depths
  └── Update frequency: 10-second resolution, configurable window
```

#### Dashboard Design Principles

**1. Use consistent time ranges.** Every panel on a dashboard should show the same time window. Mixed time ranges create cognitive load during incidents.

**2. Show change markers.** Overlay deployment events on every time-series graph. Most production incidents are caused by changes — the deployment marker immediately answers "did this correlate with a deployment?"

**3. Color consistently:** Red = bad, green = good, yellow = warning. Never use red for a neutral metric.

**4. Show the SLO threshold as a reference line.** On every latency and error rate panel, draw a horizontal line at the SLO threshold. Engineers should immediately see how far they are from the SLO limit.

**5. Design for the incident, not the steady state.** The dashboard that looks beautiful when everything is fine is irrelevant. Optimize for clarity when three panels are red at 3am and the on-call engineer has been awake for 20 minutes.

```
Sample Service Health Dashboard Layout
──────────────────────────────────────────────────────────────────
┌──────────────────────┬────────────────┬────────────────────────┐
│  AVAILABILITY SLO    │  P99 LATENCY   │  REQUEST RATE          │
│  ████████░░  98.7%   │   247ms        │   1,247 req/s          │
│  Budget: 42% left    │  ── SLO: 300ms │  ▲ +12% vs last week   │
├──────────────────────┴────────────────┴────────────────────────┤
│  ERROR RATE (5m rolling)                [deployments ▼]        │
│  ┤                                 ↑ deploy v2.4.1             │
│  ┤ 0.5% ─────────────────────────────────────────────────────  │
│  ┤      SLO threshold ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─   │
│  ┤ 0.0%                                                        │
├──────────────────────┬────────────────────────────────────────-┤
│  SATURATION          │  ACTIVE ALERTS                          │
│  CPU:   45%  ██████░ │  🔴 P1: None                            │
│  Mem:   72%  █████░░ │  🟡 P2: DB pool at 73% (since 14:32)    │
│  DB:    38%  ████░░░ │  ℹ️  Info: Deploy in progress           │
└──────────────────────┴────────────────────────────────────────-┘
```

---

### 3.9 Prometheus — The SRE Metrics Engine {#39-prometheus}

Prometheus is the de facto metrics standard for cloud-native systems. It is a pull-based time-series database that scrapes metrics endpoints (usually `/metrics`) from instrumented services, stores them efficiently, and provides a powerful query language (PromQL).

#### Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  Prometheus Architecture                │
│                                                         │
│  Targets (apps)   ──scrape──►  Prometheus Server        │
│  /metrics                       ├── TSDB (storage)      │
│                                 ├── Rules Engine        │
│  Service Discovery              │   (recording + alert) │
│  (k8s, consul, etc.)──►         └── HTTP API            │
│                                          │              │
│  Alertmanager  ◄────alerts───────────────┘              │
│  (route, dedupe,                                        │
│   silence, inhibit)                                     │
│       │                                                 │
│       ▼                                                 │
│  PagerDuty / Slack / OpsGenie                          │
└─────────────────────────────────────────────────────────┘
```

#### Instrumenting an Application

```python
# Python service instrumented with prometheus_client
from prometheus_client import Counter, Histogram, Gauge, start_http_server
import time
import functools

# Define metrics
REQUEST_COUNT = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status_code']
)

REQUEST_LATENCY = Histogram(
    'http_request_duration_seconds',
    'HTTP request duration',
    ['method', 'endpoint'],
    buckets=[.005, .01, .025, .05, .1, .25, .5, 1, 2.5, 5, 10]
)

ACTIVE_REQUESTS = Gauge(
    'http_requests_in_flight',
    'Current in-flight HTTP requests',
    ['endpoint']
)

# Decorator for automatic instrumentation
def track_requests(endpoint: str):
    def decorator(func):
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            ACTIVE_REQUESTS.labels(endpoint=endpoint).inc()
            start = time.time()
            status = "500"
            try:
                result = func(*args, **kwargs)
                status = str(result.status_code)
                return result
            except Exception as e:
                status = "500"
                raise
            finally:
                duration = time.time() - start
                REQUEST_COUNT.labels(
                    method="POST",
                    endpoint=endpoint,
                    status_code=status
                ).inc()
                REQUEST_LATENCY.labels(
                    method="POST",
                    endpoint=endpoint
                ).observe(duration)
                ACTIVE_REQUESTS.labels(endpoint=endpoint).dec()
        return wrapper
    return decorator

# Usage
@track_requests("/api/checkout")
def handle_checkout(request):
    # Your handler logic
    pass

# Expose metrics on :8080/metrics
start_http_server(8080)
```

#### Prometheus Configuration

```yaml
# prometheus.yml — production-grade configuration
global:
  scrape_interval: 15s          # How often to scrape targets
  evaluation_interval: 15s      # How often to evaluate rules
  scrape_timeout: 10s

# Alertmanager integration
alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']

# Load recording and alerting rules
rule_files:
  - "rules/recording_rules.yml"
  - "rules/slo_alerts.yml"
  - "rules/infra_alerts.yml"

scrape_configs:
  # Kubernetes service discovery — auto-discovers all annotated pods
  - job_name: 'kubernetes-pods'
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      # Only scrape pods with annotation: prometheus.io/scrape: "true"
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      # Use custom port annotation if present
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        regex: (\d+)
        replacement: $1
        target_label: __address__
      # Enrich metrics with k8s labels
      - source_labels: [__meta_kubernetes_namespace]
        target_label: namespace
      - source_labels: [__meta_kubernetes_pod_name]
        target_label: pod
      - source_labels: [__meta_kubernetes_pod_label_app]
        target_label: service

  # Static scrape for infrastructure exporters
  - job_name: 'node-exporter'
    static_configs:
      - targets:
          - 'node-exporter-01:9100'
          - 'node-exporter-02:9100'
    relabel_configs:
      - source_labels: [__address__]
        regex: '([^:]+):\d+'
        target_label: instance
```

#### Recording Rules — Pre-compute Expensive Queries

```yaml
# rules/recording_rules.yml
# Pre-compute expensive PromQL expressions to speed up dashboards and alerts

groups:
  - name: slo_recording_rules
    interval: 30s
    rules:
      # 5-minute error rate (used in alerts and dashboards)
      - record: job:slo_errors:rate5m
        expr: |
          sum by (job) (
            rate(http_requests_total{status_code=~"5.."}[5m])
          )
          /
          sum by (job) (
            rate(http_requests_total[5m])
          )

      # 1-hour error rate (for burn rate alerting)
      - record: job:slo_errors:rate1h
        expr: |
          sum by (job) (
            rate(http_requests_total{status_code=~"5.."}[1h])
          )
          /
          sum by (job) (
            rate(http_requests_total[1h])
          )

      # P99 latency — 5 minute window
      - record: job:http_request_duration_seconds:p99_5m
        expr: |
          histogram_quantile(0.99,
            sum by (job, le) (
              rate(http_request_duration_seconds_bucket[5m])
            )
          )
```

---

### 3.10 Grafana — Visualization and SLO Dashboards {#310-grafana}

Grafana is the standard visualization layer for Prometheus (and dozens of other data sources). Beyond basic dashboards, it provides SLO tracking, alerting, and — with Grafana SLO plugin — fully automated SLO dashboards.

#### SLO Dashboard in Grafana (JSON excerpt)

```json
{
  "title": "Checkout Service — SLO Dashboard",
  "panels": [
    {
      "title": "Error Budget Remaining (28-day)",
      "type": "gauge",
      "fieldConfig": {
        "defaults": {
          "min": 0, "max": 100,
          "thresholds": {
            "steps": [
              {"color": "red",    "value": 0},
              {"color": "yellow", "value": 25},
              {"color": "green",  "value": 50}
            ]
          },
          "unit": "percent"
        }
      },
      "targets": [{
        "expr": "(1 - (sum(increase(http_requests_total{service='checkout',status_code=~'5..'}[28d])) / sum(increase(http_requests_total{service='checkout'}[28d]))) / 0.001) * 100",
        "legendFormat": "Budget Remaining"
      }]
    },
    {
      "title": "P99 Latency vs SLO Threshold",
      "type": "timeseries",
      "fieldConfig": {
        "defaults": { "unit": "ms" },
        "overrides": [{
          "matcher": { "id": "byName", "options": "SLO Threshold" },
          "properties": [
            {"id": "custom.lineStyle", "value": {"dash": [10, 10]}},
            {"id": "color",            "value": {"fixedColor": "red", "mode": "fixed"}}
          ]
        }]
      }
    }
  ]
}
```

#### Grafana Alerting with Notification Policies

```yaml
# grafana/provisioning/alerting/notification-policy.yml
apiVersion: 1
policies:
  - receiver: default-receiver
    group_by: [service, severity]
    group_wait: 30s
    group_interval: 5m
    repeat_interval: 12h
    routes:
      - matchers:
          - severity = page
        receiver: pagerduty-oncall
        continue: false
      - matchers:
          - severity = ticket
        receiver: slack-sre-channel
        continue: false

receivers:
  - name: pagerduty-oncall
    pagerduty_configs:
      - routing_key: "${PAGERDUTY_INTEGRATION_KEY}"
        description: "{{ .CommonAnnotations.summary }}"
        details:
          runbook: "{{ .CommonAnnotations.runbook_url }}"
          service: "{{ .CommonLabels.service }}"

  - name: slack-sre-channel
    slack_configs:
      - api_url: "${SLACK_WEBHOOK_URL}"
        channel: "#sre-alerts"
        title: "⚠️ {{ .CommonAnnotations.summary }}"
        text: "{{ .CommonAnnotations.description }}"
```

---

### 3.11 OpenTelemetry — The Unified Observability Standard {#311-opentelemetry}

OpenTelemetry (OTel) is the CNCF standard for generating, collecting, and exporting telemetry data (metrics, logs, traces) from applications. It replaces vendor-specific SDKs with a single, vendor-neutral instrumentation library.

**Why OTel matters to SREs:** Before OTel, switching observability vendors meant re-instrumenting every service. With OTel, you instrument once and route to any backend (Prometheus, Datadog, Jaeger, Honeycomb) by changing a configuration file.

```
Application Code
      │
      ▼
OpenTelemetry SDK (instrument once)
      │
      ▼
OTel Collector (receive, process, export)
      │
      ├──► Prometheus (metrics)
      ├──► Jaeger / Tempo (traces)
      └──► Loki / Elasticsearch (logs)
```

#### Instrumenting with OpenTelemetry (Python)

```python
# Auto-instrumentation + manual spans — OpenTelemetry Python
from opentelemetry import trace, metrics
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor
import fastapi

# --- Tracing setup ---
tracer_provider = TracerProvider()
tracer_provider.add_span_processor(
    BatchSpanProcessor(
        OTLPSpanExporter(endpoint="http://otel-collector:4317")
    )
)
trace.set_tracer_provider(tracer_provider)
tracer = trace.get_tracer("checkout-service", "2.4.1")

# --- Auto-instrument FastAPI and SQLAlchemy ---
app = fastapi.FastAPI()
FastAPIInstrumentor.instrument_app(app)
SQLAlchemyInstrumentor().instrument(engine=db_engine)

# --- Manual span for business logic ---
@app.post("/api/checkout")
async def checkout(order: Order):
    with tracer.start_as_current_span("process_checkout") as span:
        span.set_attribute("order.id",     order.id)
        span.set_attribute("order.amount", order.total_usd)
        span.set_attribute("user.id",      order.user_id)

        with tracer.start_as_current_span("validate_inventory"):
            inventory_ok = await check_inventory(order.items)
            span.set_attribute("inventory.available", inventory_ok)

        if not inventory_ok:
            span.set_status(trace.StatusCode.ERROR, "Inventory unavailable")
            raise HTTPException(status_code=409, detail="Item out of stock")

        with tracer.start_as_current_span("process_payment"):
            result = await charge_payment(order)

        return {"order_id": order.id, "status": "confirmed"}
```

#### OTel Collector Configuration

```yaml
# otel-collector-config.yml
receivers:
  otlp:
    protocols:
      grpc: { endpoint: "0.0.0.0:4317" }
      http: { endpoint: "0.0.0.0:4318" }

processors:
  batch:
    timeout: 10s
    send_batch_size: 1024

  # Enrich all telemetry with k8s metadata
  k8sattributes:
    auth_type: "serviceAccount"
    extract:
      metadata: [k8s.namespace.name, k8s.pod.name, k8s.deployment.name]

  # Sample traces — keep 100% of error traces, 10% of successful traces
  probabilistic_sampler:
    sampling_percentage: 10
  tail_sampling:
    policies:
      - name: keep-errors
        type: status_code
        status_code: { status_codes: [ERROR] }

exporters:
  prometheus:
    endpoint: "0.0.0.0:8889"

  otlp/tempo:
    endpoint: "tempo:4317"
    tls: { insecure: true }

  loki:
    endpoint: "http://loki:3100/loki/api/v1/push"

service:
  pipelines:
    traces:
      receivers:  [otlp]
      processors: [k8sattributes, tail_sampling, batch]
      exporters:  [otlp/tempo]
    metrics:
      receivers:  [otlp]
      processors: [k8sattributes, batch]
      exporters:  [prometheus]
    logs:
      receivers:  [otlp]
      processors: [k8sattributes, batch]
      exporters:  [loki]
```

---

### 3.12 Datadog — Enterprise Observability at Scale {#312-datadog}

Datadog is the leading commercial observability platform, providing unified metrics, logs, traces, and synthetic monitoring in a single product. It is common in enterprises that prioritize operational simplicity over customization.

**SRE-relevant Datadog capabilities:**

| Feature | Use Case |
|---|---|
| **APM + Distributed Tracing** | Automatic trace collection with flame graphs |
| **SLO Tracking** | Native SLO dashboards with burn rate alerts |
| **Log Management** | Ingestion, parsing, correlation with traces |
| **Synthetic Monitoring** | Continuous user journey testing from global locations |
| **Watchdog** | ML-based anomaly detection (no threshold configuration required) |
| **Incident Management** | Built-in incident workflow, timeline, and postmortem tools |
| **Service Catalog** | Ownership registry linking services to SLOs, dashboards, runbooks |

```python
# Datadog custom metrics via DogStatsD
from datadog import initialize, statsd

initialize(statsd_host='localhost', statsd_port=8125)

def process_payment(order):
    with statsd.timed('payment.processing_time', tags=[f"payment_method:{order.method}"]):
        result = payment_gateway.charge(order)

    if result.success:
        statsd.increment('payment.success', tags=[f"amount_tier:{get_tier(order.amount)}"])
        statsd.histogram('payment.amount_usd', order.amount)
    else:
        statsd.increment('payment.failure', tags=[f"reason:{result.error_code}"])

    return result
```

**Datadog vs Prometheus — when to choose each:**

| Dimension | Prometheus + Grafana | Datadog |
|---|---|---|
| Cost | Open source (infra cost only) | $15–$23/host/month |
| Setup complexity | High (you manage everything) | Low (SaaS) |
| Customization | Unlimited | Within product limits |
| Logs + traces | Requires Loki, Tempo, OTel | Native, integrated |
| Cardinality | Limited (high-cardinality metrics expensive) | Better cardinality handling |
| Best for | Kubernetes-native, cost-sensitive, engineering-heavy teams | Enterprise, multi-cloud, teams that want a managed solution |

---

### 3.13 Building an Observability Strategy {#313-observability-strategy}

An observability strategy is not a tool selection exercise — it is a decision about *what questions your team needs to be able to answer* and *how you will instrument your systems to answer them.*

**The Observability Maturity Ladder:**

```
Level 0: Flying blind
  - No metrics, no logs, no traces
  - Incidents discovered by users
  - "Is it down?" requires SSH to server

Level 1: Basic monitoring
  - Infrastructure metrics (CPU, memory, disk)
  - Application logs (unstructured)
  - Threshold-based alerts (too many, too noisy)

Level 2: Service health visibility
  - Four Golden Signals per service
  - Structured logging
  - SLO dashboards
  - SLO-based alerting (burn rate)

Level 3: Distributed observability
  - Distributed tracing across all services
  - Correlated metrics + logs + traces (shared trace_id)
  - Service dependency maps
  - SLO burn rate → trace correlation for instant debug

Level 4: Proactive observability
  - Synthetic monitoring (user journeys tested continuously)
  - Anomaly detection (ML-based, not threshold-based)
  - Business metrics correlated with technical SLIs
  - Observability driving on-call runbook automation
```

**Instrumentation priority order** (where to start):
1. Four Golden Signals on your highest-traffic, highest-revenue services
2. SLO dashboards and burn rate alerts for those services
3. Structured logging across all services
4. Distributed tracing on the critical path (the flows users actually care about)
5. Extend to remaining services
6. Synthetic monitoring for critical user journeys
7. Anomaly detection and ML-based alerting

---

## Key Principles & Best Practices {#key-principles}

1. **Alert on symptoms, not causes.** Pages wake engineers up. Every page must represent a symptom the user is experiencing or will experience imminently. Cause-based alerts belong in dashboards, not pagers.

2. **Measure from the user's perspective.** Instrument the edge of your system — what arrives at the user — before instrumenting internals. A healthy internal metric masking user pain is worse than no metric.

3. **The three pillars are complementary, not redundant.** Metrics tell you *that* something changed. Logs tell you *what* happened. Traces tell you *where* in the request flow. You need all three for incident response; investing in only one leaves you blind to the others' questions.

4. **Cardinality kills Prometheus.** Every unique combination of label values creates a new time series. `user_id` as a label on a high-traffic metric will crash your Prometheus. Use trace IDs in spans, not metrics, for high-cardinality attributes.

5. **Dashboards are for incidents, not tours.** Design every dashboard for the worst moment — when the on-call engineer is groggy at 3am, three panels are red, and they need to understand the blast radius in 30 seconds.

6. **Treat your monitoring system like a production service.** Your observability stack needs uptime, capacity planning, and its own alerts. A monitoring system that goes dark during an incident is catastrophic.

7. **Instrument new services before they launch.** Observability is a PRR requirement. A service without Four Golden Signals does not go to production.

8. **Invest in recording rules early.** Pre-compute expensive PromQL expressions as recording rules. Dashboard load times > 5 seconds are a morale tax on every on-call rotation.

---

## Tools & Technologies {#tools}

| Tool | Category | SRE Use Case |
|---|---|---|
| **Prometheus** | Metrics | Pull-based time-series DB, PromQL, alerting rules |
| **Grafana** | Visualization | Dashboards, SLO tracking, alert routing |
| **OpenTelemetry** | Instrumentation SDK | Vendor-neutral metrics/traces/logs collection |
| **Jaeger / Grafana Tempo** | Distributed Tracing | Trace storage and visualization |
| **Grafana Loki** | Log Aggregation | Cost-efficient log storage, integrates with Grafana |
| **Elasticsearch + Kibana** | Log Management | Full-text search over logs (higher cost, higher query power) |
| **Datadog** | All-in-One Observability | Commercial platform: metrics + logs + traces + SLO |
| **VictoriaMetrics** | Prometheus Alternative | Higher performance, lower cost at scale, Prometheus-compatible |
| **Thanos / Cortex** | Prometheus HA | Long-term storage and multi-cluster Prometheus federation |
| **PagerDuty / OpsGenie** | Alert Routing | On-call schedules, escalation, incident management |
| **Alertmanager** | Alert Management | Routing, deduplication, silencing, inhibition for Prometheus alerts |

---

## Hands-on Exercises / Labs {#labs}

### Lab 3.1 — Four Golden Signals Instrumentation

**Goal:** Instrument a Python web service with all Four Golden Signals.

**Setup:**
```bash
pip install prometheus_client flask
```

**Task:** Given this skeleton Flask service, add complete Four Golden Signals instrumentation:

```python
# skeleton_service.py — add instrumentation
from flask import Flask, jsonify
import time, random

app = Flask(__name__)

@app.route('/api/product/<int:product_id>')
def get_product(product_id):
    # Simulate variable latency
    time.sleep(random.uniform(0.01, 0.5))

    # Simulate 2% error rate
    if random.random() < 0.02:
        return jsonify({"error": "internal server error"}), 500

    return jsonify({"id": product_id, "name": f"Product {product_id}", "price": 9.99})

if __name__ == '__main__':
    app.run(port=5000)
```

**Deliverables:**
1. Add Prometheus metrics: request counter (with method, route, status), latency histogram, active requests gauge, and a saturation metric of your choice.
2. Start the app and generate traffic with a loop: `for i in {1..100}; do curl localhost:5000/api/product/$i; done`
3. Query your metrics via `curl localhost:8080/metrics`
4. Write PromQL queries for: current RPS, P99 latency, 5-minute error rate, saturation gauge value.

---

### Lab 3.2 — Build a Burn Rate Alert

**Goal:** Write and validate a Prometheus burn rate alerting rule for a 99.9% SLO.

**Given:**
- SLO: 99.9% availability (0.1% error budget per 28 days)
- Metric: `http_requests_total{service="api", status_code="<code>"}`

**Tasks:**
1. Write the PromQL expression for current error rate (5-minute window).
2. Calculate: at a burn rate of 14.4×, how many hours until the monthly budget is exhausted?
3. Write a complete Prometheus alerting rule (YAML) for the P1 burn rate alert using a 1h + 5m double window.
4. Write the P2 warning alert using a 6h + 30m double window at 6× burn rate.
5. Write the silence condition (YAML) you'd apply during a planned maintenance window.

---

### Lab 3.3 — Distributed Trace Analysis

**Goal:** Analyze a distributed trace waterfall and identify the performance bottleneck.

**Given trace (simulated output from Jaeger):**
```
POST /api/checkout                   total: 2,340ms
├── authenticate_user                    45ms
├── load_cart                            12ms
├── validate_items (3 calls)
│   ├── check_inventory: item_1          8ms
│   ├── check_inventory: item_2         11ms
│   └── check_inventory: item_3       1,847ms  ◄
│       └── db_query: SELECT inventory   1,831ms  ◄
│           └── [WAITING FOR LOCK]
├── calculate_tax                         9ms
├── process_payment                     380ms
│   └── stripe_api_call                 371ms
└── create_order_record                  22ms
```

**Tasks:**
1. Identify the root cause of the 2,340ms total latency.
2. What SQL query pattern likely caused the lock wait? Write a hypothesis.
3. What three fixes would you propose, in priority order?
4. What metric would you add to detect this proactively (before users notice)?
5. Write the structured log entry that `check_inventory` should emit when it detects a slow query (> 500ms).

---

### Lab 3.4 — Dashboard Design Review

**Goal:** Critique and redesign a poor monitoring dashboard.

**Given dashboard description:**
- Panel 1: "CPU Usage" — shows `node_cpu_seconds_total` raw counter for the last 24 hours. No threshold line.
- Panel 2: "Memory" — shows resident set size in bytes. Threshold at 8GB (hard-coded).
- Panel 3: "Errors" — shows count of error log lines over 30 days.
- Panel 4: "Uptime" — shows time since last restart in seconds.
- Panel 5: "Requests" — shows total request count (cumulative counter) since deployment.
- All panels use different time ranges (some 1h, some 24h, some 30d).

**Tasks:**
1. List every dashboard anti-pattern present (minimum 6).
2. Redesign the dashboard: choose the correct metrics, time ranges, visualization types, and threshold lines for an SRE responding to an active incident.
3. Write the PromQL query for a replacement "Error Rate" panel that shows the 5-minute rolling error percentage with the SLO threshold overlaid.
4. Sketch (in ASCII or prose) the layout of your redesigned dashboard using the Level 2 Service Health template from Section 3.8.

---

## Common Pitfalls & Anti-patterns {#pitfalls}

**Anti-pattern 1: Monitoring for monitoring's sake (dashboard theatre)**
Teams build dozens of dashboards because dashboards *look* like observability. No one looks at them except during company all-hands demos. No alerts are tied to them. During incidents, engineers SSH to servers instead. *Fix:* Every dashboard must own at least one alert. If no one is alerted by a panel's metric, question whether that panel belongs in a response dashboard.

**Anti-pattern 2: Threshold-based alerting on causes**
Alert rules fire on CPU > 80%, memory > 90%, disk > 85% — triggering dozens of pages per week, most of which resolve themselves before the on-call engineer has context. Mean time to alert is 0 seconds; mean time to relevance is 2 hours. *Fix:* Move to SLO-based burn rate alerting. Let USE/RED metrics live in dashboards, not pagers.

**Anti-pattern 3: Label cardinality explosion**
An engineer adds `user_id` as a Prometheus label. The service has 10M users. Prometheus creates 10M time series and runs out of memory. *Fix:* Never add unbounded values (user IDs, request IDs, IP addresses, trace IDs) as Prometheus labels. These belong in trace spans and log structured fields.

**Anti-pattern 4: Ignoring failed request latency**
SLO dashboards measure P99 latency only on successful requests. Failures complete in 2ms (fast fail) and are excluded. The dashboard looks healthy. Users are experiencing 50% errors. *Fix:* Track error rate and success latency as separate SLI dimensions. Both must be healthy for the SLO to be met.

**Anti-pattern 5: Unstructured logging at scale**
Teams log 10GB/day in free-text format. Querying for a specific error means `grep` on 10 servers. During incidents, log analysis takes 45 minutes. *Fix:* Mandate structured (JSON) logging with trace_id, service, version, and severity as required fields. Make it a PRR requirement and provide a logging library that enforces it.

**Anti-pattern 6: Neglecting the observability stack**
Prometheus runs out of disk space during a major incident. The monitoring system goes dark exactly when it's needed most. The on-call engineer is flying blind. *Fix:* Monitor your monitoring. Prometheus has metrics about itself (`prometheus_tsdb_*`). Alert on storage > 80%, scrape failures > 5%, and rule evaluation latency > 30s.

---

## Interview Questions {#interview-questions}

**Conceptual:**

1. *"Explain the difference between monitoring and observability. Give an example of a production failure where monitoring alone would be insufficient."*
   — Look for: pre-defined questions vs exploratory questions; three pillars; example like a cascading failure or novel bug; correlation of signals.

2. *"Walk me through the Four Golden Signals. Why does Google recommend measuring failed request latency separately from successful request latency?"*
   — Look for: latency/traffic/errors/saturation definitions; fail-fast failures skew averages; separate SLIs for error rate and latency.

3. *"What is a burn rate alert and why is it superior to a simple error-rate threshold alert?"*
   — Look for: budget consumption rate vs instantaneous threshold; reduces false positives; links alert to SLO impact; double-window technique.

**Scenario-based:**

4. *"Your checkout service P99 latency alert fires at 2am. You open Grafana and see latency is 2,000ms vs normal 200ms — but error rate is normal (0.1%). Traffic is normal. Where do you look next and why?"*
   — Look for: slow successful requests = downstream dependency issue; open distributed traces filtered by high duration; look for long database/cache spans; USE method on database nodes; check for lock contention, missing indexes, connection pool saturation.

5. *"A developer asks why their new service's Prometheus metrics aren't showing up. They've added the prometheus_client library and defined a counter. What are the five most likely causes?"*
   — Look for: no `/metrics` endpoint exposed; endpoint on wrong port; pod not annotated for scraping; counter not incremented (defined but never called); label cardinality causing silent drop; scrape config missing or wrong job_name.

---

## Further Reading & Resources {#further-reading}

**Books:**
- *Observability Engineering* — Majors, Fong-Jones, Miranda (O'Reilly) — The definitive guide to modern observability with OTel
- *Prometheus: Up & Running* — Brazil (O'Reilly) — Complete Prometheus reference
- *Distributed Systems Observability* — Sridharan (O'Reilly, free PDF) — Short, excellent primer on the three pillars

**Online:**
- [Brendan Gregg's USE Method](https://www.brendangregg.com/usemethod.html) — Original reference with Linux-specific implementation
- [Google SRE Book: Monitoring Distributed Systems](https://sre.google/sre-book/monitoring-distributed-systems/) — The Four Golden Signals source
- [OpenTelemetry Documentation](https://opentelemetry.io/docs/) — Official OTel instrumentation guides
- [Robust Perception: PromQL for Humans](https://www.robustperception.io/blog) — Deep PromQL tutorials

**Talks:**
- "Distributed Tracing: We've Been Doing It Wrong" — Cindy Sridharan (QCon)
- "The Art of SLOs" — CRE Life Lessons (Google Cloud) — Practical SLO definition and alerting
- "How Observability and SLOs Work Together" — Grafana ObservabilityCON

---

## Key Takeaways {#key-takeaways}

> **Chapter 3 Summary**
>
> - **Monitoring answers expected questions; observability answers unexpected ones.** You need monitoring for operational health and alerting, and observability for debugging novel failures. Build both.
>
> - **The Three Pillars — metrics, logs, traces — are complementary.** Metrics tell you *that* something changed. Logs tell you *what* happened. Traces tell you *where* in the request path. Correlating all three via `trace_id` compresses incident debug time from hours to minutes.
>
> - **The Four Golden Signals (latency, traffic, errors, saturation) are the minimum viable instrumentation** for any user-facing service. Apply USE for infrastructure resources and RED for per-service microservice dashboards.
>
> - **Alert on symptoms, not causes.** Cause-based alerts (CPU > 80%) create noise without actionability. Symptom-based, SLO burn rate alerts page only when users are actually impacted — or will be imminently.
>
> - **Burn rate alerting links every page to SLO consumption.** A 14.4× burn rate over 1 hour depletes your monthly error budget in 2 days. This replaces arbitrary thresholds with mathematically grounded urgency.
>
> - **Dashboard design is an operational skill.** Design for the incident, not the steady state. Every dashboard should answer a specific question, show deployment markers, and display SLO thresholds as reference lines.
>
> - **OpenTelemetry is the future of instrumentation.** Instrument once; route to any backend. Avoid vendor lock-in by building on OTel from day one.
>
> - **Cardinality is Prometheus's Achilles heel.** Never use unbounded values (user IDs, IPs, trace IDs) as metric labels. High-cardinality attributes belong in traces and logs.

---

*Previous: [Chapter 2 — From DevOps to Site Reliability Engineering](#chapter2)*
*Next: Chapter 4 — Incident Management and Risk Mitigation*


