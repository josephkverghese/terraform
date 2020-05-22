#!/bin/bash -xe
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
sudo -u splunk /data/gmnts/splunk/bin/splunk edit licenser-localslave -master_uri 'https://${license_master_hostname}:${splunk_mgmt_port}' -auth admin:${splunkadminpass}
sudo -u splunk echo -e "[general]\nserverName = "$(curl http://169.254.169.254/latest/meta-data/local-hostname)"-deployer" > /data/gmnts/splunk/etc/system/local/server.conf
sudo -u splunk echo -e  "[shclustering]\npass4SymmKey = ${shclusterkey}\nshcluster_label = ${shclusterlabel}" >> /data/gmnts/splunk/etc/system/local/server.conf
service splunk restart
#add outputs.conf to forward SH logs data to indexer cluster
ixrpeers=""
for i in $(sudo -u splunk /data/gmnts/splunk/bin/splunk list search-server|cut -c 16-35|cut -d':' -f 1|sed 's/$/:${splunkingest}/'); do
    ixrpeers+="$i,"
done
ixrpeers=$${ixrpeers:0:-1}
echo $ixrpeers
sudo -u splunk mkdir /data/gmnts/splunk/etc/apps/${project_name}
sudo -u splunk mkdir /data/gmnts/splunk/etc/apps/${project_name}/default
sudo -u splunk echo -e "[tcpout]\ndefaultGroup = ixrs\n[tcpout:ixrs]\nserver = $ixrpeers\n[indexAndForward]\nindex = false" > /data/gmnts/splunk/etc/apps/${project_name}/default/outputs.conf
chmod 774 -R /data/gmnts/splunk/etc/apps/${project_name}
service splunk restart
