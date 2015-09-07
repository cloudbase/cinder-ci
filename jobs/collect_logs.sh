#!/bin/bash
echo "Collecting logs"

echo "Creating logs destination folder"
ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $LOGS_SSH_KEY logs@logs.openstack.tld "if [ ! -d /srv/logs/cinder/$ZUUL_CHANGE/$ZUUL_PATCHSET/$JOB_TYPE ]; then mkdir -p /srv/logs/cinder/$ZUUL_CHANGE/$ZUUL_PATCHSET/$JOB_TYPE; else rm -rf /srv/logs/cinder/$ZUUL_CHANGE/$ZUUL_PATCHSET/$JOB_TYPE/*; fi"

if [ $ZUUL_BRANCH = "stable/juno" ] || [ $ZUUL_BRANCH = "stable/icehouse" ]; then
    if [ $JOB_TYPE = "smb3_linux" ] || [ $JOB_TYPE = "smb3_windows" ]; then
        echo "SMB3 drivers are not supported on OpenStack Icehouse or Juno." > /tmp/results.txt
        scp -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $LOGS_SSH_KEY /tmp/results.txt logs@logs.openstack.tld:/srv/logs/cinder/$ZUUL_CHANGE/$ZUUL_PATCHSET/$JOB_TYPE/results.txt
        rm /tmp/results.txt
        exit 0
    fi
fi

ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $DEVSTACK_SSH_KEY ubuntu@$DEVSTACK_FLOATING_IP "/home/ubuntu/bin/collect_logs.sh $DEBUG_JOG"

echo "Downloading logs"
scp -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $DEVSTACK_SSH_KEY ubuntu@$DEVSTACK_FLOATING_IP:/home/ubuntu/aggregate.tar.gz "aggregate-$NAME.tar.gz"

echo "Uploading logs"
scp -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $LOGS_SSH_KEY "aggregate-$NAME.tar.gz" logs@logs.openstack.tld:/srv/logs/cinder/$ZUUL_CHANGE/$ZUUL_PATCHSET/$JOB_TYPE/aggregate-logs.tar.gz

echo "Before gzip:"
ls -lia `dirname $CONSOLE_LOG`

echo "GZIP:"
gzip -9 -v $CONSOLE_LOG

echo "After gzip:"
ls -lia `dirname $CONSOLE_LOG`

scp -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $LOGS_SSH_KEY $CONSOLE_LOG* logs@logs.openstack.tld:/srv/logs/cinder/$ZUUL_CHANGE/$ZUUL_PATCHSET/$JOB_TYPE/ && rm -f $CONSOLE_LOG*

echo "Extracting logs"
ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $LOGS_SSH_KEY logs@logs.openstack.tld "tar -xzf /srv/logs/cinder/$ZUUL_CHANGE/$ZUUL_PATCHSET/$JOB_TYPE/aggregate-logs.tar.gz -C /srv/logs/cinder/$ZUUL_CHANGE/$ZUUL_PATCHSET/$JOB_TYPE/"
echo "Fixing permissions on all log files"
ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $LOGS_SSH_KEY logs@logs.openstack.tld "chmod a+rx -R /srv/logs/cinder/$ZUUL_CHANGE/$ZUUL_PATCHSET/$JOB_TYPE/"
