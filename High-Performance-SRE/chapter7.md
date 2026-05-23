# Chapter 7 — Capacity Planning
---
## Table of Contents

- [Learning Objectives](#learning-objectives)
- [Core Concepts](#core-concepts)
  - [7.1 What Is Capacity Planning?](#71-what-is-capacity-planning)
  - [7.2 Demand Forecasting](#72-demand-forecasting)
  - [7.3 Resource Utilization Models](#73-resource-utilization-models)
  - [7.4 Load Testing Strategies](#74-load-testing-strategies)
  - [7.5 Autoscaling Patterns](#75-autoscaling-patterns)
  - [7.6 Cost vs Reliability Tradeoffs](#76-cost-vs-reliability-tradeoffs)
  - [7.7 Cloud-Native Capacity Management](#77-cloud-native-capacity-management)
  - [7.8 Database Capacity Planning](#78-database-capacity-planning)
  - [7.9 Capacity Incident Response](#79-capacity-incident-response)
  - [7.10 Capacity Planning as a Continuous Practice](#710-continuous-practice)
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

- Build demand forecasting models using time-series decomposition, regression, and seasonal adjustment — and know when each method is appropriate.
- Design and execute a load testing strategy that validates capacity headroom against SLOs, distinguishing between load, stress, soak, and spike tests.
- Implement and compare the four primary autoscaling patterns — reactive HPA, predictive, scheduled, and KEDA event-driven — with PromQL-based custom metrics.
- Model the cost vs reliability tradeoff quantitatively, calculating the breakeven point between over-provisioning (cost) and under-provisioning (incident revenue loss).
- Apply cloud-native capacity management techniques — spot instance strategies, multi-region active/active provisioning, and FinOps discipline — to reduce cost without sacrificing reliability.

---

## Core Concepts {#core-concepts}

### 7.1 What Is Capacity Planning? {#71-what-is-capacity-planning}

Capacity planning is the practice of ensuring a system has sufficient resources — compute, memory, storage, network, and external service quotas — to meet demand at the reliability level the SLO requires, at the lowest sustainable cost.

The two failure modes of capacity planning are opposites, and both are expensive:

```
Under-provisioned                    Over-provisioned
─────────────────────────────────    ─────────────────────────────────
Resources insufficient for           Resources far exceed demand.
actual demand.                       Cost budget wasted on idle
                                     infrastructure.

Result:                              Result:
  Latency spikes under load            $500k/year in unused compute
  Saturation causes cascades           Engineers ignore capacity alerts
  SLO breaches                         (always under threshold)
  Incident → revenue loss              Competitive disadvantage
  On-call pages at 3am                 Budget redirected from product

Cost: Incident + engineering time    Cost: Wasted infrastructure spend
─────────────────────────────────────────────────────────────────────
```

The goal is the **reliability-cost efficient frontier** — the minimum resource footprint that sustains SLO compliance across all expected demand scenarios, including peak events, seasonal spikes, and failure modes (e.g., one availability zone goes down, requiring the remaining zones to absorb 50% more load).

```
              SLO Compliance
              ▲
   100% ─────┼────────────────────────────── SLO target ─ ─ ─
             │         ★ Efficient Frontier
             │      ★
             │   ★
             │ ★
             └─────────────────────────────────────────────►
                              Resource Cost

  Below frontier: under-provisioned (SLO at risk)
  Above frontier: over-provisioned (cost wasted)
  On frontier: optimal — meets SLO at minimum cost
```

**Capacity planning is not a one-time exercise.** It is a continuous operational practice with weekly, monthly, and quarterly cadences tied to demand forecasting, load testing, and cost review cycles.

---

### 7.2 Demand Forecasting {#72-demand-forecasting}

Demand forecasting answers: *how much traffic will this service receive in the future?* The answer drives provisioning decisions: how many instances, how much database capacity, how wide the autoscaling bounds.

#### Traffic Pattern Decomposition

Real-world traffic is composed of four components:

```
Traffic = Trend + Seasonality + Cyclic + Residual (noise)

Trend:       Long-term growth or decline in baseline traffic
             "10% MoM user growth → 10% MoM traffic growth"

Seasonality: Repeating patterns at fixed intervals
             Daily: peak at 9am, trough at 4am
             Weekly: lower weekend traffic for B2B SaaS
             Annual: Black Friday peak, January drop

Cyclic:      Irregular multi-year patterns (economic cycles,
             pandemic effects, market expansion phases)

Residual:    Unexplained variation — noise, anomalies, one-off events
```

#### Method 1: Linear Trend Extrapolation

Suitable for steady-growth services with predictable demand expansion.

```python
import numpy as np
import pandas as pd
from datetime import datetime, timedelta
from sklearn.linear_model import LinearRegression
from sklearn.preprocessing import PolynomialFeatures
import warnings
warnings.filterwarnings('ignore')

def forecast_linear_trend(
    daily_rps: list,          # Historical daily peak RPS values
    forecast_days: int = 90,  # How far ahead to forecast
    confidence: float = 0.95  # Confidence interval for upper bound
) -> dict:
    """
    Linear trend extrapolation for capacity forecasting.
    Returns point forecast + upper confidence bound for provisioning.
    """
    n = len(daily_rps)
    X = np.arange(n).reshape(-1, 1)
    y = np.array(daily_rps)

    model = LinearRegression()
    model.fit(X, y)

    # Residuals for confidence interval
    residuals = y - model.predict(X)
    std_residual = np.std(residuals)

    # Forecast future days
    future_X = np.arange(n, n + forecast_days).reshape(-1, 1)
    point_forecast = model.predict(future_X)

    # Upper confidence bound for provisioning
    # Use upper bound — better to over-provision slightly than under-provision
    from scipy import stats
    t_val = stats.t.ppf(confidence, df=n-2)
    upper_bound = point_forecast + t_val * std_residual

    forecast_dates = [
        datetime.now() + timedelta(days=i)
        for i in range(1, forecast_days + 1)
    ]

    return {
        "model":           "linear_trend",
        "daily_growth_rps": round(float(model.coef_[0]), 2),
        "r_squared":        round(float(model.score(X, y)), 4),
        "current_rps":      round(float(y[-1]), 0),
        "forecast_30d":     round(float(point_forecast[29]), 0),
        "forecast_60d":     round(float(point_forecast[59]), 0),
        "forecast_90d":     round(float(point_forecast[89]), 0),
        "upper_bound_30d":  round(float(upper_bound[29]), 0),
        "upper_bound_90d":  round(float(upper_bound[89]), 0),
        "provisioning_target_90d": round(float(upper_bound[89]) * 1.2, 0),
        # 1.2× safety margin on top of upper bound
        "provisioning_note": (
            f"Provision for {round(float(upper_bound[89]) * 1.2, 0)} RPS "
            f"by day {forecast_days}. "
            f"Current capacity should be {round(float(upper_bound[89]) * 1.2 / y[-1], 2)}× current."
        )
    }

# Example: checkout API growing at ~50 RPS/day
historical_peak_rps = [
    1000 + i * 50 + np.random.normal(0, 30)
    for i in range(90)
]
result = forecast_linear_trend(historical_peak_rps, forecast_days=90)
print(f"Current: {result['current_rps']} RPS")
print(f"Forecast 90d: {result['forecast_90d']} RPS (upper: {result['upper_bound_90d']})")
print(f"Provision for: {result['provisioning_target_90d']} RPS")
print(f"Note: {result['provisioning_note']}")
```

#### Method 2: Seasonal Decomposition with STL

For services with strong seasonal patterns (e-commerce, B2C, media), linear extrapolation misses the peaks that drive provisioning decisions.

```python
from statsmodels.tsa.seasonal import STL
import pandas as pd
import numpy as np

def forecast_with_seasonality(
    hourly_rps: pd.Series,    # Hourly RPS as pandas Series with DatetimeIndex
    forecast_hours: int = 168 # 7 days ahead
) -> pd.DataFrame:
    """
    STL decomposition + trend extrapolation for seasonal traffic forecasting.
    Captures daily and weekly seasonality patterns.
    """
    # Decompose into trend + seasonal + residual
    stl = STL(
        hourly_rps,
        period=24,        # 24-hour daily seasonality
        seasonal=13,      # Smoothing window for seasonal component
        trend=25,         # Smoothing window for trend component
        robust=True       # Robust to outliers (incidents, anomalies)
    )
    result = stl.fit()

    trend     = result.trend
    seasonal  = result.seasonal
    residual  = result.resid

    # Extrapolate trend linearly
    n = len(trend)
    X = np.arange(n)
    trend_coeffs = np.polyfit(X[-168:], trend[-168:], deg=1)  # Last 7 days
    future_X = np.arange(n, n + forecast_hours)
    future_trend = np.polyval(trend_coeffs, future_X)

    # Project seasonal pattern from last cycle
    seasonal_cycle = seasonal[-168:]  # Last 7 days (weekly cycle)
    future_seasonal = np.tile(
        seasonal_cycle,
        int(np.ceil(forecast_hours / len(seasonal_cycle)))
    )[:forecast_hours]

    # Combined forecast
    forecast = future_trend + future_seasonal

    # Upper bound for provisioning: add 1.5× residual std
    upper_bound = forecast + 1.5 * np.std(residual)

    future_index = pd.date_range(
        start=hourly_rps.index[-1] + pd.Timedelta(hours=1),
        periods=forecast_hours,
        freq='H'
    )

    return pd.DataFrame({
        'forecast_rps':         forecast,
        'upper_bound_rps':      upper_bound,
        'provisioning_target':  upper_bound * 1.2,  # 20% safety margin
    }, index=future_index)

# Usage: query Prometheus for hourly RPS, feed into forecast
# prometheus_query: avg_over_time(
#   sum(rate(http_requests_total{service="checkout"}[1m]))[90d:1h]
# )
```

#### Method 3: Event-Driven Capacity Planning

For known spikes (product launches, marketing campaigns, Black Friday), historical extrapolation is insufficient. Use event-based multipliers:

```python
from dataclasses import dataclass
from typing import Optional

@dataclass
class TrafficEvent:
    name: str
    event_date: str
    baseline_rps: float
    expected_multiplier: float    # e.g., 4.0 = 4× normal traffic
    peak_duration_hours: int      # How long the peak lasts
    ramp_up_hours: int            # Time from normal to peak
    confidence: str               # high | medium | low

    @property
    def peak_rps(self) -> float:
        return self.baseline_rps * self.expected_multiplier

    @property
    def required_capacity_rps(self) -> float:
        # 30% safety margin on top of expected peak
        return self.peak_rps * 1.3

    def capacity_plan_summary(self) -> str:
        return (
            f"\n{'='*55}\n"
            f"  Capacity Plan: {self.name}\n"
            f"{'='*55}\n"
            f"  Event Date:         {self.event_date}\n"
            f"  Baseline RPS:       {self.baseline_rps:,.0f}\n"
            f"  Expected Peak:      {self.peak_rps:,.0f} RPS "
            f"({self.expected_multiplier}×)\n"
            f"  Required Capacity:  {self.required_capacity_rps:,.0f} RPS "
            f"(+30% margin)\n"
            f"  Peak Duration:      {self.peak_duration_hours}h\n"
            f"  Ramp-up:            {self.ramp_up_hours}h before event\n"
            f"  Confidence:         {self.confidence}\n"
            f"{'='*55}\n"
            f"  Action Items:\n"
            f"  1. Scale to {self.required_capacity_rps:,.0f} RPS by "
            f"{self.ramp_up_hours}h before event\n"
            f"  2. Load test to {self.peak_rps:,.0f} RPS in staging\n"
            f"  3. Pre-warm caches {self.ramp_up_hours * 2}h before event\n"
            f"  4. Disable autoscale floor cooldown during ramp-up\n"
            f"  5. Schedule war room for event duration\n"
        )

# Black Friday planning example
black_friday = TrafficEvent(
    name="Black Friday 2024",
    event_date="2024-11-29",
    baseline_rps=5_000,
    expected_multiplier=8.0,     # Based on last 3 years: 6.2×, 7.1×, 7.8×
    peak_duration_hours=18,
    ramp_up_hours=6,
    confidence="high"
)
print(black_friday.capacity_plan_summary())
```

#### Demand Forecasting with Prometheus Data

```promql
# Extract historical RPS from Prometheus for forecasting
# 90-day hourly resolution — feed into Python forecasting models

# Peak daily RPS (for trend analysis)
max_over_time(
  sum(rate(http_requests_total{service="checkout"}[5m]))[90d:1d]
)

# Hourly average RPS (for seasonal decomposition)
avg_over_time(
  sum(rate(http_requests_total{service="checkout"}[5m]))[90d:1h]
)

# Week-over-week growth rate
(
  sum(rate(http_requests_total{service="checkout"}[7d]))
  /
  sum(rate(http_requests_total{service="checkout"}[7d] offset 7d))
) - 1
```

---

### 7.3 Resource Utilization Models {#73-resource-utilization-models)

Understanding how resource utilization maps to performance degradation is the foundation of capacity planning. The relationship is non-linear — performance degrades gracefully at moderate utilization and catastrophically near saturation.

#### The Utilization-Latency Curve

Based on queueing theory (specifically the M/M/1 queue model), response time grows as a function of utilization:

```
Response Time = Service Time / (1 - Utilization)

At 50% utilization: Response time = 1× service time (normal)
At 80% utilization: Response time = 5× service time (degraded)
At 90% utilization: Response time = 10× service time (severely degraded)
At 95% utilization: Response time = 20× service time (near unusable)
At 99% utilization: Response time = 100× service time (effectively broken)
```

```python
import numpy as np
import matplotlib
matplotlib.use('Agg')  # Non-interactive backend

def utilization_latency_curve(
    service_time_ms: float = 10.0,
    utilizations: list = None
) -> list:
    """
    M/M/1 queue model: predicts response time at given utilization.
    This explains why we target <70% CPU — beyond that, latency
    grows non-linearly and becomes unpredictable.
    """
    if utilizations is None:
        utilizations = [i/100 for i in range(10, 100, 5)]

    results = []
    for u in utilizations:
        if u >= 1.0:
            response_time = float('inf')
        else:
            # M/M/1 mean response time
            response_time = service_time_ms / (1 - u)

        slo_impact = "safe" if response_time < 50 \
                    else "degraded" if response_time < 200 \
                    else "critical"

        results.append({
            "utilization_pct": round(u * 100, 0),
            "response_time_ms": round(response_time, 1),
            "slo_impact": slo_impact,
            "latency_multiplier": round(response_time / service_time_ms, 1)
        })

    return results

# Print the curve — this is why 70% CPU is the warning threshold
curve = utilization_latency_curve(service_time_ms=10)
print(f"{'Utilization':>12} {'Response Time':>15} {'Multiplier':>12} {'Impact':>10}")
print("-" * 55)
for point in curve:
    print(f"{point['utilization_pct']:>11}% "
          f"{point['response_time_ms']:>14}ms "
          f"{point['latency_multiplier']:>11}× "
          f"{point['slo_impact']:>10}")
```

**Output:**
```
 Utilization    Response Time   Multiplier     Impact
-------------------------------------------------------
         10%           11.1ms          1.1×       safe
         30%           14.3ms          1.4×       safe
         50%           20.0ms          2.0×       safe
         70%           33.3ms          3.3×       safe
         80%           50.0ms          5.0×       safe
         85%           66.7ms          6.7×   degraded
         90%          100.0ms         10.0×   degraded
         95%          200.0ms         20.0×   critical
         99%        1,000.0ms        100.0×   critical
```

This curve is why SREs target **70% as the CPU warning threshold** — at 70%, latency is 3× service time, which is typically within SLO. At 85%, latency is near the threshold. At 90%+, the system is effectively unusable under sustained load.

#### Universal Scalability Law (USL)

For multi-instance systems, the USL predicts how throughput scales with added instances — accounting for contention (serialization) and coherence (coordination overhead):

```python
def universal_scalability_law(
    n_instances: int,
    sigma: float,    # Contention coefficient (0-1): serialized resource contention
    kappa: float,    # Coherence coefficient (0-1): coordination overhead
    lambda_1: float = 1.0  # Throughput of single instance
) -> float:
    """
    Predict relative throughput for N instances using USL.

    sigma: Fraction of work that must be serialized (e.g., lock contention)
           sigma=0 → linear scaling
           sigma=0.1 → 10% of work serialized → scaling caps ~10 instances

    kappa: Fraction of work requiring global coordination
           kappa=0.01 → 1% coordination overhead → scaling caps ~32 instances
    """
    throughput = (n_instances * lambda_1) / (
        1 + sigma * (n_instances - 1) + kappa * n_instances * (n_instances - 1)
    )
    return throughput

# Example: web service with 5% serialization, 0.1% coherence
print(f"{'Instances':>10} {'Throughput':>12} {'Efficiency':>12}")
print("-" * 38)
for n in [1, 2, 4, 8, 16, 32, 64]:
    throughput = universal_scalability_law(n, sigma=0.05, kappa=0.001)
    efficiency = throughput / n  # Throughput per instance
    print(f"{n:>10} {throughput:>12.2f} {efficiency:>11.1%}")
```

#### Resource Capacity Thresholds

```
Resource Utilization Thresholds — Production Guidelines
─────────────────────────────────────────────────────────────────────
Resource    Scale-Up   Warning   Critical   Why These Numbers
─────────────────────────────────────────────────────────────────────
CPU         60-70%     80%       90%        Queueing theory: >70%
                                            latency becomes non-linear

Memory      70%        80%       90%        OOM kill risk >90%;
                                            GC pressure at 80%

Disk I/O    60%        75%       85%        I/O wait causes
                                            cascading slowdowns

Disk Space  70%        80%       90%        Leave room for log
                                            spikes, temp files

Network     60%        75%       85%        Packet drops begin
                                            above 80% on most NICs

DB Conns    60%        75%       85%        Connection storms at
(pool)                                      >85% pool utilization

Queue depth 70% cap    80% cap   Full       Consumer can't keep up;
                                            backpressure needed
─────────────────────────────────────────────────────────────────────
```

---

### 7.4 Load Testing Strategies {#74-load-testing-strategies}

Load testing validates that the system can handle expected and unexpected demand levels at SLO. It is the empirical complement to forecasting — forecasting tells you what to expect; load testing tells you how the system actually behaves.

#### Four Load Test Types

```
Test Type       Purpose                  Load Profile          Duration
─────────────────────────────────────────────────────────────────────────
Load Test       Verify SLO at expected   Ramp to target,       30-60 min
                peak traffic             hold, ramp down

Stress Test     Find the breaking point  Ramp beyond           60-120 min
                and failure mode         target until
                                         degradation

Soak Test       Detect memory leaks,     Hold at 60-80%        24-72 hours
                resource exhaustion      of peak capacity
                over time

Spike Test      Validate autoscaling     Sudden 10×            15-30 min
                and burst capacity       traffic injection
─────────────────────────────────────────────────────────────────────────
```

#### Load Test Implementation with k6

```javascript
// k6 load test — checkout service capacity validation
// Tests SLO compliance at 150% of expected peak (safety margin)
// Run: k6 run --out prometheus=http://prometheus:9090 checkout_load_test.js

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';

// Custom metrics for SLO validation
const sloBreaches   = new Counter('slo_breaches_total');
const errorRate     = new Rate('slo_error_rate');
const checkoutTime  = new Trend('checkout_duration_ms', true);

// Load test configuration
export const options = {
    scenarios: {
        // Phase 1: Ramp up to expected peak (5,000 RPS) over 10 minutes
        ramp_to_peak: {
            executor: 'ramping-arrival-rate',
            startRate: 100,
            timeUnit: '1s',
            preAllocatedVUs: 500,
            maxVUs: 2000,
            stages: [
                { duration: '10m', target: 5000 },  // Ramp to peak
                { duration: '20m', target: 5000 },  // Hold at peak
                { duration: '5m',  target: 0    },  // Ramp down
            ],
        },
    },
    thresholds: {
        // SLO pass/fail gates — test fails if these are breached
        'http_req_duration{scenario:ramp_to_peak}': [
            'p(95)<300',    // 95% of requests under 300ms
            'p(99)<1000',   // 99% under 1 second
        ],
        'http_req_failed{scenario:ramp_to_peak}': [
            'rate<0.001',   // Error rate under 0.1% (matches SLO budget)
        ],
        'slo_error_rate': ['rate<0.001'],
        'checkout_duration_ms': ['p(99)<3000'],
    },
};

const BASE_URL = __ENV.BASE_URL || 'https://staging.example.com';

// Test data — pre-generated test users and products
const TEST_USERS = JSON.parse(open('./fixtures/test_users.json'));
const TEST_PRODUCTS = JSON.parse(open('./fixtures/test_products.json'));

export default function () {
    const user    = TEST_USERS[Math.floor(Math.random() * TEST_USERS.length)];
    const product = TEST_PRODUCTS[Math.floor(Math.random() * TEST_PRODUCTS.length)];

    // Simulate full checkout journey
    const startTime = Date.now();

    // Step 1: Add to cart
    const cartRes = http.post(
        `${BASE_URL}/api/cart`,
        JSON.stringify({ product_id: product.id, quantity: 1 }),
        {
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${user.token}`,
            },
            tags: { step: 'add_to_cart' },
        }
    );

    const cartOk = check(cartRes, {
        'cart: status 201':       (r) => r.status === 201,
        'cart: has cart_id':      (r) => r.json('cart_id') !== undefined,
        'cart: under 1s':         (r) => r.timings.duration < 1000,
    });

    if (!cartOk) {
        errorRate.add(1);
        sloBreaches.add(1);
        return;
    }

    const cartId = cartRes.json('cart_id');

    // Step 2: Checkout (no real payment)
    const checkoutRes = http.post(
        `${BASE_URL}/api/checkout`,
        JSON.stringify({
            cart_id:       cartId,
            payment_token: 'tok_load_test_visa',  // Test token
        }),
        {
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${user.token}`,
            },
            tags:    { step: 'checkout' },
            timeout: '5s',
        }
    );

    const checkoutOk = check(checkoutRes, {
        'checkout: status 200':        (r) => r.status === 200,
        'checkout: has order_id':      (r) => r.json('order_id') !== undefined,
        'checkout: status confirmed':  (r) => r.json('status') === 'confirmed',
        'checkout: under 3s':          (r) => r.timings.duration < 3000,
    });

    const totalDuration = Date.now() - startTime;
    checkoutTime.add(totalDuration);
    errorRate.add(!checkoutOk ? 1 : 0);

    if (!checkoutOk) {
        sloBreaches.add(1);
    }

    // Think time — simulate real user pacing
    sleep(Math.random() * 2 + 0.5);
}

// Teardown: post results to Slack
export function handleSummary(data) {
    const p99 = data.metrics['http_req_duration'].values['p(99)'];
    const errRate = data.metrics['http_req_failed'].values.rate;
    const passed = p99 < 1000 && errRate < 0.001;

    return {
        'stdout': JSON.stringify({
            result:          passed ? 'PASS' : 'FAIL',
            p99_latency_ms:  Math.round(p99),
            error_rate_pct:  (errRate * 100).toFixed(3),
            slo_compliant:   passed,
        }, null, 2),
        'load_test_results.json': JSON.stringify(data),
    };
}
```

#### Stress Test — Finding the Breaking Point

```javascript
// stress_test.js — find service capacity ceiling
// Gradually increase load until SLO degrades, identifying max capacity

export const options = {
    scenarios: {
        stress: {
            executor: 'ramping-arrival-rate',
            startRate: 1000,
            timeUnit: '1s',
            preAllocatedVUs: 5000,
            maxVUs: 20000,
            stages: [
                { duration: '5m',  target: 2000  },   // Normal load
                { duration: '5m',  target: 5000  },   // Expected peak
                { duration: '5m',  target: 10000 },   // 2× peak
                { duration: '5m',  target: 20000 },   // 4× peak
                { duration: '5m',  target: 30000 },   // 6× peak (break here?)
                { duration: '10m', target: 0     },   // Recovery check
            ],
        },
    },
    // No pass/fail thresholds — we WANT to see where it breaks
    thresholds: {},
};
```

**Interpreting stress test results:**

```python
def analyze_stress_test_results(results: dict) -> dict:
    """
    Find capacity ceiling from stress test data.
    Identifies the point where error rate > 1% or P99 > SLO threshold.
    """
    SLO_LATENCY_THRESHOLD_MS = 300   # P99 SLO
    SLO_ERROR_RATE_THRESHOLD  = 0.01 # 1% error rate (10× budget)

    capacity_ceiling_rps = None
    degradation_point_rps = None

    for datapoint in sorted(results['data'], key=lambda x: x['rps']):
        rps      = datapoint['rps']
        p99      = datapoint['p99_latency_ms']
        err_rate = datapoint['error_rate']

        # First point where latency degrades above SLO
        if p99 > SLO_LATENCY_THRESHOLD_MS and not degradation_point_rps:
            degradation_point_rps = rps

        # First point where errors spike
        if err_rate > SLO_ERROR_RATE_THRESHOLD and not capacity_ceiling_rps:
            capacity_ceiling_rps = rps

    safe_capacity = degradation_point_rps * 0.7 if degradation_point_rps else None

    return {
        "degradation_starts_at_rps": degradation_point_rps,
        "error_ceiling_rps":         capacity_ceiling_rps,
        "safe_operating_capacity":   safe_capacity,
        "headroom_factor":           (
            round(safe_capacity / results['current_peak_rps'], 2)
            if safe_capacity else None
        ),
        "recommendation": (
            f"Safe operating capacity: {safe_capacity:,} RPS. "
            f"Current peak: {results['current_peak_rps']:,} RPS. "
            f"Headroom: {safe_capacity / results['current_peak_rps']:.1f}×. "
            + ("⚠️ Insufficient headroom — scale up before next peak."
               if safe_capacity < results['current_peak_rps'] * 1.5
               else "✅ Sufficient headroom for projected growth.")
        )
    }
```

#### Soak Test — Long-Duration Reliability

```bash
#!/bin/bash
# soak_test.sh — 48-hour soak test with resource monitoring
# Detects: memory leaks, connection pool exhaustion, disk fill, GC pressure

SERVICE="checkout"
NAMESPACE="staging"
DURATION_HOURS=48
TARGET_RPS=3000   # 60% of expected peak — sustainable for 48h

echo "Starting ${DURATION_HOURS}h soak test at ${TARGET_RPS} RPS"
echo "Monitoring: memory, CPU, DB connections, GC pressure"

# Start k6 in background
k6 run \
  --vus 500 \
  --duration "${DURATION_HOURS}h" \
  --constant-arrival-rate \
  --rate "$TARGET_RPS" \
  --out "prometheus=http://prometheus-staging:9090" \
  soak_test.js &
K6_PID=$!

# Monitor for resource exhaustion every 30 minutes
while kill -0 $K6_PID 2>/dev/null; do
    TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

    # Memory trend — looking for steady increase (leak indicator)
    MEMORY_MB=$(kubectl -n $NAMESPACE top pods -l app=$SERVICE \
        --no-headers | awk '{sum += $3} END {print sum}' | sed 's/Mi//')

    # DB connection pool utilization
    DB_CONN_PCT=$(curl -s "http://prometheus-staging:9090/api/v1/query" \
        --data-urlencode "query=pg_stat_activity_count{state='active'} / pg_settings_max_connections * 100" \
        | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['data']['result'][0]['value'][1])" 2>/dev/null)

    # Error rate
    ERROR_RATE=$(curl -s "http://prometheus-staging:9090/api/v1/query" \
        --data-urlencode "query=sum(rate(http_requests_total{service='$SERVICE',status_code=~'5..'}[5m])) / sum(rate(http_requests_total{service='$SERVICE'}[5m])) * 100" \
        | python3 -c "import sys,json; d=json.load(sys.stdin); r=d['data']['result']; print(r[0]['value'][1] if r else '0')" 2>/dev/null)

    echo "[$TIMESTAMP] Memory: ${MEMORY_MB}Mi | DB Conn: ${DB_CONN_PCT}% | Errors: ${ERROR_RATE}%"

    # Alert if memory growing >10% per hour (leak indicator)
    # (simplified — production version tracks trend over time)

    sleep 1800  # Check every 30 minutes
done

echo "Soak test complete. Review results in Grafana soak-test dashboard."
```

---

### 7.5 Autoscaling Patterns {#75-autoscaling-patterns}

Autoscaling is the primary mechanism for matching resource provisioning to actual demand in real time. SREs design autoscaling policies — they don't just accept defaults.

#### Pattern 1: Reactive HPA (Horizontal Pod Autoscaler)

The default Kubernetes autoscaling mechanism. Scales based on CPU/memory utilization or custom metrics.

```yaml
# HPA with custom SLI-based scaling — scales on request queue depth
# More sophisticated than CPU-based: scales on actual user demand
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: checkout-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: checkout
  minReplicas: 10     # Never go below — cold start risk
  maxReplicas: 200    # Cap to prevent runaway scaling costs
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60    # React fast to traffic spikes
      policies:
        - type:          Pods
          value:         20             # Add up to 20 pods at once
          periodSeconds: 60
        - type:          Percent
          value:         100            # Or double pod count
          periodSeconds: 60
      selectPolicy: Max                 # Use whichever adds more pods
    scaleDown:
      stabilizationWindowSeconds: 300   # Be conservative on scale-down
      policies:
        - type:          Percent
          value:         10             # Remove max 10% of pods per 5 min
          periodSeconds: 300            # Prevents thrashing
  metrics:
    # Scale on CPU — standard
    - type: Resource
      resource:
        name: cpu
        target:
          type:               Utilization
          averageUtilization: 60   # Target 60% CPU (not 80% — leave headroom)

    # Scale on custom metric: RPS per pod (primary driver)
    - type: Pods
      pods:
        metric:
          name: http_requests_per_second
        target:
          type:         AverageValue
          averageValue: 500    # Target 500 RPS per pod

    # Scale on SLO pressure: P99 latency
    - type: Object
      object:
        metric:
          name: checkout_p99_latency_ms
        target:
          type:  Value
          value: 200   # Scale up if P99 approaches 200ms (SLO is 300ms)
        describedObject:
          apiVersion: apps/v1
          kind: Deployment
          name: checkout
```

**Custom metrics adapter for HPA (Prometheus → Kubernetes metrics API):**

```yaml
# prometheus-adapter-config.yaml
# Exposes Prometheus metrics as Kubernetes custom metrics for HPA

rules:
  - seriesQuery: 'http_requests_total{kubernetes_namespace!="",kubernetes_pod_name!=""}'
    resources:
      overrides:
        kubernetes_namespace: {resource: "namespace"}
        kubernetes_pod_name:  {resource: "pod"}
    name:
      matches: "^(.*)_total$"
      as: "${1}_per_second"
    metricsQuery: |
      sum(rate(<<.Series>>{<<.LabelMatchers>>}[2m])) by (<<.GroupBy>>)

  - seriesQuery: 'http_request_duration_seconds_bucket{le="0.3"}'
    name:
      as: "checkout_p99_latency_ms"
    metricsQuery: |
      histogram_quantile(0.99,
        sum(rate(http_request_duration_seconds_bucket[5m])) by (le)
      ) * 1000
```

#### Pattern 2: Predictive Autoscaling

Reactive scaling has an inherent lag — by the time CPU spikes, users are already experiencing latency. Predictive scaling uses historical patterns to scale *before* demand arrives.

```python
#!/usr/bin/env python3
"""
predictive_scaler.py — Pre-scale based on traffic forecasting
Run as a Kubernetes CronJob every 30 minutes.
Queries historical patterns and scales deployment proactively.
"""

import requests
import subprocess
import json
import math
from datetime import datetime, timedelta

PROMETHEUS_URL = "http://prometheus:9090"
NAMESPACE      = "production"
DEPLOYMENT     = "checkout"
RPS_PER_POD    = 500           # Target RPS per pod (from load testing)
MIN_PODS       = 10
MAX_PODS       = 200
SAFETY_MARGIN  = 1.3           # 30% above forecast

def get_historical_rps_at_time(
    hour: int, day_of_week: int
) -> float:
    """
    Get median RPS for a specific hour and day from last 4 weeks.
    Used to predict traffic 30 minutes ahead.
    """
    query = f"""
        quantile(0.75,
            label_replace(
                avg_over_time(
                    sum(rate(http_requests_total{{service="checkout"}}[5m]))[4w:5m]
                    @ {(datetime.now() - timedelta(weeks=i)).timestamp()}
                ),
                "week", "", "", ""
            )
        )
    """
    # Simplified: query last 4 weeks at same hour
    queries = []
    for weeks_ago in range(1, 5):
        target_time = datetime.now() - timedelta(weeks=weeks_ago)
        # Align to same hour and day of week
        if target_time.weekday() == day_of_week and target_time.hour == hour:
            queries.append(target_time.timestamp())

    if not queries:
        return None

    all_rps = []
    for ts in queries:
        r = requests.get(
            f"{PROMETHEUS_URL}/api/v1/query",
            params={
                "query": 'sum(rate(http_requests_total{service="checkout"}[5m]))',
                "time": ts
            }
        )
        data = r.json()["data"]["result"]
        if data:
            all_rps.append(float(data[0]["value"][1]))

    return sorted(all_rps)[len(all_rps) // 4 * 3] if all_rps else None  # P75

def calculate_required_pods(forecast_rps: float) -> int:
    """Calculate pod count for forecasted RPS with safety margin."""
    required = math.ceil((forecast_rps * SAFETY_MARGIN) / RPS_PER_POD)
    return max(MIN_PODS, min(MAX_PODS, required))

def scale_deployment(target_pods: int) -> None:
    """Scale Kubernetes deployment to target replica count."""
    current_pods = int(subprocess.check_output([
        "kubectl", "-n", NAMESPACE, "get", "deployment", DEPLOYMENT,
        "-o", "jsonpath={.spec.replicas}"
    ]).decode())

    if abs(target_pods - current_pods) <= 2:
        print(f"No scaling needed: current={current_pods}, target={target_pods}")
        return

    print(f"Scaling {DEPLOYMENT}: {current_pods} → {target_pods} pods")
    subprocess.run([
        "kubectl", "-n", NAMESPACE, "scale",
        f"deployment/{DEPLOYMENT}",
        f"--replicas={target_pods}"
    ], check=True)

def main():
    # Look 30 minutes ahead
    future_time = datetime.now() + timedelta(minutes=30)
    forecast_rps = get_historical_rps_at_time(
        hour=future_time.hour,
        day_of_week=future_time.weekday()
    )

    if forecast_rps is None:
        print("Insufficient historical data for prediction. Skipping.")
        return

    target_pods = calculate_required_pods(forecast_rps)
    print(f"Forecast RPS at {future_time.strftime('%H:%M')}: {forecast_rps:.0f}")
    print(f"Required pods: {target_pods}")
    scale_deployment(target_pods)

if __name__ == "__main__":
    main()
```

#### Pattern 3: Scheduled Scaling

For highly predictable patterns (business-hour services, known events), scheduled scaling is the most reliable and cheapest approach:

```yaml
# Kubernetes CronJob-based scheduled scaling
# For a B2B SaaS with strong business-hour traffic pattern

apiVersion: batch/v1
kind: CronJob
metadata:
  name: checkout-scale-schedule
  namespace: production
spec:
  schedule: "0 7 * * 1-5"   # 7am weekdays — scale up for business hours
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: scaler-sa
          containers:
            - name: scaler
              image: bitnami/kubectl:latest
              command:
                - kubectl
                - scale
                - deployment/checkout
                - --replicas=50
                - -n
                - production
          restartPolicy: Never
---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: checkout-scale-down-evening
spec:
  schedule: "0 20 * * 1-5"   # 8pm weekdays — scale down
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: scaler-sa
          containers:
            - name: scaler
              image: bitnami/kubectl:latest
              command:
                - kubectl
                - scale
                - deployment/checkout
                - --replicas=15
                - -n
                - production
          restartPolicy: Never
```

#### Pattern 4: KEDA — Event-Driven Autoscaling

KEDA (Kubernetes Event-Driven Autoscaling) scales based on event queue depth — ideal for async services, batch processors, and message consumers.

```yaml
# KEDA ScaledObject: scale order processor based on SQS queue depth
# Scales to zero when queue is empty (cost optimization)
# Scales up proportionally as messages accumulate

apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: order-processor-scaler
  namespace: production
spec:
  scaleTargetRef:
    name: order-processor
  minReplicaCount: 0          # Scale to zero when queue empty
  maxReplicaCount: 100
  cooldownPeriod: 300         # 5 min before scaling down
  pollingInterval: 30         # Check queue depth every 30s
  triggers:
    - type: aws-sqs-queue
      metadata:
        queueURL: https://sqs.us-east-1.amazonaws.com/123456/order-queue
        queueLength: "50"     # Target: 50 messages per pod
        awsRegion: us-east-1
      authenticationRef:
        name: keda-sqs-auth

    # Also scale on Prometheus metric (order processing latency)
    - type: prometheus
      metadata:
        serverAddress: http://prometheus:9090
        metricName: order_processing_lag_seconds
        threshold: "30"       # Scale up if processing lag > 30s
        query: |
          max(time() - order_last_processed_timestamp{
            service="order-processor"
          })
```

---

### 7.6 Cost vs Reliability Tradeoffs {#76-cost-vs-reliability-tradeoffs}

Every capacity decision involves a tradeoff between the cost of provisioned resources and the cost of reliability failures. SREs must model this tradeoff quantitatively — not just intuitively.

#### The Cost Tradeoff Model

```python
from dataclasses import dataclass
from typing import List

@dataclass
class CapacityScenario:
    name: str
    instances: int
    instance_cost_per_hour: float       # e.g., $0.50/hr for m5.xlarge
    max_rps_per_instance: float         # From load test results
    p99_latency_at_peak_ms: float       # From load test at this config

    # Business metrics
    revenue_per_hour_at_peak: float     # $/hr during peak traffic
    peak_hours_per_month: int           # Hours per month at peak traffic

    # Reliability metrics (from load test)
    error_rate_at_peak: float           # Fraction of failed requests
    slo_target: float = 0.999

@dataclass
class CostReliabilityAnalysis:
    scenario: CapacityScenario

    @property
    def monthly_infra_cost(self) -> float:
        return self.scenario.instances * self.scenario.instance_cost_per_hour * 730

    @property
    def peak_capacity_rps(self) -> float:
        return self.scenario.instances * self.scenario.max_rps_per_instance

    @property
    def slo_headroom_factor(self) -> float:
        """How many times current peak the system can handle."""
        return self.peak_capacity_rps / self.assumed_peak_rps

    @property
    def assumed_peak_rps(self) -> float:
        return 10_000  # Example: known peak traffic

    @property
    def monthly_incident_cost(self) -> float:
        """Expected monthly cost of SLO failures at this capacity."""
        if self.scenario.error_rate_at_peak <= (1 - self.scenario.slo_target):
            return 0  # SLO met

        # Cost of errors beyond SLO budget
        excess_error_rate = (
            self.scenario.error_rate_at_peak -
            (1 - self.scenario.slo_target)
        )
        revenue_lost_per_hour = (
            self.scenario.revenue_per_hour_at_peak * excess_error_rate
        )
        return revenue_lost_per_hour * self.scenario.peak_hours_per_month

    @property
    def total_monthly_cost(self) -> float:
        return self.monthly_infra_cost + self.monthly_incident_cost

    def summary(self) -> str:
        return (
            f"\n{'─'*55}\n"
            f"  {self.scenario.name}\n"
            f"{'─'*55}\n"
            f"  Instances:        {self.scenario.instances}\n"
            f"  Peak Capacity:    {self.peak_capacity_rps:,.0f} RPS\n"
            f"  Headroom:         {self.slo_headroom_factor:.1f}×\n"
            f"  P99 Latency:      {self.scenario.p99_latency_at_peak_ms}ms\n"
            f"  Error Rate:       {self.scenario.error_rate_at_peak:.3%}\n"
            f"  SLO Met:          {'✅ Yes' if self.scenario.error_rate_at_peak <= (1 - self.scenario.slo_target) else '❌ No'}\n"
            f"{'─'*55}\n"
            f"  Infra Cost/mo:    ${self.monthly_infra_cost:,.0f}\n"
            f"  Incident Cost/mo: ${self.monthly_incident_cost:,.0f}\n"
            f"  Total Cost/mo:    ${self.total_monthly_cost:,.0f}\n"
        )

# Compare scenarios
scenarios = [
    CostReliabilityAnalysis(CapacityScenario(
        name="Under-provisioned (10 instances)",
        instances=10,
        instance_cost_per_hour=0.50,
        max_rps_per_instance=800,
        p99_latency_at_peak_ms=2_400,
        revenue_per_hour_at_peak=50_000,
        peak_hours_per_month=200,
        error_rate_at_peak=0.08    # 8% errors at peak — SLO massively breached
    )),
    CostReliabilityAnalysis(CapacityScenario(
        name="Optimal (20 instances)",
        instances=20,
        instance_cost_per_hour=0.50,
        max_rps_per_instance=800,
        p99_latency_at_peak_ms=180,
        revenue_per_hour_at_peak=50_000,
        peak_hours_per_month=200,
        error_rate_at_peak=0.0005  # 0.05% errors — within SLO budget
    )),
    CostReliabilityAnalysis(CapacityScenario(
        name="Over-provisioned (50 instances)",
        instances=50,
        instance_cost_per_hour=0.50,
        max_rps_per_instance=800,
        p99_latency_at_peak_ms=95,
        revenue_per_hour_at_peak=50_000,
        peak_hours_per_month=200,
        error_rate_at_peak=0.0001  # 0.01% errors — far below budget
    )),
]

for analysis in scenarios:
    print(analysis.summary())
```

**Output interpretation:**
```
Under-provisioned (10 instances):
  Infra Cost/mo:    $3,650
  Incident Cost/mo: $76,000   ← 8% errors × $50k/hr × 200 peak hours
  Total Cost/mo:    $79,650

Optimal (20 instances):
  Infra Cost/mo:    $7,300
  Incident Cost/mo: $0        ← SLO met, no excess errors
  Total Cost/mo:    $7,300    ← OPTIMAL

Over-provisioned (50 instances):
  Infra Cost/mo:    $18,250
  Incident Cost/mo: $0
  Total Cost/mo:    $18,250   ← 2.5× more expensive than optimal, no benefit
```

#### N+1, N+2 Redundancy Models

A critical capacity decision is how much redundancy to provision for failure scenarios:

```
N   = Minimum instances to serve peak traffic
N+1 = Can lose one instance and still serve peak (single-failure resilient)
N+2 = Can lose two instances (or one AZ) and still serve peak
2N  = Can lose half of all instances (full AZ failure with no degradation)

For most production services: N+1 minimum, N+2 recommended
For SLO 99.99%+: 2N across ≥2 availability zones

Cost impact of redundancy models (N=20 pods):
  N    = 20 pods  (100% — baseline)
  N+1  = 21 pods  (105% — minimal overhead)
  N+2  = 22 pods  (110% — small overhead)
  2N   = 40 pods  (200% — significant cost for highest resilience)
```

---

### 7.7 Cloud-Native Capacity Management {#77-cloud-native-capacity-management}

Cloud infrastructure enables elastic capacity — you only pay for what you use. But elastic capacity without discipline creates elastic costs. Cloud-native capacity management applies SRE rigor to cloud infrastructure economics.

#### Spot/Preemptible Instance Strategy

Spot instances (AWS) / Preemptible VMs (GCP) are 60–90% cheaper than on-demand but can be reclaimed with 2-minute notice. Used correctly, they dramatically reduce infrastructure cost without impacting reliability.

```python
from dataclasses import dataclass
from typing import List

@dataclass
class InstancePool:
    name: str
    instance_type: str
    count: int
    spot: bool
    cost_per_hour: float
    preemption_rate: float   # Fraction reclaimed per hour (historical)

class HybridFleetConfig:
    """
    Hybrid fleet: on-demand base + spot burst capacity.
    On-demand handles guaranteed minimum; spot handles burst.
    """
    def __init__(
        self,
        on_demand_pools: List[InstancePool],
        spot_pools: List[InstancePool],
        min_on_demand_fraction: float = 0.30  # Keep at least 30% on-demand
    ):
        self.on_demand = on_demand_pools
        self.spot = spot_pools
        self.min_on_demand_fraction = min_on_demand_fraction

    @property
    def total_instances(self) -> int:
        return sum(p.count for p in self.on_demand + self.spot)

    @property
    def on_demand_fraction(self) -> float:
        od = sum(p.count for p in self.on_demand)
        return od / self.total_instances

    @property
    def monthly_cost(self) -> float:
        total = 0
        for pool in self.on_demand + self.spot:
            total += pool.count * pool.cost_per_hour * 730
        return total

    @property
    def expected_availability(self) -> float:
        """
        Model availability considering spot preemption.
        Spot preemptions are staggered — at 2% hourly preemption rate,
        expected simultaneous loss is small if pools are diversified.
        """
        spot_count = sum(p.count for p in self.spot)
        od_count   = sum(p.count for p in self.on_demand)

        # Expected spot instances available at any moment
        avg_preemption_rate = sum(
            p.preemption_rate for p in self.spot
        ) / len(self.spot) if self.spot else 0

        expected_spot_available = spot_count * (1 - avg_preemption_rate)
        total_available = od_count + expected_spot_available

        # Availability = fraction of time total capacity > minimum required
        min_required = od_count  # Can serve SLO on on-demand alone
        return min(1.0, total_available / self.total_instances)

    def summary(self) -> str:
        return (
            f"Fleet: {self.total_instances} instances "
            f"({self.on_demand_fraction:.0%} on-demand, "
            f"{1-self.on_demand_fraction:.0%} spot)\n"
            f"Monthly cost: ${self.monthly_cost:,.0f}\n"
            f"Expected availability: {self.expected_availability:.4%}"
        )

# Example: 20 on-demand (base) + 30 spot (burst)
fleet = HybridFleetConfig(
    on_demand_pools=[
        InstancePool("od-primary", "m5.2xlarge", 20, False, 0.384, 0.0),
    ],
    spot_pools=[
        InstancePool("spot-m5",   "m5.2xlarge",  15, True, 0.115, 0.02),
        InstancePool("spot-m4",   "m4.2xlarge",  10, True, 0.095, 0.02),
        InstancePool("spot-c5",   "c5.2xlarge",  5,  True, 0.085, 0.015),
    ]
)
print(fleet.summary())
```

#### Multi-Region Active/Active Provisioning

```yaml
# Terraform: multi-region capacity with traffic weighting
# Ensures N+1 at the region level — lose one region, serve from others

resource "aws_route53_record" "checkout_global" {
  zone_id = var.hosted_zone_id
  name    = "api.example.com"
  type    = "A"

  alias {
    name                   = aws_lb.checkout_us_east.dns_name
    zone_id                = aws_lb.checkout_us_east.zone_id
    evaluate_target_health = true  # Remove from DNS if health check fails
  }
}

# Region capacity sizing — each region handles 100% of peak load
# (N+1 at region level: lose one region, other absorbs all traffic)
module "checkout_us_east_1" {
  source      = "./modules/service"
  region      = "us-east-1"
  min_replicas = 20
  max_replicas = 200
  # Sized for 100% of peak (not 50%) — ensures full capacity if other region fails
  target_rps_per_pod = 500
}

module "checkout_eu_west_1" {
  source      = "./modules/service"
  region      = "eu-west-1"
  min_replicas = 20
  max_replicas = 200
}
```

#### FinOps Discipline for SREs

```python
def generate_rightsizing_report(
    services: list,
    prometheus_url: str
) -> list:
    """
    Identify over-provisioned services by comparing P99 utilization
    to configured resource limits.

    Services consistently below 50% utilization are candidates
    for right-sizing — reducing instance size or count.
    """
    import requests

    report = []
    for service in services:
        # P99 CPU utilization over last 30 days
        cpu_p99 = _query(prometheus_url, f"""
            quantile_over_time(0.99,
                sum by (pod) (
                    rate(container_cpu_usage_seconds_total{{
                        container="{service}"
                    }}[5m])
                )[30d:5m]
            )
        """)

        # P99 memory utilization over last 30 days
        mem_p99 = _query(prometheus_url, f"""
            quantile_over_time(0.99,
                container_memory_working_set_bytes{{
                    container="{service}"
                }}[30d:5m]
            )
        """)

        # Resource limits
        cpu_limit = _query(prometheus_url, f"""
            kube_pod_container_resource_limits{{
                container="{service}", resource="cpu"
            }}
        """)
        mem_limit = _query(prometheus_url, f"""
            kube_pod_container_resource_limits{{
                container="{service}", resource="memory"
            }}
        """)

        cpu_utilization = cpu_p99 / cpu_limit if cpu_limit > 0 else 0
        mem_utilization = mem_p99 / mem_limit if mem_limit > 0 else 0

        # Right-sizing recommendation
        # Target: P99 utilization at 70% of limit (leaves 30% headroom)
        recommended_cpu_limit = cpu_p99 / 0.70 if cpu_p99 > 0 else cpu_limit
        recommended_mem_limit = mem_p99 / 0.70 if mem_p99 > 0 else mem_limit

        savings_fraction = 1 - (
            max(recommended_cpu_limit, recommended_mem_limit) /
            max(cpu_limit, mem_limit)
        ) if max(cpu_limit, mem_limit) > 0 else 0

        report.append({
            "service":              service,
            "cpu_p99_utilization":  f"{cpu_utilization:.1%}",
            "mem_p99_utilization":  f"{mem_utilization:.1%}",
            "rightsizing_action":   (
                "REDUCE" if cpu_utilization < 0.5 and mem_utilization < 0.5
                else "OK" if cpu_utilization < 0.8
                else "INCREASE"
            ),
            "estimated_savings":    f"{savings_fraction:.1%}",
        })

    return sorted(report, key=lambda x: x["rightsizing_action"])

def _query(url: str, q: str) -> float:
    import requests
    r = requests.get(f"{url}/api/v1/query", params={"query": q})
    results = r.json().get("data", {}).get("result", [])
    return float(results[0]["value"][1]) if results else 0.0
```

---

### 7.8 Database Capacity Planning {#78-database-capacity-planning}

Database capacity is the most consequential and least elastic resource in most architectures. Unlike stateless services, you cannot simply add more database instances — you must plan carefully for connection limits, storage growth, and replication lag.

#### Database Capacity Dimensions

```
┌────────────────────────────────────────────────────────────────┐
│              Database Capacity Dimensions                      │
│                                                                │
│  COMPUTE          CONNECTIONS          STORAGE                 │
│  ─────────        ───────────          ───────                 │
│  CPU cores        Max connections      Data growth rate        │
│  Memory (buffer   Connection pool      Index growth            │
│  pool size)       utilization          WAL/binlog size         │
│                   Query concurrency    Backup retention         │
│                                                                │
│  REPLICATION      QUERY PERFORMANCE    LOCKS                   │
│  ───────────      ────────────────     ─────                   │
│  Lag seconds      Slow query rate      Lock wait time          │
│  Replica count    Index hit rate       Deadlock rate           │
│  Failover RTO     Cache hit ratio      Transaction length      │
└────────────────────────────────────────────────────────────────┘
```

```promql
# Database capacity monitoring queries

# Connection pool utilization (alert > 75%)
pg_stat_activity_count{state="active"} / pg_settings_max_connections

# Storage growth rate — project exhaustion date
predict_linear(
  pg_database_size_bytes{datname="checkout"}[7d],
  86400 * 30   # Predict 30 days ahead
)

# Replication lag — alert > 5 seconds
pg_replication_lag_seconds

# Buffer pool hit ratio — target > 99% (low = too little memory)
(pg_stat_bgwriter_buffers_alloc - pg_stat_bgwriter_buffers_backend)
/ pg_stat_bgwriter_buffers_alloc

# Slow query rate (queries > 1 second)
rate(pg_stat_statements_total_time{le="1000"}[5m])
/ rate(pg_stat_statements_calls[5m])
```

#### Connection Pool Sizing Formula

```python
def calculate_connection_pool_size(
    app_instances: int,
    threads_per_instance: int,
    target_pool_utilization: float = 0.70,  # Target 70% pool utilization
    db_max_connections: int = 500,
    connection_overhead_pct: float = 0.10   # Reserve 10% for admin/replicas
) -> dict:
    """
    Calculate optimal connection pool settings.

    Key formula: pool_size = db_max_connections × (1 - overhead) / app_instances
    Each instance should have enough connections for all threads,
    but total connections must stay under db_max_connections × target_utilization.
    """
    available_connections = int(
        db_max_connections * (1 - connection_overhead_pct)
    )
    target_connections    = int(available_connections * target_pool_utilization)

    # Connections per instance
    connections_per_instance = max(
        2,   # Minimum 2 per instance
        target_connections // app_instances
    )

    # Recommended settings for PgBouncer / HikariCP
    hikari_settings = {
        "maximumPoolSize":   connections_per_instance,
        "minimumIdle":       max(2, connections_per_instance // 4),
        "connectionTimeout": 3000,   # 3s — fail fast
        "idleTimeout":       600000, # 10 min
        "maxLifetime":       1800000 # 30 min
    }

    pgbouncer_settings = {
        "max_client_conn":     app_instances * threads_per_instance,
        "default_pool_size":   connections_per_instance,
        "reserve_pool_size":   max(2, connections_per_instance // 5),
        "pool_mode":           "transaction",  # Most efficient
    }

    total_connections = connections_per_instance * app_instances

    return {
        "app_instances":          app_instances,
        "connections_per_instance": connections_per_instance,
        "total_connections":      total_connections,
        "db_utilization":         f"{total_connections / db_max_connections:.1%}",
        "headroom":               db_max_connections - total_connections,
        "hikaricp":               hikari_settings,
        "pgbouncer":              pgbouncer_settings,
        "recommendation": (
            "✅ Safe" if total_connections < db_max_connections * 0.75
            else "⚠️  Approaching limit — consider PgBouncer"
            if total_connections < db_max_connections * 0.90
            else "🔴 Too many connections — add connection pooler immediately"
        )
    }

# Example: 50 app instances, 10 threads each, PostgreSQL max_connections=500
result = calculate_connection_pool_size(
    app_instances=50,
    threads_per_instance=10,
    db_max_connections=500
)
import json
print(json.dumps(result, indent=2))
```

---

### 7.9 Capacity Incident Response {#79-capacity-incident-response}

Capacity-related incidents have distinct characteristics: they often escalate quickly (saturation is self-reinforcing), they may not be immediately obvious (gradual latency degradation before errors), and they have specific mitigation options distinct from software bugs.

#### Capacity Incident Runbook

```
Capacity Incident Response — Decision Tree
──────────────────────────────────────────────────────────────────────
Symptom: High latency / error rate / saturation alert

Step 1: Identify the resource
  ├── CPU saturation?     → Step 2A
  ├── Memory OOM?         → Step 2B
  ├── DB connections?     → Step 2C
  ├── Traffic spike?      → Step 2D
  └── Network bandwidth?  → Step 2E

Step 2A: CPU Saturation
  Check: kubectl top pods -l app=<service> -n production
  ├── Normal traffic + high CPU?
  │   → Possible: runaway process, infinite loop, inefficient query
  │   → Action: kubectl describe pod <pod> | grep -i cpu
  │             Check for one pod consuming all CPU
  └── High traffic + high CPU?
      → Scale out: kubectl scale deployment/<service> --replicas=+10
      → Enable HPA emergency override if needed

Step 2B: Memory OOM Kills
  Check: kubectl get events -n production | grep OOMKilled
  ├── Recent deployment?
  │   → Roll back: kubectl rollout undo deployment/<service>
  └── No recent deployment?
      → Temporary: increase memory limit
        kubectl set resources deployment/<service>
          --limits=memory=2Gi
      → Permanent: investigate memory leak (pprof/heap dump)

Step 2C: Database Connection Exhaustion
  Check: psql -c "SELECT count(*), state FROM pg_stat_activity GROUP BY state;"
  ├── Too many idle connections?
  │   → Kill idle: SELECT pg_terminate_backend(pid)
  │                FROM pg_stat_activity
  │                WHERE state = 'idle'
  │                AND state_change < NOW() - INTERVAL '5 minutes';
  └── Active connections at limit?
      → Emergency: lower connection pool size in app
        (forces connections to wait, not pile up)
      → Scale: deploy PgBouncer if not present

Step 2D: Traffic Spike
  Check: Prometheus — rate(http_requests_total[1m]) vs baseline
  ├── Legitimate traffic (product launch, marketing)?
  │   → Scale out aggressively
  │   → Enable spot fleet emergency expansion
  │   → Open war room — this may sustain
  └── Illegitimate traffic (DDoS, scraper)?
      → Enable rate limiting at gateway
      → Block source IPs at CDN/WAF
      → Contact cloud provider DDoS support

Step 2E: Network Bandwidth
  Check: sar -n DEV 1 3 or CloudWatch/Stackdriver network metrics
  ├── Egress bandwidth?
  │   → Enable CDN for static assets (offload 80%+ of egress)
  │   → Compress responses (gzip/brotli)
  └── Ingress bandwidth?
      → Check for unusual upload activity
      → Rate limit large payloads at gateway
──────────────────────────────────────────────────────────────────────
```

---

### 7.10 Capacity Planning as a Continuous Practice {#710-continuous-practice}

Capacity planning is not a quarterly ritual — it is an ongoing operational discipline integrated into the SRE team's regular cadences.

#### Capacity Review Cadence

```
Weekly (15 minutes — SRE standup):
  ├── Review saturation metrics for any service > 70%
  ├── Review autoscaling events (unexpected scale-ups = hidden demand)
  └── Flag any services approaching max replica count

Monthly (1 hour — Reliability review):
  ├── Traffic growth vs forecast: is actual growth tracking the model?
  ├── Cost vs budget: are actual cloud costs within forecast?
  ├── Load test results: any services showing reduced headroom?
  ├── Database storage projections: any hitting 80% within 90 days?
  └── Update demand forecast with latest 30 days of data

Quarterly (Half day — Capacity planning workshop):
  ├── Full demand forecast refresh (90-day horizon)
  ├── Stress test for top 5 services
  ├── Instance right-sizing review (FinOps)
  ├── Database capacity planning (storage, connections, read replicas)
  ├── Event capacity planning (known peaks in next quarter)
  └── N+1 redundancy audit: are all services zone-resilient?

Pre-major-event (2 weeks before):
  ├── Event-specific demand forecast
  ├── Load test at expected peak × 1.5
  ├── Pre-scale to forecasted capacity
  ├── Pre-warm caches
  ├── Disable autoscale cooldown during ramp-up
  └── Schedule war room for event duration
```

---

## Key Principles & Best Practices {#key-principles}

1. **Provision for headroom, not just current demand.** The right provisioning target is upper-confidence-bound forecast × 1.2 safety margin — not median forecast. The cost of under-provisioning (incident, lost revenue) almost always exceeds the cost of the extra capacity.

2. **Load test before every major event.** Historical capacity that was sufficient in June may not handle Black Friday. Load test specifically at the forecasted peak × 1.5 headroom, not just at current peak. Always test the full system, not individual services.

3. **Autoscaling is not a substitute for capacity planning.** Autoscaling handles gradual demand growth and routine spikes. It cannot prevent a SEV1 caused by a traffic spike faster than the scale-up reaction time (typically 2–5 minutes for new pods to be ready). Capacity planning ensures minimum pod counts are already sufficient for peak load.

4. **Target CPU at 60-70%, never 80%+.** The utilization-latency curve is non-linear. At 70% CPU, latency is 3× service time — usually within SLO. At 90%, it's 10× — almost certainly a breach. Set HPA CPU targets at 60%, not 80%.

5. **Database capacity is your most expensive surprise.** Database storage fills gradually and then all at once — you get no warning until it's full. Storage projections, connection pool sizing, and replication lag monitoring belong in every weekly capacity review.

6. **Model cost vs reliability quantitatively.** The "optimal" provisioning point is not "as cheap as possible" — it's the crossover where the cost of the next instance equals the expected value of the incidents it prevents. Build this model and use it to justify investment.

7. **Spot instances for burst, on-demand for base.** The correct fleet composition is: on-demand instances sized for minimum sustainable load + spot/preemptible for burst. Never run critical workloads on 100% spot — preemption during peak = self-inflicted capacity incident.

---

## Tools & Technologies {#tools}

| Tool | Category | Capacity Use Case |
|---|---|---|
| **Kubernetes HPA** | Autoscaling | CPU/memory/custom metric reactive scaling |
| **KEDA** | Event-Driven Autoscaling | Queue-depth and event-based scaling to zero |
| **Cluster Autoscaler** | Node Scaling | Add/remove cluster nodes based on pod scheduling pressure |
| **Vertical Pod Autoscaler (VPA)** | Resource Right-sizing | Auto-adjust CPU/memory requests/limits |
| **Prometheus** | Metrics | Utilization tracking, forecast data source, HPA custom metrics |
| **k6** | Load Testing | Scripted load, stress, soak, spike tests with SLO thresholds |
| **Locust** | Load Testing | Python-based distributed load testing |
| **Gatling** | Load Testing | Scala DSL load testing, CI/CD integration |
| **AWS Auto Scaling** | Cloud Scaling | EC2 ASG, ECS Service Auto Scaling, target tracking policies |
| **Terraform** | IaC | Codify instance types, counts, and scaling policies |
| **Kubecost** | FinOps | Kubernetes cost allocation and right-sizing recommendations |
| **AWS Cost Explorer** | FinOps | Cost trends, Reserved Instance planning, Savings Plans |

---

## Hands-on Exercises / Labs {#labs}

### Lab 7.1 — Demand Forecasting

**Goal:** Build a demand forecast and translate it into a capacity plan.

**Given:** 90 days of hourly RPS data for a B2C e-commerce API with clear daily and weekly seasonality. Average weekday peak: 8,000 RPS at noon. Weekend peak: 12,000 RPS. Growing at approximately 8% month-over-month.

**Tasks:**
1. Apply `forecast_linear_trend()` to the daily peak data. What does the 90-day forecast predict?
2. Identify: what are the peak hours requiring maximum provisioning? Why doesn't linear extrapolation alone capture this?
3. Apply STL decomposition to the hourly data. Extract the trend, weekly seasonal, and daily seasonal components.
4. Using the composite forecast (trend + seasonality), calculate:
   - Required capacity at forecasted peak in 90 days
   - Required capacity for a planned "Summer Sale" event expected to produce 3× normal weekend peak
5. Write the capacity plan document for the next quarter, including: current capacity, required capacity at 90 days, scaling actions required, and load test milestones.

---

### Lab 7.2 — Load Test Design and Execution

**Goal:** Design a complete load test strategy for a service before a major traffic event.

**Scenario:** Your team is launching a major product feature in 3 weeks expected to drive 5× normal traffic for the first 48 hours. Current peak: 3,000 RPS. SLO: 99.9% availability, P99 < 500ms.

**Tasks:**
1. Design the load test strategy: what test types (load, stress, soak, spike) will you run, in what order, at what targets, and what are the pass/fail criteria?
2. Write a k6 load test script for the feature's primary user journey (define the journey yourself — e.g., view feature → interact → submit).
3. Set the SLO-aligned thresholds in the k6 options that will automatically fail the test if the SLO would be breached at peak load.
4. Write the stress test configuration to find the capacity ceiling.
5. Based on stress test results showing the service degrades at 18,000 RPS, write the capacity plan: how many instances? What autoscaling configuration? What pre-scaling schedule?

---

### Lab 7.3 — Autoscaling Configuration

**Goal:** Configure production-grade autoscaling for a stateless web service.

**Given:**
- Service: `recommendation-api`
- Load test results: 400 RPS per pod at P99 = 150ms (SLO: 200ms)
- Traffic pattern: Business hours peak (9am-6pm) at 8,000 RPS; overnight trough at 500 RPS
- Scaling constraint: Cost budget requires <30 pods overnight, flexibility to 200 during business hours

**Tasks:**
1. Write the HPA configuration with:
   - Custom RPS-per-pod metric (target: 400 RPS/pod)
   - CPU target (derive the correct percentage from load test data)
   - Conservative scale-down policy (prevent thrashing)
   - Aggressive scale-up policy (prevent lag during spikes)
2. Write the scheduled scaling CronJobs that pre-scale before business hours.
3. Configure the Prometheus custom metrics adapter to expose RPS-per-pod as a Kubernetes custom metric.
4. Write PromQL alerts for: autoscaling hitting max replicas, scale-up events > 3 in 10 minutes (potential runaway), and scale-down failures.
5. Simulate: at 9,000 RPS with 20 pods (450 RPS/pod — above target), how long before HPA adds pods? What is the user impact during the lag? How do you mitigate it?

---

### Lab 7.4 — Cost vs Reliability Analysis

**Goal:** Build the cost-reliability model and justify an optimal provisioning decision.

**Given:**
```
Service: payment-api
Load test results:
  10 instances: max 8,000 RPS, P99 = 180ms at 5,000 RPS, errors = 0.01%
  15 instances: max 12,000 RPS, P99 = 120ms at 5,000 RPS, errors = 0.001%
  20 instances: max 16,000 RPS, P99 = 95ms at 5,000 RPS, errors = 0.0001%
  25 instances: max 20,000 RPS, P99 = 90ms at 5,000 RPS, errors = 0.0001%

Instance cost: $0.80/hour (m5.2xlarge)
Peak traffic: 5,000 RPS for 300 hours/month
Revenue at peak: $80,000/hour
SLO: 99.9% availability
SLA: 99.5% (credits: 10% MRR per 0.1% below SLA)
Monthly MRR: $2,000,000
```

**Tasks:**
1. For each instance count (10, 15, 20, 25), calculate: monthly infra cost, monthly incident cost (using the model from Section 7.6), total monthly cost.
2. Identify the optimal instance count (minimum total cost while meeting SLO).
3. Model N+1 redundancy: what instance count ensures the service can still meet SLO if one instance fails unexpectedly?
4. Model the spot instance hybrid: replace 60% of instances with spot (70% discount, 2% hourly preemption). What is the monthly saving? What is the new expected availability?
5. Write the capacity decision memo for your engineering director: optimal configuration, monthly cost, SLO compliance, redundancy model, and cost vs alternatives.

---

## Common Pitfalls & Anti-patterns {#pitfalls}

**Anti-pattern 1: Capacity planning as an annual ritual**
The team runs a capacity planning exercise once a year, provisions infrastructure for the year, and considers the job done. By Q3, traffic has grown 40% beyond forecast and services are saturating. *Fix:* Capacity planning is a weekly (saturation review), monthly (forecast update), and quarterly (full exercise) cadence — not an annual event.

**Anti-pattern 2: Autoscaling with CPU target at 80%**
The HPA CPU target is set at 80%. By the time autoscaling triggers at 80%, latency is already 5× service time — well into SLO violation territory. The scale-up lag (2–5 minutes for new pods to be healthy) means users experience degradation during every traffic spike. *Fix:* Set HPA CPU target at 60%. At 60%, latency is 2.5× service time — still within most SLOs. The scale-up triggers before the problem reaches users.

**Anti-pattern 3: Load testing only at current peak**
Load tests are run at "expected peak" (current traffic × 1.2). They pass. The service is deployed. A marketing campaign drives 5× traffic and the service falls over. *Fix:* Always load test at 1.5–2× expected peak for planned events. For Black Friday or product launches, test at the stress limit — find the breaking point so you know your headroom.

**Anti-pattern 4: No database capacity plan**
Stateless services are carefully autoscaled and right-sized. The database is given an instance type and forgotten. Six months later, storage fills up (no monitoring), connection pool exhausts during peak (never sized properly), and replication lag causes stale reads. *Fix:* Database capacity gets the same quarterly review as compute: storage growth projection (predict_linear in PromQL), connection pool sizing formula, replication lag monitoring, and annual performance review.

**Anti-pattern 5: Treating autoscaling as infinite**
Engineers assume the cloud is infinite and autoscaling will always save them. They set maxReplicas=1000, expect the cluster to expand indefinitely, and never test what happens when the account hits instance quota limits, or when the node pool runs out of available instances in an AZ. *Fix:* Autoscaling has limits — service quota limits, cluster capacity limits, instance availability in spot markets. Test scale-up to maxReplicas in staging. Monitor available node capacity. Set alerts when approaching quotas.

**Anti-pattern 6: Ignoring the N+1 requirement during normal operations**
Services are provisioned at N (exactly enough for peak). During normal operations, this looks fine. When one instance fails or one AZ becomes unavailable, the remaining instances are immediately overloaded. *Fix:* Minimum provisioning for any production service is N+1. For services with 99.99% SLOs, N+2 across ≥2 AZs is required. Build this into capacity models explicitly.

---

## Interview Questions {#interview-questions}

**Conceptual:**

1. *"Explain the utilization-latency curve (queueing theory) and why it justifies targeting 60-70% CPU utilization rather than 80-90%."*
   — Look for: M/M/1 queue model; response time = service time / (1 - utilization); at 70% utilization latency is 3× baseline (usually in SLO); at 90% it's 10× (usually out of SLO); scale-up lag means you need headroom before hitting the cliff.

2. *"What is the Universal Scalability Law and what does it tell us about horizontal scaling?"*
   — Look for: throughput doesn't scale linearly with instances due to contention (serialization) and coherence (coordination) overhead; sigma (contention) limits scalability around 10–20 instances; kappa (coherence) causes throughput to actually decrease at very high instance counts; practical implication: identify shared resources and reduce contention.

3. *"Describe the four load test types and when you would use each."*
   — Look for: load test (validate SLO at expected peak, 30-60 min), stress test (find breaking point, no pass/fail thresholds), soak test (detect memory leaks/resource exhaustion over 24-72h), spike test (validate autoscaling and burst capacity, sudden 10× injection); each answers a different question about system behavior.

**Scenario-based:**

4. *"Your checkout service HPA is configured with maxReplicas=50. On Black Friday, traffic hits 40× normal baseline and the service scales to 50 pods and starts returning 503 errors. What went wrong and what do you do right now, and in the next sprint?"*
   — Look for: right now — manual override to increase maxReplicas (or deploy pre-scaled dedicated Black Friday deployment), scale database connections, check for non-auto-scaling bottlenecks (database, caches, downstream services); root cause — load test before the event was insufficient, maxReplicas set too low, no pre-scaling plan; next sprint — event capacity planning process, pre-scale the week before, load test at 50× baseline, raise maxReplicas with budget approval, implement predictive scaling.

5. *"Your engineering director asks you to reduce cloud infrastructure costs by 30% without impacting reliability. How do you approach this?"*
   — Look for: start with right-sizing (VPA recommendations, P99 utilization vs limits); identify spot instance candidates (stateless services with 30+ minute warm-up time); reserved instance analysis for stable baseline load; autoscaling floor reduction (lower minReplicas overnight); identify dev/staging environments with production-level resources; KEDA scale-to-zero for batch/async workloads; quantify each saving opportunity before implementing; never reduce below N+1 redundancy; present as a portfolio of changes with risk/savings for each.

---

## Further Reading & Resources {#further-reading}

**Books:**
- *Systems Performance* — Brendan Gregg (Pearson) — Definitive reference on performance analysis, USE method, and utilization modeling
- *The Art of Capacity Planning* — John Allspaw (O'Reilly) — Practical capacity planning for web operations
- *Database Reliability Engineering* — Laine Campbell & Charity Majors (O'Reilly) — Database-specific capacity and reliability

**Online:**
- [Brendan Gregg: USE Method](https://www.brendangregg.com/usemethod.html) — Utilization, Saturation, Errors methodology
- [Neil Gunther: Universal Scalability Law](http://www.perfdynamics.com/Manifesto/USLscalability.html) — Original USL paper
- [AWS Auto Scaling Best Practices](https://docs.aws.amazon.com/autoscaling/ec2/userguide/as-scaling-best-practices.html)
- [k6 Documentation](https://k6.io/docs/) — Load testing framework with SLO thresholds
- [KEDA Documentation](https://keda.sh/docs/) — Event-driven autoscaling for Kubernetes

**Tools:**
- [Gatling Enterprise](https://gatling.io) — Enterprise load testing with CI/CD integration
- [Kubecost](https://www.kubecost.com) — Kubernetes cost monitoring and right-sizing

---

## Key Takeaways {#key-takeaways}

> **Chapter 7 Summary**
>
> - **Capacity planning has two failure modes:** under-provisioning (incidents, SLO breach, revenue loss) and over-provisioning (wasted cost, competitive disadvantage). The goal is the reliability-cost efficient frontier — meeting SLO at minimum cost.
>
> - **Demand forecasting uses three methods:** linear trend extrapolation for steady-growth services, STL seasonal decomposition for services with daily/weekly patterns, and event-based multipliers for known spikes like Black Friday. Historical performance is the primary input; user research and business requirements constrain the output.
>
> - **The utilization-latency curve explains why 70% is the warning threshold.** At 70% CPU, latency is 3× service time — typically within SLO. At 90%, it's 10× — almost certainly a breach. Target HPA CPU at 60%, not 80%, to leave headroom for scale-up lag.
>
> - **Four load test types answer four different questions:** load tests validate SLO compliance at expected peak; stress tests find the breaking point; soak tests detect resource exhaustion over time; spike tests validate autoscaling responsiveness.
>
> - **Autoscaling patterns have distinct use cases:** reactive HPA for general stateless services, predictive scaling for highly seasonal patterns, scheduled scaling for deterministic business-hour patterns, and KEDA for event-driven/async workloads.
>
> - **Cost vs reliability is a quantitative model, not a negotiation.** Under-provisioning transfers cost from the infrastructure budget to the incident budget — usually at 10–100× cost. Build the model, find the crossover, provision at the efficient frontier.
>
> - **Database capacity requires special treatment.** Storage fills non-linearly, connections are a hard limit, and replication lag compounds under load. Database capacity planning — storage projections, connection pool sizing, read replica planning — deserves its own quarterly review.
>
> - **N+1 is a minimum, not a luxury.** Every production service must be able to serve peak traffic after losing at least one instance. For 99.99%+ SLOs, N+2 across multiple availability zones is required.

---
*Previous: [Chapter 6 — SLI / SLO / SLA](#chapter-6)*
*Next: Chapter 8 — On-Call and First Response*
