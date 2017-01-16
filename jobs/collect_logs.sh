#!/bin/bash
source /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt
source /home/jenkins-slave/tools/keystonerc_admin
source /usr/local/src/cinder-ci/jobs/utils.sh

CONSOLE_LOG=/home/jenkins-slave/logs/console-log.$ZUUL_UUID.$JOB_TYPE.log
logs_project=cinder

set +e

ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $DEVSTACK_SSH_KEY ubuntu@$DEVSTACK_FLOATING_IP "mkdir -p /openstack/logs/${hyperv01%%[.]*}"
ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $DEVSTACK_SSH_KEY ubuntu@$DEVSTACK_FLOATING_IP "mkdir -p /openstack/logs/${hyperv02%%[.]*}"
ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $DEVSTACK_SSH_KEY ubuntu@$DEVSTACK_FLOATING_IP "mkdir -p /openstack/logs/windows"
ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $DEVSTACK_SSH_KEY ubuntu@$DEVSTACK_FLOATING_IP "sudo chown -R nobody:nogroup /openstack/logs"
ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $DEVSTACK_SSH_KEY ubuntu@$DEVSTACK_FLOATING_IP "sudo chmod -R 777 /openstack/logs"

set -f

run_wsmancmd_with_retry 3 $hyperv01 $WIN_USER $WIN_PASS 'powershell -ExecutionPolicy RemoteSigned Copy-Item -Recurse C:\OpenStack\Log\* \\'$DEVSTACK_FLOATING_IP'\openstack\logs\'${hyperv01%%[.]*}'\'
run_wsmancmd_with_retry 3 $hyperv01 $WIN_USER $WIN_PASS 'powershell -ExecutionPolicy RemoteSigned C:\OpenStack\cinder-ci\HyperV\scripts\export-eventlog.ps1'
run_wsmancmd_with_retry 3 $hyperv01 $WIN_USER $WIN_PASS 'powershell -ExecutionPolicy RemoteSigned cp -Recurse -Container  C:\OpenStack\Logs\Eventlog\* \\'$DEVSTACK_FLOATING_IP'\openstack\logs\'${hyperv01%%[.]*}'\'

run_wsmancmd_with_retry 3 $hyperv01 $WIN_USER $WIN_PASS 'systeminfo >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\'${hyperv01%%[.]*}'\systeminfo.log'
run_wsmancmd_with_retry 3 $hyperv01 $WIN_USER $WIN_PASS 'wmic qfe list >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\'${hyperv01%%[.]*}'\windows_hotfixes.log'
run_wsmancmd_with_retry 3 $hyperv01 $WIN_USER $WIN_PASS 'pip freeze >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\'${hyperv01%%[.]*}'\pip_freeze.log'
run_wsmancmd_with_retry 3 $hyperv01 $WIN_USER $WIN_PASS 'ipconfig /all >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\'${hyperv01%%[.]*}'\ipconfig.log'

run_wsmancmd_with_retry 3 $hyperv01 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned get-netadapter ^| Select-object * >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\'${hyperv01%%[.]*}'\get_netadapter.log'
run_wsmancmd_with_retry 3 $hyperv01 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned get-vmswitch ^| Select-object * >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\'${hyperv01%%[.]*}'\get_vmswitch.log'
run_wsmancmd_with_retry 3 $hyperv01 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned get-WmiObject win32_logicaldisk ^| Select-object * >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\'${hyperv01%%[.]*}'\disk_free.log'
run_wsmancmd_with_retry 3 $hyperv01 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned get-netfirewallprofile ^| Select-Object * >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\'${hyperv01%%[.]*}'\firewall.log'
run_wsmancmd_with_retry 3 $hyperv01 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned get-process ^| Select-Object * >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\'${hyperv01%%[.]*}'\get_process.log'
run_wsmancmd_with_retry 3 $hyperv01 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned get-service ^| Select-Object * >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\'${hyperv01%%[.]*}'\get_service.log'

run_wsmancmd_with_retry 3 $hyperv01 $WIN_USER $WIN_PASS 'sc qc nova-compute >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\'${hyperv01%%[.]*}'\nova_compute_service.log'
run_wsmancmd_with_retry 3 $hyperv01 $WIN_USER $WIN_PASS 'sc qc neutron-hyperv-agent >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\'${hyperv01%%[.]*}'\neutron_hyperv_agent_service.log'

run_wsmancmd_with_retry 3 $hyperv02 $WIN_USER $WIN_PASS 'powershell -ExecutionPolicy RemoteSigned Copy-Item -Recurse C:\OpenStack\Log\* \\'$DEVSTACK_FLOATING_IP'\openstack\logs\'${hyperv02%%[.]*}'\'
run_wsmancmd_with_retry 3 $hyperv02 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned C:\OpenStack\cinder-ci\HyperV\scripts\export-eventlog.ps1'
run_wsmancmd_with_retry 3 $hyperv02 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned cp -Recurse -Container  C:\OpenStack\Logs\Eventlog\* \\'$DEVSTACK_FLOATING_IP'\openstack\logs\'${hyperv02%%[.]*}'\'

run_wsmancmd_with_retry 3 $hyperv02 $WIN_USER $WIN_PASS 'systeminfo >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\'${hyperv02%%[.]*}'\systeminfo.log'
run_wsmancmd_with_retry 3 $hyperv02 $WIN_USER $WIN_PASS 'wmic qfe list >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\'${hyperv02%%[.]*}'\windows_hotfixes.log'
run_wsmancmd_with_retry 3 $hyperv02 $WIN_USER $WIN_PASS 'pip freeze >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\'${hyperv02%%[.]*}'\pip_freeze.log'
run_wsmancmd_with_retry 3 $hyperv02 $WIN_USER $WIN_PASS 'ipconfig /all >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\'${hyperv02%%[.]*}'\ipconfig.log'

run_wsmancmd_with_retry 3 $hyperv02 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned get-netadapter ^| Select-object * >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\'${hyperv02%%[.]*}'\get_netadapter.log'
run_wsmancmd_with_retry 3 $hyperv02 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned get-vmswitch ^| Select-object * >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\'${hyperv02%%[.]*}'\get_vmswitch.log'
run_wsmancmd_with_retry 3 $hyperv02 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned get-WmiObject win32_logicaldisk ^| Select-object * >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\'${hyperv02%%[.]*}'\disk_free.log'
run_wsmancmd_with_retry 3 $hyperv02 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned get-netfirewallprofile ^| Select-Object * >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\'${hyperv02%%[.]*}'\firewall.log'
run_wsmancmd_with_retry 3 $hyperv02 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned get-process ^| Select-Object * >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\'${hyperv02%%[.]*}'\get_process.log'
run_wsmancmd_with_retry 3 $hyperv02 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned get-service ^| Select-Object * >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\'${hyperv02%%[.]*}'\get_service.log'

run_wsmancmd_with_retry 3 $hyperv02 $WIN_USER $WIN_PASS 'sc qc nova-compute >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\'${hyperv02%%[.]*}'\nova_compute_service.log'
run_wsmancmd_with_retry 3 $hyperv02 $WIN_USER $WIN_PASS 'sc qc neutron-hyperv-agent >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\'${hyperv02%%[.]*}'\neutron_hyperv_agent_service.log'

echo "Export eventlog entries to files"
run_wsmancmd_with_retry 3 $ws2012r2 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned C:\cinder-ci\windows\scripts\export-eventlog.ps1'
# echo "Copy eventlog files"
# run_wsmancmd_with_retry 3 $ws2012r2 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned cp -Recurse -Container  C:\OpenStack\Log\Eventlog\* \\'$DEVSTACK_FLOATING_IP'\openstack\logs\windows\'
    
echo "Copy systeminfo"
run_wsmancmd_with_retry 3 $ws2012r2 $WIN_USER $WIN_PASS 'systeminfo >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\windows\systeminfo.log'
echo "Copy windows updates status"
run_wsmancmd_with_retry 3 $ws2012r2 $WIN_USER $WIN_PASS 'wmic qfe list >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\windows\windows_hotfixes.log'
echo "Copy pip freeze list"
run_wsmancmd_with_retry 3 $ws2012r2 $WIN_USER $WIN_PASS 'pip freeze >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\windows\pip_freeze.log'
echo "Copy network configuration info"
run_wsmancmd_with_retry 3 $ws2012r2 $WIN_USER $WIN_PASS 'ipconfig /all >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\windows\ipconfig.log'
    
echo "Copy network addapter information"
run_wsmancmd_with_retry 3 $ws2012r2 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned get-netadapter ^| Select-object * >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\windows\get_netadapter.log'
echo "Copy disk partition info"
run_wsmancmd_with_retry 3 $ws2012r2 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned get-WmiObject win32_logicaldisk ^| Select-object * >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\windows\disk_free.log'
echo "Copy firewall status"
run_wsmancmd_with_retry 3 $ws2012r2 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned get-netfirewallprofile ^| Select-Object * >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\windows\firewall.log'
echo "Copy list of running processes"
run_wsmancmd_with_retry 3 $ws2012r2 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned get-process ^| Select-Object * >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\windows\get_process.log'
echo "Copy list of windows services"
run_wsmancmd_with_retry 3 $ws2012r2 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned get-service ^| Select-Object * >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\windows\get_service.log'
echo "Copy cinder volume service details"
run_wsmancmd_with_retry 3 $ws2012r2 $WIN_USER $WIN_PASS 'sc qc cinder-volume >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\windows\cinder-volume.log'

set +f


echo "Collecting logs"

if [ -z "$DEBUG_JOB" ] || [ "$DEBUG_JOB" != "yes" ]; then
    LOGSDEST="/srv/logs/cinder/$ZUUL_CHANGE/$ZUUL_PATCHSET/$JOB_TYPE"
else
    LOGSDEST="/srv/logs/cinder/debug/$ZUUL_CHANGE/$ZUUL_PATCHSET/$JOB_TYPE"
fi

echo "Creating logs destination folder"
ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $LOGS_SSH_KEY logs@logs.openstack.tld "if [ ! -d $LOGSDEST ]; then mkdir -p $LOGSDEST; else rm -rf $LOGSDEST/*; fi"

#if [[ $JOB_TYPE != 'smb3_linux' ]] ;then
#	echo 'Getting the Hyper-V logs'
#	get_hyperv_logs
#fi

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

echo "Clean up local copy of aggregate archive"
rm -f "aggregate-$NAME.tar.gz"
