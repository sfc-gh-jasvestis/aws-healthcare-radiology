-- Radiology Analytics: Semantic View
USE DATABASE HEALTHCARE_RADIOLOGY;
USE SCHEMA AI;

CREATE OR REPLACE SEMANTIC VIEW RADIOLOGY_SEMANTIC_VIEW
	tables (
		TAT as HEALTHCARE_RADIOLOGY.CURATED.TAT_METRICS primary key (MODALITY,METRIC_DATE) comment='Turnaround time metrics by modality and date',
		CF as HEALTHCARE_RADIOLOGY.CURATED.CRITICAL_FINDINGS_QUEUE primary key (FINDING_ID) comment='Critical findings queue with acknowledgement status',
		PROD as HEALTHCARE_RADIOLOGY.CURATED.RADIOLOGIST_PRODUCTIVITY primary key (RADIOLOGIST_ID,METRIC_DATE) comment='Radiologist productivity metrics per day'
	)
	facts (
		TAT.AVG_TAT_FACT as AVG_TAT_MINUTES,
		TAT.MEDIAN_TAT_FACT as MEDIAN_TAT_MINUTES,
		TAT.STUDIES_COMPLETED_FACT as STUDIES_COMPLETED,
		TAT.SLA_BREACH_COUNT_FACT as TAT_SLA_BREACH_COUNT,
		TAT.SLA_BREACH_PCT_FACT as SLA_BREACH_PCT,
		CF.HOURS_SINCE_FACT as HOURS_SINCE_DETECTION,
		CF.PRIORITY_FACT as PRIORITY_RANK,
		PROD.DAILY_READS_FACT as DAILY_READS,
		PROD.PROD_TAT_FACT as AVG_TAT_MINUTES,
		PROD.STAT_READS_FACT as STAT_READS,
		PROD.CT_READS_FACT as CT_READS,
		PROD.MRI_READS_FACT as MRI_READS
	)
	dimensions (
		TAT.MODALITY_DIM as MODALITY comment='Imaging modality (CT, MRI, XR, US, NM)',
		TAT.METRIC_DATE_DIM as METRIC_DATE comment='Date of the TAT metric',
		CF.FINDING_TYPE_DIM as FINDING_TYPE comment='Type of critical finding (Pulmonary_Embolism, Pneumothorax, Acute_Stroke, Fracture, Mass, Aneurysm)',
		CF.SEVERITY_DIM as SEVERITY comment='Finding severity (CRITICAL or HIGH)',
		CF.BODY_PART_DIM as BODY_PART comment='Body part examined',
		CF.URGENCY_DIM as URGENCY comment='Study urgency level (STAT/URGENT/ROUTINE)',
		CF.CF_SUBSPECIALTY_DIM as SUBSPECIALTY comment='Radiologist subspecialty from critical findings',
		CF.CF_MODALITY_DIM as MODALITY comment='Study modality from critical findings',
		PROD.RADIOLOGIST_NAME_DIM as RADIOLOGIST_NAME comment='Name of the radiologist',
		PROD.SUBSPECIALTY_DIM as SUBSPECIALTY comment='Radiologist subspecialty',
		PROD.PROD_DATE_DIM as METRIC_DATE comment='Date of productivity metric'
	)
	metrics (
		TAT.AVG_TAT_METRIC as AVG(tat.AVG_TAT_FACT) comment='Average turnaround time in minutes',
		TAT.STUDIES_COUNT_METRIC as SUM(tat.STUDIES_COMPLETED_FACT) comment='Total studies completed',
		TAT.SLA_BREACH_METRIC as SUM(tat.SLA_BREACH_COUNT_FACT) comment='Total SLA breaches',
		TAT.SLA_BREACH_PCT_METRIC as AVG(tat.SLA_BREACH_PCT_FACT) comment='Average SLA breach percentage',
		CF.CRITICAL_COUNT_METRIC as COUNT(cf.FINDING_ID) comment='Count of critical findings',
		CF.UNACKED_COUNT_METRIC as COUNT_IF(cf.PRIORITY_FACT <= 2) comment='Count of unacknowledged critical findings',
		PROD.READS_PER_DAY_METRIC as AVG(prod.DAILY_READS_FACT) comment='Average reads per day per radiologist',
		PROD.AVG_RADIOLOGIST_TAT_METRIC as AVG(prod.PROD_TAT_FACT) comment='Average TAT per radiologist in minutes'
	)
	comment='Radiology analytics - TAT metrics, critical findings, and radiologist productivity'
	ai_sql_generation 'Focus on CT turnaround time SLA breach crisis: CT average TAT is 285 minutes vs 120 minute SLA target. There are 847 unacknowledged critical findings. Top radiologist Dr. Tanaka reads 45/day while bottom performers read 4-5/day. Round numeric values to 1 decimal place.';
