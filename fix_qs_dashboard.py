import boto3, time

qs = boto3.client('quicksight', region_name='us-west-2')
account_id = '__AWS_ACCOUNT_ID__'
user_arn = f'arn:aws:quicksight:us-west-2:{account_id}:user/default/{account_id}'

# Delete old
try:
    qs.delete_dashboard(AwsAccountId=account_id, DashboardId='hc-radiology-dashboard')
    print('Deleted old dashboard, waiting...')
    time.sleep(10)
except Exception as e:
    print(f'Delete: {e}')
    time.sleep(5)

definition = {
    'DataSetIdentifierDeclarations': [
        {'Identifier': 'tat', 'DataSetArn': f'arn:aws:quicksight:us-west-2:{account_id}:dataset/hc-radiology-tat'},
        {'Identifier': 'critical', 'DataSetArn': f'arn:aws:quicksight:us-west-2:{account_id}:dataset/hc-radiology-critical'}
    ],
    'Sheets': [{
        'SheetId': 'sheet1',
        'Name': 'Turnaround Time & Critical Findings',
        'Visuals': [
            {
                'LineChartVisual': {
                    'VisualId': 'line1',
                    'Title': {'Visibility': 'VISIBLE', 'FormatText': {'PlainText': 'Average TAT by Modality (Minutes)'}},
                    'ChartConfiguration': {
                        'FieldWells': {'LineChartAggregatedFieldWells': {
                            'Category': [{'DateDimensionField': {'FieldId': 'f1', 'Column': {'DataSetIdentifier': 'tat', 'ColumnName': 'METRIC_DATE'}}}],
                            'Values': [{'NumericalMeasureField': {'FieldId': 'f2', 'Column': {'DataSetIdentifier': 'tat', 'ColumnName': 'AVG_TAT_MINUTES'}, 'AggregationFunction': {'SimpleNumericalAggregation': 'AVERAGE'}}}],
                            'Colors': [{'CategoricalDimensionField': {'FieldId': 'f3', 'Column': {'DataSetIdentifier': 'tat', 'ColumnName': 'MODALITY'}}}]
                        }}
                    }
                }
            },
            {
                'BarChartVisual': {
                    'VisualId': 'bar1',
                    'Title': {'Visibility': 'VISIBLE', 'FormatText': {'PlainText': 'SLA Breach % by Modality'}},
                    'ChartConfiguration': {
                        'FieldWells': {'BarChartAggregatedFieldWells': {
                            'Category': [{'CategoricalDimensionField': {'FieldId': 'f4', 'Column': {'DataSetIdentifier': 'tat', 'ColumnName': 'MODALITY'}}}],
                            'Values': [{'NumericalMeasureField': {'FieldId': 'f5', 'Column': {'DataSetIdentifier': 'tat', 'ColumnName': 'SLA_BREACH_PCT'}, 'AggregationFunction': {'SimpleNumericalAggregation': 'AVERAGE'}}}]
                        }},
                        'Orientation': 'HORIZONTAL',
                        'SortConfiguration': {'CategorySort': [{'FieldSort': {'FieldId': 'f5', 'Direction': 'DESC'}}]}
                    }
                }
            },
            {
                'BarChartVisual': {
                    'VisualId': 'bar2',
                    'Title': {'Visibility': 'VISIBLE', 'FormatText': {'PlainText': 'Unacknowledged Critical Findings by Type'}},
                    'ChartConfiguration': {
                        'FieldWells': {'BarChartAggregatedFieldWells': {
                            'Category': [{'CategoricalDimensionField': {'FieldId': 'f6', 'Column': {'DataSetIdentifier': 'critical', 'ColumnName': 'FINDING_TYPE'}}}],
                            'Values': [{'NumericalMeasureField': {'FieldId': 'f7', 'Column': {'DataSetIdentifier': 'critical', 'ColumnName': 'UNACK'}, 'AggregationFunction': {'SimpleNumericalAggregation': 'SUM'}}}]
                        }},
                        'Orientation': 'HORIZONTAL',
                        'SortConfiguration': {'CategorySort': [{'FieldSort': {'FieldId': 'f7', 'Direction': 'DESC'}}]}
                    }
                }
            },
            {
                'KPIVisual': {
                    'VisualId': 'kpi1',
                    'Title': {'Visibility': 'VISIBLE', 'FormatText': {'PlainText': 'Total Studies Completed'}},
                    'ChartConfiguration': {
                        'FieldWells': {'Values': [{'NumericalMeasureField': {'FieldId': 'f8', 'Column': {'DataSetIdentifier': 'tat', 'ColumnName': 'STUDIES_COMPLETED'}, 'AggregationFunction': {'SimpleNumericalAggregation': 'SUM'}}}]}
                    }
                }
            }
        ]
    }]
}

resp = qs.create_dashboard(
    AwsAccountId=account_id,
    DashboardId='hc-radiology-dashboard',
    Name='Radiology: TAT & Critical Findings',
    Definition=definition
)
print(f"Created: {resp.get('Status')} - {resp.get('CreationStatus')}")

qs.update_dashboard_permissions(
    AwsAccountId=account_id,
    DashboardId='hc-radiology-dashboard',
    GrantPermissions=[{
        'Principal': user_arn,
        'Actions': [
            'quicksight:DescribeDashboard', 'quicksight:ListDashboardVersions',
            'quicksight:QueryDashboard', 'quicksight:UpdateDashboard',
            'quicksight:DeleteDashboard', 'quicksight:UpdateDashboardPermissions',
            'quicksight:DescribeDashboardPermissions', 'quicksight:UpdateDashboardPublishedVersion'
        ]
    }]
)
print('Permissions granted')

# Verify
time.sleep(3)
d = qs.describe_dashboard(AwsAccountId=account_id, DashboardId='hc-radiology-dashboard')
print(f"Final Status: {d['Dashboard']['Version']['Status']}")
print(f"Errors: {d['Dashboard']['Version'].get('Errors', [])}")
