-- Synthetic department-day operations data for a fictional Singapore imaging network.
-- Department-level aggregate counts only: there are no patient records, no
-- images, no report text and no clinical findings. Nothing is seeded as a
-- prediction. Randomness is HASH-seeded, so every rebuild is reproducible:
-- per-department breach propensity, drift between scanner QA checks, missed QA
-- checks, department-type-weighted delay drivers, worklist escalations that are
-- cleared on review, and two area-wide PACS outages.
USE DATABASE IDENTIFIER($DEMO_DB);
USE SCHEMA RAW;
USE WAREHOUSE IDENTIFIER($DEMO_WH);

CREATE TABLE RAW.DEPARTMENTS AS
WITH depts AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS DEPT_INDEX
  FROM TABLE(GENERATOR(ROWCOUNT => 40))
), draws AS (
  SELECT DEPT_INDEX,
         MOD(ABS(HASH(DEPT_INDEX, 'sg-rad-staffing')), 1000000) / 1e6 AS U_STAFF,
         MOD(ABS(HASH(DEPT_INDEX, 'sg-rad-breach')), 1000000) / 1e6 AS U_RATE,
         MOD(ABS(HASH(DEPT_INDEX, 'sg-rad-qa interval')), 1000000) / 1e6 AS U_QA,
         MOD(ABS(HASH(DEPT_INDEX, 'sg-rad-discipline')), 1000000) / 1e6 AS U_DISCIPLINE,
         MOD(ABS(HASH(DEPT_INDEX, 'sg-rad-tier')), 1000000) / 1e6 AS U_TIER,
         MOD(ABS(HASH(DEPT_INDEX, 'sg-rad-volume')), 1000000) / 1e6 AS U_VOLUME,
         MOD(ABS(HASH(DEPT_INDEX, 'sg-rad-plan')), 1000000) / 1e6 AS U_PLAN
  FROM depts
), sized AS (
  SELECT *,
         -- Deterministic spread (5 and 8 are coprime): every planning area and
         -- department type is present.
         CASE MOD(DEPT_INDEX, 5) WHEN 0 THEN 'Novena' WHEN 1 THEN 'Jurong East'
              WHEN 2 THEN 'Tampines' WHEN 3 THEN 'Queenstown' ELSE 'Woodlands' END AS REGION,
         CASE MOD(DEPT_INDEX, 8) WHEN 0 THEN 'Emergency' WHEN 1 THEN 'Emergency' WHEN 2 THEN 'Emergency'
              WHEN 3 THEN 'Inpatient' WHEN 4 THEN 'Inpatient' WHEN 5 THEN 'Outpatient'
              WHEN 6 THEN 'Cancer centre' ELSE 'Community' END AS CATEGORY,
         -- Mean imaging studies completed per day in the department.
         30 + U_VOLUME * 90 AS STUDY_RATE
  FROM draws
)
SELECT 'DEPT-' || LPAD(DEPT_INDEX::VARCHAR, 4, '0') AS ID,
       'Synthetic imaging department ' || LPAD(DEPT_INDEX::VARCHAR, 4, '0') AS NAME,
       REGION, CATEGORY, DEPT_INDEX,
       1 + FLOOR(U_TIER * 3) AS SERVICE_TIER,
       ROUND(2 + U_STAFF * 10, 1) AS READER_FTE,
       STUDY_RATE,
       -- Planned study volume for the 90-day window (synthetic capacity plan).
       ROUND(STUDY_RATE * 90 * (0.92 + 0.16 * U_PLAN)) AS PLANNED_STUDIES_90D,
       -- Base daily probability of a confirmed priority-study turnaround breach
       -- 0.4%-3%; ~15% of departments are persistent outliers (x3).
       (0.004 + U_RATE * 0.026) * IFF(U_RATE > 0.85, 3, 1) AS BASE_BREACH_RATE,
       7 * (1 + FLOOR(U_QA * 3)) AS QA_INTERVAL_DAYS,
       0.55 + U_DISCIPLINE * 0.45 AS QA_COMPLETION_PROB,
       'Active' AS STATUS
FROM sized;

CREATE TABLE RAW.DEPT_DAILY AS
WITH days AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS DAY_INDEX
  FROM TABLE(GENERATOR(ROWCOUNT => 90))
), regional_events AS (
  -- Two area PACS outages; every department in the planning area raises an escalation.
  SELECT * FROM VALUES (27, 'Jurong East'), (64, 'Woodlands') AS o(DAY_INDEX, REGION)
), base AS (
  SELECT d0.ID AS ENTITY_ID, d0.DEPT_INDEX, d0.CATEGORY, d0.REGION, d0.READER_FTE, d0.STUDY_RATE,
         d0.BASE_BREACH_RATE, d0.QA_INTERVAL_DAYS, d0.QA_COMPLETION_PROB,
         d.DAY_INDEX,
         DATEADD('day', d.DAY_INDEX - 89, CURRENT_DATE()) AS EVENT_DATE,
         MOD(d.DAY_INDEX + d0.DEPT_INDEX * 5, d0.QA_INTERVAL_DAYS) AS DAYS_SINCE_QA,
         MOD(ABS(HASH(d0.ID, d.DAY_INDEX, 'sg-rad-breach')), 1000000) / 1e6 AS U_BREACH,
         MOD(ABS(HASH(d0.ID, d.DAY_INDEX, 'sg-rad-detect')), 1000000) / 1e6 AS U_DETECT,
         MOD(ABS(HASH(d0.ID, d.DAY_INDEX, 'sg-rad-cleared')), 1000000) / 1e6 AS U_FP,
         MOD(ABS(HASH(d0.ID, d.DAY_INDEX, 'sg-rad-driver')), 1000000) / 1e6 AS U_DRIVER,
         MOD(ABS(HASH(d0.ID, d.DAY_INDEX, 'sg-rad-qa check')), 1000000) / 1e6 AS U_DONE,
         MOD(ABS(HASH(d0.ID, d.DAY_INDEX, 'sg-rad-completed')), 1000000) / 1e6 AS U_COMPLETED,
         MOD(ABS(HASH(d0.ID, d.DAY_INDEX, 'sg-rad-in target')), 1000000) / 1e6 AS U_IN_TARGET,
         MOD(ABS(HASH(d0.ID, d.DAY_INDEX, 'sg-rad-noise')), 1000000) / 1e6 AS U_NOISE,
         MOD(ABS(HASH(d0.ID, d.DAY_INDEX, 'sg-rad-review')), 1000000) / 1e6 AS U_REVIEW,
         e.REGION IS NOT NULL AS REGIONAL_EVENT
  FROM RAW.DEPARTMENTS d0 CROSS JOIN days d
  LEFT JOIN regional_events e ON e.DAY_INDEX = d.DAY_INDEX AND e.REGION = d0.REGION
), qa AS (
  SELECT *,
         IFF(DAYS_SINCE_QA = 0, 1, 0) AS QA_DUE,
         IFF(DAYS_SINCE_QA = 0 AND U_DONE < QA_COMPLETION_PROB, 1, 0) AS QA_COMPLETED,
         -- Workflow drift rises between QA checks; weak follow-through carries it over.
         DAYS_SINCE_QA / QA_INTERVAL_DAYS + (1 - QA_COMPLETION_PROB) AS DRIFT
  FROM base
), breaches AS (
  SELECT *,
         CASE WHEN U_BREACH < LEAST(0.5, BASE_BREACH_RATE * (0.4 + 1.6 * DRIFT) * (1 + 4 / (1 + READER_FTE))) / 4 THEN 2
              WHEN U_BREACH < LEAST(0.5, BASE_BREACH_RATE * (0.4 + 1.6 * DRIFT) * (1 + 4 / (1 + READER_FTE))) THEN 1
              ELSE 0 END AS BREACH_EVENTS
  FROM qa
), escalations AS (
  SELECT *,
         -- Worklist monitoring escalates about 85% of priority-study breaches.
         IFF(REGIONAL_EVENT, 0, IFF(U_DETECT < 0.85, BREACH_EVENTS, 0)) AS BREACH_COUNT,
         -- Escalations cleared on review: higher where the worklist is busiest.
         IFF(REGIONAL_EVENT, 1, IFF(U_FP < CASE CATEGORY WHEN 'Emergency' THEN 0.14
                                                         WHEN 'Inpatient' THEN 0.10
                                                         WHEN 'Cancer centre' THEN 0.10 ELSE 0.08 END, 1, 0)) AS CLEARED_COUNT,
         FLOOR(STUDY_RATE * (0.6 + 0.8 * U_COMPLETED) + 0.5) AS COMPLETED_COUNT
  FROM breaches
)
SELECT ENTITY_ID || '-' || TO_CHAR(EVENT_DATE, 'YYYYMMDD') AS EVENT_ID,
       ENTITY_ID, EVENT_DATE,
       COMPLETED_COUNT,
       -- Reports finalised within the department's turnaround target.
       FLOOR(COMPLETED_COUNT * LEAST(0.97, 0.80 + 0.15 * U_IN_TARGET - 0.06 * DRIFT - 0.08 * BREACH_EVENTS)) AS IN_TARGET_COUNT,
       BREACH_COUNT + CLEARED_COUNT AS ESCALATION_COUNT,
       BREACH_COUNT,
       IFF(BREACH_COUNT > 0 AND U_REVIEW < 0.6, 1, 0) AS REVIEW_OPENED,
       CASE WHEN BREACH_COUNT + CLEARED_COUNT = 0 THEN 'None'
            WHEN REGIONAL_EVENT THEN 'Area PACS outage'
            WHEN CATEGORY = 'Emergency' THEN IFF(U_DRIVER < 0.4, 'Reader staffing gap', IFF(U_DRIVER < 0.75, 'Scanner downtime', 'Protocoling queue'))
            WHEN CATEGORY = 'Inpatient' THEN IFF(U_DRIVER < 0.45, 'Protocoling queue', IFF(U_DRIVER < 0.8, 'Prior image retrieval', 'Report sign-off'))
            WHEN CATEGORY = 'Outpatient' THEN IFF(U_DRIVER < 0.55, 'Protocoling queue', 'Scanner downtime')
            WHEN CATEGORY = 'Cancer centre' THEN IFF(U_DRIVER < 0.45, 'Prior image retrieval', IFF(U_DRIVER < 0.8, 'Protocoling queue', 'Reader staffing gap'))
            ELSE IFF(U_DRIVER < 0.5, 'Report sign-off', IFF(U_DRIVER < 0.75, 'Protocoling queue', 'Reader staffing gap')) END AS DELAY_DRIVER,
       QA_DUE, QA_COMPLETED,
       -- Median report turnaround (hours) and unread worklist backlog at day end.
       ROUND(3.0 + 2.5 * DRIFT + 4.0 * BREACH_EVENTS + U_NOISE * 1.5, 2) AS TAT_HOURS,
       ROUND(STUDY_RATE * (0.04 + 0.08 * DRIFT + 0.12 * BREACH_EVENTS) + U_NOISE * 4) AS BACKLOG_STUDIES,
       CURRENT_TIMESTAMP() AS LOADED_AT
FROM escalations;

-- Scanner fleet and QA certification per department (snapshot, synthetic).
CREATE TABLE RAW.SCANNER_FLEET AS
SELECT ID AS ENTITY_ID,
       CASE CATEGORY WHEN 'Emergency' THEN 'CT' WHEN 'Inpatient' THEN 'MRI'
                     WHEN 'Outpatient' THEN 'Ultrasound'
                     WHEN 'Cancer centre' THEN 'PET-CT' ELSE 'X-ray' END AS MODALITY,
       1 + MOD(ABS(HASH(ID, 'sg-rad-installed')), 4) AS SCANNERS_INSTALLED,
       LEAST(MOD(ABS(HASH(ID, 'sg-rad-certified')), 5), 1 + MOD(ABS(HASH(ID, 'sg-rad-installed')), 4)) AS QA_CERTIFIED,
       IFF(MOD(ABS(HASH(ID, 'sg-rad-certified')), 5) < 1 + MOD(ABS(HASH(ID, 'sg-rad-installed')), 4),
           MOD(ABS(HASH(ID, 'sg-rad-pending')), 3), 0) AS CERT_PENDING,
       CURRENT_DATE() AS SNAPSHOT_DATE
FROM RAW.DEPARTMENTS;
