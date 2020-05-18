#!/bin/bash -xe
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1
sudo -u splunk echo -e "[general]\nserverName = "$(curl http://169.254.169.254/latest/meta-data/local-hostname)"-ixrmaster" >/data/gmnts/splunk/etc/system/local/server.conf
sudo -u splunk echo -e "[default]\nhost = "$(curl http://169.254.169.254/latest/meta-data/local-hostname)"-ixrmaster" >/data/gmnts/splunk/etc/system/local/inputs.conf
sudo -u splunk echo -e "[clustering]\nmode=master\nreplication_factor = ${ixrcrepf}\nsearch_factor = ${ixrcsf}\npass4SymmKey = ${ixrckey}\ncluster_label = ${ixrclabel}" >>/data/gmnts/splunk/etc/system/local/server.conf
sudo -u splunk /data/gmnts/splunk/bin/splunk edit licenser-localslave -master_uri 'https://${license_master_hostname}:${splunkmgmt}' -auth admin:${splunkadminpass}
service splunk restart
sudo -u splunk /data/gmnts/splunk/bin/splunk clone-prep-clear-config -auth admin:${splunkadminpass}
service splunk restart
sudo -u splunk /data/gmnts/splunk/bin/splunk edit cluster-config -mode slave -master_uri 'https://${ixrcmaster}:${splunkmgmt}' -replication_port ${splunkixrcrepport} -auth admin:${splunkadminpass}
service splunk restart
sudo -u splunk /data/gmnts/splunk/bin/splunk edit cluster-config -mode master -replication_factor ${ixrcrepf} -search_factor ${ixrcsf} -auth admin:${splunkadminpass}
service splunk restart
