# High Performance Site Reliability Engineering: A Complete Study Guide

---

# Chapter 8 — On-Call and First Response

---

## Table of Contents

- [Learning Objectives](#learning-objectives)
- [Core Concepts](#core-concepts)
  - [8.1 The Purpose of On-Call](#81-the-purpose-of-on-call)
  - [8.2 Healthy On-Call Culture](#82-healthy-on-call-culture)
  - [8.3 On-Call Scheduling and Rotation Strategies](#83-on-call-scheduling)
  - [8.4 Paging Design — Alerting That Respects Humans](#84-paging-design)
  - [8.5 Escalation Policies](#85-escalation-policies)
  - [8.6 Cognitive Load Management](#86-cognitive-load-management)
  - [8.7 Incident Command Systems in Practice](#87-incident-command-systems)
  - [8.8 First Response Playbook](#88-first-response-playbook)
  - [8.9 Runbook Automation](#89-runbook-automation)
  - [8.10 On-Call Metrics and Health Tracking](#810-on-call-metrics)
  - [8.11 Tooling Ecosystem](#811-tooling-ecosystem)
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

- Design a healthy on-call program that engineers want to participate in — including rotation structure, compensation models, and psychological safety practices.
- Build a paging strategy grounded in SLO burn rates that eliminates actionable-but-unimportant pages and surfaces only genuine user impact.
- Configure multi-tier escalation policies in PagerDuty and OpsGenie that route the right person to the right incident without human decision-making overhead.
- Apply cognitive load management techniques — structured communication, decision frameworks, and stress protocols — that keep responders effective under pressure.
- Implement runbook automation ranging from diagnostic scripts to fully self-healing systems using Kubernetes operators and event-driven remediation.

---

## Core Concepts {#core-concepts}

### 8.1 The Purpose of On-Call {#81-the-purpose-of-on-call}

On-call is not a punishment. It is not an admission that the system is unreliable. It is the operational acknowledgment that complex systems fail in complex ways — and that user-impacting failures require human judgment to resolve, at any hour.

The purpose of on-call, precisely stated, is:

> To ensure a human with sufficient context and authority is reachable within a defined time window whenever a failure meets the threshold for requiring human intervention.

Every word in that sentence matters:

```
"human with sufficient context"
  → Not just any engineer — someone who understands the system
    well enough to make consequential decisions under pressure.
    Context gap = longer MTTR.

"and authority"
  → The on-call engineer must be empowered to rollback, disable
    features, redirect traffic, and escalate — without waiting
    for approval. Authority gap = longer MTTR.

"reachable within a defined time window"
  → The response time target (MTTA) is defined by the SLO.
    A 99.99% SLO with 4h MTTA is incoherent.

"whenever a failure meets the threshold"
  → Not every alert warrants on-call. Threshold design is the
    primary lever for on-call health. Too low = burnout.
    Too high = SLO breach.
```

**The two failure modes of on-call programs:**

```
Overloaded On-Call                    Underloaded On-Call
──────────────────────────────────    ─────────────────────────────────
Pages: 15+ per week                  Pages: 0 per month
Sleep disruption: chronic            Alerting: misconfigured
Engineer burnout: high               Real incidents: silently missed
Attrition: significant               Context loss: engineers unfamiliar
Quality of response: degraded        Response time: slow (no practice)
Alert acknowledgment: mechanical     SLO: quietly deteriorating

Both are dangerous. The goal is calibrated on-call:
2-5 actionable pages per week per engineer.
```

---

### 8.2 Healthy On-Call Culture {#82-healthy-on-call-culture}

On-call culture is the set of norms, expectations, and practices that determine whether engineers experience on-call as a meaningful professional responsibility or as an extractive burden.

The organizations with the healthiest on-call programs share five characteristics:

#### Characteristic 1: On-Call is Compensated

Engineers who carry a pager are doing additional labor — availability labor. This must be compensated, not normalized as "part of the job."

```
Compensation Models
──────────────────────────────────────────────────────────────────
Model            Structure              Best For
──────────────────────────────────────────────────────────────────
Flat stipend     $X per week on-call    Low-page environments
                 regardless of pages    (< 2 pages/week)

Per-page bounty  $Y per page            Fair for variable
                 (night pages higher)   page volume environments

Time off in lieu 1 day off for each     Teams that value
                 on-call weekend        time over cash

Comp time bank   Hours logged during    Engineering-first
                 incidents credited     organizations
                 as flex time
──────────────────────────────────────────────────────────────────
```

**The Google model:** SREs receive time-off-in-lieu: one full day off for every weekend on-call shift, and compensatory time for incidents that run beyond 2 hours in a night.

#### Characteristic 2: Post-On-Call Recovery is Protected

An engineer who handles a 4-hour P1 incident from 1am to 5am must not be expected to be functional in a 9am standup. Recovery time is a health requirement, not a perk.

```
Recovery Time Policy
─────────────────────────────────────────────────────────────────
Incident during sleep hours:
  → Next morning: optional attendance at standup
  → Hours worked during incident credited as flex time
  → No mandatory on-site presence for 24 hours

Multiple overnight incidents in one week:
  → Engineer removed from rotation for remainder of week
  → Backup takes over
  → Root cause: alerting quality or staffing reviewed

Sustained overload (>10 pages/week for 2+ weeks):
  → Engineering Manager escalation required
  → On-call load analysis presented to leadership
  → Staffing or reliability investment decision within 2 weeks
```

#### Characteristic 3: Every Page Must Be Actionable

The most corrosive force in on-call culture is the non-actionable page — an alert that fires, wakes an engineer, and resolves without any action required. Each one erodes trust in the alerting system and trains engineers to be slower to respond.

```python
# On-call page quality audit
# Run weekly to identify non-actionable alerts

def audit_page_quality(
    incidents: list,    # List of PagerDuty incident records
    lookback_days: int = 30
) -> dict:
    """
    Classify incidents by outcome to identify alerting waste.
    Non-actionable = resolved without any human action taken.
    """
    total = len(incidents)
    categories = {
        "actionable_mitigated":     0,   # Human action stopped the incident
        "actionable_informational":  0,   # Human investigated, self-resolved
        "non_actionable_auto":       0,   # Resolved before engineer engaged
        "non_actionable_false_alarm": 0,  # Alert fired; nothing was wrong
        "non_actionable_duplicate":  0,   # Same root cause, multiple alerts
    }

    for inc in incidents:
        duration_min  = inc["duration_seconds"] / 60
        actions_taken = len(inc.get("timeline_entries", []))
        resolution    = inc.get("resolution_note", "")

        if "rollback" in resolution.lower() or "scaled" in resolution.lower():
            categories["actionable_mitigated"] += 1
        elif duration_min < 5 and actions_taken == 0:
            categories["non_actionable_auto"] += 1
        elif "false" in resolution.lower() or "noise" in resolution.lower():
            categories["non_actionable_false_alarm"] += 1
        elif actions_taken > 0 and duration_min > 30:
            categories["actionable_informational"] += 1
        else:
            categories["non_actionable_duplicate"] += 1

    actionable = (
        categories["actionable_mitigated"] +
        categories["actionable_informational"]
    )
    non_actionable = total - actionable
    actionability_rate = actionable / total if total > 0 else 0

    return {
        "total_pages":        total,
        "actionable":         actionable,
        "non_actionable":     non_actionable,
        "actionability_rate": f"{actionability_rate:.1%}",
        "categories":         categories,
        "health_status": (
            "✅ Healthy"   if actionability_rate > 0.80 else
            "⚠️  Warning"  if actionability_rate > 0.60 else
            "🔴 Critical — alert quality review required"
        ),
        "top_recommendation": (
            "Review non-actionable alerts and silence or raise thresholds"
            if non_actionable > total * 0.3
            else "Alert quality is acceptable"
        )
    }
```

#### Characteristic 4: The On-Call Engineer Has Authority

On-call authority must be explicit and pre-approved. An on-call engineer who must escalate for permission to roll back a deployment, disable a feature, or scale up infrastructure will always have a longer MTTR than one who can act immediately.

```yaml
# On-Call Authority Charter — explicit pre-approvals
# Signed by: Engineering VP, Legal, Security

on_call_pre_approved_actions:
  immediate_no_approval_required:
    - rollback_deployment:
        scope: "Any service in production"
        constraint: "To a version deployed within last 7 days"
    - disable_feature_flag:
        scope: "Any feature flag in LaunchDarkly"
        constraint: "Must document flag name in incident ticket"
    - scale_out:
        scope: "Any autoscaling group or Kubernetes deployment"
        constraint: "Up to 2× current count; not above account quota"
    - toggle_circuit_breaker:
        scope: "Any service circuit breaker"
        constraint: "Document action + business impact in ticket"
    - enable_degraded_mode:
        scope: "Any service with a defined degraded mode"
        constraint: "Notify product owner within 30 min"
    - silence_non_critical_alerts:
        scope: "Any SEV3/SEV4 alert"
        constraint: "Max 4-hour silence; ticket created for follow-up"

  requires_secondary_approval:
    - database_failover:
        approver: "On-call DBA or Senior SRE"
        rationale: "High risk — data integrity implications"
    - disable_entire_service:
        approver: "Engineering Manager"
        rationale: "Complete service outage; customer impact"
    - modify_rate_limits_upward:
        approver: "Security on-call"
        rationale: "Potential DDoS vector"
```

#### Characteristic 5: Blameless Debrief After Every Significant Page

After every SEV1 or SEV2 incident, the on-call engineer participates in a blameless debrief. The goal is not to evaluate the engineer's performance — it is to improve the system.

Questions asked in the debrief:
- Was the alert clear about what was wrong and what to do?
- Was the runbook accurate and sufficient?
- Were there any moments of confusion about what authority the engineer had?
- What would have made this response faster?
- What did we learn about the system that we didn't know before?

---

### 8.3 On-Call Scheduling and Rotation Strategies {#83-on-call-scheduling}

#### Rotation Models

```
┌───────────────────────────────────────────────────────────────────┐
│                   On-Call Rotation Models                         │
├─────────────────┬─────────────────────────────────────────────────┤
│ Follow-the-Sun  │ Shifts aligned to business hours by timezone.   │
│                 │ EU team covers 7am-3pm UTC; US team 3pm-11pm;   │
│                 │ APAC team 11pm-7am.                             │
│                 │                                                 │
│                 │ ✅ No sleep disruption                          │
│                 │ ❌ Requires 3+ regional teams                   │
│                 │ ❌ Handoff quality critical                     │
├─────────────────┼─────────────────────────────────────────────────┤
│ Weekly Rotation │ One engineer owns primary on-call for a full    │
│                 │ calendar week, then rotates.                    │
│                 │                                                 │
│                 │ ✅ Simple, predictable                          │
│                 │ ✅ Deep context during week                     │
│                 │ ❌ Week of poor sleep if high-page service      │
│                 │ ❌ Minimum 4-5 person team needed               │
├─────────────────┼─────────────────────────────────────────────────┤
│ Split Shifts    │ Primary: 8am–midnight. Secondary: midnight–8am. │
│                 │ Different engineers for day/night.              │
│                 │                                                 │
│                 │ ✅ Protects sleep for most engineers            │
│                 │ ❌ Handoff twice per day                        │
│                 │ ❌ Night-shift engineer needs full context      │
├─────────────────┼─────────────────────────────────────────────────┤
│ Primary /       │ Primary responds first. Secondary is backup.    │
│ Secondary       │ Secondary pages if primary doesn't ack in 5min. │
│                 │                                                 │
│                 │ ✅ Safety net against missed pages              │
│                 │ ✅ Shadowing opportunity for new engineers      │
│                 │ ❌ Secondary still woken for every escalation   │
└─────────────────┴─────────────────────────────────────────────────┘
```

#### Rotation Sizing Formula

```python
def calculate_rotation_size(
    target_oncall_shifts_per_month: int = 1,    # Each engineer on-call 1 week/mo
    engineers_available: int = None,
    min_rotation_size: int = 4,                  # Minimum viable rotation
    weeks_per_rotation: int = 1,                 # How often rotation cycles
    include_shadow: bool = True                  # Shadow shifts for new engineers
) -> dict:
    """
    Calculate minimum rotation size and identify staffing gaps.

    Rule of thumb: Each engineer should be on-call no more than
    1 week in 4-6 weeks (17-25% of their time).
    """
    weeks_per_month = 4.33

    # Minimum engineers for target frequency
    shifts_per_engineer_per_month = weeks_per_month / weeks_per_rotation
    min_engineers_for_target = int(
        shifts_per_engineer_per_month / target_oncall_shifts_per_month
    )

    # Shadow slots reduce effective rotation
    effective_engineers = (
        engineers_available * 0.8
        if (include_shadow and engineers_available)
        else engineers_available
    )

    actual_freq = (
        shifts_per_engineer_per_month / effective_engineers
        if effective_engineers
        else None
    )

    status = "unknown"
    if engineers_available:
        if effective_engineers >= min_engineers_for_target:
            status = f"✅ Healthy — {actual_freq:.2f} shifts/month/engineer"
        elif effective_engineers >= min_rotation_size:
            status = f"⚠️  Strained — {actual_freq:.2f} shifts/month/engineer"
        else:
            status = f"🔴 Critical — {effective_engineers:.0f} engineers < {min_rotation_size} minimum"

    return {
        "min_rotation_for_target":  min_engineers_for_target,
        "min_viable_rotation":      min_rotation_size,
        "current_engineers":        engineers_available,
        "effective_engineers":      effective_engineers,
        "shifts_per_eng_per_month": round(actual_freq, 2) if actual_freq else "N/A",
        "status":                   status,
        "recommendation": (
            f"Need {max(0, min_engineers_for_target - (engineers_available or 0))} "
            f"more engineers for healthy rotation"
            if engineers_available and engineers_available < min_engineers_for_target
            else "Rotation adequately staffed"
        )
    }

# Examples
healthy   = calculate_rotation_size(engineers_available=8)
strained  = calculate_rotation_size(engineers_available=4)
critical  = calculate_rotation_size(engineers_available=3)
for r in [healthy, strained, critical]:
    print(f"{r['current_engineers']} engineers: {r['status']}")
```

#### Schedule Configuration (PagerDuty)

```python
# PagerDuty API — programmatic schedule creation
# Demonstrates a primary/secondary weekly rotation with business-hours override

import requests
import json
from datetime import datetime, timezone

PAGERDUTY_API_KEY = "your_api_key"
HEADERS = {
    "Authorization": f"Token token={PAGERDUTY_API_KEY}",
    "Content-Type":  "application/json",
    "Accept":        "application/vnd.pagerduty+json;version=2",
}

def create_oncall_schedule(
    team_name: str,
    engineer_ids: list,    # PagerDuty user IDs
    rotation_start: str,   # ISO 8601 datetime
    timezone: str = "America/New_York"
) -> dict:
    """Create a weekly primary rotation schedule."""

    schedule_payload = {
        "schedule": {
            "name":      f"{team_name} - Primary On-Call",
            "time_zone": timezone,
            "schedule_layers": [
                {
                    "name":                  "Weekly Rotation",
                    "start":                 rotation_start,
                    "rotation_virtual_start": rotation_start,
                    "rotation_turn_length_seconds": 604800,  # 1 week
                    "users": [
                        {"user": {"id": uid, "type": "user_reference"}}
                        for uid in engineer_ids
                    ],
                    "restrictions": []   # No restrictions = 24/7 coverage
                }
            ]
        }
    }

    response = requests.post(
        "https://api.pagerduty.com/schedules",
        headers=HEADERS,
        json=schedule_payload
    )
    response.raise_for_status()
    return response.json()

def create_business_hours_override_schedule(
    team_name: str,
    engineer_ids: list,
    rotation_start: str
) -> dict:
    """
    Business hours schedule (9am-6pm Mon-Fri).
    Layered on top of primary rotation — whoever is scheduled
    during business hours gets business-hours pages first.
    """
    schedule_payload = {
        "schedule": {
            "name":      f"{team_name} - Business Hours",
            "time_zone": "America/New_York",
            "schedule_layers": [
                {
                    "name":  "Business Hours Rotation",
                    "start": rotation_start,
                    "rotation_virtual_start": rotation_start,
                    "rotation_turn_length_seconds": 604800,
                    "users": [
                        {"user": {"id": uid, "type": "user_reference"}}
                        for uid in engineer_ids
                    ],
                    "restrictions": [
                        {
                            "type":               "weekly_restriction",
                            "start_time_of_day":  "09:00:00",
                            "duration_seconds":   32400,   # 9 hours
                            "start_day_of_week":  1,       # Monday
                        },
                        # Repeat for Tue-Fri
                        *[
                            {
                                "type":               "weekly_restriction",
                                "start_time_of_day":  "09:00:00",
                                "duration_seconds":   32400,
                                "start_day_of_week":  day,
                            }
                            for day in [2, 3, 4, 5]  # Tue through Fri
                        ]
                    ]
                }
            ]
        }
    }

    response = requests.post(
        "https://api.pagerduty.com/schedules",
        headers=HEADERS,
        json=schedule_payload
    )
    response.raise_for_status()
    return response.json()
```

#### Handoff Protocol

The rotation handoff is where context is most commonly lost. A poor handoff means the incoming on-call engineer starts their shift without knowing about a degraded service, a pending deployment risk, or a silent alarm that's been suppressed.

```markdown
# On-Call Handoff Template
**Date:** {{date}}
**Outgoing:** {{outgoing_engineer}}
**Incoming:** {{incoming_engineer}}

---

## Open Incidents / Active Issues
<!-- List any active incidents or ongoing degradation -->
| Incident | Severity | Status | Next Action | Owner |
|----------|----------|--------|-------------|-------|
| INC-1234 | SEV3     | Monitoring recovery | Watch DB conn pool | @james |

## Silenced Alerts (active suppressions)
| Alert | Silenced Until | Reason | Action Required |
|-------|---------------|--------|-----------------|
| HighErrorRate/search | 2024-01-15 08:00 | Known Elasticsearch reindex | Resume alert after reindex |

## Upcoming Risky Changes
| Change | Service | Scheduled | Risk | Contact |
|--------|---------|-----------|------|---------|
| DB migration v3.2 | payments | Tue 02:00 UTC | Medium — test revert plan | @sarah |

## Known Fragile Areas
<!-- Services / components in Yellow/Red error budget zone -->
- Cart service: 88% error budget consumed — avoid deployments
- Search: Elasticsearch cluster under-replicated (known risk, tracked as RISK-042)

## Runbook Updates Since Last Handoff
- checkout/high-error-rate: Added Step 3C for Stripe timeout fallback

## Notes for Incoming On-Call
- PD escalation policy updated: now pages @tom as secondary (was @alice)
- Planned maintenance: search reindex Thursday 10pm-midnight UTC
```

---

### 8.4 Paging Design — Alerting That Respects Humans {#84-paging-design}

Paging design is the discipline of configuring alerting systems to wake humans only when human intervention is genuinely required. Every unnecessary page is a withdrawal from the on-call engineer's trust account — too many withdrawals and they stop responding with urgency.

#### The Page Decision Framework

```
Should this fire a page?
──────────────────────────────────────────────────────────────────────
1. Is a user experiencing degraded service right now?
   → NO  → Does not warrant a page. Dashboard or ticket.
   → YES → Proceed to 2.

2. Does it require human action to resolve?
   → NO  → Auto-remediate. Alert when auto-remediation fails.
   → YES → Proceed to 3.

3. Is it urgent enough to wake someone?
   → Is SLO budget being consumed at a dangerous rate?
     → YES (burn rate > 14.4×) → PAGE
     → NO                      → Ticket (P2/P3 handling)

4. Who is the right person to page?
   → Does the on-call engineer have the context and authority?
     → YES → Page on-call
     → NO  → Page the SME directly (domain specialist)
──────────────────────────────────────────────────────────────────────
```

#### Alert Routing by SLO Impact

```yaml
# Alertmanager routing tree — routes alerts to correct team/channel
# based on severity, service ownership, and time of day

global:
  resolve_timeout: 5m

route:
  receiver: default-sink       # Catch-all for unmatched alerts
  group_by: [service, alertname]
  group_wait:      30s         # Wait 30s for related alerts to group
  group_interval:  5m          # Resend grouped alerts every 5m
  repeat_interval: 4h          # Re-notify if unresolved after 4h

  routes:
    # ── Critical/SLO-burning alerts → immediate page ──────────────
    - matchers:
        - severity = critical
      receiver: pagerduty-critical
      group_wait:      10s     # Faster grouping for critical
      repeat_interval: 30m     # Aggressive re-notification

    # ── Warning alerts during business hours → Slack ──────────────
    - matchers:
        - severity = warning
      active_time_intervals: [business_hours]
      receiver: slack-sre-channel
      group_interval:  15m

    # ── Warning alerts outside business hours → PagerDuty (low urgency)
    - matchers:
        - severity = warning
      receiver: pagerduty-low-urgency
      group_wait:  5m

    # ── Database alerts → DBA on-call ─────────────────────────────
    - matchers:
        - service = postgresql
        - severity =~ "critical|warning"
      receiver: pagerduty-dba-oncall
      continue: false          # Don't also send to default

    # ── Security alerts → Security team ───────────────────────────
    - matchers:
        - category = security
      receiver: pagerduty-security
      group_wait: 0s           # No delay for security incidents
      continue: true           # Also goes to SIEM

    # ── Informational → logging only ──────────────────────────────
    - matchers:
        - severity = info
      receiver: alert-log-sink
      group_wait: 5m

time_intervals:
  - name: business_hours
    time_intervals:
      - times:
          - start_time: "09:00"
            end_time:   "18:00"
        weekdays: [monday:friday]

inhibit_rules:
  # If service is completely down (critical), suppress warning-level alerts for same service
  - source_matchers: [severity = critical]
    target_matchers: [severity = warning]
    equal: [service]

  # If node is down, suppress pod-level alerts for pods on that node
  - source_matchers: [alertname = NodeDown]
    target_matchers: [alertname =~ "Pod.*"]
    equal: [node]

receivers:
  - name: pagerduty-critical
    pagerduty_configs:
      - routing_key: ${PAGERDUTY_CHECKOUT_KEY}
        severity:    critical
        class:       "{{ .CommonLabels.alertname }}"
        component:   "{{ .CommonLabels.service }}"
        group:       "{{ .CommonLabels.team }}"
        details:
          runbook:     "{{ .CommonAnnotations.runbook_url }}"
          dashboard:   "{{ .CommonAnnotations.dashboard_url }}"
          description: "{{ .CommonAnnotations.description }}"

  - name: pagerduty-low-urgency
    pagerduty_configs:
      - routing_key: ${PAGERDUTY_CHECKOUT_KEY}
        severity:    warning

  - name: slack-sre-channel
    slack_configs:
      - api_url: ${SLACK_SRE_WEBHOOK}
        channel:  "#sre-alerts"
        title:    "⚠️ {{ .CommonAnnotations.summary }}"
        text: |
          *Service:* {{ .CommonLabels.service }}
          *Alert:*   {{ .CommonLabels.alertname }}
          {{ .CommonAnnotations.description }}
        actions:
          - type: button
            text: "View Dashboard"
            url:  "{{ .CommonAnnotations.dashboard_url }}"
          - type: button
            text: "View Runbook"
            url:  "{{ .CommonAnnotations.runbook_url }}"
```

#### Alert Deduplication and Grouping

```python
# Alert grouping logic — prevents alert storms from flooding on-call
# during cascading failures (where many services alert simultaneously)

def should_group_with_existing(
    new_alert: dict,
    active_alerts: list,
    group_window_seconds: int = 300
) -> dict | None:
    """
    Determine if a new alert should be grouped with an existing incident
    rather than creating a new page.

    Grouping logic:
    1. Same service + same root cause label → group
    2. Multiple services alerting within 5 minutes → likely cascade → group
    3. Same infrastructure component (node, AZ) → likely hardware issue → group
    """
    import time

    now = time.time()
    new_service   = new_alert.get("labels", {}).get("service")
    new_component = new_alert.get("labels", {}).get("component")
    new_node      = new_alert.get("labels", {}).get("node")

    for existing in active_alerts:
        existing_time = existing.get("started_at", 0)
        age_seconds   = now - existing_time

        if age_seconds > group_window_seconds:
            continue   # Too old to group with

        existing_labels = existing.get("labels", {})

        # Same service — always group
        if existing_labels.get("service") == new_service:
            return existing

        # Same infrastructure node — likely common cause
        if new_node and existing_labels.get("node") == new_node:
            return existing

        # Cascade detection: multiple services alerting within 5 minutes
        # If 3+ services alert in 5 minutes, treat as cascade incident
        recent_services = {
            a["labels"]["service"]
            for a in active_alerts
            if now - a.get("started_at", 0) < group_window_seconds
            and "service" in a.get("labels", {})
        }
        if len(recent_services) >= 3:
            return existing  # Group into the first one

    return None  # Create new incident
```

---

### 8.5 Escalation Policies {#85-escalation-policies}

An escalation policy defines the sequence of notifications when an incident is not acknowledged within the required response time. Well-designed escalation policies provide redundancy without being punitive.

#### Escalation Policy Architecture

```
Primary Escalation Path (SEV1)
──────────────────────────────────────────────────────────────────
T+0:00   Alert fires
T+0:30   Alertmanager groups and routes
T+1:00   Page primary on-call (push notification + phone call)
T+5:00   [No ack] → Page secondary on-call
T+10:00  [No ack] → Page team lead (SMS + call)
T+15:00  [No ack] → Page engineering manager (phone call)
T+20:00  [No ack] → Page VP Engineering (phone call + text)
T+30:00  [No ack] → Automated incident creation + Slack broadcast
──────────────────────────────────────────────────────────────────

SEV2 Escalation Path:
T+0:00   Alert fires
T+2:00   Page primary on-call
T+10:00  [No ack] → Page secondary on-call
T+30:00  [No ack] → Page team lead
T+4h     [Unresolved] → Notify engineering manager

SEV3/4 Path:
T+0:00   Alert fires → Slack notification + Jira ticket
T+8h     [Unacknowledged] → Slack reminder
T+24h    [Unacknowledged] → Team lead notification
```

```python
# PagerDuty escalation policy via API
# Creates tiered escalation with SMS + call for higher tiers

def create_escalation_policy(
    team_name: str,
    primary_schedule_id: str,
    secondary_schedule_id: str,
    team_lead_user_id: str,
    engineering_manager_id: str,
    sev1_ack_timeout_minutes: int = 5
) -> dict:
    """
    Create multi-tier escalation policy for SEV1 incidents.
    """
    payload = {
        "escalation_policy": {
            "name":         f"{team_name} — SEV1 Escalation",
            "description":  f"SEV1 escalation for {team_name} service",
            "num_loops":    2,     # Repeat cycle twice if no ack after all tiers
            "escalation_rules": [
                # Tier 1: Primary on-call — 5 minutes to ack
                {
                    "escalation_delay_in_minutes": sev1_ack_timeout_minutes,
                    "targets": [
                        {
                            "type": "schedule_reference",
                            "id":   primary_schedule_id,
                        }
                    ],
                },
                # Tier 2: Secondary on-call — additional 5 minutes
                {
                    "escalation_delay_in_minutes": 5,
                    "targets": [
                        {
                            "type": "schedule_reference",
                            "id":   secondary_schedule_id,
                        }
                    ],
                },
                # Tier 3: Team lead — additional 5 minutes
                {
                    "escalation_delay_in_minutes": 5,
                    "targets": [
                        {
                            "type": "user_reference",
                            "id":   team_lead_user_id,
                        }
                    ],
                },
                # Tier 4: Engineering manager — no further escalation
                {
                    "escalation_delay_in_minutes": 10,
                    "targets": [
                        {
                            "type": "user_reference",
                            "id":   engineering_manager_id,
                        }
                    ],
                },
            ],
        }
    }

    response = requests.post(
        "https://api.pagerduty.com/escalation_policies",
        headers=HEADERS,
        json=payload
    )
    response.raise_for_status()
    return response.json()
```

#### Service-Specific Escalation Routing

Different services have different subject matter experts who should be in the escalation path:

```yaml
# Service-to-escalation-policy mapping
# In PagerDuty: configured as Service → Escalation Policy

services:
  checkout-api:
    primary_escalation:   checkout-sev1-policy
    secondary_escalation: platform-sev1-policy
    sme_contacts:
      payment_issues:  "@tom.riley (payment-service)"
      db_issues:       "@dba-oncall"
      infra_issues:    "@platform-oncall"

  payment-api:
    primary_escalation:   payment-sev1-policy
    sme_contacts:
      stripe_issues:   "Stripe Support +1-888-926-2289"
      fraud_issues:    "@fraud-team-lead"

  search-api:
    primary_escalation:   search-sev1-policy
    sme_contacts:
      elasticsearch:   "@alice.wang (search-infra)"
      relevance:       "@data-science-oncall"
```

---

### 8.6 Cognitive Load Management {#86-cognitive-load-management}

Incident response is one of the most cognitively demanding activities in software engineering. You are debugging a complex system, making high-stakes decisions, communicating with multiple stakeholders, and often doing this at 2am while sleep-deprived.

Cognitive load management is the set of practices, tools, and team norms that keep responders effective under these conditions.

#### The Three Types of Cognitive Load

```
Intrinsic Load — inherent complexity of the task
  "Understanding why the payment service is returning 503"
  → Cannot be eliminated. Manage by building deep system context.
  → Runbooks encode context so intrinsic load doesn't start at zero.

Extraneous Load — unnecessary complexity from poor tools/process
  "Having to search 5 Slack channels for the war room link"
  "Unclear whether I should page the DBA or wait for approval"
  → Can and must be eliminated. This is SRE process debt.
  → Every minute of extraneous load in an incident = MTTR tax.

Germane Load — productive cognitive effort that builds schema
  "Recognizing this error pattern from the last outage"
  "This looks like the thundering herd pattern from our FMEA"
  → Actively build this through runbooks, GameDays, and post-mortems.
  → Experienced on-call engineers have high germane load capacity.
```

#### Cognitive Load Reduction Techniques

**Technique 1: The First-Response Checklist**

Decision fatigue is highest in the first 5 minutes of an incident. A first-response checklist eliminates decision points by providing a deterministic sequence:

```
First Response Checklist (laminated card version)
──────────────────────────────────────────────────────────────
□ 1. Acknowledge the page (stop the escalation clock)
□ 2. Open the SLO dashboard for the alerting service
□ 3. Is this real? Check error rate on dashboard (not just alert)
□ 4. Assign severity (use the matrix — don't guess)
□ 5. Open the war room channel: #incident-[date]-[service]
□ 6. Post initial status: "Investigating [service] [severity]"
□ 7. Check: was there a deployment in the last 2 hours?
     YES → Open rollback runbook NOW
     NO  → Open diagnostic runbook for this alert
□ 8. Assign IC role (yourself or escalate)
□ 9. Assign Comms Lead (SEV1/SEV2 only)
□ 10. Set a 10-minute timer for next status update
──────────────────────────────────────────────────────────────
Time to complete: < 3 minutes
```

**Technique 2: Structured Status Updates**

During incidents, informal communication creates cognitive noise. Structured updates reduce the mental overhead of composing status messages under pressure:

```python
def format_incident_status_update(
    time_utc: str,
    service: str,
    severity: str,
    impact: str,
    current_error_rate: float,
    action_in_progress: str,
    eta_minutes: int | None,
    next_update_minutes: int = 15
) -> str:
    """
    Generate structured incident status update.
    Reduces cognitive load: responder fills in slots, not free-form prose.
    """
    eta_str = f"~{eta_minutes} minutes" if eta_minutes else "Unknown"

    return f"""
🔴 [{severity}] {service.upper()} — Status Update {time_utc} UTC

IMPACT:  {impact}
STATUS:  Error rate {current_error_rate:.1%} (SLO: 0.1%)
ACTION:  {action_in_progress}
ETA:     {eta_str}

Next update: {next_update_minutes} minutes or on significant change.
""".strip()

# Example usage during an active incident
update = format_incident_status_update(
    time_utc="02:47",
    service="checkout",
    severity="SEV1",
    impact="~18% of checkout attempts failing. Est. $2,400/min revenue impact.",
    current_error_rate=0.182,
    action_in_progress="Rolling back payment-service v3.1.2 to v3.1.1 (ETA: 3 min)",
    eta_minutes=5,
    next_update_minutes=10
)
print(update)
```

**Technique 3: The OODA Loop for Incident Response**

The OODA (Observe, Orient, Decide, Act) loop from military decision theory maps directly to incident response. Making the loop explicit reduces the cognitive overhead of "what should I be doing right now?":

```
OODA Loop — Applied to Incident Response
──────────────────────────────────────────────────────────────────────
OBSERVE (1-2 minutes)
  → Look at dashboards. What signals are present?
  → What changed recently? (Deployments, config changes, traffic)
  → What is the blast radius? (Which services, which users?)

ORIENT (1-2 minutes)
  → Compare observations to known failure patterns.
  → Does this match a known failure mode in the runbook?
  → Is this a cascade (upstream failure) or a local issue?

DECIDE (30 seconds)
  → Choose ONE action. Not three. One.
  → Default: if recent deployment → ROLLBACK
  → If no recent deployment → identify highest-signal diagnostic

ACT (as fast as possible)
  → Execute the decision fully.
  → Document action + timestamp in scribe log.
  → Set a 10-minute observation window.

→ Repeat OODA loop. Each cycle should narrow the hypothesis space.
──────────────────────────────────────────────────────────────────────
```

**Technique 4: Context Preservation Under Stress**

```python
# Incident context object — single source of truth during an incident
# Reduces cognitive load by externalizing state

from dataclasses import dataclass, field
from datetime import datetime
from typing import List, Dict, Optional

@dataclass
class IncidentContext:
    """
    Shared context object for active incident.
    Passed between responders; updated in real time.
    Replaces memory-heavy "holding state in your head" pattern.
    """
    incident_id:       str
    service:           str
    severity:          str
    declared_at:       datetime = field(default_factory=datetime.utcnow)

    # Current state
    current_error_rate: float = 0.0
    current_latency_p99_ms: float = 0.0
    affected_user_pct:  float = 0.0

    # Investigation state
    confirmed_facts:    List[str] = field(default_factory=list)
    active_hypotheses:  List[str] = field(default_factory=list)
    ruled_out:          List[str] = field(default_factory=list)
    actions_taken:      List[Dict] = field(default_factory=list)

    # Roles
    incident_commander: Optional[str] = None
    tech_lead:          Optional[str] = None
    comms_lead:         Optional[str] = None
    scribe:             Optional[str] = None

    def add_fact(self, fact: str) -> None:
        ts = datetime.utcnow().strftime("%H:%M")
        self.confirmed_facts.append(f"[{ts}] {fact}")

    def add_action(self, action: str, actor: str) -> None:
        self.actions_taken.append({
            "timestamp": datetime.utcnow().strftime("%H:%M"),
            "actor":     actor,
            "action":    action
        })

    def rule_out(self, hypothesis: str) -> None:
        if hypothesis in self.active_hypotheses:
            self.active_hypotheses.remove(hypothesis)
        self.ruled_out.append(hypothesis)

    def status_summary(self) -> str:
        return (
            f"Incident: {self.incident_id} | {self.service} | {self.severity}\n"
            f"Duration: {(datetime.utcnow() - self.declared_at).seconds // 60}min\n"
            f"Error Rate: {self.current_error_rate:.1%} | "
            f"P99: {self.current_latency_p99_ms}ms\n"
            f"IC: {self.incident_commander or 'UNASSIGNED'} | "
            f"CL: {self.tech_lead or 'UNASSIGNED'}\n\n"
            f"Confirmed:\n" +
            "\n".join(f"  ✓ {f}" for f in self.confirmed_facts[-5:]) +
            f"\n\nActive hypotheses:\n" +
            "\n".join(f"  ? {h}" for h in self.active_hypotheses) +
            f"\n\nLast 3 actions:\n" +
            "\n".join(
                f"  [{a['timestamp']}] {a['actor']}: {a['action']}"
                for a in self.actions_taken[-3:]
            )
        )
```

---

### 8.7 Incident Command Systems in Practice {#87-incident-command-systems}

Chapter 4 introduced incident roles. This section covers how they operate under real-world constraints — particularly the common scenario where a small team must cover all roles simultaneously, and how to maintain command structure under resource pressure.

#### Minimum Viable Command Structure

```
Team Size      Roles Coverage
─────────────────────────────────────────────────────────────────
1 engineer     IC + CL + Scribe + Tech Lead (all roles, solo)
               → Post update every 10 min to ticket (serves as scribe log)
               → Keep investigation notes in ticket (context preservation)
               → Verbalize decisions before executing (prevents tunnel vision)

2 engineers    IC = Eng A (coordinates, communicates, decides)
               Tech Lead = Eng B (investigates, executes)
               → IC also serves as Scribe (documents in war room)
               → Eng B also serves as Comms Lead (posts status)

3+ engineers   Full role separation (see Chapter 4)
               → IC coordinates
               → Tech Lead investigates
               → Comms Lead handles all external communication
               → Scribe maintains live timeline
               → SMEs join as needed
─────────────────────────────────────────────────────────────────
```

#### War Room Facilitation Script

The IC runs the war room with a repeating cadence. This script eliminates improvisation overhead:

```
War Room Facilitation — IC Script
──────────────────────────────────────────────────────────────────────
OPENING (T+0):
  "This is [NAME], IC for [INCIDENT-ID].
   Service: [SERVICE]. Severity: [SEV X].
   Confirmed roles:
     Tech Lead: [NAME or 'needed']
     Comms Lead: [NAME or 'needed']
     Scribe: [NAME or 'needed']
   Tech Lead — what are we seeing?"

STATUS CHECK (every 10-15 minutes):
  "Status check at [TIME].
   Error rate: [X]% [improving/stable/worsening].
   [TECH LEAD NAME] — update on current investigation?
   [COMMS LEAD NAME] — status page updated?
   Next check at [TIME+15] or on significant change."

DECISION CALL:
  "Based on [EVIDENCE], I'm calling [ACTION].
   [TECH LEAD NAME] — please execute [SPECIFIC ACTION].
   Scribe — log that we're [ACTION] at [TIME].
   I need an update in [N] minutes."

RABBIT HOLE INTERVENTION:
  "We've been on [APPROACH] for [N] minutes without progress.
   I'm calling a pivot. [TECH LEAD] — set this aside.
   New focus: [NEW DIRECTION].
   15 minutes on this, then we reassess."

RESOLUTION:
  "Error rate has been within SLO for [N] minutes.
   Declaring resolution at [TIME].
   [COMMS LEAD] — please post resolution to status page.
   Post-mortem scheduled for [DATE TIME].
   Thank you all."
──────────────────────────────────────────────────────────────────────
```

---

### 8.8 First Response Playbook {#88-first-response-playbook}

The first response playbook is the universal initial diagnostic that applies to any alert, regardless of service or failure mode. It provides a structured starting point before service-specific runbooks take over.

```python
#!/usr/bin/env python3
"""
first_responder.py — Universal first-response diagnostic
Runs in < 60 seconds; gives on-call engineer immediate context.
Usage: python first_responder.py --service checkout --namespace production
"""

import subprocess
import requests
import json
import argparse
import sys
from datetime import datetime, timedelta

def run(cmd: str, capture: bool = True) -> str:
    """Execute shell command and return output."""
    try:
        result = subprocess.run(
            cmd, shell=True, capture_output=capture,
            text=True, timeout=10
        )
        return result.stdout.strip() if capture else ""
    except subprocess.TimeoutExpired:
        return "TIMEOUT"
    except Exception as e:
        return f"ERROR: {e}"

def query_prometheus(url: str, query: str) -> str:
    try:
        r = requests.get(
            f"{url}/api/v1/query",
            params={"query": query},
            timeout=5
        )
        results = r.json().get("data", {}).get("result", [])
        return str(round(float(results[0]["value"][1]), 4)) if results else "N/A"
    except Exception:
        return "N/A"

def run_first_response_diagnostic(
    service: str,
    namespace: str,
    prometheus_url: str = "http://prometheus:9090"
) -> None:
    ts = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
    print(f"\n{'='*60}")
    print(f"  FIRST RESPONSE DIAGNOSTIC — {service.upper()}")
    print(f"  {ts}")
    print(f"{'='*60}")

    # ── 1. Current Health Metrics ──────────────────────────────────
    print("\n[1/6] CURRENT HEALTH METRICS")
    error_rate = query_prometheus(
        prometheus_url,
        f'sum(rate(http_requests_total{{service="{service}",status_code=~"5.."}}[5m])) / sum(rate(http_requests_total{{service="{service}"}}[5m]))'
    )
    p99_latency = query_prometheus(
        prometheus_url,
        f'histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket{{service="{service}"}}[5m])) by (le)) * 1000'
    )
    rps = query_prometheus(
        prometheus_url,
        f'sum(rate(http_requests_total{{service="{service}"}}[5m]))'
    )
    burn_rate = query_prometheus(
        prometheus_url,
        f'(sum(rate(http_requests_total{{service="{service}",status_code=~"5.."}}[1h])) / sum(rate(http_requests_total{{service="{service}"}}[1h]))) / 0.001'
    )
    print(f"  Error Rate (5m): {error_rate}")
    print(f"  P99 Latency:     {p99_latency} ms")
    print(f"  RPS (5m):        {rps}")
    print(f"  Burn Rate (1h):  {burn_rate}× (SLO budget)")

    # ── 2. Recent Deployments ──────────────────────────────────────
    print("\n[2/6] RECENT DEPLOYMENTS (last 2 hours)")
    deploy_log = run(
        f"kubectl -n {namespace} rollout history deployment/{service} "
        f"--no-headers 2>/dev/null | tail -5"
    )
    print(f"  {deploy_log or 'No deployment history found'}")

    # ── 3. Pod Health ──────────────────────────────────────────────
    print("\n[3/6] POD HEALTH")
    pod_status = run(
        f"kubectl -n {namespace} get pods -l app={service} "
        f"--sort-by='.status.startTime' --no-headers 2>/dev/null | "
        f"awk '{{print $1, $3, $4, $5}}' | tail -10"
    )
    print(f"  {pod_status or 'Cannot reach Kubernetes API'}")

    # ── 4. Recent Error Logs ───────────────────────────────────────
    print("\n[4/6] RECENT ERROR LOGS (last 5 minutes)")
    error_logs = run(
        f"kubectl -n {namespace} logs -l app={service} "
        f"--since=5m --tail=20 2>/dev/null | grep -iE 'error|exception|fatal' | "
        f"head -10"
    )
    print(f"  {error_logs or 'No error logs found'}")

    # ── 5. Upstream Dependency Health ─────────────────────────────
    print("\n[5/6] UPSTREAM DEPENDENCIES")
    # Load dependency list from service registry (simplified)
    dependencies = {
        "checkout": ["payment-service", "inventory-service", "cart-service"],
        "payment":  ["stripe-api", "fraud-service"],
        "search":   ["elasticsearch", "product-catalog"],
    }
    deps = dependencies.get(service, [])
    if deps:
        for dep in deps:
            dep_health = run(
                f"curl -s -o /dev/null -w '%{{http_code}}' "
                f"http://{dep}.{namespace}.svc.cluster.local/health "
                f"--max-time 3 2>/dev/null || echo 'UNREACHABLE'"
            )
            status_icon = "✅" if dep_health == "200" else "🔴"
            print(f"  {status_icon} {dep}: HTTP {dep_health}")
    else:
        print("  No dependencies configured for this service")

    # ── 6. Active Alerts ──────────────────────────────────────────
    print("\n[6/6] ACTIVE PROMETHEUS ALERTS")
    active_alerts = query_prometheus(
        prometheus_url,
        f'ALERTS{{service="{service}", alertstate="firing"}}'
    )
    print(f"  Firing alerts: {active_alerts}")

    print(f"\n{'='*60}")
    print("  Diagnostic complete. Suggested next steps:")
    print("  1. Review recent deployments — rollback if recent change")
    print("  2. Check error logs for exception pattern")
    print("  3. Verify upstream dependency health (red = cascade)")
    print(f"  4. Open service runbook: https://runbooks.internal/{service}")
    print(f"{'='*60}\n")

def main():
    parser = argparse.ArgumentParser(description="First responder diagnostic")
    parser.add_argument("--service",        required=True)
    parser.add_argument("--namespace",      default="production")
    parser.add_argument("--prometheus-url", default="http://prometheus:9090")
    args = parser.parse_args()
    run_first_response_diagnostic(args.service, args.namespace, args.prometheus_url)

if __name__ == "__main__":
    main()
```

---

### 8.9 Runbook Automation {#89-runbook-automation}

Runbook automation is the practice of converting manual response steps into code that executes automatically — either fully (self-healing) or semi-automatically (one-click remediation presented to the on-call engineer).

#### Automation Maturity Levels

```
Level 0: Manual runbook
  Engineer reads steps, executes commands manually.
  MTTR contribution: 15-45 minutes.

Level 1: Scripted diagnostics
  Automated diagnostic script runs; engineer interprets and acts.
  MTTR contribution: 5-15 minutes.
  (See first_responder.py above)

Level 2: Semi-automated remediation (ChatOps)
  Engineer types "/runbook checkout restart-pods" in Slack.
  Bot validates, executes, reports result.
  MTTR contribution: 2-5 minutes.

Level 3: Triggered automation
  Alert fires → automation script runs → takes remediation action
  → notifies on-call with action taken.
  MTTR contribution: 0-2 minutes (automated).
  Requires: high-confidence alert, low-risk remediation.

Level 4: Self-healing system
  Kubernetes operator / controller detects failure state,
  executes remediation, reconciles to desired state.
  Human involvement: only if automation fails.
  MTTR contribution: seconds.
```

#### Level 2: ChatOps Runbook Bot

```python
# Slack bot — one-click runbook execution
# Engineers type "/runbook <service> <action>" in Slack
# Bot validates, executes, reports back

from slack_bolt import App
from slack_bolt.adapter.socket_mode import SocketModeHandler
import subprocess
import logging

app = App(token="xoxb-your-bot-token")
logger = logging.getLogger(__name__)

# Approved actions — explicit allowlist (security: no arbitrary commands)
APPROVED_ACTIONS = {
    "restart-pods": {
        "description": "Restart all pods for a service",
        "command": "kubectl -n {namespace} rollout restart deployment/{service}",
        "confirmation_required": True,
        "risk": "medium",
    },
    "rollback": {
        "description": "Roll back to previous deployment",
        "command": "kubectl -n {namespace} rollout undo deployment/{service}",
        "confirmation_required": True,
        "risk": "medium",
    },
    "scale-up": {
        "description": "Double the current replica count",
        "command": "kubectl -n {namespace} scale deployment/{service} --replicas={target}",
        "confirmation_required": False,   # Low risk — safe to execute immediately
        "risk": "low",
    },
    "diagnose": {
        "description": "Run first-response diagnostic",
        "command": "python /runbooks/first_responder.py --service {service} --namespace {namespace}",
        "confirmation_required": False,
        "risk": "none",
    },
}

@app.command("/runbook")
def handle_runbook_command(ack, say, command, client):
    ack()  # Acknowledge immediately (Slack requires < 3s)

    parts   = command["text"].split()
    service = parts[0] if len(parts) > 0 else None
    action  = parts[1] if len(parts) > 1 else None

    if not service or not action:
        say("Usage: `/runbook <service> <action>`\n"
            f"Available actions: {', '.join(APPROVED_ACTIONS.keys())}")
        return

    if action not in APPROVED_ACTIONS:
        say(f"Unknown action: `{action}`. "
            f"Available: `{', '.join(APPROVED_ACTIONS.keys())}`")
        return

    action_config = APPROVED_ACTIONS[action]
    namespace     = "production"

    if action_config["confirmation_required"]:
        # Send confirmation message with approve/cancel buttons
        client.chat_postMessage(
            channel=command["channel_id"],
            text=f"⚠️  Confirm: `{action}` on `{service}` in `{namespace}`?",
            blocks=[
                {
                    "type": "section",
                    "text": {
                        "type": "mrkdwn",
                        "text": (
                            f"*Runbook Action Request*\n"
                            f"Service: `{service}`\n"
                            f"Action: `{action}` — {action_config['description']}\n"
                            f"Risk: `{action_config['risk']}`\n"
                            f"Requested by: <@{command['user_id']}>"
                        )
                    }
                },
                {
                    "type": "actions",
                    "elements": [
                        {
                            "type":      "button",
                            "text":      {"type": "plain_text", "text": "✅ Confirm"},
                            "style":     "primary",
                            "action_id": "confirm_runbook",
                            "value":     f"{service}|{action}|{namespace}",
                        },
                        {
                            "type":      "button",
                            "text":      {"type": "plain_text", "text": "❌ Cancel"},
                            "style":     "danger",
                            "action_id": "cancel_runbook",
                        }
                    ]
                }
            ]
        )
    else:
        # Execute immediately for low-risk actions
        execute_runbook_action(service, action, namespace, command, say)

@app.action("confirm_runbook")
def handle_confirmation(ack, body, say):
    ack()
    value   = body["actions"][0]["value"]
    service, action, namespace = value.split("|")
    executor = body["user"]["id"]
    execute_runbook_action(
        service, action, namespace,
        {"user_id": executor},
        say
    )

def execute_runbook_action(
    service: str, action: str, namespace: str,
    command: dict, say
) -> None:
    action_config = APPROVED_ACTIONS[action]

    # Get current replica count for scale-up
    target = "10"  # Default
    if action == "scale-up":
        current = subprocess.check_output([
            "kubectl", "-n", namespace, "get", "deployment", service,
            "-o", "jsonpath={.spec.replicas}"
        ]).decode().strip()
        target = str(int(current) * 2) if current.isdigit() else "10"

    cmd = action_config["command"].format(
        service=service, namespace=namespace, target=target
    )

    say(f"⚙️  Executing: `{action}` on `{service}`...")
    logger.info("runbook_executed",
                extra={"service": service, "action": action,
                       "executor": command.get("user_id"), "cmd": cmd})

    try:
        result = subprocess.run(
            cmd, shell=True, capture_output=True, text=True, timeout=60
        )
        if result.returncode == 0:
            say(f"✅ `{action}` on `{service}` completed successfully.\n"
                f"```{result.stdout[:500]}```")
        else:
            say(f"❌ `{action}` on `{service}` failed:\n"
                f"```{result.stderr[:500]}```")
    except subprocess.TimeoutExpired:
        say(f"⏱️  Action `{action}` timed out after 60 seconds.")

if __name__ == "__main__":
    SocketModeHandler(app, "xapp-your-app-token").start()
```

#### Level 3: Triggered Auto-Remediation

```python
# auto_remediation.py — triggered by Alertmanager webhook
# Runs automated fixes for known, low-risk failure patterns

from flask import Flask, request, jsonify
import subprocess
import logging
import json
from datetime import datetime

app    = Flask(__name__)
logger = logging.getLogger(__name__)

# Remediation playbook — maps alert names to automated actions
# Only include actions with high confidence and low blast radius
REMEDIATION_PLAYBOOK = {
    "PodCrashLooping": {
        "action":       "restart_pod",
        "max_attempts": 2,          # Don't loop forever
        "notify":       True,
        "description":  "Restart crash-looping pod",
    },
    "HighConnectionPoolUtilization": {
        "action":       "kill_idle_db_connections",
        "max_attempts": 1,
        "notify":       True,
        "description":  "Kill idle DB connections to free pool headroom",
    },
    "DiskSpaceLow": {
        "action":       "clean_log_files",
        "max_attempts": 1,
        "notify":       True,
        "description":  "Clean old log files to free disk space",
    },
    "ServiceUnhealthy": {
        "action":       "rolling_restart",
        "max_attempts": 1,
        "notify":       True,
        "description":  "Initiate rolling restart of unhealthy service",
    },
}

@app.route("/webhook/alertmanager", methods=["POST"])
def handle_alert():
    """Receive alerts from Alertmanager and trigger remediation."""
    payload = request.json
    alerts  = payload.get("alerts", [])

    for alert in alerts:
        if alert.get("status") != "firing":
            continue   # Only remediate active alerts

        alert_name = alert.get("labels", {}).get("alertname", "")
        service    = alert.get("labels", {}).get("service", "")
        namespace  = alert.get("labels", {}).get("namespace", "production")
        pod        = alert.get("labels", {}).get("pod", "")

        if alert_name not in REMEDIATION_PLAYBOOK:
            logger.info(f"No remediation for alert: {alert_name}")
            continue

        playbook = REMEDIATION_PLAYBOOK[alert_name]
        logger.info(f"Auto-remediating {alert_name} on {service}")

        success = execute_remediation(
            action=playbook["action"],
            service=service,
            namespace=namespace,
            pod=pod,
            alert_name=alert_name
        )

        if playbook["notify"]:
            notify_slack(
                alert_name=alert_name,
                service=service,
                action=playbook["description"],
                success=success
            )

    return jsonify({"status": "processed"})

def execute_remediation(
    action: str, service: str, namespace: str,
    pod: str, alert_name: str
) -> bool:
    """Execute the remediation action."""
    try:
        if action == "restart_pod" and pod:
            result = subprocess.run(
                f"kubectl -n {namespace} delete pod {pod}",
                shell=True, capture_output=True, text=True, timeout=30
            )
        elif action == "rolling_restart" and service:
            result = subprocess.run(
                f"kubectl -n {namespace} rollout restart deployment/{service}",
                shell=True, capture_output=True, text=True, timeout=60
            )
        elif action == "kill_idle_db_connections":
            result = subprocess.run(
                """psql $DATABASE_URL -c "SELECT pg_terminate_backend(pid)
                   FROM pg_stat_activity
                   WHERE state = 'idle'
                   AND state_change < NOW() - INTERVAL '5 minutes';" """,
                shell=True, capture_output=True, text=True, timeout=30
            )
        elif action == "clean_log_files":
            result = subprocess.run(
                f"find /var/log/{service} -name '*.log' -mtime +7 -delete",
                shell=True, capture_output=True, text=True, timeout=30
            )
        else:
            logger.error(f"Unknown action: {action}")
            return False

        success = result.returncode == 0
        logger.info(
            f"Remediation {'succeeded' if success else 'failed'}",
            extra={"action": action, "service": service,
                   "alert": alert_name, "output": result.stdout[:200]}
        )
        return success

    except Exception as e:
        logger.error(f"Remediation error: {e}")
        return False

def notify_slack(
    alert_name: str, service: str, action: str, success: bool
) -> None:
    import requests as req
    import os
    status_emoji = "✅" if success else "❌"
    req.post(os.environ["SLACK_WEBHOOK"], json={
        "text": (
            f"{status_emoji} Auto-remediation: "
            f"`{alert_name}` on `{service}` — "
            f"{action} {'succeeded' if success else 'FAILED'}"
        )
    })

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
```

#### Level 4: Kubernetes Self-Healing Operator

```python
# Simple Kubernetes controller (using kopf framework)
# Watches for services in degraded state and auto-remediates

import kopf
import kubernetes
import logging

kubernetes.config.load_incluster_config()
apps_v1 = kubernetes.client.AppsV1Api()
logger  = logging.getLogger(__name__)

@kopf.on.field(
    "apps", "v1", "deployments",
    field="status.unavailableReplicas"
)
def on_unavailable_replicas_change(
    old, new, name, namespace, body, **kwargs
):
    """
    React when a deployment has unavailable replicas.
    If > 50% of pods are unavailable for > 2 minutes,
    attempt automated rollback.
    """
    if new is None or new == 0:
        return   # No unavailable replicas — healthy

    spec        = body.get("spec", {})
    total       = spec.get("replicas", 1)
    unavailable = new or 0

    unavailable_pct = unavailable / total if total > 0 else 0
    logger.warning(
        f"Deployment {name} in {namespace}: "
        f"{unavailable}/{total} pods unavailable ({unavailable_pct:.0%})"
    )

    if unavailable_pct > 0.5:
        logger.error(
            f"CRITICAL: {name} has {unavailable_pct:.0%} unavailable pods. "
            f"Initiating auto-rollback."
        )

        # Check if this deployment has a previous revision to roll back to
        history = apps_v1.read_namespaced_deployment(name=name, namespace=namespace)
        annotations = history.metadata.annotations or {}
        revision = annotations.get("deployment.kubernetes.io/revision", "1")

        if int(revision) > 1:
            # Perform rollback via annotation (triggers Kubernetes rollback)
            patch = {
                "spec": {
                    "template": {
                        "metadata": {
                            "annotations": {
                                "kubectl.kubernetes.io/last-applied-configuration": None
                            }
                        }
                    }
                }
            }
            # In production: use kubectl rollout undo or proper rollback API
            logger.info(f"Auto-rollback triggered for {name}")

            # Notify on-call
            notify_oncall_of_auto_remediation(
                service=name, namespace=namespace,
                action="auto-rollback",
                reason=f"{unavailable_pct:.0%} of pods unavailable"
            )

def notify_oncall_of_auto_remediation(
    service: str, namespace: str, action: str, reason: str
) -> None:
    """
    Always notify on-call when automation takes action.
    Automation should never be invisible to the human on-call.
    """
    import requests, os
    requests.post(os.environ["PAGERDUTY_WEBHOOK"], json={
        "payload": {
            "summary":  f"Auto-remediation: {action} on {service}",
            "severity": "warning",
            "source":   "sre-operator",
            "custom_details": {
                "service":   service,
                "namespace": namespace,
                "action":    action,
                "reason":    reason,
                "note":      "Automated remediation took action. Verify recovery."
            }
        },
        "routing_key": os.environ["PAGERDUTY_ROUTING_KEY"],
        "event_action": "trigger"
    })
```

---

### 8.10 On-Call Metrics and Health Tracking {#810-on-call-metrics}

```python
def generate_oncall_health_report(
    incidents: list,
    window_weeks: int = 4
) -> dict:
    """
    Generate on-call health report for team retrospective.
    Identifies patterns requiring process improvement.
    """
    from collections import Counter
    import statistics

    total_pages        = len(incidents)
    pages_per_week     = total_pages / window_weeks
    night_pages        = [i for i in incidents
                          if 0 <= i.get("hour_utc", 12) < 8]
    weekend_pages      = [i for i in incidents
                          if i.get("day_of_week", 0) in [5, 6]]

    durations          = [i.get("duration_minutes", 0) for i in incidents
                          if i.get("duration_minutes")]
    avg_duration       = statistics.mean(durations) if durations else 0

    actionable         = [i for i in incidents
                          if i.get("required_action", False)]
    actionability_rate = len(actionable) / total_pages if total_pages > 0 else 0

    # Most frequent alert sources
    alert_counts = Counter(i.get("alertname", "unknown") for i in incidents)
    top_alerts   = alert_counts.most_common(5)

    # Calculate MTTR
    mttr_minutes = statistics.mean(durations) if durations else 0

    health_score = _calculate_health_score(
        pages_per_week, actionability_rate, mttr_minutes,
        len(night_pages), total_pages
    )

    return {
        "window_weeks":        window_weeks,
        "total_pages":         total_pages,
        "pages_per_week":      round(pages_per_week, 1),
        "night_pages":         len(night_pages),
        "night_page_pct":      f"{len(night_pages)/total_pages:.1%}" if total_pages else "0%",
        "weekend_pages":       len(weekend_pages),
        "actionability_rate":  f"{actionability_rate:.1%}",
        "avg_duration_min":    round(avg_duration, 1),
        "mttr_minutes":        round(mttr_minutes, 1),
        "top_alert_sources":   top_alerts,
        "health_score":        health_score,
        "recommendations":     _get_recommendations(
            pages_per_week, actionability_rate, mttr_minutes, night_pages, total_pages
        ),
    }

def _calculate_health_score(
    pages_per_week, actionability_rate, mttr_minutes,
    night_pages, total_pages
) -> str:
    score = 100
    if pages_per_week > 10:    score -= 30
    elif pages_per_week > 5:   score -= 15
    if actionability_rate < 0.6: score -= 25
    elif actionability_rate < 0.8: score -= 10
    if mttr_minutes > 60:      score -= 20
    elif mttr_minutes > 30:    score -= 10
    night_pct = night_pages / total_pages if total_pages > 0 else 0
    if night_pct > 0.4:        score -= 15

    return (
        f"🟢 Healthy ({score}/100)"  if score >= 80 else
        f"🟡 Warning ({score}/100)"  if score >= 60 else
        f"🔴 Critical ({score}/100)"
    )

def _get_recommendations(
    pages_per_week, actionability_rate, mttr_minutes,
    night_pages, total_pages
) -> list:
    recs = []
    if pages_per_week > 10:
        recs.append("🔴 Page volume critical (>10/week). Immediate alert review required.")
    if actionability_rate < 0.7:
        recs.append("⚠️  Low actionability. Audit non-actionable alerts and raise thresholds.")
    if mttr_minutes > 45:
        recs.append("⚠️  High MTTR. Review runbook quality and diagnostic tooling.")
    if night_pages and total_pages and len(night_pages)/total_pages > 0.3:
        recs.append("⚠️  >30% of pages are overnight. Improve alert thresholds and runbook automation.")
    if not recs:
        recs.append("✅ On-call health is good. Continue monitoring trends.")
    return recs
```

#### On-Call Health Target Metrics

```
Metric                     Target       Warning      Critical
──────────────────────────────────────────────────────────────
Pages/week/engineer        2-5          6-10         >10
Actionability rate         >85%         70-85%       <70%
Night pages (midnight-8am) <15%         15-30%       >30%
MTTR (SEV1)                <30 min      30-60 min    >60 min
False positive rate        <10%         10-25%       >25%
Post-mortem completion     >90% (48h)   75-90%       <75%
Runbook coverage           100% alerts  —            Any alert
                           have runbook              without runbook
──────────────────────────────────────────────────────────────
```

---

### 8.11 Tooling Ecosystem {#811-tooling-ecosystem}

```
On-Call Tooling Stack
──────────────────────────────────────────────────────────────────────
Layer           Tool Options              Purpose
──────────────────────────────────────────────────────────────────────
Alerting        Prometheus Alertmanager   Alert routing, grouping,
                Grafana Alerting          silencing, inhibition
                Datadog Monitors

On-Call         PagerDuty                 Schedules, escalation policies,
Management      OpsGenie                  on-call analytics
                Grafana OnCall (OSS)

Incident        Incident.io               War room coordination,
Coordination    FireHydrant               timeline automation,
                Blameless                 status page integration

Communication   Slack                     War room channels,
                Microsoft Teams           ChatOps bot integration

Runbook         Confluence                Runbook hosting
Hosting         GitBook                   Version-controlled runbooks
                Notion                    Collaborative runbooks

Automation      Ansible AWX               Playbook execution
                Rundeck                   Job scheduling and automation
                Argo Events               Kubernetes event automation
                Kopf                      Kubernetes operator framework

Status Page     Atlassian Statuspage      Customer-facing status
                Cachet (OSS)              Incident history

Mobile          PagerDuty Mobile          Alert acknowledgment
                OpsGenie Mobile           On-call status
──────────────────────────────────────────────────────────────────────
```

---

## Key Principles & Best Practices {#key-principles}

1. **On-call must be sustainable or it will collapse.** An on-call program that burns engineers out doesn't improve reliability — it destroys the team that maintains reliability. Enforce compensation, recovery time, and page volume limits non-negotiably.

2. **Every page must be actionable or it must be fixed.** Track actionability rate monthly. Any alert that fires more than twice without requiring action should be tuned, raised, or deleted. The second non-actionable page is a bug report against your alerting system.

3. **The first 5 minutes of an incident are the highest-leverage time.** The on-call engineer's first actions determine whether MTTR is 15 minutes or 3 hours. Invest in first-response tooling: automated diagnostics, first-response checklists, and pre-approved authority to act.

4. **Automation must always notify humans.** Self-healing systems are invaluable, but invisible automation is dangerous. Every automated remediation action must generate a notification so the on-call engineer knows what the system did, can verify recovery, and can intervene if the automation is wrong.

5. **Runbook quality is a reliability multiplier.** A runbook that saves 20 minutes per incident, across 5 incidents per month, saves 100 engineer-minutes per month. Multiply across 10 services and 3 years — the investment compounds. Treat runbook updates with the same priority as code changes.

6. **Cognitive load is the enemy of effective response.** Every decision that can be pre-made (authority charter, severity framework, first-response checklist) should be. Reducing cognitive load in the first 5 minutes of an incident has a higher ROI than almost any other on-call investment.

7. **Handoff quality determines rotation continuity.** A bad handoff means the incoming engineer starts their shift at an information disadvantage. The handoff template is not optional — it is the primary context transfer mechanism in a distributed, rotating team.

---

## Tools & Technologies {#tools}

| Tool | Category | On-Call Use Case |
|---|---|---|
| **PagerDuty** | On-call Platform | Schedules, escalation policies, incident analytics, mobile app |
| **OpsGenie** | On-call Platform | Alternative to PagerDuty; ITSM integrations, stakeholder notifications |
| **Grafana OnCall** | On-call (OSS) | Open-source on-call management integrated with Grafana stack |
| **Incident.io** | Incident Management | Slack-native incident workflow, auto-timeline, post-mortem |
| **FireHydrant** | Incident Management | Runbook integration, automated checklists, retrospectives |
| **Alertmanager** | Alert Routing | Routing, grouping, deduplication, inhibition, silencing |
| **Slack Bolt** | ChatOps | Runbook bot, incident coordination, status updates |
| **Rundeck** | Runbook Automation | Scheduled and triggered job automation with audit trail |
| **Ansible AWX** | Runbook Automation | Playbook-based remediation with approval workflows |
| **Kopf** | K8s Operator Framework | Self-healing Kubernetes controllers |

---

## Hands-on Exercises / Labs {#labs}

### Lab 8.1 — On-Call Health Audit

**Goal:** Audit an on-call program and produce a health improvement plan.

**Given:** 4 weeks of on-call data for a 6-person SRE team covering a checkout platform:
```
Total pages:          87 over 4 weeks
Night pages (0-8am):  34 (39% of total)
Weekend pages:        22 (25% of total)
Actionable pages:     51 (59% of total)
Average MTTR:         52 minutes
Top alert sources:    HighCPU (28), ConnectionPool (19), PodRestart (17), SlowQuery (14), Other (9)
Rotation:             6 engineers, weekly shifts
Compensation:         $200/week stipend, no comp time
```

**Tasks:**
1. Run the `generate_oncall_health_report()` function with this data. What health score does it produce?
2. Identify the top 3 problems with this on-call program (use the health metrics table).
3. For the top alert source (HighCPU, 28 pages in 4 weeks), design a remediation plan: tighten threshold? Automate? Convert to ticket? Justify your choice.
4. Redesign the compensation model to be fair given the page volume and night page rate.
5. Write a 1-page "On-Call Health Improvement Plan" for the engineering manager, including: current state, target state, top 3 actions, success metrics, and 90-day timeline.

---

### Lab 8.2 — Escalation Policy Design

**Goal:** Design and implement a complete escalation policy for a multi-service platform.

**Given:**
- Platform: Payments + Checkout + Search + User Auth
- Team size: 12 SREs, 4 per service area
- Business hours: 9am–6pm ET Mon–Fri
- SLAs: Payments (99.99%), Checkout (99.9%), Search (99.5%), Auth (99.99%)

**Tasks:**
1. Design the rotation structure: how many rotations? What model (primary/secondary, follow-the-sun, weekly)? Justify given team size and SLA requirements.
2. Define escalation policy tiers for each SLA tier (99.99% needs faster escalation than 99.5%). What are the acknowledgment time targets for each?
3. Write the Alertmanager routing configuration that routes payment and auth alerts separately from search alerts, with different timeout windows.
4. Define the authority charter for on-call engineers: what can they do without approval? What requires secondary approval?
5. Write the on-call handoff template customized for a payments platform (what specific information is critical for this domain?).

---

### Lab 8.3 — Runbook Automation Implementation

**Goal:** Build a Level 2 (ChatOps) and Level 3 (triggered automation) runbook for a specific alert.

**Alert:**
```yaml
- alert: HighDatabaseConnectionPoolUtilization
  expr: pg_stat_activity_count{state="active"} / pg_settings_max_connections > 0.80
  for: 3m
  labels:
    severity: warning
    service: checkout
  annotations:
    summary: "DB connection pool at {{ $value | humanizePercentage }}"
```

**Tasks:**
1. Write the Level 1 diagnostic script (`db_diagnose.sh`) that runs automatically and outputs: active connections by application, idle connections by age, top 5 slowest queries, and connection pool setting.
2. Extend the ChatOps bot to support `/runbook checkout db-pool-relief` — which kills idle connections older than 5 minutes and reports connections freed.
3. Write the Level 3 triggered automation (Alertmanager webhook handler) that automatically kills idle connections when pool exceeds 85% and notifies the on-call channel.
4. Write the decision logic for Level 3: under what conditions should automation NOT run? (e.g., if MTTR for this alert is already 0 min via autoscaling, don't add another action; if pool has been at 100% for > 10 min, escalate rather than just killing connections)
5. Implement the "automation circuit breaker": if the automated kill-connections action has run 3 times in 1 hour without the alert resolving, disable automation and escalate to on-call.

---

### Lab 8.4 — Cognitive Load Simulation (Tabletop)

**Goal:** Practice first-response decision-making under simulated pressure.

**Setup:** Set a 5-minute timer. You receive this PagerDuty alert at 3:17am:

```
ALERT: SLO_Availability_FastBurn_P1 [FIRING]
Service: checkout-api
Burn Rate: 18.4× (1h window)
Error Rate: 1.84%
Budget Remaining: 12%
Dashboard: https://grafana.internal/d/checkout-slo
Runbook: https://runbooks.internal/checkout/high-error-rate
```

**Within 5 minutes, complete ALL of the following:**
1. Write the first response checklist steps you take in order.
2. Write your initial war room message (post to #incidents within 2 minutes).
3. You open the dashboard and see: error rate spike began 8 minutes ago, traffic is normal, last deployment was 6 hours ago, payment service health endpoint is returning 503. Assign severity. Justify.
4. You have 2 other engineers available. Assign roles and write the opening war room statement.
5. Write the status page update to post within 5 minutes of alert.

**After the timer:** Review your responses against the frameworks in this chapter. Where did cognitive load slow you down? What would a checklist or template have helped with?

---

## Common Pitfalls & Anti-patterns {#pitfalls}

**Anti-pattern 1: Hero culture on-call**
One or two senior engineers handle all significant incidents because "they know the system best." Junior engineers are never on primary rotation. The senior engineers are chronically sleep-deprived and resentful. When they leave, the team has no on-call capability. *Fix:* Shadow rotations for every new engineer. Primary rotation for all engineers within 90 days of joining. Runbooks encode the knowledge that was previously in senior engineers' heads.

**Anti-pattern 2: Acknowledging pages without investigating**
On-call engineers acknowledge pages immediately to stop the escalation clock — then go back to sleep without investigating. Alerts are "resolved" by the system without any human action. Actionability rate appears high; actual response quality is zero. *Fix:* Require incident ticket creation for every acknowledgment. Track: was an action taken? Did the alert resolve because of that action? Surface patterns where pages are acked but not investigated.

**Anti-pattern 3: Runbook as a historical document**
Runbooks are written when a service launches and never updated. By 18 months in, the runbook references services that no longer exist, commands that no longer work, and escalation paths that are out of date. The on-call engineer opens the runbook during an incident and it actively misleads them. *Fix:* Runbooks have owners and review dates. Every post-mortem includes a runbook review step. Any runbook step that fails during an incident is fixed before the incident ticket closes.

**Anti-pattern 4: Automated remediation without notification**
A Kubernetes operator silently restarts pods, kills connections, and scales services 50 times per month. The on-call engineer never sees these actions. A silent action masks a growing reliability problem — the system appears healthy (alerts auto-resolve) while the underlying issue worsens. *Fix:* All automated actions emit a notification (Slack, low-urgency PagerDuty). The on-call engineer reviews automation actions daily. If automation fires more than 3 times for the same issue in 24 hours, it escalates instead of retrying.

**Anti-pattern 5: Escalation policy as punishment**
Engineers dread being escalated to because it implies they failed. They avoid escalating until the situation is dire. Escalation happens too late, after the SLA is already at risk. *Fix:* Frame escalation as information sharing, not failure reporting. "I'm escalating to the DBA because I need database expertise" is not a failure — it is correct incident management. Celebrate escalations that prevented SLA breaches.

**Anti-pattern 6: One-size-fits-all paging**
All alerts page with the same urgency — full phone calls at 3am for a dev environment CPU spike. Engineers tune out because everything feels like an emergency. *Fix:* Differentiate paging by SLO impact and time of day. Use push notifications for P2 during business hours, phone calls for P1 at any hour. Reserve voice calls and SMS for genuine user-impacting incidents.

---

## Interview Questions {#interview-questions}

**Conceptual:**

1. *"What makes an on-call program 'healthy'? What are the most important metrics you would track to evaluate it?"*
   — Look for: actionability rate (>85%), pages per week per engineer (2-5), night page percentage (<15%), MTTR, compensation model, recovery time protection; cultural aspects: blameless debrief, authority charter, rotation fairness.

2. *"What is the difference between cognitive load and burnout in on-call context? How do you address each?"*
   — Look for: cognitive load = mental overhead per incident (addressed with checklists, templates, pre-made decisions, runbooks, diagnostics tools); burnout = cumulative exhaustion from sustained overload (addressed with page volume limits, compensation, recovery time, rotation size, automation to reduce pages).

3. *"Explain the four levels of runbook automation. When would you NOT automate a remediation step?"*
   — Look for: Level 0-4 (manual → scripted → ChatOps → triggered → self-healing); should NOT automate: actions with high blast radius (DB failover), situations requiring human judgment (root cause unknown), actions that would mask a growing problem, anything that has failed to resolve in > 3 automated attempts.

**Scenario-based:**

4. *"Your team's on-call rotation has 4 engineers. Two are leaving in the next month. The remaining 2 engineers will be on-call 50% of the time. How do you handle this?"*
   — Look for: immediate — add secondary rotation (managers, senior ICs) as backup; escalate to engineering management; pause hiring-dependent reliability work; increase automation to reduce page volume; medium-term — prioritize hiring with on-call capacity as explicit requirement; consider whether the rotation can be merged with another team temporarily; never accept a 2-person rotation for a business-critical service without a formal risk acknowledgment and a plan.

5. *"You join a team where the on-call engineer is being paged 20 times per week, 40% of pages are at night, and engineers are visibly burned out. You have been asked to fix this in 90 days. What do you do?"*
   — Look for: day 1 — quantify and categorize (what alerts, what times, actionability rate); week 1 — identify the top 3 alert sources and silence/raise threshold for demonstrably non-actionable ones; week 2-4 — implement automation for top 2 auto-remediatable alerts; month 2 — runbook review, improve first-response tooling; month 3 — review rotation size, propose staffing if page volume is fundamentally too high for team size; measure: pages/week trend, actionability rate, night page percentage; present progress to leadership monthly.

---

## Further Reading & Resources {#further-reading}

**Books:**
- *Site Reliability Engineering* — Chapters 11 & 12: Being On-Call, Effective Troubleshooting (Google, O'Reilly) — The foundational on-call framework
- *The Site Reliability Workbook* — Chapter 9: Incident Management — Practical incident command implementation
- *Incident Management for Operations* — Rob Schnepp et al. (O'Reilly) — ICS for technology operations

**Online:**
- [PagerDuty Incident Response Guide](https://response.pagerduty.com/) — Free, comprehensive playbook covering all aspects of on-call
- [Google's On-Call Philosophy](https://sre.google/sre-book/being-on-call/) — Authoritative treatment of sustainable on-call
- [Charity Majors: On Call Doesn't Have to Suck](https://charity.wtf/2020/10/03/on-call-doesnt-have-to-suck/) — Practitioner perspective on healthy on-call culture
- [Brendan Gregg: The USE Method for Linux](https://www.brendangregg.com/USEmethod/use-linux.html) — First-response resource utilization methodology

**Talks:**
- "Making On-Call Not Suck" — Alice Goldfuss (SREcon) — Cultural and process improvements
- "Sustainable On-Call" — Liz Fong-Jones (SREcon) — Engineering for on-call sustainability
- "ChatOps at GitHub" — Jesse Newland (Velocity) — Automation via ChatOps

---

## Key Takeaways {#key-takeaways}

> **Chapter 8 Summary**
>
> - **On-call is not a punishment — it is a defined operational responsibility** that requires compensation, recovery time, clear authority, and psychological safety. Programs that treat it otherwise experience burnout, attrition, and degraded response quality.
>
> - **Healthy on-call has five characteristics:** compensation, post-incident recovery protection, 100% actionable pages, explicit pre-approved authority to act, and blameless post-incident debriefs.
>
> - **Paging design is the primary lever for on-call health.** Alert only when a user is experiencing degraded service AND human action is required AND the burn rate justifies waking someone. Non-actionable pages are bugs in the alerting system.
>
> - **Escalation policies must be automated, not negotiated.** The sequence of who gets paged when no one responds must be defined before the incident, not decided during it. Multi-tier escalation with pre-defined timeouts eliminates decision overhead when it is most costly.
>
> - **Cognitive load is the enemy of effective first response.** First-response checklists, pre-made authority decisions, structured status update templates, and automated diagnostics each reduce cognitive overhead during the most high-pressure minutes of an incident.
>
> - **Runbook automation has four levels** — manual, scripted diagnostics, ChatOps one-click, and triggered self-healing. Each level reduces MTTR. Level 4 (self-healing) requires high confidence, low blast radius, and mandatory human notification for every automated action.
>
> - **On-call health must be measured.** Track pages per week, actionability rate, night page percentage, and MTTR monthly. Present trends to leadership. If any metric is in the Critical zone, it is an engineering emergency — not a personal failing.
>
> - **Handoff quality is the continuity mechanism.** A structured handoff template covering open incidents, silenced alerts, upcoming risky changes, and fragile areas is the primary knowledge transfer between rotation shifts.

---

*Previous: [Chapter 7 — Capacity Planning](#chapter-7)*
*Next: Chapter 9 — Root Cause Analysis and Post-Mortems*

---

*Document version: 1.0 | Study Guide: High Performance SRE | Chapter 8 of 12*
