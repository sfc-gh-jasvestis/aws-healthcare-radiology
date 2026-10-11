-- Validate the producer contract before building downstream objects.
USE DATABASE IDENTIFIER($DEMO_DB);
USE SCHEMA RAW;
USE WAREHOUSE IDENTIFIER($DEMO_WH);

EXECUTE IMMEDIATE $$
DECLARE
  violations INTEGER;
  invalid_source EXCEPTION (-20001, 'Synthetic source failed grain or measure validation');
BEGIN
  SELECT COUNT(*) INTO :violations FROM (
    SELECT ENTITY_ID, EVENT_DATE
    FROM RAW.DEPT_DAILY
    GROUP BY ENTITY_ID, EVENT_DATE HAVING COUNT(*) <> 1
    UNION ALL
    SELECT observation.ENTITY_ID, observation.EVENT_DATE
    FROM RAW.DEPT_DAILY observation
    LEFT JOIN RAW.DEPARTMENTS site ON site.ID = observation.ENTITY_ID
    WHERE site.ID IS NULL OR observation.COMPLETED_COUNT < 0
       OR observation.IN_TARGET_COUNT < 0 OR observation.IN_TARGET_COUNT > observation.COMPLETED_COUNT
       OR observation.BREACH_COUNT < 0 OR observation.BREACH_COUNT > observation.ESCALATION_COUNT
       OR observation.REVIEW_OPENED > observation.BREACH_COUNT
       OR observation.QA_COMPLETED > observation.QA_DUE
  );
  IF (violations > 0) THEN
    RAISE invalid_source;
  END IF;
END;
$$;
