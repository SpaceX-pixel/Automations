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

Every production incident has a cost: direct revenue loss, user trust erosion, engineer time, and the psychological toll on the team. The post-mortem is the mechanism by which that cost is converted from pure loss into organizational learning.

Without post-mortems, incidents are pure loss. With high-quality post-mortems and completed action items, incidents become the most efficient source of reliability knowledge an engineering organization possesses.

```
The Post-Mortem Value Equation

Incident Cost  =  Revenue lost + Engineer time + Trust damage

Without post-mortem:
  → Pure loss — cost paid, no return

With poor post-mortem:
  → Marginal return — time spent, learnings vague,
    actions never completed

With excellent post-mortem + completed actions:
  → Cost becomes an investment in:
    • Preventing recurrence of this specific failure
    • Building systemic awareness of failure modes
    • Improving detection and response tooling
    • Growing organizational reliability knowledge
    • Calibrating risk models for future decisions
```

The post-mortem does not undo the incident. It determines whether the incident was a pure cost or a learning investment. The difference between organizations that continuously improve reliability and those that experience the same failures repeatedly lies in post-mortem quality and follow-through.

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
───────────────────────────────────────────────────────────────
Incident occurs
    ↓
Blame-oriented review:
  "Who deployed the bad code?"
  "Why didn't the on-call catch it faster?"
  "Who approved this change?"
    ↓
Engineer identified as responsible
    ↓
Engineer punished / warned / publicly shamed
    ↓
Organization believes: "Problem solved — bad engineer identified"
    ↓
Systemic causes remain intact:
  • Deployment pipeline had no canary
  • Alert thresholds were too permissive
  • Runbook was three years out of date
  • System had known single point of failure
    ↓
Same failure mode recurs in 3 months
───────────────────────────────────────────────────────────────
```

#### The Just Culture Model

The blameless model does not mean zero accountability — it means accountability at the correct level. Adapted from Sidney Dekker's "Just Culture" framework:

```
Action Category            Organizational Response
───────────────────────────────────────────────────────────────
Human error                Console and support the person.
(slip, mistake)            Investigate the system that allowed
                           the error to have impact.

At-risk behavior           Coach and correct. Understand why
(shortcuts taken due       the behavior was chosen — usually
to competing pressures)    system design made the risky path
                           the easy path.

Reckless behavior          Accountability appropriate. Rare in
(conscious disregard       well-functioning engineering teams.
of substantial risk)       Verify: is this truly recklessness
                           or a system design problem?

Systemic failure           Redesign the system. No individual
(most incidents)           accountability.
───────────────────────────────────────────────────────────────
```

#### Language That Protects Psychological Safety

Post-mortem language shapes culture. The same factual content can be written in a way that creates or destroys psychological safety:

```
Blame Language                    Blameless Language
───────────────────────────────────────────────────────────────
"Bob deployed bad code"           "A deployment introduced a 
                                   regression in error handling"

"The on-call missed the alert"    "Alert threshold was set too 
                                   permissively; alert failed to 
                                   detect the issue"

"Alice should have tested this"   "The test suite did not cover 
                                   this code path"

"Team failed to follow runbook"   "Runbook did not address this 
                                   failure scenario"

"Human error caused the outage"   "System design did not prevent 
                                   this predictable human action 
                                   from causing user impact"
───────────────────────────────────────────────────────────────
```

**The Counterfactual Test:** Before including any statement about a person's action, ask: "If a different, equally experienced engineer had been in this exact situation, with the same information and constraints, would they have done something different?" If the answer is no, it's not a person problem—it's a system problem.

#### Running a Blameless Post-Mortem Meeting

**Pre-Meeting Preparation:**
1. Circulate draft document 24 hours before meeting
2. Assign a dedicated facilitator (not the incident IC)
3. Invite all responders — not just senior engineers
4. Block 60-90 minutes — do not rush

**Opening Statement (read verbatim):**
> "The goal of this meeting is to understand what happened and how to prevent it — not to evaluate performance. There are no stupid questions. Everything said here is focused on the system, not the people. If you hear anything that feels like blame, call it out."

**During the Meeting:**
- Facilitator summarizes timeline; ask for corrections
- Explore: Why did each person make their decision at that moment? (Not "why did they do X," but "what information did they have that made X seem right?")
- Identify contributing factors, not just proximate causes
- Validate: "It makes sense that person Y took action Z given information W"
- Separate responsibility from accountability

---

### 9.3 When to Write a Post-Mortem {#93-when-to-write}

Not every incident warrants a post-mortem. Reserved capacity for writing and action item completion is finite.

**Write a post-mortem if:**
- SEV1 or SEV2 incident (material user impact)
- Unexpected failure mode (learned something new)
- Recurring incident (prevented recurrence needed)
- Changed infrastructure or process post-incident
- Organizational learning benefit exceeds effort

**Consider skip if:**
- SEV3+ (single user affected; expected failure pattern)
- Fully automated remediation; no human decision involved
- No action items identified

---

### 9.4 Timeline Reconstruction {#94-timeline-reconstruction}

An accurate timeline is the foundation of effective RCA. Reconstruct from multiple sources:

**Data Sources for Timeline Reconstruction:**
- Prometheus/Datadog metrics (precise timestamps)
- Application/infrastructure logs (exact sequence of events)
- Slack/chat history (human observations and decisions)
- Deployment systems (when code/config changes deployed)
- PagerDuty/on-call logs (who was alerted and when)
- Git commits (what changed)
- Database transaction logs (what data operations occurred)

**Automated Timeline Extraction:**

```python
import json
from datetime import datetime
from typing import List

class TimelineReconstructor:
    def __init__(self, incident_id: str):
        self.incident_id = incident_id
        self.events = []
    
    def add_metric_event(self, timestamp: str, metric: str, value: float, severity: str):
        """Add an event from metrics (Prometheus, Datadog)"""
        self.events.append({
            "timestamp": timestamp,
            "source": "metrics",
            "metric": metric,
            "value": value,
            "severity": severity,
        })
    
    def add_log_event(self, timestamp: str, component: str, level: str, message: str):
        """Add an event from logs"""
        self.events.append({
            "timestamp": timestamp,
            "source": "logs",
            "component": component,
            "level": level,
            "message": message,
        })
    
    def add_alert_event(self, timestamp: str, alert_name: str, recipient: str):
        """Add an alert firing event"""
        self.events.append({
            "timestamp": timestamp,
            "source": "alerting",
            "alert": alert_name,
            "recipient": recipient,
        })
    
    def add_human_event(self, timestamp: str, person: str, action: str, tool: str):
        """Add a human action (deployment, config change, etc.)"""
        self.events.append({
            "timestamp": timestamp,
            "source": "human",
            "person": person,
            "action": action,
            "tool": tool,
        })
    
    def get_timeline(self) -> List[dict]:
        """Return timeline sorted by timestamp"""
        return sorted(self.events, key=lambda e: e["timestamp"])
    
    def print_timeline(self):
        """Pretty-print the timeline"""
        for event in self.get_timeline():
            ts = event["timestamp"]
            if event["source"] == "metrics":
                print(f"[{ts}] METRIC: {event['metric']} = {event['value']} ({event['severity']})")
            elif event["source"] == "logs":
                print(f"[{ts}] LOG: {event['component']}/{event['level']} — {event['message']}")
            elif event["source"] == "alerting":
                print(f"[{ts}] ALERT: {event['alert']} → {event['recipient']}")
            elif event["source"] == "human":
                print(f"[{ts}] ACTION: {event['person']} {event['action']} (via {event['tool']})")
```

#### Annotating the Timeline: The Five Key Moments

Mark these critical moments:

```
T+0:00  - Service degradation begins (usually detected via metrics)
T+2:30  - Detection: First alert fires (gap: T+2:30 - T+0:00 = 2.5 min TTDETECT)
T+3:15  - Triage: On-call understands severity
T+5:45  - Diagnosis: Root cause hypothesis formed
T+7:20  - Mitigation begins: First action taken
T+9:15  - Resolution: Service returns to normal (gap: T+9:15 - T+0:00 = 9.25 min TTRESOLUTION)
T+9:30  - Post-incident: Incident declared over; monitoring stabilizes
```

**SLO Impact Calculation:**
```
Service availability during incident = 1 - (error_rate_during_incident × minutes_of_incident)
Example: 5% error rate for 9 minutes on 99% availability SLO
  Availability loss = 5% × 9 = 0.45% of daily budget
```

---

### 9.5 Root Cause Analysis Methods {#95-rca-methods}

Three methods, each suited to different incident patterns:

1. **5-Whys** — For simple linear causal chains
2. **Fishbone (Ishikawa)** — For complex, multi-factor incidents
3. **Fault Tree Analysis** — For high-risk, systematic failures (nuclear plants, aircraft)

---

### 9.6 The 5-Whys Technique {#96-five-whys}

Ask "why" repeatedly until you reach the root cause. The art is knowing when to stop — not at human error, but at system design.

#### 5-Whys: Worked Example

```
Incident: Payment service unavailable for 12 minutes
User Impact: Users unable to complete checkout; $50K revenue loss

Why 1: Why did payment service go down?
  → Database connection pool was exhausted

Why 2: Why was the connection pool exhausted?
  → New retry logic in payment service created infinite retry loop

Why 3: Why was infinite retry loop introduced?
  → Developer added retry without testing against timeouts

Why 4: Why wasn't this tested?
  → Test suite did not include timeout scenarios

Why 5: Why doesn't the test suite include timeout scenarios?
  → Developers perceive timeout testing as "networking stuff" — someone else's job
  → No shared ownership of end-to-end resilience

ROOT CAUSE: Organizational boundary between application and infrastructure 
           testing; unclear ownership of resilience testing

NOT A ROOT CAUSE: "Developer made a mistake" — this is a human error description,
                  not actionable for prevention
```

#### 5-Whys Common Traps

**Trap 1: Stopping at Human Error**
- ❌ "Why did the incident happen? Bob didn't test the change."
- ✅ "Why wasn't the change tested? Automated testing didn't cover this scenario."

**Trap 2: Stopping Too Early**
- ❌ "Why? Server ran out of memory."
- ✅ Keep going: "Why did it run out of memory? Leak in cache. Why? TTL not set. Why? Config defaulted to null."

**Trap 3: Anchoring on Proximate Cause**
- ❌ "The database crashed — that's why service failed."
- ✅ Continue: "But why did one database crash cascade to all replicas? No circuit breaker. Why not? Never implemented. Why? Cost perceived as high."

---

### 9.7 Fishbone (Ishikawa) Diagram Analysis {#97-fishbone}

Fishbone is better for complex incidents with multiple contributing factors.

#### Standard Fishbone Categories for SRE

```
                            Incident: Payment Outage
                                    ↑
                    ┌───────────────┼───────────────┐
                    │               │               │
              PEOPLE          PROCESS          TECHNOLOGY
                    │               │               │
    ┌───────────────┴───┐   ┌───────┴────────┐    │
    │                   │   │                │    │
  Fatigue         On-call    No             Database
  (night shift)   runbook    canary         failover
  outdated        unclear    deployment     misconfigured
                              
    ┌─────────────────────────┐   ┌──────────────────┐
    │                         │   │                  │
  TOOLS                    ENVIRONMENT         DATA
    │                         │   │                  │
  Alert too    ┌────────────┤  └─────────┘
  noisy;       │            │ 
  missed       No           Production
  true         logging      traffic
  signal       of errors    4x staging
```

#### Fishbone vs 5-Whys — When to Use Each

| Situation | Use 5-Whys | Use Fishbone |
|-----------|-----------|--------------|
| Simple linear failure (one cause chain) | ✓ | ✗ |
| Complex incident (multiple factors) | ✗ | ✓ |
| Time pressure (quick analysis needed) | ✓ | ✗ |
| Team learning (explore system deeply) | ✗ | ✓ |
| Infrastructure incident | ✓ | ✗ |
| Organizational/process incident | ✗ | ✓ |

---

### 9.8 Contributing Factors vs Root Causes {#98-contributing-factors}

**Contributing Factor:** A condition that existed before the incident and, if removed, would have reduced (but not eliminated) impact.

**Root Cause:** The reason the contributing factor existed; its absence would have prevented the incident entirely.

```
Example: Database failed, service crashed, users impacted

Contributing Factors:
  • Database replica was not responding to health checks
  • Load balancer didn't remove it from pool in time
  • Application didn't have circuit breaker

Root Causes:
  • Monitoring of database health only checked TCP port, not query latency
  • No automated testing of failover behavior
  • Circuit breaker was deprioritized in backlog for 6 months

Fix Contributing Factors: Makes failure slower, less severe
Fix Root Causes: Prevents failure entirely
```

---

### 9.9 Writing Effective Post-Mortem Documents {#99-writing-post-mortems}

#### The Post-Mortem Template

```markdown
# Post-Mortem: [Service] [Failure Type]

**Date:** YYYY-MM-DD | **Duration:** X min | **Severity:** SEV1/2/3 | **Status:** Resolved

---

## Executive Summary

[2-3 sentences: What happened? Who was impacted? What was the business impact?]

Example:
"The payment service was unavailable for 12 minutes due to a database connection pool exhaustion 
caused by a new retry loop that was deployed without timeout testing. Approximately 8,000 users 
were unable to complete checkout. Estimated revenue impact: $50,000."

---

## Incident Timeline

| Time | What Happened | Data Source |
|------|---------------|-------------|
| 14:30 | New payment retry logic deployed to production | Git log |
| 14:33 | Error rate on payment service spikes to 45% | Prometheus |
| 14:35 | PagerDuty alert fires: "Payment Error Rate High" | PagerDuty logs |
| 14:36 | On-call engineer Alice paged; begins investigation | Slack |
| 14:41 | Database connection pool exhaustion identified in logs | Application logs |
| 14:42 | Deployment rolled back | Git |
| 14:45 | Service returns to normal; error rate < 0.5% | Prometheus |

---

## What Went Well ✓

- Alert fired within 2 minutes of degradation
- On-call was responsive; began investigation immediately
- Root cause identified quickly by reviewing recent deployments
- Rollback was clean and complete

---

## What Could Be Improved ⚠️

- No timeout testing in pre-production validation
- Developers not aware of connection pool limits
- Deployment pipeline had no automated testing of retry logic

---

## Root Cause Analysis

### Contributing Factors
1. **No timeout testing in test suite** — Retry logic was tested in happy path only
2. **Insufficient documentation** — Connection pool limits not documented for developers
3. **No automated regression testing** — Retry logic behavior not tested post-deployment

### Root Causes (Why these conditions existed)
1. **Organizational boundary** — Testing responsibility unclear between app and infrastructure teams
2. **Incomplete test coverage** — Timeout scenarios deprioritized; required extra infrastructure
3. **Missing runbooks** — Developers not aware of production constraints (connection pool size)

### Why This Happened (System Design Root)
The organization treats "application testing" and "infrastructure testing" as separate domains. 
When retry logic changes, application tests pass, but infrastructure constraints (DB connection pools) 
are not tested. No clear ownership of end-to-end resilience testing.

---

## Action Items

| Item | Owner | Priority | Due Date | Status |
|------|-------|----------|----------|--------|
| Add timeout testing to payment service test suite | @alice | High | 2025-06-06 | Open |
| Document connection pool limits for all developers | @bob | High | 2025-06-06 | Open |
| Create pre-deployment integration test for retry logic | @carol | High | 2025-06-13 | Open |
| Review retry logic in all services for similar issues | @dave | Medium | 2025-06-20 | Open |
| Implement canary deployment for payment service changes | @eve | Medium | 2025-06-27 | Open |

---

## Prevention: If This Happens Again

1. Deployment pipeline will reject changes with retry logic that lacks timeout testing
2. Alert threshold lowered from 5% to 2% error rate for faster detection
3. Connection pool limits documented in developer onboarding wiki
4. Monthly audit of retry logic across all services

---

## Questions & Discussion

*Was there anything about the incident or response that confused you?*
*Any aspects of the timeline or RCA that need clarification?*

---

## Lessons for Other Teams

This incident reveals a systemic gap in how we handle resilience across team boundaries. 
If you're adding retry logic, timeout logic, or connection pooling, coordinate with infrastructure 
and include integration tests in your pipeline.
```

---

### 9.10 Action Item Tracking and Accountability {#910-action-item-tracking}

Post-mortems are only valuable if action items are completed. This requires:

1. **Clear ownership** — One person per action item
2. **Specific success criteria** — Not "improve testing" but "add timeout test for payment retry"
3. **Time-bound deadlines** — Not "soon" but "2025-06-06"
4. **Public tracking** — Visible to org; progress reported monthly
5. **Executive support** — When trade-offs needed, prioritize reliability action items

#### The Action Item Accountability Cycle

```
Post-mortem written
    ↓
Action items identified + assigned
    ↓
Owner schedules work in sprint (not "when I have time")
    ↓
Weekly check-in: What's the status?
    ↓
At 50% of due date: Is this on track?
    ↓
At due date: Is it done?
    ├─ YES → Close item; measure impact
    └─ NO → Escalate: Why delayed? New deadline?
    ↓
30 days later: Did the fix prevent recurrence?
```

---

### 9.11 Learning from Incidents at Scale {#911-learning-at-scale}

With many incidents monthly, patterns emerge:

#### Incident Pattern Analysis

```python
def analyze_incident_patterns(incidents: List[dict]) -> dict:
    """
    Identify systemic patterns across incidents.
    
    Returns: Top failure modes, most frequent root causes, etc.
    """
    failure_modes = {}
    root_causes = {}
    affected_services = {}
    time_to_detect = []
    time_to_resolve = []
    
    for incident in incidents:
        # Pattern 1: Most common failure types
        mode = incident.get("failure_type")
        failure_modes[mode] = failure_modes.get(mode, 0) + 1
        
        # Pattern 2: Most common root causes (systemic issues)
        for cause in incident.get("root_causes", []):
            root_causes[cause] = root_causes.get(cause, 0) + 1
        
        # Pattern 3: Services with most incidents
        service = incident.get("service")
        affected_services[service] = affected_services.get(service, 0) + 1
        
        # Pattern 4: Detection and resolution latencies
        ttd = incident.get("time_to_detect_min")
        ttr = incident.get("time_to_resolve_min")
        if ttd: time_to_detect.append(ttd)
        if ttr: time_to_resolve.append(ttr)
    
    return {
        "most_common_failures": sorted(failure_modes.items(), key=lambda x: x[1], reverse=True),
        "systemic_root_causes": sorted(root_causes.items(), key=lambda x: x[1], reverse=True),
        "most_affected_services": sorted(affected_services.items(), key=lambda x: x[1], reverse=True),
        "avg_time_to_detect_min": sum(time_to_detect) / len(time_to_detect) if time_to_detect else 0,
        "avg_time_to_resolve_min": sum(time_to_resolve) / len(time_to_resolve) if time_to_resolve else 0,
    }
```

#### Learning Sharing Mechanisms

1. **Monthly Incident Review** — All engineers review top 5 incidents of the month
2. **Blameless Learning Culture** — Celebrate: "We learned X"
3. **Distributed Runbook Updates** — Incidents drive updates to operational playbooks
4. **Architecture Reviews** — Use incident patterns to inform system redesigns
5. **Training & Onboarding** — New engineers learn from real post-mortems

---

### 9.12 Post-Mortem Anti-Patterns and Rescue Techniques {#912-antipatterns}

**Anti-Pattern 1: "It's just human error"**
- ❌ "Bob made a typo in config"
- ✅ "Config syntax validation tool didn't catch the typo; no dry-run before apply"

**Anti-Pattern 2: Incomplete RCA ("we fixed the symptom")**
- ❌ "We restarted the service and it's working now"
- ✅ Continue: "Why did it crash? Out of memory. Why? Unbounded queue. Why? No flow control."

**Anti-Pattern 3: No action items**
- ❌ Post-mortem written, filed away, forgotten
- ✅ Each post-mortem → 3-5 specific action items with owners and dates

**Anti-Pattern 4: Action items never completed**
- ❌ "Improve monitoring" assigned to @alice, due "ASAP", status unknown
- ✅ "Add p99 latency alert for checkout service" assigned to @alice, due 2025-06-06, tracked publicly

**Anti-Pattern 5: Blame creeping in**
- ❌ "Alice failed to follow the runbook"
- ✅ "The runbook didn't cover this scenario"

---

## Key Principles & Best Practices {#key-principles}

1. **Blameless is about finding truth**, not being nice
2. **Separate contributing factors from root causes** — Fix both, but understand the difference
3. **Timeline first** — Establish accurate sequence before RCA
4. **Ask "why" until you reach system design**, not human error
5. **Action items drive value** — Post-mortems are only valuable if followed by action
6. **Public sharing** — Incidents are organizational learning, not shameful secrets
7. **Measure impact** — Track: Did this fix prevent recurrence?

---

## Tools & Technologies {#tools}

| Tool | Purpose | License |
|------|---------|---------|
| PostMortem doc template | Structured incident documentation | Internal |
| Incident tracker | Public action item visibility | Internal or Jira |
| Slack (incident channel) | Real-time communication during incident | Commercial |
| Grafana (incident dashboard) | Timeline reconstruction from metrics | OSS |
| GitHub Issues | Action item tracking | OSS |

---

## Hands-on Exercises / Labs {#labs}

### Lab 9.1 — Timeline Reconstruction

**Objective:** Reconstruct a realistic incident timeline from raw data sources.

**Time:** 1 hour

**Steps:**
1. Given: Sample Prometheus metrics, logs, Slack history, PagerDuty events
2. Extract timestamps for: detection, alert, on-call page, diagnosis, mitigation, resolution
3. Calculate: TTDETECT, TTDIAGNOSE, TTRESOLUTION
4. Identify: Five key moments in the timeline
5. Create: Professional timeline visualization

**Deliverable:** Timeline diagram + key metrics

---

### Lab 9.2 — 5-Whys Deep Dive

**Objective:** Practice 5-Whys analysis on a complex incident.

**Time:** 1.5 hours

**Steps:**
1. Pick an incident from your organization (or use provided case study)
2. Start: "Why did [failure] occur?"
3. Why-chain 5 levels; document each answer
4. Identify: Root cause vs contributing factors
5. Propose: System changes that would prevent recurrence

**Deliverable:** Annotated 5-Whys chain + prevention recommendations

---

### Lab 9.3 — Post-Mortem Writing

**Objective:** Draft a complete, high-quality post-mortem.

**Time:** 2 hours

**Steps:**
1. Use provided incident scenario or real incident
2. Write using the template in Section 9.9
3. Include: Timeline, RCA, action items, lessons
4. Peer review: Is it blameless? Is RCA clear? Are action items specific?
5. Revise based on feedback

**Deliverable:** Completed post-mortem document

---

### Lab 9.4 — Aggregate Incident Analysis

**Objective:** Analyze patterns across multiple incidents.

**Time:** 1 hour

**Steps:**
1. Given: Data from 20 incidents (failure types, root causes, services affected)
2. Run analysis: Most common failures, systemic causes, most affected services
3. Hypothesis: What systemic change would prevent the most incidents?
4. Plan: What action items would address the top 3 root causes?

**Deliverable:** Incident pattern analysis + improvement recommendations

---

## Common Pitfalls & Anti-patterns {#pitfalls}

**Pitfall 1: Blame Creeps Back In**
- *Problem:* Post-mortem starts blameless, then "Alice should have..."
- *Fix:* Facilitator intervenes: "System question: How do we prevent this scenario?"

**Pitfall 2: Action Items Never Completed**
- *Problem:* 80% of post-mortem action items are not done 3 months later
- *Fix:* Public tracking, executive prioritization, weekly check-ins

**Pitfall 3: No Action Items**
- *Problem:* Post-mortem identifies issues but proposes no changes
- *Fix:* Template requires ≥3 action items per post-mortem

**Pitfall 4: RCA Stops Too Early**
- *Problem:* "Cause: Out of memory. Done."
- *Fix:* Keep asking why until you reach system design

**Pitfall 5: Same Incident Twice**
- *Problem:* Identical failure recurs; original post-mortem action items not completed
- *Fix:* RCA of second incident includes: "Why didn't the original fix prevent this?"

---

## Interview Questions {#interview-questions}

1. **Explain the difference between "blameless" and "no accountability." Can both exist?**
2. **Describe the Just Culture model. What are the four categories of action?**
3. **You're facilitating a post-mortem. A senior engineer says: "The junior dev deployed bad code." How do you respond?**
4. **Walk through 5-Whys analysis. When does it break down? When should you use Fishbone instead?**
5. **What is the difference between a contributing factor and a root cause? Give an example.**
6. **Design a post-mortem process for your team. How would you ensure action items are completed?**
7. **An action item from a post-mortem 6 months ago wasn't completed. The same incident recurs. How do you respond?**
8. **You notice a pattern: 40% of SEV1 incidents are due to "insufficient testing." What systemic change do you propose?**
9. **Write a post-mortem template that ensures blameless language and actionable outcomes.**
10. **How would you measure the effectiveness of your post-mortem process?**

---

## Further Reading & Resources {#further-reading}

- **"Blameless PostMortems and a Just Culture" by John Allspaw** — Etsy blog post (foundational)
- **"The Field Guide to Understanding Human Error" by Sidney Dekker** — Just Culture framework
- **"Incident Response & Recovery" by Chartrand, Pagliarulo** — O'Reilly
- **Google's "Incident Management Best Practices"** — Google Cloud documentation
- **"The Five Dysfunctions of a Team" by Patrick Lencioni** — Psychological safety foundation

---

## Key Takeaways {#key-takeaways}

1. **Post-mortems convert incident costs into organizational learning**—but only if action items are completed.
2. **Blameless culture is about finding truth**, not avoiding accountability.
3. **Accurate timelines are the foundation** of effective RCA.
4. **Use 5-Whys for simple chains; Fishbone for complex multi-factor incidents.**
5. **Separate contributing factors from root causes**—fix both, but understand the difference.
6. **Action items drive value**—track them publicly; ensure completion.
7. **Systemic patterns across incidents** reveal the highest-leverage improvements.
8. **Language matters**: How you phrase findings determines whether people learn or hide.
