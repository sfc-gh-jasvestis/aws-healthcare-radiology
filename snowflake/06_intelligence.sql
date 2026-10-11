-- ============================================================================
-- 06_INTELLIGENCE.SQL - search, anomaly detection, semantic view, agent,
-- live study-status alert and on-demand refresh DAG.
-- Run with snowflake/run_intelligence.py (substitutes validated __DEMO_DB__ /
-- __DEMO_WH__ / __ALERT_EMAIL__). Requires 00-05, plus 08 (Snowflake only) or
-- aws/setup_aws.py (AWS build) for RAW.LIVE_STUDIES.
-- Alerts and tasks are created SUSPENDED; run them with EXECUTE ALERT / EXECUTE TASK.
-- ============================================================================
USE DATABASE __DEMO_DB__;
CREATE SCHEMA IF NOT EXISTS SEARCH;
CREATE SCHEMA IF NOT EXISTS APP;

-- ---------- Synthetic radiology workflow knowledge base (clearly synthetic SOPs) ----------
CREATE OR REPLACE TABLE SEARCH.DEPT_SOP_DOCS AS
WITH drivers AS (
  SELECT DISTINCT r.DELAY_DRIVER, s.CATEGORY
  FROM RAW.DEPT_DAILY r JOIN RAW.DEPARTMENTS s ON s.ID = r.ENTITY_ID
  WHERE r.BREACH_COUNT > 0
)
SELECT
  'SOP-' || LPAD(ROW_NUMBER() OVER (ORDER BY CATEGORY, DELAY_DRIVER)::VARCHAR, 3, '0') AS DOC_ID,
  'SOP' AS DOC_TYPE,
  CATEGORY,
  DELAY_DRIVER,
  CATEGORY || ' - ' || DELAY_DRIVER || ' turnaround breach follow-up' AS TITLE,
  'Synthetic demo SOP for radiology department operations; not clinical, diagnostic or regulatory guidance. Department type: ' || CATEGORY
  || '. Delay driver: ' || DELAY_DRIVER || '. '
  || 'Step 1: log the escalation in the department operations tracker and notify the duty radiology operations coordinator within 2 hours. '
  || 'Step 2: ' || CASE
       WHEN DELAY_DRIVER = 'Protocoling queue' THEN 'list priority requests waiting more than 1 hour for protocoling and reassign them to an available protocoling reader.'
       WHEN DELAY_DRIVER = 'Reader staffing gap' THEN 'compare the reading roster with the worklist by modality and request cover from the network reading pool.'
       WHEN DELAY_DRIVER = 'Prior image retrieval' THEN 'check the prior-image retrieval queue and raise a ticket with the PACS administrator for requests older than 30 minutes.'
       WHEN DELAY_DRIVER = 'Scanner downtime' THEN 'confirm the scanner downtime ticket with biomedical engineering and redirect priority bookings to another scanner of the same modality.'
       WHEN DELAY_DRIVER = 'Report sign-off' THEN 'list preliminary reports awaiting final sign-off for more than 4 hours and escalate them to the reporting lead.'
       ELSE 'review the flagged records against the department profile and escalate if unexplained.'
     END
  || ' Step 3: if the unread backlog stays above 15% of daily volume or average turnaround stays above 8 hours after follow-up, schedule a workflow review with the department manager. '
  || 'Step 4: record the root cause; if the breach is confirmed, open a breach review for the radiology operations lead to approve.' AS CONTENT
FROM drivers;

CREATE OR REPLACE CORTEX SEARCH SERVICE SEARCH.DEPT_SOP_SEARCH
  ON CONTENT
  ATTRIBUTES CATEGORY, DELAY_DRIVER
  WAREHOUSE = __DEMO_WH__
  TARGET_LAG = '7 days'
AS (SELECT DOC_ID, TITLE, CATEGORY, DELAY_DRIVER, CONTENT FROM SEARCH.DEPT_SOP_DOCS);

-- ---------- Report turnaround anomaly detection (train first 75 days, detect last 15) ----------
CREATE OR REPLACE VIEW ML.TAT_SERIES AS
SELECT ENTITY_ID, EVENT_DATE::TIMESTAMP_NTZ AS TS, TAT_HOURS::FLOAT AS TAT_HOURS
FROM RAW.DEPT_DAILY;
CREATE OR REPLACE VIEW ML.TAT_TRAIN AS
SELECT * FROM ML.TAT_SERIES WHERE TS < (SELECT DATEADD(day, -15, MAX(TS)) FROM ML.TAT_SERIES);
CREATE OR REPLACE VIEW ML.TAT_DETECT AS
SELECT * FROM ML.TAT_SERIES WHERE TS >= (SELECT DATEADD(day, -15, MAX(TS)) FROM ML.TAT_SERIES);

CREATE OR REPLACE SNOWFLAKE.ML.ANOMALY_DETECTION ML.TAT_ANOMALY_MODEL(
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'ML.TAT_TRAIN'),
  SERIES_COLNAME => 'ENTITY_ID', TIMESTAMP_COLNAME => 'TS', TARGET_COLNAME => 'TAT_HOURS',
  LABEL_COLNAME => '');

CREATE OR REPLACE TABLE ML.TAT_ANOMALIES AS
SELECT SERIES::VARCHAR AS ENTITY_ID, TS::DATE AS EVENT_DATE, Y AS TAT_HOURS, FORECAST AS EXPECTED,
       LOWER_BOUND, UPPER_BOUND, IS_ANOMALY, PERCENTILE
FROM TABLE(ML.TAT_ANOMALY_MODEL!DETECT_ANOMALIES(
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'ML.TAT_DETECT'),
  SERIES_COLNAME => 'ENTITY_ID', TIMESTAMP_COLNAME => 'TS', TARGET_COLNAME => 'TAT_HOURS'));

-- ---------- Semantic view ----------
CREATE OR REPLACE SEMANTIC VIEW APP.RADIOLOGY_OPS_ANALYTICS
  TABLES (
    depts AS CURATED.PERFORMANCE_SUMMARY PRIMARY KEY (ENTITY_ID)
      COMMENT = 'One row per imaging department, 90-day totals',
    risk AS ML.BREACH_RISK_SCORES PRIMARY KEY (ENTITY_ID)
      COMMENT = 'Latest next-7-day priority-study TAT breach probability per department',
    drivers AS CURATED.DRIVER_SUMMARY PRIMARY KEY (DELAY_DRIVER)
      COMMENT = 'Worklist escalations, confirmed TAT breaches and breach reviews by delay driver, 90 days',
    daily AS CURATED.TREND_ANALYSIS PRIMARY KEY (METRIC_DATE)
      COMMENT = 'Network-wide totals per day'
  )
  RELATIONSHIPS (risk_dept AS risk (ENTITY_ID) REFERENCES depts)
  FACTS (
    depts.completed_f AS COMPLETED_COUNT,
    depts.intarget_f AS IN_TARGET_COUNT,
    depts.target_f AS PLANNED_STUDIES_90D,
    depts.escalations_f AS ESCALATION_COUNT,
    depts.breaches_f AS BREACH_COUNT,
    depts.reviews_f AS REVIEW_COUNT,
    depts.qa_due_f AS QA_DUE,
    depts.qa_done_f AS QA_COMPLETED,
    risk.breach_prob_f AS BREACH_PROB_7D,
    drivers.type_signals_f AS ESCALATION_COUNT,
    drivers.type_confirmed_f AS BREACH_COUNT,
    drivers.type_capas_f AS REVIEW_COUNT,
    daily.day_completed_f AS COMPLETED_COUNT,
    daily.day_intarget_f AS IN_TARGET_COUNT,
    daily.day_escalations_f AS ESCALATION_COUNT
  )
  DIMENSIONS (
    depts.dept_id AS ENTITY_ID WITH SYNONYMS = ('department', 'entities', 'imaging department'),
    depts.dept_name AS ENTITY_NAME,
    depts.planning_area AS REGION WITH SYNONYMS = ('planning area', 'area', 'district', 'location') COMMENT = 'Singapore planning area where the department is located',
    depts.dept_type AS CATEGORY WITH SYNONYMS = ('department type', 'service line'),
    depts.service_tier AS SERVICE_TIER COMMENT = 'Service tier 1 (community) to 3 (tertiary)',
    risk.risk_band AS RISK_BAND COMMENT = 'High >= 0.5, Medium >= 0.25, else Low',
    risk.scored_as_of AS SCORED_AS_OF,
    drivers.delay_driver AS DELAY_DRIVER WITH SYNONYMS = ('driver', 'delay cause', 'bottleneck'),
    daily.metric_date AS METRIC_DATE
  )
  METRICS (
    depts.dept_count AS COUNT(depts.completed_f) WITH SYNONYMS = ('number of departments', 'entities count'),
    depts.total_in_target AS SUM(depts.intarget_f) WITH SYNONYMS = ('reports in target', 'on-time reports'),
    depts.total_completed AS SUM(depts.completed_f) WITH SYNONYMS = ('studies', 'study volume', 'exams'),
    depts.volume_vs_plan_pct AS 100 * SUM(depts.completed_f) / NULLIF(SUM(depts.target_f), 0)
      COMMENT = 'Studies completed / planned studies for the 90-day window',
    depts.outside_target_pct AS 100 * (SUM(depts.completed_f) - SUM(depts.intarget_f)) / NULLIF(SUM(depts.completed_f), 0)
      COMMENT = 'Reports finalised outside the TAT target / studies completed',
    depts.escalation_confirm_pct AS 100 * SUM(depts.breaches_f) / NULLIF(SUM(depts.escalations_f), 0)
      COMMENT = 'Confirmed priority TAT breaches / worklist escalations raised',
    depts.worklist_escalations AS SUM(depts.escalations_f) WITH SYNONYMS = ('escalations', 'flags'),
    depts.confirmed_breaches AS SUM(depts.breaches_f) WITH SYNONYMS = ('TAT breaches', 'turnaround breaches'),
    depts.reviews_opened AS SUM(depts.reviews_f) WITH SYNONYMS = ('breach reviews', 'reviews'),
    depts.qa_compliance_pct AS 100 * SUM(depts.qa_done_f) / NULLIF(SUM(depts.qa_due_f), 0)
      COMMENT = 'Scanner QA checks completed / QA checks due',
    risk.avg_breach_prob AS AVG(risk.breach_prob_f),
    drivers.type_escalations AS SUM(drivers.type_signals_f),
    drivers.type_breaches AS SUM(drivers.type_confirmed_f),
    drivers.type_reviews AS SUM(drivers.type_capas_f),
    drivers.type_confirmation_pct AS 100 * SUM(drivers.type_confirmed_f) / NULLIF(SUM(drivers.type_signals_f), 0),
    daily.daily_completed AS SUM(daily.day_completed_f),
    daily.daily_in_target AS SUM(daily.day_intarget_f),
    daily.daily_escalations AS SUM(daily.day_escalations_f)
  )
  COMMENT = 'Synthetic radiology department operations analytics (demo; no patient data)';

-- ---------- Cortex Agent ----------
CREATE OR REPLACE AGENT APP.RADIOLOGY_OPS_AGENT
  COMMENT = 'Radiology operations assistant over a synthetic Singapore imaging network'
  FROM SPECIFICATION
$$
models:
  orchestration: claude-sonnet-4-5
instructions:
  response: "Answer only from tool results. State that data is synthetic. Give department IDs and numbers with units. Do not give medical, diagnostic or clinical advice; this is operational data only."
  orchestration: "Use radiology_ops_analyst for study volume, turnaround in target, worklist escalations, confirmed TAT breaches, breach reviews, scanner QA compliance, departments, planning areas, department types and breach risk. Use sop_search for follow-up procedures."
tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: radiology_ops_analyst
      description: "Study volume vs plan, reports outside TAT target, worklist escalations, confirmed TAT breaches, breach reviews, scanner QA compliance, delay drivers and breach risk scores per department"
  - tool_spec:
      type: cortex_search
      name: sop_search
      description: "Synthetic radiology workflow SOPs by department type and delay driver"
tool_resources:
  radiology_ops_analyst:
    semantic_view: __DEMO_DB__.APP.RADIOLOGY_OPS_ANALYTICS
    execution_environment:
      type: warehouse
      warehouse: __DEMO_WH__
  sop_search:
    name: __DEMO_DB__.SEARCH.DEPT_SOP_SEARCH
    max_results: 3
    id_column: DOC_ID
    title_column: TITLE
$$;

-- ---------- Live study-status alert ----------
CREATE TABLE IF NOT EXISTS APP.ALERT_LOG (
  ALERTED_AT TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(), DEPT_ID VARCHAR,
  EVENT_TS TIMESTAMP_NTZ, WAIT_MINUTES FLOAT, TAT_HOURS FLOAT, SOP_HINT VARCHAR);

CREATE OR REPLACE NOTIFICATION INTEGRATION SG_HEALTHCARE_RADIOLOGY_EMAIL_INT
  TYPE = EMAIL ENABLED = TRUE ALLOWED_RECIPIENTS = ('__ALERT_EMAIL__');

CREATE OR REPLACE PROCEDURE APP.LOG_LIVE_ALERTS()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
  n NUMBER;
BEGIN
  INSERT INTO APP.ALERT_LOG (DEPT_ID, EVENT_TS, WAIT_MINUTES, TAT_HOURS, SOP_HINT)
    SELECT v.DEPT_ID, v.EVENT_TS, v.WAIT_MINUTES, v.TAT_HOURS,
           'Check ' || s.CATEGORY || ' follow-up SOPs; current risk band ' || COALESCE(r.RISK_BAND, 'n/a')
    FROM RAW.LIVE_STUDIES v
    JOIN RAW.DEPARTMENTS s ON s.ID = v.DEPT_ID
    LEFT JOIN ML.BREACH_RISK_SCORES r ON r.ENTITY_ID = v.DEPT_ID
    WHERE v.STATUS = 'ALERT'
      AND NOT EXISTS (SELECT 1 FROM APP.ALERT_LOG l WHERE l.DEPT_ID = v.DEPT_ID AND l.EVENT_TS = v.EVENT_TS);
  n := SQLROWCOUNT;
  IF (n > 0) THEN
    CALL SYSTEM$SEND_EMAIL('SG_HEALTHCARE_RADIOLOGY_EMAIL_INT', '__ALERT_EMAIL__',
      '[Demo] Radiology operations alert',
      'New study-status alerts logged in APP.ALERT_LOG: ' || :n || '. Data is synthetic.');
  END IF;
  RETURN n;
END;
$$;

CREATE OR REPLACE ALERT APP.LIVE_STUDY_ALERT
  WAREHOUSE = __DEMO_WH__
  SCHEDULE = '5 MINUTE'
  IF (EXISTS (
    SELECT 1 FROM RAW.LIVE_STUDIES v
    WHERE v.STATUS = 'ALERT'
      AND NOT EXISTS (SELECT 1 FROM APP.ALERT_LOG l WHERE l.DEPT_ID = v.DEPT_ID AND l.EVENT_TS = v.EVENT_TS)))
  THEN CALL APP.LOG_LIVE_ALERTS();

-- ---------- On-demand refresh DAG (suspended; run with EXECUTE TASK APP.TASK_REFRESH_CURATED) ----------
CREATE OR REPLACE PROCEDURE APP.REFRESH_CURATED()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN
  ALTER DYNAMIC TABLE CURATED.PERFORMANCE_SUMMARY REFRESH;
  ALTER DYNAMIC TABLE CURATED.TREND_ANALYSIS REFRESH;
  ALTER DYNAMIC TABLE CURATED.DRIVER_SUMMARY REFRESH;
  ALTER DYNAMIC TABLE CURATED.KPI_SUMMARY REFRESH;
  RETURN 'refreshed';
END;
$$;

CREATE OR REPLACE TASK APP.TASK_REFRESH_CURATED
  WAREHOUSE = __DEMO_WH__
AS
  CALL APP.REFRESH_CURATED();

CREATE OR REPLACE TASK APP.TASK_RESCORE_RISK
  WAREHOUSE = __DEMO_WH__
  AFTER APP.TASK_REFRESH_CURATED
AS
  CREATE OR REPLACE TABLE ML.BREACH_RISK_SCORES COPY GRANTS AS
  WITH latest AS (
    SELECT * FROM ML.BREACH_FEATURES QUALIFY ROW_NUMBER() OVER (PARTITION BY ENTITY_ID ORDER BY EVENT_DATE DESC) = 1
  ), p AS (
    SELECT ENTITY_ID, EVENT_DATE,
           ML.BREACH_RISK_MODEL!PREDICT(INPUT_DATA => OBJECT_CONSTRUCT(
             'CATEGORY', CATEGORY, 'SERVICE_TIER', SERVICE_TIER, 'READER_FTE', READER_FTE,
             'TAT_HOURS', TAT_HOURS, 'BACKLOG_STUDIES', BACKLOG_STUDIES,
             'TAT_7D', TAT_7D, 'BREACH_30D', BREACH_30D)) AS PRED
    FROM latest
  )
  SELECT ENTITY_ID, EVENT_DATE AS SCORED_AS_OF, ROUND(PRED:probability:BREACH::FLOAT, 4) AS BREACH_PROB_7D,
         CASE WHEN PRED:probability:BREACH::FLOAT >= 0.5 THEN 'High'
              WHEN PRED:probability:BREACH::FLOAT >= 0.25 THEN 'Medium' ELSE 'Low' END AS RISK_BAND,
         CURRENT_TIMESTAMP() AS SCORED_AT
  FROM p;
