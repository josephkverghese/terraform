#create a cloudwatch log group for this project
resource "aws_cloudwatch_log_group" "log_group" {
  name              = var.cloudwatch_loggroup_name
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
  name       = "splunk_ec2_attach"
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  roles = [
  aws_iam_role.splunk_ec2_role.id]
}

#attach the policy to the iam role
resource "aws_iam_policy_attachment" "splunk_ec2_attach1" {
  name       = "splunk_ec2_attach"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
  roles = [
  aws_iam_role.splunk_ec2_role.id]
}

#attach the policy to the iam role
resource "aws_iam_policy_attachment" "splunk_ec2_attach2" {
  name       = "splunk_ec2_attach"
  policy_arn = "arn:aws:iam::aws:policy/AutoScalingReadOnlyAccess"
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
  template = file("${path.module}/cloudwatch_config.sh")
  vars = {
    cw_log_group = var.project_name
  }
}

#single node splunk

#conditional resource. Deployed only for splunk single node
resource "aws_instance" "splunk" {
  count         = var.enable_splunk_shc ? 0 : 1
  ami           = var.splunk-ami
  instance_type = var.splunk_instance_type
  subnet_id     = var.subnetAid
  vpc_security_group_ids = [
  aws_security_group.splunk_sg_single_node[0].id]
  key_name             = var.key_name
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.id
  user_data            = data.template_file.cloud_watch.rendered
  tags = {
    Name = var.instance_name
  }
}

#public single node splunk instance security group
resource "aws_security_group" "splunk_sg_single_node" {
  count       = var.enable_splunk_shc ? 0 : 1
  name        = "gtos_public_splunk_sg_single_node"
  description = "security group to allow access to public single node splunk instance"
  vpc_id      = var.vpc_id

  #splunk-web
  ingress {
    from_port = var.splunk_web_port
    to_port   = var.splunk_web_port
    protocol  = "tcp"
    security_groups = [
    aws_security_group.splunk_sg_alb.0.id]
    cidr_blocks = [
      var.subnetACIDR,
      var.subnetBCIDR,
      var.subnetCCIDR,
    var.subnetDCIDR]
  }


  #splunk-mgmt,rep
  ingress {
    from_port = var.splunk_mgmt_port
    to_port   = var.splunkshcrepport
    protocol  = "tcp"
    security_groups = [
    aws_security_group.splunk_sg_alb.0.id]
    cidr_blocks = [
      var.subnetACIDR,
      var.subnetBCIDR,
      var.subnetCCIDR,
    var.subnetDCIDR]
  }

  #SSH
  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = [
    var.subnetCCIDR]
  }

  #splunk-web
  egress {
    from_port = var.splunk_web_port
    to_port   = var.splunk_web_port
    protocol  = "tcp"
    security_groups = [
    aws_security_group.splunk_sg_alb.0.id]
    cidr_blocks = [
      var.subnetACIDR,
      var.subnetBCIDR,
      var.subnetCCIDR,
    var.subnetDCIDR]
  }


  #splunk-mgmt,rep
  egress {
    from_port = var.splunk_mgmt_port
    to_port   = var.splunkshcrepport
    protocol  = "tcp"
    security_groups = [
    aws_security_group.splunk_sg_alb.0.id]
    cidr_blocks = [
      var.subnetACIDR,
      var.subnetBCIDR,
      var.subnetCCIDR,
    var.subnetDCIDR]
  }

}


#splunk indexer cluster
#ixr master
#ixr members


#init logic for ixr master
data "template_file" "ixrcmaster_init" {
  template = file("${path.module}/ixrcmaster_config.sh")

  vars = {
    splunkixrcrepport       = var.splunkixrcrepport
    ixrcrepf                = var.ixrcrepf
    ixrcsf                  = var.ixrcsf
    license_master_hostname = var.license_server_hostname
    splunk_mgmt_port        = var.splunk_mgmt_port
    splunkadminpass         = var.splunkadminpass
    ixrckey                 = var.ixrckey
    ixrclabel               = var.ixrclabel
  }
}

data "template_cloudinit_config" "ixrcmaster_cloud_init" {
  gzip          = false
  base64_encode = false

  # cloud-config configuration file for cloudwatch.
  part {
    filename     = "cloud_watch.sh"
    content_type = "text/x-shellscript"
    content      = data.template_file.cloud_watch.rendered
  }
  part {
    filename     = "ixrcmaster.sh"
    content_type = "text/x-shellscript"
    content      = data.template_file.ixrcmaster_init.rendered
  }
}

# splunk ixrc master
# start with base splunk ami
# add ixrc master clustering stanza
# add as a slave to splunk license master
resource "aws_instance" "splunk_ixrcmaster" {
  count         = var.enable_splunk_shc ? 1 : 0
  ami           = var.splunk-ami
  instance_type = var.splunk_instance_type
  subnet_id     = var.subnetAid
  vpc_security_group_ids = [
  aws_security_group.splunk_sg_ixrc.0.id]
  key_name             = var.key_name
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.id
  user_data            = data.template_cloudinit_config.ixrcmaster_cloud_init.rendered
  tags = {
    Name = "${var.project_name}-IXRCMaster"
  }
}


data "template_file" "ixrc_init" {

  template = file("${path.module}/ixrc_config.sh")

  vars = {
    splunkixrcrepport       = var.splunkixrcrepport
    ixrcmaster              = aws_instance.splunk_ixrcmaster.0.private_dns
    ixrckey                 = var.ixrckey
    shcmembercount          = var.shcmembercount
    license_master_hostname = var.license_server_hostname
    splunkmgmt              = var.splunk_mgmt_port
    splunkadminpass         = var.splunkadminpass
    splunkingest            = var.splunk_ingest_port
  }
}

data "template_cloudinit_config" "ixrc_cloud_init" {
  gzip          = false
  base64_encode = false

  # cloud-config configuration file for cloudwatch.
  part {
    filename     = "cloud_watch.sh"
    content_type = "text/x-shellscript"
    content      = data.template_file.cloud_watch.rendered
  }
  part {
    filename     = "ixrc.sh"
    content_type = "text/x-shellscript"
    content      = data.template_file.ixrc_init.rendered
  }
}

#security group for all splunk ixrc nodes
#allows access from shc to splunk mgmt port
#allows ssh from the bastion host subnet
resource "aws_security_group" "splunk_sg_ixrc" {
  count       = var.enable_splunk_shc ? 1 : 0
  name        = "gtos_splunk_sg_ixrc"
  description = "Used by members for splunk ixrc"
  vpc_id      = var.vpc_id

  #splunk-mgmt,rep
  ingress {
    from_port = var.splunk_mgmt_port
    to_port   = var.splunk_mgmt_port
    protocol  = "tcp"
    cidr_blocks = [
      var.subnetACIDR,
    var.subnetBCIDR]
  }

  ingress {
    from_port = var.splunkixrcrepport
    to_port   = var.splunkixrcrepport
    protocol  = "tcp"
    cidr_blocks = [
      var.subnetACIDR,
    var.subnetBCIDR]

  }

  #splunk-mgmt,rep
  egress {
    from_port = var.splunk_mgmt_port
    to_port   = var.splunk_mgmt_port
    protocol  = "tcp"
    cidr_blocks = [
      var.subnetACIDR,
    var.subnetBCIDR]

  }

  egress {
    from_port = var.splunkixrcrepport
    to_port   = var.splunkixrcrepport
    protocol  = "tcp"
    cidr_blocks = [
      var.subnetACIDR,
    var.subnetBCIDR]
  }

  #for aws cli
  egress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"
    cidr_blocks = [
    "0.0.0.0/0"]
  }

  #for aws cli
  egress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    cidr_blocks = [
    "0.0.0.0/0"]
  }

  #SSH
  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = [
    var.subnetCCIDR]
  }

  #splunk ingest port
  ingress {
    from_port = var.splunk_ingest_port
    to_port   = var.splunk_ingest_port
    protocol  = "tcp"
    cidr_blocks = [
    "0.0.0.0/0"]
  }

}


resource "aws_launch_configuration" "splunk_ixrc" {
  # Launch Configurations cannot be updated after creation with the AWS API.
  # In order to update a Launch Configuration, Terraform will destroy the
  # existing resource and create a replacement.
  # We're only setting the name_prefix here,
  # Terraform will add a random string at the end to keep it unique.
  name_prefix   = "Splunk-IXRC-launch-conf-${var.project_name}"
  count         = var.enable_splunk_shc ? 1 : 0
  image_id      = var.splunk-ami
  instance_type = var.splunk_instance_type
  security_groups = [
  aws_security_group.splunk_sg_ixrc.0.id]
  key_name             = var.key_name
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.id
  user_data            = data.template_cloudinit_config.ixrc_cloud_init.rendered
  ebs_block_device {
    device_name = "/dev/sdf"
    volume_type = "standard"
    volume_size = var.splunk_ixrc_volume_size
  }
  root_block_device {
    volume_type = "standard"
    volume_size = var.splunk_ixrc_root_volume_size
  }
}

resource "aws_autoscaling_group" "splunk_ixrc" {
  # Force a redeployment when launch configuration changes.
  # This will reset the desired capacity if it was changed due to
  # autoscaling events.
  depends_on = [
  aws_instance.splunk_ixrcmaster]
  count                = var.enable_splunk_shc ? 1 : 0
  name_prefix          = "Splunk-IXRC-asg-${var.project_name}"
  min_size             = var.ixrcmembercount
  desired_capacity     = var.ixrcmembercount
  max_size             = var.ixrcmembercount
  health_check_type    = "EC2"
  launch_configuration = aws_launch_configuration.splunk_ixrc.0.name
  vpc_zone_identifier = [
    var.subnetAid,
  var.subnetBid]

  # Required to redeploy without an outage.
  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    propagate_at_launch = true
    value               = "Splunk-IXRC-asg-${var.project_name}"
  }
  tag {
    key                 = var.asgindex
    propagate_at_launch = true
    value               = count.index
  }
}


#########IXR Cluster logic ends#######

#splunk shc
#deployer- init,deployer
#SHs - launch config,auto scaling group
#ALB - alb, alb listener, target group, autoscaling attachment

#init logic for deployer
data "template_file" "deployer_init" {
  template = file("${path.module}/deployer_config.sh")

  vars = {
    license_master_hostname = var.license_server_hostname
    splunk_mgmt_port        = var.splunk_mgmt_port
    splunkadminpass         = var.splunkadminpass
    shclusterkey            = var.project_name
    shclusterlabel          = var.project_name
    splunkingest            = var.splunk_ingest_port
    project_name            = var.project_name
    splunkixrasgname        = aws_autoscaling_group.splunk_ixrc.0.name
  }
}

data "template_cloudinit_config" "deployer_cloud_init" {
  gzip          = false
  base64_encode = false

  # cloud-config configuration file for cloudwatch.
  part {
    filename     = "cloud_watch.sh"
    content_type = "text/x-shellscript"
    content      = data.template_file.cloud_watch.rendered
  }
  part {
    filename     = "deployer.sh"
    content_type = "text/x-shellscript"
    content      = data.template_file.deployer_init.rendered
  }
}

# splunk deployer
# start with base splunk ami
# add sh clustering stanza
# add as a slave to splunk license master
resource "aws_instance" "splunk_deployer" {
  count         = var.enable_splunk_shc ? 1 : 0
  ami           = var.splunk-ami
  instance_type = var.splunk_instance_type
  subnet_id     = var.subnetAid
  vpc_security_group_ids = [
  aws_security_group.splunk_sg_shc.0.id]
  key_name             = var.key_name
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.id
  user_data            = data.template_cloudinit_config.deployer_cloud_init.rendered
  tags = {
    Name = "${var.project_name}-Deployer"
  }
}

#SHC
//data "template_file" "set_shc_captain" {
//
//  template = file("${path.module}/set_shc_captain.sh")
//
//  vars = {
//    shclusterlabel = var.project_name
//    splunkshcasgname = "Splunk-SHC-asg-${var.project_name}"
//    shcmembercount = var.shcmembercount
//    shc_init_check_retry_count = var.shc_init_check_retry_count
//    shc_init_check_retry_sleep_wait = var.shc_init_check_retry_sleep_wait
//    splunkadminpass = var.splunkadminpass
//  }
//}
data "template_file" "shc_init" {

  template = file("${path.module}/shc_config.sh")

  vars = {
    shcmembercount                  = var.shcmembercount
    license_master_hostname         = var.license_server_hostname
    deployer_ip                     = aws_instance.splunk_deployer.0.private_ip
    shclusterlabel                  = var.project_name
    shclusterkey                    = var.shclusterkey
    splunkmgmt                      = var.splunk_mgmt_port
    splunkadminpass                 = var.splunkadminpass
    splunkshcrepfact                = var.splunkshcrepfact
    splunkshcrepport                = var.splunkshcrepport
    splunkshcasgname                = "Splunk-SHC-asg-${var.project_name}"
    shcmemberindex                  = var.shcmemberindex_captain
    asgindex                        = var.asgindex
    shc_init_check_retry_count      = var.shc_init_check_retry_count
    shc_init_check_retry_sleep_wait = var.shc_init_check_retry_sleep_wait
    ixrcmaster                      = aws_instance.splunk_ixrcmaster.0.private_dns
    ixrckey                         = var.ixrckey
    splunkingest                    = var.splunk_ingest_port
    project_name                    = var.project_name
  }
}

data "template_cloudinit_config" "shc_cloud_init" {
  gzip          = false
  base64_encode = false

  # cloud-config configuration file for cloudwatch.
  part {
    filename     = "cloud_watch.sh"
    content_type = "text/x-shellscript"
    content      = data.template_file.cloud_watch.rendered
  }
  part {
    filename     = "shc.sh"
    content_type = "text/x-shellscript"
    content      = data.template_file.shc_init.rendered
  }
  //  part {
  //    filename = "setcaptain.sh"
  //    content_type = "text/x-shellscript"
  //    content = data.template_file.set_shc_captain.rendered
  //  }
}

#security group for all splunk shc nodes
#allows access from alb to splunk web port,splunk mgmt port
#allows ssh from the bastion host subnet
resource "aws_security_group" "splunk_sg_shc" {
  count       = var.enable_splunk_shc ? 1 : 0
  name        = "gtos_splunk_sg_shc"
  description = "Used by members for splunk shc"
  vpc_id      = var.vpc_id

  #splunk-web
  ingress {
    from_port = var.splunk_web_port
    to_port   = var.splunk_web_port
    protocol  = "tcp"
    security_groups = [
    aws_security_group.splunk_sg_alb.0.id]
    cidr_blocks = [
      var.subnetACIDR,
      var.subnetBCIDR,
      var.subnetCCIDR,
    var.subnetDCIDR]
  }


  #splunk-mgmt,rep
  ingress {
    from_port = var.splunk_mgmt_port
    to_port   = var.splunkshcrepport
    protocol  = "tcp"
    security_groups = [
    aws_security_group.splunk_sg_alb.0.id]
    cidr_blocks = [
      var.subnetACIDR,
      var.subnetBCIDR,
      var.subnetCCIDR,
    var.subnetDCIDR]
  }

  #splunk-web
  egress {
    from_port = var.splunk_web_port
    to_port   = var.splunk_web_port
    protocol  = "tcp"
    security_groups = [
    aws_security_group.splunk_sg_alb.0.id]
    cidr_blocks = [
      var.subnetACIDR,
      var.subnetBCIDR,
      var.subnetCCIDR,
    var.subnetDCIDR]
  }


  #splunk-mgmt
  egress {
    from_port = var.splunk_mgmt_port
    to_port   = var.splunk_mgmt_port
    protocol  = "tcp"
    security_groups = [
    aws_security_group.splunk_sg_alb.0.id]
    cidr_blocks = [
      var.subnetACIDR,
      var.subnetBCIDR
    ]
  }

  egress {
    from_port = var.splunkshcrepport
    to_port   = var.splunkshcrepport
    protocol  = "tcp"
    security_groups = [
    aws_security_group.splunk_sg_alb.0.id]
    cidr_blocks = [
      var.subnetACIDR,
    var.subnetBCIDR]
  }

  egress {
    from_port = var.splunk_ingest_port
    to_port   = var.splunk_ingest_port
    protocol  = "tcp"
    security_groups = [
    aws_security_group.splunk_sg_alb.0.id]
    cidr_blocks = [
      var.subnetACIDR,
    var.subnetBCIDR]
  }

  egress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"
    security_groups = [
    aws_security_group.splunk_sg_alb.0.id]
    cidr_blocks = [
    "0.0.0.0/0"]
  }

  egress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    security_groups = [
    aws_security_group.splunk_sg_alb.0.id]
    cidr_blocks = [
    "0.0.0.0/0"]
  }

  #SSH
  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = [
    var.subnetCCIDR]
  }

}

resource "aws_launch_configuration" "splunk_sh" {
  # Launch Configurations cannot be updated after creation with the AWS API.
  # In order to update a Launch Configuration, Terraform will destroy the
  # existing resource and create a replacement.
  # We're only setting the name_prefix here,
  # Terraform will add a random string at the end to keep it unique.
  name_prefix   = "Splunk-SHC-launch-conf-${var.project_name}"
  count         = var.enable_splunk_shc ? 1 : 0
  image_id      = var.splunk-ami
  instance_type = var.splunk_instance_type
  security_groups = [
  aws_security_group.splunk_sg_shc.0.id]
  key_name             = var.key_name
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.id
  user_data            = data.template_cloudinit_config.shc_cloud_init.rendered
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
  depends_on = [
  aws_autoscaling_group.splunk_ixrc]
  count                = var.enable_splunk_shc ? 1 : 0
  name_prefix          = "Splunk-SHC-asg-${var.project_name}"
  min_size             = var.shcmembercount
  desired_capacity     = var.shcmembercount
  max_size             = var.shcmembercount
  health_check_type    = "EC2"
  launch_configuration = aws_launch_configuration.splunk_sh.0.name
  vpc_zone_identifier = [
    var.subnetAid,
  var.subnetBid]

  # Required to redeploy without an outage.
  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    propagate_at_launch = true
    value               = "Splunk-SHC-asg-${var.project_name}"
  }
  tag {
    key                 = var.asgindex
    propagate_at_launch = true
    value               = count.index
  }
}
//
//  tags = [
//    map("key", "Name", "value", "splunk-sh", "propagate_at_launch", true)]


# ALB

#public splunk alb security group
resource "aws_security_group" "splunk_sg_alb" {
  count       = var.enable_splunk_shc ? 1 : 0
  name        = "gtos_public_splunk_sg_alb"
  description = "Used for access to public splunk alb"
  vpc_id      = var.vpc_id

  #splunk-web
  ingress {
    from_port   = var.splunk_web_port
    to_port     = var.splunk_web_port
    protocol    = "tcp"
    cidr_blocks = var.accessip
  }

  egress {
    from_port = var.splunk_web_port
    to_port   = var.splunk_web_port
    protocol  = "tcp"
    cidr_blocks = [
      var.subnetACIDR,
    var.subnetBCIDR]
  }
}

resource "aws_alb" "splunk_shc_alb" {
  count              = var.enable_splunk_shc ? 1 : 0
  name               = var.splunk_shc_alb
  internal           = false
  load_balancer_type = "application"
  security_groups = [
  aws_security_group.splunk_sg_alb.0.id]
  subnets = [
    var.subnetCid,
  var.subnetDid]
  //  enable_deletion_protection = true

  tags = {
    Environment = "production"
  }
}

resource "aws_alb_listener" "alb_listener" {
  count             = var.enable_splunk_shc ? 1 : 0
  load_balancer_arn = aws_alb.splunk_shc_alb.0.arn
  port              = var.splunk_web_port
  protocol          = var.alb_listener_protocol

  default_action {
    target_group_arn = aws_alb_target_group.splunk_shs.0.arn
    type             = "forward"
  }
}


resource "aws_alb_target_group" "splunk_shs" {
  count    = var.enable_splunk_shc ? 1 : 0
  name     = "shc-target-group"
  port     = var.splunk_web_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  stickiness {
    type            = "lb_cookie"
    cookie_duration = 1800
    enabled         = true
  }
  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 10
    timeout             = 5
    interval            = 10
    path                = "/"
    port                = var.splunk_web_port
  }

}

#Autoscaling Attachment
resource "aws_autoscaling_attachment" "splunk_shc_target" {
  count                  = var.enable_splunk_shc ? 1 : 0
  alb_target_group_arn   = aws_alb_target_group.splunk_shs.0.arn
  autoscaling_group_name = aws_autoscaling_group.splunk_shc.0.id
}


resource "null_resource" "get_sh_ip" {
  count = var.enable_splunk_shc ? 1 : 0
  depends_on = [
  aws_autoscaling_group.splunk_shc]
  provisioner "local-exec" {
    command = "aws ec2 describe-instances --region us-east-1 --instance-ids $(aws autoscaling describe-auto-scaling-instances --region us-east-1 --output text --query 'AutoScalingInstances[].[AutoScalingGroupName,InstanceId]'| grep -P ${aws_autoscaling_group.splunk_shc.0.name}| cut -f 2) --query 'Reservations[].Instances[].PrivateIpAddress' --filters Name=instance-state-name,Values=running --output text|cut -f 1 > /opt/terraform/work/out.txt"
  }
}


data "local_file" "sh_ip" {
  count = var.enable_splunk_shc ? 1 : 0
  depends_on = [
  null_resource.get_sh_ip]
  filename = "/opt/terraform/work/out.txt"
}


data "template_file" "shc_config_postprocess" {

  count    = var.enable_splunk_shc ? 1 : 0
  template = file("${path.module}/shc_config_postprocess.sh")

  vars = {
    shcmembercount                  = var.shcmembercount
    shclusterlabel                  = var.project_name
    splunkshcasgname                = aws_autoscaling_group.splunk_shc.0.name
    shc_init_check_retry_count      = var.shc_init_check_retry_count
    shc_init_check_retry_sleep_wait = var.shc_init_check_retry_sleep_wait
    project_name                    = var.project_name
    splunkadminpass                 = var.splunkadminpass
  }
}


resource "null_resource" "bootstrap_splunk_shc" {
  count = var.enable_splunk_shc ? 1 : 0
  depends_on = [
    aws_autoscaling_group.splunk_shc,
  null_resource.get_sh_ip]
  provisioner "file" {
    content     = data.template_file.shc_config_postprocess.0.rendered
    destination = "/tmp/shc_config_postprocess.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/shc_config_postprocess.sh",
      "/tmp/shc_config_postprocess.sh",
    ]
  }

  connection {
    bastion_private_key = var.pvt_key
    bastion_user        = var.ec2-user
    user                = var.ec2-user
    private_key         = var.pvt_key
    bastion_host        = var.bastion_public_ip
    host                = data.local_file.sh_ip.0.content
    timeout             = "3m"
    type                = "ssh"
  }

}