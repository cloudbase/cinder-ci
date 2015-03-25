#!/bin/bash
echo "Collecting logs"
ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $DEVSTACK_SSH_KEY ubuntu@$DEVSTACK_FLOATING_IP "/home/ubuntu/bin/collect_logs.sh"

echo "Creating logs destination folder"
ssh -vv -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $LOGS_SSH_KEY logs@logs.openstack.tld "if [ ! -d /srv/logs/cinder/test/$ZUUL_CHANGE/$ZUUL_PATCHSET/$JOB_TYPE ]; then mkdir -p /srv/logs/cinder/test/$ZUUL_CHANGE/$ZUUL_PATCHSET/$JOB_TYPE; else rm -rf /srv/logs/cinder/test/$ZUUL_CHANGE/$ZUUL_PATCHSET/$JOB_TYPE/*; fi"

echo "Downloading logs"
scp -vv -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $DEVSTACK_SSH_KEY ubuntu@$DEVSTACK_FLOATING_IP:/home/ubuntu/aggregate.tar.gz "aggregate-$NAME.tar.gz"

echo "Uploading logs"
scp -vv -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $LOGS_SSH_KEY "aggregate-$NAME.tar.gz" logs@logs.openstack.tld:/srv/logs/cinder/test/$ZUUL_CHANGE/$ZUUL_PATCHSET/$JOB_TYPE/aggregate-logs.tar.gz
#gzip -9 /var/lib/jenkins/logs/console-$ZUUL_CHANGE-$ZUUL_PATCHSET.log
#scp -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $LOGS_SSH_KEY "/var/lib/jenkins/jenkins-master/logs/console-$ZUUL_CHANGE-$ZUUL_PATCHSET.log.gz" logs@logs.openstack.tld:/srv/logs/cinder/$ZUUL_CHANGE/$ZUUL_PATCHSET/console.log.gz && rm -f /var/lib/jenkins/logs/console-$ZUUL_CHANGE-$ZUUL_PATCHSET.log.gz
echo "Extracting logs"
ssh -vv -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $LOGS_SSH_KEY logs@logs.openstack.tld "tar -xzf /srv/logs/cinder/test/$ZUUL_CHANGE/$ZUUL_PATCHSET/$JOB_TYPE/aggregate-logs.tar.gz -C /srv/logs/cinder/test/$ZUUL_CHANGE/$ZUUL_PATCHSET/$JOB_TYPE/"
echo "Fixing permissions on all log files"
ssh -vv -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $LOGS_SSH_KEY logs@logs.openstack.tld "chmod a+rx -R /srv/logs/cinder/test/$ZUUL_CHANGE/$ZUUL_PATCHSET/$JOB_TYPE/"
