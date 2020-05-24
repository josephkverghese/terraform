output "splunk" {
  value = aws_instance.splunk.*.id
}

output "splunk_az" {
  value = aws_instance.splunk.*.availability_zone
}

output "splunk_ip" {
  value = aws_instance.splunk.*.associate_public_ip_address
}

output "cloudwatch_group" {
  value = aws_cloudwatch_log_group.log_group.name
}

output "splunk_ec2_instance_role" {
  value = aws_iam_role.splunk_ec2_role.arn
}

output "splunk_shc_alb" {
  value = aws_alb.splunk_shc_alb.0.dns_name
}

output "deployer_init" {
  value = data.template_cloudinit_config.deployer_cloud_init.rendered
}

output "shc_init" {
  value = data.template_cloudinit_config.shc_cloud_init.rendered
}

output "shc_ip" {
  value = data.local_file.sh_ip.0.content
}