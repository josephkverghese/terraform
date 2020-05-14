#----networking/variables.tf----
variable "vpc_cidr" {
  type = string
}

variable "public_cidrs" {
  type = list
}

variable "private_cidrs" {
  type = list
}

variable "aws_region" {
}

variable "user_cidr" {}

variable "project_name" {}

variable "enable_nat_instance" {}