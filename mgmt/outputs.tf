output "splunk_license_s3_bucket" {
  value = aws_s3_bucket.s3_bucket_splunk_license.bucket
}

output "s3_bucket_splunk_license" {
  value = aws_s3_bucket.s3_bucket_splunk_license.bucket
}

output "aws_kms" {
  value = aws_kms_key.s3key.arn
}