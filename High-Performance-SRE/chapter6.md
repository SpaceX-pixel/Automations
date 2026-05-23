# High Performance Site Reliability Engineering: A Complete Study Guide

---

# Chapter 6 — SLI / SLO / SLA

---

## Table of Contents

- [Learning Objectives](#learning-objectives)
- [Core Concepts](#core-concepts)
  - [6.1 The SLI/SLO/SLA Hierarchy](#61-the-hierarchy)
  - [6.2 Defining Meaningful SLIs](#62-defining-meaningful-slis)
  - [6.3 SLI Categories and Measurement Patterns](#63-sli-categories)
  - [6.4 User Journey Mapping to Indicators](#64-user-journey-mapping)
  - [6.5 Setting Realistic SLOs](#65-setting-realistic-slos)
  - [6.6 SLO Target Selection — The Negotiation](#66-slo-target-selection)
  - [6.7 SLA — Contractual Obligations and Legal Reality](#67-sla-contractual)
  - [6.8 SLA Tiers and Compensation Models](#68-sla-tiers)
  - [6.9 Multi-Window Multi-Burn-Rate Alerts — Complete Implementation](#69-multi-window-alerts)
  - [6.10 SLO Dashboards — Design and Implementation](#610-slo-dashboards)
  - [6.11 SLO Reporting — Internal and External](#611-slo-reporting)
  - [6.12 SLO Review Cadence and Iteration](#612-slo-review-cadence)
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

- Articulate the precise distinctions between SLI, SLO, and SLA — and explain how violations at each level trigger different organizational responses.
- Define SLIs that genuinely reflect user experience, avoiding the common trap of instrumenting what is easy to measure rather than what matters.
- Map complete user journeys to indicator sets, ensuring every critical path has coverage before a service enters production.
- Set SLO targets grounded in user research, business requirements, and technical feasibility — not guesswork or organizational politics.
- Implement the complete multi-window multi-burn-rate alerting framework in PromQL, covering four alert tiers with distinct severity and response expectations.
- Build SLO dashboards and reporting pipelines that communicate reliability state accurately to technical and non-technical audiences.

---

## Core Concepts {#core-concepts}

### 6.1 The SLI/SLO/SLA Hierarchy {#61-the-hierarchy}

Three terms, three layers of commitment, three distinct organizational responses when violated. Confusing them — and organizations frequently do — leads to either under-engineered reliability or catastrophically misaligned customer expectations.

```
┌─────────────────────────────────────────────────────────────────────┐
│                     The SLI/SLO/SLA Hierarchy                      │
│                                                                     │
│  SLA  ─── Contractual commitment to customers                       │
│  │        "We guarantee 99.9% availability per month.               │
│  │         Breach → service credits, legal liability."              │
│  │                                                                  │
│  │        Always more lenient than the SLO.                         │
│  │        The SLO is the internal warning system.                   │
│  │                                                                  │
│  SLO  ─── Internal engineering target                               │
│  │        "We aim for 99.95% availability.                          │
│  │         Breach → error budget freeze, reliability sprint."        │
│  │                                                                  │
│  │        Always tighter than the SLA.                              │
│  │        The gap is the buffer against SLA breach.                 │
│  │                                                                  │
│  SLI  ─── The measurement itself                                    │
│           "The fraction of HTTP requests returning                  │
│            non-5xx responses in under 300ms."                       │
│                                                                     │
│           A ratio: good events / total events                       │
│           Feeds the SLO. Defines the error budget.                  │
└─────────────────────────────────────────────────────────────────────┘
```

**The three-layer buffer model:**

```
SLI measurement     →    99.97% (actual performance)
SLO target          →    99.95% (internal warning threshold)
SLA commitment      →    99.90% (external contractual promise)

Buffer 1: SLI vs SLO     = 0.02% headroom before internal alarm
Buffer 2: SLO vs SLA     = 0.05% buffer before customer impact
Buffer 3: SLA vs failure = Service credits, not catastrophe

If SLI drops to 99.91%:
  → SLO breached → error budget freeze, reliability sprint
  → SLA intact   → no customer credit required
  → Buffer absorbed the hit before it reached the customer
```

**Violation responses at each layer:**

| Layer | Violation Response | Owner | Urgency |
|-------|-------------------|-------|---------|
| SLI misses SLO | Error budget policy triggered. Feature freeze. Reliability sprint. | Engineering + SRE | Hours to days |
| SLO breach (sustained) | Executive escalation. Emergency reliability investment. | VP Engineering | Days |
| SLA breach | Legal review. Customer notification. Service credits issued. Customer success engaged. | Legal + Leadership | Immediate |

---

### 6.2 Defining Meaningful SLIs {#62-defining-meaningful-slis}

The most common and most damaging SLI mistake is measuring what is easy to instrument — CPU, memory, disk — rather than what the user actually experiences.

**The SLI test:** Can a user feel the difference between SLI = 99% and SLI = 98%? If not, it is not a meaningful SLI.

A CPU utilization SLI fails this test — users don't experience CPU. A checkout success rate SLI passes — users directly experience failed checkout attempts.

#### SLI Design Principles

**Principle 1: Measure from the user's vantage point.**
The ideal SLI is measured as close to the user as possible — at the load balancer, CDN edge, or client SDK. An SLI measured inside the service misses failures that occur between the user and the service (DNS failures, network partitions, CDN misconfigurations).

```
User ──► CDN ──► Load Balancer ──► API Gateway ──► Service ──► Database
  │        │           │                │               │           │
  ▼        ▼           ▼                ▼               ▼           ▼
Best    Better      Good            Acceptable      Internal    Too deep
(client (edge)     (infra)         (app layer)     only)       (no user
 SDK)                                                            signal)
```

**Principle 2: SLIs are ratios, not raw counts.**
An SLI is always expressed as: `good events / total events`. This normalization makes the SLI comparable across traffic volumes, time windows, and service scales.

```
❌ Wrong SLI: "Number of 500 errors per minute"
   Problem: 100 errors/minute at 10,000 RPS is fine.
            100 errors/minute at 200 RPS is catastrophic.

✅ Correct SLI: "Fraction of requests returning non-5xx response"
   500 errors / 10,000 total = 5% error rate = clear signal
```

**Principle 3: Define "good" precisely and conservatively.**
"Good" must be an unambiguous boolean classification for every request. Ambiguous good/bad classification produces noisy, unreliable SLIs.

```python
# SLI good-event classification — be explicit about every condition

def is_good_request(
    status_code: int,
    duration_ms: float,
    response_body: dict
) -> bool:
    """
    Classify whether a checkout request was 'good' from user perspective.
    A request is good ONLY IF all three conditions are met.
    """
    # Condition 1: HTTP success (not 5xx)
    if status_code >= 500:
        return False

    # Condition 2: Within latency threshold
    if duration_ms > 300:
        return False

    # Condition 3: Response contains required fields
    # (prevents 200 OK with empty/malformed body from counting as good)
    required_fields = {"order_id", "status", "confirmation_number"}
    if not required_fields.issubset(response_body.keys()):
        return False

    return True
```

**Principle 4: Exclude client errors from the denominator selectively.**
HTTP 4xx errors are typically caused by clients (invalid input, unauthorized requests). Including 400/401/403/404 in the total inflates the denominator and masks real server failures. But 429 (rate limited) and 408 (timeout) may indicate server-side problems.

```promql
# SLI: availability — excluding expected client errors
# "Good" = non-5xx AND non-429 AND non-408
# "Total" = all requests EXCEPT pure client errors (400, 401, 403, 404)

sum(rate(http_requests_total{
  service="checkout",
  status_code!~"5..|429|408"
}[5m]))
/
sum(rate(http_requests_total{
  service="checkout",
  status_code!~"400|401|403|404"
}[5m]))
```

**Principle 5: Maintain SLI independence.**
If two SLIs are highly correlated (both go bad at the same time for the same reason), they don't provide independent signal — they just double-count the same failure. Define SLIs that cover orthogonal failure modes.

```
Independent SLI set for checkout:
  SLI 1: Availability     (HTTP success rate) ─── orthogonal ───► SLI 3
  SLI 2: Latency          (P99 < 300ms)       ─── independent ──► SLI 4
  SLI 3: Correctness      (order confirmed in DB after payment)
  SLI 4: Freshness        (inventory data < 60s old)

  SLI 1 and SLI 2 may correlate during overload (errors spike AND latency spikes)
  but each can fail independently — availability is fine while latency is bad
  (slow but returning 200s), or vice versa (fast 500s).
```

---

### 6.3 SLI Categories and Measurement Patterns {#63-sli-categories}

Different service types require different SLI categories. Google's SRE Workbook defines five primary SLI categories that cover virtually every service type.

#### Category 1: Availability

*The fraction of time the service is usable.*

```promql
# Availability SLI — request success rate
# Good: non-5xx, non-timeout responses
# Total: all valid incoming requests

(
  sum(rate(http_requests_total{
    service="$service",
    status_code!~"5..|408|429"
  }[28d]))
)
/
(
  sum(rate(http_requests_total{
    service="$service",
    status_code!~"400|401|403|404"
  }[28d]))
)
```

**Availability SLI for a TCP service (non-HTTP):**
```yaml
# Blackbox exporter probe — for services without HTTP
# Counts successful TCP connects as "good" events
- job_name: 'tcp-availability'
  metrics_path: /probe
  params:
    module: [tcp_connect]
  static_configs:
    - targets:
        - "payment-service.internal:5432"
        - "cache.internal:6379"
  relabel_configs:
    - source_labels: [__address__]
      target_label: __param_target
    - source_labels: [__param_target]
      target_label: instance
    - target_label: __address__
      replacement: blackbox-exporter:9115
```

#### Category 2: Latency

*The fraction of requests served within a specified threshold.*

Note: Latency SLIs are expressed as *availability* of fast responses — "what fraction of requests were fast?" — not as a raw percentile. This makes them directly usable as error budgets.

```promql
# Latency SLI — fraction of requests completing under 300ms
# This is more useful than P99 latency for SLO purposes
# because it gives a ratio that feeds directly into the budget

sum(rate(http_request_duration_seconds_bucket{
  service="checkout",
  le="0.3"         # 300ms threshold
}[28d]))
/
sum(rate(http_request_duration_seconds_count{
  service="checkout"
}[28d]))
```

**Multiple latency thresholds:**
For services with heterogeneous request types, define latency SLIs per request class:

```promql
# Fast path (search autocomplete): 95% under 50ms
sum(rate(http_request_duration_seconds_bucket{
  service="search", route="/api/autocomplete", le="0.05"
}[28d]))
/
sum(rate(http_request_duration_seconds_count{
  service="search", route="/api/autocomplete"
}[28d]))

# Slow path (report generation): 90% under 30s
sum(rate(http_request_duration_seconds_bucket{
  service="search", route="/api/reports", le="30"
}[28d]))
/
sum(rate(http_request_duration_seconds_count{
  service="search", route="/api/reports"
}[28d]))
```

#### Category 3: Quality / Correctness

*The fraction of responses that are correct and complete.*

Quality SLIs are harder to instrument but often most important. A service that returns 200 OK with corrupted data has perfect availability and terrible quality.

```python
# Quality SLI instrumentation — in-application validation
# Increment good/bad counters based on business logic validation

from prometheus_client import Counter

RESPONSE_QUALITY = Counter(
    'response_quality_total',
    'Response quality classification',
    ['service', 'endpoint', 'quality']  # quality: good | bad
)

def validate_order_response(response: dict, order_id: str) -> bool:
    """
    Validate that an order response meets quality criteria.
    Returns True if response is 'good' for SLI purposes.
    """
    required_fields = {
        "order_id", "status", "items", "total_usd",
        "confirmation_number", "estimated_delivery"
    }

    # Check required fields present
    if not required_fields.issubset(response.keys()):
        RESPONSE_QUALITY.labels(
            service="checkout",
            endpoint="/api/orders",
            quality="bad"
        ).inc()
        return False

    # Check business logic: total matches item sum
    item_total = sum(item["price"] * item["quantity"]
                     for item in response["items"])
    if abs(item_total - response["total_usd"]) > 0.01:  # Allow rounding
        RESPONSE_QUALITY.labels(
            service="checkout",
            endpoint="/api/orders",
            quality="bad"
        ).inc()
        return False

    # Check order ID matches request
    if response["order_id"] != order_id:
        RESPONSE_QUALITY.labels(
            service="checkout",
            endpoint="/api/orders",
            quality="bad"
        ).inc()
        return False

    RESPONSE_QUALITY.labels(
        service="checkout",
        endpoint="/api/orders",
        quality="good"
    ).inc()
    return True
```

#### Category 4: Freshness

*The fraction of data that is sufficiently up-to-date.*

Critical for data pipelines, caches, and read-heavy services where stale data causes user harm.

```promql
# Freshness SLI — fraction of cache entries under 60 seconds old
# "Good" = data age under threshold
# "Total" = all data reads

sum(rate(cache_reads_total{
  service="inventory",
  data_age_seconds="<60"     # custom label set during cache read
}[1h]))
/
sum(rate(cache_reads_total{service="inventory"}[1h]))
```

```python
# Freshness measurement for a data pipeline
import time
from prometheus_client import Histogram, Counter

DATA_FRESHNESS = Histogram(
    'pipeline_data_age_seconds',
    'Age of data when read from pipeline output',
    ['pipeline', 'dataset'],
    buckets=[30, 60, 120, 300, 600, 1800, 3600]
)

FRESHNESS_SLI = Counter(
    'pipeline_freshness_total',
    'Data freshness SLI good/bad events',
    ['pipeline', 'dataset', 'freshness']  # freshness: good | stale
)

FRESHNESS_THRESHOLD_SECONDS = 300   # 5 minutes SLO threshold

def read_pipeline_data(pipeline: str, dataset: str):
    data = fetch_from_pipeline(pipeline, dataset)
    age_seconds = time.time() - data.created_at.timestamp()

    DATA_FRESHNESS.labels(
        pipeline=pipeline, dataset=dataset
    ).observe(age_seconds)

    quality = "good" if age_seconds <= FRESHNESS_THRESHOLD_SECONDS else "stale"
    FRESHNESS_SLI.labels(
        pipeline=pipeline, dataset=dataset, freshness=quality
    ).inc()

    return data
```

#### Category 5: Throughput / Coverage

*The fraction of expected work that is processed successfully.*

Used for batch jobs, queues, and async systems where the SLI is not per-request but per-unit-of-work.

```promql
# Throughput SLI — fraction of queued messages processed successfully
# Used for: email delivery, payment processing queues, ETL pipelines

sum(rate(message_processing_total{
  service="notifications",
  status="success"
}[1h]))
/
sum(rate(message_processing_total{
  service="notifications"
}[1h]))
```

---

### 6.4 User Journey Mapping to Indicators {#64-user-journey-mapping}

The most rigorous approach to SLI definition starts not with metrics but with **user journeys** — the sequences of actions users take to accomplish goals. Every step in a critical user journey that can fail needs an SLI.

#### User Journey Mapping Process

```
Step 1: Identify critical user journeys
  → What are the 3-5 actions that, if broken, cause users to
    immediately seek alternatives or abandon the product?

Step 2: Map each journey step by step
  → For an e-commerce checkout: search → view product → add to cart
    → enter payment → confirm order → receive confirmation

Step 3: For each step, identify failure modes
  → What breaks? How does the user experience the failure?
    Is it silent (wrong result) or loud (error page)?

Step 4: Define an SLI for each critical failure mode
  → What metric distinguishes "working correctly" from "failing"?
    Where is it measured? What is the good-event definition?

Step 5: Validate coverage
  → For every past incident that caused user impact,
    would at least one SLI have caught it?
    If not, add the missing SLI.
```

#### Worked Example: E-Commerce Platform User Journeys

```
┌─────────────────────────────────────────────────────────────────────┐
│          Critical User Journey: Complete a Purchase                 │
│                                                                     │
│  [1] Search    [2] Browse    [3] Cart     [4] Checkout  [5] Confirm │
│   Product       Product       Mgmt        Payment       Order       │
│      │             │            │             │            │        │
│      ▼             ▼            ▼             ▼            ▼        │
│  SLI: Search   SLI: Page    SLI: Cart    SLI: Payment SLI: Order   │
│  result        load time    operation    success rate  confirm      │
│  relevance     <2s          success      <3s           delivery     │
│  & speed       (95%)        rate (99.9%) (99.95%)      rate (99.9%) │
└─────────────────────────────────────────────────────────────────────┘
```

#### Complete Journey-to-SLI Mapping Table

```
User Journey: E-Commerce Checkout
──────────────────────────────────────────────────────────────────────────────────
Journey     User         Failure           SLI                  SLO
Step        Action       Mode              Definition           Target
──────────────────────────────────────────────────────────────────────────────────
1. Search   Query for    No results,       Fraction of search   99.5%
            product      wrong results,    requests returning   availability
                         timeout           ≥1 result in <500ms  95% latency
                                                                (<500ms)

2. Browse   View         Page doesn't      Fraction of product  99.9%
            product      load, missing     page requests        availability
            detail       images, wrong     completing in <2s    95% latency
                         price             with complete data   (<2s)

3. Cart     Add item,    Item not added,   Fraction of cart     99.95%
            update       quantity wrong,   mutations completing availability
            quantity     cart lost         correctly in <1s     99% latency
                                                                (<1s)

4. Checkout Enter        Payment error,    Fraction of payment  99.95%
            payment,     timeout, wrong    attempts completing  availability
            submit       charge amount     in <3s with correct  99% latency
                                           amount               (<3s)

5. Confirm  Receive      No email,         Fraction of orders   99.9%
            order        wrong order       receiving confirm.   availability
            confirmation details,          email within 5min    95% freshness
                         delayed email     with correct details (<5min)
──────────────────────────────────────────────────────────────────────────────────
```

#### Mapping to PromQL: The Journey SLI Pyramid

Each journey step translates to specific PromQL expressions that can be combined into a single composite SLI:

```promql
# Journey Step 3: Cart Operations
# Good = cart operation succeeds AND completes within 1 second

# Availability component
sum(rate(http_requests_total{
  service="cart",
  route=~"/api/cart.*",
  status_code!~"5.."
}[28d]))
/
sum(rate(http_requests_total{
  service="cart",
  route=~"/api/cart.*",
  status_code!~"400|401|403|404"
}[28d]))

# Latency component (fraction of cart ops under 1s)
sum(rate(http_request_duration_seconds_bucket{
  service="cart",
  route=~"/api/cart.*",
  le="1.0"
}[28d]))
/
sum(rate(http_request_duration_seconds_count{
  service="cart",
  route=~"/api/cart.*"
}[28d]))

# Composite: good only if BOTH conditions met
# (requires application-level instrumentation or service mesh)
sum(rate(cart_operations_total{result="good"}[28d]))
/
sum(rate(cart_operations_total[28d]))
```

#### Synthetic Journey Monitoring

For complete journey validation, synthetic monitors replay the full user journey from external locations:

```python
# Synthetic monitor: complete purchase journey
# Runs every 5 minutes from multiple regions
# Reports journey-level SLI metrics

import time
import requests
from dataclasses import dataclass
from prometheus_client import Counter, Histogram

JOURNEY_RESULT = Counter(
    'synthetic_journey_total',
    'Synthetic journey results',
    ['journey', 'region', 'step', 'result']
)

JOURNEY_DURATION = Histogram(
    'synthetic_journey_duration_seconds',
    'End-to-end journey duration',
    ['journey', 'region'],
    buckets=[1, 2, 5, 10, 20, 30, 60]
)

@dataclass
class JourneyStep:
    name: str
    fn: callable
    timeout_s: float
    required: bool = True   # If False, failure doesn't abort journey

def run_purchase_journey(region: str, base_url: str) -> dict:
    session = requests.Session()
    results = {}
    journey_start = time.time()

    steps = [
        JourneyStep("search",   lambda: _step_search(session, base_url),   5.0),
        JourneyStep("view",     lambda: _step_view_product(session, base_url), 3.0),
        JourneyStep("add_cart", lambda: _step_add_to_cart(session, base_url),  2.0),
        JourneyStep("checkout", lambda: _step_checkout(session, base_url),     5.0),
        JourneyStep("confirm",  lambda: _step_confirm(session, base_url),      3.0),
    ]

    for step in steps:
        step_start = time.time()
        try:
            step.fn()
            result = "good"
        except Exception as e:
            result = "bad"
            results[step.name] = {"result": "bad", "error": str(e)}
            if step.required:
                # Abort journey — downstream steps are meaningless
                break

        JOURNEY_RESULT.labels(
            journey="purchase",
            region=region,
            step=step.name,
            result=result
        ).inc()
        results[step.name] = {
            "result": result,
            "duration_ms": (time.time() - step_start) * 1000
        }

    total_duration = time.time() - journey_start
    JOURNEY_DURATION.labels(journey="purchase", region=region).observe(total_duration)

    return results

def _step_search(session, base_url):
    r = session.get(f"{base_url}/api/search?q=laptop", timeout=5)
    assert r.status_code == 200
    assert len(r.json().get("results", [])) > 0, "Empty search results"

def _step_view_product(session, base_url):
    r = session.get(f"{base_url}/api/products/TEST-SKU-001", timeout=3)
    assert r.status_code == 200
    data = r.json()
    assert "price" in data and "name" in data

def _step_add_to_cart(session, base_url):
    r = session.post(
        f"{base_url}/api/cart",
        json={"product_id": "TEST-SKU-001", "quantity": 1},
        timeout=2
    )
    assert r.status_code == 201

def _step_checkout(session, base_url):
    # Use test payment token — does not charge real card
    r = session.post(
        f"{base_url}/api/checkout",
        json={"payment_token": "tok_synthetic_test_visa"},
        timeout=5
    )
    assert r.status_code == 200
    assert r.json().get("status") == "pending_confirmation"

def _step_confirm(session, base_url):
    # Poll for order confirmation (max 30s)
    for _ in range(6):
        time.sleep(5)
        r = session.get(f"{base_url}/api/orders/latest", timeout=3)
        if r.status_code == 200 and r.json().get("status") == "confirmed":
            return
    raise AssertionError("Order not confirmed within 30 seconds")
```

---

### 6.5 Setting Realistic SLOs {#65-setting-realistic-slos}

SLO setting is part science, part negotiation, part organizational psychology. An SLO set too high creates an unachievable target that burns budget immediately and demoralizes the team. An SLO set too low creates no tension and no investment signal.

#### The Four Inputs to SLO Setting

**Input 1: User research — what do users actually need?**

The most rigorous input, and the least commonly used. Conduct user research to find the reliability level below which users notice degradation, start complaining, and consider alternatives.

Typical findings:
- Availability: users start noticing outages > 1 hour/month (≈ 99.86%)
- Latency: users perceive slowness above ~300ms for interactive flows; above ~3s for non-critical flows
- Freshness: tolerable staleness varies dramatically by use case (real-time trading: seconds; news feed: minutes; analytics: hours)

**Input 2: Historical performance — what can the system currently achieve?**

Setting an SLO above current performance guarantees immediate breach. Start with data:

```python
def calculate_historical_slo(
    prometheus_url: str,
    service: str,
    lookback_days: int = 90
) -> dict:
    """
    Calculate historical SLI performance to inform SLO target selection.
    Query Prometheus for 90-day performance baseline.
    """
    import requests

    def query(q):
        r = requests.get(
            f"{prometheus_url}/api/v1/query_range",
            params={
                "query": q,
                "start": f"now-{lookback_days}d",
                "end": "now",
                "step": "1d"
            }
        )
        values = [float(v[1]) for v in r.json()["data"]["result"][0]["values"]]
        return values

    availability_values = query(
        f'sum(rate(http_requests_total{{service="{service}",status_code!~"5.."}}[1d]))'
        f'/sum(rate(http_requests_total{{service="{service}"}}[1d]))'
    )

    import statistics
    avail = sorted(availability_values)
    n = len(avail)

    return {
        "p50_availability": statistics.median(avail),
        "p5_availability":  avail[int(n * 0.05)],    # Worst 5% of days
        "p1_availability":  avail[int(n * 0.01)],    # Worst 1% of days
        "min_availability": avail[0],
        "recommended_slo":  avail[int(n * 0.05)],    # P5 = achievable with effort
        "aspirational_slo": statistics.mean(avail),  # Average = stretch target
    }
```

**Input 3: Business requirements — what does the product promise?**

SLAs with customers, regulatory requirements (e.g., banking uptime mandates), and contractual commitments define minimum SLO requirements. The SLO must be tight enough to protect the SLA.

```
SLO = SLA + Safety Buffer

If SLA commits to 99.9%:
  SLO target = 99.95%   (50% buffer above SLA)

If SLA commits to 99.99%:
  SLO target = 99.995%  (requires extreme investment)
```

**Input 4: Cost of reliability — what is the marginal cost of each 9?**

Each additional "9" of reliability is roughly an order of magnitude more expensive than the previous one. This input ensures SLO targets are financially rational.

```
Cost of Reliability (rough order of magnitude)
─────────────────────────────────────────────────────────────
99%     → Active/passive HA, basic redundancy
99.9%   → Active/active, auto-failover, runbooks
99.99%  → Multi-region active/active, chaos engineering,
           dedicated SRE team, sophisticated monitoring
99.999% → Extremely expensive. Justified only for
          life-safety or massive-revenue-per-minute systems.
─────────────────────────────────────────────────────────────
```

#### The SLO Setting Decision Matrix

```
                    High User Sensitivity
                            │
      Tight SLO (99.95%+)  │  Tight SLO (99.99%+)
      e.g., Social feed     │  e.g., Payments, Banking
                            │
Low ────────────────────────┼──────────────────── High
Business                    │                   Business
Impact                      │                   Impact
                            │
      Relaxed SLO (99%)     │  Moderate SLO (99.9%)
      e.g., Internal tools  │  e.g., Analytics, Reports
                            │
                    Low User Sensitivity
```

---

### 6.6 SLO Target Selection — The Negotiation {#66-slo-target-selection}

In practice, SLO targets are set through a negotiation between SREs (who know what is technically achievable), product managers (who know what users need), and business leadership (who know the contractual and financial constraints).

The negotiation should be grounded in data, not opinion.

#### SLO Negotiation Framework

```
Phase 1: Anchor with data
  SRE presents: historical SLI performance (90-day baseline)
  PM presents:  user research on sensitivity thresholds
  Business presents: SLA commitments and regulatory requirements

Phase 2: Propose a starting point
  Recommended approach:
    Initial SLO = median(P5 historical performance,
                         user sensitivity threshold,
                         SLA + safety buffer)

Phase 3: Model the error budget
  For proposed SLO, calculate:
    - Error budget in minutes and requests
    - How many past incidents would have breached this budget
    - What budget remains after historical incidents
  This makes the SLO target viscerally concrete.

Phase 4: Agree on review cadence
  SLOs are not permanent. Agree:
    - Quarterly review of SLO targets
    - Tighten if consistently above target (wasted headroom)
    - Relax if consistently breaching (unachievable target)
    - Never tighten mid-quarter to avoid retroactive breaches
```

#### SLO Target Negotiation Cheatsheet

| Situation | Recommendation |
|---|---|
| New service, no historical data | Start conservative (99.5%). Tighten after 2 quarters. |
| Service consistently at 99.97% vs 99.9% SLO | Tighten to 99.95%. The gap gives false confidence. |
| SLO consistently breached | Either lower the target or fund the reliability investment to meet it. Never leave a chronic breach unaddressed. |
| Team inheriting legacy service | Set SLO at current P10 performance. Create backlog to improve. |
| Launching a new critical service | Set SLO at P5 of comparable services. Run GameDay before launch. |

---

### 6.7 SLA — Contractual Obligations and Legal Reality {#67-sla-contractual}

SLAs are contracts. Breaching them has legal and financial consequences. SREs must understand SLAs not just as reliability targets but as legal documents.

#### SLA Components

A well-constructed SLA specifies:

```
SLA Anatomy
─────────────────────────────────────────────────────────────────
1. Covered Services
   Which specific services and features are covered?
   Which are explicitly excluded?

2. Availability Definition
   How is "available" defined? (HTTP 2xx? TCP connect? Feature set?)
   What measurement method? (Prometheus? Third-party monitoring?)
   Who is the authoritative source of truth?

3. Measurement Window
   Monthly? Quarterly? Annual?
   Rolling or calendar-aligned?

4. Exclusions (what doesn't count as downtime)
   Scheduled maintenance (with advance notice)
   Force majeure (natural disasters, widespread internet outages)
   Customer-caused outages (traffic exceeding contracted limits)
   Third-party failures (AWS region outage, Stripe outage)
   Beta/preview features

5. Reporting and Verification
   How does the customer verify SLA compliance?
   What is the dispute resolution process?
   What data is provided to the customer?

6. Remedies and Credits
   What credits are issued for each tier of breach?
   Are credits automatic or must they be requested?
   Are credits the sole remedy, or can customers terminate?
   Is there a cap on total credits per period?
─────────────────────────────────────────────────────────────────
```

#### SLA vs SLO Gap Analysis

The gap between SLA and SLO must be large enough to absorb realistic incident scenarios:

```python
def sla_slo_gap_analysis(
    sla_target: float,
    slo_target: float,
    window_days: int,
    historical_incidents: list  # list of (duration_minutes, severity) tuples
) -> dict:
    """
    Analyze whether the SLO-SLA buffer is sufficient given historical incidents.
    """
    budget_total_minutes = window_days * 24 * 60

    # Budget calculations
    slo_budget_minutes = budget_total_minutes * (1 - slo_target)
    sla_budget_minutes = budget_total_minutes * (1 - sla_target)
    buffer_minutes = sla_budget_minutes - slo_budget_minutes

    # Simulate historical incidents against the SLO
    slo_breach_months = 0
    sla_breach_months = 0

    for month_incidents in historical_incidents:
        month_downtime = sum(d for d, _ in month_incidents)
        if month_downtime > slo_budget_minutes:
            slo_breach_months += 1
        if month_downtime > sla_budget_minutes:
            sla_breach_months += 1

    total_months = len(historical_incidents)

    return {
        "sla_target":            f"{sla_target:.4%}",
        "slo_target":            f"{slo_target:.4%}",
        "slo_budget_minutes":    round(slo_budget_minutes, 1),
        "sla_budget_minutes":    round(sla_budget_minutes, 1),
        "buffer_minutes":        round(buffer_minutes, 1),
        "slo_breach_rate":       f"{slo_breach_months}/{total_months} months",
        "sla_breach_rate":       f"{sla_breach_months}/{total_months} months",
        "buffer_adequate":       sla_breach_months == 0,
        "recommendation":        (
            "Buffer adequate — SLA never breached historically"
            if sla_breach_months == 0 else
            f"WARNING: SLA breached {sla_breach_months}x historically. "
            f"Widen SLO-SLA gap or improve reliability."
        )
    }
```

---

### 6.8 SLA Tiers and Compensation Models {#68-sla-tiers}

Enterprise SaaS products typically offer tiered SLAs with corresponding compensation structures. SREs must understand these tiers to calibrate SLO targets per tier.

#### Standard SLA Tier Model

```
┌──────────────────────────────────────────────────────────────────────┐
│                     SLA Tier Structure                               │
├─────────────┬────────────┬──────────────────┬────────────────────────┤
│ Tier        │ SLA Target │ Compensation     │ SRE SLO Target         │
├─────────────┼────────────┼──────────────────┼────────────────────────┤
│ Enterprise  │ 99.99%     │ 25% credit if    │ 99.995%                │
│             │            │ <99.99%          │                        │
│             │            │ 50% if <99.9%    │                        │
│             │            │ 100% if <99%     │                        │
├─────────────┼────────────┼──────────────────┼────────────────────────┤
│ Business    │ 99.9%      │ 10% credit if    │ 99.95%                 │
│             │            │ <99.9%           │                        │
│             │            │ 25% if <99%      │                        │
├─────────────┼────────────┼──────────────────┼────────────────────────┤
│ Starter     │ 99.5%      │ No SLA credits   │ 99.7%                  │
│             │            │ (best effort)    │                        │
│             │            │                  │                        │
├─────────────┼────────────┼──────────────────┼────────────────────────┤
│ Free        │ None       │ No commitment    │ Internal target only   │
└─────────────┴────────────┴──────────────────┴────────────────────────┘
```

#### SLA Monitoring for Compliance

```python
# SLA compliance monitoring — track per customer tier
# Run daily to generate compliance report and flag customers approaching breach

from datetime import datetime, timedelta
from typing import List, Dict
import requests

SLA_TIERS = {
    "enterprise": {"target": 0.9999, "credit_threshold_1": 0.9999,
                   "credit_pct_1": 25, "credit_threshold_2": 0.999,
                   "credit_pct_2": 50},
    "business":   {"target": 0.999,  "credit_threshold_1": 0.999,
                   "credit_pct_1": 10, "credit_threshold_2": 0.99,
                   "credit_pct_2": 25},
    "starter":    {"target": 0.995,  "credit_threshold_1": None,
                   "credit_pct_1": 0, "credit_threshold_2": None,
                   "credit_pct_2": 0},
}

def calculate_customer_sla_compliance(
    customer_id: str,
    tier: str,
    month_start: datetime,
    actual_availability: float,
    mrr: float
) -> dict:
    """Calculate SLA compliance and credit amount for a customer."""
    sla = SLA_TIERS[tier]
    sla_met = actual_availability >= sla["target"]

    credit_pct = 0
    if sla["credit_threshold_1"] and actual_availability < sla["credit_threshold_1"]:
        credit_pct = sla["credit_pct_1"]
    if sla["credit_threshold_2"] and actual_availability < sla["credit_threshold_2"]:
        credit_pct = sla["credit_pct_2"]  # Higher tier kicks in

    credit_amount = mrr * (credit_pct / 100)
    downtime_minutes = (1 - actual_availability) * 30 * 24 * 60

    return {
        "customer_id":       customer_id,
        "tier":              tier,
        "month":             month_start.strftime("%Y-%m"),
        "sla_target":        f"{sla['target']:.4%}",
        "actual":            f"{actual_availability:.5%}",
        "sla_met":           sla_met,
        "downtime_minutes":  round(downtime_minutes, 1),
        "credit_percentage": credit_pct,
        "credit_amount_usd": round(credit_amount, 2),
        "action_required":   "Issue credit" if credit_amount > 0 else "None",
    }
```

---

### 6.9 Multi-Window Multi-Burn-Rate Alerts — Complete Implementation {#69-multi-window-alerts}

Chapter 5 introduced the burn rate alerting concept. This section provides the complete, production-ready four-tier implementation covering both availability and latency SLIs with full annotation context.

#### The Four-Tier Alert Taxonomy

```
Tier   Window   Burn Rate   Budget/Hour   Severity   Action
─────────────────────────────────────────────────────────────────────────
P1     1h+5m    ≥ 14.4×     ~0.21%        PAGE       Wake on-call NOW
P2     6h+30m   ≥ 6×        ~0.09%        TICKET     Investigate today
P3     3d+6h    ≥ 3×        ~0.04%        NOTIFY     Plan this week
P4     28d      ≥ 1×        = budget/day  REPORT     Review this month
─────────────────────────────────────────────────────────────────────────
P1: Budget gone in ~2 days     → user impact imminent or occurring
P2: Budget gone in ~4.7 days   → serious degradation, act urgently
P3: Budget gone in ~9.3 days   → sustained below-target performance
P4: On pace to just exhaust    → exactly meeting (not exceeding) budget
```

#### Complete PromQL Implementation

```yaml
# slo-alerts-complete.yml
# Full four-tier multi-window burn rate alert set
# Covers: availability SLI + latency SLI

groups:
  # ════════════════════════════════════════════════════════════════
  # RECORDING RULES — Pre-compute all burn rate windows
  # ════════════════════════════════════════════════════════════════
  - name: slo_recording_rules_checkout
    interval: 60s
    rules:

      # ── Availability SLI recording rules ───────────────────────
      - record: job:availability_sli:rate5m
        expr: &availability_sli_expr |
          sum by (job) (
            rate(http_requests_total{status_code!~"5..|408|429"}[5m])
          ) / sum by (job) (
            rate(http_requests_total{status_code!~"400|401|403|404"}[5m])
          )

      - record: job:availability_sli:rate30m
        expr: |
          sum by (job) (
            rate(http_requests_total{status_code!~"5..|408|429"}[30m])
          ) / sum by (job) (
            rate(http_requests_total{status_code!~"400|401|403|404"}[30m])
          )

      - record: job:availability_sli:rate1h
        expr: |
          sum by (job) (
            rate(http_requests_total{status_code!~"5..|408|429"}[1h])
          ) / sum by (job) (
            rate(http_requests_total{status_code!~"400|401|403|404"}[1h])
          )

      - record: job:availability_sli:rate6h
        expr: |
          sum by (job) (
            rate(http_requests_total{status_code!~"5..|408|429"}[6h])
          ) / sum by (job) (
            rate(http_requests_total{status_code!~"400|401|403|404"}[6h])
          )

      - record: job:availability_sli:rate3d
        expr: |
          sum by (job) (
            rate(http_requests_total{status_code!~"5..|408|429"}[3d])
          ) / sum by (job) (
            rate(http_requests_total{status_code!~"400|401|403|404"}[3d])
          )

      - record: job:availability_sli:rate28d
        expr: |
          sum by (job) (
            rate(http_requests_total{status_code!~"5..|408|429"}[28d])
          ) / sum by (job) (
            rate(http_requests_total{status_code!~"400|401|403|404"}[28d])
          )

      # ── Latency SLI recording rules (fraction of requests < 300ms) ──
      - record: job:latency_sli:rate5m
        expr: |
          sum by (job) (
            rate(http_request_duration_seconds_bucket{le="0.3"}[5m])
          ) / sum by (job) (
            rate(http_request_duration_seconds_count[5m])
          )

      - record: job:latency_sli:rate30m
        expr: |
          sum by (job) (
            rate(http_request_duration_seconds_bucket{le="0.3"}[30m])
          ) / sum by (job) (
            rate(http_request_duration_seconds_count[30m])
          )

      - record: job:latency_sli:rate1h
        expr: |
          sum by (job) (
            rate(http_request_duration_seconds_bucket{le="0.3"}[1h])
          ) / sum by (job) (
            rate(http_request_duration_seconds_count[1h])
          )

      - record: job:latency_sli:rate6h
        expr: |
          sum by (job) (
            rate(http_request_duration_seconds_bucket{le="0.3"}[6h])
          ) / sum by (job) (
            rate(http_request_duration_seconds_count[6h])
          )

      - record: job:latency_sli:rate3d
        expr: |
          sum by (job) (
            rate(http_request_duration_seconds_bucket{le="0.3"}[3d])
          ) / sum by (job) (
            rate(http_request_duration_seconds_count[3d])
          )

      # ── Composite SLI (availability AND latency) ───────────────
      # A request is "good" only if it is both fast AND successful
      # Approximated as: min(availability_sli, latency_sli)
      # For production use, instrument composite directly at app layer

      - record: job:composite_sli:rate5m
        expr: |
          min by (job) (
            job:availability_sli:rate5m
            or
            job:latency_sli:rate5m
          )

      # ── Error budget remaining ──────────────────────────────────
      # SLO target = 0.999 for 99.9% → budget fraction = 0.001
      - record: job:error_budget_remaining:ratio28d
        expr: |
          (job:availability_sli:rate28d - 0.999) / 0.001

  # ════════════════════════════════════════════════════════════════
  # AVAILABILITY ALERTS — Four tiers
  # ════════════════════════════════════════════════════════════════
  - name: slo_availability_alerts_checkout
    rules:

      # ── Tier 1: P1 Fast burn — PAGE ─────────────────────────────
      - alert: SLO_Availability_FastBurn_P1
        expr: |
          (
            (1 - job:availability_sli:rate1h{job="checkout"}) > (14.4 * 0.001)
          and
            (1 - job:availability_sli:rate5m{job="checkout"}) > (14.4 * 0.001)
          )
        for: 2m
        labels:
          severity:   critical
          team:       checkout-oncall
          sli_type:   availability
          tier:       P1
        annotations:
          summary: >
            🔴 [P1] Checkout availability burning critically — PAGE NOW
          description: |
            Service:       checkout
            SLO Target:    99.9%
            Current (1h):  {{ printf "%.4f" (1 - (query "job:availability_sli:rate1h{job='checkout'}" | first | value)) | humanize }}% error rate
            Burn Rate:     {{ printf "%.1f" (div (1 - (query "job:availability_sli:rate1h{job='checkout'}" | first | value)) 0.001) }}× (budget exhausted in ~{{ printf "%.1f" (div 2.0 (div (1 - (query "job:availability_sli:rate1h{job='checkout'}" | first | value)) 0.001)) }} days)
            Budget Left:   {{ printf "%.1f" ((query "job:error_budget_remaining:ratio28d{job='checkout'}" | first | value) * 100) }}%

            🔗 Dashboard:  https://grafana.internal/d/checkout-slo
            📖 Runbook:    https://runbooks.internal/checkout/high-error-rate
            🎫 Incident:   /pd trigger checkout-oncall

      # ── Tier 2: P2 Slow burn — TICKET ───────────────────────────
      - alert: SLO_Availability_SlowBurn_P2
        expr: |
          (
            (1 - job:availability_sli:rate6h{job="checkout"}) > (6 * 0.001)
          and
            (1 - job:availability_sli:rate30m{job="checkout"}) > (6 * 0.001)
          )
        for: 15m
        labels:
          severity:   warning
          team:       checkout-team
          sli_type:   availability
          tier:       P2
        annotations:
          summary: >
            🟡 [P2] Checkout availability elevated — investigate today
          description: |
            6h burn rate above 6× threshold for 15+ minutes.
            Budget will exhaust in ~4-5 days if not addressed.
            Create a ticket and investigate before next deploy.
            Dashboard: https://grafana.internal/d/checkout-slo

      # ── Tier 3: P3 Sustained degradation — NOTIFY ───────────────
      - alert: SLO_Availability_Sustained_P3
        expr: |
          (
            (1 - job:availability_sli:rate3d{job="checkout"}) > (3 * 0.001)
          and
            (1 - job:availability_sli:rate6h{job="checkout"}) > (3 * 0.001)
          )
        for: 1h
        labels:
          severity:   info
          team:       checkout-team
          sli_type:   availability
          tier:       P3
        annotations:
          summary: >
            ℹ️  [P3] Checkout availability below target for 3 days
          description: |
            3-day burn rate at 3× — sustained below-target performance.
            Add reliability investigation to sprint planning.
            Budget depletion estimated in ~9 days at this rate.

      # ── Tier 4: P4 Budget pace alert — WEEKLY REPORT ────────────
      - alert: SLO_Availability_BudgetPace_P4
        expr: |
          job:error_budget_remaining:ratio28d{job="checkout"} < 0.20
        for: 2h
        labels:
          severity:   info
          team:       checkout-team
          sli_type:   availability
          tier:       P4
        annotations:
          summary: >
            📊 [P4] Checkout error budget below 20% — review in monthly report
          description: |
            Budget remaining: {{ printf "%.1f" ($value * 100) }}%.
            Review error budget consumption at monthly reliability review.

  # ════════════════════════════════════════════════════════════════
  # LATENCY ALERTS — Four tiers (mirroring availability)
  # ════════════════════════════════════════════════════════════════
  - name: slo_latency_alerts_checkout
    rules:

      # Latency SLO: 95% of requests under 300ms (budget = 0.05)
      - alert: SLO_Latency_FastBurn_P1
        expr: |
          (
            (1 - job:latency_sli:rate1h{job="checkout"}) > (14.4 * 0.05)
          and
            (1 - job:latency_sli:rate5m{job="checkout"}) > (14.4 * 0.05)
          )
        for: 2m
        labels:
          severity:   critical
          team:       checkout-oncall
          sli_type:   latency
          tier:       P1
        annotations:
          summary: >
            🔴 [P1] Checkout latency SLO burning critically
          description: |
            More than {{ printf "%.1f" ((1 - (query "job:latency_sli:rate5m{job='checkout'}" | first | value)) * 100) }}%
            of requests are exceeding the 300ms latency threshold.
            SLO target: 95% of requests under 300ms.
            Runbook: https://runbooks.internal/checkout/high-latency

      - alert: SLO_Latency_SlowBurn_P2
        expr: |
          (
            (1 - job:latency_sli:rate6h{job="checkout"}) > (6 * 0.05)
          and
            (1 - job:latency_sli:rate30m{job="checkout"}) > (6 * 0.05)
          )
        for: 15m
        labels:
          severity:   warning
          team:       checkout-team
          sli_type:   latency
          tier:       P2
        annotations:
          summary: >
            🟡 [P2] Checkout latency elevated — investigate today
```

---

### 6.10 SLO Dashboards — Design and Implementation {#610-slo-dashboards}

SLO dashboards have a specific purpose distinct from operational dashboards: they communicate reliability commitments and their status over time. The audience includes engineers, product managers, and leadership — each with different information needs.

#### The Four-Panel SLO Dashboard

```
┌─────────────────────────────────────────────────────────────────────┐
│  Checkout Service — SLO Dashboard          [28d] [7d] [1d]  📅     │
├──────────────────┬────────────────┬──────────────┬─────────────────┤
│  AVAILABILITY    │  LATENCY       │ ERROR BUDGET │ BURN RATE       │
│  SLO COMPLIANCE  │  SLO COMPLIANCE│ REMAINING    │ (1h)            │
│                  │                │              │                 │
│  ████████░  ✅   │  ███████░░  ✅ │  ██████░░░░  │                 │
│  99.94%          │  96.2%         │  34%         │  1.8×           │
│  vs 99.90% SLO   │  vs 95% SLO   │ of 28d budget│  ↓ from 3.2×   │
│                  │                │              │                 │
│  SLA: 99.90% ✅  │                │              │                 │
├──────────────────┴────────────────┴──────────────┴─────────────────┤
│  ERROR BUDGET CONSUMPTION — LAST 28 DAYS                           │
│                                                                     │
│  100% ─────────────────────────────────── Budget ceiling           │
│   75% ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  Yellow zone              │
│   50%          ┌─┐ INC-0831                                        │
│   34% ─ ─ ─ ─ ─│─│─ ─ ─ ─ ─ ─ ─ ─ ─ ─  Current level ◄──────    │
│   25%           └─┘                                                │
│    0% ──────────────────────────────────────────────────           │
│       Jan 1     Jan 8     Jan 15    Jan 22    Jan 28               │
│                                                                     │
│       ▼ deploy v2.3    ▼ v2.4   ▼ INC    ▼ v2.5                   │
├──────────────────────┬──────────────────────────────────────────────┤
│  SLI TREND (30-day)  │  RECENT INCIDENTS (budget impact)           │
│                      │                                              │
│  Availability:       │  INC-0847  Jan 22  18 min  14% budget       │
│  ████████████ 99.94% │  INC-0831  Jan 15  23 min   8% budget       │
│                      │  INC-0804  Jan  8   8 min   3% budget       │
│  Latency P99:        │                                              │
│  ████████████  247ms │  Total consumed: 25% of 28d budget          │
└──────────────────────┴──────────────────────────────────────────────┘
```

#### Grafana Dashboard as Code (JSON Model)

```json
{
  "title": "SLO Dashboard — Checkout Service",
  "uid": "checkout-slo-v2",
  "tags": ["slo", "checkout", "reliability"],
  "time": {"from": "now-28d", "to": "now"},
  "refresh": "5m",
  "templating": {
    "list": [
      {
        "name": "service",
        "type": "custom",
        "options": [
          {"value": "checkout", "selected": true},
          {"value": "payment"},
          {"value": "cart"}
        ]
      },
      {
        "name": "slo_target",
        "type": "custom",
        "current": {"value": "0.999"}
      }
    ]
  },
  "panels": [
    {
      "title": "Availability SLO Compliance (28d)",
      "type": "stat",
      "gridPos": {"x": 0, "y": 0, "w": 6, "h": 4},
      "options": {
        "reduceOptions": {"calcs": ["lastNotNull"]},
        "orientation": "auto",
        "colorMode": "background"
      },
      "fieldConfig": {
        "defaults": {
          "unit": "percentunit",
          "decimals": 4,
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {"color": "red",    "value": 0},
              {"color": "yellow", "value": 0.9985},
              {"color": "green",  "value": 0.999}
            ]
          }
        }
      },
      "targets": [{
        "expr": "job:availability_sli:rate28d{job=\"$service\"}",
        "legendFormat": "Availability SLI"
      }]
    },
    {
      "title": "Error Budget Remaining (28d)",
      "type": "gauge",
      "gridPos": {"x": 12, "y": 0, "w": 6, "h": 4},
      "fieldConfig": {
        "defaults": {
          "min": 0,
          "max": 1,
          "unit": "percentunit",
          "thresholds": {
            "steps": [
              {"color": "red",    "value": 0},
              {"color": "yellow", "value": 0.1},
              {"color": "green",  "value": 0.5}
            ]
          }
        }
      },
      "targets": [{
        "expr": "job:error_budget_remaining:ratio28d{job=\"$service\"}",
        "legendFormat": "Budget Remaining"
      }]
    },
    {
      "title": "Availability SLI — 28-Day Trend",
      "type": "timeseries",
      "gridPos": {"x": 0, "y": 4, "w": 24, "h": 8},
      "fieldConfig": {
        "overrides": [
          {
            "matcher": {"id": "byName", "options": "SLO Target"},
            "properties": [
              {"id": "custom.lineStyle", "value": {"dash": [8, 8]}},
              {"id": "color", "value": {"fixedColor": "orange", "mode": "fixed"}},
              {"id": "custom.lineWidth", "value": 2}
            ]
          },
          {
            "matcher": {"id": "byName", "options": "SLA Target"},
            "properties": [
              {"id": "custom.lineStyle", "value": {"dash": [4, 4]}},
              {"id": "color", "value": {"fixedColor": "red", "mode": "fixed"}},
              {"id": "custom.lineWidth", "value": 1}
            ]
          }
        ]
      },
      "targets": [
        {
          "expr": "job:availability_sli:rate1h{job=\"$service\"}",
          "legendFormat": "Availability SLI (1h)"
        },
        {
          "expr": "vector($slo_target)",
          "legendFormat": "SLO Target"
        },
        {
          "expr": "vector(0.999)",
          "legendFormat": "SLA Target"
        }
      ]
    }
  ]
}
```

---

### 6.11 SLO Reporting — Internal and External {#611-slo-reporting}

#### Monthly SLO Report Structure

```markdown
# SLO Monthly Report — January 2024
Generated: 2024-02-01 | Distribution: Engineering, Product, Leadership

---

## Executive Summary

| Service         | SLO Target | Actual  | Status    | Budget Used |
|-----------------|------------|---------|-----------|-------------|
| Checkout API    | 99.90%     | 99.94%  | ✅ Met    | 66%         |
| Payment API     | 99.95%     | 99.97%  | ✅ Met    | 40%         |
| Search API      | 99.50%     | 99.48%  | 🔴 Missed | 106%        |
| Cart Service    | 99.90%     | 99.91%  | ✅ Met    | 89%         |
| User Auth       | 99.99%     | 99.991% | ✅ Met    | 90%         |

SLO Compliance Rate: 4/5 services (80%) — below 90% target

---

## SLO Breach: Search API

**Service:** Search API
**SLO:** 99.5% availability (28-day rolling)
**Actual:** 99.48% (0.02% below target)
**Budget consumed:** 106% (SLO breached by 0.02%)

**Root cause:** Two incidents this month:
- Jan 14: Elasticsearch node failure (19 min, 47% budget)
- Jan 23: Index backfill blocking queries (14 min, 34% budget)

**Actions taken:**
1. ✅ Added replica shard for search index (prevents single-node failures)
2. 🔄 In progress: Separate index backfill to dedicated cluster (ETA: Feb 15)
3. 🔄 Planned: Implement read/write separation (ETA: Feb 28)

**SLA status:** SLA target is 99% — no customer SLA breach.
**Customer impact:** No enterprise customers affected.

---

## Reliability Investments This Month

| Investment                     | Budget Impact | Status    |
|-------------------------------|---------------|-----------|
| DB read replica (checkout)     | -34% budget   | ✅ Done   |
| Circuit breaker (payment)      | Prevented 2 incidents | ✅ Done |
| Search replica shards          | Reduces P(breach) 60% | ✅ Done |
| Checkout canary pipeline       | Reduces CFR   | 🔄 In progress |

---

## Next Month Outlook

Services at risk (>50% budget consumed):
- Cart Service: 89% consumed with 2 weeks to go. Monitoring closely.
- User Auth: 90% consumed — no planned work that could cause incidents.

Planned high-risk changes:
- Feb 12: Search index restructure — potential 30% budget impact.
  Mitigation: staging test, off-peak deployment, rollback plan ready.
```

#### Automated SLO Report Generation

```python
#!/usr/bin/env python3
"""
slo_report_generator.py — Generate monthly SLO report
Queries Prometheus, formats report, posts to Confluence and Slack.
"""

import requests
import json
from datetime import datetime
from typing import List, Dict

PROMETHEUS_URL = "http://prometheus.internal:9090"
SERVICES = [
    {"name": "checkout",  "job": "checkout",  "slo": 0.999,  "sla": 0.999},
    {"name": "payment",   "job": "payment",   "slo": 0.9995, "sla": 0.999},
    {"name": "search",    "job": "search",    "slo": 0.995,  "sla": 0.99},
    {"name": "cart",      "job": "cart",      "slo": 0.999,  "sla": 0.999},
    {"name": "auth",      "job": "auth",      "slo": 0.9999, "sla": 0.9999},
]

def query_instant(query: str) -> float:
    """Execute PromQL instant query."""
    r = requests.get(
        f"{PROMETHEUS_URL}/api/v1/query",
        params={"query": query}
    )
    results = r.json()["data"]["result"]
    return float(results[0]["value"][1]) if results else 0.0

def generate_service_report(svc: dict) -> dict:
    job = svc["job"]
    slo = svc["slo"]
    budget_fraction = 1 - slo

    actual_sli    = query_instant(f'job:availability_sli:rate28d{{job="{job}"}}')
    budget_remain = query_instant(f'job:error_budget_remaining:ratio28d{{job="{job}"}}')
    burn_rate_1h  = query_instant(
        f'(1 - job:availability_sli:rate1h{{job="{job}"}}) / {budget_fraction}'
    )

    slo_met = actual_sli >= slo
    sla_met = actual_sli >= svc["sla"]
    status  = "✅ Met" if slo_met else "🔴 Missed"

    return {
        "service":          svc["name"],
        "slo_target":       f"{slo:.4%}",
        "actual_sli":       f"{actual_sli:.5%}",
        "budget_remaining": f"{budget_remain:.1%}",
        "budget_consumed":  f"{(1 - budget_remain):.1%}",
        "burn_rate_1h":     f"{burn_rate_1h:.1f}×",
        "status":           status,
        "slo_met":          slo_met,
        "sla_met":          sla_met,
        "action_required":  not slo_met or budget_remain < 0.1,
    }

def generate_full_report() -> str:
    now = datetime.now()
    reports = [generate_service_report(s) for s in SERVICES]
    compliant = sum(1 for r in reports if r["slo_met"])

    lines = [
        f"# SLO Monthly Report — {now.strftime('%B %Y')}",
        f"Generated: {now.strftime('%Y-%m-%d %H:%M UTC')}",
        "",
        "## Summary",
        "",
        f"SLO Compliance: **{compliant}/{len(reports)} services**",
        "",
        "| Service | SLO Target | Actual | Budget Consumed | Status |",
        "|---------|-----------|--------|-----------------|--------|",
    ]

    for r in reports:
        lines.append(
            f"| {r['service']} | {r['slo_target']} | {r['actual_sli']} "
            f"| {r['budget_consumed']} | {r['status']} |"
        )

    lines += ["", "## Services Requiring Attention", ""]
    attention = [r for r in reports if r["action_required"]]
    if attention:
        for r in attention:
            lines.append(f"- **{r['service']}**: "
                        f"{'SLO breached. ' if not r['slo_met'] else ''}"
                        f"Budget consumed: {r['budget_consumed']}")
    else:
        lines.append("All services within acceptable thresholds.")

    return "\n".join(lines)

if __name__ == "__main__":
    print(generate_full_report())
```

---

### 6.12 SLO Review Cadence and Iteration {#612-slo-review-cadence}

SLOs are not permanent. A correctly designed SLO review process tightens targets as reliability improves and relaxes them when targets prove unachievable without investment.

```
SLO Review Cadence
──────────────────────────────────────────────────────────────────
Weekly      → Budget state review in SRE standup
              Flag services entering Yellow/Red zones
              No SLO target changes

Monthly     → Full SLO compliance report (as above)
              Review incidents and their budget impact
              Track action item completion rate
              Surface candidates for SLO tightening/relaxation

Quarterly   → SLO target review and renegotiation
              Tighten if: service consistently at 2× above SLO
              Relax if: service consistently breaches despite investment
              Add SLIs if: incidents occurred with no SLI coverage
              Remove SLIs if: zero budget consumed (no signal value)
              Update SLA to reflect new SLO targets

Annually    → Strategic SLO review
              Benchmark against industry standards
              Align with product/business roadmap for next year
              Review SLA tier structure
──────────────────────────────────────────────────────────────────
```

**SLO tightening criteria:**
```python
def should_tighten_slo(
    actual_sli_values: list,  # 6 months of monthly SLI measurements
    current_slo: float,
    tighten_threshold: float = 0.5  # Tighten if consistently 50% above target
) -> dict:
    """
    Recommend SLO tightening when service consistently outperforms target.
    Tightening unused headroom improves signal sensitivity.
    """
    import statistics

    median_sli = statistics.median(actual_sli_values)
    gap_to_slo = median_sli - current_slo
    budget_fraction = 1 - current_slo
    gap_as_budget_multiple = gap_to_slo / budget_fraction

    months_well_above = sum(
        1 for v in actual_sli_values
        if v - current_slo > budget_fraction * tighten_threshold
    )

    should_tighten = months_well_above >= 4  # 4 of 6 months well above

    if should_tighten:
        # Propose new SLO at P10 of historical performance
        new_slo = sorted(actual_sli_values)[int(len(actual_sli_values) * 0.10)]
        new_slo = round(new_slo, 4)  # Round to 4 decimal places
    else:
        new_slo = current_slo

    return {
        "current_slo":          f"{current_slo:.4%}",
        "median_actual":        f"{median_sli:.4%}",
        "months_well_above":    f"{months_well_above}/6",
        "recommendation":       "TIGHTEN" if should_tighten else "MAINTAIN",
        "proposed_slo":         f"{new_slo:.4%}" if should_tighten else "No change",
        "rationale":            (
            f"Service has outperformed SLO by >{tighten_threshold:.0%} of budget "
            f"for {months_well_above} of the last 6 months. "
            f"Tightening to {new_slo:.4%} improves signal sensitivity."
            if should_tighten else
            "SLO target is appropriately calibrated."
        )
    }
```

---

## Key Principles & Best Practices {#key-principles}

1. **SLIs measure user experience, not system health.** CPU and memory are not SLIs. They are diagnostic signals. SLIs must answer the question: did the user get what they needed, when they needed it, at the expected quality?

2. **The SLO-SLA gap is a deliberate safety buffer, not sloppiness.** Setting the SLO tighter than the SLA gives the engineering team time to detect a developing SLO breach and fix it before it becomes an SLA breach and triggers legal and financial consequences.

3. **Start with fewer, better SLIs rather than many mediocre ones.** Five SLIs with precise good-event definitions, measured from the right vantage point, outperform twenty SLIs measured from the wrong place with ambiguous definitions.

4. **User journey mapping is the highest-leverage SLI design tool.** Start with the three most critical things users do in your product. Define the SLI for each step. Cover every step that, if broken, would cause users to abandon the product.

5. **Multi-window alerting on all four tiers is not optional.** P1 (fast burn/page) without P2/P3 (slow burn/ticket) means you catch catastrophes but miss the gradual erosion that depletes your budget across 20 days. All four tiers together provide complete budget protection.

6. **SLOs must be renegotiated when they stop providing signal.** A service with 18 months of 99.98% actual performance against a 99.9% SLO is burning unused headroom, sending no improvement signal, and giving false confidence. Tighten it.

7. **SLA language must be reviewed by legal, not just engineering.** SREs write the technical content; legal ensures the exclusions, measurement methodology, and remedies are legally sound and enforceable.

---

## Tools & Technologies {#tools}

| Tool | Category | SLI/SLO/SLA Use Case |
|---|---|---|
| **Prometheus + Alertmanager** | Metrics + Alerting | SLI measurement, recording rules, burn rate alerts |
| **Grafana** | Visualization | SLO dashboards, budget trend charts, compliance panels |
| **Sloth** | SLO-as-Code | YAML SLO definitions → auto-generated Prometheus rules |
| **Pyrra** | Kubernetes SLO Operator | Kubernetes-native SLO management with CRDs |
| **OpenSLO** | SLO Standard | Vendor-neutral SLO specification for multi-backend |
| **Nobl9** | SLO Platform | Commercial: multi-source SLO, budget tracking, reporting |
| **Datadog SLOs** | Integrated | Native SLO dashboards + burn rate alerts in Datadog |
| **Statuspage** | External Reporting | Customer-facing SLA compliance and incident history |
| **Blackbox Exporter** | Synthetic Probing | External availability checking for TCP/HTTP/ICMP |
| **k6 / Synthetic SDK** | Synthetic Monitoring | Scripted user journey monitoring from external locations |

---

## Hands-on Exercises / Labs {#labs}

### Lab 6.1 — SLI Design Workshop

**Goal:** Define a complete SLI set for a real service from user journeys.

**Scenario:** You are the SRE assigned to a video streaming platform. Core features: video search, video playback, user authentication, watchlist management, and recommendation feed.

**Tasks:**
1. Identify the 3 most critical user journeys (the flows that, if broken, cause immediate churn).
2. For each journey, map every step and identify the failure mode at each step.
3. Define at least 6 SLIs (mix of availability, latency, quality, and freshness). For each, specify:
   - What is the "good event"?
   - What is the "bad event"?
   - Where is it measured (client, CDN, API gateway, service)?
   - What PromQL or instrumentation implements it?
4. Apply the independence test: verify no two SLIs are measuring the same failure mode.
5. Apply the user-vantage-point test: for each SLI, how close is it to actual user experience?

---

### Lab 6.2 — SLO Target Setting

**Goal:** Set evidence-based SLO targets for a service with historical data.

**Given:**
```
Service: video-playback-api
90-day availability data (daily measurements):
[99.97, 99.98, 99.95, 99.99, 99.97, 99.96, 99.94, 99.98, 99.97, 99.99,
 99.96, 99.93, 99.97, 99.98, 99.95, 99.91, 99.97, 99.98, 99.96, 99.99,
 99.97, 99.94, 99.98, 99.96, 99.97, 99.93, 99.98, 99.95, 99.97, 99.96,
 (... 60 more days at similar distribution)]

Current SLA: 99.9% monthly
User research finding: users notice buffering/errors above 0.1% failure rate
Business requirement: protect enterprise SLA (99.9%)
Cost constraint: team cannot invest more than 2 sprints in reliability work
```

**Tasks:**
1. Calculate: P5, P10, P50 of the historical data.
2. Apply the four-input SLO framework: user research, historical performance, business requirements, cost.
3. Propose an initial SLO target with justification.
4. Calculate the SLO-SLA buffer and verify it is sufficient given the worst historical month.
5. Run `should_tighten_slo()` on the historical data. What does it recommend?
6. Write the SLO definition in OpenSLO YAML format.

---

### Lab 6.3 — Complete Alert Implementation

**Goal:** Implement the full four-tier multi-window burn rate alert set.

**Given service:** `search-api` with:
- Availability SLO: 99.5% (budget = 0.5%)
- Latency SLO: 90% of requests under 500ms (budget = 10%)
- Metrics: `http_requests_total{service="search", status_code=...}` and `http_request_duration_seconds_*{service="search"}`

**Tasks:**
1. Write all recording rules for 5m, 30m, 1h, 6h, 3d, 28d windows for both availability and latency SLIs.
2. Calculate the correct burn rate thresholds for each tier given the 0.5% and 10% budget fractions.
3. Write all 8 alert rules (4 tiers × 2 SLIs) with complete annotations including: runbook URL, current error rate, burn rate, and estimated days to exhaustion.
4. Test your alert logic: at an error rate of 2% on a 99.5% SLO, which alerts fire?
5. Write the Alertmanager routing configuration that sends P1 to PagerDuty and P2/P3 to Slack.

---

### Lab 6.4 — SLA Compliance Audit

**Goal:** Simulate an end-of-month SLA compliance audit with credit calculation.

**Given:**
```
Month: January 2024 (31 days = 44,640 minutes)
Customers and tiers:
  - Acme Corp:     Enterprise (SLA 99.99%, MRR $50,000)
  - Beta Inc:      Business   (SLA 99.9%,  MRR $5,000)
  - Gamma Ltd:     Starter    (SLA 99.5%,  MRR $500)

Incidents this month:
  Jan 12 2:15am   Duration: 8 minutes    All customers affected
  Jan 19 11:30am  Duration: 34 minutes   All customers affected
  Jan 26 3:00pm   Duration: 12 minutes   Acme Corp only (region-specific)
```

**Tasks:**
1. Calculate total downtime per customer for January.
2. Calculate actual availability percentage for each customer.
3. Apply the SLA tier credit model from Section 6.8 to determine credits owed.
4. Write the SLA compliance report entry for each customer.
5. Identify: which customers receive automatic credits vs must request them?
6. Write the customer-facing SLA compliance notification for Acme Corp.
7. What SLO adjustment would prevent these SLA breaches next month?

---

## Common Pitfalls & Anti-patterns {#pitfalls}

**Anti-pattern 1: Infrastructure metrics as SLIs**
"Our SLO is 80% CPU utilization below 70%." Users don't experience CPU utilization. A CPU-bound server serving responses in 50ms is perfectly fine. A server at 40% CPU serving 10-second responses is broken. *Fix:* Only define SLIs that capture user-observable behavior. Replace every infrastructure SLI with a latency, availability, quality, or freshness SLI.

**Anti-pattern 2: SLO set at current performance**
Setting SLO = current actual performance means the error budget is never consumed and no improvement signal is generated. The SLO becomes a false compliance dashboard. *Fix:* SLOs represent what users *require*, not what the system currently delivers. The gap between current and target is the engineering agenda.

**Anti-pattern 3: SLA without SLO buffer**
SLA and SLO targets are set identically (both 99.9%). When an incident occurs and the SLO is breached, the SLA is simultaneously breached — triggering customer credits, legal review, and executive escalation with no warning period. *Fix:* SLO must always be tighter than SLA. The gap (typically 0.05–0.1%) gives the team time to respond to an SLO breach before it reaches the customer.

**Anti-pattern 4: All SLIs aggregated, none decomposed by journey step**
A single "checkout availability" SLI masks which step in the checkout journey is failing. When the SLI drops, the team doesn't know if it's search, cart, payment, or confirmation. *Fix:* Define per-journey-step SLIs. The additional granularity compresses MTTR during incidents and surfaces which investments have the most impact.

**Anti-pattern 5: SLO defined but never reviewed**
An SLO is set at launch and never revisited. After 18 months, the service is running at 99.98% against a 99.9% SLO — the team has 8× more headroom than they need, all high-risk experiments are approved even when they shouldn't be, and the team has lost the improvement signal the SLO was supposed to provide. *Fix:* Quarterly SLO review is mandatory. Tighten when the service consistently outperforms the target; the headroom is wasted opportunity for signal.

**Anti-pattern 6: Single-window burn rate alerts**
A P1 alert fires on 1-minute burst of errors. The on-call engineer is paged. By the time they open their laptop, the error has resolved. False alarm — but it's 3am and the engineer is wide awake. After the third false alarm in a week, engineers start silencing the alert. *Fix:* Multi-window burn rate alerting with `for: 2m` stabilization period. The short window confirms the condition is ongoing; the long window confirms meaningful budget consumption. No legitimate P1 fires on a 90-second blip.

---

## Interview Questions {#interview-questions}

**Conceptual:**

1. *"Explain the difference between SLI, SLO, and SLA. Why should the SLO always be tighter than the SLA?"*
   — Look for: SLI = measurement, SLO = internal target, SLA = contractual commitment; SLO-SLA gap is the warning buffer; SLO breach gives time to fix before SLA breach; legal/financial consequences of SLA breach vs engineering response to SLO breach.

2. *"What makes a good SLI? Give two examples of bad SLIs and explain how you would fix them."*
   — Look for: good = ratio, user-observable, precise good-event definition, measured near user; bad examples: CPU utilization (not user-observable), total error count (not normalized), P99 latency as raw value (not ratio); fix: replace with availability fraction, error rate, fraction of requests under latency threshold.

3. *"What is multi-window burn rate alerting and why do we need both a short and a long window?"*
   — Look for: burn rate = error rate / budget fraction; short window (5m) confirms condition is active and real; long window (1h/6h) confirms meaningful budget consumption; single-window produces false positives from transient spikes; both must exceed threshold simultaneously.

**Scenario-based:**

4. *"You are setting up SLOs for a payment processing API for the first time. The service has been running for 2 years with no SLOs. Walk me through how you would define the SLIs, set the SLO targets, and handle the SLA commitments to enterprise customers."*
   — Look for: start with user journey mapping (submit payment → receive confirmation); define availability SLI (fraction of payment requests succeeding) + latency SLI (fraction completing in < 3s) + correctness SLI (amount charged matches request); query historical performance for 90-day baseline; set SLO at P5 historical performance; SLA = SLO - 0.05% buffer; implement multi-window burn rate alerts; present to product and legal for sign-off.

5. *"Your search service SLO is 99.5% and actual performance this month is 99.42%. The SLA to customers is 99%. No customer SLA is breached. Your manager says 'we're fine.' How do you respond?"*
   — Look for: SLO is the internal warning system — breaching it is the signal to invest in reliability before it reaches the SLA; if we accept chronic SLO breaches, the SLA becomes the de facto target and we lose the buffer; the next incident may push below 99% and trigger SLA breach; calculate: two more incidents of average size would breach the SLA; present the risk in business terms; propose specific reliability investment to prevent SLA breach.

---

## Further Reading & Resources {#further-reading}

**Books:**
- *Site Reliability Engineering* — Chapter 4: Service Level Objectives (Google, O'Reilly) — The canonical SLI/SLO/SLA framework
- *The Site Reliability Workbook* — Chapters 2–4: Implementing SLOs, SLO Engineering Case Studies — Practical implementation with worked examples
- *Implementing Service Level Objectives* — Alex Hidalgo (O'Reilly) — The most comprehensive book dedicated entirely to SLO practice

**Online:**
- [Google SRE Workbook: Implementing SLOs](https://sre.google/workbook/implementing-slos/) — Complete implementation guide with worked examples
- [OpenSLO Specification](https://openslo.com) — Vendor-neutral SLO YAML standard
- [Sloth Documentation](https://sloth.dev) — SLO-as-code tool with full Prometheus integration
- [SLOconf Talks Archive](https://www.sloconf.com/talks) — Annual SLO conference recordings (free)
- [Alexis Richardson: The Art of SLOs](https://www.youtube.com/watch?v=E3ReKuJ8ewA) — Practical SLO design talk

**Papers:**
- [Alerting on SLOs Like Pros](https://sre.google/workbook/alerting-on-slos/) — Google's multi-window burn rate methodology in full mathematical detail
- [CRE Life Lessons: The Art of SLOs](https://cloud.google.com/blog/products/devops-sre/sre-fundamentals-slis-slas-and-slos) — Google Cloud's SLO practitioner guide

---

## Key Takeaways {#key-takeaways}

> **Chapter 6 Summary**
>
> - **SLI, SLO, and SLA are three distinct layers** with different audiences and violation responses. SLI = measurement. SLO = internal engineering target. SLA = contractual customer commitment. The SLO is always tighter than the SLA, creating a buffer that absorbs incidents before they reach the customer.
>
> - **Meaningful SLIs measure user experience, not system health.** CPU, memory, and disk are diagnostic signals. A valid SLI is a ratio (good events / total events) that captures whether users received the value they expected, measured as close to the user as possible.
>
> - **User journey mapping is the rigorous path to SLI completeness.** For every critical user journey, map every step, identify every failure mode, and define an SLI for each. Verify coverage: would every past incident have been caught by at least one SLI?
>
> - **SLO target setting requires four inputs:** user sensitivity research, historical performance baseline, business/SLA requirements, and cost-of-reliability analysis. SLOs should represent what users need, not what the system currently delivers.
>
> - **Multi-window multi-burn-rate alerting covers four tiers:** P1 (14.4× / 1h+5m / page), P2 (6× / 6h+30m / ticket), P3 (3× / 3d+6h / notify), P4 (budget low / report). Each tier uses both a short and long window simultaneously to eliminate false positives from transient spikes.
>
> - **SLO dashboards serve three audiences:** engineers (operational health), product managers (deployment capacity), and leadership (business impact). Each needs different information presented at different levels of abstraction.
>
> - **SLOs must be reviewed quarterly.** Tighten when the service consistently outperforms the target — unused headroom produces no improvement signal. Relax when chronic breach despite investment signals the target is unrealistic.
>
> - **SLA language is a legal document.** SREs write the technical content; legal ensures exclusions, measurement methodology, and remedies are sound. Never publish an SLA that hasn't been reviewed by legal.

---

*Previous: [Chapter 5 — Error Budgets](#chapter-5)*
*Next: Chapter 7 — Capacity Planning*

---

*Document version: 1.0 | Study Guide: High Performance SRE | Chapter 6 of 12*
