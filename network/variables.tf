#----networking/variables.tf----
variable "vpc_cidr" {
  type = "string"
}

variable "public_cidrs" {
  type = "list"
}
variable "accessip" {
  type = string
}

variable "aws_region" {
}

variable "private_cidr" {}