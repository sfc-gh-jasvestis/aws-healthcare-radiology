# Radiology Department Operations

**Singapore - Harbourline Imaging (fictional)**
Use case: Report turnaround, backlog and priority-study breach risk

> Operations for 40 imaging departments of Harbourline Imaging, a fictional Singapore imaging network across 5 planning areas: dynamic tables, a holdout-evaluated TAT breach classifier, a reporting forecast and grounded AI answers. Synthetic, department-level data only; no patient records, images or report text.

## Why Snowflake

- **Dynamic tables** reconcile study volume against plan, reports outside the TAT target, worklist escalations, confirmed breaches and scanner QA compliance from RAW department data, with checks in `run_core.py`
- **TAT breach classification** gives a holdout-evaluated next-7-day probability per department
- **Reporting forecast** projects 14 days of reports finalised in target with prediction intervals, for reader capacity planning
- **Grounded AI**: the Cortex Agent (Analyst over a semantic view, plus Search over SOPs) shows its SQL and SOP citations
- **Live study status**: a native simulator (Snowflake only) or Amazon Data Firehose, S3 and Snowpipe (AWS build), then an alert and email

## What is built

| | |
|---|---|
| Dimension table | `RAW.DEPARTMENTS` (40 rows) |
| Fact table | `RAW.DEPT_DAILY` (3,600 department-days, 90 days) |
| Curated layer | `CURATED.KPI_SUMMARY`, `PERFORMANCE_SUMMARY`, `DRIVER_SUMMARY`, `TREND_ANALYSIS` |
| ML | `ML.BREACH_RISK_SCORES`, `ML.BREACH_RISK_HOLDOUT_METRICS`, `ML.VOLUME_FORECAST`, `ML.TAT_ANOMALIES` |

Planning areas: Novena, Jurong East, Tampines, Queenstown, Woodlands (8 departments each).
Department types: Emergency, Inpatient, Outpatient, Cancer centre, Community.

## KPI cards (live from `CURATED.KPI_SUMMARY`; no fallback values)

| Card | Value from the seeded data |
|---|---|
| Study Volume vs Plan | 100.2% |
| Studies Completed | 277,237 |
| Reports Outside TAT Target | 17.6% |
| Escalation Confirmation Rate | 38.3% |
| Worklist Escalations | 666 |
| Confirmed Priority TAT Breaches | 255 |
| Breach Reviews Opened | 125 |
| Scanner QA Compliance | 77.0% |
| Departments Active | 40 |
| Scanner QA Certification | 56.6% |
| Scanner Certifications Pending | 25 |
| Average Report TAT (hours) | 6 (5.7 before rounding) |
| Unread Backlog (study-days) | 35,224 |

Values are synthetic. A rebuild reproduces them because the data is HASH-seeded; dates are relative to the build day, so forecast and anomaly figures can shift slightly.

## Demo flow

1. Executive Cockpit: KPIs, daily studies against worklist escalations, escalations and confirmed breaches by delay driver, department table with planning area
2. Predictive: holdout metrics, risk bands, 14-day reporting forecast, report turnaround anomalies
3. Workflow Risk: scanner QA compliance, certification coverage and pending certifications, QA compliance against confirmed breaches, then generate the action memo
4. Live Studies: run `CALL APP.SIMULATE_STUDIES(20)` (Snowflake only) or `python aws/publish_studies.py --count 20` (AWS build). Then run `EXECUTE ALERT APP.LIVE_STUDY_ALERT` and show the alert log and email.
5. Ask AI: the Cortex Agent answers metric questions through the semantic view and cites SOPs from Cortex Search. The SQL is shown. Try "What is study volume vs plan by planning area?"
6. QuickSight (AWS build): the same Snowflake tables through DIRECT_QUERY
7. Architecture: both builds side by side

## Talking points

- Harbourline Imaging is at 100.2% of its 90-day study plan, yet 5 departments are below 95% of plan and 17.6% of reports are finalised outside the TAT target.
- About two worklist escalations in five are confirmed as priority-study TAT breaches (38.3%). The protocoling queue produces the most confirmed breaches (79). Jurong East has the most confirmed breaches of the 5 planning areas (70) and Tampines the fewest (33).
- The two area PACS outages (Jurong East and Woodlands) hit every department in the planning area at once; their 16 escalations are never confirmed, and they are excluded from model training because they are not department-driven.
- The risk model is evaluated on a time-based holdout: precision 0.46 and recall 0.61 at 0.5, against a 0.29 base rate. Present it as triage for workflow effort, not a verdict on a department.
- This is operational data only. It makes no diagnostic, clinical-accuracy, medical-efficacy or regulatory claims and contains no patient records or images.

## Business impact

Use only the sourced references in `README.md` (Business Impact).
