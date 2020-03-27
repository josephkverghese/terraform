variable "subnetid" {}
variable "securitygroup" {}
variable "splunk-ami" {}
variable "splunk_instance_type" {}
variable "splunk_web_port" {}
variable "splunk_mgmt_port" {}
variable "gtos_vpc" {}
variable "accessip" {}
variable "key_name" {}
variable "instance_name" {}
variable "cloudwatch_retention" {
  default = 30
}
variable "cloudwatch_loggroup_name" {}
