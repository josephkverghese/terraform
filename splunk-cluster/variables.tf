variable "subnetid" {}
variable "securitygroup" {}
variable "splunk-ami" {}
variable "splunk_instance_type" {}
variable "splunk_web_port" {}
variable "splunk_mgmt_port" {}
variable "vpc_id" {}
variable "accessip" {}
variable "key_name" {}
variable "instance_name" {}
variable "cloudwatch_retention" {
  default = 30
}
variable "cloudwatch_loggroup_name" {}
variable "splunk_shc_alb" {}
variable "alb_listener_port" {}
variable "alb_listener_protocol" {}
variable "splunk_sh_target_port" {}