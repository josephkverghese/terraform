output "splunk" {
  value = aws_instance.splunk.id
}

output "splunk_az" {
  value = aws_instance.splunk.availability_zone
}

output "splunk_ip" {
  value = aws_instance.splunk.associate_public_ip_address
}

output "cloudwatch_group" {
  value = aws_cloudwatch_log_group.log_group.name
}