#!/bin/bash -xe
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1
sudo -u splunk echo -e "[general]\nserverName = "$(curl http://169.254.169.254/latest/meta-data/local-hostname)"-sh" > /data/gmnts/splunk/etc/system/local/server.conf
sudo -u splunk echo -e "[default]\nhost = "$(curl http://169.254.169.254/latest/meta-data/local-hostname)"-sh" > /data/gmnts/splunk/etc/system/local/inputs.conf
sudo -u splunk /data/gmnts/splunk/bin/splunk edit licenser-localslave -master_uri 'https://${license_master_hostname}:${splunkmgmt}' -auth admin:${splunkadminpass}
service splunk restart
sudo -u splunk /data/gmnts/splunk/bin/splunk init shcluster-config -auth admin:${splunkadminpass} -mgmt_uri https://"$(curl http://169.254.169.254/latest/meta-data/local-hostname)":${splunkmgmt} -replication_port ${splunkshcrepport} -replication_factor ${splunkshcrepfact} -conf_deploy_fetch_url https://${deployer_ip}:${splunkmgmt} -secret ${shclusterkey} -shcluster_label ${shclusterlabel}
service splunk restart
#integrate search head cluster with ixr cluster - run on each search head
sudo -u splunk /data/gmnts/splunk/bin/splunk edit cluster-config -mode searchhead -master_uri 'https://${ixrcmaster}:${splunkmgmt}' -secret ${ixrckey} -auth admin:${splunkadminpass}
service splunk restart
#add outputs.conf to forward SH logs data to indexer cluster
ixrpeers=""
for i in $(sudo -u splunk /data/gmnts/splunk/bin/splunk list search-server -auth admin:${splunkadminpass}|cut -c 16-35|cut -d':' -f 1|sed 's/$/:${splunkingest}/'); do
    ixrpeers+="$i,"
done
ixrpeers=$${ixrpeers:0:-1}
echo $ixrpeers
sudo -u splunk mkdir /data/gmnts/splunk/etc/apps/${project_name}
sudo -u splunk mkdir /data/gmnts/splunk/etc/apps/${project_name}/default
sudo -u splunk echo -e "[tcpout]\ndefaultGroup = ixrs\n[tcpout:ixrs]\nserver = $ixrpeers\n[indexAndForward]\nindex = false" > /data/gmnts/splunk/etc/apps/${project_name}/default/outputs.conf
chmod 774 -R /data/gmnts/splunk/etc/apps/${project_name}
service splunk restart
#add indexes.conf