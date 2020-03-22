# vpc and 2 subnets
# internet gateway
# custom public routetable with route to internetgateway
# route table associations for both the public subnets
# ----- networking/main.tf
data "aws_availability_zones" "available" {}

#vpc
resource "aws_vpc" "gtosvpc" {
  cidr_block = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support = true
  tags = {
    Name = "gtosvpc"
    project = "gtos"
    group = "gmnts"
  }
}

#internet gateway
resource "aws_internet_gateway" "gtos_igw" {
  vpc_id = aws_vpc.gtosvpc.id
  tags = {
    project = "gtos"
    group = "gmnts"
    Name = "gtos_igw"
  }
}

# public route table
resource "aws_route_table" "gtos_public_rt" {
  vpc_id = aws_vpc.gtosvpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gtos_igw.id
  }
  tags = {
    Name = "gtos_public_rt"
    project = "gtos"
    group = "gmnts"
  }
}

# private route table
resource "aws_default_route_table" "gtos_private_rt" {
  default_route_table_id = aws_vpc.gtosvpc.default_route_table_id

  tags = {
    Name = "gtos_private_rt"
    project = "gtos"
    group = "gmnts"
  }
}

#create two public subnets
resource "aws_subnet" "gtos_public_subnet" {
  count = 2
  vpc_id = aws_vpc.gtosvpc.id
  cidr_block = var.public_cidrs[count.index]
  map_public_ip_on_launch = true
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "gtos_public_subnet_${count.index+1}"
  }
}

#create a private subnet, this is where users live
resource "aws_subnet" "gtos_user_subnet" {
  vpc_id = aws_vpc.gtosvpc.id
  cidr_block = var.private_cidr
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "gtos_private_subnet"
  }
}


#route table association - public
resource "aws_route_table_association" "gtos_public_rt_assoc" {
  count = length(aws_subnet.gtos_public_subnet)
  subnet_id = aws_subnet.gtos_public_subnet.*.id[count.index]
  route_table_id = aws_route_table.gtos_public_rt.id
}
#ec2 security group - public to restrict traffic to ec2 instances
resource "aws_security_group" "gtos_public_sg" {
  name = "gtos_public_sg"
  description = "Used for access to the public instances"
  vpc_id = aws_vpc.gtosvpc.id

  #SSH

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [
      var.accessip_ssh]
  }

  #HTTP

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = [
      var.accessip]
  }

  #splunk-web

  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = [
      var.accessip]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [
      "0.0.0.0/0"]
  }
}