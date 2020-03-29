#create a log group for this project
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


resource "aws_instance" "splunk" {
  ami = var.splunk-ami
  instance_type = var.splunk_instance_type
  subnet_id = var.subnetid
  vpc_security_group_ids = [
    aws_security_group.splunk_sg.id]
  key_name = var.key_name
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.id
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


resource "aws_launch_configuration" "splunk_sh" {
  # Launch Configurations cannot be updated after creation with the AWS API.
  # In order to update a Launch Configuration, Terraform will destroy the
  # existing resource and create a replacement.
  #
  # We're only setting the name_prefix here,
  # Terraform will add a random string at the end to keep it unique.
  name_prefix = "splunk-sh-"

  image_id = var.splunk-ami
  instance_type = var.splunk_instance_type
  security_groups = aws_security_group.splunk_sg
  key_name = var.key_name
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.id
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "splunk_shc" {
  # Force a redeployment when launch configuration changes.
  # This will reset the desired capacity if it was changed due to
  # autoscaling events.
  name = "${aws_launch_configuration.splunk_sh.name}-asg"
  min_size = 3
  desired_capacity = 3
  max_size = 3
  health_check_type = "EC2"
  launch_configuration = aws_launch_configuration.splunk_sh.name
  vpc_zone_identifier = var.subnetid

  # Required to redeploy without an outage.
  lifecycle {
    create_before_destroy = true
  }
}


# ALB
resource "aws_alb" "splunk_shc_alb" {
  name = var.splunk_shc_alb
  internal = false
  load_balancer_type = "application"
  security_groups = [
    aws_security_group.splunk_sg.id]
  subnets = [
    var.subnetid]
  enable_deletion_protection = true

  tags = {
    Environment = "production"
  }
}

resource "aws_alb_listener" "alb_listener" {
  load_balancer_arn = aws_alb.splunk_shc_alb.arn
  port = var.alb_listener_port
  protocol = var.alb_listener_protocol

  default_action {
    target_group_arn = aws_alb_target_group.splunk_shs.arn
    type = "forward"
  }
}


resource "aws_alb_target_group" "splunk_shs" {
  name = "shc-target-group"
  port = var.splunk_sh_target_port
  protocol = "HTTP"
  vpc_id = var.splunk_shc_vpc
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
    port = var.splunk_sh_target_port
  }

}

#Autoscaling Attachment
resource "aws_autoscaling_attachment" "splunk_shc_target" {
  alb_target_group_arn = aws_alb_target_group.splunk_shs.arn
  autoscaling_group_name = aws_autoscaling_group.splunk_shc.id
}