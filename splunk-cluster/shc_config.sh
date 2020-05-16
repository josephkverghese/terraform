#!/bin/bash -xe
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
sudo -u splunk /data/gmnts/splunk/bin/splunk edit licenser-localslave -master_uri 'https://${license_master_hostname}:${splunkmgmt}' -auth admin:${splunkadminpass}
sudo -u splunk /data/gmnts/splunk/bin/splunk init shcluster-config -auth admin:${splunkadminpass} -mgmt_uri https://"$(curl http://169.254.169.254/latest/meta-data/local-hostname)":${splunkmgmt} -replication_port ${splunkshcrepport} -replication_factor ${splunkshcrepfact} -conf_deploy_fetch_url https://${deployer_ip}:${splunkmgmt} -secret ${shclusterkey} -shcluster_label ${shclusterlabel}
service splunk restart
hosts=""
splunkasg=${splunkshcasgname}

if (( ${shcmemberindex}==$(aws ec2 describe-tags --region us-east-1 \
     --filters "Name=resource-id,Values=$(curl 169.254.169.254/latest/meta-data/instance-id)" \
               "Name=key,Values=${asgindex}" --query Tags[].Value --output text) )); then

    for i in $(aws ec2 describe-instances --region us-east-1 --instance-ids \
       $(aws autoscaling describe-auto-scaling-instances --region us-east-1 --output text  \
             --query "AutoScalingInstances[?AutoScalingGroupName=='$splunkasg'].InstanceId") \
       --query "Reservations[].Instances[].PrivateDnsName" \
       --filters Name=instance-state-name,Values=running --output text)
    do
        hosts+="https://$i:8089,"
    done

    hosts=$${hosts:0:-1}
    sudo -u splunk /data/gmnts/splunk/bin/splunk bootstrap shcluster-captain -servers_list $hosts -auth admin:${splunkadminpass}
    service splunk restart
fi
