#!/bin/bash
source /usr/local/src/cinder-ci/jobs/utils.sh

echo "Collecting logs"

if [ -z "$DEBUG_JOB" ] || [ "$DEBUG_JOB" != "yes" ]; then
    LOGSDEST="/srv/logs/cinder/$ZUUL_CHANGE/$ZUUL_PATCHSET/$JOB_TYPE"
else
    LOGSDEST="/srv/logs/cinder/debug/$ZUUL_CHANGE/$ZUUL_PATCHSET/$JOB_TYPE"
fi

echo "Creating logs destination folder"
ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $LOGS_SSH_KEY logs@logs.openstack.tld "if [ ! -d $LOGSDEST ]; then mkdir -p $LOGSDEST; else rm -rf $LOGSDEST/*; fi"

if [[ $JOB_TYPE != 'smb3_linux' ]] ;then
	echo 'Getting the Hyper-V logs'
	get_hyperv_logs
fi

echo 'Collecting the devstack logs'
ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $DEVSTACK_SSH_KEY ubuntu@$DEVSTACK_FLOATING_IP "/home/ubuntu/bin/collect_logs.sh $DEBUG_JOB"

echo "Downloading logs from the devstack VM"
scp -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $DEVSTACK_SSH_KEY ubuntu@$DEVSTACK_FLOATING_IP:/home/ubuntu/aggregate.tar.gz "aggregate-$NAME.tar.gz"

echo "Uploading logs to the logs server"
scp -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $LOGS_SSH_KEY "aggregate-$NAME.tar.gz" logs@logs.openstack.tld:$LOGSDEST/aggregate-logs.tar.gz

echo "Archiving the devstack console log"
gzip -9 -v $CONSOLE_LOG

echo 'Copying the devstack console log to the logs server'
scp -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $LOGS_SSH_KEY $CONSOLE_LOG.gz logs@logs.openstack.tld:$LOGSDEST/ && rm -f $CONSOLE_LOG.gz

echo "Extracting the logs tar archive"
ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $LOGS_SSH_KEY logs@logs.openstack.tld "tar -xzf $LOGSDEST/aggregate-logs.tar.gz -C $LOGSDEST/"

#echo "Uploading threaded logs"
#set +e
#scp -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $LOGS_SSH_KEY /home/jenkins-slave/logs/devstack-build-log-$JOB_TYPE-$ZUUL_UUID logs@logs.openstack.tld:$LOGSDEST/
#scp -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $LOGS_SSH_KEY /home/jenkins-slave/logs/cinder-windows-build-log-$JOB_TYPE-$ZUUL_UUID logs@logs.openstack.tld:$LOGSDEST/
#set -e

echo "Fixing permissions on all log files on the logs server"
ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $LOGS_SSH_KEY logs@logs.openstack.tld "chmod a+rx -R $LOGSDEST/"
