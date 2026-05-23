# High Performance Site Reliability Engineering: A Complete Study Guide

---

# Chapter 9 — Root Cause Analysis and Post-Mortems

---

## Table of Contents

- [Learning Objectives](#learning-objectives)
- [Core Concepts](#core-concepts)
  - [9.1 Why Post-Mortems Exist](#91-why-post-mortems-exist)
  - [9.2 Blameless Culture — The Foundation](#92-blameless-culture)
  - [9.3 When to Write a Post-Mortem](#93-when-to-write)
  - [9.4 Timeline Reconstruction](#94-timeline-reconstruction)
  - [9.5 Root Cause Analysis Methods](#95-rca-methods)
  - [9.6 The 5-Whys Technique](#96-five-whys)
  - [9.7 Fishbone (Ishikawa) Diagram Analysis](#97-fishbone)
  - [9.8 Contributing Factors vs Root Causes](#98-contributing-factors)
  - [9.9 Writing Effective Post-Mortem Documents](#99-writing-post-mortems)
  - [9.10 Action Item Tracking and Accountability](#910-action-item-tracking)
  - [9.11 Learning from Incidents at Scale](#911-learning-at-scale)
  - [9.12 Post-Mortem Anti-Patterns and Rescue Techniques](#912-antipatterns)
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

- Explain the philosophical and practical case for blameless post-mortems, and identify the specific organizational behaviors that undermine psychological safety during incident reviews.
- Reconstruct an accurate, timestamped incident timeline from disparate sources — logs, alerts, chat history, and monitoring data — and identify the moments of detection, diagnosis, and decision.
- Apply the 5-Whys technique and Fishbone analysis rigorously, avoiding the common traps of stopping too early, anchoring on the proximate cause, and treating human error as a root cause.
- Write a post-mortem document that is clear, factually precise, blameless in tone, and structured to drive action — not to assign responsibility.
- Design and operate an action item tracking system that converts post-mortem insights into completed engineering work, with measurable impact on reliability.

---

## Core Concepts {#core-concepts}

### 9.1 Why Post-Mortems Exist {#91-why-post-mortems-exist}

Every production incident has a cost: direct revenue loss, user trust erosion, engineer time, and the psychological toll on the team. The post-mortem is the mechanism by which that cost is converted into organizational learning — the only way to ensure the investment has a return.

Without post-mortems, incidents are pure loss. With high-quality post-mortems and completed action items, incidents become the most efficient source of reliability knowledge an engineering organization can have.

```
The Post-Mortem Value Equation

Incident Cost    =  Revenue lost + Engineer time + Trust damage
                                          ▼
Without post-mortem:  Pure loss — cost paid, no return
                                          ▼
With poor post-mortem: Marginal return — time spent, learnings vague,
                       actions never completed
                                          ▼
With excellent post-mortem + completed actions:
    Cost becomes an investment in:
      → Preventing recurrence of this specific failure
      → Building systemic awareness of failure modes
      → Improving detection and response tooling
      → Growing organizational reliability knowledge
      → Calibrating risk models for future decisions
```

The post-mortem does not undo the incident. It determines whether the incident was a pure cost or a learning investment. The difference between organizations that continuously improve reliability and those that fight the same fires indefinitely is almost entirely in post-mortem quality and action item completion.

**The five outputs of an excellent post-mortem:**

1. An accurate factual record of what happened, preserved before memory decays
2. A clear causal chain from contributing factors through root causes to user impact
3. Specific, actionable, owned remediation items that prevent recurrence
4. Systemic insights that improve practices beyond this single incident
5. A demonstration of organizational maturity — we learn from failure without hiding it

---

### 9.2 Blameless Culture — The Foundation {#92-blameless-culture}

Blameless post-mortem culture is not about being "nice." It is an epistemological commitment to finding truth — and the recognition that blame is incompatible with truth-finding.

When engineers fear punishment for their role in an incident, they:
- Withhold information that implicates them
- Reconstruct timelines favorably to themselves
- Avoid being on-call when they might make consequential decisions
- Stop taking risks that might produce valuable learning

The result is an organization that punishes the visible symptoms of systemic problems while leaving the underlying causes intact.

```
The Blame Trap
──────────────────────────────────────────────────────────────────
Incident occurs
    │
    ▼
Blame-oriented review:
  "Who deployed the bad code?"
  "Why didn't the on-call catch it faster?"
  "Who approved this change?"
    │
    ▼
Engineer identified as responsible
    │
    ▼
Engineer punished / warned / publicly shamed
    │
    ▼
Organization believes: "Problem solved — bad engineer identified"
    │
    ▼
Systemic causes remain intact:
  → Deployment pipeline had no canary
  → Alert thresholds were too permissive
  → Runbook was three years out of date
  → System had known single point of failure
    │
    ▼
Same failure mode recurs in 3 months
──────────────────────────────────────────────────────────────────
```

#### The Just Culture Model

The blameless model does not mean zero accountability — it means accountability at the correct level. Adapted from Sidney Dekker's "Just Culture" framework:

```
Action Category        Organizational Response
─────────────────────────────────────────────────────────────────
Human error            Console and support the person.
(slip, mistake)        Investigate the system that allowed
                       the error to have impact.

At-risk behavior       Coach and correct. Understand why
(shortcuts taken due   the behavior was chosen — usually
to competing pressures) system design made the risky path
                       the easy path.

Reckless behavior      Accountability appropriate. Rare in
(conscious disregard   well-functioning engineering teams.
of substantial risk)   Verify: is this truly recklessness
                       or a system design problem?

Systemic failure       Redesign the system. No individual
(most incidents)       accountability.
─────────────────────────────────────────────────────────────────
```

#### Language That Protects Psychological Safety

Post-mortem language shapes culture. The same factual content can be written in a way that creates or destroys psychological safety:

```
Blame Language                    Blameless Language
──────────────────────────────────────────────────────────────────────
"Bob deployed bad code"           "A deployment introduced a regression"

"The on-call missed the alert"    "The alert threshold was set too
                                   permissively to detect the issue"

"Alice should have tested this"   "The test suite did not cover this
                                   code path"

"The team failed to follow the    "The runbook did not address this
 runbook"                          failure scenario"

"Human error caused the outage"   "The system design did not prevent
                                   a predictable human action from
                                   causing user impact"
──────────────────────────────────────────────────────────────────────
```

**The Counterfactual Test:** Before including any statement about a person's action, ask: "If a different, equally experienced engineer had been in this exact situation, with the same information, tools, and pressures — would they have made the same choice?" If yes, the system needs to change, not the person.

#### Running a Blameless Post-Mortem Meeting

```python
def blameless_meeting_checklist() -> list:
    """
    Pre-meeting preparation and facilitation guidelines
    for a blameless post-mortem review meeting.
    """
    return [
        # Before the meeting
        "Circulate the draft document 24 hours before",
        "Explicitly set the blameless norm at meeting open",
        "Assign a dedicated facilitator (not the incident IC)",
        "Invite all responders — not just senior engineers",
        "Block 60-90 minutes — do not rush",

        # Opening statement (read verbatim):
        # 'The goal of this meeting is to understand what happened
        #  and how to prevent it — not to evaluate performance.
        #  There are no stupid questions. Everything said here
        #  is focused on the system, not the people.
        #  If you hear anything that feels like blame, call it out.',

        # During the meeting
        "Walk through timeline chronologically — no skipping to 'the cause'",
        "For each decision point: what information did they have at the time?",
        "When someone says 'I should have...' — reframe: 'what would have helped?'",
        "Capture every action item as it arises — do not defer",
        "Ask: 'what would have to be true for this not to happen again?'",
        "Ensure quieter voices are heard — not just the loudest engineers",

        # Red flags to intervene on
        "Stop any statement that names an individual as a cause",
        "Stop any statement that uses 'should have' without system follow-up",
        "Stop any statement that accepts 'human error' as a final answer",

        # Closing
        "Confirm all action items have owners and due dates before adjourning",
        "Thank participants — incidents are stressful; post-mortems are vulnerable",
        "Set follow-up review date for action item progress",
    ]
```

---

### 9.3 When to Write a Post-Mortem {#93-when-to-write}

```
Post-Mortem Trigger Criteria
──────────────────────────────────────────────────────────────────
MANDATORY (SEV1 or any of these):
  → Any customer-facing outage lasting > 5 minutes
  → Any SLA breach (customer contractual obligation violated)
  → Any data loss or data corruption, regardless of scope
  → Any security incident or unauthorized access event
  → Any incident requiring executive escalation
  → Any incident causing > $10,000 estimated revenue impact

RECOMMENDED (SEV2 or any of these):
  → Repeated SEV3 incidents with the same root cause (2+ in 30 days)
  → Any incident that consumed > 20% of the monthly error budget
  → Near-misses: failure that would have been SEV1 if not caught early
  → Any incident where the runbook was significantly wrong or missing
  → Any incident where MTTR exceeded 2× the target

LIGHTWEIGHT REVIEW (SEV3/4):
  → Bug in alerting that caused a false alarm page
  → Deployment that required immediate rollback
  → Configuration error caught in staging before production
──────────────────────────────────────────────────────────────────

Timing:
  Draft started:     Within 24 hours of resolution
  Draft circulated:  Within 48 hours
  Review meeting:    Within 72 hours (while memory is fresh)
  Document finalized: Within 5 business days
  Action items due:  Agreed at meeting; tracked in sprint system
```

---

### 9.4 Timeline Reconstruction {#94-timeline-reconstruction}

The incident timeline is the factual backbone of the post-mortem. It must be precise, timestamped, and reconstructed from authoritative sources — not from memory.

Memory is unreliable after incidents. Studies of aviation post-mortems consistently show that participants' memories of event sequences diverge significantly from objective records within 24–48 hours. The post-mortem timeline must be sourced from logs.

#### Data Sources for Timeline Reconstruction

```
Source                  What It Captures                    Reliability
───────────────────────────────────────────────────────────────────────
Prometheus/Grafana       Metric changes, alert fires         High
                         (timestamped to second)

Application logs         Error events, specific failures     High
(ELK/Loki)              (structured logs are better)

Kubernetes events        Pod restarts, scaling events        High
(kubectl get events)     Node failures, scheduling

Deployment logs          Deploy timestamps, versions         High
(CI/CD system)           rolled back

PagerDuty / OpsGenie     Alert fire time, ack time,          High
                         escalation events

Scribe log / war room    Responder observations,             Medium
(Slack/Jira)             decisions, hypotheses

Chat history (Slack)     Informal observations, DMs          Medium
                         (incomplete record)

Engineer memory          Subjective recall                   Low
                         (use only to fill gaps,
                          verify against logs)
───────────────────────────────────────────────────────────────────────
```

#### Automated Timeline Extraction

```python
#!/usr/bin/env python3
"""
timeline_extractor.py — Extract incident timeline from multiple sources
Produces a unified, chronological timeline for post-mortem documentation.
"""

import requests
import subprocess
import json
from datetime import datetime, timedelta, timezone
from dataclasses import dataclass, field
from typing import List, Optional
import re

@dataclass
class TimelineEvent:
    timestamp:   datetime
    source:      str          # prometheus | k8s | slack | pagerduty | deploy
    event_type:  str          # alert | error | scale | deploy | ack | note
    description: str
    actor:       Optional[str] = None    # Engineer/system that took action
    raw_data:    Optional[dict] = None

    def to_markdown(self) -> str:
        actor_str  = f" — *{self.actor}*" if self.actor else ""
        ts_str     = self.timestamp.strftime("%H:%M:%S UTC")
        source_tag = f"[{self.source.upper()}]"
        return f"| {ts_str} | {source_tag} {self.description}{actor_str} |"

class TimelineExtractor:

    def __init__(
        self,
        prometheus_url: str,
        namespace:      str = "production"
    ):
        self.prometheus_url = prometheus_url
        self.namespace      = namespace
        self.events:        List[TimelineEvent] = []

    def extract_prometheus_alerts(
        self,
        service:    str,
        start_time: datetime,
        end_time:   datetime
    ) -> None:
        """Extract alert firing events from Prometheus."""
        query = f"""
            changes(ALERTS{{
                service="{service}",
                alertstate="firing"
            }}[{int((end_time - start_time).total_seconds())}s])
        """
        try:
            resp = requests.get(
                f"{self.prometheus_url}/api/v1/query_range",
                params={
                    "query": f'ALERTS{{service="{service}"}}',
                    "start": start_time.timestamp(),
                    "end":   end_time.timestamp(),
                    "step":  "60s"
                },
                timeout=10
            )
            for series in resp.json().get("data", {}).get("result", []):
                alert_name = series["metric"].get("alertname", "unknown")
                for ts, value in series["values"]:
                    if float(value) == 1:  # Alert is firing
                        self.events.append(TimelineEvent(
                            timestamp=datetime.fromtimestamp(
                                float(ts), tz=timezone.utc
                            ),
                            source="prometheus",
                            event_type="alert",
                            description=f"Alert FIRING: {alert_name}",
                            raw_data=series["metric"]
                        ))
        except Exception as e:
            print(f"Warning: Could not extract Prometheus alerts: {e}")

    def extract_kubernetes_events(
        self,
        service:    str,
        start_time: datetime,
        end_time:   datetime
    ) -> None:
        """Extract Kubernetes events for a service."""
        try:
            output = subprocess.check_output([
                "kubectl", "-n", self.namespace,
                "get", "events",
                f"--field-selector=involvedObject.name={service}",
                "--sort-by=.metadata.creationTimestamp",
                "-o", "json"
            ], timeout=15).decode()

            events_data = json.loads(output)
            for event in events_data.get("items", []):
                event_time_str = (
                    event.get("lastTimestamp") or
                    event.get("eventTime") or
                    event.get("metadata", {}).get("creationTimestamp")
                )
                if not event_time_str:
                    continue

                event_time = datetime.fromisoformat(
                    event_time_str.replace("Z", "+00:00")
                )
                if not (start_time <= event_time <= end_time):
                    continue

                reason  = event.get("reason", "unknown")
                message = event.get("message", "")
                kind    = event.get("involvedObject", {}).get("kind", "")

                self.events.append(TimelineEvent(
                    timestamp=event_time,
                    source="kubernetes",
                    event_type=reason.lower(),
                    description=f"{kind} {reason}: {message[:120]}",
                    raw_data=event
                ))
        except Exception as e:
            print(f"Warning: Could not extract K8s events: {e}")

    def extract_deployment_history(
        self,
        service:    str,
        start_time: datetime,
        end_time:   datetime
    ) -> None:
        """Extract deployment history from kubectl rollout history."""
        try:
            output = subprocess.check_output([
                "kubectl", "-n", self.namespace,
                "rollout", "history",
                f"deployment/{service}",
                "--no-headers"
            ], timeout=10).decode()

            for line in output.strip().split("\n"):
                if not line.strip():
                    continue
                parts = line.split()
                if len(parts) >= 2:
                    revision = parts[0]
                    change_cause = " ".join(parts[2:]) if len(parts) > 2 else "unknown"
                    # Note: kubectl rollout history doesn't provide timestamps
                    # Cross-reference with CI/CD system for accurate times
                    self.events.append(TimelineEvent(
                        timestamp=start_time,  # Placeholder — enrich from CI/CD
                        source="deploy",
                        event_type="deployment",
                        description=f"Deployment revision {revision}: {change_cause}",
                    ))
        except Exception as e:
            print(f"Warning: Could not extract deployment history: {e}")

    def add_manual_event(
        self,
        timestamp:   datetime,
        description: str,
        actor:       Optional[str] = None,
        source:      str = "manual"
    ) -> None:
        """Add a manually extracted event (from Slack, scribe log, etc.)."""
        self.events.append(TimelineEvent(
            timestamp=timestamp,
            source=source,
            event_type="note",
            description=description,
            actor=actor
        ))

    def get_sorted_timeline(self) -> List[TimelineEvent]:
        """Return events sorted chronologically."""
        return sorted(self.events, key=lambda e: e.timestamp)

    def to_markdown_table(self) -> str:
        """Generate markdown timeline table for post-mortem document."""
        lines = [
            "## Incident Timeline",
            "",
            "| Time (UTC) | Source | Event |",
            "|-----------|--------|-------|",
        ]
        for event in self.get_sorted_timeline():
            lines.append(event.to_markdown())
        return "\n".join(lines)

    def identify_key_moments(self) -> dict:
        """
        Identify the critical moments in the timeline:
        detection, triage, mitigation, resolution.
        These are the focus points for the post-mortem narrative.
        """
        events = self.get_sorted_timeline()
        key_moments = {
            "first_symptom":    None,  # When did something first go wrong?
            "detection":        None,  # When did the alert fire?
            "acknowledgment":   None,  # When did on-call respond?
            "diagnosis":        None,  # When was root cause identified?
            "mitigation_start": None,  # When did first fix attempt start?
            "user_impact_end":  None,  # When did users stop experiencing issues?
            "full_resolution":  None,  # When was everything fully restored?
        }

        for event in events:
            desc_lower = event.description.lower()
            if not key_moments["detection"] and "alert" in event.event_type:
                key_moments["detection"] = event
            if not key_moments["acknowledgment"] and (
                "ack" in desc_lower or "acknowledged" in desc_lower
            ):
                key_moments["acknowledgment"] = event
            if "rollback" in desc_lower or "fix" in desc_lower:
                if not key_moments["mitigation_start"]:
                    key_moments["mitigation_start"] = event
            if "resolved" in desc_lower or "recovery" in desc_lower:
                key_moments["full_resolution"] = event

        return key_moments

    def calculate_response_metrics(self) -> dict:
        """Calculate MTTD, MTTA, MTTM, MTTR from timeline events."""
        moments = self.identify_key_moments()
        metrics = {}

        if moments["first_symptom"] and moments["detection"]:
            delta = moments["detection"].timestamp - moments["first_symptom"].timestamp
            metrics["mttd_minutes"] = round(delta.total_seconds() / 60, 1)

        if moments["detection"] and moments["acknowledgment"]:
            delta = moments["acknowledgment"].timestamp - moments["detection"].timestamp
            metrics["mtta_minutes"] = round(delta.total_seconds() / 60, 1)

        if moments["detection"] and moments["mitigation_start"]:
            delta = moments["mitigation_start"].timestamp - moments["detection"].timestamp
            metrics["mttm_minutes"] = round(delta.total_seconds() / 60, 1)

        if moments["detection"] and moments["full_resolution"]:
            delta = moments["full_resolution"].timestamp - moments["detection"].timestamp
            metrics["mttr_minutes"] = round(delta.total_seconds() / 60, 1)

        return metrics
```

#### Annotating the Timeline: The Five Key Moments

Every post-mortem timeline should explicitly identify these five moments and the gaps between them:

```
Timeline Annotation Framework
────────────────────────────────────────────────────────────────────
T₀: First symptom
    When did the system first behave incorrectly?
    (Often before anyone noticed — found in logs retrospectively)

T₁: Detection
    When did the alerting system fire? (Or when did a user report?)
    Gap T₀→T₁ = detection latency. This is where monitoring gaps live.

T₂: Acknowledgment
    When did the on-call engineer acknowledge the page?
    Gap T₁→T₂ = response time. Is it within MTTA target?

T₃: Diagnosis
    When was the root cause or primary symptom identified?
    Gap T₂→T₃ = diagnosis time. This is where runbook value lives.

T₄: Mitigation
    When did user-facing impact stop or significantly improve?
    Gap T₃→T₄ = mitigation time. Rollback vs. fix time.

T₅: Resolution
    When was the system fully restored and monitoring confirmed stable?
    Gap T₄→T₅ = recovery confirmation time.

Total MTTR = T₅ - T₁
Incident Duration = T₅ - T₀

Where was time spent? Which gap is largest?
That gap is the highest-leverage improvement target.
────────────────────────────────────────────────────────────────────
```

---

### 9.5 Root Cause Analysis Methods {#95-rca-methods}

Root cause analysis (RCA) is the systematic investigation of why an incident occurred — moving past the proximate (immediate) cause to the contributing factors and underlying system conditions that made the incident possible.

**Critical distinction:** An RCA that stops at the proximate cause produces action items that address the symptom but not the disease.

```
RCA Depth Levels
──────────────────────────────────────────────────────────────────
Level 1: Proximate cause (symptom)
  "The database ran out of connections."
  Action: Increase max_connections.
  Problem: Does nothing about why connections exhausted.

Level 2: Contributing factor
  "Connections exhausted because of a connection leak in the
   new user service deployment."
  Action: Fix the connection leak. Roll back the deployment.
  Problem: Does nothing about why the leak reached production.

Level 3: Systemic cause
  "The connection leak reached production because:
   (a) No connection pool monitoring in the staging environment
   (b) Load testing does not simulate the traffic duration needed
       to trigger the leak (it manifests after 6+ hours)
   (c) No alerting on connection pool trend velocity"
  Action: Three specific, systemic improvements.
  These prevent this class of failure, not just this instance.

Level 4: Cultural / process cause (deepest)
  "The load test did not cover long-duration scenarios because
   the team had no formal load test specification process.
   Changes ship without a capacity validation checklist."
  Action: Introduce load test specification requirement in PRR.
  This prevents an entire category of future incidents.
──────────────────────────────────────────────────────────────────
```

**The "Root Cause" Fallacy:** Most incidents have no single root cause. They are the product of multiple contributing factors that individually were manageable — but in combination created an outage. Searching for "the root cause" oversimplifies complex system failures and produces incomplete action items.

The correct framing: **What were the necessary and contributing conditions that, together, produced this incident?**

---

### 9.6 The 5-Whys Technique {#96-five-whys}

Developed by Sakichi Toyoda at Toyota, the 5-Whys technique iteratively asks "why?" to drill past symptoms to underlying causes. In SRE practice, it is the most commonly used RCA tool.

#### 5-Whys: Worked Example

**Incident:** Checkout service error rate reached 12% for 34 minutes on a Tuesday afternoon.

```
Why 1: Why did the checkout error rate spike to 12%?
  → Because the checkout service was timing out on requests
    to the payment service.

Why 2: Why was the checkout service timing out on payment requests?
  → Because the payment service was returning responses
    in 8-12 seconds instead of the normal < 300ms.

Why 3: Why was the payment service responding so slowly?
  → Because its database was under extreme load — CPU at 98%,
    query queue depth > 500.

Why 4: Why was the payment service database under extreme load?
  → Because a new background job (deployed Tuesday morning)
    was running a full-table scan every 60 seconds on the
    transactions table (now containing 400M rows).

Why 5: Why was a full-table scan running every 60 seconds on
       a 400M-row table in production?
  → Because the query was developed against a staging database
    with < 100,000 rows where it completed in 20ms. No query
    plan analysis was performed. No staging-to-production
    data volume equivalence testing exists.

Root cause: Absence of query performance validation process
            for production-scale data volumes.
```

**Action items from this 5-Whys:**
1. Add missing index to `transactions` table (immediate mitigation)
2. Kill/throttle the runaway background job
3. Add query plan analysis requirement to code review checklist
4. Provision staging with production-scale data volumes (or anonymized subset)
5. Add alert on database CPU > 70% and query queue depth > 50

#### 5-Whys Implementation in Python

```python
from dataclasses import dataclass, field
from typing import List, Optional

@dataclass
class WhyNode:
    level: int
    observation: str
    answer: str
    evidence: str               # What data supports this answer?
    confidence: str             # high | medium | low
    children: List['WhyNode'] = field(default_factory=list)
    action_item: Optional[str] = None  # If this level produces an action

    def to_markdown(self, indent: int = 0) -> str:
        prefix = "  " * indent
        lines = [
            f"{prefix}**Why {self.level}:** {self.observation}",
            f"{prefix}*Answer:* {self.answer}",
            f"{prefix}*Evidence:* {self.evidence}",
            f"{prefix}*Confidence:* {self.confidence}",
        ]
        if self.action_item:
            lines.append(f"{prefix}*→ Action Item:* {self.action_item}")
        for child in self.children:
            lines.append("")
            lines.extend(child.to_markdown(indent + 1).split("\n"))
        return "\n".join(lines)

@dataclass
class FiveWhysAnalysis:
    incident_id:    str
    incident_title: str
    initiating_event: str    # The observable failure that started the analysis
    whys:           List[WhyNode] = field(default_factory=list)

    def add_why(self, node: WhyNode) -> None:
        self.whys.append(node)

    def get_all_action_items(self) -> List[str]:
        """Collect all action items across all why levels."""
        actions = []
        def collect(nodes):
            for node in nodes:
                if node.action_item:
                    actions.append(f"[Why {node.level}] {node.action_item}")
                collect(node.children)
        collect(self.whys)
        return actions

    def validate(self) -> List[str]:
        """Check for common 5-Whys mistakes."""
        warnings = []

        def check_nodes(nodes):
            for node in nodes:
                # Warning: human error as a final answer
                human_error_phrases = [
                    "human error", "operator error",
                    "forgot to", "failed to check",
                    "didn't follow"
                ]
                if any(p in node.answer.lower() for p in human_error_phrases):
                    if not node.children:  # Only warn if it's a leaf node
                        warnings.append(
                            f"Why {node.level}: Answer ends with human error "
                            f"without asking why the human was in that position. "
                            f"Add another Why: what system condition made this "
                            f"human action possible/likely?"
                        )

                # Warning: low confidence without alternative branches
                if node.confidence == "low" and not node.children:
                    warnings.append(
                        f"Why {node.level}: Low-confidence answer with no "
                        f"alternative hypothesis. Consider branching the analysis."
                    )

                check_nodes(node.children)

        check_nodes(self.whys)

        if len(self.whys) < 3:
            warnings.append(
                "Analysis has fewer than 3 Why levels. "
                "Most production incidents require 4-6 levels to reach "
                "systemic causes."
            )

        return warnings

    def to_markdown(self) -> str:
        lines = [
            f"## Root Cause Analysis: 5-Whys",
            f"",
            f"**Incident:** {self.incident_id} — {self.incident_title}",
            f"**Initiating Event:** {self.initiating_event}",
            f"",
            "### Analysis Chain",
            "",
        ]
        for why in self.whys:
            lines.append(why.to_markdown())
            lines.append("")

        actions = self.get_all_action_items()
        if actions:
            lines.extend([
                "### Action Items Identified",
                "",
                *[f"- {a}" for a in actions]
            ])

        warnings = self.validate()
        if warnings:
            lines.extend([
                "",
                "### ⚠️ Analysis Warnings",
                "",
                *[f"- {w}" for w in warnings]
            ])

        return "\n".join(lines)

# Example usage
analysis = FiveWhysAnalysis(
    incident_id="INC-2024-0847",
    incident_title="Checkout 12% error rate — payment service database overload",
    initiating_event="Checkout error rate spiked to 12% at 14:23 UTC"
)

analysis.add_why(WhyNode(
    level=1,
    observation="Why did checkout error rate spike to 12%?",
    answer="Checkout service was timing out on payment service requests (8-12s vs normal <300ms)",
    evidence="Distributed traces show payment service spans at 8-12 seconds",
    confidence="high",
    children=[WhyNode(
        level=2,
        observation="Why was payment service responding in 8-12 seconds?",
        answer="Payment service database CPU at 98%, query queue depth > 500",
        evidence="Prometheus: pg_stat_activity_count showed 500+ active queries",
        confidence="high",
        action_item="Add alert on DB query queue depth > 100",
        children=[WhyNode(
            level=3,
            observation="Why was payment DB under extreme load?",
            answer="New background job deployed 09:15 UTC running full-table scan every 60s",
            evidence="EXPLAIN ANALYZE on background job query shows Seq Scan on transactions (400M rows)",
            confidence="high",
            action_item="Add missing composite index on (status, created_at) to transactions table",
            children=[WhyNode(
                level=4,
                observation="Why did a full-table scan reach production?",
                answer="Query developed on staging with <100k rows where it completed in 20ms. No query plan review in PR process.",
                evidence="Staging DB has 98,234 rows; production has 412,847,003 rows",
                confidence="high",
                action_item="Add EXPLAIN ANALYZE requirement to code review checklist for any new query",
                children=[WhyNode(
                    level=5,
                    observation="Why does staging have 100k rows when production has 400M?",
                    answer="No process exists for staging data volume equivalence or query performance validation at scale",
                    evidence="Engineering wiki: no mention of load/data testing requirements",
                    confidence="high",
                    action_item="Add 'Query Performance at Scale' section to Production Readiness Review checklist"
                )]
            )]
        )]
    )]
))

print(analysis.to_markdown())
```

#### 5-Whys Common Traps

```
Trap 1: Stopping at the proximate cause
  "The database ran out of disk space."
  → This is a description of the failure, not an explanation of
    why the system had no safeguards against disk exhaustion.

Trap 2: Human error as a terminal answer
  "An engineer deleted the wrong database table."
  → Why was it possible to delete a production table without
    confirmation? Why did no backup exist? Why was the engineer
    operating with production write permissions?

Trap 3: Single-threaded analysis (missing branches)
  Complex incidents have multiple contributing causal paths.
  The 5-Whys should be a tree, not a chain, when multiple
  independent conditions contributed to the outcome.

Trap 4: Premature closure on first plausible cause
  The first plausible cause found often anchors the analysis.
  Validate each Why with evidence before proceeding.
  Ask: "Is this definitely true, or just likely true?"

Trap 5: Why chains that produce no actionable items
  Every Why should produce at least one action item, or
  demonstrate that an action item at a higher level subsumes it.
  A Why chain with no actions was an exercise, not an analysis.
```

---

### 9.7 Fishbone (Ishikawa) Diagram Analysis {#97-fishbone}

The Fishbone diagram (also called Ishikawa or cause-and-effect diagram) is a visual RCA technique that organizes contributing factors into categories, making it easier to see multiple contributing causes simultaneously.

It is particularly useful for complex incidents with many contributing factors — where the 5-Whys linear chain obscures the breadth of causes.

#### Standard Fishbone Categories for SRE

```
                              INCIDENT
                    (Effect — the observable failure)
                                 ◄
                    ─────────────────────────────────
                   /                                  \
     PEOPLE/PROCESS ──┐         ┌── CODE/DEPLOYMENT
                      │         │
       MONITORING ────┤ SPINE ├──── CONFIGURATION
                      │         │
    INFRASTRUCTURE ───┘         └── DEPENDENCIES/EXTERNAL
                    ─────────────────────────────────
```

**Categories and their SRE-specific prompts:**

```python
FISHBONE_CATEGORIES = {
    "Code / Deployment": [
        "Was a code change involved? When was it deployed?",
        "Was the change tested at production scale?",
        "Was there a canary deployment?",
        "Were there known bugs or technical debt in this area?",
        "Was the deployment rollback-able?",
    ],
    "Configuration": [
        "Was a configuration change made recently?",
        "Was the configuration validated before deployment?",
        "Are configuration changes version-controlled?",
        "Could a configuration drift have occurred gradually?",
    ],
    "Infrastructure": [
        "Was there a hardware failure or cloud provider issue?",
        "Was a network change made?",
        "Was resource provisioning sufficient?",
        "Was there a cascading failure from another component?",
    ],
    "Monitoring / Detection": [
        "Was there a monitoring gap — failure existed before alert fired?",
        "Were alert thresholds appropriate?",
        "Were runbooks up-to-date and accurate?",
        "Did the on-call have sufficient observability?",
    ],
    "Process / Procedure": [
        "Was there a process that should have prevented this?",
        "Was the process followed? If not, why not?",
        "Was the process known to the people involved?",
        "Would a different process have caught this earlier?",
    ],
    "People / Cognitive": [
        "Were there competing pressures that influenced decisions?",
        "Was there sufficient context at decision points?",
        "Was cognitive load a factor?",
        "Were team communication channels effective?",
    ],
    "External Dependencies": [
        "Did a third-party service degrade or fail?",
        "Was there an API change from an external provider?",
        "Were rate limits hit on an external service?",
        "Was a CDN, DNS, or cloud provider involved?",
    ],
}

def conduct_fishbone_analysis(incident_description: str) -> dict:
    """
    Guide a facilitator through Fishbone analysis.
    Returns structured cause map for documentation.
    """
    cause_map = {}
    print(f"Fishbone Analysis: {incident_description}\n")
    print("For each category, list contributing causes identified:\n")

    for category, prompts in FISHBONE_CATEGORIES.items():
        print(f"\n{'─'*50}")
        print(f"Category: {category}")
        print("Prompts to consider:")
        for p in prompts:
            print(f"  • {p}")
        cause_map[category] = []  # Facilitator fills in during meeting

    return cause_map
```

#### Fishbone vs 5-Whys — When to Use Each

```
Use 5-Whys when:
  → Incident has a clear, linear causal chain
  → Team is small and familiar with the failure
  → Time is limited (5-Whys is faster)
  → Single service / component involved

Use Fishbone when:
  → Incident involves multiple teams or systems
  → Contributing factors span several categories
  → Team needs to ensure all areas are considered
  → Prior 5-Whys analyses missed contributing factors
  → The incident is novel or particularly complex

Use Both when:
  → SEV1 incidents with broad impact
  → Fishbone identifies the contributing factor categories;
    5-Whys drills into each branch for root cause
```

---

### 9.8 Contributing Factors vs Root Causes {#98-contributing-factors}

The language of "root cause" is useful but incomplete. A rigorous post-mortem distinguishes between:

```
Term                Definition
──────────────────────────────────────────────────────────────────
Trigger             The immediate event that initiated the incident.
                    Example: "An engineer deployed service v2.4.1 at 14:23"
                    Note: The trigger is rarely the root cause.

Proximate Cause     The direct technical cause of the failure.
                    Example: "The new deployment introduced a
                    connection leak in the payment service client."

Contributing        System conditions that allowed the trigger to
Factors             become an incident. Each one alone might have
                    been manageable; together they produced the
                    incident.
                    Examples:
                      "Connection pool had no monitoring"
                      "Load test did not cover connection leak patterns"
                      "No circuit breaker on payment service client"
                      "Rollback was not pre-tested for this version"

Root Cause(s)       The systemic conditions, absent which the incident
                    would not have occurred or would have been minor.
                    Examples:
                      "Absence of production-equivalent load testing"
                      "No alerting on connection pool trend velocity"

Underlying           Deep systemic or cultural conditions.
System Conditions   Examples:
                      "Staging environment is not representative of
                       production scale"
                      "Team has no standard for performance regression
                       testing before deployment"
──────────────────────────────────────────────────────────────────
```

```python
@dataclass
class CausalAnalysis:
    """
    Structured causal analysis for post-mortem documentation.
    Forces explicit distinction between trigger, contributing factors,
    and root causes.
    """
    incident_id: str

    trigger: str                        # What initiated the incident?
    proximate_cause: str                # Direct technical cause?
    contributing_factors: list[str]     # What made this possible?
    root_causes: list[str]              # Systemic conditions to fix
    underlying_conditions: list[str]    # Deep cultural/process issues

    def validate(self) -> list[str]:
        warnings = []
        human_error = ["human error", "user error", "operator error", "forgot"]

        if any(p in self.root_causes[0].lower() for p in human_error) \
                if self.root_causes else False:
            warnings.append(
                "Root cause appears to be human error. "
                "This is rarely the root cause — investigate what system "
                "conditions made the human error impactful."
            )
        if len(self.contributing_factors) < 2:
            warnings.append(
                "Only one contributing factor identified. "
                "Most incidents have 3-5 contributing factors. "
                "Review the Fishbone categories."
            )
        if not self.underlying_conditions:
            warnings.append(
                "No underlying conditions identified. "
                "Consider: what process or cultural condition "
                "allowed the contributing factors to persist?"
            )
        return warnings

    def action_items_required(self) -> int:
        """
        Rule of thumb: each contributing factor should have
        at least one action item. Root causes should have at least two.
        """
        return len(self.contributing_factors) + (len(self.root_causes) * 2)

    def to_markdown(self) -> str:
        return f"""
## Causal Analysis

**Trigger:** {self.trigger}

**Proximate Cause:** {self.proximate_cause}

**Contributing Factors:**
{chr(10).join(f'- {f}' for f in self.contributing_factors)}

**Root Causes:**
{chr(10).join(f'- {r}' for r in self.root_causes)}

**Underlying System Conditions:**
{chr(10).join(f'- {u}' for u in self.underlying_conditions)}
""".strip()
```

---

### 9.9 Writing Effective Post-Mortem Documents {#99-writing-post-mortems}

The post-mortem document is the permanent record of the incident and the learning it produced. It must be clear enough for an engineer who wasn't there to understand completely, precise enough to be referenced years later, and blameless enough that no engineer fears having their name associated with it.

#### The Post-Mortem Template

```markdown
# Post-Mortem: [Brief Incident Title]
**Incident ID:**      INC-2024-XXXX
**Date:**             [Date of incident]
**Duration:**         [Start time] → [End time] UTC ([N] minutes)
**Severity:**         SEV[1/2]
**Status:**           [Draft | Under Review | Final]
**Author(s):**        [Names]
**Reviewers:**        [Names]
**Last Updated:**     [Date]

---

## Summary

<!-- One paragraph. What happened, what was the user impact,
     what was the business impact, and how was it resolved.
     Written for a reader who wasn't there. No jargon. -->

Example:
On Tuesday January 15 at 14:23 UTC, the checkout service began
returning HTTP 500 errors for approximately 12% of checkout
attempts. The incident lasted 34 minutes and affected an estimated
18,000 users. Revenue impact is estimated at $47,000. The incident
was caused by a database query introduced in the 09:15 UTC deployment
that performed a full-table scan on a 400M-row table at 60-second
intervals, saturating the payment service database. The issue was
resolved by rolling back the 09:15 deployment at 14:57 UTC.

---

## Impact

| Dimension           | Value                          |
|---------------------|-------------------------------|
| Duration            | 34 minutes                    |
| Users Affected      | ~18,000 (12% of active users) |
| Error Rate Peak     | 12.3%                         |
| Revenue Impact      | ~$47,000 (estimated)          |
| SLO Impact          | 28% of monthly error budget   |
| SLA Breach          | No (SLA target: 99%)          |
| Customer Complaints | 47 support tickets opened     |

---

## Timeline

<!-- Chronological table. Every significant event with timestamp.
     Include: alert fires, acknowledgment, escalations,
     investigation discoveries, decisions, actions taken,
     and recovery milestones. -->

| Time (UTC) | Source | Event |
|-----------|--------|-------|
| 09:15     | Deploy | Deployment of payment-service v3.4.1 |
| 14:21     | Prometheus | Alert: PaymentServiceHighLatency (P99 > 2s) |
| 14:23     | Prometheus | Alert: SLO_Availability_FastBurn_P1 (burn rate 18×) |
| 14:24     | PagerDuty | On-call Sarah acknowledged |
| 14:26     | Slack | SEV2 declared; war room opened |
| 14:28     | Slack | Tom (payment SME) joined war room |
| 14:31     | Investigation | Identified full-table scan in payment-bg-job process |
| 14:33     | Decision | IC: rolling back payment-service v3.4.1 |
| 14:35     | Action | Rollback to v3.4.0 initiated |
| 14:41     | Prometheus | Error rate declining: 12.3% → 6.2% → 1.8% |
| 14:52     | Prometheus | Error rate within SLO: 0.08% |
| 14:57     | Slack | IC: resolution declared |
| 14:58     | Statuspage | Customer status page updated to "Resolved" |

**Key Metrics:**
- MTTD (first alert → on-call aware): 3 minutes
- MTTA (alert → acknowledgment): 3 minutes
- MTTM (alert → mitigation): 12 minutes
- MTTR (alert → resolution): 34 minutes

---

## Root Cause Analysis

### Trigger
Deployment of `payment-service v3.4.1` at 09:15 UTC introduced
a background job that executed a full-table scan on the
`transactions` table (400M rows) every 60 seconds.

### Proximate Cause
The `transactions` table scan caused payment service database
CPU to reach 98% and query queue depth to exceed 500, resulting
in payment API response times degrading from <300ms to 8-12 seconds.
The checkout service's payment client had a 10-second timeout,
causing 12% of checkout requests to fail with HTTP 500.

### Contributing Factors
1. **No query performance review in code review process.** The
   background job query was not analyzed with EXPLAIN ANALYZE
   before merging.

2. **Staging data volume not representative.** The staging database
   has 98,234 rows; the query completed in 20ms in staging and was
   not identified as a full-table scan.

3. **No alerting on database query queue depth.** The query queue
   depth metric exists but no alert was configured. Database CPU
   alerting threshold was set at 95% (too late to prevent impact).

4. **No circuit breaker on checkout→payment dependency.** Checkout
   service had no fallback for payment service degradation, causing
   checkout errors to mirror payment latency issues 1:1.

### Root Causes
1. **Absence of query performance validation for production-scale
   data volumes.** No process exists to test queries against
   representative data before deployment.

2. **Database health monitoring insufficient for early detection.**
   Query queue depth and slow query rate were not monitored.

### Underlying System Conditions
- The Production Readiness Review checklist does not include query
  performance validation requirements.
- Staging environments are not provisioned with production-equivalent
  data volumes or synthetic load.

---

## What Went Well

<!-- Genuinely positive observations — this section matters.
     It reinforces practices worth keeping. -->

- Alert detection was fast: SLO burn rate alert fired within 2 minutes
  of user impact beginning.
- Rollback execution was smooth: the team had practiced rollback
  procedures; v3.4.0 was healthy and rollback completed in 90 seconds.
- Communication was clear: status page was updated within 5 minutes
  of declaration; no executive escalation was required.
- The scribe log was complete and accurate — enabled this post-mortem
  to be written with full timeline detail.

---

## Where We Got Lucky

<!-- Near-misses and mitigations that could have made this worse.
     These often produce the highest-value action items. -->

- The incident occurred during business hours. The same failure at
  3am would have had a longer MTTA (engineer deep in sleep vs. awake).
- Traffic was 40% below normal peak. At peak traffic, the database
  would have saturated faster and MTTR would have been longer.
- We had a stable v3.4.0 rollback target. If this had been a first
  deployment with no prior stable version, rollback would not have
  been possible.

---

## Action Items

<!-- Every action item must have: owner, priority, due date, ticket.
     No orphan action items. Every item is in the sprint system. -->

| # | Action | Owner | Priority | Due Date | Ticket |
|---|--------|-------|----------|----------|--------|
| 1 | Add EXPLAIN ANALYZE to code review checklist for new queries | @alice | P1 | Jan 22 | ENG-4821 |
| 2 | Configure alert on pg_stat_activity queue depth > 100 | @sarah | P1 | Jan 22 | ENG-4822 |
| 3 | Implement circuit breaker on checkout→payment dependency | @james | P1 | Jan 29 | ENG-4823 |
| 4 | Provision staging with production-scale data (anonymized) | @platform | P2 | Feb 15 | ENG-4824 |
| 5 | Add query performance section to PRR checklist | @sre-lead | P2 | Jan 29 | ENG-4825 |
| 6 | Lower DB CPU alert threshold from 95% to 70% | @sarah | P1 | Jan 22 | ENG-4826 |
| 7 | Document rollback procedure for payment-service | @tom | P2 | Feb 1 | ENG-4827 |

---

## Lessons Learned

<!-- Generalizable insights beyond this specific incident. -->

1. **Staging data volume equivalence is a systemic gap.** This incident
   exposed that our staging environments consistently have < 0.1% of
   production data volume. Any query or operation whose performance is
   data-volume-sensitive cannot be adequately validated in staging.
   This is a category of risk, not a one-time problem.

2. **Dependency health cascades without circuit breakers.** The checkout
   service had no ability to degrade gracefully when payment was slow —
   it simply returned errors 1:1. Adding circuit breakers to all
   inter-service dependencies is a systemic reliability improvement.

3. **Database queue depth is a more sensitive leading indicator than CPU.**
   CPU reached 98% when queue depth was already at 500+. Earlier
   alerting on queue depth would have provided 8-12 minutes of
   additional response time.

---

## Appendix

### Relevant Graphs
<!-- Link to Grafana time-series snapshots showing the incident -->
- [Checkout error rate during incident](https://grafana.internal/snapshot/xxx)
- [Payment DB CPU and queue depth](https://grafana.internal/snapshot/yyy)
- [Distributed trace: slow payment request](https://jaeger.internal/trace/zzz)

### Relevant Logs
<!-- Preserved log excerpts showing the failure -->
```
[14:21:07 UTC] payment-bg-job: BEGIN query: SELECT * FROM transactions WHERE status='pending'
[14:21:07 UTC] payment-db: Seq Scan on transactions (cost=0.00..8921432.00 rows=400M)
[14:31:22 UTC] payment-svc: ERROR timeout waiting for db connection (pool exhausted)
[14:31:22 UTC] checkout-svc: ERROR PaymentService timeout after 10000ms: order_id=a1b2c3
```
```

---

### 9.10 Action Item Tracking and Accountability {#910-action-item-tracking}

The most common post-mortem failure is excellent analysis producing action items that disappear into a backlog and are never completed. Six months later, the same failure mode produces a second incident.

```python
from dataclasses import dataclass, field
from datetime import datetime, date
from enum import Enum
from typing import List, Optional

class ActionStatus(Enum):
    OPEN        = "open"
    IN_PROGRESS = "in_progress"
    BLOCKED     = "blocked"
    COMPLETED   = "completed"
    DEFERRED    = "deferred"
    CANCELLED   = "cancelled"

class ActionPriority(Enum):
    P0 = "P0"  # Emergency — must complete this week (prevents imminent recurrence)
    P1 = "P1"  # High — complete this sprint (reduces recurrence risk significantly)
    P2 = "P2"  # Medium — complete this quarter (systemic improvement)
    P3 = "P3"  # Low — backlog (nice to have)

@dataclass
class ActionItem:
    id:            str
    incident_id:   str
    description:   str
    owner:         str
    priority:      ActionPriority
    due_date:      date
    ticket_id:     str              # Jira/Linear/GitHub Issue ID
    status:        ActionStatus = ActionStatus.OPEN
    completed_date: Optional[date] = None
    impact:        Optional[str] = None  # What reliability improvement results?
    blocked_by:    Optional[str] = None

    @property
    def is_overdue(self) -> bool:
        return (
            self.status not in [ActionStatus.COMPLETED, ActionStatus.CANCELLED]
            and date.today() > self.due_date
        )

    @property
    def days_overdue(self) -> int:
        if not self.is_overdue:
            return 0
        return (date.today() - self.due_date).days

class ActionItemTracker:

    def __init__(self):
        self.items: List[ActionItem] = []

    def add(self, item: ActionItem) -> None:
        self.items.append(item)

    def overdue_items(self) -> List[ActionItem]:
        return [i for i in self.items if i.is_overdue]

    def completion_rate(
        self, incident_id: Optional[str] = None
    ) -> float:
        items = (
            [i for i in self.items if i.incident_id == incident_id]
            if incident_id else self.items
        )
        if not items:
            return 0.0
        completed = sum(
            1 for i in items
            if i.status == ActionStatus.COMPLETED
        )
        return completed / len(items)

    def generate_weekly_digest(self) -> str:
        """
        Weekly digest for engineering manager and SRE lead review.
        Surfaces overdue items and tracks completion velocity.
        """
        overdue = self.overdue_items()
        open_p0_p1 = [
            i for i in self.items
            if i.status in [ActionStatus.OPEN, ActionStatus.IN_PROGRESS]
            and i.priority in [ActionPriority.P0, ActionPriority.P1]
        ]
        overall_rate = self.completion_rate()

        lines = [
            f"# Post-Mortem Action Item Digest — {date.today().isoformat()}",
            f"",
            f"**Overall completion rate:** {overall_rate:.1%}",
            f"**Open P0/P1 items:** {len(open_p0_p1)}",
            f"**Overdue items:** {len(overdue)}",
            f"",
        ]

        if overdue:
            lines.append("## ⚠️ Overdue Action Items")
            lines.append("")
            for item in sorted(overdue, key=lambda x: x.days_overdue, reverse=True):
                lines.append(
                    f"- **[{item.priority.value}] {item.id}** "
                    f"({item.days_overdue}d overdue) — "
                    f"{item.description[:80]} "
                    f"| Owner: @{item.owner} "
                    f"| Ticket: {item.ticket_id}"
                )
            lines.append("")

        if open_p0_p1:
            lines.append("## 🔴 Open High-Priority Items")
            lines.append("")
            for item in open_p0_p1:
                lines.append(
                    f"- **[{item.priority.value}]** {item.description[:80]} "
                    f"| Due: {item.due_date} "
                    f"| Owner: @{item.owner} "
                    f"| Status: {item.status.value}"
                )

        return "\n".join(lines)

    def completion_rate_trend(
        self, weeks: int = 8
    ) -> dict:
        """
        Track completion rate over time.
        Declining trend = action items not being prioritized.
        """
        # Simplified: in production, track with timestamps
        return {
            "overall_completion_rate": f"{self.completion_rate():.1%}",
            "total_items":    len(self.items),
            "completed":      sum(1 for i in self.items
                                  if i.status == ActionStatus.COMPLETED),
            "overdue":        len(self.overdue_items()),
            "health_signal":  (
                "🟢 Healthy"  if self.completion_rate() > 0.80 else
                "🟡 Warning"  if self.completion_rate() > 0.60 else
                "🔴 Critical — action items not being completed"
            )
        }
```

#### The Action Item Accountability Cycle

```
Action Item Accountability Cycle
──────────────────────────────────────────────────────────────────────
Post-mortem meeting
  → Action items created with owner + due date + ticket
  → Tickets linked in post-mortem document
  → Tickets added to sprint backlog by end of day
       │
       ▼
Weekly (Engineering standup or SRE sync):
  → Review overdue action items
  → Escalate to manager if P1 item > 1 week overdue
       │
       ▼
Monthly (Reliability review):
  → Completion rate reported to leadership
  → Any P1/P2 items > 30 days without progress escalated
  → Cancelled/deferred items require written justification
       │
       ▼
Quarterly (Post-mortem retrospective):
  → Were action items completed? If not, why?
  → Did completed action items improve reliability?
  → Which incident categories are recurring?
  → What investment is needed to break the cycle?
──────────────────────────────────────────────────────────────────────
```

**The 80% Rule:** If action item completion rate drops below 80%, the post-mortem process has broken down. The analysis is producing value on paper but not in the system. This requires management escalation — not because engineers are lazy, but because action items are competing with feature work and losing. The solution is organizational (sprint allocation for reliability work) not individual (badgering engineers).

---

### 9.11 Learning from Incidents at Scale {#911-learning-at-scale}

Individual post-mortems produce tactical learning. An aggregate view across post-mortems produces strategic learning — the patterns that reveal systemic reliability investments worth making.

#### Incident Pattern Analysis

```python
from collections import Counter, defaultdict
from typing import List, Dict
import json

@dataclass
class PostMortemRecord:
    incident_id:        str
    date:               date
    service:            str
    duration_minutes:   int
    severity:           str
    root_cause_category: str     # e.g., "missing_circuit_breaker",
                                 # "data_volume_testing_gap",
                                 # "alert_threshold_too_high"
    contributing_factors: List[str]
    action_items_count:  int
    action_items_completed: int
    repeat_incident:    bool     # Same root cause as prior incident?
    revenue_impact_usd: float

def analyze_incident_patterns(
    records: List[PostMortemRecord],
    period_months: int = 6
) -> dict:
    """
    Aggregate post-mortem analysis for strategic reliability investment.
    Identifies the highest-value systemic improvements.
    """
    total_incidents      = len(records)
    total_revenue_impact = sum(r.revenue_impact_usd for r in records)
    total_duration_hours = sum(r.duration_minutes for r in records) / 60
    repeat_incidents     = [r for r in records if r.repeat_incident]

    # Root cause frequency
    root_cause_freq = Counter(r.root_cause_category for r in records)

    # Revenue impact by root cause category
    revenue_by_cause: Dict[str, float] = defaultdict(float)
    for r in records:
        revenue_by_cause[r.root_cause_category] += r.revenue_impact_usd

    # Service reliability ranking
    service_incidents = Counter(r.service for r in records)
    service_revenue   = defaultdict(float)
    for r in records:
        service_revenue[r.service] += r.revenue_impact_usd

    # Action item completion rates
    total_actions    = sum(r.action_items_count for r in records)
    completed_actions = sum(r.action_items_completed for r in records)
    completion_rate  = completed_actions / total_actions if total_actions else 0

    # Top systemic investments (by revenue prevented)
    top_investments = sorted(
        revenue_by_cause.items(),
        key=lambda x: x[1],
        reverse=True
    )[:5]

    return {
        "period_months":          period_months,
        "total_incidents":        total_incidents,
        "incidents_per_month":    round(total_incidents / period_months, 1),
        "total_revenue_impact":   f"${total_revenue_impact:,.0f}",
        "total_downtime_hours":   round(total_duration_hours, 1),
        "repeat_incident_rate":   f"{len(repeat_incidents)/total_incidents:.1%}",
        "action_completion_rate": f"{completion_rate:.1%}",

        "top_root_cause_categories": [
            {"category": cat, "count": count,
             "revenue_impact": f"${revenue_by_cause[cat]:,.0f}"}
            for cat, count in root_cause_freq.most_common(5)
        ],

        "top_systemic_investments": [
            {"root_cause": rc, "potential_revenue_protected": f"${rev:,.0f}"}
            for rc, rev in top_investments
        ],

        "reliability_debt_services": [
            {"service": svc, "incidents": cnt,
             "revenue_impact": f"${service_revenue[svc]:,.0f}"}
            for svc, cnt in service_incidents.most_common(3)
        ],

        "key_insights": _generate_insights(
            records, root_cause_freq, repeat_incidents, completion_rate
        )
    }

def _generate_insights(records, root_cause_freq, repeats, completion_rate) -> List[str]:
    insights = []
    top_cause, top_count = root_cause_freq.most_common(1)[0]
    insights.append(
        f"'{top_cause}' is the most frequent root cause ({top_count} incidents). "
        f"Systemic investment here has the highest prevention value."
    )
    if len(repeats) / len(records) > 0.2:
        insights.append(
            f"{len(repeats)/len(records):.0%} of incidents are repeats. "
            f"Action item completion rate ({completion_rate:.0%}) is insufficient "
            f"to prevent recurrence. Escalate to engineering leadership."
        )
    return insights
```

#### Learning Sharing Mechanisms

```
Mechanisms for Spreading Post-Mortem Learning
──────────────────────────────────────────────────────────────────
Internal Newsletter / Digest
  → Monthly "Incident Review" newsletter
  → 3-5 incidents with anonymized details and key learnings
  → "Learning of the month" — one systemic insight per issue
  → Distributed to all engineering teams

Incident Review Meeting (monthly, open to all engineers)
  → 60-minute session reviewing 2-3 post-mortems
  → Focus on learnings applicable across teams
  → Not a blame session — curiosity and improvement framing
  → Record and post for engineers who couldn't attend

Post-Mortem Database (searchable)
  → All post-mortems in searchable system (Confluence, Notion)
  → Tagged by: root cause category, affected service,
    contributing factors, action item types
  → "Similar incidents" feature: before writing a new post-mortem,
    search for prior incidents with same symptoms

Pre-Mortem (proactive application of post-mortem learning)
  → Before a major launch, conduct a "pre-mortem":
    "Imagine this launch caused a SEV1. What was the cause?"
  → Surfaces risks identified from prior incident patterns
  → Apply post-mortem learning prospectively

GameDay Integration
  → Post-mortem learnings feed chaos engineering scenarios:
    "We had an incident caused by X — let's verify we can
     handle it now that we've fixed it."
──────────────────────────────────────────────────────────────────
```

---

### 9.12 Post-Mortem Anti-Patterns and Rescue Techniques {#912-antipatterns}

```
Anti-Pattern                     Symptoms                    Rescue
──────────────────────────────────────────────────────────────────────
Blame in disguise                "Bob deployed without        Reframe: "What system
                                  testing" as root cause.     condition made this
                                                              action possible?"

Premature closure                "Root cause: DB query"       Keep asking Why until
                                  (no action item for why     you reach a systemic
                                  query reached production)   condition with an
                                                              addressable action.

Action item inflation             15 action items from a      Prioritize ruthlessly.
                                  single SEV3. Most never     If you can't do them
                                  completed.                  all, pick the top 3.
                                                              Close the rest with
                                                              justification.

Root cause tunnel vision          Team converges on first      Run Fishbone before
                                  plausible cause, ignores    5-Whys to ensure all
                                  contributing factors.       categories considered.

Post-mortem theater               Meeting held, document       Make action items
                                  filed, nothing changes.      P1 sprint items.
                                  Same incident recurs.        Track completion rate.
                                                              Present to leadership.

Recency bias in timeline          Timeline starts when alert   Start from "first
                                  fired. The 4-hour window     symptom visible in
                                  before detection omitted.    logs." Detection gap
                                                              is often the highest-
                                                              value finding.

Perfect document, late            Post-mortem published 3      Publish a "living
delivery                          weeks after incident.        document" draft within
                                  Memory has faded.            48h. Refine over time.
                                  Key details lost.            Don't wait for perfect.
──────────────────────────────────────────────────────────────────────
```

---

## Key Principles & Best Practices {#key-principles}

1. **Blame and truth are incompatible.** Organizations that punish engineers for incidents get less information about those incidents. Less information produces worse action items. Worse action items produce more incidents. Blameless culture is not moral softness — it is epistemological pragmatism.

2. **The timeline is the source of truth.** Start every post-mortem by building the timeline from logs, not from memory. Memory is unreliable, self-serving, and decays rapidly. Every disputed fact in a post-mortem meeting should be resolved by evidence.

3. **"Human error" is never a root cause — it is a starting point.** When a human action contributed to an incident, the correct question is: what system design, process gap, or organizational condition made that human action possible and consequential? The answer to that question is the root cause.

4. **Depth over breadth in action items.** Five specific, completed action items that address root causes improve reliability more than twenty vague action items that are never completed. Prioritize ruthlessly and ensure every action item has an owner, a ticket, and a due date before the meeting ends.

5. **The "Where We Got Lucky" section is the most underrated.** Near-misses that could have made the incident worse reveal the fragility hidden beneath incidents that resolved without catastrophe. These often produce the highest-value action items.

6. **Post-mortem learning compounds.** An organization that runs 50 quality post-mortems per year and completes 80% of action items will improve reliability dramatically within 2-3 years. The same organization that runs 50 post-mortems and completes 20% of action items will fight the same fires indefinitely.

7. **Aggregate analysis reveals what individual post-mortems cannot.** A single post-mortem about a missing circuit breaker is a tactical finding. Ten post-mortems about missing circuit breakers across eight services is a strategic finding that justifies a cross-team reliability initiative.

---

## Tools & Technologies {#tools}

| Tool | Category | Post-Mortem Use Case |
|---|---|---|
| **Blameless** | SRE Platform | Integrated incident + post-mortem + SLO platform |
| **Incident.io** | Incident Management | Auto-timeline generation from Slack; post-mortem templates |
| **FireHydrant** | Incident Management | Guided retrospectives; action item tracking integration |
| **Confluence** | Documentation | Post-mortem templates; searchable incident knowledge base |
| **Jira** | Issue Tracking | Action item tickets with SLA tracking and sprint integration |
| **Linear** | Issue Tracking | Engineering-first issue tracker; incident action item workflows |
| **PagerDuty Postmortems** | Integrated | Timeline auto-generated from incident data |
| **Alluvial / Honeycomb** | Observability | Trace-level investigation for timeline reconstruction |
| **Miro / Mural** | Whiteboarding | Visual Fishbone diagram construction in retrospective |
| **Notion** | Documentation | Searchable post-mortem database with tagging |

---

## Hands-on Exercises / Labs {#labs}

### Lab 9.1 — Timeline Reconstruction

**Goal:** Reconstruct an accurate incident timeline from raw data.

**Given data (simulated from multiple sources):**
```
Prometheus alerts log:
  14:21:03 — PaymentServiceHighLatency FIRING (P99 > 2s)
  14:22:47 — SLO_Availability_FastBurn_P1 FIRING (burn rate 18×)
  14:42:11 — SLO_Availability_FastBurn_P1 RESOLVED

Kubernetes events:
  09:15:33 — Deployment payment-service updated to revision 47 (v3.4.1)
  14:22:01 — Pod payment-bg-job-7d9f8 Memory: 98% (warning event)

PagerDuty log:
  14:23:15 — Alert triggered, assigned to Sarah
  14:24:02 — Sarah acknowledged
  14:26:33 — SEV2 declared by Sarah
  14:57:44 — Incident resolved

Slack war room log:
  14:28 — @tom joined #incident-2024-0847
  14:31 — @tom: "Found it — bg job doing full table scan every 60s"
  14:33 — @sarah (IC): "Executing rollback to v3.4.0, Tom confirm"
  14:34 — @tom: "Confirmed. Rollback executing"
  14:52 — @sarah: "Error rate back within SLO. Monitoring."
  14:57 — @sarah: "Declaring resolution. 34 min incident."

Application logs (checkout-svc):
  14:22:59 — ERROR PaymentService timeout after 10000ms order_id=a1b2c3
  14:23:01 — ERROR PaymentService timeout after 10000ms order_id=d4e5f6
  [thousands of similar lines until 14:41:32]
  14:41:32 — INFO PaymentService response 287ms order_id=x1y2z3 (first normal response)
```

**Tasks:**
1. Construct a complete chronological timeline table with all events from all sources.
2. Identify and label the five key moments: T₀ (first symptom), T₁ (detection), T₂ (acknowledgment), T₃ (diagnosis), T₄ (mitigation), T₅ (resolution).
3. Calculate MTTD, MTTA, MTTM, and MTTR from the timeline.
4. Identify the gap with the most improvement potential. What one action item would reduce this gap most?
5. What information is missing from this timeline that you would want to fill in for a complete post-mortem?

---

### Lab 9.2 — 5-Whys Deep Dive

**Goal:** Conduct a rigorous 5-Whys analysis and validate it against common traps.

**Incident:** At 3:15am on a Saturday, the user authentication service became unavailable for 22 minutes. All users were logged out. The authentication service's Redis session cache ran out of memory, evicting all session tokens, forcing 100% of active users to re-authenticate simultaneously. This created a login storm that overloaded the authentication database.

**Tasks:**
1. Build the `FiveWhysAnalysis` object for this incident with at minimum 5 Why levels.
2. For each Why level, provide: the observation, the answer, the supporting evidence (what data would confirm this), and confidence level.
3. Run the `validate()` method logic mentally: does any level stop at human error? Is the chain deep enough?
4. Identify the branching points — where does the causal chain have more than one contributing path? Add at least one branch.
5. Extract the action items. Categorize each as: immediate mitigation, detection improvement, process improvement, or architectural change.
6. Apply the Fishbone framework: which categories (Code, Config, Infra, Monitoring, Process, People, External) contributed? Does the Fishbone reveal any contributing factors the 5-Whys missed?

---

### Lab 9.3 — Post-Mortem Writing

**Goal:** Write a complete, blameless, publication-quality post-mortem document.

**Use the incident from Lab 9.1 and Lab 9.2 combined:** The checkout service experienced 12% error rates for 34 minutes caused by a payment service database overload from a background job running a full-table scan. Refer to the timeline from Lab 9.1 and the causal analysis you built in Lab 9.2.

**Tasks:**
1. Write the full post-mortem using the template from Section 9.9. Every section must be complete.
2. Apply the language review: identify any sentence that could be perceived as blaming an individual and rewrite it.
3. Write the "What Went Well" section with at least 3 genuine positives.
4. Write the "Where We Got Lucky" section — what three things could have made this worse?
5. Produce 5-7 action items with owner, priority, due date, and expected reliability impact. Ensure every contributing factor has at least one action item.
6. Write the "Lessons Learned" section — what 2-3 generalizable insights does this incident produce for the engineering organization?
7. Peer review: exchange your post-mortem with another engineer (or self-review after 24 hours). Does the summary paragraph tell the complete story in 5 sentences? Can a reader who wasn't there fully understand what happened?

---

### Lab 9.4 — Aggregate Incident Analysis

**Goal:** Derive strategic reliability investment priorities from a set of post-mortems.

**Given:** 6 months of post-mortem data (24 incidents):
```python
incidents = [
    {"id": "INC-001", "service": "checkout",   "root_cause": "missing_circuit_breaker",    "revenue": 47000, "repeat": False},
    {"id": "INC-002", "service": "search",     "root_cause": "data_volume_testing_gap",    "revenue": 8000,  "repeat": False},
    {"id": "INC-003", "service": "payment",    "root_cause": "db_connection_pool",         "revenue": 92000, "repeat": False},
    {"id": "INC-004", "service": "checkout",   "root_cause": "missing_circuit_breaker",    "revenue": 51000, "repeat": True},
    {"id": "INC-005", "service": "auth",       "root_cause": "session_cache_sizing",       "revenue": 31000, "repeat": False},
    {"id": "INC-006", "service": "payment",    "root_cause": "db_connection_pool",         "revenue": 88000, "repeat": True},
    {"id": "INC-007", "service": "search",     "root_cause": "alert_threshold_too_high",   "revenue": 5000,  "repeat": False},
    {"id": "INC-008", "service": "checkout",   "root_cause": "deployment_no_canary",       "revenue": 29000, "repeat": False},
    # ... 16 more incidents
]
```

**Tasks:**
1. Run `analyze_incident_patterns()` on this dataset. What are the top 3 root cause categories by frequency? By revenue impact?
2. Calculate the repeat incident rate. Is it above the 20% threshold that indicates a broken action item process?
3. Identify the single systemic investment that would have the highest expected revenue protection. Build the business case: what would this investment cost (engineering weeks) and what revenue does it protect?
4. Write a 1-page "Quarterly Reliability Investment Proposal" for your VP of Engineering: current state of incidents, top 3 investments, expected outcomes, and cost.
5. Design the "incident review" newsletter for this quarter: which 3 incidents would you feature, and what learnings would you highlight for teams not directly involved?

---

## Common Pitfalls & Anti-patterns {#pitfalls}

**Anti-pattern 1: Blame in blameless clothing**
The post-mortem document uses passive voice and system language throughout. But in the meeting, engineers subtly point fingers: "Well, if the deployment hadn't been rushed..." or "Normally someone would have caught that..." The meeting erodes psychological safety while the document appears blameless. *Fix:* Facilitate the meeting with explicit norms. Interrupt any statement that implies individual failure. Reframe every "person should have" to "what would the system need to make that unnecessary?"

**Anti-pattern 2: The 15-action-item post-mortem**
The team is thorough and motivated. The post-mortem produces 15 action items covering everything from "add a comment to line 47" to "redesign the entire caching layer." Six months later, 3 are done, 8 are stale Jira tickets, and 4 were never created. The incident recurs. *Fix:* Cap action items at 7 per post-mortem. Force prioritization. If you have more than 7, you must explicitly choose which ones not to do — and document why.

**Anti-pattern 3: Timeline that starts at the alert**
The post-mortem timeline begins when PagerDuty fired. There's no investigation of when the failure actually began — which is often 10-30 minutes earlier. The detection gap is invisible and produces no action items. *Fix:* Always search logs for the first symptom. Ask: "When was the first log line, metric anomaly, or user complaint that indicates something was wrong?" That is T₀. The gap between T₀ and T₁ is the detection gap — often the highest-value improvement target.

**Anti-pattern 4: Post-mortem as a performance review**
Leadership attends the post-mortem meeting. Engineers' statements are remembered and referenced in performance reviews ("You said in the post-mortem that you made a deployment error"). Engineers become guarded, withhold information, and stop attending. *Fix:* Post-mortem participation should never influence performance reviews. Make this explicit in writing. Some organizations make post-mortem meetings private to the engineering team (no leadership attendance). The document is published; the discussion is protected.

**Anti-pattern 5: Orphan action items**
Action items are documented in the post-mortem but not linked to tickets in the sprint system. They exist as text in Confluence, not as work in progress. Engineers have no visibility into them during sprint planning. They are never completed. *Fix:* No post-mortem meeting ends until every action item has a Jira/Linear/GitHub ticket created and linked. This takes 10 minutes at the end of the meeting. Without a ticket, the action item does not exist.

---

## Interview Questions {#interview-questions}

**Conceptual:**

1. *"What is a blameless post-mortem and why is it important? What are the practical behaviors that undermine blameless culture even when organizations claim to practice it?"*
   — Look for: blame prevents truth-telling; psychological safety required for accurate reconstruction; practical undermines: blame in meeting language, PM notes used in reviews, passive-aggressive passive voice, "should have" language without system follow-up, leadership attendance that changes engineer behavior.

2. *"Why is 'human error' never an acceptable root cause in a blameless post-mortem?"*
   — Look for: human error is a starting point not an endpoint; the Just Culture model; counterfactual test (would any competent engineer have done the same?); systems that make human errors impactful need redesign; "human error as root cause" produces no actionable system improvements.

3. *"What are the five key moments in an incident timeline and what does analyzing the gaps between them tell you?"*
   — Look for: T₀ first symptom, T₁ detection, T₂ acknowledgment, T₃ diagnosis, T₄ mitigation, T₅ resolution; T₀→T₁ = monitoring gap; T₁→T₂ = response time / escalation gap; T₂→T₃ = runbook/tooling gap; T₃→T₄ = authority/process gap; T₄→T₅ = recovery confidence gap.

**Scenario-based:**

4. *"You are facilitating a post-mortem for a SEV1 that caused $200k revenue loss. During the meeting, a senior engineer says 'The root cause is clear — James deployed without testing and broke production.' How do you handle this?"*
   — Look for: immediately reframe without shaming the speaker — "Let's focus on the system conditions that made it possible for this to cause an outage"; redirect: "What would the system need to prevent this class of change from causing a production failure?"; privately follow up with the senior engineer about post-mortem norms; do not let the statement stand unchallenged.

5. *"Your team has been running post-mortems for 6 months. Action item completion rate is 35%. The same database connection pool failure has occurred 3 times. Your engineering manager asks you to 'fix the post-mortem process.' What do you do?"*
   — Look for: 35% completion rate is a systemic failure not an individual one; investigate where action items die (never ticketed? sprint not allocated? competing priorities?); the root cause is likely that reliability work is not protected in sprint planning; escalate to leadership with data: "We have spent $X on incidents caused by this failure mode. Completing the action items would cost $Y. We need sprint allocation for reliability work"; implement: P0/P1 action items treated as sprint commitments, weekly digest to manager, quarterly review with leadership.

---

## Further Reading & Resources {#further-reading}

**Books:**
- *Site Reliability Engineering* — Chapter 15: Postmortem Culture: Learning from Failure (Google, O'Reilly) — The definitive SRE post-mortem framework
- *The Field Guide to Understanding Human Error* — Sidney Dekker — The philosophical foundation for blameless culture
- *Behind Human Error* — Woods, Dekker, Cook, Johannesen, Sarter — Systems thinking approach to human factors in incidents
- *Thinking in Systems* — Donella Meadows — Understanding system dynamics and why systemic causes are harder to find but more important to fix

**Online:**
- [PagerDuty Post-Mortem Guide](https://postmortems.pagerduty.com/) — Comprehensive, free post-mortem guide
- [Google Post-Mortem Philosophy](https://sre.google/sre-book/postmortem-culture/) — The canonical SRE post-mortem framework
- [Etsy's Debriefing Facilitation Guide](https://extfiles.etsy.com/DebriefingFacilitationGuide.pdf) — Excellent facilitation guide for blameless reviews
- [John Allspaw: The Infinite Hows](https://www.kitchensoap.com/2014/11/14/the-infinite-hows-or-the-dangers-of-the-5-whys/) — Critical perspective on 5-Whys limitations
- [Learning from Incidents](https://www.learningfromincidents.io/) — Community and resources for incident analysis practice

**Talks:**
- "The Human Side of Post-Mortems" — Dave Zwieback (Velocity) — Human factors in incident review
- "How to Run a Blameless Post-Mortem" — Liz Fong-Jones (SREcon) — Practical facilitation techniques
- "Debriefing as a Tool for Learning" — Johan Bergström (Just Culture)

---

## Key Takeaways {#key-takeaways}

> **Chapter 9 Summary**
>
> - **Post-mortems convert incident costs into reliability investments.** Without them, every incident is a pure loss. With high-quality post-mortems and completed action items, incidents become the most efficient source of reliability knowledge the organization has.
>
> - **Blameless culture is epistemological, not moral.** Blame suppresses information, distorts timelines, and leaves systemic causes intact. Blameless culture produces the accurate, complete information needed to fix the actual causes.
>
> - **The timeline is the foundation — build it from logs, not memory.** Memory is unreliable after 48 hours. Reconstruct every timeline from Prometheus, Kubernetes events, deployment logs, and PagerDuty data. The gap between T₀ (first symptom) and T₁ (detection) is consistently the highest-leverage finding.
>
> - **"Human error" is a starting point, not a conclusion.** The correct question is always: what system condition made this human action impactful? The answer is the root cause.
>
> - **5-Whys and Fishbone analysis are complementary.** 5-Whys drills deep into a single causal chain. Fishbone ensures all categories of contributing factors are considered. For complex SEV1 incidents, use both.
>
> - **A post-mortem's value is determined by its action items.** The most eloquent root cause analysis is worthless if no one fixes anything. Every action item needs an owner, a ticket, a due date, and sprint allocation before the meeting ends.
>
> - **80% action item completion rate is the floor, not the ceiling.** Below 80%, the process is producing learning on paper but not in the system. This requires management escalation and sprint allocation for reliability work.
>
> - **Aggregate analysis reveals strategic opportunities.** Individual post-mortems produce tactical fixes. Quarterly analysis across 20+ post-mortems reveals the systemic investments — circuit breakers, test coverage, staging equivalence — that prevent entire categories of future incidents.

---

*Previous: [Chapter 8 — On-Call and First Response](#chapter-8)*
*Next: Chapter 10 — Chaos Engineering*

---

*Document version: 1.0 | Study Guide: High Performance SRE | Chapter 9 of 12*
