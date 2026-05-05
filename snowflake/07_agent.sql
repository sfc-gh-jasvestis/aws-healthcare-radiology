-- Radiology Analytics: Cortex Agent
USE DATABASE HEALTHCARE_RADIOLOGY;
USE SCHEMA APP;

CREATE OR REPLACE CORTEX AGENT RADIOLOGY_AGENT
    COMMENT = 'Radiology analytics agent for TAT monitoring, critical findings, and productivity analysis'
    MODEL = 'claude-3-5-sonnet'
    TOOLS = (
        RadiologyAnalyst = SEMANTIC_VIEW('HEALTHCARE_RADIOLOGY.APP.RADIOLOGY_SEMANTIC_VIEW'),
        GuidelinesSearch = CORTEX_SEARCH('HEALTHCARE_RADIOLOGY.SEARCH.GUIDELINES_SEARCH')
    )
    AGENT_CONFIG = '{
        "color": "red",
        "description": "Radiology Analytics Agent — monitors turnaround times, manages critical findings queue, analyzes radiologist productivity, and searches clinical guidelines.",
        "instructions": "You are a radiology analytics assistant. Help users monitor turnaround times (CT SLA is 120 minutes, MRI is 180 minutes, X-Ray is 60 minutes). Flag unacknowledged critical findings. Track radiologist productivity against daily targets. Search radiology guidelines when asked about protocols or policies. Always include specific numbers and actionable recommendations."
    }';
