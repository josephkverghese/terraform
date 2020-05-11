#create a cloudwatch log group for this project
resource "aws_cloudwatch_log_group" "log_group" {
  name = var.cloudwatch_loggroup_name
  retention_in_days = var.cloudwatch_retention
}

//resource "aws_iam_role" "log_group_role" {
//  name = "log_group_role"
//  path = "/"
//  # who can assume this role
//  assume_role_policy = <<EOF
//{
//    "Version": "2012-10-17",
//    "Statement": [
//        {
//            "Action": "sts:AssumeRole",
//            "Principal": {
//               "Service": "ec2.amazonaws.com"
//            },
//            "Effect": "Allow",
//            "Sid": ""
//        }
//    ]
//}
//EOF
//}


#policy that allows access to publish to the above log group
//
//data "aws_iam_policy_document" "log_group_policy_doc" {
//  statement {
//    sid = "1"
//
//    effect = "Allow"
//    actions = [
//      "cloudwatch:PutMetricData",
//      "ec2:DescribeVolumes",
//      "ec2:DescribeTags",
//      "logs:PutLogEvents",
//      "logs:DescribeLogStreams",
//      "logs:DescribeLogGroups",
//      "logs:CreateLogStream",
//      "logs:CreateLogGroup"
//    ]
//    resources = [
//      aws_cloudwatch_log_group.log_group.arn
//    ]
//  }
//}

//resource "aws_iam_policy" "log_group_policy" {
//  policy = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
//}


resource "aws_iam_role" "splunk_ec2_role" {
  name = "splunk_ec2_role-${var.project_name}"
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

#common cloud init script for cloudwatch
#customize log group name as per project and start agent
data template_file "cloud_watch" {
  template = file("${path.module}/cloudwatch_config")
  vars = {
    cw_log_group = var.project_name
  }
}

#single node splunk

#conditional resource. Deployed only for splunk single node
resource "aws_instance" "splunk" {
  count = var.enable_splunk_shc ? 0 : 1
  ami = var.splunk-ami
  instance_type = var.splunk_instance_type
  subnet_id = var.subnetAid
  vpc_security_group_ids = [
    aws_security_group.splunk_sg_single_node[0].id]
  key_name = var.key_name
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.id
  user_data = data.template_file.cloud_watch.rendered
  tags = {
    Name = var.instance_name
  }
}

#public single node splunk instance security group
resource "aws_security_group" "splunk_sg_single_node" {
  count = var.enable_splunk_shc ? 0 : 1
  name = "gtos_public_splunk_sg_single_node"
  description = "security group to allow access to public single node splunk instance"
  vpc_id = var.vpc_id

  #SSH

  ingress {
    from_port = 22
    to_port = 22
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

}

#splunk shc
#deployer- init,deployer
#SHs - launch config,auto scaling group
#ALB - alb, alb listener, target group, autoscaling attachment

#init logic for deployer
data "template_file" "deployer_init" {
  template = file("${path.module}/deployer_config")

  vars = {
    license_master_hostname = var.license_server_hostname
    splunk_mgmt_port = var.splunk_mgmt_port
    splunkadminpass = var.splunkadminpass
    shclusterkey = var.project_name
    shclusterlabel = var.project_name
  }
}

data "template_cloudinit_config" "deployer_cloud_init" {
  gzip = false
  base64_encode = false

  # cloud-config configuration file for cloudwatch.
  part {
    filename = "init.cfg"
    content_type = "text/cloud-config"
    content = data.template_file.cloud_watch.rendered
  }
  part {
    filename = "init.cfg"
    content_type = "text/cloud-config"
    content = data.template_file.deployer_init.rendered
  }
}

# splunk deployer
# start with base splunk ami
# add sh clustering stanza
# add as a slave to splunk license master
resource "aws_instance" "splunk_deployer" {
  count = var.enable_splunk_shc ? 1 : 0
  ami = var.splunk-ami
  instance_type = var.splunk_instance_type
  subnet_id = var.subnetAid
  vpc_security_group_ids = [
    aws_security_group.splunk_sg_shc.0.id]
  key_name = var.key_name
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.id
  user_data = data.template_cloudinit_config.deployer_cloud_init.rendered
  tags = {
    Name = "${var.project_name}-Deployer"
  }
}

#SHC

data "template_file" "shc_init" {
  template = file("${path.module}/shc_config")

  vars = {
    license_master_hostname = var.license_server_hostname
    deployer_ip = aws_instance.splunk_deployer.0.private_ip
    shclusterlabel = var.project_name
    shclusterkey = var.shclusterkey
    splunkmgmt = var.splunk_mgmt_port
    splunkadminpass = var.splunkadminpass
    splunkshcrepfact = var.splunkshcrepfact
    splunkshcrepport = var.splunkshcrepport
  }
}

data "template_cloudinit_config" "shc_cloud_init" {
  gzip = false
  base64_encode = false

  # cloud-config configuration file for cloudwatch.
  part {
    filename = "init.cfg"
    content_type = "text/cloud-config"
    content = data.template_file.cloud_watch.rendered
  }
  part {
    filename = "init.cfg"
    content_type = "text/cloud-config"
    content = data.template_file.deployer_init.rendered
  }
}

resource "aws_security_group" "splunk_sg_shc" {
  count = var.enable_splunk_shc ? 1 : 0
  name = "gtos_public_splunk_sg_shc"
  description = "Used for access to splunk shc from alb"
  vpc_id = var.vpc_id

  #splunk-web

  ingress {
    from_port = var.splunk_web_port
    to_port = var.splunk_web_port
    protocol = "tcp"
    security_groups = [
      aws_security_group.splunk_sg_alb.0.id]
  }

  #SSH
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [
      var.subnetACIDR]
  }

}

resource "aws_launch_configuration" "splunk_sh" {
  # Launch Configurations cannot be updated after creation with the AWS API.
  # In order to update a Launch Configuration, Terraform will destroy the
  # existing resource and create a replacement.
  # We're only setting the name_prefix here,
  # Terraform will add a random string at the end to keep it unique.
  name_prefix = "splunk-sh-"
  count = var.enable_splunk_shc ? 1 : 0
  image_id = var.splunk-ami
  instance_type = var.splunk_instance_type
  security_groups = [
    aws_security_group.splunk_sg_shc.0.id]
  key_name = var.key_name
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.id
  user_data = data.template_cloudinit_config.shc_cloud_init.rendered
  lifecycle {
    create_before_destroy = true
  }
  ebs_block_device {
    device_name = "/dev/sdf"
    volume_type = "standard"
    volume_size = var.splunk_shc_volume_size
  }
  root_block_device {
    volume_type = "standard"
    volume_size = var.splunk_shc_root_volume_size
  }
}

resource "aws_autoscaling_group" "splunk_shc" {
  # Force a redeployment when launch configuration changes.
  # This will reset the desired capacity if it was changed due to
  # autoscaling events.
  count = var.enable_splunk_shc ? 1 : 0
  name = "${aws_launch_configuration.splunk_sh.0.name}-asg"
  min_size = 3
  desired_capacity = 3
  max_size = 3
  health_check_type = "EC2"
  launch_configuration = aws_launch_configuration.splunk_sh.0.name
  vpc_zone_identifier = [
    var.subnetAid,
    var.subnetBid]

  # Required to redeploy without an outage.
  lifecycle {
    create_before_destroy = true
  }

  tag {
    key = "Name"
    value = "${var.project_name}-splunk-sh-${[count.index]}"
    propagate_at_launch = true
}
}

# ALB

#public splunk alb security group
resource "aws_security_group" "splunk_sg_alb" {
count = var.enable_splunk_shc ? 1 : 0
name = "gtos_public_splunk_sg_alb"
description = "Used for access to public splunk alb"
vpc_id = var.vpc_id

#splunk-web
ingress {
from_port = var.splunk_web_port
to_port = var.splunk_web_port
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
var.subnetBCIDR]
}
}

resource "aws_alb" "splunk_shc_alb" {
count = var.enable_splunk_shc ? 1 : 0
name = var.splunk_shc_alb
internal = false
load_balancer_type = "application"
security_groups = [
aws_security_group.splunk_sg_alb.0.id]
subnets = [
var.subnetAid,
var.subnetBid]
//  enable_deletion_protection = true

tags = {
Environment = "production"
}
}

resource "aws_alb_listener" "alb_listener" {
count = var.enable_splunk_shc ? 1 : 0
load_balancer_arn = aws_alb.splunk_shc_alb.0.arn
port = var.splunk_web_port
protocol = var.alb_listener_protocol

default_action {
target_group_arn = aws_alb_target_group.splunk_shs.0.arn
type = "forward"
}
}


resource "aws_alb_target_group" "splunk_shs" {
count = var.enable_splunk_shc ? 1 : 0
name = "shc-target-group"
port = var.splunk_web_port
protocol = "HTTP"
vpc_id = var.vpc_id
stickiness {
type = "lb_cookie"
cookie_duration = 1800
enabled = true
}
health_check {
healthy_threshold = 3
unhealthy_threshold = 10
timeout = 5
interval = 10
path = "/"
port = var.splunk_web_port
}

}

#Autoscaling Attachment
resource "aws_autoscaling_attachment" "splunk_shc_target" {
count = var.enable_splunk_shc ? 1 : 0
alb_target_group_arn = aws_alb_target_group.splunk_shs.0.arn
autoscaling_group_name = aws_autoscaling_group.splunk_shc.0.id
}