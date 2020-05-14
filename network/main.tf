# vpc
# 2 public subnets
# 2 private subnet
# 1 user subnet
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
    Name = "gtos_vpc"
    project = "gtos"
    group = "gmnts"
  }
}

#internet gateway
resource "aws_internet_gateway" "gtos_igw" {
  vpc_id = aws_vpc.gtosvpc.id
  tags = {
    Project = var.project_name
    group = "gmnts"
    Name = "gtos_igw"
  }
}

# public route table
resource "aws_route_table" "gtos_route_table_public" {
  vpc_id = aws_vpc.gtosvpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gtos_igw.id
  }
  tags = {
    Name = "gtos_public_rt"
    Project = var.project_name
    group = "gmnts"
  }
}

# private route table
resource "aws_route_table" "gtos_route_table_private" {
  vpc_id = aws_vpc.gtosvpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_instance.nat_instance.0.id
  }
  tags = {
    Name = "gtos_private_rt"
    Project = var.project_name
    Group = "gmnts"
  }
}

#create two public subnets
resource "aws_subnet" "gtos_subnet_public" {
  count = 2
  vpc_id = aws_vpc.gtosvpc.id
  cidr_block = var.public_cidrs[count.index]
  map_public_ip_on_launch = true
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "gtos_public_subnet_${count.index+1}"
    Project = var.project_name

  }
}


#create two private subnets
resource "aws_subnet" "gtos_subnet_private" {
  count = 2
  vpc_id = aws_vpc.gtosvpc.id
  cidr_block = var.private_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "gtos_private_subnet_${count.index+1}"
    Project = var.project_name

  }
}

#create a private subnet, this is where users live
resource "aws_subnet" "gtos_user_subnet" {
  vpc_id = aws_vpc.gtosvpc.id
  cidr_block = var.user_cidr
  availability_zone = data.aws_availability_zones.available.names[0]
  tags = {
    Name = "gtos_user_subnet"
    Project = var.project_name

  }
}

#route table association - public
resource "aws_route_table_association" "gtos_public_rt_assoc" {
  count = length(aws_subnet.gtos_subnet_public)
  subnet_id = aws_subnet.gtos_subnet_public.*.id[count.index]
  route_table_id = aws_route_table.gtos_route_table_public.id
}


#route table association - public
resource "aws_route_table_association" "gtos_private_rt_assoc" {
  count = length(aws_subnet.gtos_subnet_private)
  subnet_id = aws_subnet.gtos_subnet_private.*.id[count.index]
  route_table_id = aws_route_table.gtos_route_table_private.id
}

#add a nat instance to the module
resource aws_instance "nat_instance" {
  count = var.enable_nat_instance ? 1 : 0
  ami = "ami-00a9d4a05375b2763"
  instance_type = "t2.micro"
  source_dest_check = false
  subnet_id = aws_subnet.gtos_subnet_public.0.id
}

resource "aws_eip" "nat_eip" {
  count = var.enable_nat_instance ? 1 : 0
  instance = aws_instance.nat_instance.0.id
  vpc = true
}

resource "aws_security_group" "nat-sg" {
  count = var.enable_nat_instance? 1 : 0
  name = "gtos_nat_sg"
  description = "Used for access to public splunk alb"
  vpc_id = aws_vpc.gtosvpc.id

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = [
      aws_subnet.gtos_subnet_private.0.cidr_block,
      aws_subnet.gtos_subnet_private.1.cidr_block]
  }

  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = [
      aws_subnet.gtos_subnet_private.0.cidr_block,
      aws_subnet.gtos_subnet_private.1.cidr_block]
  }

  egress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = [
      "0.0.0.0/0"]
  }

  egress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = [
      "0.0.0.0/0"]
  }


}
}