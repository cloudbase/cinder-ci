#!/bin/bash
basedir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt
source $basedir/utils.sh

LOG_SERVER=cloudbase@cloudbase-ci.com
LOGS_SSH_KEY=$DEVSTACK_SSH_KEY
hyperv01=$HV1_IP
FLOATING_IP=$DEVSTACK_IP

CONSOLE_LOG=/home/jenkins-slave/logs/console-$ZUUL_UUID.$JOB_TYPE.log
logs_project=cinder
set +e
set -f

echo "Processing logs for $hyperv01"

[ "$IS_DEBUG_JOB" != "yes" ] && run_wsmancmd_with_retry 3 $hyperv01 $WIN_USER $WIN_PASS 'powershell -ExecutionPolicy RemoteSigned Stop-service nova-compute'
[ "$IS_DEBUG_JOB" != "yes" ] && run_wsmancmd_with_retry 3 $hyperv01 $WIN_USER $WIN_PASS 'powershell -ExecutionPolicy RemoteSigned Stop-service neutron-hyperv-agent'

run_wsmancmd_with_retry 3 $hyperv01 $WIN_USER $WIN_PASS 'powershell -ExecutionPolicy RemoteSigned C:\OpenStack\cinder-ci\HyperV\scripts\export-eventlog.ps1'
run_wsmancmd_with_retry 3 $hyperv01 $WIN_USER $WIN_PASS 'powershell -ExecutionPolicy RemoteSigned C:\OpenStack\cinder-ci\HyperV\scripts\collect_systemlogs.ps1'

echo "Processing logs for $ws2012r2"

[ "$IS_DEBUG_JOB" != "yes" ] && run_wsmancmd_with_retry 3 $ws2012r2 $WIN_USER $WIN_PASS 'powershell -ExecutionPolicy RemoteSigned Stop-service cinder-volume'

run_wsmancmd_with_retry 3 $ws2012r2 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned C:\openstack\cinder-ci\windows\scripts\export-eventlog.ps1'
run_wsmancmd_with_retry 3 $ws2012r2 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned C:\openstack\cinder-ci\windows\scripts\collect_systemlogs.ps1'


set +f

echo "Collecting logs"

if [ -z "$ZUUL_CHANGE" ] || [ -z "$ZUUL_PATCHSET" ]; then echo 'Missing parameters!'; exit 1; fi

if [ -z "$IS_DEBUG_JOB" ] || [ "$IS_DEBUG_JOB" != "yes" ]; then
    LOGSDEST="/srv/logs/cinder/$ZUUL_CHANGE/$ZUUL_PATCHSET/$JOB_TYPE"
else
    TIMESTAMP=$(date +%d-%m-%Y_%H-%M)
    LOGSDEST="/srv/logs/debug/cinder/$ZUUL_CHANGE/$ZUUL_PATCHSET/$JOB_TYPE/$TIMESTAMP"
fi

echo "Creating logs destination folder"
ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $LOGS_SSH_KEY $LOG_SERVER "if [ ! -d $LOGSDEST ]; then mkdir -p $LOGSDEST; else rm -rf $LOGSDEST/*; fi"

echo 'Collecting the devstack logs'
ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $DEVSTACK_SSH_KEY ubuntu@$DEVSTACK_FLOATING_IP "/home/ubuntu/bin/collect_logs.sh"

echo "Downloading logs from the devstack VM"
scp -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $DEVSTACK_SSH_KEY ubuntu@$DEVSTACK_FLOATING_IP:/home/ubuntu/aggregate.tar.gz "aggregate-$NAME.tar.gz"

echo "Uploading logs to the logs server"
scp -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $LOGS_SSH_KEY "aggregate-$NAME.tar.gz" $LOG_SERVER:$LOGSDEST/aggregate-logs.tar.gz

echo "Archiving the devstack console log"
gzip -9 -v $CONSOLE_LOG
gzip -9 /home/jenkins-slave/logs/hyperv-$hyperv01-build-log-$ZUUL_UUID-$JOB_TYPE.log
gzip -9 /home/jenkins-slave/logs/ws2012-build-log-$ZUUL_UUID-$JOB_TYPE.log
gzip -9 /home/jenkins-slave/logs/build-devstack-log-$ZUUL_UUID-$JOB_TYPE.log

echo "Extracting the logs tar archive"
ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $LOGS_SSH_KEY $LOG_SERVER "tar -xzf $LOGSDEST/aggregate-logs.tar.gz -C $LOGSDEST/"

set +e
echo "Uploading build and console logs"
scp -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $LOGS_SSH_KEY $CONSOLE_LOG.gz $LOG_SERVER:$LOGSDEST/
scp -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $LOGS_SSH_KEY /home/jenkins-slave/logs/hyperv-$hyperv01-build-log-$ZUUL_UUID-$JOB_TYPE.log.gz $LOG_SERVER:$LOGSDEST/
scp -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $LOGS_SSH_KEY /home/jenkins-slave/logs/ws2012-build-log-$ZUUL_UUID-$JOB_TYPE.log.gz $LOG_SERVER:$LOGSDEST/
scp -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $LOGS_SSH_KEY /home/jenkins-slave/logs/build-devstack-log-$ZUUL_UUID-$JOB_TYPE.log.gz $LOG_SERVER:$LOGSDEST/
set -e

echo "Fixing permissions on all log files on the logs server"
ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $LOGS_SSH_KEY $LOG_SERVER "chmod a+rx -R $LOGSDEST/"

echo "Clean up local copy of aggregate archive"
rm -f "aggregate-$NAME.tar.gz"
rm -f $CONSOLE_LOG.gz
rm -f /home/jenkins-slave/logs/hyperv-$hyperv01-build-log-$ZUUL_UUID-$JOB_TYPE.log.gz
rm -f /home/jenkins-slave/logs/ws2012-build-log-$ZUUL_UUID-$JOB_TYPE.log.gz
rm -f /home/jenkins-slave/logs/build-devstack-log-$ZUUL_UUID-$JOB_TYPE.log.gz
