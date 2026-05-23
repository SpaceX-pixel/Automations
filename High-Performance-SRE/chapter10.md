# Chapter 10 — Chaos Engineering
---

## Table of Contents

- [Learning Objectives](#learning-objectives)
- [Core Concepts](#core-concepts)
  - [10.1 What Is Chaos Engineering?](#101-what-is-chaos-engineering)
  - [10.2 The Five Principles of Chaos Engineering](#102-five-principles)
  - [10.3 The Steady-State Hypothesis](#103-steady-state-hypothesis)
  - [10.4 Blast Radius Control](#104-blast-radius-control)
  - [10.5 Failure Injection Taxonomy](#105-failure-taxonomy)
  - [10.6 Staging vs Production Chaos](#106-staging-vs-production)
  - [10.7 Tools — Chaos Monkey, Gremlin, and Litmus](#107-tools)
  - [10.8 GameDays — Structured Chaos Exercises](#108-gamedays)
  - [10.9 Building a Chaos Culture](#109-chaos-culture)
  - [10.10 Chaos Experiment Automation](#1010-automation)
  - [10.11 Measuring Chaos Engineering Maturity](#1011-maturity)
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

- Articulate the chaos engineering philosophy — including its distinction from random failure injection — and explain why proactive resilience testing is preferable to discovering failures under production load.
- Design rigorous chaos experiments using the steady-state hypothesis framework: defining measurable success criteria, selecting appropriate failure types, and bounding blast radius before execution.
- Apply blast radius controls — traffic segmentation, feature flags, staged rollout, and abort conditions — to safely run experiments in production without SLO impact.
- Execute structured GameDays that produce actionable resilience findings, improve team response capability, and feed directly into the risk register and post-mortem process.
- Select and operate the appropriate chaos tooling for a given environment — Chaos Monkey for Netflix-style random termination, Gremlin for controlled enterprise experiments, and Litmus for Kubernetes-native chaos.

---

## Core Concepts {#core-concepts}

### 10.1 What Is Chaos Engineering? {#101-what-is-chaos-engineering}

Chaos engineering is the discipline of experimenting on a system in order to build confidence in its ability to withstand turbulent conditions in production.

The Netflix engineering team coined the term in 2011 when they created Chaos Monkey — a tool that randomly terminated production EC2 instances. The premise was stark: *if our infrastructure can randomly fail at any time, we must build systems that survive it rather than trying to prevent it.*

This premise generalizes beyond Netflix. Every production system will face unexpected failures: hardware dies, networks partition, dependencies degrade, configuration drifts, traffic spikes arrive unannounced. The choice is not between "system that fails" and "system that doesn't fail" — it is between "system that fails in known, manageable ways" and "system that fails in unknown, catastrophic ways."

Chaos engineering shifts failure discovery from production incidents (expensive, uncontrolled, user-impacting) to designed experiments (controlled, bounded, fixable).

```
The Discovery Spectrum
──────────────────────────────────────────────────────────────────────
Worst:    User reports the system is broken
          → Failure discovered under production load, at full scale,
            with no preparation, no abort conditions, users affected

Bad:      Monitoring alert fires during real incident
          → Better than user report, but damage already occurring

Good:     Chaos experiment in staging reveals failure mode
          → No user impact; controlled; fixable before production

Best:     Chaos experiment in production (low blast radius) reveals
          failure mode before real-world trigger
          → Smallest possible blast radius; team practiced on response;
            fix deployed before random version occurs at full scale
──────────────────────────────────────────────────────────────────────
```

**Chaos engineering is not:**
- Random destruction with no hypothesis
- An excuse to break things
- A substitute for good design
- Only for hyperscale organizations

**Chaos engineering is:**
- Hypothesis-driven experimentation
- A method for discovering unknown failure modes
- A practice that makes failure response a practiced skill
- Applicable to any system operating above a certain reliability threshold

#### The Economics of Chaos Engineering

```
Cost of Discovery Through Incidents:
  Average SEV2 incident duration:     45 minutes
  Average engineering cost:           4 engineers × 45 min = 3 hours
  Revenue impact at $10,000/min:      $450,000 per incident
  Post-mortem cost:                   8 engineer-hours
  Probability-weighted monthly cost:  $450,000 × P(incident)

Cost of Discovery Through Chaos:
  Experiment design:                  2-4 engineer-hours
  Execution (controlled):             30-60 minutes
  Blast radius at peak:               2-5% traffic
  Finding to fix:                     1-2 sprint weeks
  Prevention value:                   Prevents recurrence of this
                                      failure mode indefinitely

ROI: A single prevented SEV2 pays for 20-40 chaos experiments.
```

---

### 10.2 The Five Principles of Chaos Engineering {#102-five-principles}

The Principles of Chaos Engineering (principlesofchaos.org) defines five core practices. Together they distinguish rigorous chaos engineering from random failure injection.

#### Principle 1: Build a Hypothesis Around Steady-State Behavior

A chaos experiment is not "let's see what breaks." It is a falsifiable hypothesis: *if we inject [failure X], then [metric Y] will remain within [threshold Z].*

Without a hypothesis, you have no pass/fail criteria. Without pass/fail criteria, every experiment "succeeds" by definition — you learn nothing actionable.

#### Principle 2: Vary Real-World Events

Inject failures that actually occur in production: server failures, network latency, disk exhaustion, dependency timeouts, packet loss, process crashes, clock skew. Synthetic, laboratory-only failure modes (that never occur in production) waste resources and produce misleading confidence.

#### Principle 3: Run Experiments in Production

This is the most controversial principle — and the most important. Staging environments differ from production in data volume, traffic patterns, service topology, and configuration. A system that survives chaos in staging may behave completely differently under production load.

Running experiments in production is only safe when blast radius controls are in place (Section 10.4). Without blast radius control, production chaos is reckless. With proper controls, it is the highest-signal testing available.

#### Principle 4: Automate Experiments to Run Continuously

One-off chaos experiments discover failure modes. Continuously running chaos experiments prevent regression — ensuring that a failure mode you fixed last quarter hasn't been re-introduced by a recent deployment.

Continuous chaos is analogous to continuous integration: it catches problems as they are introduced, not months later when they've compounded.

#### Principle 5: Minimize Blast Radius

The obligation to minimize blast radius is not optional. It is what makes production chaos engineering responsible rather than reckless. Every experiment should be designed with the smallest possible user impact — starting with 0.1% of traffic, expanding only when the experiment proves safe.

---

### 10.3 The Steady-State Hypothesis {#103-steady-state-hypothesis}

The steady-state hypothesis is the scientific core of chaos engineering. It transforms a vague "let's see if this breaks" into a rigorous experiment with measurable success criteria.

**Structure:**
```
"We believe that [system/service] will maintain [metric(s)] within
 [acceptable range] when [failure condition] is applied to
 [scope/percentage] of [infrastructure/traffic]."
```

**Example hypotheses:**

```
Hypothesis 1 — Dependency failure:
"We believe that the checkout service will maintain an error rate
 below 0.1% and P99 latency below 500ms when the inventory service
 is made unavailable for 2 minutes for 10% of requests."

Hypothesis 2 — Node failure:
"We believe that the payment API cluster will maintain its SLO
 (99.95% availability) when one of its three database replicas
 is terminated and the cluster auto-fails over."

Hypothesis 3 — Latency injection:
"We believe that the search service will serve results within
 200ms P99 when a 100ms artificial latency is added to the
 product catalog dependency."

Hypothesis 4 — Resource exhaustion:
"We believe that the user auth service will gracefully degrade
 (serve cached sessions) rather than fail when its Redis cache
 is terminated and restarted."
```

#### Hypothesis Design Framework

```python
from dataclasses import dataclass, field
from typing import List, Optional
from enum import Enum

class ExperimentResult(Enum):
    HYPOTHESIS_CONFIRMED   = "confirmed"    # System behaved as expected
    HYPOTHESIS_REJECTED    = "rejected"     # System failed — new finding!
    INCONCLUSIVE           = "inconclusive" # Insufficient data
    ABORTED                = "aborted"      # Blast radius exceeded; stopped

@dataclass
class SteadyStateMetric:
    """A single measurable dimension of steady-state behavior."""
    name:          str           # Human-readable name
    promql:        str           # How to measure it
    threshold:     float         # Acceptable boundary
    comparison:    str           # "below" | "above" | "within_pct"
    tolerance_pct: float = 5.0   # Allowed deviation before abort

    def is_healthy(self, current_value: float) -> bool:
        if self.comparison == "below":
            return current_value <= self.threshold * (1 + self.tolerance_pct / 100)
        elif self.comparison == "above":
            return current_value >= self.threshold * (1 - self.tolerance_pct / 100)
        return False

    def format_for_doc(self) -> str:
        direction = "below" if self.comparison == "below" else "above"
        return f"`{self.name}` remains {direction} `{self.threshold}`"

@dataclass
class ChaosExperiment:
    """
    A fully specified chaos experiment with hypothesis, method, and abort conditions.
    """
    id:               str
    title:            str
    hypothesis:       str
    service:          str
    environment:      str          # staging | canary | production-5pct | production

    # Failure injection specification
    failure_type:     str          # pod_kill | latency | network_loss | cpu_stress | etc.
    failure_target:   str          # What receives the failure
    failure_params:   dict         # Failure-specific parameters
    blast_radius_pct: float        # Max % of traffic/instances affected

    # Steady-state definition
    steady_state_metrics: List[SteadyStateMetric]

    # Timing
    baseline_duration_min:    int = 5   # Measure baseline before injection
    experiment_duration_min:  int = 10  # How long to run injection
    recovery_duration_min:    int = 5   # Observe recovery

    # Safety
    abort_conditions:     List[str] = field(default_factory=list)
    rollback_procedure:   str = ""
    requires_approval:    bool = True
    approved_by:          Optional[str] = None

    # Results (filled post-experiment)
    result:               Optional[ExperimentResult] = None
    findings:             List[str] = field(default_factory=list)
    action_items:         List[str] = field(default_factory=list)

    def validate(self) -> List[str]:
        """Validate experiment design before execution."""
        errors = []
        if not self.steady_state_metrics:
            errors.append("No steady-state metrics defined. Cannot determine pass/fail.")
        if self.blast_radius_pct > 10 and self.environment == "production":
            errors.append(
                f"Blast radius {self.blast_radius_pct}% exceeds recommended "
                f"10% maximum for production. Start smaller."
            )
        if not self.abort_conditions:
            errors.append("No abort conditions defined. Add at least one.")
        if not self.rollback_procedure:
            errors.append("No rollback procedure documented.")
        if self.environment == "production" and not self.approved_by:
            errors.append("Production experiments require explicit approval.")
        return errors

    def generate_experiment_brief(self) -> str:
        """Generate human-readable experiment brief for team review."""
        metrics_str = "\n".join(
            f"  - {m.format_for_doc()}"
            for m in self.steady_state_metrics
        )
        abort_str = "\n".join(
            f"  - {a}" for a in self.abort_conditions
        )
        validation = self.validate()
        validation_str = (
            "✅ Experiment design is valid."
            if not validation
            else "❌ Issues:\n" + "\n".join(f"  - {e}" for e in validation)
        )

        return f"""
╔══════════════════════════════════════════════════════════════╗
║  CHAOS EXPERIMENT BRIEF: {self.id}
╚══════════════════════════════════════════════════════════════╝

Title:        {self.title}
Service:      {self.service}
Environment:  {self.environment}
Blast Radius: {self.blast_radius_pct}% of traffic/instances

HYPOTHESIS
  {self.hypothesis}

FAILURE INJECTION
  Type:   {self.failure_type}
  Target: {self.failure_target}
  Params: {self.failure_params}

STEADY-STATE SUCCESS CRITERIA
{metrics_str}

TIMELINE
  Baseline:   {self.baseline_duration_min} min (measure before injection)
  Experiment: {self.experiment_duration_min} min (active failure)
  Recovery:   {self.recovery_duration_min} min (observe return to normal)

ABORT CONDITIONS
{abort_str}

ROLLBACK
  {self.rollback_procedure}

VALIDATION
  {validation_str}
""".strip()


# Example experiment: inventory service dependency failure
experiment = ChaosExperiment(
    id="CE-2024-017",
    title="Checkout graceful degradation during inventory service outage",
    hypothesis=(
        "The checkout service will maintain error rate below 0.1% "
        "and serve degraded responses (without stock validation) "
        "when inventory service returns 503 for 10% of requests."
    ),
    service="checkout",
    environment="production",
    failure_type="http_error_injection",
    failure_target="inventory-service.production.svc:8080",
    failure_params={
        "error_code":  503,
        "probability": 0.10,
        "duration_s":  600,
    },
    blast_radius_pct=10.0,
    steady_state_metrics=[
        SteadyStateMetric(
            name="checkout_error_rate",
            promql='sum(rate(http_requests_total{service="checkout",status_code=~"5.."}[1m])) / sum(rate(http_requests_total{service="checkout"}[1m]))',
            threshold=0.001,
            comparison="below"
        ),
        SteadyStateMetric(
            name="checkout_p99_latency_ms",
            promql='histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket{service="checkout"}[1m])) by (le)) * 1000',
            threshold=500.0,
            comparison="below"
        ),
        SteadyStateMetric(
            name="checkout_requests_per_second",
            promql='sum(rate(http_requests_total{service="checkout"}[1m]))',
            threshold=800.0,
            comparison="above",
            tolerance_pct=15.0   # Allow 15% drop before aborting
        ),
    ],
    baseline_duration_min=5,
    experiment_duration_min=10,
    recovery_duration_min=5,
    abort_conditions=[
        "checkout_error_rate exceeds 0.5% for 60 consecutive seconds",
        "checkout_p99_latency_ms exceeds 2000ms",
        "checkout_requests_per_second drops below 500 (circuit breaker opened)",
        "Any P1 alert fires during experiment",
    ],
    rollback_procedure=(
        "Stop Gremlin attack via: gremlin attacks stop CE-2024-017\n"
        "Verify inventory service health: curl inventory-service/health\n"
        "Monitor checkout error rate for 5 minutes post-stop"
    ),
    requires_approval=True,
    approved_by="@sre-lead"
)

print(experiment.generate_experiment_brief())
errors = experiment.validate()
if not errors:
    print("\n✅ Ready to execute")
```

---

### 10.4 Blast Radius Control {#104-blast-radius-control}

Blast radius is the scope of potential impact of a chaos experiment. Controlling it is the difference between responsible chaos engineering and reckless failure injection. Every mechanism described here limits how much of the system — and therefore how many users — can be affected if the experiment reveals an unexpected failure mode.

#### The Blast Radius Ladder

Start at the smallest possible scope. Only expand when the experiment at the current scope passes cleanly.

```
Blast Radius Expansion Ladder
──────────────────────────────────────────────────────────────────────
Level 1: Developer environment (no users affected)
  → Run failure injection in local development
  → Validate: does the application log errors? Does it recover?
  → Gate: application handles failure without crashing

Level 2: Staging with synthetic traffic (no real users)
  → Inject failure against staging environment
  → k6/synthetic load generator provides traffic
  → Gate: steady-state metrics maintained under synthetic load

Level 3: Canary / shadow production (1-5% real traffic)
  → Inject failure against canary deployment
  → Real production traffic routed at 1-5% to canary
  → Gate: SLO metrics maintained; no P1/P2 alerts

Level 4: Production subset (5-10% real traffic)
  → Inject failure affecting 5-10% of production
  → Continuous monitoring with auto-abort
  → Gate: pass/fail criteria met; error budget not materially consumed

Level 5: Production at scale (>10% traffic)
  → Large-scale experiments after Level 4 validation
  → Reserved for mature chaos programs with strong automation
  → Gate: exhaustive validation at all prior levels
──────────────────────────────────────────────────────────────────────
Most teams should spend 80% of their experiments at Levels 2-3.
Level 4 requires mature SLO infrastructure and auto-abort.
Level 5 requires Netflix-scale chaos program maturity.
```

#### Blast Radius Control Techniques

```python
import time
import requests
import threading
from datetime import datetime, timedelta

class BlastRadiusController:
    """
    Real-time blast radius monitoring and experiment abort controller.
    Monitors steady-state metrics during a chaos experiment and
    automatically stops the experiment if abort conditions are met.
    """

    def __init__(
        self,
        experiment:      ChaosExperiment,
        prometheus_url:  str,
        abort_callback:  callable,          # Function to stop the experiment
        check_interval:  int = 10,          # Seconds between health checks
    ):
        self.experiment     = experiment
        self.prometheus_url = prometheus_url
        self.abort_callback = abort_callback
        self.check_interval = check_interval
        self._running       = False
        self._abort_reason: str | None = None
        self._health_log    = []

    def query_metric(self, promql: str) -> float | None:
        try:
            r = requests.get(
                f"{self.prometheus_url}/api/v1/query",
                params={"query": promql},
                timeout=5
            )
            results = r.json().get("data", {}).get("result", [])
            return float(results[0]["value"][1]) if results else None
        except Exception:
            return None

    def check_abort_conditions(self) -> tuple[bool, str]:
        """
        Check all steady-state metrics against abort thresholds.
        Returns (should_abort, reason).
        """
        for metric in self.experiment.steady_state_metrics:
            current = self.query_metric(metric.promql)
            if current is None:
                continue   # Can't measure — don't abort on missing data

            if not metric.is_healthy(current):
                return True, (
                    f"Abort condition met: {metric.name} = {current:.4f} "
                    f"(threshold: {metric.threshold}, "
                    f"comparison: {metric.comparison})"
                )

        return False, ""

    def monitor(self, experiment_end_time: datetime) -> None:
        """
        Continuously monitor experiment health until end time or abort.
        Runs in a separate thread during experiment execution.
        """
        self._running = True
        consecutive_violations = 0

        while self._running and datetime.utcnow() < experiment_end_time:
            should_abort, reason = self.check_abort_conditions()

            health_entry = {
                "timestamp": datetime.utcnow().isoformat(),
                "healthy":   not should_abort,
                "details":   reason
            }
            self._health_log.append(health_entry)

            if should_abort:
                consecutive_violations += 1
                print(f"⚠️  Health check failed ({consecutive_violations}/3): {reason}")

                # Require 3 consecutive violations to abort
                # (prevents false aborts from momentary spikes)
                if consecutive_violations >= 3:
                    self._abort_reason = reason
                    print(f"\n🛑 ABORTING EXPERIMENT: {reason}")
                    self.abort_callback(self.experiment.id, reason)
                    self._running = False
                    return
            else:
                consecutive_violations = 0   # Reset on healthy check
                print(f"✅ [{datetime.utcnow().strftime('%H:%M:%S')}] "
                      f"Steady state maintained")

            time.sleep(self.check_interval)

        self._running = False

    def start_monitoring(self, duration_minutes: int) -> threading.Thread:
        """Start monitoring in background thread."""
        end_time = datetime.utcnow() + timedelta(minutes=duration_minutes)
        thread   = threading.Thread(
            target=self.monitor,
            args=(end_time,),
            daemon=True
        )
        thread.start()
        return thread

    def was_aborted(self) -> bool:
        return self._abort_reason is not None

    def get_abort_reason(self) -> str | None:
        return self._abort_reason

    def health_summary(self) -> dict:
        total    = len(self._health_log)
        healthy  = sum(1 for e in self._health_log if e["healthy"])
        return {
            "total_checks":      total,
            "healthy_checks":    healthy,
            "unhealthy_checks":  total - healthy,
            "health_pct":        f"{healthy/total:.1%}" if total else "N/A",
            "aborted":           self.was_aborted(),
            "abort_reason":      self.get_abort_reason(),
        }
```

#### Traffic Segmentation for Blast Radius

```yaml
# Istio VirtualService: route 5% of traffic to chaos-enabled canary
# The canary pod has Gremlin agent injected — chaos only affects 5% of users

apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: checkout-chaos-split
  namespace: production
spec:
  hosts:
    - checkout
  http:
    # 5% of traffic → chaos canary (experiment target)
    - match:
        - headers:
            x-chaos-canary:
              exact: "true"   # Internal traffic header
      route:
        - destination:
            host:   checkout
            subset: chaos-canary
      fault:
        abort:
          percentage:
            value: 10.0   # 10% of canary traffic gets 503
          httpStatus: 503

    # 95% of traffic → stable production (unaffected)
    - route:
        - destination:
            host:   checkout
            subset: stable
          weight: 95
        - destination:
            host:   checkout
            subset: chaos-canary
          weight: 5
---
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: checkout-subsets
  namespace: production
spec:
  host: checkout
  subsets:
    - name: stable
      labels:
        version: stable
    - name: chaos-canary
      labels:
        version: chaos-canary
```

---

### 10.5 Failure Injection Taxonomy {#105-failure-taxonomy}

A systematic catalog of failure types gives chaos engineers a shared vocabulary and ensures experiments cover the full spectrum of real-world failure modes.

```
Failure Injection Taxonomy
──────────────────────────────────────────────────────────────────────────────
Category        Type                    Tool        Real-World Trigger
──────────────────────────────────────────────────────────────────────────────
Infrastructure  Pod/instance kill        Chaos Monkey Random AWS instance failure
                                        Litmus       Spot instance preemption
                Node failure             Litmus       Hardware failure, AZ outage
                Container OOM kill       Litmus       Memory leak, traffic spike
                CPU stress               Gremlin      Noisy neighbor, runaway job
                Memory pressure          Gremlin      Memory leak, large payload
                Disk fill                Gremlin      Log accumulation, data growth

Network         Latency injection        Gremlin      WAN latency, congested link
                Packet loss              Gremlin      Network instability
                Network partition        Chaos Mesh   AZ split, VPC routing issue
                DNS failure              Gremlin      DNS misconfiguration
                Bandwidth throttle       Gremlin      Saturated network link

Application     HTTP error injection     Istio/Envoy  Upstream returning errors
                HTTP latency injection   Istio/Envoy  Slow upstream dependency
                Process kill             Gremlin      Application crash
                Thread starvation        Custom       Thread pool exhaustion
                Exception injection      ByteBuddy    Code path coverage

State           Database kill            Litmus       Primary DB failure
                Cache eviction           Custom       Redis memory pressure
                Queue backup             Custom       Consumer lag / outage
                Data corruption          Custom       Bit-rot, encoding error
                Replication lag          Custom       DB replication failure

Time            Clock skew               Gremlin      NTP drift, VM migration
                Leap second              Custom       Known periodic risk

External        Third-party API timeout  Gremlin      Stripe, Twilio, AWS API slow
                Third-party API error    Gremlin      Provider outage
                Certificate expiry       Custom       Cert rotation failure
──────────────────────────────────────────────────────────────────────────────
```

---

### 10.6 Staging vs Production Chaos {#106-staging-vs-production}

The staging vs production debate in chaos engineering resolves not to "one or the other" but to "both, with appropriate controls at each level."

```
Staging Chaos
─────────────────────────────────────────────────────────────────────
Advantages:
  → Zero user impact — experiment freely
  → No SLO consumption
  → Can run destructive experiments (full data deletion tests)
  → No approval overhead
  → Ideal for: first runs, new failure types, learning

Limitations:
  → Traffic patterns differ from production
  → Data volume often 1-5% of production
  → Service topology may differ (fewer replicas)
  → Autoscaling behavior may differ
  → Load test traffic is synthetic — misses real user patterns

Best for:
  → Initial experiment design and validation
  → New engineers learning chaos engineering
  → Destructive experiments (DB deletion, full service kill)
  → CI/CD pipeline integration (every merge triggers chaos)
─────────────────────────────────────────────────────────────────────

Production Chaos (with blast radius control)
─────────────────────────────────────────────────────────────────────
Advantages:
  → Tests against real traffic patterns
  → Tests against real data volumes
  → Tests real autoscaling behavior
  → Reveals failure modes that only appear at scale
  → Team practices real incident response during experiment

Limitations:
  → Requires blast radius controls
  → Requires mature SLO monitoring for abort conditions
  → Requires explicit approval process
  → Cannot run purely destructive experiments
  → Mistakes have user impact

Best for:
  → Validating resilience patterns under real load
  → High-confidence experiments that passed staging
  → Continuous chaos (automated, always-on)
  → GameDays with realistic incident response practice
─────────────────────────────────────────────────────────────────────
```

#### Production Chaos Safety Requirements Checklist

```python
def production_chaos_safety_check(
    experiment: ChaosExperiment
) -> dict:
    """
    Validate that a chaos experiment meets all safety requirements
    before execution in production.
    """
    checks = []

    # Check 1: Blast radius bounded
    checks.append({
        "check":   "Blast radius ≤ 10%",
        "result":  experiment.blast_radius_pct <= 10.0,
        "detail":  f"Configured: {experiment.blast_radius_pct}%"
    })

    # Check 2: Steady-state metrics defined
    checks.append({
        "check":   "Steady-state metrics defined",
        "result":  len(experiment.steady_state_metrics) >= 2,
        "detail":  f"{len(experiment.steady_state_metrics)} metrics defined"
    })

    # Check 3: Abort conditions defined
    checks.append({
        "check":   "Abort conditions defined",
        "result":  len(experiment.abort_conditions) >= 2,
        "detail":  f"{len(experiment.abort_conditions)} conditions defined"
    })

    # Check 4: Rollback procedure documented
    checks.append({
        "check":   "Rollback procedure documented",
        "result":  bool(experiment.rollback_procedure.strip()),
        "detail":  "Procedure present" if experiment.rollback_procedure.strip() else "MISSING"
    })

    # Check 5: Experiment approved
    checks.append({
        "check":   "Explicit approval obtained",
        "result":  bool(experiment.approved_by),
        "detail":  f"Approved by: {experiment.approved_by or 'NOT APPROVED'}"
    })

    # Check 6: SLO monitoring active
    checks.append({
        "check":   "SLO monitoring active (verify manually)",
        "result":  True,   # Must be verified by human
        "detail":  "Ensure Grafana SLO dashboard is open during experiment"
    })

    # Check 7: On-call aware
    checks.append({
        "check":   "On-call engineer notified",
        "result":  True,   # Must be verified by human
        "detail":  "On-call must be aware experiment is running"
    })

    # Check 8: Not during peak traffic
    import datetime
    current_hour = datetime.datetime.utcnow().hour
    is_peak = 13 <= current_hour <= 21   # Peak hours UTC
    checks.append({
        "check":   "Not during peak traffic hours",
        "result":  not is_peak,
        "detail":  f"Current UTC hour: {current_hour} (peak: 13-21 UTC)"
    })

    all_passed = all(c["result"] for c in checks)

    return {
        "experiment_id": experiment.id,
        "go_no_go":      "✅ GO" if all_passed else "🔴 NO-GO",
        "checks":        checks,
        "blockers":      [c for c in checks if not c["result"]],
    }
```

---

### 10.7 Tools — Chaos Monkey, Gremlin, and Litmus {#107-tools}

#### Chaos Monkey (Netflix OSS)

Chaos Monkey is the original chaos engineering tool. It randomly terminates EC2 instances and containers during business hours, forcing Netflix engineers to build services that survive arbitrary instance loss.

```yaml
# Chaos Monkey configuration (spinnaker-integrated)
# chaos-monkey-config.yml

simianarmy:
  chaos:
    # Global on/off switch
    enabled: true
    leashed: false      # false = actually terminate instances
                        # true = dry-run mode (log but don't kill)

    # Only run during business hours (not overnight)
    ASG:
      enabled:            true
      probability:        0.1    # 10% chance of termination per hour
      maxTerminations:    1      # Max 1 termination per ASG per day
      allowedHours:       "9-17" # Business hours only
      allowedDays:        "Mon,Tue,Wed,Thu,Fri"

    # Service-specific overrides
    exceptions:
      - account: production
        region:  us-east-1
        stack:   payments-critical   # Exclude payments from random termination
        detail:  ""
        type:    ""
```

**When to use Chaos Monkey:** When you want continuous, random instance termination to ensure your service can handle any single node loss at any time. Best suited for stateless services with N+2 redundancy already proven.

#### Gremlin — Enterprise Chaos Platform

Gremlin provides the most comprehensive commercial chaos engineering platform, with a rich experiment library, fine-grained blast radius control, and enterprise safety features.

```python
# Gremlin Python SDK — programmatic experiment execution
from gremlin_python.clients import GremlinAPIClient
from gremlin_python.attacks import (
    CPUAttack, MemoryAttack, LatencyAttack,
    PacketLossAttack, ShutdownAttack, ContainerKillAttack
)

client = GremlinAPIClient(
    team_id=GREMLIN_TEAM_ID,
    api_key=GREMLIN_API_KEY
)

# Experiment 1: CPU stress on 2 checkout pods for 5 minutes
cpu_attack = CPUAttack(
    length=300,        # 5 minutes
    cores=2,           # Stress 2 CPU cores
    percent=80         # At 80% utilization
)

cpu_target = {
    "type":         "Container",
    "strategy":     {
        "type":         "RandomK8sPodCriteria",
        "k8s_namespace": "production",
        "k8s_labels":   {"app": "checkout"},
        "count":        2   # Affect 2 pods out of N
    }
}

attack_id = client.attacks.create(
    command=cpu_attack,
    target=cpu_target
)
print(f"Attack started: {attack_id}")

# Monitor and abort if needed
import time
for i in range(30):   # Check every 10s for 5 minutes
    time.sleep(10)
    attack = client.attacks.get(attack_id)
    if attack["status"] == "Finished":
        print("Attack completed normally")
        break
    # Check abort conditions here
    # If violated: client.attacks.stop(attack_id)


# Experiment 2: Network latency injection
latency_attack = LatencyAttack(
    length=300,
    delay=100,         # 100ms added latency
    jitter=25,         # ±25ms jitter
    hostnames=["inventory-service.production.svc.cluster.local"]
)

# Experiment 3: Packet loss
packet_loss_attack = PacketLossAttack(
    length=180,
    percent=20,        # 20% packet loss
    hostnames=["payment-service.production.svc.cluster.local"]
)
```

**Gremlin Scenarios — Multi-Step Experiments:**

```python
# Gremlin Scenarios allow sequencing multiple attacks
# This scenario tests the full cascade failure path

scenario = {
    "name": "Payment cascade resilience",
    "description": "Test checkout resilience through payment degradation",
    "hypothesis": "Checkout maintains <0.1% errors during payment latency",
    "steps": [
        {
            "delay": 0,
            "attack": {
                "type": "latency",
                "args": {
                    "delay":     200,    # 200ms latency
                    "hostnames": ["payment-service.production.svc"],
                    "length":    300
                }
            }
        },
        {
            "delay": 60,   # After 60 seconds, also inject errors
            "attack": {
                "type": "blackhole",
                "args": {
                    "hostnames": ["payment-service.production.svc"],
                    "length":    60     # 60-second total blackhole
                }
            }
        }
    ]
}
```

#### Litmus — Kubernetes-Native Chaos

LitmusChaos is the CNCF chaos engineering tool built natively for Kubernetes. Experiments are defined as Kubernetes CRDs, run as Kubernetes Jobs, and integrate naturally with GitOps workflows.

```yaml
# LitmusChaos: Pod Kill experiment
# Kills a random checkout pod every 60 seconds for 5 minutes
# Tests: does HPA replace it? Does traffic shift cleanly?

apiVersion: litmuschaos.io/v1alpha1
kind: ChaosEngine
metadata:
  name: checkout-pod-kill
  namespace: production
spec:
  appinfo:
    appns:    production
    applabel: "app=checkout"
    appkind:  deployment

  # What to do before/after the experiment
  jobCleanUpPolicy: delete

  # Monitoring integration
  monitoring: true
  components:
    runner:
      image: litmuschaos/chaos-runner:latest

  experiments:
    - name: pod-kill
      spec:
        components:
          env:
            - name:  TOTAL_CHAOS_DURATION
              value: "300"          # 5 minutes total
            - name:  CHAOS_INTERVAL
              value: "60"           # Kill a pod every 60 seconds
            - name:  FORCE
              value: "false"        # Graceful termination
            - name:  PODS_AFFECTED_PERC
              value: "20"           # 20% of pods affected (1 in 5)
            - name:  RAMP_TIME
              value: "30"           # 30s before starting (measure baseline)

  # Steady-state probes: abort if these fail
  probes:
    - name: checkout-availability-probe
      type: promProbe
      mode: Continuous
      runProperties:
        probeTimeout: 10
        interval:     10
        retry:        3
        probePollingInterval: 5
      promProbe/inputs:
        endpoint:   http://prometheus:9090
        query: |
          sum(rate(http_requests_total{
            service="checkout",
            status_code!~"5.."
          }[1m])) /
          sum(rate(http_requests_total{
            service="checkout"
          }[1m]))
        comparator:
          type:     float
          criteria: ">="
          value:    "0.999"   # Abort if availability drops below 99.9%
```

```yaml
# LitmusChaos: Network chaos — latency injection between services
apiVersion: litmuschaos.io/v1alpha1
kind: ChaosEngine
metadata:
  name: inventory-network-latency
  namespace: production
spec:
  appinfo:
    appns:    production
    applabel: "app=inventory-service"
    appkind:  deployment
  experiments:
    - name: pod-network-latency
      spec:
        components:
          env:
            - name:  TOTAL_CHAOS_DURATION
              value: "600"      # 10 minutes
            - name:  NETWORK_LATENCY
              value: "200"      # 200ms additional latency
            - name:  JITTER
              value: "50"       # ±50ms jitter
            - name:  CONTAINER_RUNTIME
              value: containerd
            - name:  SOCKET_PATH
              value: /run/containerd/containerd.sock
            - name:  PODS_AFFECTED_PERC
              value: "100"      # All inventory pods (contained blast radius via traffic routing)
  probes:
    - name: checkout-slo-probe
      type: promProbe
      mode: Continuous
      promProbe/inputs:
        endpoint: http://prometheus:9090
        query: |
          histogram_quantile(0.99,
            sum(rate(http_request_duration_seconds_bucket{
              service="checkout"
            }[1m])) by (le)
          ) * 1000
        comparator:
          type:     float
          criteria: "<="
          value:    "500"   # Abort if checkout P99 exceeds 500ms
```

#### Tool Selection Guide

```
Tool Comparison
──────────────────────────────────────────────────────────────────────
Dimension         Chaos Monkey     Gremlin          Litmus
──────────────────────────────────────────────────────────────────────
Cost              Free (OSS)       $$$              Free (CNCF)
Setup complexity  Medium           Low (SaaS)       Medium
Failure types     Instance kill    30+ types        20+ K8s types
Blast radius ctrl Basic            Excellent        Good
Kubernetes native No               Yes              Yes (native)
Production safety Basic            Enterprise-grade Good
CI/CD integration Limited          Good             Excellent
Reporting         Basic            Dashboard        Grafana integration
Learning curve    Low              Low              Medium
Best for          Random instance  Enterprise,      Kubernetes-first,
                  termination,     multi-failure    GitOps teams
                  Netflix-style    scenarios
──────────────────────────────────────────────────────────────────────
```

---

### 10.8 GameDays — Structured Chaos Exercises {#108-gamedays}

A **GameDay** is a scheduled, team-wide chaos exercise designed to simulate a realistic production failure scenario. Unlike automated experiments that run quietly in the background, a GameDay is an active, collaborative exercise that simultaneously tests system resilience AND team response capability.

The term comes from American football, where "game day" is when everything practiced in training is executed under real pressure. Similarly, a GameDay tests whether the systems *and* the people can perform under realistic failure conditions.

#### GameDay Structure

```
GameDay Structure — Full Day Exercise
──────────────────────────────────────────────────────────────────────
Phase 1: Preparation (1 week before)
  → Select scenario: realistic failure mode from risk register
  → Brief engineers: scenario exists but NOT which specific failure
    will be injected or when
  → Verify blast radius controls are in place
  → Assign roles: facilitator (runs failure injection), observers
    (SRE leadership watching response), responders (on-call team)
  → Ensure runbooks are up to date
  → Schedule 4-hour window; notify stakeholders

Phase 2: Baseline (30 minutes before)
  → Verify all monitoring is healthy
  → Confirm SLO dashboards are visible
  → Brief responders: "We are running a GameDay today.
    At some point in the next 3 hours, we will inject a failure.
    Respond as you would to a real incident."
  → Start scribe log

Phase 3: Injection (T+0 to T+scenario end)
  → Facilitator injects failure at random time (within window)
  → Responders must detect, triage, and respond as normal
  → Observers watch without intervening
  → Abort if blast radius controls indicate user impact

Phase 4: Debrief (1 hour post-injection)
  → Timeline review: what happened, when, by whom?
  → What was detected? What was missed?
  → Where did response go well? Where did it struggle?
  → Runbook gaps identified?
  → Action items captured

Phase 5: Post-GameDay (48 hours)
  → Written GameDay report
  → Action items tracked
  → Update runbooks based on findings
  → Risk register updated
──────────────────────────────────────────────────────────────────────
```

#### GameDay Scenario Library

```python
from dataclasses import dataclass
from typing import List

@dataclass
class GameDayScenario:
    name:             str
    narrative:        str          # Story context for the exercise
    failure_injection: str         # What is actually injected
    target:           str
    duration_min:     int
    difficulty:       str          # beginner | intermediate | advanced
    skills_tested:    List[str]
    success_criteria: List[str]
    common_failure_modes: List[str]  # What teams typically struggle with

SCENARIO_LIBRARY = [
    GameDayScenario(
        name="Silent Dependency Death",
        narrative=(
            "It's Tuesday at 2pm. Traffic is normal. Nothing looks wrong. "
            "But users are starting to see empty search results — not errors, "
            "just empty. The search service is returning 200 OK with zero results."
        ),
        failure_injection="product-catalog service returning empty response body with 200 OK",
        target="product-catalog service",
        duration_min=60,
        difficulty="intermediate",
        skills_tested=[
            "Detecting silent failures (no error rate spike)",
            "Quality SLI measurement (correctness, not just availability)",
            "Distinguishing client-side from server-side empty results",
        ],
        success_criteria=[
            "Team detects within 15 minutes (synthetic monitor should catch)",
            "Team identifies catalog dependency as root cause",
            "Circuit breaker or fallback activated to show cached results",
        ],
        common_failure_modes=[
            "Team only monitors HTTP status codes — 200 OK masks the failure",
            "No quality SLI for 'search returns results' — failure is invisible",
            "Team checks checkout and payment before search dependency",
        ]
    ),
    GameDayScenario(
        name="The Slow Cascade",
        narrative=(
            "9am Monday. Traffic ramps up to business hours peak. "
            "Checkout latency is creeping upward — P99 was 150ms, now 280ms, "
            "now 420ms. Not erroring yet. But it's getting worse every 5 minutes."
        ),
        failure_injection="database connection pool gradually filling (simulated via thread starvation)",
        target="checkout-db connection pool",
        duration_min=45,
        difficulty="advanced",
        skills_tested=[
            "Detecting gradual degradation (not sudden spike)",
            "Identifying saturation as a leading indicator",
            "Acting before errors appear (proactive vs reactive)",
        ],
        success_criteria=[
            "Team detects latency trend before errors begin",
            "Team identifies DB connection pool as saturation cause",
            "Team takes action (kill idle connections, scale out) before SLO breached",
        ],
        common_failure_modes=[
            "Waiting for errors to spike before acting (SLO already burning)",
            "Scaling compute when DB is the bottleneck",
            "Not monitoring connection pool utilization",
        ]
    ),
    GameDayScenario(
        name="The AZ Split",
        narrative=(
            "Your Kubernetes cluster spans 3 availability zones. "
            "At 11pm, us-east-1b stops routing traffic to other AZs. "
            "30% of your pods can't reach the database. "
            "Error rate is 30%. Is this an outage or a split-brain?"
        ),
        failure_injection="network partition between us-east-1b and other AZs",
        target="kubernetes node network",
        duration_min=90,
        difficulty="advanced",
        skills_tested=[
            "Network partition diagnosis",
            "Split-brain detection and mitigation",
            "Multi-AZ traffic rerouting",
            "Communicating under ambiguity",
        ],
        success_criteria=[
            "Team identifies network partition within 20 minutes",
            "Traffic redirected away from affected AZ",
            "Root cause (AZ isolation) vs symptom (DB unreachable) distinction made",
            "Executive communication appropriate to ambiguity level",
        ],
        common_failure_modes=[
            "Treating it as an application bug rather than network issue",
            "Rolling back healthy deployments (no deployment was the cause)",
            "Not checking cross-AZ connectivity as first diagnostic step",
        ]
    ),
    GameDayScenario(
        name="The Thundering Herd",
        narrative=(
            "Marketing just sent an email to 2M users. "
            "1.4M click the link simultaneously. "
            "Your cache is cold (Redis was restarted 10 minutes ago). "
            "Every request is hitting the database."
        ),
        failure_injection="Redis cache clear + traffic spike simulation (k6 10×)",
        target="Redis cache layer",
        duration_min=30,
        difficulty="beginner",
        skills_tested=[
            "Cache stampede recognition",
            "Database protection under cache failure",
            "Traffic throttling and rate limiting",
        ],
        success_criteria=[
            "Team recognizes cache miss storm within 5 minutes",
            "Database protection activated (rate limiting, circuit breaker)",
            "Cache warming initiated",
        ],
        common_failure_modes=[
            "Scaling out app servers (doesn't help when DB is the bottleneck)",
            "Not having a DB rate limit / circuit breaker in place",
        ]
    ),
]

def select_gameday_scenario(
    team_maturity: str,   # beginner | intermediate | advanced
    recent_incidents: List[str],   # Recent incident types to avoid repeating trivially
    risk_register_top_risks: List[str]
) -> GameDayScenario:
    """
    Select the most valuable GameDay scenario for a given team.
    Prioritizes scenarios that match risk register items.
    """
    candidates = [
        s for s in SCENARIO_LIBRARY
        if s.difficulty == team_maturity
    ]

    # Prefer scenarios that test risk register items
    for scenario in candidates:
        if any(risk.lower() in scenario.failure_injection.lower()
               for risk in risk_register_top_risks):
            return scenario

    return candidates[0] if candidates else SCENARIO_LIBRARY[0]
```

#### GameDay Report Template

```markdown
# GameDay Report: [Scenario Name]
**Date:**        [Date]
**Duration:**    [Start] → [End]
**Facilitator:** [Name]
**Observers:**   [Names]
**Responders:**  [Names — the on-call team]

---

## Scenario
[Brief scenario description. What failure was injected, when, against what.]

## Hypothesis
[What was the team expected to do? What steady-state was expected?]

## Timeline of Events
| Time | Event | Who |
|------|-------|-----|
| T+00:00 | Failure injected: [description] | Facilitator |
| T+08:32 | First alert fired: [alert name] | Prometheus |
| T+09:15 | On-call acknowledged | @sarah |
| T+12:00 | SEV2 declared; war room opened | @sarah (IC) |
| ... | | |

## What Went Well
- [Positive observations]

## What Needs Improvement
- [Gaps identified]

## Surprises (What Was Not Expected)
- [Failure modes that appeared unexpectedly]
- [Monitoring gaps revealed]
- [Runbook inaccuracies found]

## Action Items
| Action | Owner | Priority | Due Date |
|--------|-------|----------|----------|
| Fix runbook step 3 (incorrect command) | @alice | P1 | [date] |
| Add quality SLI for search results count | @bob | P1 | [date] |

## Risk Register Updates
- [New risks identified during the exercise]
- [Existing risks confirmed or reclassified]
```

---

### 10.9 Building a Chaos Culture {#109-chaos-culture}

A chaos engineering program is only as effective as the culture that sustains it. Technical tooling without cultural adoption produces sporadic experiments, organizational resistance, and abandoned programs.

#### The Chaos Maturity Journey

```
Chaos Engineering Maturity Levels
──────────────────────────────────────────────────────────────────────
Level 0: No chaos engineering
  → Failure modes discovered via production incidents
  → Team has not heard of chaos engineering or dismisses it
  → Reliability tested only by production traffic

Level 1: Experimental (1-2 engineers exploring)
  → A few engineers run ad-hoc chaos experiments in staging
  → No standard process; no team buy-in
  → Findings rarely acted upon
  → "We tried it once" stage

Level 2: Tactical (team-level adoption)
  → Chaos experiments run as part of release validation
  → Standard experiment templates and hypothesis framework in use
  → GameDays run quarterly
  → Findings tracked in risk register
  → SRE team owns chaos program

Level 3: Strategic (organizational practice)
  → Chaos integrated into CI/CD pipeline (continuous chaos)
  → Multiple teams running experiments independently
  → Production chaos with blast radius controls
  → Post-mortem action items include chaos validation
  → Leadership understands and supports the investment

Level 4: Advanced (Netflix/Google-style)
  → Continuous chaos on production at scale
  → Automated hypothesis generation from monitoring data
  → Chaos results feed directly into SLO management
  → Chaos findings prevent incidents before they occur
  → All new services chaos-tested before launch (PRR requirement)
──────────────────────────────────────────────────────────────────────
```

#### Overcoming Organizational Resistance

```python
RESISTANCE_PATTERNS = {
    "We'll break production": {
        "concern": "Fear of chaos engineering causing incidents",
        "response": [
            "Start in staging. No production chaos until staging passes.",
            "Show blast radius controls — we affect 1% of traffic max.",
            "Present the alternative: discovering this failure mode via a real incident at full scale.",
            "Walk through the abort conditions. The experiment stops automatically if anything goes wrong.",
        ]
    },
    "We don't have time": {
        "concern": "Chaos experiments compete with feature work",
        "response": [
            "A 2-hour chaos experiment prevents a 4-hour incident.",
            "Frame as incident prevention, not extra work.",
            "Start with 1 GameDay per quarter — 4 hours every 3 months.",
            "Show the incident cost data: last 6 months, $X in incidents. Chaos budget: $Y.",
        ]
    },
    "Our system is too complex": {
        "concern": "System is too interconnected for controlled experiments",
        "response": [
            "Complex systems benefit most from chaos — they have the most unknown failure modes.",
            "Start with the simplest experiment: kill one pod and verify HPA replaces it.",
            "Build complexity gradually as team confidence grows.",
        ]
    },
    "We're not Netflix": {
        "concern": "Chaos engineering is only for hyperscale organizations",
        "response": [
            "Netflix invented the tooling. The practice applies to any system with SLOs.",
            "Your 99.9% SLO needs the same failure mode validation as Netflix's 99.99%.",
            "The tools (Litmus, Gremlin) are accessible to teams of any size.",
        ]
    },
    "What if our SLO gets consumed": {
        "concern": "Chaos experiments will burn error budget",
        "response": [
            "With blast radius controls, experiments should not consume measurable budget.",
            "Budget consumption during a chaos experiment is the fastest possible validation.",
            "An experiment that burns 1% of budget discovered a failure mode that would have burned 100% via a real incident.",
        ]
    },
}

def generate_objection_response(objection: str) -> str:
    for key, pattern in RESISTANCE_PATTERNS.items():
        if objection.lower() in key.lower() or key.lower() in objection.lower():
            response = f"Concern: {pattern['concern']}\n\nResponse:\n"
            response += "\n".join(f"  • {r}" for r in pattern["response"])
            return response
    return "Specific objection not in library. Focus on: 'what is the cost of NOT knowing this failure mode?'"
```

#### The Chaos Engineering Charter

```markdown
# Chaos Engineering Charter — [Team/Organization Name]

## Purpose
We practice chaos engineering to discover failure modes in our systems
before they are discovered by users. We believe that the reliability
of our systems is only knowable through experimentation, not assumption.

## Principles
1. **Hypothesis-driven.** Every experiment begins with a written hypothesis
   and measurable success criteria. We do not inject failures to "see what happens."

2. **Blast radius bounded.** Every production experiment is bounded to
   ≤10% of traffic. Every experiment has defined abort conditions.

3. **Blameless.** Findings from chaos experiments, like findings from
   post-mortems, are system findings — not people findings. An experiment
   that reveals a gap is a success, not a failure.

4. **Action-oriented.** Findings without action items are observations.
   Every experiment produces at least one action item before it is closed.

5. **Progressive.** We run experiments at the smallest blast radius that
   produces meaningful signal. We expand scope only after smaller scopes pass.

## Process
- Experiments require design review + approval before production execution
- Staging experiments require no approval
- All experiments documented in [link]
- GameDays scheduled quarterly; all engineers participate
- Findings feed into risk register and PRR checklist

## Authority
- Staging chaos: any SRE may run without approval
- Production chaos (≤5%): SRE lead approval
- Production chaos (5-10%): Engineering VP approval
- Production chaos (>10%): Reserved; requires documented justification
```

---

### 10.10 Chaos Experiment Automation {#1010-automation}

Manual chaos experiments are valuable but limited. Continuous chaos — experiments that run automatically as part of the CI/CD pipeline or on a recurring schedule — provides ongoing resilience validation and regression detection.

```yaml
# GitHub Actions: chaos experiment in staging on every merge to main
# Tests pod kill resilience before deploying to production

name: Chaos Validation Gate

on:
  push:
    branches: [main]

jobs:
  deploy-staging:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Deploy to staging
        run: ./scripts/deploy.sh staging

  chaos-validation:
    needs: deploy-staging
    runs-on: ubuntu-latest
    steps:
      - name: Wait for staging to stabilize
        run: sleep 120

      - name: Run pod kill chaos experiment
        env:
          LITMUS_URL: ${{ secrets.LITMUS_STAGING_URL }}
        run: |
          # Apply chaos experiment
          kubectl apply -f chaos/staging/pod-kill-experiment.yaml \
            --kubeconfig=${{ secrets.STAGING_KUBECONFIG }}

          # Wait for experiment to complete
          kubectl wait chaosengine checkout-pod-kill \
            --for=condition=Completed \
            --timeout=600s \
            --namespace staging \
            --kubeconfig=${{ secrets.STAGING_KUBECONFIG }}

      - name: Check chaos results
        run: |
          # Get experiment results
          RESULT=$(kubectl get chaosresult checkout-pod-kill-pod-kill \
            -o jsonpath='{.status.experimentStatus.verdict}' \
            --namespace staging \
            --kubeconfig=${{ secrets.STAGING_KUBECONFIG }})

          echo "Chaos experiment result: $RESULT"

          if [ "$RESULT" != "Pass" ]; then
            echo "❌ Chaos experiment FAILED: $RESULT"
            echo "The service did not maintain steady-state during pod kill."
            echo "Blocking deployment to production."
            exit 1
          fi
          echo "✅ Chaos validation passed. Service resilient to pod kill."

  deploy-production:
    needs: chaos-validation
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to production (canary)
        run: ./scripts/deploy.sh production --strategy canary --weight 5
```

#### Continuous Chaos Scheduler

```python
#!/usr/bin/env python3
"""
chaos_scheduler.py — Continuous chaos experiment runner
Runs a rotating set of chaos experiments on a schedule,
ensuring resilience is continuously validated.
"""

import schedule
import time
import logging
import subprocess
import json
from datetime import datetime

logger = logging.getLogger(__name__)

# Experiment catalog — runs on rotating schedule
EXPERIMENTS = [
    {
        "name":     "checkout-pod-kill",
        "schedule": "every monday at 14:00",    # Business hours
        "environment": "production-canary",
        "tool":     "litmus",
        "spec":     "chaos/production/pod-kill.yaml",
        "blast_radius_pct": 5.0,
    },
    {
        "name":     "inventory-latency",
        "schedule": "every wednesday at 15:00",
        "environment": "production-canary",
        "tool":     "gremlin",
        "attack_type": "latency",
        "params":   {"delay": 100, "hostnames": ["inventory-service.production.svc"]},
        "blast_radius_pct": 10.0,
    },
    {
        "name":     "payment-dependency-failure",
        "schedule": "every friday at 11:00",
        "environment": "staging",
        "tool":     "litmus",
        "spec":     "chaos/staging/payment-http-error.yaml",
        "blast_radius_pct": 100.0,   # Staging: full blast
    },
]

def should_run_today(experiment: dict) -> bool:
    """Check if today is a valid day to run this experiment."""
    # Don't run during peak traffic hours (real production)
    current_hour = datetime.utcnow().hour
    if experiment["environment"] != "staging" and 13 <= current_hour <= 21:
        logger.info(f"Skipping {experiment['name']}: peak traffic hours")
        return False

    # Don't run during known maintenance windows
    # (Load from a maintenance calendar or config)
    return True

def run_litmus_experiment(experiment: dict) -> bool:
    """Execute a LitmusChaos experiment and return pass/fail."""
    try:
        # Apply the chaos engine
        subprocess.run(
            ["kubectl", "apply", "-f", experiment["spec"],
             "-n", "production"],
            check=True, timeout=30
        )

        # Wait for completion
        result = subprocess.run(
            ["kubectl", "wait", "chaosengine",
             experiment["name"],
             "--for=condition=Completed",
             "--timeout=700s",
             "-n", "production"],
            capture_output=True, text=True, timeout=720
        )

        if result.returncode != 0:
            logger.error(f"Experiment {experiment['name']} timed out")
            return False

        # Get result
        verdict = subprocess.check_output([
            "kubectl", "get", "chaosresult",
            f"{experiment['name']}-pod-kill",
            "-o", "jsonpath={.status.experimentStatus.verdict}",
            "-n", "production"
        ]).decode().strip()

        passed = verdict == "Pass"
        logger.info(
            f"Experiment {experiment['name']}: {verdict}",
            extra={"experiment": experiment["name"], "result": verdict}
        )
        return passed

    except Exception as e:
        logger.error(f"Failed to run experiment {experiment['name']}: {e}")
        return False

def on_experiment_failure(experiment: dict) -> None:
    """Handle a failed chaos experiment — alert and create ticket."""
    message = (
        f"🔴 Chaos experiment FAILED: `{experiment['name']}`\n"
        f"Environment: {experiment['environment']}\n"
        f"This indicates a resilience regression. "
        f"The service does not handle this failure mode correctly.\n"
        f"Action required: investigate and fix before next deployment."
    )
    # Post to Slack
    import requests, os
    requests.post(os.environ["SLACK_SRE_WEBHOOK"], json={"text": message})
    logger.error(f"CHAOS FAILURE ALERT: {experiment['name']}")
    # In production: also create a Jira ticket automatically

def run_scheduled_experiment(experiment: dict) -> None:
    if not should_run_today(experiment):
        return
    logger.info(f"Running chaos experiment: {experiment['name']}")
    passed = run_litmus_experiment(experiment)
    if not passed:
        on_experiment_failure(experiment)

# Schedule experiments
for exp in EXPERIMENTS:
    schedule.every().monday.at("14:00").do(
        run_scheduled_experiment, exp
    ) if "monday" in exp["schedule"] else None
    schedule.every().wednesday.at("15:00").do(
        run_scheduled_experiment, exp
    ) if "wednesday" in exp["schedule"] else None
    schedule.every().friday.at("11:00").do(
        run_scheduled_experiment, exp
    ) if "friday" in exp["schedule"] else None

if __name__ == "__main__":
    logger.info("Chaos scheduler started")
    while True:
        schedule.run_pending()
        time.sleep(60)
```

---

### 10.11 Measuring Chaos Engineering Maturity {#1011-maturity}

```python
def assess_chaos_maturity(
    experiments_last_quarter:    int,
    production_experiments:      int,
    staging_experiments:         int,
    gamedays_last_year:          int,
    findings_with_action_items:  int,
    total_findings:              int,
    continuous_chaos_enabled:    bool,
    failure_types_covered:       int,   # Out of 20 in taxonomy
    services_with_chaos_tests:   int,
    total_services:              int,
) -> dict:
    """
    Assess chaos engineering program maturity against
    a 0-100 scoring rubric.
    """
    score = 0

    # Experiment volume (30 points)
    if experiments_last_quarter >= 20:   score += 30
    elif experiments_last_quarter >= 10: score += 20
    elif experiments_last_quarter >= 5:  score += 10
    elif experiments_last_quarter >= 1:  score += 5

    # Production chaos presence (20 points)
    prod_ratio = production_experiments / max(experiments_last_quarter, 1)
    if prod_ratio >= 0.50:    score += 20
    elif prod_ratio >= 0.25:  score += 12
    elif prod_ratio >= 0.10:  score += 6

    # GameDay frequency (15 points)
    if gamedays_last_year >= 4:   score += 15
    elif gamedays_last_year >= 2: score += 10
    elif gamedays_last_year >= 1: score += 5

    # Action item follow-through (15 points)
    action_rate = findings_with_action_items / max(total_findings, 1)
    if action_rate >= 0.90:   score += 15
    elif action_rate >= 0.75: score += 10
    elif action_rate >= 0.50: score += 5

    # Automation (10 points)
    score += 10 if continuous_chaos_enabled else 0

    # Coverage breadth (10 points)
    type_coverage = failure_types_covered / 20
    service_coverage = services_with_chaos_tests / max(total_services, 1)
    score += int(10 * min(type_coverage, service_coverage))

    level = (
        "Level 4 — Advanced"    if score >= 85 else
        "Level 3 — Strategic"   if score >= 65 else
        "Level 2 — Tactical"    if score >= 40 else
        "Level 1 — Experimental" if score >= 15 else
        "Level 0 — Pre-Chaos"
    )

    return {
        "score":                    score,
        "maturity_level":           level,
        "experiments_per_quarter":  experiments_last_quarter,
        "production_ratio":         f"{prod_ratio:.0%}",
        "gamedays_per_year":        gamedays_last_year,
        "action_item_rate":         f"{action_rate:.0%}",
        "failure_type_coverage":    f"{failure_types_covered}/20",
        "service_coverage":         f"{services_with_chaos_tests}/{total_services}",
        "continuous_chaos":         "Enabled" if continuous_chaos_enabled else "Not yet",
        "top_improvement":          _top_improvement(
            score, prod_ratio, gamedays_last_year,
            action_rate, continuous_chaos_enabled
        )
    }

def _top_improvement(score, prod_ratio, gamedays, action_rate, continuous) -> str:
    if score < 15:
        return "Run your first chaos experiment in staging this week."
    if gamedays < 1:
        return "Schedule a GameDay — highest impact for team resilience."
    if not continuous:
        return "Integrate chaos into CI/CD — catches regressions automatically."
    if prod_ratio < 0.1:
        return "Move experiments to production with blast radius controls."
    if action_rate < 0.75:
        return "Improve action item tracking — findings without fixes are wasted."
    return "Expand failure type coverage and service coverage."
```

---

## Key Principles & Best Practices {#key-principles}

1. **Hypothesis first, failure second.** A chaos experiment without a steady-state hypothesis is random destruction. Define measurable success criteria before touching anything.

2. **Minimize blast radius, maximize learning.** The smallest blast radius that produces meaningful signal is the right blast radius. Starting at 1% and expanding is always safer than starting at 50%.

3. **Abort conditions are non-negotiable.** Every experiment must have at least two abort conditions with automated monitoring. An experiment that runs to completion regardless of system health is not chaos engineering — it is chaos.

4. **Staging results do not guarantee production results.** Staging traffic is synthetic, data volumes are wrong, and topology differs. Staging experiments reduce risk; production experiments (with blast radius controls) validate reality.

5. **Chaos findings without action items are observations.** The point of chaos engineering is to improve resilience, not to document it. Every experiment finding needs a Jira ticket before the experiment report is published.

6. **GameDays test people, not just systems.** The best GameDay scenario is one where the system reveals a failure mode the team didn't expect — because the team's response to that surprise is what you're actually testing.

7. **Continuous chaos prevents resilience regression.** A single GameDay tells you the system was resilient on that day. Continuous automated chaos tells you whether it remained resilient through all subsequent deployments.

---

## Tools & Technologies {#tools}

| Tool | Category | Use Case |
|---|---|---|
| **Chaos Monkey** | Instance termination | Random EC2/container kill for Netflix-style resilience |
| **Gremlin** | Enterprise chaos | Multi-failure-type experiments with safety controls |
| **LitmusChaos** | Kubernetes chaos | GitOps-native K8s chaos with Prometheus probes |
| **Chaos Mesh** | Kubernetes chaos | Network chaos, pod failure, Kubernetes-native CRDs |
| **Istio fault injection** | Service mesh chaos | HTTP error/latency injection at traffic level |
| **Toxiproxy** | Network proxy chaos | TCP-level latency, packet loss, connection disruption |
| **Pumba** | Container chaos | Docker-native container disruption |
| **AWS Fault Injection Simulator (FIS)** | Cloud chaos | Native AWS infrastructure failure injection |
| **Azure Chaos Studio** | Cloud chaos | Azure-native chaos experiments |
| **Chaos Toolkit** | OSS framework | Extensible, language-agnostic chaos experiment framework |

---

## Hands-on Exercises / Labs {#labs}

### Lab 10.1 — Hypothesis Design Workshop

**Goal:** Write rigorous chaos experiment hypotheses from first principles.

**Context:** You are the SRE for an e-commerce platform. The risk register contains these items: (1) checkout has no circuit breaker on payment dependency, (2) search service has a single Redis cache with no fallback, (3) the platform has never tested AZ failure recovery.

**Tasks:**
1. For each risk register item, write a chaos experiment hypothesis using the structure: "We believe that [service] will maintain [metric(s)] within [range] when [failure] is applied to [scope]."
2. For each hypothesis, define exactly three steady-state metrics with specific PromQL expressions and threshold values.
3. For each experiment, define three abort conditions with specific, measurable trigger criteria.
4. Validate each experiment using the `ChaosExperiment.validate()` logic. What would it flag?
5. Order the experiments in the sequence you would run them. Justify the ordering (which needs to pass before the next begins? Which requires production vs staging?).

---

### Lab 10.2 — Litmus Chaos Experiment Implementation

**Goal:** Implement and interpret a complete LitmusChaos experiment for a Kubernetes service.

**Scenario:** You want to validate that the checkout service maintains its SLO when any single pod is killed.

**Tasks:**
1. Write the complete `ChaosEngine` YAML for a pod-kill experiment on the checkout deployment. Include:
   - Appropriate `PODS_AFFECTED_PERC` (how many pods should be killed at once?)
   - A `RAMP_TIME` that gives you a clean baseline measurement
   - A `promProbe` that validates error rate remains below 0.1% throughout
   - A `promProbe` that validates P99 latency remains below 300ms
2. Write the `ChaosResult` query command to check pass/fail after the experiment.
3. Interpret these three possible results and describe what each means technically:
   - Result: `Pass` — but latency spiked to 285ms during pod kill
   - Result: `Fail` — error rate hit 2% for 45 seconds after kill
   - Result: `Fail` — promProbe returned "metric not found" (Prometheus query error)
4. Write the GitHub Actions step that runs this experiment in staging as a deployment gate.
5. Based on a `Fail` result, write the post-experiment action item set (3-5 items) and risk register entry.

---

### Lab 10.3 — GameDay Design and Facilitation

**Goal:** Design a complete GameDay exercise for a team at Chaos Maturity Level 1.

**Context:** Your team of 8 engineers has never run a GameDay. They are competent at incident response but have never deliberately tested their systems under failure. They support: checkout, payment, search, and user auth. The highest-priority risk register item is: "checkout has no fallback when inventory service is unavailable."

**Tasks:**
1. Choose the appropriate scenario from the `SCENARIO_LIBRARY` or design a custom scenario. Justify your choice.
2. Write the complete GameDay brief (narrative, failure injection specification, success criteria, common failure modes to watch for).
3. Design the GameDay schedule: what happens in the 1 week before, the 30-minute preparation window, the exercise itself, and the debrief?
4. Write the facilitator script for the debrief: what questions do you ask, in what order, to maximize learning without blame?
5. After the exercise, the team discovered: (a) no alert exists for empty checkout responses when inventory is down, (b) the runbook doesn't mention the inventory dependency, (c) the team correctly identified the issue in 12 minutes but took 28 minutes to decide to enable degraded mode. Write the action items and GameDay report sections for each finding.

---

### Lab 10.4 — Chaos Maturity Assessment and Roadmap

**Goal:** Assess a team's chaos engineering maturity and build a 6-month improvement roadmap.

**Given team profile:**
```
Experiments last quarter:   3 (all in staging)
Production experiments:     0
GameDays last year:         0
Findings with action items: 2 out of 3 (67%)
Continuous chaos:           No
Failure types covered:      3 out of 20
Services with chaos tests:  2 out of 8
```

**Tasks:**
1. Run `assess_chaos_maturity()` with this data. What is the maturity score and level?
2. Identify the top 3 improvement opportunities based on the scoring rubric.
3. Build a 6-month roadmap:
   - Month 1-2: What specific experiments will you add? To which services?
   - Month 3-4: When will you run the first GameDay? On which scenario?
   - Month 5-6: How will you move toward production chaos and continuous automation?
4. For each roadmap milestone, define a success metric (how will you know it's done?).
5. Write the "Chaos Engineering Investment Proposal" for your engineering director: current state, 6-month plan, expected outcomes, resource requirements (people and time), and ROI framing (what incidents does this prevent?).

---

## Common Pitfalls & Anti-patterns {#pitfalls}

**Anti-pattern 1: Chaos without hypothesis**
A team installs Gremlin and starts injecting failures with enthusiasm. Latency here, pod kills there. Something fails spectacularly. The team isn't sure if the failure was expected or a new finding. There are no pass/fail criteria. The experiment is inconclusive. *Fix:* Never run an experiment without a written hypothesis and steady-state metrics. The hypothesis is not bureaucracy — it is what transforms random destruction into scientific learning.

**Anti-pattern 2: Chaos theater**
A team runs monthly chaos experiments that always pass. Leadership is impressed. But the experiments are designed to pass — they test failure modes already known to be handled. Novel failure modes are never tested. *Fix:* Chaos experiments should occasionally fail. A program where every experiment passes is either testing too easy scenarios or the system is genuinely resilient (verify with increasingly difficult scenarios). Calibrate toward finding real gaps.

**Anti-pattern 3: Production chaos without preparation**
An enthusiastic engineer reads the Principles of Chaos Engineering and runs a node kill in production at 3pm on a Friday. The service goes down for 45 minutes. The team is blamed. Chaos engineering is banned. *Fix:* Production chaos requires: staging experiments that pass, blast radius controls, abort conditions, on-call awareness, explicit approval, and off-peak execution. The principles say "run in production" — not "run in production without preparation."

**Anti-pattern 4: GameDay as performance review**
Management watches the GameDay specifically to evaluate which engineers responded quickly and which made mistakes. Engineers perform for the audience rather than responding naturally. The results are not representative of real incident performance. *Fix:* GameDay is a learning exercise, not an evaluation. Leaders observe to learn about system gaps, not to assess individual performance. Make this explicit in the GameDay charter and observer guidelines.

**Anti-pattern 5: Chaos findings with no follow-through**
The team runs a GameDay. Twelve findings are documented. Two action items are created. The rest are discussed briefly and forgotten. In 6 months, when a real incident occurs with the same failure mode, the GameDay report is found in Confluence. *Fix:* Every finding from every chaos experiment must have a ticket before the experiment is marked complete. Apply the same 80% completion rate target as post-mortem action items.

**Anti-pattern 6: Mistaking chaos engineering for load testing**
"We ran a chaos test — we sent 10× traffic and watched the system struggle." Load testing and chaos engineering both stress systems but answer different questions: load testing asks "can this handle expected demand?" Chaos engineering asks "does this handle unexpected failure modes?" *Fix:* Use load testing (k6, Gatling) for capacity validation. Use chaos engineering (Litmus, Gremlin) for resilience validation. Both are necessary; neither substitutes for the other.

---

## Interview Questions {#interview-questions}

**Conceptual:**

1. *"What is chaos engineering and how does it differ from load testing and random failure injection?"*
   — Look for: hypothesis-driven (falsifiable hypothesis + steady-state metrics + measured pass/fail); discovers failure modes before production incidents; different from load testing (capacity vs resilience) and random destruction (no hypothesis, no pass/fail criteria); controlled blast radius; Principles of Chaos Engineering.

2. *"Explain the steady-state hypothesis. Why is it the most important element of a chaos experiment?"*
   — Look for: defines what "normal" looks like for the system; without it there are no pass/fail criteria; transforms experiment into scientific test; enables automation (abort conditions); the hypothesis encodes your assumptions about resilience — rejecting it is the finding.

3. *"What is blast radius in chaos engineering and what techniques do you use to control it?"*
   — Look for: scope of potential impact if experiment reveals unexpected failure; techniques: traffic segmentation (Istio/Envoy percentage routing), feature flags, canary deployments, experiment time limits, automated abort conditions, off-peak scheduling, starting at staging; blast radius expansion ladder (dev → staging → canary → production-5% → production-10% → at scale).

**Scenario-based:**

4. *"You run a chaos experiment injecting 200ms latency on your inventory service. Your hypothesis was that checkout would maintain below 0.1% errors. The experiment passes — errors stay at 0.08%. But P99 latency went from 180ms to 470ms. Is this a pass or a fail? What do you do next?"*
   — Look for: technically a pass on the defined hypothesis (error rate threshold met); but latency result is concerning — 470ms is close to the SLO boundary; update the hypothesis for next experiment to include latency: "P99 latency remains below 300ms"; create action item to investigate why 200ms upstream latency causes 290ms checkout latency increase (no circuit breaker? serial dependency?); this is a "near-miss" finding even though the experiment technically passed.

5. *"Your team is resistant to chaos engineering. The VP of Engineering says 'we're too busy and it's too risky.' How do you make the case and build a minimal viable chaos program in 90 days?"*
   — Look for: reframe risk — "the risk is not running chaos, it's discovering failure modes via user-facing incidents"; quantify incident cost from last 6 months; start with staging only (zero user risk); propose 1 GameDay in 90 days (4 hours, no production risk); first experiment = simplest possible (pod kill, already in HPA behavior); present findings at engineering all-hands to demonstrate value; build from there.

---

## Further Reading & Resources {#further-reading}

**Books:**
- *Chaos Engineering* — Casey Rosenthal & Nora Jones (O'Reilly) — The comprehensive reference for chaos engineering practice
- *Learning Chaos Engineering* — Russ Miles (O'Reilly) — Hands-on introduction to chaos engineering implementation
- *Site Reliability Engineering* — Chapter 17: Testing for Reliability (Google, O'Reilly) — SRE approach to reliability testing

**Online:**
- [Principles of Chaos Engineering](https://principlesofchaos.org/) — The foundational principles document
- [Netflix Tech Blog: Chaos Engineering](https://netflixtechblog.com/tagged/chaos-engineering) — Original chaos engineering articles from Netflix
- [LitmusChaos Documentation](https://litmuschaos.io/docs) — CNCF chaos engineering for Kubernetes
- [Gremlin Chaos Engineering Guide](https://www.gremlin.com/chaos-engineering/) — Comprehensive practical guide
- [AWS Fault Injection Simulator](https://docs.aws.amazon.com/fis/) — AWS-native chaos engineering

**Talks:**
- "Chaos Engineering: Why Breaking Things Should Be Practiced" — Casey Rosenthal (QCon)
- "Inside Chaos Engineering at Netflix" — Nora Jones (SREcon)
- "Controlled Chaos: The Art of Intentionally Breaking Your Own System" — Lorin Hochstein

---

## Key Takeaways {#key-takeaways}

> **Chapter 10 Summary**
>
> - **Chaos engineering is hypothesis-driven experimentation, not random destruction.** Every experiment begins with a falsifiable hypothesis, measurable steady-state metrics, and defined abort conditions. Without these, you have chaos — not chaos engineering.
>
> - **Failure modes discovered in experiments are 10-100× cheaper than failure modes discovered via production incidents.** The economics strongly favor proactive chaos over reactive incident response for any failure mode that can be anticipated.
>
> - **The steady-state hypothesis is the scientific core.** It defines what "normal" looks like, specifies how it is measured, and makes the experiment falsifiable. Rejecting the hypothesis is the most valuable outcome — it reveals a real resilience gap.
>
> - **Blast radius control is the obligation that makes production chaos responsible.** The blast radius expansion ladder (dev → staging → canary → 5% production → 10%) ensures every experiment starts at the smallest meaningful scope.
>
> - **Tools serve different use cases:** Chaos Monkey for random instance termination, Gremlin for multi-failure-type enterprise experiments with fine-grained safety controls, Litmus for Kubernetes-native GitOps-integrated chaos.
>
> - **GameDays test people AND systems simultaneously.** The team's response to an unexpected failure during a GameDay is at least as valuable as the system's response. Practicing incident response under controlled failure conditions makes real incidents less catastrophic.
>
> - **Continuous chaos prevents resilience regression.** Integrating chaos experiments into CI/CD pipelines ensures that every deployment is validated for resilience, not just correctness — and that resilience improvements don't quietly regress.
>
> - **Findings without action items are observations.** Apply the same 80% completion rate requirement to chaos experiment findings as to post-mortem action items. A resilience gap documented but not fixed is a known vulnerability.

---
*Previous: [Chapter 9 — Root Cause Analysis and Post-Mortems](#chapter-9)*
*Next: Chapter 11 — Artificial Intelligence for Site Reliability Engineering*
