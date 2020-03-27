#create a log group for this project
resource "aws_cloudwatch_log_group" "log_group" {
  name = var.cloudwatch_loggroup_name
  retention_in_days = var.cloudwatch_retention
}

resource "aws_instance" "splunk" {
  ami = var.splunk-ami
  instance_type = var.splunk_instance_type
  subnet_id = var.subnetid
  vpc_security_group_ids = [
    aws_security_group.splunk_sg.id]
  key_name = var.key_name
  iam_instance_profile = ""
  tags = {
    Name = var.instance_name
  }
}


resource "aws_security_group" "splunk_sg" {
  name = "gtos_public_splunk_sg"
  description = "Used for access to the public instances"
  vpc_id = var.gtos_vpc

  #SSH

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [
      var.accessip]
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
    from_port = var.splunk_web_port
    to_port = var.splunk_web_port
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