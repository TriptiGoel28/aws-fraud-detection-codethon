output "bucket_name" {
  value = aws_s3_bucket.data_bucket.bucket
}

output "glue_job_name" {
  value = aws_glue_job.fraud_detection_job.name
}

output "glue_role_arn" {
  value = aws_iam_role.glue_role.arn
}