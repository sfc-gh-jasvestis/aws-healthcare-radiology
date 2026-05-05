# Demo Script: Radiology Analytics Command Center
## 4-Minute Recorded Walkthrough
**Format**: Screen recording with voiceover
**Target**: AWS Summit booth / customer meeting

---

## The Story

A Chief Radiologist discovers CT turnaround time has blown past SLA — averaging 285 minutes against a 120-minute target. 847 critical findings sit unacknowledged. Using the Radiology Analytics platform, they identify the bottleneck, track productivity, and use AI to extract structured findings from reports.

---

## Two Personas

| Persona | Tool | What they care about |
|---|---|---|
| **Chief Radiologist** | Streamlit in Snowflake | TAT, critical findings queue, reader productivity |
| **Hospital COO** | Amazon QuickSight + Amazon Q | SLA compliance trends, volume planning, resource allocation |

---

## Narrative Arc: Architecture → SLA Breach → Root Cause → Queue Triage → AI Extraction → Prediction

---

## Script

### [0:00–0:10] OPEN — ARCHITECTURE (Show: README.md in VS Code / GitHub, scroll to architecture diagram)

> "Let's look at what we've built. This is the Radiology Analytics platform — end-to-end on Snowflake with AWS integration. At the bottom, S3 ingestion and Bedrock for report extraction. Raw data flows through Dynamic Tables into three curated views: turnaround time, critical findings queue, and radiologist productivity. On top of that, ML models for forecasting, Cortex Search over clinical guidelines, and a Semantic View — all unified by a Cortex Agent. The Streamlit app sits on top for the clinical team."

### [0:10–0:20] PERSONAS (Show: Scroll to Personas table in README)

> "Two personas. The Chief Radiologist — Dr. Tanaka — manages 50 readers, monitors SLA compliance, triages critical findings. The Hospital COO tracks department KPIs and forecasts capacity. Same governed data, different consumption patterns — Streamlit for clinical, QuickSight for executive."

### [0:20–0:30] DATA SCALE & CAPABILITIES (Show: Scroll to Data Scale and Capabilities sections)

> "50,000 studies, 44,000 reports, 3,000 critical findings, 80 clinical guidelines indexed for search. Eight capabilities — from real-time TAT monitoring to anomaly detection to conversational AI. All running continuously through Dynamic Tables with no batch orchestration."

### [0:30–0:40] DEMO NARRATIVE (Show: Scroll to Demo Narrative section)

> "The story: CT turnaround time is in crisis. 285 minutes average against a 120-minute SLA. 847 critical findings sitting unacknowledged. Let's see it live."

### [0:40–0:55] THE SLA CRISIS (Show: Switch to Streamlit — TAT Dashboard page)

> "Here's the dashboard. CT at 285 minutes — 138% over SLA target. MRI borderline at 190 minutes against 180. X-ray is the only modality meeting its target. Something is systemically broken in the CT workflow."

### [0:55–1:15] TAT TREND (Show: TAT trend line chart)

> "The trend line confirms it's not a blip — CT has been deteriorating for weeks. The Dynamic Table refreshes every 5 minutes so we're looking at near real-time. No overnight batch jobs. The moment a report is finalized, the metric updates."

### [1:15–1:40] CRITICAL FINDINGS (Show: Critical Findings page)

> "Now the urgent problem. 847 unacknowledged critical findings. Pulmonary embolism, acute stroke, pneumothorax — these are life-threatening conditions waiting for communication. The queue shows severity, finding type, and time since detection. Every minute counts."

### [1:40–2:05] PRODUCTIVITY (Show: Productivity page)

> "Why is CT backed up? Radiologist productivity tells the story. Dr. Tanaka: 45 reads per day. Bottom performers like Dr. Taylor: just 4-5 reads per day. That's a 10x productivity gap. Combined with the CT TAT chart, I can see which readers are creating the bottleneck and which need workload rebalancing."

### [2:05–2:30] AI EXTRACTION (Show: AI Summary page, click Extract)

> "Here's where AI accelerates the workflow. Click 'Extract Findings' — Cortex AI reads the full radiology report and returns structured JSON: modality, body part, findings array with types and descriptions, impression, critical flag, urgency level. This powers the automated triage queue — critical findings get flagged instantly without waiting for manual classification."

### [2:30–2:55] CORTEX ANALYST (Show: Ask Radiology page)

> "'What is the average TAT for CT this month?' — typed in plain English. Cortex Analyst generates the SQL, returns the answer. No BI team involved. The Chief Radiologist gets answers at the speed of thought."

### [2:55–3:15] FORECAST (Show: Forecast page in Streamlit — CT selected)

> "Snowflake ML FORECAST predicts TAT by modality for the next 30 days. The red dashed line is the prediction, the shaded band is the 95% confidence interval, and the green dotted line is the SLA target. CT stays well above SLA for the foreseeable future — this isn't going to fix itself. If volume spikes from seasonal pneumonia, it gets worse. Predictive staffing, not reactive firefighting."

### [3:15–3:40] AMAZON Q (Show: Switch to QuickSight)

> "The Hospital COO opens QuickSight. Amazon Q: 'Which modalities are breaching SLA and by how much?' — instant answer from live Snowflake data. The COO sees the same metrics the radiologist sees, but through a strategic lens. Same governed data, different consumption pattern."

### [3:40–4:00] CLOSE

> "We started with the architecture — S3 ingestion, Dynamic Tables, ML, Cortex AI — then saw it in action. CT TAT at 285 minutes — detected automatically. 847 critical findings queued by severity. AI extraction turning free-text into structured data in seconds. ML forecasting volume spikes before they happen. That's Radiology Analytics — Snowflake and AWS making the reading room smarter."

---

## Pre-Recording Checklist

- [ ] Open README.md in VS Code (or GitHub) — verify architecture diagram renders correctly
- [ ] Scroll: Architecture → Personas → Data Scale → Capabilities → Demo Narrative
- [ ] Open Streamlit: HEALTHCARE_RADIOLOGY.APP.RADIOLOGY_ANALYTICS_APP
- [ ] Verify TAT Dashboard shows CT at ~285 min
- [ ] Switch to Critical Findings — verify ~847 unacknowledged
- [ ] Switch to Productivity — verify Dr. Tanaka at top (~45 avg reads/day)
- [ ] Test AI Summary extraction button
- [ ] Open QuickSight: https://us-west-2.quicksight.aws.amazon.com/sn/dashboards/hc-radiology-dashboard
- [ ] Test Q topic question: "Which modalities are breaching SLA and by how much?"
