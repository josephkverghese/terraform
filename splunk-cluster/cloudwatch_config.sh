#! /bin/bash
#customize the cloudwatch configuration as per the project
sed -i 's/gtos_gmnts_ec2_logs/${cw_log_group}/g' /data/gmnts/cloudwatch/cloudwatch_config
#run the agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/data/gmnts/cloudwatch/cloudwatch_config -s
