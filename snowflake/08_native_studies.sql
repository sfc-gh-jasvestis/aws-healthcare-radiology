-- ============================================================================
-- 08_native_studies.sql - Snowflake-only build: live study-status feed without AWS.
-- Creates RAW.LIVE_STUDIES (same columns as the Snowpipe target created by
-- aws/setup_aws.py) and APP.SIMULATE_STUDIES(N), which inserts synthetic
-- study-status events (department level, no patient identifiers) with the same value ranges
-- and ~10% ALERT rate as aws/publish_studies.py. Rows are inserted directly;
-- this simulates a RIS worklist feed and is not Snowpipe Streaming.
-- Run before 06_intelligence.sql (the alert reads RAW.LIVE_STUDIES).
-- Idempotent: safe to run in the AWS build too.
-- ============================================================================
CREATE SCHEMA IF NOT EXISTS RAW;
CREATE SCHEMA IF NOT EXISTS APP;

CREATE TABLE IF NOT EXISTS RAW.LIVE_STUDIES (
  DEPT_ID VARCHAR, EVENT_TS TIMESTAMP_NTZ, WAIT_MINUTES FLOAT, TAT_HOURS FLOAT,
  STATUS VARCHAR, SENT_TS TIMESTAMP_NTZ, SOURCE_FILE VARCHAR,
  LOADED_AT TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP());

CREATE OR REPLACE PROCEDURE APP.SIMULATE_STUDIES(N NUMBER)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN
  IF (N < 1 OR N > 1000) THEN
    RETURN 0;
  END IF;
  INSERT INTO RAW.LIVE_STUDIES (DEPT_ID, EVENT_TS, WAIT_MINUTES, TAT_HOURS, STATUS, SENT_TS, SOURCE_FILE)
    WITH g AS (
      SELECT 'DEPT-' || LPAD(UNIFORM(0, 39, RANDOM())::VARCHAR, 4, '0') AS DEPT_ID,
             UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) < 0.1 AS IS_ALERT,
             SYSDATE() AS TS, SEQ4() AS I
      FROM TABLE(GENERATOR(ROWCOUNT => 1000))
    )
    -- NORMAL() needs a constant mean, so the alert offset is added outside it.
    SELECT DEPT_ID, TS,
           ROUND(IFF(IS_ALERT, 120, 18) * EXP(NORMAL(0, 0.5, RANDOM())), 1),
           ROUND(GREATEST(0, IFF(IS_ALERT, 9.5, 2.5) + NORMAL(0, 1.0, RANDOM())), 2),
           IFF(IS_ALERT, 'ALERT', 'OK'), TS, 'APP.SIMULATE_STUDIES'
    FROM g
    WHERE I < :N;
  RETURN SQLROWCOUNT;
END;
$$;

-- Optional continuous feed for longer demos (suspended; RESUME to start, SUSPEND after).
CREATE OR REPLACE TASK APP.TASK_SIMULATE_STUDIES
  WAREHOUSE = __DEMO_WH__
  SCHEDULE = '1 MINUTE'
AS
  CALL APP.SIMULATE_STUDIES(5);
