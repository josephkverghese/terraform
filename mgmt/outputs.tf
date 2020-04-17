output "s3_bucket_splunk_license" {
  value = aws_s3_bucket.s3_bucket_splunk_license.bucket
}

output "aws_kms" {
  value = aws_kms_key.s3key.arn
}

output "bastion_public_ip" {
  value = aws_spot_instance_request.bastionH_WindowsUser.0.public_ip
}

output "WinUser_public_ip" {
  value = aws_spot_instance_request.bastionH_WindowsUser.1.public_ip
}