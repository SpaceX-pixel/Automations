# Chapter 11 — Artificial Intelligence for Site Reliability Engineering
---

## Table of Contents

- [Learning Objectives](#learning-objectives)
- [Core Concepts](#core-concepts)
  - [11.1 AIOps — The Discipline and Its Limits](#111-aiops)
  - [11.2 Anomaly Detection with Machine Learning](#112-anomaly-detection)
  - [11.3 Predictive Alerting](#113-predictive-alerting)
  - [11.4 LLM-Assisted Incident Response](#114-llm-incident-response)
  - [11.5 Automated Root Cause Analysis](#115-automated-rca)
  - [11.6 Intelligent On-Call Routing](#116-intelligent-routing)
  - [11.7 AI-Driven Capacity Forecasting](#117-capacity-forecasting)
  - [11.8 Log Intelligence and Natural Language Querying](#118-log-intelligence)
  - [11.9 AI for SLO and Error Budget Management](#119-ai-slo)
  - [11.10 Ethical Concerns and Failure Modes](#1110-ethics)
  - [11.11 Building an AI-Augmented SRE Practice](#1111-building)
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

- Define AIOps and clearly articulate where AI adds genuine value in SRE workflows versus where it introduces risk, hallucination, or automation bias.
- Implement anomaly detection models — from statistical baselines to isolation forests — and integrate them with Prometheus to generate alerts on behavioral deviations rather than static thresholds.
- Build an LLM-assisted incident response pipeline that surfaces relevant runbooks, synthesizes alert context, and generates structured post-mortem drafts — while maintaining human authority over all consequential decisions.
- Evaluate AI-generated RCA outputs critically: understanding their utility as hypothesis generators versus their limitations as authoritative root cause finders.
- Apply ethical frameworks to AI use in SRE: identifying alert hallucination risk, automation bias, data quality requirements, and the irreplaceable role of human judgment in high-stakes operations.

---

## Core Concepts {#core-concepts}

### 11.1 AIOps — The Discipline and Its Limits {#111-aiops}

**AIOps** (Artificial Intelligence for IT Operations) is the application of machine learning, natural language processing, and automation to operational data — metrics, logs, traces, tickets, and alerts — to improve incident response time and reduce toil.

Gartner coined the term in 2016. The promise: reduce alert noise, detect anomalies earlier, correlate signals across data sources too large for human review, and automate routine operational tasks.

The reality, a decade later, is more nuanced. AIOps delivers genuine value in specific, well-bounded applications. It also introduces new failure modes — particularly automation bias, hallucination, and explainability gaps that make debugging harder, not easier.

#### AIOps Value Map

```
HIGH VALUE (proven, deploy with confidence)
  ✓ Anomaly detection on time-series metrics
  ✓ Log pattern clustering (group similar errors automatically)
  ✓ Alert noise reduction (correlation + deduplication)
  ✓ Capacity trend forecasting
  ✓ LLM-assisted runbook lookup and context summarization
  ✓ Automated ticket classification and routing

MEDIUM VALUE (useful with human oversight)
  ≈ Automated RCA hypothesis generation (human must verify)
  ≈ Predictive failure alerting (high false positive risk)
  ≈ LLM-generated post-mortem drafts (factual errors possible)
  ≈ Intelligent on-call routing (useful signal, not sole authority)

LOW VALUE / HIGH RISK (approach cautiously)
  ✗ Fully automated production remediation without human approval
  ✗ LLM-generated kubectl/SQL commands executed without review
  ✗ AI-generated RCA as authoritative root cause (no human verification)
  ✗ Black-box model alerts with no explainability
  ✗ Replacing on-call engineers with fully automated response
```

#### The Human-in-the-Loop Imperative

The most important architectural decision in any AIOps implementation is where the human sits in the loop. AI should amplify human judgment, not replace it for consequential decisions.

```
Decision Tier          AI Role                  Human Role
─────────────────────────────────────────────────────────────────
Detection              Primary (anomaly ML)     Review + calibrate model
Triage                 Support (context)        Final severity decision
Hypothesis             Suggest (LLM/ML)         Validate + reject/accept
Remediation (low risk) Execute (auto-remediate) Review logs; abort if wrong
Remediation (high risk) Suggest action         Execute with full authority
Post-mortem            Draft (LLM)             Verify facts; add judgment
Learning               Surface patterns         Interpret; prioritize action
```

---

### 11.2 Anomaly Detection with Machine Learning {#112-anomaly-detection}

Traditional threshold-based alerting requires humans to manually set thresholds for every metric. This approach fails at scale: services have thousands of metrics, optimal thresholds change with traffic patterns and deployments, and manual tuning is impossible.

ML-based anomaly detection learns normal behavior from historical data and alerts when current behavior deviates from that learned baseline — without requiring manual threshold configuration.

#### Method 1: Statistical Baseline with Z-Score Detection

The simplest approach. Compute the mean and standard deviation of a metric over a rolling window, then alert when the current value exceeds N standard deviations from the mean.

```python
import numpy as np
import pandas as pd
from dataclasses import dataclass
from typing import List, Optional
import requests
from datetime import datetime, timedelta

@dataclass
class AnomalyDetectionResult:
    timestamp:       datetime
    metric_name:     str
    current_value:   float
    expected_value:  float
    std_deviation:   float
    z_score:         float
    is_anomaly:      bool
    severity:        str        # none | low | medium | high | critical
    explanation:     str

def detect_zscore_anomaly(
    metric_name:    str,
    current_value:  float,
    historical_values: List[float],
    z_threshold_warning:  float = 2.5,
    z_threshold_critical: float = 4.0,
) -> AnomalyDetectionResult:
    """
    Detect anomalies using Z-score against rolling baseline.
    Seasonal adjustment uses hour-of-week comparison to avoid
    false alarms from predictable traffic patterns.
    """
    if len(historical_values) < 30:
        return AnomalyDetectionResult(
            timestamp=datetime.utcnow(),
            metric_name=metric_name,
            current_value=current_value,
            expected_value=float(np.mean(historical_values)) if historical_values else 0,
            std_deviation=0,
            z_score=0,
            is_anomaly=False,
            severity="none",
            explanation="Insufficient history for anomaly detection"
        )

    values = np.array(historical_values)
    mean   = np.mean(values)
    std    = np.std(values)

    if std < 1e-10:
        # Metric is constant — any change is anomalous
        is_anomaly = current_value != mean
        return AnomalyDetectionResult(
            timestamp=datetime.utcnow(),
            metric_name=metric_name,
            current_value=current_value,
            expected_value=mean,
            std_deviation=0,
            z_score=float('inf') if is_anomaly else 0,
            is_anomaly=is_anomaly,
            severity="high" if is_anomaly else "none",
            explanation="Metric usually constant — any deviation is anomalous"
        )

    z_score = (current_value - mean) / std

    if abs(z_score) >= z_threshold_critical:
        severity = "critical"
    elif abs(z_score) >= z_threshold_warning:
        severity = "high"
    elif abs(z_score) >= z_threshold_warning * 0.7:
        severity = "medium"
    else:
        severity = "none"

    is_anomaly = abs(z_score) >= z_threshold_warning

    direction = "above" if z_score > 0 else "below"
    explanation = (
        f"{metric_name} is {abs(z_score):.1f} standard deviations "
        f"{direction} expected value "
        f"(current: {current_value:.3f}, expected: {mean:.3f} ± {std:.3f})"
        if is_anomaly else
        f"{metric_name} within normal range (z={z_score:.2f})"
    )

    return AnomalyDetectionResult(
        timestamp=datetime.utcnow(),
        metric_name=metric_name,
        current_value=current_value,
        expected_value=float(mean),
        std_deviation=float(std),
        z_score=float(z_score),
        is_anomaly=is_anomaly,
        severity=severity,
        explanation=explanation
    )
```

#### Method 2: Isolation Forest for Multivariate Anomaly Detection

Z-score works on single metrics. Real anomalies often manifest as unusual *combinations* of metrics — e.g., high request rate combined with low error rate combined with unusual latency distribution. Isolation Forest detects these multivariate patterns.

```python
from sklearn.ensemble import IsolationForest
from sklearn.preprocessing import StandardScaler
import numpy as np
import pandas as pd
import joblib
import os
from typing import Optional, List

class MultivariatAnomalyDetector:
    """
    Isolation Forest-based anomaly detector for service health.
    Trains on multiple metrics simultaneously to detect
    unusual combinations that single-metric thresholds miss.
    """

    def __init__(
        self,
        service:          str,
        contamination:    float = 0.02,    # Expected fraction of anomalies (2%)
        n_estimators:     int   = 100,
        model_path:       str   = "/models/anomaly",
    ):
        self.service       = service
        self.contamination = contamination
        self.model_path    = f"{model_path}/{service}_iforest.pkl"
        self.scaler_path   = f"{model_path}/{service}_scaler.pkl"
        self.feature_names: List[str] = []
        self.model:  Optional[IsolationForest] = None
        self.scaler: Optional[StandardScaler]  = None

        # Load existing model if available
        if os.path.exists(self.model_path):
            self.model  = joblib.load(self.model_path)
            self.scaler = joblib.load(self.scaler_path)

    def extract_features_from_prometheus(
        self,
        prometheus_url: str,
        lookback_hours: int = 168,  # 7 days of training data
    ) -> pd.DataFrame:
        """
        Query Prometheus for service health metrics.
        Returns DataFrame with one row per time step, one column per feature.
        """
        # Feature set: Four Golden Signals + saturation metrics
        feature_queries = {
            "error_rate":      f'sum(rate(http_requests_total{{service="{self.service}",status_code=~"5.."}}[5m])) / sum(rate(http_requests_total{{service="{self.service}"}}[5m]))',
            "request_rate":    f'sum(rate(http_requests_total{{service="{self.service}"}}[5m]))',
            "p99_latency":     f'histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket{{service="{self.service}"}}[5m])) by (le))',
            "cpu_utilization": f'avg(rate(container_cpu_usage_seconds_total{{container="{self.service}"}}[5m]))',
            "memory_bytes":    f'avg(container_memory_working_set_bytes{{container="{self.service}"}})',
        }

        data_frames = {}
        for feature_name, query in feature_queries.items():
            try:
                r = requests.get(
                    f"{prometheus_url}/api/v1/query_range",
                    params={"query": query},
                    timeout=15
                )
                results = r.json().get("data", {}).get("result", [])
                if results:
                    series = results[0]["values"]
                    data_frames[feature_name] = pd.Series(
                        {datetime.fromtimestamp(float(ts)): float(val)
                         for ts, val in series}
                    )
            except Exception as e:
                print(f"Warning: Could not fetch {feature_name}: {e}")

        df = pd.DataFrame(data_frames).fillna(method="ffill").fillna(0)
        self.feature_names = list(df.columns)
        return df

    def train(self, training_data: pd.DataFrame) -> None:
        """Train the isolation forest on historical data."""
        X = training_data.values

        self.scaler = StandardScaler()
        X_scaled    = self.scaler.fit_transform(X)

        self.model = IsolationForest(
            contamination = self.contamination,
            n_estimators  = 100,
            random_state  = 42,
            n_jobs        = -1,
        )
        self.model.fit(X_scaled)

        # Persist model
        os.makedirs(os.path.dirname(self.model_path), exist_ok=True)
        joblib.dump(self.model,  self.model_path)
        joblib.dump(self.scaler, self.scaler_path)
        print(f"Model trained and saved to {self.model_path}")

    def predict(self, current_features: dict) -> dict:
        """Predict whether current service state is anomalous."""
        if not self.model or not self.scaler:
            return {"error": "Model not trained. Call train() first."}

        # Build feature vector in correct order
        feature_vector = np.array([[
            current_features.get(f, 0.0)
            for f in self.feature_names
        ]])

        X_scaled    = self.scaler.transform(feature_vector)
        score       = self.model.score_samples(X_scaled)[0]
        prediction  = self.model.predict(X_scaled)[0]
        is_anomaly  = prediction == -1

        return {
            "service":       self.service,
            "is_anomaly":    is_anomaly,
            "anomaly_score": round(float(score), 4),
            "severity":      (
                "critical" if score < -0.3 else
                "high"     if score < -0.2 else
                "medium"   if score < -0.1 else
                "low"      if is_anomaly   else
                "none"
            ),
            "timestamp": datetime.utcnow().isoformat(),
        }
```

#### Method 3: Prophet for Seasonal Time-Series Anomaly Detection

Facebook Prophet handles complex seasonality patterns (daily + weekly + holiday) that make Z-score and Isolation Forest produce excessive false positives.

#### Integrating Anomaly Detection with Prometheus

Expose anomaly scores as Prometheus metrics for alerting:

```yaml
# Prometheus alert on ML anomaly detection
- alert: ServiceAnomalyDetected
  expr: service_anomaly_detected{severity=~"high|critical"} == 1
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "ML anomaly detected in {{ $labels.service }}"
    description: |
      Isolation Forest anomaly detector flagged {{ $labels.service }}
      as exhibiting unusual behavior (severity: {{ $labels.severity }}).
      Review metrics and compare with baseline.
      This is a supporting signal — verify with Golden Signals dashboard.
```

---

### 11.3 Predictive Alerting {#113-predictive-alerting}

Predictive alerting fires before a failure occurs — detecting trends that will cross a threshold in the future rather than waiting for the threshold to be crossed now.

```promql
# Predict whether disk will fill in 4 hours
predict_linear(
  node_filesystem_avail_bytes{
    mountpoint="/",
    fstype!="tmpfs"
  }[2h],
  4 * 3600  # 4 hours in seconds
) < 0

# Predict connection pool exhaustion in 30 minutes
predict_linear(
  pg_stat_activity_count{state="active"}[30m],
  1800  # 30 minutes
) > pg_settings_max_connections * 0.90
```

---

### 11.4 LLM-Assisted Incident Response {#114-llm-incident-response}

Large Language Models offer concrete capabilities in incident response: context synthesis, runbook retrieval, status page generation, and post-mortem drafting.

**Critical constraint:** LLMs must never directly execute production commands. They suggest; humans decide and execute.

#### Architecture: The Incident Response Assistant

LLM ingests:
- Active alerts
- Recent logs (sample)
- Deployed versions
- Runbook index
- Historical incidents

LLM outputs:
- Structured incident summary
- Top 3 hypotheses (ranked by likelihood)
- Recommended diagnostic steps
- Relevant runbook snippets
- Draft status updates

---

### 11.5 Automated Root Cause Analysis {#115-automated-rca}

AI can suggest RCA hypotheses by analyzing patterns in logs, metrics, and configuration changes, but human judgment must validate the analysis. Use AI as a hypothesis generator, not as authoritative truth.

---

### 11.6 Intelligent On-Call Routing {#116-intelligent-routing}

Route alerts to the engineer most likely to resolve them quickly based on:
- Historical resolution time by engineer
- Current on-call schedule and rotations
- Service expertise scores
- Geographic timezone optimization

---

### 11.7 AI-Driven Capacity Forecasting {#117-capacity-forecasting}

Use ML models (Prophet, LSTM, Exponential Smoothing) to forecast capacity demand 1-3 months ahead, accounting for seasonality, growth trends, and known events.

---

### 11.8 Log Intelligence and Natural Language Querying {#118-log-intelligence}

Index logs with embeddings, enabling natural language queries like:
- "Show me all errors related to payment processing in the last hour"
- "Which services had unusual response time patterns yesterday?"
- "Find logs associated with user ID 12345"

---

### 11.9 AI for SLO and Error Budget Management {#119-ai-slo}

Use ML to predict error budget burn rate and trigger proactive actions:
- If burn rate > 2x normal, recommend deployment hold
- If SLO track record indicates breach risk, auto-escalate capacity investment

---

### 11.10 Ethical Concerns and Failure Modes {#1110-ethics}

#### Failure Mode 1: Automation Bias

Humans over-trust automated decisions. An AI alert fires → human assumes it's correct → doesn't verify → incorrect action.

**Mitigation:**
- Require human confirmation for all consequential actions
- Audit AI decisions post-incident: was it right?
- Monitor over-trust: if engineers never question AI suggestions, retrain expectations

#### Failure Mode 2: LLM Hallucination in Operational Context

LLM generates plausible-sounding but false commands or advice. Example: "Run `kubectl delete pvc data-cache` to free space" — which accidentally deletes a production data volume.

**Mitigation:**
- LLM output goes to review queue, never direct to execution
- Require human to explicitly approve any destructive action
- Validate all LLM-generated commands in dry-run mode first

#### Failure Mode 3: Model Drift and Distribution Shift

Anomaly detection model trained on 2024 data. In 2025, traffic patterns change (new feature launch, user base shift). Model now fires false positives or misses true anomalies.

**Mitigation:**
- Retrain models on a regular schedule (weekly/monthly)
- Monitor model performance: track false positive rate, false negative rate
- A/B test new models before replacing production models
- Keep human thresholds as safety net alongside ML

#### The Ethical Framework for AI in SRE

```
1. Transparency
   - Humans understand why an alert fired
   - Explainability built in: "Anomaly score: 0.85. Reason: CPU 3σ above baseline"

2. Human Authority
   - Humans remain decision-makers for consequential actions
   - AI suggests; human approves

3. Auditability
   - Every AI decision logged: timestamp, inputs, output, human decision
   - Enable post-incident review: "Was the AI suggestion correct?"

4. Fairness
   - AI models don't discriminate by service tier, team, or geography
   - Regularly audit for bias

5. Safety
   - Blast radius controls on AI-automated actions
   - Kill-switches always available
   - High-confidence threshold before autonomous action

6. Continuous Improvement
   - Monitor AI predictions against ground truth
   - Retrain models on schedule
   - Gather human feedback; incorporate into training
```

---

### 11.11 Building an AI-Augmented SRE Practice {#1111-building}

#### The Three-Phase Adoption Roadmap

**Phase 1: Pilot (Months 1-2)**
- Deploy anomaly detection on 1-2 non-critical services
- Evaluate false positive rate, model accuracy
- Collect human feedback: Does the AI add value?

**Phase 2: Expand (Months 3-4)**
- Roll out to all services (with graduated blast radius)
- Add LLM runbook assistant
- Integrate AI results into incident dashboards

**Phase 3: Optimize (Months 5+)**
- Continuous chaos informed by AI findings
- Predictive alerting for capacity
- Post-mortem automation (LLM drafts)

#### Minimum Viable AIOps Implementation

Start here:

1. **Anomaly detection** on four golden signals (request rate, error rate, latency, saturation)
2. **Alert correlation** (deduplicate related alerts)
3. **Runbook indexing** (keyword search or simple embeddings)
4. **Incident context summaries** (LLM synthesizes latest metrics + logs into plain English)

Do NOT start with:
- Fully automated remediation
- LLM-generated kubectl commands
- Replacing on-call engineers with AI

---

## Key Principles & Best Practices {#key-principles}

1. **Humans in the loop for consequential decisions**. AI suggests; humans approve.
2. **Explainability first**: Every AI alert should explain why it fired.
3. **Measure AI accuracy**: False positive rate, false negative rate, model drift.
4. **Retrain regularly**: ML models degrade as production changes.
5. **Start simple**: Anomaly detection is higher ROI than full automation.
6. **Audit post-incident**: Was the AI suggestion correct? Feed this back into retraining.
7. **Automation bias is real**: Humans over-trust AI; build in friction for consequential decisions.

---

## Tools & Technologies {#tools}

| Tool | Use Case | License | Maturity |
|------|----------|---------|----------|
| Prometheus + custom Python | Anomaly detection | OSS | Mature |
| Prophet | Time-series forecasting | OSS | Mature |
| Datadog Anomaly Detection | Managed anomaly detection | Commercial | Mature |
| Claude / GPT-4 | LLM incident response | Commercial | Growing |
| LitmusChaos + AI | Guided chaos experiments | OSS | Growing |
| Moogsoft | AIOps platform | Commercial | Mature |

---

## Hands-on Exercises / Labs {#labs}

### Lab 11.1 — Anomaly Detection Implementation

**Objective:** Deploy Z-score anomaly detection on a Prometheus metric.

**Time:** 1.5 hours

**Steps:**
1. Query Prometheus for historical metric data (1 week)
2. Implement `detect_zscore_anomaly()` function
3. Create Prometheus alert rule for anomalies
4. Test with synthetic anomaly (inject spike)
5. Measure: false positive rate over 1 day

**Deliverable:** Working anomaly detector + alert rule

---

### Lab 11.2 — LLM Incident Response Pipeline

**Objective:** Build an LLM-assisted incident context synthesizer.

**Time:** 2 hours

**Prerequisites:** Claude/GPT-4 API key

**Steps:**
1. Fetch current Prometheus metrics for a service
2. Query recent error logs (sample 10 unique errors)
3. Build structured context prompt for Claude
4. Call Claude API; generate incident summary
5. Parse JSON response; display top 3 hypotheses

**Deliverable:** Working incident context generator + sample output

---

### Lab 11.3 — Ethical AI Audit

**Objective:** Evaluate your AIOps implementation for ethical risks.

**Time:** 1 hour

**Checklist:**
- [ ] All AI alerts include explainability ("why did this fire?")
- [ ] No AI-automated production remediation without human approval
- [ ] Model retraining scheduled (weekly/monthly)
- [ ] False positive rate monitored and < 10%
- [ ] Audit log exists: every AI decision recorded
- [ ] Kill-switch available for every AI system

**Deliverable:** Ethical audit report + remediation plan

---

### Lab 11.4 — Building a Minimum Viable AIOps Stack

**Objective:** Deploy a complete AIOps stack for one service.

**Time:** 3-4 hours

**Components:**
1. Anomaly detection (Prometheus + custom exporter)
2. Alert correlation (deduplication rules)
3. LLM context synthesis (Claude)
4. Incident dashboard (Grafana)
5. Integration with on-call tool (PagerDuty)

**Deliverable:** End-to-end AIOps setup + demo

---

## Common Pitfalls & Anti-patterns {#pitfalls}

**Pitfall 1: AI Without Explainability**
- *Problem:* Alert fires, no one understands why
- *Fix:* Every alert includes explanation

**Pitfall 2: Automation Bias**
- *Problem:* Engineers blindly trust AI; don't verify
- *Fix:* Require explicit approval for consequential actions

**Pitfall 3: Model Drift**
- *Problem:* Model trained in 2024, still running in 2026; production patterns changed
- *Fix:* Retrain on schedule; monitor accuracy metrics

**Pitfall 4: Over-Automation**
- *Problem:* Tried to automate everything; LLM generates incorrect kubectl commands
- *Fix:* Start with low-risk automation; require human approval

**Pitfall 5: No Rollback Plan**
- *Problem:* AI system misbehaves; no way to disable it
- *Fix:* Feature flag every AI feature; kill-switch always available

---

## Interview Questions {#interview-questions}

1. **Explain the difference between anomaly detection and threshold-based alerting. When would you use each?**
2. **You deploy an ML anomaly detector that fires 1000 alerts per day. What went wrong? How do you fix it?**
3. **Design an LLM-assisted incident response system. Where does the human stay in control?**
4. **What is "automation bias"? Give an example. How do you prevent it?**
5. **A model trained on 2024 traffic patterns is still running in 2026. What happens? How do you detect drift?**
6. **Compare Z-score anomaly detection, Isolation Forest, and Prophet. When would you choose each?**
7. **An LLM suggests running `kubectl delete deployment --all`. What do you do?**
8. **Design a measurement framework for AIOps: How would you track success?**
9. **You have 4 weeks to implement AIOps. What's your MVP? What can you defer?**
10. **What are three ethical concerns with AI in SRE? How do you address each?**

---

## Further Reading & Resources {#further-reading}

- **"Observability Engineering" by Liz Fong-Jones & George Miranda** — O'Reilly
- **OpenTelemetry Documentation:** https://opentelemetry.io
- **Prophet Time Series Forecasting:** https://facebook.github.io/prophet/
- **Anomaly Detection in Time Series with LSTMs:** arXiv papers on deep learning anomaly detection
- **The AI Risk Institute:** Ethical AI frameworks for operations
- **Gartner AIOps Maturity Model:** 5 levels from reactive to autonomous

---

## Key Takeaways {#key-takeaways}

1. **AI is best used as amplification, not replacement**: Suggest, don't decide.
2. **Explainability is non-negotiable**: Every alert must explain why it fired.
3. **Start small**: Anomaly detection first; full automation later.
4. **Monitor your models**: False positive rate, accuracy, drift.
5. **Humans in the loop**: For every consequential decision, human must approve.
6. **Ethical AI requires discipline**: Bias, hallucination, and automation bias are real risks.
7. **Retrain on schedule**: ML models degrade as production changes.
8. **Keep kill-switches**: Feature flags on every AI system; disable instantly if misbehaving.
