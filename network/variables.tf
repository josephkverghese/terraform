#----networking/variables.tf----
variable "vpc_cidr" {
  type = string
}

variable "public_cidrs" {
  type = list(string)
}

variable "private_cidrs" {
  type = list(string)
}

variable "aws_region" {
}

variable "user_cidr" {}

variable "project_name" {}