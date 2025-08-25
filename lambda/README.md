# Lambda Functions

This directory contains all AWS Lambda functions for the fraud detection pipeline.

## Functions

### `lambda_function.py`
- **Purpose**: Processes anomaly scores and creates fraud alerts
- **Trigger**: Manual/scheduled execution
- **Input**: Reads from S3 scored data
- **Output**: Writes alerts to DynamoDB
- **Filter**: Only stores transactions with anomaly_score > 2.5

### `fraud_investigator_lambda.py`
- **Purpose**: AI assistant backend for natural language queries
- **Trigger**: API Gateway requests
- **Input**: Natural language queries via JSON
- **Output**: Intelligent fraud analysis responses
- **Features**: Query parsing, data analysis, report generation

### `fraud_investigator.py`
- **Purpose**: Local version of AI assistant for testing
- **Usage**: Run locally for development and testing
- **Features**: Same functionality as Lambda version

## Deployment

```bash
# Package and deploy
zip -r fraud_processor.zip lambda_function.py
zip -r fraud_investigator.zip fraud_investigator_lambda.py

# Deploy via AWS CLI or Terraform
```