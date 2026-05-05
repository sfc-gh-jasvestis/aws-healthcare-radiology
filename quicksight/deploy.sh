#!/bin/bash
# QuickSight Deployment for Radiology Analytics
set -e

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-west-2"
DATA_SOURCE_ID="healthcare-snowflake-ds"

echo "=== Deploying QuickSight Datasets for Radiology ==="

# Dataset: TAT Metrics
aws quicksight create-dataset \
    --aws-account-id "$ACCOUNT_ID" \
    --dataset-id "hc-radiology-tat" \
    --name "Radiology TAT Metrics" \
    --physical-table-map '{
        "RadiologyTAT": {
            "CustomSql": {
                "DataSourceArn": "arn:aws:quicksight:'$REGION':'$ACCOUNT_ID':datasource/'$DATA_SOURCE_ID'",
                "Name": "RadiologyTAT",
                "SqlQuery": "SELECT MODALITY, STUDY_DATE, STUDIES_COMPLETED, AVG_TAT_MINUTES, MEDIAN_TAT_MINUTES, TAT_SLA_BREACH_COUNT, SLA_BREACH_PCT FROM HEALTHCARE_RADIOLOGY.CURATED.TAT_METRICS",
                "Columns": [
                    {"Name": "MODALITY", "Type": "STRING"},
                    {"Name": "STUDY_DATE", "Type": "DATETIME"},
                    {"Name": "STUDIES_COMPLETED", "Type": "INTEGER"},
                    {"Name": "AVG_TAT_MINUTES", "Type": "DECIMAL"},
                    {"Name": "MEDIAN_TAT_MINUTES", "Type": "DECIMAL"},
                    {"Name": "TAT_SLA_BREACH_COUNT", "Type": "INTEGER"},
                    {"Name": "SLA_BREACH_PCT", "Type": "DECIMAL"}
                ]
            }
        }
    }' \
    --import-mode SPICE \
    --region "$REGION"

echo "Created dataset: hc-radiology-tat"

# Dataset: Critical Findings
aws quicksight create-dataset \
    --aws-account-id "$ACCOUNT_ID" \
    --dataset-id "hc-radiology-critical" \
    --name "Radiology Critical Findings" \
    --physical-table-map '{
        "CriticalFindings": {
            "CustomSql": {
                "DataSourceArn": "arn:aws:quicksight:'$REGION':'$ACCOUNT_ID':datasource/'$DATA_SOURCE_ID'",
                "Name": "CriticalFindings",
                "SqlQuery": "SELECT FINDING_ID, FINDING_TYPE, SEVERITY, RADIOLOGIST_NAME, ACKNOWLEDGED, MINUTES_TO_ACKNOWLEDGE, PRIORITY_RANK, IDENTIFIED_AT FROM HEALTHCARE_RADIOLOGY.CURATED.CRITICAL_FINDINGS_QUEUE",
                "Columns": [
                    {"Name": "FINDING_ID", "Type": "STRING"},
                    {"Name": "FINDING_TYPE", "Type": "STRING"},
                    {"Name": "SEVERITY", "Type": "STRING"},
                    {"Name": "RADIOLOGIST_NAME", "Type": "STRING"},
                    {"Name": "ACKNOWLEDGED", "Type": "BIT"},
                    {"Name": "MINUTES_TO_ACKNOWLEDGE", "Type": "INTEGER"},
                    {"Name": "PRIORITY_RANK", "Type": "INTEGER"},
                    {"Name": "IDENTIFIED_AT", "Type": "DATETIME"}
                ]
            }
        }
    }' \
    --import-mode SPICE \
    --region "$REGION"

echo "Created dataset: hc-radiology-critical"

# Q Topic
aws quicksight create-topic \
    --aws-account-id "$ACCOUNT_ID" \
    --topic-id "hc-radiology-q" \
    --topic '{
        "Name": "Radiology Analytics",
        "Description": "Natural language queries over radiology turnaround times, critical findings, and radiologist productivity",
        "DataSets": [
            {
                "DatasetArn": "arn:aws:quicksight:'$REGION':'$ACCOUNT_ID':dataset/hc-radiology-tat",
                "DatasetName": "Radiology TAT Metrics"
            },
            {
                "DatasetArn": "arn:aws:quicksight:'$REGION':'$ACCOUNT_ID':dataset/hc-radiology-critical",
                "DatasetName": "Radiology Critical Findings"
            }
        ]
    }' \
    --region "$REGION"

echo "Created Q topic: hc-radiology-q"
echo "=== QuickSight deployment complete ==="
