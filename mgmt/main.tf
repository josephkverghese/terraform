resource "aws_kms_key" "s3key" {
  description = "This key is used to encrypt s3 license bucket"
  deletion_window_in_days = 10
}

resource "aws_s3_bucket" "s3_bucket_splunk_license" {
  bucket = var.s3_bucket_name
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.s3key.arn
        sse_algorithm = "aws:kms"
      }
    }
  }
  tags = {
    Name = var.s3_bucket_name
  }
}

#splunk security group for license server
resource "aws_security_group" "splunk_sg_license_server" {
  name = "gtos_public_splunk_sg_license_server"
  description = "security group to allow access to splunk license server"
  vpc_id = var.vpc_id

  #SSH
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [
      var.subnetACIDR]
  }

  #splunk-web
  ingress {
    from_port = var.splunk_web_port
    to_port = var.splunk_web_port
    protocol = "tcp"
    cidr_blocks = [
      var.subnetACIDR,
      var.subnetBCIDR]
  }
}


resource "aws_iam_role" "splunk_ec2_role" {
  name = "splunk_ec2_role"
  path = "/"
  # who can assume this role
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        },
        {
            "Action": ["s3:GetObject","s3:ListObject"],
            "Effect": "Allow",
            "Sid": "",
            "Resource":[${aws_s3_bucket.s3_bucket_splunk_license.arn}]
        }
    ]
}
EOF
}

# ec2 instances should be able to access other ec2 instances, cloudwatch, sns topic
//resource "aws_iam_policy" "splunk_ec2_policy" {
//  policy = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
//}

#attach the policy to the iam role
resource "aws_iam_policy_attachment" "splunk_ec2_attach" {
  name = "splunk_ec2_attach"
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  roles = [
    aws_iam_role.splunk_ec2_role.id]
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "iam_instance_profile"
  role = aws_iam_role.splunk_ec2_role.id
}

#splunk license file source
data "aws_s3_bucket_object" "splunk_license_file" {
  bucket = aws_s3_bucket.s3_bucket_splunk_license.bucket
  key = var.splunk_license_file
}

#splunk license server

resource "aws_instance" "splunk_license_server" {

  ami = var.splunk-ami
  instance_type = var.splunk_instance_type
  subnet_id = var.subnetAid
  vpc_security_group_ids = [
    aws_security_group.splunk_sg_license_server.id]
  key_name = var.key_name
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.id
  provisioner "file" {
    source = data.aws_s3_bucket_object.splunk_license_file
    destination = var.splunk_license_file_path
  }
  tags = {
    Name = "${var.project_name}-License Server"
  }
}