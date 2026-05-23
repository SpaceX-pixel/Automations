---

# Chapter 2 — From DevOps to Site Reliability Engineering

---

## Table of Contents

- [Learning Objectives](#learning-objectives)
- [Core Concepts](#core-concepts)
  - [2.1 A Tale of Two Movements](#21-a-tale-of-two-movements)
  - [2.2 The DevOps Philosophy — Culture, Automation, Measurement, Sharing](#22-the-devops-philosophy)
  - [2.3 Where DevOps Falls Short at Scale](#23-where-devops-falls-short)
  - [2.4 SRE as Opinionated DevOps](#24-sre-as-opinionated-devops)
  - [2.5 Shared Ownership Models](#25-shared-ownership-models)
  - [2.6 Embedding SREs in Product Teams](#26-embedding-sres-in-product-teams)
  - [2.7 CI/CD Reliability — Making the Pipeline a Reliability Asset](#27-cicd-reliability)
  - [2.8 Shift-Left Reliability](#28-shift-left-reliability)
  - [2.9 The Production Readiness Review (PRR)](#29-the-production-readiness-review)
  - [2.10 Measuring the DevOps → SRE Transition](#210-measuring-the-transition)
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

- Articulate the philosophical and operational differences between DevOps and SRE, and explain why neither replaces the other.
- Design a shared ownership model that distributes operational responsibility between developers and SREs without creating a blame vacuum.
- Evaluate the trade-offs of embedded vs. consulting vs. platform SRE models when placing SREs inside product teams.
- Audit a CI/CD pipeline for reliability gaps and apply concrete fixes — from deployment strategies to pipeline observability.
- Apply shift-left reliability practices (Design for Reliability, PRRs, chaos in staging) to a software development lifecycle.

---

## Core Concepts {#core-concepts}

### 2.1 A Tale of Two Movements {#21-a-tale-of-two-movements}

In 2009, Patrick Debois organized the first **DevOpsDays** conference in Ghent, Belgium. The event crystallized a growing frustration: development teams and operations teams were structurally adversarial. Developers wanted to ship fast; operations wanted stability. The "wall of confusion" between them was costing organizations speed, quality, and morale.

DevOps emerged as a cultural antidote — tear down the silos, build shared ownership, automate everything, and measure outcomes rather than activity.

Around the same time, Google's SRE model — already running internally for six years — was producing measurable results at a scale DevOps practitioners could only aspire to. When Google published *Site Reliability Engineering* in 2016, practitioners recognized it as something DevOps had promised but never fully delivered: **a concrete, engineered implementation of reliability at scale.**

These two movements are not competing ideologies. They are **complementary layers of the same system** — DevOps provides the cultural and organizational foundation; SRE provides the engineering discipline and measurement framework that makes reliability *real.*

```
DevOps                          SRE
────────────────────────────────────────────────────
"Why"   ─────────────────────► "How"
Culture & philosophy            Engineering practices
Collaboration principles        Quantified reliability (SLOs/SLIs)
Continuous delivery             Reliable delivery pipelines
Shared ownership                Error budget-enforced ownership
Reduce silos                    Embed engineers, not just processes
```

---

### 2.2 The DevOps Philosophy — CAMS {#22-the-devops-philosophy}

The DevOps movement is most concisely captured by the **CAMS framework** (originally CALMS with Lean added later), coined by John Willis and Damon Edwards:

| Pillar | Meaning | SRE Expression |
|--------|---------|----------------|
| **Culture** | Shared ownership, psychological safety, no blame | Blameless post-mortems, joint on-call |
| **Automation** | Eliminate manual processes end-to-end | Toil elimination, self-healing infra |
| **Measurement** | Instrument everything, make data drive decisions | SLIs, SLOs, error budgets, DORA metrics |
| **Sharing** | Practices, tools, and knowledge flow across teams | Internal platforms, runbooks, PRRs |

DevOps at its best is transformative. Organizations that execute on CAMS genuinely ship faster, recover faster, and build more reliable software. The problem is that CAMS is a *direction*, not a destination. It tells you what to value; it doesn't tell you exactly *how* to implement reliability when you're operating 500 microservices across three cloud regions.

That's where SRE picks up.

---

### 2.3 Where DevOps Falls Short at Scale {#23-where-devops-falls-short}

DevOps works extraordinarily well for teams of 5–50 engineers. Everyone knows the system, communication is informal, and "shared ownership" is achievable through proximity.

At 500 engineers, cracks appear:

**Problem 1: Ownership dilution.**
When everyone owns reliability, effectively no one does. "Shared ownership" without explicit accountability degrades into the tragedy of the commons — teams optimize for their own service's velocity and assume someone else is watching the system holistically.

**Problem 2: Alert fatigue and on-call chaos.**
DevOps encourages developer on-call ("you build it, you run it"). At scale, without a structured alerting philosophy, SLO-based paging, and runbooks, this collapses into 3am pages for every deployment, developer burnout, and eventual attrition.

**Problem 3: No reliability engineering.**
DevOps teams typically have no dedicated function to *engineer* reliability improvements. Reliability work competes directly with feature work — and features almost always win, because features have visible owners (PMs, designers) and reliability doesn't.

**Problem 4: CI/CD as an afterthought.**
Many DevOps transformations invest heavily in CI and poorly in CD. Deployment pipelines are fast but fragile, lacking canary deployments, automated rollback, and production observability hooks.

SRE addresses each of these problems with concrete mechanisms:

| DevOps Gap | SRE Mechanism |
|---|---|
| Ownership dilution | Error budgets + SLO ownership per service |
| On-call chaos | Structured on-call, alert philosophy, SLO-based paging |
| No reliability engineering | Dedicated SRE headcount with engineering mandate |
| Fragile pipelines | Reliable CI/CD practices, deployment observability |

---

### 2.4 SRE as Opinionated DevOps {#24-sre-as-opinionated-devops}

Google's SRE book states it directly:

> "SRE is what you get when you treat operations as if it's a software problem... SRE is one implementation of the DevOps philosophy."

The key word is *implementation*. DevOps says "automate" — SRE tells you what to automate, how to measure whether the automation is working, and when to stop automating and accept human judgment.

The opinionated additions SRE brings to DevOps:

**1. Quantified reliability targets (SLOs).**
DevOps says "be reliable." SRE says "define reliability as 99.95% of homepage requests completing in under 300ms, measured over a 28-day rolling window, and hold all teams accountable to it."

**2. Error budgets as a policy mechanism.**
SRE converts the reliability target into an *actionable constraint*. When the budget is healthy, teams ship freely. When it's exhausted, reliability work takes precedence over features — automatically, without management negotiation.

**3. Toil as a tracked metric.**
DevOps encourages automation without making toil *measurable*. SRE makes toil a first-class metric — tracked per engineer, per team, reported to leadership, and subject to a hard cap.

**4. The Production Readiness Review.**
SRE introduces a formal gate — before a new service goes to production or before an SRE team accepts on-call responsibility for a service, it must pass a PRR. This bakes reliability into the development process rather than bolting it on afterward.

---

### 2.5 Shared Ownership Models {#25-shared-ownership-models}

The transition from "ops owns production" to a mature shared ownership model is one of the most organizationally challenging aspects of SRE adoption. There is no single right answer — but there are well-understood patterns.

#### Model A: "You Build It, You Run It" (Full Developer Ownership)
Popularized by Werner Vogels at Amazon. Developer teams own their services end-to-end, including on-call.

```
Product Team
├── Engineers (build features)
├── On-call rotation (all engineers)
└── Reliability responsibility (full)
```

**Strengths:** Maximum accountability. Developers feel the operational pain of their decisions immediately, creating strong incentives for reliable code.

**Weaknesses:** Not scalable without heavy platform investment. Developer burnout at high incident rates. Reliability competes directly with feature work, and features typically win.

**Best for:** Mature DevOps organizations with small teams, high autonomy, and strong platform support.

---

#### Model B: Centralized SRE with SLO-based Handoff (Google Model)

SRE team owns on-call for services that meet reliability standards. Services that exceed the error budget are "handed back" to the development team until stability is restored.

```
SRE Team ◄──────── SLO Compliance ────────► Product Team
  │                                              │
  ├── On-call (SLO-compliant services)          ├── On-call (services failing SLO)
  ├── Tooling & platform                        ├── Feature development
  └── Reliability engineering                  └── Reliability remediation
```

**Strengths:** Highly scalable. Creates strong incentives for developer-led reliability. SREs spend time on high-impact engineering, not firefighting.

**Weaknesses:** Requires mature SLO definitions and organizational trust. The "handback" mechanism can feel adversarial if poorly implemented.

**Best for:** Large organizations with 10+ product teams and a mature SRE function.

---

#### Model C: Embedded SRE (Hybrid)

SREs are assigned to product teams but report to a central SRE chapter for standards and career development.

```
SRE Chapter (Standards, Career)
│
├── SRE Engineer ── [Product Team A: Payments]
├── SRE Engineer ── [Product Team B: Checkout]
└── SRE Engineer ── [Product Team C: Search]
```

**Strengths:** Deep domain context. SREs develop strong relationships with developers. Reliability is a standing agenda item in team planning.

**Weaknesses:** SREs can become "ops" if not protected by chapter-level standards. Risk of inconsistent reliability practices across teams.

**Best for:** Mid-sized organizations (100–500 engineers) making the transition from traditional ops to SRE.

---

#### Ownership Responsibility Matrix (RACI)

Regardless of model, a clear RACI prevents the ownership vacuum:

| Activity | Developer | SRE | Platform | Management |
|---|---|---|---|---|
| Define SLIs/SLOs | Consulted | **Responsible** | Informed | Accountable |
| Implement features | **Responsible** | Consulted | Informed | Accountable |
| Incident response (P1) | Consulted | **Responsible** | Informed | Informed |
| Post-mortem | **Responsible** | Facilitated | Informed | Accountable |
| Pipeline reliability | **Responsible** | Consulted | **Responsible** | Informed |
| Capacity planning | Consulted | **Responsible** | Consulted | Accountable |

---

### 2.6 Embedding SREs in Product Teams {#26-embedding-sres-in-product-teams}

When an SRE joins a product team, the first 90 days determine whether the engagement will be transformative or just expensive staffing. High-performance SREs follow a structured onboarding pattern:

**Days 1–30: Listen, observe, measure.**
- Shadow on-call. Take notes on every alert: Was it actionable? Was the runbook complete? Did it require judgment or could it be automated?
- Audit the service's architecture. Draw the dependency graph. Find the single points of failure.
- Establish baseline reliability metrics: current error rate, P50/P95/P99 latency, deployment frequency, MTTR.
- Build rapport. Do not walk in with a list of problems on day one.

**Days 30–60: Define and socialize SLOs.**
- Draft SLI/SLO proposals based on user journeys (not infrastructure metrics).
- Present to the team and stakeholders. Adjust based on feedback.
- Instrument SLO tracking in the existing observability stack.
- Identify the top 3 sources of toil. Begin automating the highest-cost one.

**Days 60–90: Build, review, and hand off.**
- Implement at least one automation that reduces toil measurably.
- Run the first Production Readiness Review for any upcoming launch.
- Define the error budget policy with the team and PM.
- Establish a blameless post-mortem template and run one — even retrospectively on a past incident.

**The SRE's "Exit Criteria":**
A well-functioning embedded SRE should be working toward making themselves partially redundant — by raising the reliability bar of the team itself, so the SRE's unique expertise is needed less often for routine operations.

---

### 2.7 CI/CD Reliability — Making the Pipeline a Reliability Asset {#27-cicd-reliability}

The CI/CD pipeline is the primary mechanism by which unreliability enters production. A deployment that bypasses testing, skips canary stages, or lacks automated rollback is a reliability liability.

High-performance SREs treat the pipeline as a system with its own SLOs.

#### The Reliable Deployment Pipeline

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Reliable CI/CD Pipeline                          │
│                                                                     │
│  Code  ──► Unit    ──► Integration ──► Staging  ──► Canary  ──► Prod│
│  Commit    Tests       Tests           Tests        (1-5%)         │
│            │           │               │             │              │
│            ▼           ▼               ▼             ▼              │
│          FAIL?       FAIL?           FAIL?    SLO burn rate?        │
│            │           │               │         too high?         │
│            └───────────┴───────────────┴────────────┘              │
│                              BLOCK + ALERT                          │
└─────────────────────────────────────────────────────────────────────┘
```

#### Deployment Strategies and Their Reliability Profiles

| Strategy | Description | Risk | Recovery |
|---|---|---|---|
| **Big Bang** | All traffic switches at once | High — no rollback path | Manual, slow |
| **Blue/Green** | Two identical envs; switch DNS | Medium — full switch still instant | Fast — revert DNS |
| **Rolling** | Gradual instance replacement | Low-medium — bad instances get traffic | Moderate |
| **Canary** | 1-5% of traffic to new version | Low — blast radius limited | Fast — remove canary |
| **Feature Flags** | Code deployed, features gated | Very low — no infra change | Instant — toggle flag |

**SRE recommendation:** Default to canary + feature flags for all production changes. Reserve blue/green for database schema migrations and major infrastructure changes.

#### Pipeline Observability — SLOs for CI/CD

SREs instrument pipelines the same way they instrument services:

```yaml
# Example: Prometheus metrics for CI/CD pipeline observability
# Expose these from your CI system (GitHub Actions, Jenkins, etc.)

pipeline_build_duration_seconds:
  type: histogram
  labels: [pipeline, stage, branch]
  description: Duration of each pipeline stage

pipeline_failure_total:
  type: counter
  labels: [pipeline, stage, reason]
  description: Total pipeline failures by stage and reason

deployment_success_rate:
  type: gauge
  labels: [service, environment]
  description: Ratio of successful deployments over rolling 7-day window

canary_error_rate:
  type: gauge
  labels: [service, version]
  description: Error rate for canary vs stable version (for automated rollback trigger)
```

#### Automated Rollback

The most valuable reliability feature in a deployment pipeline is automated rollback — the ability to detect a bad deployment and revert without human intervention:

```python
# Simplified canary analysis logic — runs after canary deployment
# In production, use tools like Argo Rollouts, Spinnaker, or Flagger

import time
import requests

CANARY_ERROR_THRESHOLD = 0.01   # 1% error rate triggers rollback
STABLE_BASELINE_MULTIPLIER = 2  # Canary error rate must be < 2x stable
ANALYSIS_WINDOW_SECONDS = 300   # Evaluate for 5 minutes

def get_error_rate(version: str) -> float:
    """Query Prometheus for error rate of a given version."""
    query = f'rate(http_requests_total{{version="{version}",status=~"5.."}}[5m]) / rate(http_requests_total{{version="{version}"}}[5m])'
    response = requests.get("http://prometheus:9090/api/v1/query", params={"query": query})
    result = response.json()["data"]["result"]
    return float(result[0]["value"][1]) if result else 0.0

def canary_analysis(canary_version: str, stable_version: str) -> str:
    print(f"[INFO] Beginning canary analysis for {canary_version} vs {stable_version}")
    time.sleep(ANALYSIS_WINDOW_SECONDS)

    canary_errors = get_error_rate(canary_version)
    stable_errors = get_error_rate(stable_version)

    print(f"[METRIC] Canary error rate: {canary_errors:.3%}")
    print(f"[METRIC] Stable error rate: {stable_errors:.3%}")

    if canary_errors > CANARY_ERROR_THRESHOLD:
        return "ROLLBACK"
    if stable_errors > 0 and canary_errors > stable_errors * STABLE_BASELINE_MULTIPLIER:
        return "ROLLBACK"
    return "PROMOTE"

decision = canary_analysis("v2.4.1", "v2.4.0")
print(f"[DECISION] {decision}")
```

#### The Change Failure Rate — A DORA Metric SREs Own

The DORA (DevOps Research and Assessment) research program identified four key metrics that predict software delivery performance:

| DORA Metric | Elite Performers | High Performers |
|---|---|---|
| **Deployment Frequency** | On-demand (multiple/day) | Daily to weekly |
| **Lead Time for Changes** | < 1 hour | 1 day – 1 week |
| **Change Failure Rate** | 0–15% | 16–30% |
| **Time to Restore Service** | < 1 hour | < 1 day |

SREs own **Change Failure Rate** and **Time to Restore Service (MTTR)** as primary metrics. These are the reliability dimensions of software delivery.

```promql
# PromQL: Change Failure Rate over 30 days
# Deployments that caused an incident or rollback / total deployments

(
  sum(increase(deployments_failed_total[30d]))
  /
  sum(increase(deployments_total[30d]))
) * 100
```

---

### 2.8 Shift-Left Reliability {#28-shift-left-reliability}

"Shift left" means moving practices earlier in the software development lifecycle — from post-production to pre-production, or even into the design phase. SREs apply this principle to reliability: don't wait for production to find reliability problems.

```
Traditional (Shift Right)
─────────────────────────────────────────────────────────────►
Design  →  Code  →  Test  →  Build  →  Deploy  →  [FIND BUGS IN PROD]

Shift-Left Reliability
─────────────────────────────────────────────────────────────►
[DESIGN   [CODE       [TEST          [BUILD       [DEPLOY
 FOR       REVIEW +    CHAOS +        RELIABILITY  CANARY +
 RELIABILITY LINT      LOAD TEST]     GATES]       ROLLBACK]
```

#### Shift-Left Practice 1: Design for Reliability (DFR)

Before a single line of code is written, reliability should be a design constraint — not a post-launch polish item.

**DFR Checklist (applied at architecture review):**

- [ ] Are all external dependencies wrapped with circuit breakers?
- [ ] Does the service degrade gracefully if a dependency is unavailable?
- [ ] Is there a documented fallback for every critical path?
- [ ] Are retry policies defined with exponential backoff and jitter?
- [ ] Is the data model designed for idempotency?
- [ ] Has a failure mode analysis (FMEA) been conducted?
- [ ] Are all new SLIs/SLOs defined before coding begins?

**Failure Mode and Effects Analysis (FMEA) — simplified:**

| Component | Failure Mode | Effect | Likelihood (1-5) | Impact (1-5) | Risk Score | Mitigation |
|---|---|---|---|---|---|---|
| Payment API | Timeout | Order fails silently | 3 | 5 | 15 | Circuit breaker + retry |
| Database | Connection pool exhausted | All writes fail | 2 | 5 | 10 | Pool monitoring + alert |
| Cache | Cold start (Redis restart) | 10× DB load spike | 2 | 4 | 8 | Cache warming + DB rate limit |
| CDN | Misconfigured cache headers | Stale content served | 4 | 3 | 12 | Cache-Control audit in CI |

**Risk Score = Likelihood × Impact.** Prioritize mitigations by score.

---

#### Shift-Left Practice 2: Reliability in Code Review

Code review is one of the highest-leverage shift-left opportunities. SREs establish reliability review criteria that developers can apply in every pull request:

```python
# Anti-pattern: No timeout, no retry, no fallback
response = requests.get("https://api.payments.internal/charge", json=payload)

# SRE-approved pattern: Timeout + retry with backoff + fallback
import time
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

def call_payment_api(payload: dict, max_retries: int = 3) -> dict:
    session = requests.Session()
    retry_strategy = Retry(
        total=max_retries,
        backoff_factor=0.5,          # 0.5s, 1s, 2s
        status_forcelist=[500, 502, 503, 504],
        raise_on_status=False
    )
    adapter = HTTPAdapter(max_retries=retry_strategy)
    session.mount("https://", adapter)

    try:
        response = session.post(
            "https://api.payments.internal/charge",
            json=payload,
            timeout=(3, 10)          # (connect timeout, read timeout)
        )
        response.raise_for_status()
        return response.json()
    except requests.exceptions.Timeout:
        # Fallback: queue for async retry
        queue_payment_for_retry(payload)
        return {"status": "queued", "message": "Payment queued for retry"}
    except requests.exceptions.RequestException as e:
        raise PaymentServiceUnavailable(f"Payment API unreachable: {e}") from e
```

**SRE Code Review Checklist:**
- [ ] Are all network calls bounded by timeouts?
- [ ] Are retries implemented with backoff and jitter (not fixed delays)?
- [ ] Are errors handled explicitly, not swallowed?
- [ ] Are new metrics emitted for new code paths?
- [ ] Is the new feature behind a feature flag for safe rollout?
- [ ] Has the load on upstream dependencies been estimated?

---

#### Shift-Left Practice 3: Reliability Testing in the Pipeline

Testing for reliability is distinct from testing for correctness. A function can return the right answer under normal conditions and still be a reliability liability under load, with a degraded dependency, or after days of continuous operation.

**Reliability test types and their pipeline placement:**

| Test Type | Pipeline Stage | What It Catches |
|---|---|---|
| **Unit tests with fault injection** | CI (every commit) | Missing error handling, bad retry logic |
| **Contract tests** | CI (every commit) | API breaking changes between services |
| **Load tests** | Staging (pre-deploy) | Latency degradation, resource leaks under traffic |
| **Chaos tests** | Staging (pre-deploy) | Dependency failure handling, cascade failures |
| **Synthetic monitoring** | Production (always on) | User journey availability from external vantage points |
| **Soak tests** | Staging (weekly/release) | Memory leaks, connection pool exhaustion over time |

```yaml
# GitHub Actions: Reliability gate — load test must pass before production deploy
name: Reliability Gate

on:
  push:
    branches: [main]

jobs:
  load-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Deploy to staging
        run: ./scripts/deploy.sh staging

      - name: Run k6 load test
        uses: grafana/k6-action@v0.3.0
        with:
          filename: tests/load/checkout_flow.js
          flags: --vus 200 --duration 5m

      - name: Assert SLO thresholds
        run: |
          # Fail the pipeline if p99 latency > 500ms or error rate > 0.1%
          python scripts/assert_slo.py \
            --p99-threshold 500 \
            --error-rate-threshold 0.001 \
            --results k6_results.json

      - name: Deploy to production (canary)
        if: success()
        run: ./scripts/deploy.sh production --strategy canary --weight 5
```

---

### 2.9 The Production Readiness Review (PRR) {#29-the-production-readiness-review}

The **Production Readiness Review** is SRE's primary shift-left mechanism at the service level. Before a new service enters production (or before SRE accepts on-call responsibility for it), it must pass a structured review against a reliability checklist.

The PRR is not a gatekeeping exercise — it is a *collaborative engineering review* that surfaces reliability gaps early, when they are cheap to fix.

#### PRR Checklist (Abbreviated)

**Architecture & Design**
- [ ] Dependency map documented and reviewed
- [ ] Single points of failure identified and mitigated
- [ ] Graceful degradation path defined for each critical dependency
- [ ] Data persistence strategy documented (backup, recovery, RTO/RPO)

**Observability**
- [ ] Four Golden Signals instrumented (latency, traffic, errors, saturation)
- [ ] Distributed tracing integrated
- [ ] Structured logging with correlation IDs
- [ ] SLI dashboards built and verified

**SLOs & Alerting**
- [ ] SLIs defined based on user journeys
- [ ] SLOs agreed upon with product/stakeholders
- [ ] Alerts configured using SLO burn rate approach (not threshold-based)
- [ ] PagerDuty/OpsGenie routing configured

**Deployment & Rollback**
- [ ] Canary or progressive rollout configured
- [ ] Automated rollback trigger defined
- [ ] Feature flags covering all major new features
- [ ] Deployment runbook reviewed by an engineer unfamiliar with the service

**Operations**
- [ ] On-call runbooks written for top 5 expected alerts
- [ ] Runbooks verified by someone who didn't write them
- [ ] Incident escalation path documented
- [ ] On-call rotation established and staffed
- [ ] GameDay (chaos exercise) conducted in staging

**Capacity**
- [ ] Load test results reviewed against expected traffic
- [ ] Autoscaling configured and tested
- [ ] Resource limits (CPU, memory) set and validated

#### PRR Outcome States

| Outcome | Meaning |
|---|---|
| **Green — Ready** | Service meets all criteria. SRE accepts on-call. |
| **Yellow — Conditional** | Minor gaps identified. SRE accepts on-call with a remediation timeline. |
| **Red — Not Ready** | Critical gaps. Launch delayed until resolved. |

---

### 2.10 Measuring the DevOps → SRE Transition {#210-measuring-the-transition}

Organizational transformations are only credible if they are measurable. When leading or participating in a DevOps → SRE transition, track these metrics:

**Leading indicators** (tell you if you're doing the right things):
- % of services with defined SLOs
- % of SRE time classified as engineering vs. toil
- Number of PRRs conducted per quarter
- % of deployments using canary or progressive rollout

**Lagging indicators** (tell you if it's working):
- Change Failure Rate (target: < 15% for elite)
- MTTR (target: < 1 hour for P1 incidents)
- SLO compliance rate across portfolio
- Developer on-call page volume per engineer per week

```
SRE Maturity Model
──────────────────────────────────────────────────────────────────
Level 0 (Ad-hoc)
  - No SLOs. Reliability = "it's up"
  - On-call = whoever is available
  - Deployments are manual, scary, weekend events
  - Post-mortems are blame sessions (or don't happen)

Level 1 (Reactive)
  - SLOs defined but not enforced
  - On-call rotation exists but runbooks are sparse
  - CI/CD pipeline exists but lacks reliability gates
  - Some post-mortems, but action items aren't tracked

Level 2 (Managed)
  - SLOs enforced via error budget policy
  - Toil < 50%, tracked and reported
  - Canary deployments standard
  - Blameless post-mortems with tracked action items

Level 3 (Proactive)
  - SLOs drive roadmap decisions
  - Toil actively decreasing quarter over quarter
  - Chaos engineering in staging, moving to production
  - PRRs standard for all new services
  - Developer teams self-serve on reliability tooling

Level 4 (Optimizing)
  - Reliability is a product feature, not an SRE tax
  - Automated incident detection and remediation for majority of alerts
  - SRE function transitioning to pure platform engineering
  - Error budgets inform business decisions (pricing, SLAs)
```

---

## Key Principles & Best Practices {#key-principles}

1. **Don't import DevOps theater.** Renaming "Ops" to "SRE" without changing incentives, authority, or engineering time is expensive rebranding. Start with the 50% engineering time rule as a non-negotiable organizational commitment.

2. **Shared ownership requires explicit contracts.** "Everyone owns reliability" is a recipe for no one owning it. Define RACI explicitly. Who gets paged? Who approves the rollback? Who runs the post-mortem?

3. **The CI/CD pipeline is a reliability system.** Instrument it, define its SLOs, and treat a pipeline failure as a reliability incident. A pipeline that takes 45 minutes to run is a reliability liability — it slows the MTTR for every production fix.

4. **Shift left by shifting *conversations* left.** The most effective shift-left practice is inviting the SRE to the architecture review — before the design is locked, before the code is written. No checklist in a PR comment changes an architectural decision that was made six months ago.

5. **PRRs are partnerships, not audits.** Frame the Production Readiness Review as the SRE helping the team ship reliably — not the SRE blocking the team from shipping. The goal is a green launch, not a gated launch.

6. **Treat DORA metrics as your reliability scoreboard.** Change Failure Rate and MTTR are the reliability dimensions of software delivery. Track them, trend them, and present them to leadership quarterly.

7. **The best SREs improve the reliability of teams, not just systems.** When an embedded SRE leaves a team, the team should be measurably more reliable than before. If reliability depends on the SRE's presence, the engagement failed.

---

## Tools & Technologies {#tools}

| Tool | Category | SRE Use Case |
|---|---|---|
| **GitHub Actions / GitLab CI** | CI/CD | Pipeline orchestration, reliability gates, canary triggers |
| **Argo Rollouts** | Progressive Delivery | Canary + blue/green deployments with automated analysis |
| **Flagger** | Progressive Delivery | Kubernetes-native canary operator, integrates with Prometheus |
| **k6 / Locust** | Load Testing | Shift-left load tests as pipeline stages |
| **LaunchDarkly / Flagsmith** | Feature Flags | Safe deployments, instant rollback via flag toggle |
| **Checkov / Terrascan** | IaC Security/Reliability | Shift-left IaC reliability scanning in CI |
| **OPA (Open Policy Agent)** | Policy as Code | Enforce reliability standards (e.g., all services must have resource limits) |
| **Backstage** | Internal Developer Portal | Centralize PRR tracking, SLO dashboards, service maturity scores |
| **DORA Metrics Dashboard** | Measurement | Track deployment frequency, CFR, MTTR across the organization |

---

## Hands-on Exercises / Labs {#labs}

### Lab 2.1 — Shared Ownership RACI Workshop

**Goal:** Design a shared ownership model for a real or hypothetical product team.

**Scenario:** A 20-person product team (15 developers, 1 PM, 2 QA, 2 SREs) runs a B2B SaaS payments platform with a 99.9% SLA to customers. There have been three P1 incidents in the past month. In each case, developers claimed "ops should have caught it" and the SRE team claimed "developers deployed bad code."

**Tasks:**
1. Identify the 8 most critical operational activities for this team (hint: use the RACI table from Section 2.5 as a starting point).
2. For each activity, assign R/A/C/I across: Junior Developer, Senior Developer, SRE, PM, and SRE Manager.
3. Identify where the three incidents would have been caught under your model.
4. Write a one-page "Reliability Ownership Charter" that the team could sign and display in their Notion/Confluence page.

---

### Lab 2.2 — CI/CD Reliability Audit

**Goal:** Identify and remediate reliability gaps in a CI/CD pipeline.

**Given:** A simplified pipeline definition (GitHub Actions) with the following stages: lint → unit test → build → push image → deploy to production.

```yaml
# Current pipeline — find the reliability gaps
name: Deploy

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - run: npm run lint
      - run: npm test
      - run: docker build -t myapp:${{ github.sha }} .
      - run: docker push myapp:${{ github.sha }}
      - run: kubectl set image deployment/myapp myapp=myapp:${{ github.sha }}
```

**Tasks:**
1. List every reliability gap in the pipeline above (minimum 5).
2. Rewrite the pipeline to address each gap. Include: staging deploy, load test gate, canary rollout, automated rollback trigger, and Slack notification on failure.
3. Define a "Pipeline SLO": what does a healthy pipeline look like in terms of success rate and duration? What would you alert on?

---

### Lab 2.3 — Shift-Left FMEA Exercise

**Goal:** Apply Failure Mode and Effects Analysis to a system before it is built.

**Scenario:** You are joining the architecture review for a new microservice: a real-time inventory availability API. It will be called by the checkout frontend (synchronously) and the warehouse management system (asynchronously). It reads from a primary PostgreSQL database and caches results in Redis for 60 seconds.

**Tasks:**
1. Identify at least 6 failure modes using the FMEA table format from Section 2.8.
2. Calculate risk scores. Prioritize the top 3 for immediate mitigation.
3. For the top 3 risks, write a one-paragraph architectural mitigation that can be implemented before coding begins.
4. Add 3 items to the PRR checklist specific to this service that aren't in the standard checklist.

---

### Lab 2.4 — PRR Simulation

**Goal:** Conduct a Production Readiness Review for a service near launch.

**Context:** A developer has submitted a new checkout service for PRR. It has: unit tests (90% coverage), a Datadog dashboard (CPU and memory only), deployment via `kubectl apply` (no canary), and a runbook that says "if it breaks, restart the pod."

**Tasks:**
1. Score the service against the abbreviated PRR checklist in Section 2.9.
2. Produce a Red/Yellow/Green outcome with written justification.
3. Write the top 5 action items the developer must complete before SRE accepts on-call.
4. Draft the PRR feedback email — firm but collaborative in tone.

---

## Common Pitfalls & Anti-patterns {#pitfalls}

**Anti-pattern 1: The DevOps → SRE rename with no substance**
An organization announces an "SRE transformation" by renaming the ops team, publishing a glossy internal blog post, and changing job titles. Six months later, SREs are handling 100% tickets, doing zero engineering work, and the MTTR has not improved. The transformation was a rebrand, not a transformation. *Fix:* Define success metrics before the transformation begins. Track toil %, engineering time %, and DORA metrics monthly. Make them visible to senior leadership.

**Anti-pattern 2: Reliability gates as gatekeeping**
SREs use PRRs and reliability criteria to slow down product teams, protecting their on-call load at the expense of business velocity. Trust erodes. Product teams route around SREs. *Fix:* Reframe PRRs as "launch assistance," not "launch approval." SREs help teams meet the criteria, not just judge them.

**Anti-pattern 3: CI/CD as a compliance checkbox**
Teams add a "load test" stage to the pipeline that runs 5 virtual users for 30 seconds against a staging environment with 10% of production data. The test always passes; it catches nothing. *Fix:* Load tests must reflect production traffic patterns and run against a staging environment that mirrors production capacity. Define pass/fail thresholds based on SLOs, not arbitrary numbers.

**Anti-pattern 4: Shift-left without developer education**
SREs add a reliability checklist to the PR template. Developers check all boxes without understanding why. "Are all external calls wrapped with timeouts?" — checked. Code shipped. Timeout set to 60 seconds with no fallback. *Fix:* Pair every checklist item with a link to an internal guide or example. Run quarterly "reliability office hours" where SREs walk developers through common reliability patterns.

**Anti-pattern 5: DORA metrics as a performance review tool**
Management uses deployment frequency and MTTR to rank engineers. Teams start gaming metrics — deploying trivial changes to inflate frequency, suppressing incidents to protect MTTR. *Fix:* DORA metrics are team-level indicators, not individual performance metrics. They measure the health of a system and process, not a person.

---

## Interview Questions {#interview-questions}

**Conceptual:**

1. *"How would you explain the relationship between DevOps and SRE to a developer who thinks they're the same thing?"*
   — Look for: DevOps as philosophy/culture, SRE as opinionated implementation; error budgets, toil, PRR as SRE-specific mechanisms; both are complementary.

2. *"What is 'shift-left reliability' and what are the three most impactful places to apply it in an SDLC?"*
   — Look for: design reviews (FMEA), reliability in code review (timeouts, retries), reliability testing in pipelines (chaos/load tests in staging).

**Scenario-based:**

3. *"You join a product team as an embedded SRE. The developers are defensive and see you as an 'ops person' who will slow them down. How do you approach your first 90 days?"*
   — Look for: listen-first approach, finding quick wins (automating a clear pain point), building relationships before enforcing standards, co-owning the first PRR rather than auditing it.

4. *"A developer wants to skip the canary deployment stage for a high-priority fix because 'it's just a config change.' How do you respond?"*
   — Look for: empathy + data (most production incidents are caused by 'small' changes), discuss risk scope, propose a 5% canary for 10 minutes as a low-cost middle ground, reference error budget state.

5. *"Your organization's Change Failure Rate is 35% — well above the industry benchmark of 15%. Walk me through how you would diagnose and systematically improve it."*
   — Look for: decompose CFR by service/team/change type to find concentrations; audit pipeline reliability gates; interview on-call engineers about recent incidents; identify top failure causes (missing tests, no canary, poor runbooks); implement targeted fixes with before/after measurement.

---

## Further Reading & Resources {#further-reading}

**Books:**
- *Accelerate* — Forsgren, Humble, Kim — The research behind DORA metrics and high-performing engineering organizations
- *The DevOps Handbook* — Kim, Humble, Debois, Willis — Comprehensive DevOps implementation guide
- *Continuous Delivery* — Humble & Farley — The definitive guide to reliable deployment pipelines
- *Team Topologies* — Skelton & Pais — How to structure teams (including SRE topologies) for fast flow and reliability

**Online:**
- [DORA State of DevOps Report](https://dora.dev) — Annual research report on software delivery performance
- [Google's SRE Workbook — Chapter on SRE Engagement Model](https://sre.google/workbook/engagement-model/) — The consulting SRE model in detail
- [Argo Rollouts Documentation](https://argo-rollouts.readthedocs.io/) — Progressive delivery for Kubernetes
- [Martin Fowler's Canary Release](https://martinfowler.com/bliki/CanaryRelease.html) — Canonical reference on canary deployments

**Talks:**
- "10+ Deploys Per Day: Dev and Ops Cooperation at Flickr" — Allspaw & Hammond (Velocity 2009) — The talk that started DevOps
- "Keys to SRE" — Ben Treynor Sloss (SREcon 2014) — The SRE model from its creator

---

## Key Takeaways {#key-takeaways}

> **Chapter 2 Summary**
>
> - **DevOps and SRE are complementary, not competing.** DevOps provides the cultural philosophy; SRE provides the engineering discipline and quantified practices that make reliability real at scale. The best organizations do both.
>
> - **Shared ownership requires explicit design.** "Everyone owns reliability" collapses at scale without a RACI, an error budget policy, and clear escalation paths. Ambiguity breeds the blame vacuum that caused the original Dev/Ops split.
>
> - **Embedding SREs accelerates reliability culture** — but only with a structured 90-day plan that prioritizes listening, measurement, and quick wins before enforcement. SREs who arrive with a checklist on day one lose the team.
>
> - **The CI/CD pipeline is a reliability system.** It deserves SLOs, instrumentation, and canary/rollback capabilities. A fast pipeline that ships bad code faster is not a reliability asset.
>
> - **Shift left to find reliability failures when they're cheap.** FMEA at design time, reliability criteria in code review, load tests and chaos in the pipeline — each layer catches failures earlier and cheaper than the one to its right.
>
> - **Measure the transformation with DORA metrics.** Change Failure Rate and MTTR are the reliability report card for your delivery system. Track them, trend them, and use them to drive investment decisions.
>
> - **PRRs are partnerships.** The Production Readiness Review is SRE's most powerful shift-left tool — but only if it's framed as collaborative launch assistance, not a gatekeeping audit.

---

*Previous: [Chapter 1 — Introduction to Site Reliability Engineering](#chapter1)*
*Next: Chapter 3 — Monitoring*

---

