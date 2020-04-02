variable "subnetAid" {}
variable "subnetBid" {}
variable "subnetACIDR" {}
variable "subnetBCIDR" {}
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
variable "alb_listener_protocol" {}
variable "enable_splunk_shc" {
  description = "If set to true, enable auto scaling"
  type = bool
}

variable "splunk_shc_volume_size" {}
variable "splunk_shc_root_volume_size" {}