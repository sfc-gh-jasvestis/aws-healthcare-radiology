# Demo Script: Radiology Analytics Command Center
## 3.5-Minute Recorded Walkthrough
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

## Narrative Arc: SLA Breach → Root Cause → Queue Triage → AI Extraction → Prediction

---

## Script

### [0:00–0:15] THE SLA CRISIS (Show: TAT Dashboard page)

> "Radiology turnaround time. The SLA says CT scans should be reported within 2 hours. We're averaging 285 minutes — that's 4 hours 45 minutes. 138% over target. MRI is borderline at 190 minutes. X-ray is the only modality meeting SLA. Something is systemically wrong with CT workflow."

### [0:15–0:35] TAT TREND (Show: TAT trend line chart)

> "The trend line confirms it's not a blip — CT has been deteriorating for weeks. The Dynamic Table refreshes every 5 minutes so we're looking at near real-time. No overnight batch jobs. The moment a report is finalized, the metric updates."

### [0:35–1:00] CRITICAL FINDINGS (Show: Critical Findings page)

> "Now the urgent problem. 847 unacknowledged critical findings. Pulmonary embolism, acute stroke, pneumothorax — these are life-threatening conditions waiting for communication. The queue shows severity, finding type, and time since detection. Every minute counts."

### [1:00–1:25] PRODUCTIVITY (Show: Productivity page)

> "Why is CT backed up? Radiologist productivity tells the story. Dr. Tanaka: 45 reads per day. Bottom performer: 13 reads per day. That's a 3.5x gap. Combined with the CT TAT chart, I can see which readers are creating the bottleneck and which need workload rebalancing."

### [1:25–1:50] AI EXTRACTION (Show: AI Summary page, click Extract)

> "Here's where AI accelerates the workflow. Click 'Extract Findings' — Cortex AI reads the full radiology report and returns structured JSON: modality, body part, findings array with types and descriptions, impression, critical flag, urgency level. This powers the automated triage queue — critical findings get flagged instantly without waiting for manual classification."

### [1:50–2:15] CORTEX ANALYST (Show: Ask Radiology page)

> "'What is the average TAT for CT this month?' — typed in plain English. Cortex Analyst generates the SQL, returns the answer. No BI team involved. The Chief Radiologist gets answers at the speed of thought."

### [2:15–2:40] FORECAST (Show: ML results available in the platform)

> "Snowflake ML FORECAST predicts study volume by modality for the next 14 days. If CT volume is about to spike — from seasonal pneumonia, for example — we know to staff additional CT readers before the queue backs up. Predictive staffing, not reactive firefighting."

### [2:40–3:10] AMAZON Q (Show: Switch to QuickSight)

> "The Hospital COO opens QuickSight. Amazon Q: 'What is the SLA breach rate for CT?' — instant answer from live Snowflake data. The COO sees the same metrics the radiologist sees, but through a strategic lens. Same governed data, different consumption pattern."

### [3:10–3:30] CLOSE

> "CT TAT at 285 minutes — detected automatically. 847 critical findings queued — prioritized by severity. AI extraction turning free-text reports into structured data in seconds. ML forecasting volume spikes before they happen. That's Radiology Analytics — Snowflake and AWS making the reading room smarter."

---

## Pre-Recording Checklist

- [ ] Open Streamlit: HEALTHCARE_RADIOLOGY.APP.RADIOLOGY_ANALYTICS_APP
- [ ] Verify TAT Dashboard shows CT at ~285 min
- [ ] Switch to Critical Findings — verify ~847 unacknowledged
- [ ] Switch to Productivity — verify Dr. Tanaka at top
- [ ] Test AI Summary extraction button
- [ ] Open QuickSight: https://us-west-2.quicksight.aws.amazon.com/sn/dashboards/hc-radiology-dashboard
- [ ] Test Q topic question: "What is the SLA breach rate for CT?"
