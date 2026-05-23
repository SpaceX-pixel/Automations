# Chapter 4 — Incident Management and Risk Mitigation
---

## Table of Contents

- [Learning Objectives](#learning-objectives)
- [Core Concepts](#core-concepts)
  - [4.1 What Is an Incident?](#41-what-is-an-incident)
  - [4.2 The Incident Lifecycle](#42-the-incident-lifecycle)
  - [4.3 Severity Classification](#43-severity-classification)
  - [4.4 ITSM Frameworks — ITIL, NIST, and SRE](#44-itsm-frameworks)
  - [4.5 Roles in Incident Response](#45-roles-in-incident-response)
  - [4.6 Runbooks — Encoding Operational Knowledge](#46-runbooks)
  - [4.7 The War Room — Command and Control](#47-war-room)
  - [4.8 Communication Protocols](#48-communication-protocols)
  - [4.9 Risk Registers](#49-risk-registers)
  - [4.10 Failure Mode Analysis and Mitigation Strategies](#410-failure-mode-analysis)
  - [4.11 Incident Metrics — Measuring Response Effectiveness](#411-incident-metrics)
  - [4.12 Incident Management Tooling](#412-incident-management-tooling)
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

- Define the complete incident lifecycle and execute each phase with precision — from detection through resolution and retrospective.
- Design a severity classification framework that maps technical impact to business consequence, enabling consistent, fast escalation decisions.
- Assign and operate the five core incident response roles (IC, CL, SCL, SL, Comms) without role overlap or ownership gaps.
- Write production-grade runbooks that a junior engineer can execute correctly at 3am without calling for help.
- Build a risk register and apply Failure Mode and Effects Analysis (FMEA) to quantify and prioritize systemic risks before they become incidents.

---

## Core Concepts {#core-concepts}

### 4.1 What Is an Incident? {#41-what-is-an-incident}

An **incident** is any unplanned interruption to a service or degradation in service quality that causes or risks causing user impact.

The key word is *unplanned*. Planned maintenance, scheduled deployments, and known degradation windows are not incidents — they are change events. The distinction matters because incidents trigger a response process with defined roles, escalation paths, and documentation requirements.

**Incident vs Service Request vs Problem:**

```
┌─────────────────────────────────────────────────────────────────┐
│            ITSM Event Classification                            │
├─────────────────┬───────────────────────────────────────────────┤
│ Incident        │ Unplanned disruption to service quality.      │
│                 │ "Checkout errors spiking to 5%."              │
│                 │ Response: restore service ASAP.               │
├─────────────────┼───────────────────────────────────────────────┤
│ Service Request │ Planned, routine work request.                │
│                 │ "Provision a new database for team X."        │
│                 │ Response: fulfillment workflow.               │
├─────────────────┼───────────────────────────────────────────────┤
│ Problem         │ Root cause of one or more incidents.          │
│                 │ "Missing database index causes checkout       │
│                 │  timeouts under load."                        │
│                 │ Response: permanent fix via problem mgmt.     │
├─────────────────┼───────────────────────────────────────────────┤
│ Change          │ Planned modification to a system.             │
│                 │ "Deploy checkout v2.5 Tuesday 2am."           │
│                 │ Response: change management workflow.         │
└─────────────────┴───────────────────────────────────────────────┘
```

**Incidents are not failures of engineering — they are the cost of operating complex systems.** The goal is not zero incidents; the goal is fast detection, fast response, bounded blast radius, and continuous improvement from every incident.

The healthiest SRE organizations track incidents without shame, document them transparently, and treat each one as a free lesson in how their systems fail.

---

### 4.2 The Incident Lifecycle {#42-the-incident-lifecycle}

Every incident moves through six phases. The speed at which it moves through each phase — and the quality of execution at each phase — determines user impact, business cost, and team learning.

```
┌─────────────────────────────────────────────────────────────────────┐
│                     The Incident Lifecycle                          │
│                                                                     │
│  DETECT  ──►  TRIAGE  ──►  RESPOND  ──►  RESOLVE  ──►  REVIEW      │
│     │             │            │              │            │        │
│   Alert         Severity    Assemble       Restore       Post-     │
│   fires         assessed    war room       service       mortem    │
│   or user       on-call     investigate    verify        written   │
│   reports       engaged     mitigate       monitor       actions   │
│                             communicate    close         tracked   │
└─────────────────────────────────────────────────────────────────────┘
```

#### Phase 1: Detection

Detection is the trigger — the moment the team learns something is wrong. Detection sources, in order of quality:

| Source | MTTD | Quality |
|--------|------|---------|
| Synthetic monitoring (proactive) | Seconds | Best — detects before real users |
| SLO burn rate alert | 1–5 min | Excellent — user impact confirmed |
| On-call alert (threshold) | 1–15 min | Good — depends on alert quality |
| Support ticket | 30–120 min | Poor — user already impacted |
| Social media / news | Hours | Unacceptable — serious brand damage |

The goal is to drive detection as far left as possible — toward synthetic monitoring and burn rate alerts, away from user reports and social media.

```python
# Synthetic monitor — runs every 60 seconds from external locations
# Detects availability failures before real users do
import requests
import time
from prometheus_client import Gauge, Counter, push_to_gateway

SYNTHETIC_SUCCESS = Counter(
    'synthetic_check_success_total',
    'Successful synthetic checks',
    ['service', 'region', 'journey']
)
SYNTHETIC_FAILURE = Counter(
    'synthetic_check_failure_total',
    'Failed synthetic checks',
    ['service', 'region', 'journey', 'reason']
)
SYNTHETIC_LATENCY = Gauge(
    'synthetic_check_duration_seconds',
    'Synthetic check duration',
    ['service', 'region', 'journey']
)

def run_checkout_journey(region: str) -> None:
    """Simulate full checkout user journey."""
    journey = "checkout_complete"
    start = time.time()
    try:
        # Step 1: Load product page
        r1 = requests.get("https://shop.example.com/product/1",
                          timeout=5, allow_redirects=True)
        assert r1.status_code == 200, f"Product page: {r1.status_code}"

        # Step 2: Add to cart
        r2 = requests.post("https://api.example.com/cart",
                           json={"product_id": 1, "quantity": 1},
                           timeout=5)
        assert r2.status_code == 201, f"Add to cart: {r2.status_code}"

        # Step 3: Initiate checkout (no real payment)
        r3 = requests.post("https://api.example.com/checkout/preview",
                           json={"cart_id": r2.json()["cart_id"]},
                           timeout=5)
        assert r3.status_code == 200, f"Checkout: {r3.status_code}"

        duration = time.time() - start
        SYNTHETIC_LATENCY.labels(
            service="checkout", region=region, journey=journey
        ).set(duration)
        SYNTHETIC_SUCCESS.labels(
            service="checkout", region=region, journey=journey
        ).inc()

    except Exception as e:
        SYNTHETIC_FAILURE.labels(
            service="checkout", region=region,
            journey=journey, reason=type(e).__name__
        ).inc()
        # This fires the alert: synthetic_check_failure_total > 0
        raise

run_checkout_journey("us-east-1")
```

---

#### Phase 2: Triage

Triage happens in the first 2–5 minutes after detection. The on-call engineer's sole objective is to answer three questions:

1. **Is this real?** (Not a false alarm, not a known planned event)
2. **How bad is it?** (Assign severity — see Section 4.3)
3. **Who else needs to know?** (Escalate based on severity)

Triage is not debugging. The on-call engineer who spends 20 minutes diagnosing the root cause during triage instead of declaring the severity and engaging the response team has made a costly mistake — every minute of diagnostic delay is a minute more of user impact.

```
Triage Decision Tree
──────────────────────────────────────────────────────────────
Alert fires
  │
  ▼
Is the system actually impacted?
  ├── No → Acknowledge + investigate alert quality (false alarm)
  └── Yes
        │
        ▼
      Are users impacted?
        ├── No → SEV3/SEV4 — monitor, investigate async
        └── Yes
              │
              ▼
            How many users / how much revenue?
              ├── >20% users or >$10k/min → SEV1 — declare incident NOW
              ├── 5–20% users or $1k-10k/min → SEV2 — declare incident
              └── <5% users or <$1k/min → SEV3 — declare incident
```

---

#### Phase 3: Response

Response is the active phase — the team is assembled, the war room is running, and the focus is on two parallel tracks:

**Track A: Mitigation** — Stop the bleeding. Restore service by any means, even if the root cause is unknown. Rollback, reroute, disable the feature, add capacity — whatever reduces user impact fastest.

**Track B: Investigation** — Identify what changed and where the failure is. Use the monitoring and tracing stack from Chapter 3.

The critical discipline: **mitigation first, root cause second.** Many incidents are prolonged because engineers pursue the elegant fix rather than the fast fix.

```
Response Priority Matrix
─────────────────────────────────────────────────────────────────
Action                           Time    Priority
─────────────────────────────────────────────────────────────────
Roll back recent deployment      2 min   ★★★★★ Try first, always
Toggle feature flag off          1 min   ★★★★★ If feature-flagged
Shift traffic to healthy region  5 min   ★★★★☆ If multi-region
Restart failing pods/services    3 min   ★★★★☆ Quick, low risk
Scale out (add capacity)         5 min   ★★★☆☆ If saturation cause
Apply config change              5 min   ★★★☆☆ If misconfiguration
Database failover                15 min  ★★★☆☆ High risk, last resort
Code hotfix + deploy             30 min  ★★☆☆☆ Only if no other path
─────────────────────────────────────────────────────────────────
```

---

#### Phase 4: Resolution

Resolution is declared when:
- User-facing error rates return to SLO baseline
- Latency returns to normal
- The monitoring system confirms stability (not just one data point — watch for 10–15 minutes)
- Any workarounds applied are documented (e.g., "feature X is disabled")

**Do not declare resolution prematurely.** A common mistake is closing the incident as soon as the alert stops firing — only for it to re-open 10 minutes later. Resolution requires sustained recovery, not a single clean data point.

```yaml
# Incident resolution checklist
resolution_checklist:
  service_health:
    - [ ] Error rate below SLO threshold for 10+ consecutive minutes
    - [ ] P99 latency within normal range for 10+ minutes
    - [ ] Traffic volume returning to expected levels
    - [ ] No active SLO burn rate alerts

  operational:
    - [ ] All workarounds documented in incident ticket
    - [ ] Disabled features / flags documented with owner
    - [ ] Any temporary config changes noted for rollback plan
    - [ ] Affected customers identified (for comms team)

  handoff:
    - [ ] Incident ticket updated with resolution summary
    - [ ] On-call log updated
    - [ ] Post-mortem scheduled (within 48h for SEV1/SEV2)
    - [ ] Stakeholder notification sent (resolution confirmed)
```

---

#### Phase 5: Review (Post-Mortem)

The post-mortem is covered in depth in Chapter 9. In the context of the lifecycle: every SEV1 and SEV2 incident requires a blameless post-mortem within 48 hours of resolution. SEV3 incidents may use a lightweight retrospective. SEV4 incidents should be logged but may not require a full post-mortem.

The output is not a blame document — it is a learning document and an action item registry.

---

### 4.3 Severity Classification {#43-severity-classification}

Severity classification is the most consequential decision made in the first minutes of an incident. Too low: critical issues receive slow, under-resourced responses. Too high: engineers cry wolf, alert fatigue sets in, and real SEV1s get delayed responses because "the last three SEV1s were nothing."

The framework must be **objective** (based on measurable impact, not gut feel), **fast to apply** (triage takes 2–5 minutes, not 20), and **business-aligned** (tied to revenue, users, and SLA obligations).

#### Standard Severity Framework

```
┌──────┬──────────────────────┬────────────────────┬───────────────────┬────────────────────┐
│ SEV  │ User Impact          │ Business Impact    │ Response          │ Escalation         │
├──────┼──────────────────────┼────────────────────┼───────────────────┼────────────────────┤
│  1   │ Complete outage or   │ >$10k/min revenue  │ Immediate — all   │ VP Eng + exec team │
│      │ >50% users impacted  │ loss, SLA breach   │ hands on deck,    │ notified within    │
│      │ on core service      │ imminent           │ war room active   │ 15 minutes         │
├──────┼──────────────────────┼────────────────────┼───────────────────┼────────────────────┤
│  2   │ Significant degraded │ $1k-$10k/min,      │ Urgent — primary  │ Eng Manager +      │
│      │ experience, 10–50%   │ core feature       │ on-call + 1-2     │ Product notified   │
│      │ users affected       │ broken             │ SMEs engaged      │ within 30 minutes  │
├──────┼──────────────────────┼────────────────────┼───────────────────┼────────────────────┤
│  3   │ Minor degradation,   │ <$1k/min, non-core │ Standard — on-    │ Team lead notified │
│      │ <10% users or        │ feature affected   │ call investigates │ during business    │
│      │ workaround exists    │                    │ during shift      │ hours              │
├──────┼──────────────────────┼────────────────────┼───────────────────┼────────────────────┤
│  4   │ Cosmetic, no user    │ Minimal — internal │ Scheduled — fix   │ Ticket created,    │
│      │ workflow broken      │ tools, logging,    │ in next sprint    │ no escalation      │
│      │                      │ monitoring         │                   │                    │
└──────┴──────────────────────┴────────────────────┴───────────────────┴────────────────────┘
```

**Severity escalation rule:** When in doubt, declare higher and downgrade. It is far better to convene an unnecessary war room than to miss a SEV1 response window because an engineer classified it SEV3.

#### SLA-Driven Severity Thresholds

For organizations with contractual SLAs, severity must map directly to SLA obligations:

```python
# Severity auto-classification based on SLA thresholds
# Run this logic in your incident management system (PagerDuty, Opsgenie, etc.)

SLA_TIERS = {
    "enterprise": {
        "availability_sla": 0.9999,   # 99.99%
        "response_time_sev1": "15min",
        "resolution_time_sev1": "4h",
    },
    "business": {
        "availability_sla": 0.999,    # 99.9%
        "response_time_sev1": "30min",
        "resolution_time_sev1": "8h",
    },
    "standard": {
        "availability_sla": 0.995,    # 99.5%
        "response_time_sev1": "2h",
        "resolution_time_sev1": "24h",
    }
}

def classify_severity(
    error_rate: float,
    affected_user_pct: float,
    revenue_impact_per_min: float,
    customer_tier: str
) -> int:
    """Auto-classify incident severity."""
    if customer_tier == "enterprise":
        # Any degradation for enterprise = SEV2 minimum
        if error_rate > 0.0:
            return min(2, classify_by_impact(error_rate, affected_user_pct,
                                             revenue_impact_per_min))
    return classify_by_impact(error_rate, affected_user_pct, revenue_impact_per_min)

def classify_by_impact(error_rate, affected_pct, revenue_per_min) -> int:
    if affected_pct > 0.50 or revenue_per_min > 10_000:
        return 1
    if affected_pct > 0.10 or revenue_per_min > 1_000:
        return 2
    if affected_pct > 0.01 or revenue_per_min > 100:
        return 3
    return 4
```

---

### 4.4 ITSM Frameworks — ITIL, NIST, and SRE {#44-itsm-frameworks}

**IT Service Management (ITSM)** frameworks provide structured processes for managing IT services. SREs inherit vocabulary and some processes from these frameworks while adapting them for software-first, high-velocity environments.

#### ITIL 4 — The Dominant ITSM Framework

ITIL (Information Technology Infrastructure Library) is the most widely adopted ITSM framework, now in version 4. Its incident management process maps closely to SRE practice:

| ITIL 4 Term | SRE Equivalent | Key Difference |
|---|---|---|
| Incident | Incident | ITIL is ITSM-broad; SRE is code-specific |
| Problem Management | Root Cause Analysis | SRE adds blameless culture |
| Change Management | Deployment pipeline / PRR | SRE automates change approval |
| Service Level Agreement | SLA | SRE adds SLO (internal target) and SLI (metric) |
| Configuration Management DB | Service Catalog / CMDB | SRE uses code-driven service registry |
| Major Incident | SEV1 | Near-identical process |

**Where SRE diverges from ITIL:**
- ITIL assumes a manual, ticket-driven workflow. SRE automates wherever possible.
- ITIL's change management process involves approval boards and change advisory boards (CABs). SRE replaces most CAB approvals with automated CI/CD gates and canary deployments.
- ITIL does not enforce an engineering time cap. SRE requires ≤50% toil.

#### NIST Incident Response Framework

For organizations in regulated industries (finance, healthcare, government), the **NIST SP 800-61** Computer Security Incident Handling Guide provides the compliance-aligned framework:

```
NIST IR Lifecycle          SRE Mapping
──────────────────────────────────────────────
1. Preparation             On-call setup, runbooks, game days
2. Detection & Analysis    Monitoring, alerting, triage
3. Containment             Mitigation (rollback, isolation)
4. Eradication             Root cause removal
5. Recovery                Service restoration, monitoring
6. Post-Incident Activity  Post-mortem, action items
──────────────────────────────────────────────
```

The NIST framework adds a **Containment** phase that SRE's pure recovery model sometimes glosses over — particularly important for security incidents where isolating the blast radius (stopping lateral movement) precedes restoration.

---

### 4.5 Roles in Incident Response {#45-roles-in-incident-response}

Clarity of roles is the single most impactful process change an organization can make to improve incident response. When roles are ambiguous, multiple engineers attempt the same diagnostic, no one is communicating with stakeholders, and the incident commander is simultaneously debugging and writing status updates.

#### The Five Core Roles

```
┌──────────────────────────────────────────────────────────────────┐
│                   Incident Response Roles                        │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │           INCIDENT COMMANDER (IC)                        │   │
│  │  Owns the incident. Coordinates all activity.            │   │
│  │  Makes final decisions. Does NOT debug.                  │   │
│  └──────────────────┬───────────────────────────────────────┘   │
│                     │                                            │
│         ┌───────────┼──────────────────┐                        │
│         ▼           ▼                  ▼                        │
│  ┌──────────┐ ┌──────────────┐ ┌──────────────┐                │
│  │ COMMS    │ │ TECH LEAD    │ │ SCRIBE       │                │
│  │ LEAD     │ │ (CL)         │ │ (SL)         │                │
│  │          │ │              │ │              │                │
│  │ Owns all │ │ Leads debug  │ │ Documents    │                │
│  │ external │ │ + mitigation │ │ timeline,    │                │
│  │ & internal│ │ work         │ │ actions,     │                │
│  │ comms    │ │              │ │ decisions    │                │
│  └──────────┘ └──────┬───────┘ └──────────────┘                │
│                      │                                           │
│               ┌──────┘                                           │
│               ▼                                                  │
│  ┌────────────────────────────┐                                 │
│  │  SUBJECT MATTER EXPERTS    │                                 │
│  │  (SMEs) — as needed        │                                 │
│  │  Database, network, infra  │                                 │
│  │  experts pulled in by CL   │                                 │
│  └────────────────────────────┘                                 │
└──────────────────────────────────────────────────────────────────┘
```

#### Role Responsibilities in Detail

**Incident Commander (IC)**
The IC owns the incident end-to-end. They are the decision-maker and coordinator, not the debugger.

Responsibilities:
- Declare incident severity and initiate the response process
- Assign and confirm all other roles are filled
- Set investigation direction: "Focus on the checkout API, not the database — we need to determine if this is upstream or downstream first"
- Make mitigation calls: "We're rolling back v2.4.1. [Tech Lead], execute the rollback now."
- Drive the incident toward resolution; if no progress in 20 minutes, escalate or change approach
- Declare resolution and initiate post-mortem process

**What the IC must NOT do:** Debug. The moment the IC opens a terminal and starts running queries, the incident loses coordination. There is no longer anyone managing the overall response.

```
IC Communication Pattern (every 10–15 minutes)
────────────────────────────────────────────────────────────────
"Status check at 14:47.
 Checkout errors at 4.2%, up from 1.2% at 14:30.
 CL is investigating payment service — ETA on findings: 5 min.
 Comms Lead has sent customer status page update.
 Scribe: confirm the rollback attempt at 14:38 is documented.
 Next status check at 15:00."
────────────────────────────────────────────────────────────────
```

**Communications Lead (Comms Lead)**
Owns all communication — internal (to leadership, stakeholders) and external (status page, customer notifications). This role completely removes the communication burden from technical responders.

- Posts status page updates every 15–30 minutes during active SEV1/SEV2
- Sends internal Slack updates to #incidents channel
- Drafts customer emails for customer success team
- Manages executive escalation — ensures VP/C-suite receive updates without interrupting the response team

**Tech Lead (CL)**
Leads the technical investigation and mitigation. Coordinates SMEs. Reports findings to the IC.

**Scribe (SL)**
Maintains a real-time incident timeline in the incident ticket. Every significant action, observation, and decision is logged with a timestamp.

```
Scribe Timeline Example (excerpt)
─────────────────────────────────────────────────────────────
14:23 — Alert fired: checkout error rate 2.1% (SLO: 0.5%)
14:24 — On-call (Sarah) acknowledged. Triage begun.
14:26 — SEV2 declared. War room opened. IC: Sarah. CL: James.
14:28 — Comms Lead (Priya) joined. Status page updated to "Investigating."
14:31 — CL James: "Error concentrated on /api/checkout/complete endpoint.
         Payment service returning HTTP 503."
14:33 — Payment service on-call (Tom) paged. Joined at 14:35.
14:38 — Rollback of payment-service v3.1.2 → v3.1.1 initiated.
14:41 — Error rate declining: 2.1% → 1.4% → 0.8% → 0.3%
14:47 — Error rate at 0.2%. Within SLO.
14:55 — Error rate stable at 0.1% for 8 minutes.
15:02 — IC declared resolution. Status page updated to "Resolved."
15:03 — Post-mortem scheduled for Wednesday 10am.
─────────────────────────────────────────────────────────────
```

---

### 4.6 Runbooks — Encoding Operational Knowledge {#46-runbooks}

A runbook is a documented, step-by-step procedure for responding to a specific operational event. The best runbooks encode the hard-won knowledge of your most experienced engineers in a format that any competent engineer can execute at 3am, under stress, with incomplete context.

**The runbook quality test:** Hand the runbook to a junior engineer who has never seen the system. Can they execute it correctly and safely without calling anyone? If not, the runbook needs work.

#### Runbook Structure

```markdown
# Runbook: Checkout Service — High Error Rate

**Alert Name:** CheckoutAvailabilityCritical
**Severity:** SEV1/SEV2
**Last Reviewed:** 2024-01-15
**Owner:** @checkout-team
**Escalation:** #checkout-oncall → @james.chen → checkout-vp

---

## Quick Context

The checkout service handles the final payment confirmation step.
Error spikes here directly impact revenue. This runbook covers the
most common causes, which account for ~80% of checkout error incidents.

---

## Step 1: Confirm and Classify (2 minutes)

1.1 Open the [Checkout SLO Dashboard](https://grafana.internal/checkout-slo)
    Verify: Error rate > 0.5%? Confirm this is not a false alarm.

1.2 Check the [deployment log](https://deploy.internal/checkout)
    Was there a deployment in the last 2 hours?
    → YES: Go to Step 2A (Rollback Path)
    → NO: Go to Step 2B (Investigation Path)

---

## Step 2A: Rollback Path (if recent deployment)

> ⚠️ Only proceed if CL or IC has confirmed rollback decision.

2A.1 Identify the previous stable version:
     ```bash
     kubectl -n production rollout history deployment/checkout
     ```

2A.2 Execute rollback:
     ```bash
     kubectl -n production rollout undo deployment/checkout
     ```

2A.3 Monitor recovery — watch error rate on dashboard.
     Expected recovery time: 2–5 minutes.
     If no improvement in 5 minutes → proceed to Step 2B.

---

## Step 2B: Investigation Path

2B.1 Check upstream dependency health:
     ```bash
     # Payment service health
     curl -s https://payment-service.internal/health | jq .

     # Inventory service health
     curl -s https://inventory-service.internal/health | jq .
     ```

2B.2 Check recent error logs (last 15 minutes):
     ```bash
     # In Kibana: index=prod-checkout level=ERROR last 15min
     # Or via kubectl:
     kubectl -n production logs -l app=checkout --since=15m \
       | grep ERROR | tail -50
     ```

2B.3 Open distributed traces for failing requests:
     → [Jaeger: checkout errors last 15 min](https://jaeger.internal/?service=checkout&tags=error%3Dtrue)
     Look for: which downstream span is failing?

2B.4 Match symptoms to known failure patterns:
     | Symptom                        | Likely Cause          | Go To   |
     |--------------------------------|-----------------------|---------|
     | Payment service 503s           | Payment service down  | Step 3A |
     | DB connection timeout          | Pool exhaustion       | Step 3B |
     | 429 Too Many Requests          | Rate limit hit        | Step 3C |
     | Latency spike without errors   | Slow dependency       | Step 3D |

---

## Step 3A: Payment Service Downstream Failure

3A.1 Check payment service status: [Status Dashboard](https://grafana.internal/payment-slo)
3A.2 If payment service is down, page payment on-call:
     ```
     /pd page payment-oncall "Checkout blocked on payment service — SEV2"
     ```
3A.3 Enable checkout degraded mode (show "try again later" instead of error):
     ```bash
     kubectl -n production set env deployment/checkout \
       PAYMENT_FALLBACK_MODE=true
     ```
3A.4 Notify IC of status and action taken.

---

## Escalation

If no resolution within 30 minutes, escalate to:
- @james.chen (checkout tech lead)
- @tom.riley (payment service lead)
- Engineering Manager via PagerDuty escalation policy

---

## Post-Incident

After resolution:
- [ ] Document what you found in the incident ticket
- [ ] Note any manual changes made (env vars, config changes)
- [ ] Reset PAYMENT_FALLBACK_MODE if enabled:
      `kubectl -n production set env deployment/checkout PAYMENT_FALLBACK_MODE-`
- [ ] Confirm monitoring shows stable recovery for 10+ minutes
```

#### Runbook Automation

The highest-value investment in runbook quality is **partial automation** — converting diagnostic and mitigation steps into scripts that the on-call engineer runs with a single command, reducing error and cognitive load.

```bash
#!/bin/bash
# checkout-diagnose.sh — automated first-responder diagnostic
# Usage: ./checkout-diagnose.sh
# Performs all Step 2B checks automatically and prints a triage report

set -euo pipefail

NAMESPACE="production"
SERVICE="checkout"

echo "======================================"
echo "  Checkout Diagnostic Report"
echo "  $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "======================================"

echo ""
echo "--- Recent Deployments (last 2 hours) ---"
kubectl -n $NAMESPACE rollout history deployment/$SERVICE | head -5

echo ""
echo "--- Pod Status ---"
kubectl -n $NAMESPACE get pods -l app=$SERVICE \
  --sort-by='.status.startTime' | tail -10

echo ""
echo "--- Error Rate (last 5 min via Prometheus) ---"
curl -s "http://prometheus.internal/api/v1/query" \
  --data-urlencode 'query=sum(rate(http_requests_total{service="checkout",status_code=~"5.."}[5m])) / sum(rate(http_requests_total{service="checkout"}[5m]))' \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'{float(d[\"data\"][\"result\"][0][\"value\"][1]):.2%}')"

echo ""
echo "--- Upstream Dependency Health ---"
for dep in payment-service inventory-service cart-service; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    "https://$dep.internal/health" --max-time 3 || echo "TIMEOUT")
  echo "  $dep: HTTP $STATUS"
done

echo ""
echo "--- Recent Error Logs (last 20) ---"
kubectl -n $NAMESPACE logs -l app=$SERVICE --since=15m \
  | grep -i error | tail -20 || echo "No error logs found."

echo ""
echo "======================================"
echo "  Diagnostic complete. Review above."
echo "======================================"
```

---

### 4.7 The War Room — Command and Control {#47-war-room}

A **war room** is the coordinated, real-time communication space where the incident response team operates. It is not a physical room (though it can be) — in modern distributed teams, it is a dedicated video call or chat channel with defined structure.

#### War Room Principles

**1. One voice — the IC.** The IC controls the cadence of communication in the war room. When multiple engineers shout observations simultaneously, signal-to-noise collapses and the IC loses control of the response.

**2. Separate channels for separate concerns.**

```
Communication Channel Architecture
────────────────────────────────────────────────────────────
#incident-<id>-response    → Technical discussion, investigation
#incident-<id>-timeline    → Scribe updates only (no discussion)
#incident-<id>-comms       → External communication drafts
#incidents                 → All incidents summary (automated)
Leadership DM thread       → Executive updates (Comms Lead only)
────────────────────────────────────────────────────────────
```

**3. Observation sharing protocol.** When engineers make observations, they use a structured format to avoid noise:

```
Observation Protocol
─────────────────────────────────────────────────────
[OBSERVATION] Payment service returning 503 — confirmed
              in traces for 14:31–14:42. Not a fluke.
[HYPOTHESIS]  New deployment of payment v3.1.2 at 14:28
              may have introduced a connection pool regression.
[ACTION]      Initiating rollback of payment to v3.1.1.
              ETA: 3 minutes. IC please confirm.
─────────────────────────────────────────────────────
```

**4. Time-box investigation sprints.** If a diagnostic avenue yields nothing in 10 minutes, the IC calls it and redirects. Sunk cost fallacy is common in incidents — engineers keep digging down a dead-end rabbit hole because they've already spent 20 minutes there.

**5. The "15-minute rule."** If the incident is not improving 15 minutes after the response team is assembled, escalate immediately. Do not wait for the full hour.

---

### 4.8 Communication Protocols {#48-communication-protocols}

Incident communication is a distinct skill from technical response. Poor communication during a major incident — vague status updates, delayed executive notifications, inconsistent customer messaging — can cause as much reputational and financial damage as the incident itself.

#### Internal Communication

**Stakeholder notification matrix:**

| Severity | Who | When | Channel | Content |
|---|---|---|---|---|
| SEV1 | Engineering VP | Within 15 min | Phone + Slack DM | Severity, impact, response status |
| SEV1 | CTO/CEO | Within 30 min | Slack DM | Business impact summary |
| SEV1/2 | Product Manager | Within 20 min | Slack | User impact, ETA |
| SEV1/2 | Customer Success | Within 15 min | Slack | Customer impact, talking points |
| SEV3/4 | Team Lead | Within 1 hour | Slack | Technical summary |

**Internal status update template (every 15–30 min during active SEV1):**

```
🔴 [SEV1 UPDATE] Checkout Service — 14:45 UTC

IMPACT: ~15% of checkout attempts failing. Est. $2,300/min revenue impact.
STATUS: Investigating root cause. Payment service rollback in progress.
ETA TO RESOLUTION: ~10 minutes (rollback completing now)
NEXT UPDATE: 15:00 UTC or on significant change.

IC: @sarah.li | CL: @james.chen | Incident: INC-2024-0847
```

#### External Communication — Status Page Protocol

The status page is your primary external communication channel. It must be updated within 15 minutes of a SEV1/SEV2 declaration — before customers flood support channels.

```
Status Page Update Lifecycle
─────────────────────────────────────────────────────────────────────
T+0  (detection)     → No update yet
T+5  (SEV declared)  → "We are investigating reports of issues
                         with our checkout service."
T+20 (root cause id) → "We have identified the cause of the checkout
                         issue and are working on a fix.
                         Users may experience errors during checkout."
T+45 (mitigation)    → "A fix has been deployed. We are monitoring
                         for full recovery."
T+60 (resolved)      → "This incident has been resolved.
                         Checkout service is fully operational.
                         We will publish a post-mortem within 72 hours."
─────────────────────────────────────────────────────────────────────
```

**Status page writing rules:**
- Write in plain English. Avoid technical jargon ("BGP misconfiguration" means nothing to customers).
- Never speculate on cause until confirmed — "We are investigating" is sufficient.
- Never promise an ETA you're not confident about. A missed ETA erodes trust more than no ETA.
- Always acknowledge impact honestly. Downplaying impact destroys trust when customers see the full story in the post-mortem.

---

### 4.9 Risk Registers {#49-risk-registers}

A **risk register** is a living document that captures known risks to service reliability — risks that haven't yet become incidents but could. It is the SRE team's forward-looking reliability work surface.

Maintaining a risk register prevents the all-too-common pattern where a team knows about a "ticking time bomb" — a single point of failure, an underfunded dependency, a database that has never been tested for failover — and it never gets prioritized until it becomes a SEV1 at the worst possible moment.

#### Risk Register Schema

```yaml
# risk_register.yml
# Updated: quarterly (or after every SEV1)

risks:
  - id: RISK-001
    title: "Payment service database — no read replica for failover"
    service: payment-service
    category: single_point_of_failure
    description: |
      The payment service uses a single PostgreSQL primary with no read
      replica. A primary failure would cause complete payment outage with
      estimated RTO of 45–90 minutes (manual failover required).
    likelihood: 3          # 1 (rare) → 5 (frequent)
    impact: 5              # 1 (cosmetic) → 5 (complete outage)
    risk_score: 15         # likelihood × impact
    revenue_at_risk_per_hour: 420000
    last_incident_caused: null
    owner: "@tom.riley"
    mitigation_status: in_progress
    mitigation_plan: |
      Q1 2024: Provision read replica and configure streaming replication.
      Q1 2024: Implement automated failover with Patroni.
      Q2 2024: Conduct failover GameDay.
    target_completion: "2024-03-31"
    residual_risk_score: 6  # After mitigation

  - id: RISK-002
    title: "Search service — no circuit breaker on product catalog dependency"
    service: search-service
    category: cascade_failure_risk
    description: |
      Search service calls product catalog synchronously with no circuit
      breaker. Catalog slowness (>500ms) cascades to search page load
      times. During Black Friday 2023, this caused 8min of search
      degradation when catalog DB had a spike.
    likelihood: 4
    impact: 3
    risk_score: 12
    revenue_at_risk_per_hour: 85000
    last_incident_caused: "INC-2023-1102"
    owner: "@alice.wang"
    mitigation_status: planned
    mitigation_plan: |
      Implement circuit breaker (Resilience4j) on catalog dependency.
      Add 500ms timeout + cached fallback for catalog calls.
    target_completion: "2024-02-15"
    residual_risk_score: 4
```

#### Risk Register Review Process

```
Risk Register Review Cadence
──────────────────────────────────────────────────────────────
Weekly      → Add new risks identified from incidents or PRRs
Monthly     → Review top 5 risks (highest risk_score) in SRE meeting
Quarterly   → Full register review, re-score all risks,
              remove mitigated risks, add new ones
Post-SEV1   → Mandatory: add risk for each new failure mode discovered
Pre-launch  → Review risks touching any service in launch scope
──────────────────────────────────────────────────────────────
```

**Risk scoring visualization — the risk matrix:**

```
IMPACT
  5 │ ░░ ▒▒ ▒▒ ▓▓ ██
    │ ░░ ▒▒ ▓▓ ██ ██
  3 │ ░░ ░░ ▒▒ ▓▓ ██   ██ Critical  (15–25) → immediate action
    │ ░░ ░░ ▒▒ ▒▒ ▓▓   ▓▓ High      (10–14) → this quarter
  1 │ ░░ ░░ ░░ ░░ ▒▒   ▒▒ Medium    (5–9)   → this half
    └─────────────────   ░░ Low       (1–4)   → backlog
      1   2   3   4   5
              LIKELIHOOD
```

---

### 4.10 Failure Mode Analysis and Mitigation Strategies {#410-failure-mode-analysis}

Where the risk register captures known risks qualitatively, **Failure Mode and Effects Analysis (FMEA)** provides a systematic method for discovering failure modes — particularly in new systems or before major launches.

FMEA asks: for every component of this system, what can fail, what is the effect on users, and what is the risk?

#### FMEA Applied: E-Commerce Checkout Service

```
FMEA — Checkout Service (Critical Path Only)
──────────────────────────────────────────────────────────────────────────────────
Component       Failure Mode          Effect               L  I  RPN  Mitigation
──────────────────────────────────────────────────────────────────────────────────
Load Balancer   Misconfigured health  All traffic to       2  5  10   Health check
                check removes all     bad instances;            test in staging;
                healthy backends      complete outage           blue/green deploy

API Gateway     Rate limit too low    Legitimate users     3  4  12   Tune limits
                                      receive 429 during        with load tests;
                                      traffic spikes            circuit breaker

Auth Service    JWT signing key       All users logged     2  5  10   Key rotation
                rotation without      out; 401 storm            procedure tested;
                grace period          on checkout               overlap window

Cart Service    Session store (Redis) Cart data lost;      3  4  12   Cart persisted
                eviction under        users must re-add         to DB as fallback;
                memory pressure       items                     eviction policy

Payment API     Third-party timeout   Order placement      4  5  20   Circuit breaker
(Stripe/Braintree)(>30s)             fails; user charged        + idempotency key
                                      but order not created     + retry queue

Inventory DB    Primary DB failure    Cannot confirm       2  5  10   Read replica;
                                      stock; checkout           automated failover
                                      blocked                   tested in GameDay

Order Service   Deadlock under high   Order creation       2  4   8   Deadlock
                concurrency           blocked; timeout          detection; retry
                                      errors                    with backoff

Email Service   Queue backup          Order confirmation   4  2   8   Async queue;
(SES/SendGrid)  during high volume    emails delayed            decouple from
                                      hours/days                order flow
──────────────────────────────────────────────────────────────────────────────────
L=Likelihood(1-5), I=Impact(1-5), RPN=Risk Priority Number (L×I)
```

**RPN prioritization:** Address RPN ≥ 15 before launch. Review 10–14 this quarter. Log < 10 in the risk register.

#### Common Failure Patterns and Standard Mitigations

Every distributed system exhibits a small set of recurring failure patterns. SREs build a pattern library — recognizing a pattern instantly during an incident saves critical minutes.

```
Failure Pattern Library
────────────────────────────────────────────────────────────────────────
Pattern             Signature                  Mitigation
────────────────────────────────────────────────────────────────────────
Cascading Failure   One service fails;         Circuit breakers;
                    all dependents fail;       bulkheads; timeouts;
                    system-wide outage         graceful degradation

Thundering Herd     Cache expires; all         Cache stampede
                    requests hit DB            prevention (mutex lock,
                    simultaneously             jitter, probabilistic
                                               early refresh)

Retry Storm         Clients retry failed       Exponential backoff +
                    requests immediately;      jitter; retry budgets;
                    overwhelm recovering       circuit breaker on
                    service                    client side

Memory Leak         Memory grows slowly;       Heap profiling (pprof,
                    OOM kill after days;       async-profiler);
                    periodic crashes           memory limits +
                                               restart policy

Split Brain         Network partition;         Consensus algorithms
                    two nodes both think       (Raft, Paxos);
                    they're primary;           fencing tokens;
                    data corruption            STONITH

Noisy Neighbor      Shared infrastructure;     Resource quotas/limits;
                    one tenant consumes        dedicated resources
                    all resources; others      for critical services;
                    starved                    tenant isolation

Configuration       Config change pushed;      Canary config deploy;
Poisoning           all instances pick up      config validation in
                    bad config simultaneously  CI; emergency override
────────────────────────────────────────────────────────────────────────
```

#### Circuit Breaker Pattern — Implementation

The circuit breaker is one of the most important reliability patterns for preventing cascade failures:

```python
# Circuit breaker implementation using the 'pybreaker' library
# Prevents cascading failures when a downstream dependency is unhealthy

import pybreaker
import requests
import logging

logger = logging.getLogger(__name__)

# Circuit breaker configuration
# Opens after 5 consecutive failures
# Attempts reset after 30 seconds in open state
payment_breaker = pybreaker.CircuitBreaker(
    fail_max=5,
    reset_timeout=30,
    name="payment-service",
    listeners=[pybreaker.CircuitBreakerListener()]  # For metrics/logging
)

class PaymentCircuitBreakerListener(pybreaker.CircuitBreakerListener):
    def state_change(self, cb, old_state, new_state):
        logger.warning(
            "circuit_breaker_state_change",
            extra={
                "breaker": cb.name,
                "old_state": str(old_state),
                "new_state": str(new_state),
                "fail_counter": cb.fail_counter,
            }
        )
        # Emit metric for alerting
        # circuit_breaker_state{name="payment-service", state="open"} 1

@payment_breaker
def call_payment_service(order_id: str, amount: float) -> dict:
    """Call payment service — protected by circuit breaker."""
    response = requests.post(
        "https://payment.internal/charge",
        json={"order_id": order_id, "amount": amount},
        timeout=(2, 10)
    )
    response.raise_for_status()
    return response.json()

def process_payment(order_id: str, amount: float) -> dict:
    """Process payment with fallback when circuit is open."""
    try:
        return call_payment_service(order_id, amount)

    except pybreaker.CircuitBreakerError:
        # Circuit is OPEN — payment service is down
        logger.error("payment_circuit_open", extra={"order_id": order_id})
        # Fallback: queue for async retry
        queue_payment_async(order_id, amount)
        return {
            "status": "queued",
            "message": "Payment is being processed. "
                       "You will receive a confirmation email shortly.",
            "order_id": order_id
        }

    except requests.exceptions.Timeout:
        logger.error("payment_timeout", extra={"order_id": order_id})
        raise PaymentTimeoutError("Payment service timed out")
```

---

### 4.11 Incident Metrics — Measuring Response Effectiveness {#411-incident-metrics}

Incident management is only improvable if it is measurable. Track these metrics monthly and review them in SRE team retrospectives:

| Metric | Definition | Target | Warning |
|---|---|---|---|
| **MTTD** | Mean Time to Detect — alert fires to on-call aware | < 5 min | > 15 min |
| **MTTA** | Mean Time to Acknowledge — alert fires to acknowledged | < 2 min | > 5 min |
| **MTTE** | Mean Time to Engage — alert to full response team assembled | < 10 min (SEV1) | > 20 min |
| **MTTM** | Mean Time to Mitigate — incident start to user impact reduced | < 30 min (SEV1) | > 60 min |
| **MTTR** | Mean Time to Resolve — incident start to full resolution | < 2h (SEV1) | > 4h |
| **Incident Rate** | Incidents per service per month | Trending down | Trending up |
| **Repeat Incident Rate** | % of incidents caused by a previously seen failure mode | < 10% | > 25% |
| **Action Item Closure Rate** | % of post-mortem actions completed within 30 days | > 80% | < 50% |

```promql
# MTTR calculation over the last 90 days (Prometheus recording rule)
# Assumes incident_start_timestamp and incident_end_timestamp metrics
# from your incident management system

avg(
  incident_resolution_duration_seconds{severity="SEV1"}
) / 60
# Result in minutes
```

---

### 4.12 Incident Management Tooling {#412-incident-management-tooling}

| Tool | Category | SRE Use Case |
|---|---|---|
| **PagerDuty** | On-call + Incident | Alert routing, escalation, incident workflow, postmortem |
| **OpsGenie** | On-call + Incident | Alternative to PagerDuty; strong ITSM integrations |
| **Incident.io** | Incident Management | Slack-native incident workflow, timeline, postmortem |
| **FireHydrant** | Incident Management | Automated incident declaration, runbook integration |
| **Statuspage (Atlassian)** | Customer Comms | Customer-facing status page with component-level status |
| **Jira Service Management** | ITSM | ITIL-aligned ticket management + incident tracking |
| **Confluence** | Documentation | Runbook hosting, post-mortem storage, risk register |
| **Slack / Teams** | War Room | Real-time incident coordination channels |
| **Blameless** | SRE Platform | End-to-end incident + SLO + post-mortem platform |

---

## Key Principles & Best Practices {#key-principles}

1. **Declare early, downgrade late.** Severity declaration should err high. The cost of an unnecessary SEV1 response is one war room. The cost of a missed SEV1 is uncontrolled user impact, SLA breach, and reactive firefighting.

2. **Mitigation beats root cause during active incidents.** The goal of response is restoring service. Root cause analysis is for the post-mortem. An engineer who delays rollback to find the exact bug is optimizing for the wrong outcome.

3. **Roles must be explicitly confirmed, not assumed.** At the start of every SEV1 war room, the IC confirms each role is filled by name. "I'm assuming Sarah is our Comms Lead" is how status updates never get posted.

4. **Runbooks must be executable by a median engineer at 3am.** If the runbook requires tribal knowledge, institutional memory, or a call to the original author, it is incomplete.

5. **Risk registers must be living documents.** A risk register that is updated annually is a historical document, not a risk management tool. Update it after every SEV1, every PRR, and every quarter.

6. **Track repeat incidents relentlessly.** A recurring incident is evidence that post-mortem action items are not being completed. If the same failure mode produces a second incident, that is a process failure, not just a technical failure.

7. **Post-mortems are the most valuable output of every incident.** The incident itself is expensive. The post-mortem converts that cost into organizational learning. A post-mortem with no follow-through is the worst possible outcome — the cost of the incident plus the cost of the post-mortem, with no benefit.

---

## Tools & Technologies {#tools}

| Tool | Category | SRE Use Case |
|---|---|---|
| **PagerDuty** | Alerting + On-call | Escalation policies, incident timelines, analytics |
| **Incident.io** | Incident workflow | Slack-native declare/update/resolve with auto-timeline |
| **Statuspage** | External comms | Customer-facing status with component granularity |
| **Confluence** | Runbook hosting | Structured runbook templates, searchable knowledge base |
| **Jira** | Incident tracking | SEV1/2 tickets, action item tracking, SLA timers |
| **Grafana OnCall** | On-call scheduling | Open-source PagerDuty alternative, Grafana-native |
| **VictorOps (Splunk)** | Incident management | Timeline-centric incident coordination |
| **Blameless** | SRE platform | SLO + incident + post-mortem in one platform |
| **Resilience4j** | Circuit breaker (JVM) | Circuit breaker, retry, bulkhead for Java/Kotlin services |
| **pybreaker** | Circuit breaker (Python) | Circuit breaker pattern for Python services |

---

## Hands-on Exercises / Labs {#labs}

### Lab 4.1 — Severity Classification Workshop

**Goal:** Build and calibrate a severity framework for a real or hypothetical service.

**Scenario:** You are the SRE lead for a B2B SaaS project management platform with the following profile:
- 50,000 business users (20,000 paying)
- Monthly recurring revenue: $2M
- SLA commitments: 99.9% for Business tier, 99.99% for Enterprise tier
- Core features: task management, file uploads, real-time notifications

**Tasks:**
1. Design a 4-level severity framework with specific, measurable thresholds for user impact, revenue impact, and feature scope. Include SEV1–SEV4 definitions.
2. Classify each of the following events with justification:
   - File upload endpoint returning 500 errors for 100% of requests
   - Real-time notifications delayed by 10 minutes for all users
   - Task creation failing for one enterprise customer's account
   - Dashboard loading in 8 seconds instead of 1 second for 30% of users
   - Internal admin panel unreachable (affects 5 internal ops staff)
3. Identify the gap in the standard framework for enterprise customers — and propose an override rule.

---

### Lab 4.2 — Runbook Writing Exercise

**Goal:** Write a production-grade runbook for a specific alert.

**Given alert definition:**
```yaml
- alert: DatabaseConnectionPoolExhausted
  expr: |
    pg_stat_activity_count{state="active"} /
    pg_settings_max_connections > 0.85
  for: 2m
  labels:
    severity: page
    service: checkout
  annotations:
    summary: "Checkout DB connection pool at {{ $value | humanizePercentage }}"
```

**Tasks:**
1. Write a complete runbook following the structure in Section 4.6. Include:
   - Context paragraph explaining the business impact
   - Triage steps (is this real? how bad is it?)
   - At minimum 3 diagnostic paths with decision branches
   - Specific `kubectl`, `psql`, and Prometheus commands for each step
   - Mitigation options (immediate + sustainable)
   - Escalation path
   - Post-incident checklist
2. Write the automated diagnostic script (`db-diagnose.sh`) that performs all triage checks automatically.
3. Apply the runbook quality test: identify any step that requires tribal knowledge and rewrite it to be self-contained.

---

### Lab 4.3 — Risk Register Construction

**Goal:** Build a risk register for a microservices architecture.

**Given system:** A ride-sharing platform with these services: user-service, driver-service, matching-service, payment-service, maps-service (Google Maps API), notification-service (Twilio SMS).

**Tasks:**
1. Identify at least 8 risks using the FMEA approach from Section 4.10.
2. Score each risk for likelihood (1–5), impact (1–5), and calculate RPN.
3. Produce a risk matrix visualization (ASCII) showing risk distribution.
4. Write full risk register entries (using the YAML schema from Section 4.9) for the top 3 risks by RPN.
5. Define the quarterly review process: who attends, what is reviewed, what constitutes a "closed" risk.

---

### Lab 4.4 — Incident Simulation (Tabletop Exercise)

**Goal:** Practice the complete incident lifecycle using a structured tabletop scenario.

**Setup:** Run this as a team exercise (can be done solo with written responses).

**Scenario:** It is 2:17am on a Friday. Your Black Friday sale launched 3 hours ago and traffic is 4× normal. The following events occur in sequence:

```
02:17 — PagerDuty: "CheckoutAvailabilityCritical — error rate 8.3%"
02:19 — You acknowledge. Dashboard shows: error rate 8.3%, P99 3,200ms,
         traffic 4× normal. Last deployment: 18 hours ago.
02:21 — Support Slack: "URGENT — customers tweeting checkout broken"
02:23 — CTO messages you: "What's happening?"
02:24 — Payment service on-call: "Our service looks healthy"
02:26 — DB DBA joins: "Connection pool at 94%"
02:31 — You scale checkout service from 10 → 20 pods
02:34 — Error rate: 8.3% → 5.1% → 2.8% → 0.9%
02:41 — Error rate stable at 0.4% for 7 minutes
```

**Tasks:**
1. Write the complete scribe timeline for this incident (every action, every timestamp, every person).
2. Write the status page updates you would have posted at T+5, T+15, T+25, and T+resolution.
3. Write the internal update you send to the CTO at 02:23.
4. Declare the severity and justify it.
5. Write the incident resolution notice at 02:48.
6. List the top 3 post-mortem action items you would expect from this incident.

---

## Common Pitfalls & Anti-patterns {#pitfalls}

**Anti-pattern 1: Debugging during triage**
The on-call engineer spends the first 20 minutes of a SEV1 investigating root cause before declaring severity or engaging the response team. Users are impacted for 20 minutes with no response coordination, no communication, no escalation. *Fix:* Triage has a 5-minute time box. Severity declared, roles assigned, war room opened — then investigate.

**Anti-pattern 2: The heroic lone responder**
One senior engineer handles the entire incident — debugging, communicating with stakeholders, posting status updates, and managing the war room simultaneously. They're exhausted, communication is erratic, and a 2-hour incident takes 5 hours. *Fix:* Enforce role separation from the first minute. Even a 2-person war room should have an IC and a Tech Lead.

**Anti-pattern 3: Runbooks as documentation rather than procedures**
The runbook describes the system architecture in detail but provides no actionable steps. "Check the payment service logs" with no command, no log location, no pattern to look for. *Fix:* Every runbook step must be a concrete action: "Run `kubectl -n production logs -l app=payment --since=15m | grep -i error`"

**Anti-pattern 4: Severity inflation**
Every incident is declared SEV1 because "better safe than sorry." Within 3 months, SEV1 no longer triggers urgency — it triggers eye-rolls. Engineers start slow-walking SEV1 responses because 80% have been false alarms. *Fix:* Calibrate severity thresholds quarterly using historical incident data. Celebrate appropriate downgrades, not heroics.

**Anti-pattern 5: Risk registers as shelf documents**
A beautiful risk register is built during an SRE transformation. It's updated once at launch, lives in Confluence, and is never reviewed again. Three years later, a risk that was identified at launch — and never mitigated — causes a SEV1. *Fix:* The risk register review must be a recurring calendar item with an owner and a deadline. Risks without mitigations and owners are not documented risks — they are documented negligence.

**Anti-pattern 6: Post-mortem theater**
Post-mortems are written, filed, and forgotten. Action items exist as Jira tickets that never get picked up. The same failure mode produces a second incident 4 months later. The post-mortem for the second incident references the first. *Fix:* Action items from post-mortems are first-class engineering work, tracked in the team sprint backlog, with owners and due dates. Uncompleted actions are escalated to the engineering manager.

---

## Interview Questions {#interview-questions}

**Conceptual:**

1. *"Walk me through the complete incident lifecycle, from detection to post-mortem. What is the most common place organizations fail?"*
   — Look for: 5-phase lifecycle; most common failure = debugging during triage, delaying severity declaration, poor role clarity; mitigation-first principle.

2. *"What is the difference between an Incident, a Problem, and a Change in ITSM terms? Why does the distinction matter for SRE practice?"*
   — Look for: incident = restore fast, problem = fix root cause permanently, change = planned modification; distinction drives different processes and response urgency.

3. *"Describe the Incident Commander role. What should the IC absolutely NOT do during a war room, and why?"*
   — Look for: IC coordinates and decides, does not debug; debugging by IC = loss of coordination, no status updates, no escalation management; clear role separation.

**Scenario-based:**

4. *"You're on-call at 2am. An alert fires: payment service error rate 15%. You open the dashboard and see the error spike began 8 minutes ago. Walk me through your next 15 minutes."*
   — Look for: acknowledge, check for recent deployments, triage (SEV1 — 15% payment errors), declare severity, open war room, assign roles, check rollback feasibility, post status update, engage payment SME, monitor mitigation — all within 15 minutes.

5. *"Your team has had 3 SEV2 incidents caused by the same database connection pool exhaustion in the last 2 months. The post-mortem action item — 'implement connection pooling' — has been in the backlog for 6 weeks without progress. What do you do?"*
   — Look for: escalate to engineering manager (third recurrence = process failure not just technical), add to risk register as high-RPN risk, tie it to business cost (revenue lost per incident × frequency), propose a spike/tech debt sprint, implement interim mitigation (pool size increase, alert threshold), set a firm deadline with IC sign-off.

---

## Further Reading & Resources {#further-reading}

**Books:**
- *Site Reliability Engineering* — Chapter 14: Managing Incidents (Google, O'Reilly) — The definitive SRE incident management framework
- *The Practice of Cloud System Administration* — Limoncelli, Chalup, Hogan — Practical operational process design
- *Incident Management for Operations* — Rob Schnepp et al. (O'Reilly) — Comprehensive incident command system for tech

**Online:**
- [Google SRE Book: Effective Troubleshooting](https://sre.google/sre-book/effective-troubleshooting/) — Systematic diagnostic methodology
- [PagerDuty Incident Response Guide](https://response.pagerduty.com/) — Free, comprehensive incident response playbook
- [NIST SP 800-61 Rev 2](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-61r2.pdf) — Computer Security Incident Handling Guide

**Talks:**
- "How Google Handles Incidents" — Ben Treynor Sloss (SREcon) — Incident management at hyperscale
- "Every Minute Counts: Code Yellow at Slack" — Laura Nolan (SREcon 2019) — Real-world major incident response
- "Incident Management: From Chaos to Coordination" — Liz Fong-Jones

---

## Key Takeaways {#key-takeaways}

> **Chapter 4 Summary**
>
> - **An incident is any unplanned service disruption.** The goal is not zero incidents — it is fast detection, bounded blast radius, fast mitigation, and maximum learning.
>
> - **The incident lifecycle has five phases: Detect, Triage, Respond, Resolve, Review.** The most common failure point is conflating triage with investigation — spending 20 minutes debugging before declaring severity and engaging the response team.
>
> - **Severity classification must be objective and fast.** Thresholds tied to user impact percentage and revenue impact per minute remove subjectivity from the most time-pressured decision in incident response. When in doubt, declare higher.
>
> - **Role clarity is the most impactful process change you can make.** IC coordinates and decides without debugging. Tech Lead investigates. Comms Lead handles all communication. Scribe documents everything. These roles must be explicitly confirmed at war room start.
>
> - **Runbooks are operational contracts.** A runbook that requires tribal knowledge is incomplete. Every step must be executable by a median engineer at 3am with no context.
>
> - **Risk registers convert reactive firefighting into proactive engineering.** The most expensive SEV1s are caused by risks that were known and never mitigated. A living risk register with quarterly reviews and owners prevents this.
>
> - **FMEA and failure pattern libraries accelerate incident diagnosis.** Recognizing a thundering herd, cascading failure, or retry storm in the first 5 minutes of an incident is the difference between 15-minute and 3-hour resolution.
>
> - **Post-mortem action items are the ROI on every incident.** An incident without follow-through action items is a pure cost. Track completion rate — if it's below 80%, the process is broken.
---
*Previous: [Chapter 3 — Monitoring](#chapter-3)*
*Next: Chapter 5 — Error Budgets*

