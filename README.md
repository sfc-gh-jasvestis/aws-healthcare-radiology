# Radiology Analytics & Medical NLP

End-to-end healthcare radiology analytics platform — turnaround time monitoring, critical findings management, AI-powered report extraction, and ML forecasting for capacity planning.

## Architecture

A radiology analytics and medical NLP platform built on **Snowflake** (Dynamic Tables, ML.FORECAST, ML.ANOMALY_DETECTION, Cortex Search, semantic view, Cortex Agent) and **AWS** (S3, Bedrock Claude, QuickSight + Amazon Q). Studies and reports land in S3; Bedrock extracts critical findings; Snowflake monitors TAT, productivity, and forecasts modality volume.

```mermaid
flowchart LR
    S3[S3 sg-healthcare-demos-2026 / radiology] --> SF[Snowflake RAW STUDIES / REPORTS / RADIOLOGISTS / CRITICAL_FINDINGS / EQUIPMENT / GUIDELINES]
    SF --> EAI[External Access SigV4]
    EAI --> BR[Amazon Bedrock Claude report extraction]
    BR --> SF
    SF --> DT[Dynamic Tables TAT_METRICS / CRITICAL_FINDINGS_QUEUE / RADIOLOGIST_PRODUCTIVITY]
    DT --> ML[ML.FORECAST + ML.ANOMALY_DETECTION]
    DT --> CSearch[Cortex Search guidelines]
    DT --> SemView[Semantic View]
    DT --> AGT[Cortex Agent RadiologyAnalyst + GuidelinesSearch]
    DT --> ST[Streamlit TAT / Critical Findings / Productivity / Forecast / AI]
    DT --> QS[QuickSight TAT + Critical Findings + Amazon Q]
```

## Snowflake Capabilities

| Capability | Implementation |
|-----------|---------------|
| Dynamic Tables | TAT_METRICS / CRITICAL_FINDINGS_QUEUE / RADIOLOGIST_PRODUCTIVITY |
| ML Functions | ML.FORECAST modality volume + ML.ANOMALY_DETECTION TAT outliers |
| Cortex Search | 80 radiology clinical guidelines indexed |
| Cortex Agent | RadiologyAnalyst + GuidelinesSearch tools |
| Semantic View | Structured analytics over TAT, findings, productivity |
| Streamlit | 6-page dashboard: TAT / Critical / Productivity / Forecast / AI / Ask |

## AWS Services

| Service | Role in Demo |
|---------|-------------|
| Amazon S3 | Storage for radiology studies and report feeds |
| Amazon Bedrock | Claude-powered report extraction and NLP analysis |
| Amazon QuickSight | Executive TAT and critical findings dashboard |
| Amazon Q | Natural language analytics for Hospital COO |

## Personas

| Persona | Role | Key Questions |
|---------|------|---------------|
| **Dr. Tanaka** | Chief Radiologist — oversees 50 radiologists | "Which modalities are breaching SLA?" "Show unacknowledged critical findings." |
| **Hospital COO** | Operations executive — tracks department KPIs | "Forecast CT volume next 30 days." "Which radiologists are below productivity targets?" |

## Data

| Table | Rows | Description |
|-------|------|-------------|
| STUDIES | 50,000 | Radiology studies across CT, MRI, X-Ray, Ultrasound, PET |
| REPORTS | 44,000 | Structured radiology reports with findings |
| RADIOLOGISTS | 50 | Named readers (Dr. Tanaka, Dr. Patel, Dr. Smith, etc.) |
| CRITICAL_FINDINGS | 3,000 | Urgent findings requiring acknowledgment |
| EQUIPMENT | 30 | Scanners and imaging devices |
| RADIOLOGY_GUIDELINES | 80 | Clinical guidelines for Cortex Search |

## Build Instructions

### Prerequisites
- Snowflake account with ACCOUNTADMIN access
- Cortex AI enabled (ML Functions, Search, Agent)
- Warehouse: CORTEX (Medium)
- AWS CLI with Bedrock, QuickSight access

### Deployment

```bash
snowsql -f snowflake/00_setup.sql
snowsql -f snowflake/01_integrations.sql
snowsql -f snowflake/02_raw_tables.sql
snowsql -f snowflake/03_curated.sql
snowsql -f snowflake/04_search.sql
snowsql -f snowflake/05_ml.sql
snowsql -f snowflake/06_semantic.sql
snowsql -f snowflake/07_agent.sql
snowsql -f snowflake/08_ai_extraction.sql
```

### Streamlit App
```
HEALTHCARE_RADIOLOGY.APP.RADIOLOGY_ANALYTICS_APP
```

## Build Modes

### Snowflake Only
Run the SQL scripts in `snowflake/` (skip `01_integrations.sql`) and deploy the Streamlit app from `streamlit/deploy/`. Uses Cortex AI instead of Bedrock, and Snowflake Intelligence instead of QuickSight.

### Full AWS + Snowflake
Run all SQL scripts including `01_integrations.sql`, deploy the main Streamlit app from `streamlit/`, then run the QuickSight setup from `quicksight/`.

## Business Impact

Industry research and Snowflake customer outcomes:
- **AI-assisted radiology** reduces report turnaround time by 30-50% -- Multiple peer-reviewed studies
- **Unread study backlogs** cost hospitals $1.5M/year in delayed diagnoses and liability -- ACR estimates
- **Critical finding notification time** reduced 60% with AI prioritization -- Industry benchmark
- **ML forecasting** enables proactive staffing decisions, reducing overtime costs 20-30% -- Industry
- **AMN Healthcare** reduced data lake costs by 93% ($2.2M/year savings) while storing 50% more data on Snowflake -- [snowflake.com/customers/amn-healthcare](https://www.snowflake.com/en/customers/all-customers/case-study/amn-healthcare/)

## Key Demo Numbers

- **CT turnaround** averages 285 minutes (SLA is 120 minutes)
- **847 critical findings** unacknowledged
- **Dr. Tanaka** — 45 reads/day (top performer)
- **ML forecast** justifies hiring 3 additional radiologists

## License

Apache 2.0 — See [LICENSE](LICENSE) for details.

This is a personal demo project and is not an official Snowflake offering. It comes with no support or warranty. Industry metrics cited are from publicly available third-party research and Snowflake customer stories; they represent reported outcomes and are not guarantees of results.
