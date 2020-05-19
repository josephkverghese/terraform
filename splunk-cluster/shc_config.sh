#!/bin/bash -xe
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1
sudo -u splunk echo -e "[general]\nserverName = "$(curl http://169.254.169.254/latest/meta-data/local-hostname)"-sh" >/data/gmnts/splunk/etc/system/local/server.conf
sudo -u splunk echo -e "[default]\nhost = "$(curl http://169.254.169.254/latest/meta-data/local-hostname)"-sh" >/data/gmnts/splunk/etc/system/local/inputs.conf
sudo -u splunk /data/gmnts/splunk/bin/splunk edit licenser-localslave -master_uri 'https://${license_master_hostname}:${splunkmgmt}' -auth admin:${splunkadminpass}
sudo -u splunk /data/gmnts/splunk/bin/splunk init shcluster-config -auth admin:${splunkadminpass} -mgmt_uri https://"$(curl http://169.254.169.254/latest/meta-data/local-hostname)":${splunkmgmt} -replication_port ${splunkshcrepport} -replication_factor ${splunkshcrepfact} -conf_deploy_fetch_url https://${deployer_ip}:${splunkmgmt} -secret ${shclusterkey} -shcluster_label ${shclusterlabel}
service splunk restart

#hosts=""
#splunkasg=${splunkshcasgname}
#
#if (( ${shcmemberindex}==$(aws ec2 describe-tags --region us-east-1 \
#     --filters "Name=resource-id,Values=$(curl 169.254.169.254/latest/meta-data/instance-id)" \
#               "Name=key,Values=${asgindex}" --query Tags[].Value --output text) )); then
#
#    for i in $(aws ec2 describe-instances --region us-east-1 --instance-ids \
#       $(aws autoscaling describe-auto-scaling-instances --region us-east-1 --output text  \
#             --query "AutoScalingInstances[?AutoScalingGroupName=='$splunkasg'].InstanceId") \
#       --query "Reservations[].Instances[].PrivateDnsName" \
#       --filters Name=instance-state-name,Values=running --output text)
#    do
#        hosts+="https://$i:8089,"
#    done
#
#    hosts=$${hosts:0:-1}
#    sudo -u splunk /data/gmnts/splunk/bin/splunk bootstrap shcluster-captain -servers_list $hosts -auth admin:${splunkadminpass}
#    service splunk restart
#fi

splunkasg=${splunkshcasgname}
ready=false
readycount=0
shcmem=""
k=$(((RANDOM % 100 + 1)))
echo "sleeping "$k" seconds"
sleep $k
echo "resuming now..."
for i in $(
  aws ec2 describe-instances --region us-east-1 --instance-ids \
  $(
    aws autoscaling describe-auto-scaling-instances --region us-east-1 --output text \
    --query "AutoScalingInstances[].[AutoScalingGroupName,InstanceId]" |grep -P "SHC.+\$splunkasg" |cut -f 2
  ) \
  --query "Reservations[].Instances[].PrivateDnsName" \
  --filters Name=instance-state-name,Values=running --output text
); do
  host="https://$i:8089"
  shcmem+="https://$i:8089,"
  ready="false"
  retry=0
  while [[ "$ready" == false && "$retry" != ${shc_init_check_retry_count} ]]; do
    echo "checking..."$host
    if (($(curl -sk $host/services/shcluster/config -u admin:gmntssplunk | grep -oP '(?<=shcluster_label">)[^<]+') == ${shclusterlabel})); then
      echo "host is ready"
      ready="true"
      ((readycount += 1))
    else
      sleep ${shc_init_check_retry_sleep_wait}
      ((retry += 1))
    fi
  done
done
if [[ "$readycount" == ${shcmembercount} ]]; then
  echo "setting shc captain...."
  shcmem=$${shcmem:0:-1}
  service splunk restart
  sudo -u splunk /data/gmnts/splunk/bin/splunk bootstrap shcluster-captain -servers_list $shcmem -auth admin:${splunkadminpass}
  service splunk restart
  #integrate search head cluster with ixr cluster - run in only one search head
  sudo -u splunk /data/gmnts/splunk/bin/splunk edit cluster-config -mode searchhead -master_uri 'https://${ixrcmaster}:${splunkmgmt}' -secret ${ixrckey} -auth admin:${splunkadminpass}
else
  echo "node "$host" not ready..exiting..."
  exit 1
fi
