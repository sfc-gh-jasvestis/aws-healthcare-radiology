#!/bin/bash
# Tear down AWS resources for Radiology Analytics
set -e

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-west-2"

echo "=== Tearing down Radiology Analytics AWS resources ==="

# Delete Q Topic
echo "Deleting Q topic..."
aws quicksight delete-topic \
    --aws-account-id "$ACCOUNT_ID" \
    --topic-id "hc-radiology-q" \
    --region "$REGION" 2>/dev/null || echo "Q topic already deleted or not found"

# Delete Datasets
echo "Deleting datasets..."
aws quicksight delete-dataset \
    --aws-account-id "$ACCOUNT_ID" \
    --dataset-id "hc-radiology-tat" \
    --region "$REGION" 2>/dev/null || echo "Dataset hc-radiology-tat already deleted or not found"

aws quicksight delete-dataset \
    --aws-account-id "$ACCOUNT_ID" \
    --dataset-id "hc-radiology-critical" \
    --region "$REGION" 2>/dev/null || echo "Dataset hc-radiology-critical already deleted or not found"

# Clear secrets
echo "Clearing secrets..."
aws secretsmanager delete-secret \
    --secret-id "healthcare-radiology/quicksight-password" \
    --force-delete-without-recovery \
    --region "$REGION" 2>/dev/null || echo "Secret already deleted or not found"

echo "=== Teardown complete ==="
