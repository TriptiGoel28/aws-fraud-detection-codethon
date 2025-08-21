terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Use existing bucket
data "aws_s3_bucket" "existing_bucket" {
  bucket = "my-secure-bucket-wxj077wp"
}

# Encryption already configured on existing bucket

resource "aws_iam_role" "glue_role" {
  name = "${var.project_name}-glue-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "glue_service_role" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "glue_s3_policy" {
  name = "${var.project_name}-glue-s3-policy"
  role = aws_iam_role.glue_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::my-secure-bucket-wxj077wp",
          "arn:aws:s3:::my-secure-bucket-wxj077wp/*"
        ]
      }
    ]
  })
}

resource "aws_glue_job" "fraud_detection_job" {
  name     = "${var.project_name}-job"
  role_arn = aws_iam_role.glue_role.arn
  command {
    script_location = "s3://my-secure-bucket-wxj077wp/scripts/fraud_detection.py"
    python_version  = "3"
  }
  default_arguments = {
    "--job-language" = "python"
    "--bucket-name"  = "my-secure-bucket-wxj077wp"
  }
  max_retries = 1
  timeout     = 60
}

# SageMaker IAM Role
resource "aws_iam_role" "sagemaker_role" {
  name = "${var.project_name}-sagemaker-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "sagemaker.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "sagemaker_execution_role" {
  role       = aws_iam_role.sagemaker_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}

resource "aws_iam_role_policy" "sagemaker_s3_policy" {
  name = "${var.project_name}-sagemaker-s3-policy"
  role = aws_iam_role.sagemaker_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::my-secure-bucket-wxj077wp",
          "arn:aws:s3:::my-secure-bucket-wxj077wp/*"
        ]
      }
    ]
  })
}

# SageMaker Training Job
resource "aws_sagemaker_training_job" "rcf_training" {
  name     = "${var.project_name}-rcf-training"
  role_arn = aws_iam_role.sagemaker_role.arn

  algorithm_specification {
    training_image = "382416733822.dkr.ecr.us-east-1.amazonaws.com/randomcutforest:1"
  }

  input_data_config {
    channel_name = "train"
    data_source {
      s3_data_source {
        s3_data_type         = "S3Prefix"
        s3_uri               = "s3://my-secure-bucket-wxj077wp/rcf-input/"
        s3_data_distribution = "ShardedByS3Key"
      }
    }
    content_type = "text/csv"
  }

  output_data_config {
    s3_output_path = "s3://my-secure-bucket-wxj077wp/models/"
  }

  resource_config {
    instance_type  = "ml.m5.large"
    instance_count = 1
    volume_size_in_gb = 30
  }

  stopping_condition {
    max_runtime_in_seconds = 3600
  }

  hyper_parameters = {
    feature_dim = "4"
    num_trees   = "100"
    num_samples_per_tree = "256"
  }
}

# SageMaker Model
resource "aws_sagemaker_model" "rcf_model" {
  name               = "${var.project_name}-rcf-model"
  execution_role_arn = aws_iam_role.sagemaker_role.arn

  primary_container {
    image          = "382416733822.dkr.ecr.us-east-1.amazonaws.com/randomcutforest:1"
    model_data_url = "${aws_sagemaker_training_job.rcf_training.model_artifacts[0].s3_model_artifacts}"
  }

  depends_on = [aws_sagemaker_training_job.rcf_training]
}

# SageMaker Transform Job
resource "aws_sagemaker_transform_job" "batch_transform" {
  name           = "${var.project_name}-batch-transform"
  model_name     = aws_sagemaker_model.rcf_model.name
  max_concurrent_transforms = 1
  max_payload_in_mb = 6

  transform_input {
    data_source {
      s3_data_source {
        s3_data_type = "S3Prefix"
        s3_uri       = "s3://my-secure-bucket-wxj077wp/rcf-input/"
      }
    }
    content_type = "text/csv"
  }

  transform_output {
    s3_output_path = "s3://my-secure-bucket-wxj077wp/scored/"
  }

  transform_resources {
    instance_type  = "ml.m5.large"
    instance_count = 1
  }

  depends_on = [aws_sagemaker_model.rcf_model]
}

# DynamoDB Table for Fraud Alerts
resource "aws_dynamodb_table" "fraud_alerts" {
  name           = "fraud-alerts"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "transaction_id"

  attribute {
    name = "transaction_id"
    type = "S"
  }

  tags = {
    Name = "fraud-alerts"
    Environment = "dev"
  }
}

# Lambda IAM Role
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_permissions" {
  name = "${var.project_name}-lambda-permissions"
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::my-secure-bucket-wxj077wp",
          "arn:aws:s3:::my-secure-bucket-wxj077wp/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:GetItem",
          "dynamodb:Scan",
          "dynamodb:Query"
        ]
        Resource = aws_dynamodb_table.fraud_alerts.arn
      }
    ]
  })
}

# Lambda Function
resource "aws_lambda_function" "fraud_processor" {
  filename         = "fraud_processor.zip"
  function_name    = "${var.project_name}-fraud-processor"
  role            = aws_iam_role.lambda_role.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.9"
  timeout         = 60

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.fraud_alerts.name
      S3_BUCKET = "my-secure-bucket-wxj077wp"
    }
  }

  depends_on = [aws_iam_role_policy_attachment.lambda_basic_execution]
}

# FraudInvestigator Lambda Function
resource "aws_lambda_function" "fraud_investigator" {
  filename         = "fraud_investigator.zip"
  function_name    = "${var.project_name}-fraud-investigator"
  role            = aws_iam_role.lambda_role.arn
  handler         = "fraud_investigator_lambda.lambda_handler"
  runtime         = "python3.9"
  timeout         = 30

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.fraud_alerts.name
    }
  }

  depends_on = [aws_iam_role_policy_attachment.lambda_basic_execution]
}