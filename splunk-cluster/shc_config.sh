#!/bin/bash -xe
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1
sudo -u splunk echo -e "[general]\nserverName = "$(curl http://169.254.169.254/latest/meta-data/local-hostname)"-sh" >/data/gmnts/splunk/etc/system/local/server.conf
sudo -u splunk echo -e "[default]\nhost = "$(curl http://169.254.169.254/latest/meta-data/local-hostname)"-sh" >/data/gmnts/splunk/etc/system/local/inputs.conf
sudo -u splunk /data/gmnts/splunk/bin/splunk edit licenser-localslave -master_uri 'https://${license_master_hostname}:${splunkmgmt}' -auth admin:${splunkadminpass}
sudo -u splunk /data/gmnts/splunk/bin/splunk init shcluster-config -auth admin:${splunkadminpass} -mgmt_uri https://"$(curl http://169.254.169.254/latest/meta-data/local-hostname)":${splunkmgmt} -replication_port ${splunkshcrepport} -replication_factor ${splunkshcrepfact} -conf_deploy_fetch_url https://${deployer_ip}:${splunkmgmt} -secret ${shclusterkey} -shcluster_label ${shclusterlabel}
service splunk restart