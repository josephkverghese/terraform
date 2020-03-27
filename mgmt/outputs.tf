output "splunk_license_s3_bucket" {
  value = aws_s3_bucket.s3_bucket.name
}

output "aws_kms" {
  value = aws_kms_key.s3key.arn
}