-- Radiology Analytics: Semantic View
USE DATABASE HEALTHCARE_RADIOLOGY;
USE SCHEMA APP;

CREATE OR REPLACE SEMANTIC VIEW RADIOLOGY_SEMANTIC_VIEW
    COMMENT = 'Semantic view for radiology analytics over TAT metrics, critical findings, and radiologist productivity'
AS
DEFINE ENTITY tat_metrics AS (
    SELECT * FROM HEALTHCARE_RADIOLOGY.CURATED.TAT_METRICS
)
    PRIMARY KEY (MODALITY, STUDY_DATE)
    COMMENT = 'Turnaround time metrics by modality and date'

    WITH DIMENSION modality
        COMMENT = 'Imaging modality (CT, MRI, X-Ray, Ultrasound, PET)'
    WITH DIMENSION study_date
        COMMENT = 'Date of the studies'
    WITH METRIC studies_completed
        COMMENT = 'Number of studies completed'
    WITH METRIC avg_tat_minutes
        COMMENT = 'Average turnaround time in minutes from order to report'
    WITH METRIC median_tat_minutes
        COMMENT = 'Median turnaround time in minutes'
    WITH METRIC tat_sla_breach_count
        COMMENT = 'Number of studies that breached their SLA target'
    WITH METRIC sla_breach_pct
        COMMENT = 'Percentage of studies breaching SLA'

DEFINE ENTITY critical_findings AS (
    SELECT * FROM HEALTHCARE_RADIOLOGY.CURATED.CRITICAL_FINDINGS_QUEUE
)
    PRIMARY KEY (FINDING_ID)
    COMMENT = 'Critical findings requiring acknowledgment'

    WITH DIMENSION finding_type
        COMMENT = 'Type of critical finding (e.g., Pulmonary Embolism, Stroke)'
    WITH DIMENSION severity
        COMMENT = 'Severity level: Critical, Urgent, or High'
    WITH DIMENSION acknowledged
        COMMENT = 'Whether the finding has been acknowledged by the referring provider'
    WITH DIMENSION radiologist_name
        COMMENT = 'Name of the radiologist who identified the finding'
    WITH METRIC minutes_to_acknowledge
        COMMENT = 'Minutes elapsed from identification to acknowledgment'
    WITH METRIC priority_rank
        COMMENT = 'Priority ranking (1=highest, 4=lowest)'

DEFINE ENTITY radiologist_productivity AS (
    SELECT * FROM HEALTHCARE_RADIOLOGY.CURATED.RADIOLOGIST_PRODUCTIVITY
)
    PRIMARY KEY (RADIOLOGIST_ID, REPORT_DATE)
    COMMENT = 'Daily productivity metrics per radiologist'

    WITH DIMENSION full_name
        COMMENT = 'Radiologist full name'
    WITH DIMENSION subspecialty
        COMMENT = 'Radiologist subspecialty'
    WITH DIMENSION shift
        COMMENT = 'Shift assignment (Day, Evening, Night)'
    WITH DIMENSION report_date
        COMMENT = 'Date of the reads'
    WITH METRIC daily_reads
        COMMENT = 'Number of studies read that day'
    WITH METRIC avg_tat_minutes
        COMMENT = 'Average turnaround time for this radiologist on this day'
    WITH METRIC stat_reads
        COMMENT = 'Number of STAT priority reads'
    WITH METRIC target_achievement_pct
        COMMENT = 'Percentage of daily target achieved'
    WITH METRIC daily_target
        COMMENT = 'Target number of daily reads';
