resource "aws_kms_key" "s3key" {
  description = "This key is used to encrypt s3 license bucket"
  deletion_window_in_days = 10
}

resource "aws_s3_bucket" "s3_bucket_splunk_license" {
  bucket = var.splunk_license_bucket
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.s3key.arn
        sse_algorithm = "aws:kms"
      }
    }
  }
  tags = {
    Name = var.splunk_license_bucket
  }
}

resource "null_resource" "copy_splunk_license_file" {
  depends_on = [
    aws_s3_bucket.s3_bucket_splunk_license]
  provisioner "local-exec" {
    command = "aws s3 cp s3://${var.gtos_gmnts_landing}/${var.splunk_license_file} s3://${var.splunk_license_bucket}/${var.splunk_license_file}}"
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

#define an iam policy
data "aws_iam_policy_document" "splunk_instance-assume-role-policy" {
  statement {
    actions = [
      "sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = [
        "ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "splunk_instance-assume-role-policy2" {

  statement {
    actions = [
      "s3:GetObject",
      "s3:ListObject"]

    resources = [
      aws_s3_bucket.s3_bucket_splunk_license.arn]
  }
}
resource "aws_iam_policy" "splunk_s3" {
  name = "splunk_s3"
  path = "/"
  description = "My test policy"

  policy = data.aws_iam_policy_document.splunk_instance-assume-role-policy2.json
}
#add the above policy to the splunk ec2 instance role
resource "aws_iam_role" "splunk_ec2_role" {
  name = "splunk_ec2_role"
  path = "/"
  # who can assume this role
  assume_role_policy = data.aws_iam_policy_document.splunk_instance-assume-role-policy.json
}

# ec2 instances should be able to access other ec2 instances, cloudwatch, sns topic
//resource "aws_iam_policy" "splunk_ec2_policy" {
//  policy = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
//}

#attach an additional policy to the splunk ec2 iam role
resource "aws_iam_role_policy_attachment" "splunk_ec2_attach" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role = aws_iam_role.splunk_ec2_role.id
}

#attach an additional policy to the splunk ec2 iam role
resource "aws_iam_role_policy_attachment" "splunk_ec2_attach2" {
  policy_arn = aws_iam_policy.splunk_s3.arn
  role = aws_iam_role.splunk_ec2_role.id
}

#create the instance profile with the above splunk ec2 role
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "iam_instance_profile"
  role = aws_iam_role.splunk_ec2_role.id
}

#splunk license file source
data "aws_s3_bucket_object" "splunk_license_file" {
  bucket = aws_s3_bucket.s3_bucket_splunk_license.bucket
  key = var.splunk_license_file
  depends_on = [null_resource.copy_splunk_license_file]
}

#create splunk license server
#copy splunk license file from s3 bucket to this license master host
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