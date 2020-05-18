variable "subnetAid" {}
variable "subnetBid" {}
variable "subnetACIDR" {}
variable "subnetBCIDR" {}
variable "subnetCid" {}
variable "subnetDid" {}
variable "subnetCCIDR" {}
variable "subnetDCIDR" {}
variable "splunk-ami" {}
variable "splunk_instance_type" {}
variable "splunk_web_port" {}
variable "splunk_mgmt_port" {}
variable "vpc_id" {}
variable "accessip" {
  type = list(string)
}
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
  type        = bool
}

variable "splunk_shc_volume_size" {}
variable "splunk_shc_root_volume_size" {}
variable "project_name" {}
variable "license_server_hostname" {}
variable "splunkadminpass" {}
variable "splunkshcrepport" {}
variable "splunkshcrepfact" {}
variable "shclusterkey" {}
variable "key_file" {}
variable "bastion_public_ip" {}
variable "ec2-user" {
  default = "ec2-user"
}
variable "shcmemberindex_captain" {
  default = 1
}
variable "asgindex" {
  default = "asgindex"
}
variable "shcmembercount" {}
variable "shc_init_check_retry_count" {}
variable "shc_init_check_retry_sleep_wait" {}