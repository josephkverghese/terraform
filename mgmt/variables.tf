variable "subnetAid" {}
variable "subnetBid" {}
variable "subnetACIDR" {}
variable "subnetBCIDR" {}
variable "splunk-ami" {}
variable "splunk_instance_type" {}
variable "vpc_id" {}
variable "splunk_web_port" {}
variable "splunk_mgmt_port" {}
variable "key_name" {}
variable "splunk_license_bucket" {}
variable "splunk_license_file" {}
variable "splunk_license_file_path" {
  default = "/data/gmnts/splunk/etc/Splunk.License"
}
variable "project_name" {}
variable "gtos_gmnts_landing" {}