-- Radiology Analytics: AI Report Extraction
USE DATABASE HEALTHCARE_RADIOLOGY;
USE SCHEMA AI;

CREATE OR REPLACE PROCEDURE EXTRACT_REPORT_FINDINGS(REPORT_ID_INPUT VARCHAR)
RETURNS VARIANT
LANGUAGE SQL
AS
$$
DECLARE
    report_text TEXT;
    extraction_result VARIANT;
BEGIN
    SELECT REPORT_TEXT INTO report_text
    FROM HEALTHCARE_RADIOLOGY.RAW.REPORTS
    WHERE REPORT_ID = :REPORT_ID_INPUT;

    SELECT SNOWFLAKE.CORTEX.COMPLETE(
        'claude-3-5-sonnet',
        CONCAT(
            'Extract structured findings from this radiology report. Return a JSON object with keys: ',
            '"findings" (array of objects with anatomy, finding, severity, confidence), ',
            '"impression_summary" (string), ',
            '"recommendations" (array of strings), ',
            '"critical" (boolean). ',
            'Report: ', :report_text
        )
    ) INTO extraction_result;

    INSERT INTO HEALTHCARE_RADIOLOGY.AI.EXTRACTED_FINDINGS (REPORT_ID, EXTRACTED_AT, RAW_EXTRACTION)
    VALUES (:REPORT_ID_INPUT, CURRENT_TIMESTAMP(), :extraction_result);

    RETURN extraction_result;
END;
$$;

CREATE OR REPLACE TABLE HEALTHCARE_RADIOLOGY.AI.EXTRACTED_FINDINGS (
    REPORT_ID VARCHAR(20),
    EXTRACTED_AT TIMESTAMP_NTZ,
    RAW_EXTRACTION VARIANT
);
