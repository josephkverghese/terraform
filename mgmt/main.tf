resource "aws_kms_key" "s3key" {
  description = "This key is used to encrypt s3 license bucket"
  deletion_window_in_days = 10
}

resource "aws_s3_bucket" "s3_bucket_splunk_license" {
  bucket = var.splunk_license_bucket
  force_destroy = true
  acl = "private"
  //  server_side_encryption_configuration {
  //    rule {
  //      apply_server_side_encryption_by_default {
  //        kms_master_key_id = aws_kms_key.s3key.arn
  //        sse_algorithm = "aws:kms"
  //      }
  //    }
  //  }
  tags = {
    Name = var.splunk_license_bucket
  }
}

#copy from landing bucket to license bukcet
resource "null_resource" "copy_splunk_license_file" {
  depends_on = [
    aws_s3_bucket.s3_bucket_splunk_license]
  provisioner "local-exec" {
    command = "aws s3 cp s3://${var.gtos_gmnts_landing}/${var.splunk_license_file} s3://${var.splunk_license_bucket}/${var.splunk_license_file}"
  }
}

#define an iam policy
data "aws_iam_policy_document" "splunk-instance-assume-role-policy" {
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

data "aws_iam_policy_document" "splunk-get-s3-object-policy2" {

  statement {
    actions = [
      "s3:Get*"]
    effect = "Allow"
    resources = [
      "arn:aws:s3:::*"]
    //      "arn:aws:s3:::${var.splunk_license_bucket}/*"]
  }
}
resource "aws_iam_policy" "splunk_s3" {
  name = "splunk_s3"
  path = "/"
  description = "access splunk license bucket to get objects"
  policy = data.aws_iam_policy_document.splunk-get-s3-object-policy2.json
}
#add the above policy to the splunk ec2 instance role
resource "aws_iam_role" "splunk_ec2_role" {
  depends_on = [
    aws_iam_policy.splunk_s3]
  name = "splunk_ec2_role-${var.project_name}"
  path = "/"
  # who can assume this role
  assume_role_policy = data.aws_iam_policy_document.splunk-instance-assume-role-policy.json
  force_detach_policies = true
}

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
  name = "iam_instance_profile-${var.project_name}"
  role = aws_iam_role.splunk_ec2_role.id
}

//#splunk license file source
//data "aws_s3_bucket_object" "splunk_license_file" {
//  bucket = aws_s3_bucket.s3_bucket_splunk_license.bucket
//  key = var.splunk_license_file
//  depends_on = [
//    null_resource.copy_splunk_license_file]
//}

resource "aws_vpc_endpoint" "s3" {
  vpc_id = var.vpc_id
  service_name = var.endpoint_service_name
  tags = {
    project = var.project_name
    Environment = "test"
  }
}

resource "aws_vpc_endpoint_route_table_association" "splunk_pvt_s3" {
  route_table_id = var.gtos_private_route_table_id
  vpc_endpoint_id = aws_vpc_endpoint.s3.id
}

data "template_file" "splunk_l_server_init" {
  template = file("${path.module}/init_license_server")
  vars = {
    msg = "starting license server provisioning",
    splunk_license_bucket = var.splunk_license_bucket,
    splunk_license_file = var.splunk_license_file,
    splunk_admin_pass = var.splunk_admin_pass
  }
}


#create splunk license server
#copy splunk license file from s3 bucket to this license master host
resource "aws_instance" "splunk_license_server" {
  depends_on = [
    aws_vpc_endpoint.s3]
  ami = var.splunk-ami
  instance_type = var.splunk_instance_type
  subnet_id = var.subnetCid
  vpc_security_group_ids = [
    aws_security_group.splunk_sg_license_server.id]
  key_name = var.key_name
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.id
  user_data = data.template_file.splunk_l_server_init.rendered
  //  provisioner "file" {
  //    content = data.aws_s3_bucket_object.splunk_license_file.body
  //    destination = var.splunk_license_file_path
  //  }
  //
  //  provisioner "remote-exec" {
  //    inline = [
  //      "sudo -u splunk aws s3 cp s3://${var.splunk_license_bucket}/${var.splunk_license_file} /data/gmnts/splunk/etc/"
  //      // "aws s3  https://gtos-gmnts-splunk-license.s3.us-east-1.amazonaws.com/Splunk.License /data/gmnts/splunk/etc/"
  //    ]
  //
  //    connection {
  //      bastion_private_key = var.bastion_key
  //      bastion_user = var.bastion_user
  //      user = var.ec2_user
  //      private_key = var.splunk_license_master_key
  //      bastion_host = aws_spot_instance_request.bastionH_WindowsUser.0.public_ip
  //      host = aws_instance.splunk_license_server.private_ip
  //      timeout = "10m"
  //      type = "ssh"
  //    }
  //}
  tags = {
    Name = "${var.project_name}-License Server"
  }
}

#splunk security group for license server
resource "aws_security_group" "splunk_sg_license_server" {
  name = "gtos_splunk_license_server_sg"
  description = "security group for splunk license server"
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
      var.subnetBCIDR,
      var.subnetCCIDR,
      var.subnetDCIDR]
  }


  #splunk-mgmt
  ingress {
    from_port = var.splunk_mgmt_port
    to_port = var.splunk_mgmt_port
    protocol = "tcp"
    cidr_blocks = [
      var.subnetACIDR,
      var.subnetBCIDR,
      var.subnetCCIDR,
      var.subnetDCIDR]
  }

  #SSH
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [
      var.subnetCCIDR]
  }

  #splunk-web
  egress {
    from_port = var.splunk_web_port
    to_port = var.splunk_web_port
    protocol = "tcp"
    cidr_blocks = [
      var.subnetACIDR,
      var.subnetBCIDR,
      var.subnetCCIDR,
      var.subnetDCIDR]
  }


  #splunk-mgmt
  egress {
    from_port = var.splunk_mgmt_port
    to_port = var.splunk_mgmt_port
    protocol = "tcp"
    cidr_blocks = [
      var.subnetACIDR,
      var.subnetBCIDR,
      var.subnetCCIDR,
      var.subnetDCIDR]
  }

  #rest call to s3 from awscli
  egress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    prefix_list_ids = [
      aws_vpc_endpoint.s3.prefix_list_id]
  }

  egress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    prefix_list_ids = [
      aws_vpc_endpoint.s3.prefix_list_id]

  }

}

# Request a spot instance - bastion host
resource "aws_spot_instance_request" "bastionH_WindowsUser" {
  count = 1
  ami = var.ec2_ami[count.index]
  instance_type = var.bastion_instance_type
  spot_price = var.spot_price
  spot_type = "one-time"
  #block_duration_minutes = 60
  #valid_until="2020-03-21T13:00:00-07:00"
  key_name = var.key_name
  subnet_id = var.subnetAid
  vpc_security_group_ids = [
    [
      aws_security_group.bastionH_sg.id,
      aws_security_group.WinUser_sg.id][count.index]]
  tags = {
    Name = "${var.bastion_windows_name[count.index]}"
  }
}


resource "aws_security_group" "bastionH_sg" {
  vpc_id = var.vpc_id
  name = "bastionH_public_sg"
  description = "Used for accessing bastion host"

  #SSH
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [
      var.accessip]
  }

  egress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [
      var.subnetACIDR,
      var.subnetBCIDR,
      var.subnetCCIDR,
      var.subnetDCIDR]
  }
}

resource "aws_security_group" "WinUser_sg" {
  vpc_id = var.vpc_id
  name = "WinUser_public_sg"
  description = "Used for accessing bastion host"

  #RDP
  ingress {
    from_port = 3389
    to_port = 3389
    protocol = "tcp"
    cidr_blocks = [
      var.accessip]
  }

  egress {
    from_port = var.splunk_web_port
    to_port = var.splunk_web_port
    protocol = "tcp"
    cidr_blocks = [
      var.subnetACIDR,
      var.subnetBCIDR,
      var.subnetCCIDR,
      var.subnetDCIDR]
  }
}
