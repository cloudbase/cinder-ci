#!/bin/bash
source /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt
source /home/jenkins-slave/tools/keystonerc_admin
source /usr/local/src/cinder-ci-2016/jobs/utils.sh

CONSOLE_LOG=/home/jenkins-slave/logs/console-log.$ZUUL_UUID.$JOB_TYPE.log
logs_project=cinder
logs_location='C:\openstack\logs'
logs_location_win="$logs_location\windows"
echo "Hosts are $hyperv01 - $hyperv02 - $ws2012r2"
set +e

ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $DEVSTACK_SSH_KEY ubuntu@$DEVSTACK_FLOATING_IP "mkdir -p /openstack/logs/${hyperv01%%[.]*}/eventlog"
ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $DEVSTACK_SSH_KEY ubuntu@$DEVSTACK_FLOATING_IP "mkdir -p /openstack/logs/${hyperv02%%[.]*}/eventlog"
ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $DEVSTACK_SSH_KEY ubuntu@$DEVSTACK_FLOATING_IP "mkdir -p /openstack/logs/windows/eventlog"
ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $DEVSTACK_SSH_KEY ubuntu@$DEVSTACK_FLOATING_IP "sudo chown -R nobody:nogroup /openstack/logs"
ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $DEVSTACK_SSH_KEY ubuntu@$DEVSTACK_FLOATING_IP "sudo chmod -R 777 /openstack/logs"

set -f

echo "Processing logs for $hyperv01"

#run_wsmancmd_with_retry 3 $hyperv01 $WIN_USER $WIN_PASS 'powershell -ExecutionPolicy RemoteSigned Copy-Item -Recurse C:\OpenStack\Log\* \\'$DEVSTACK_FLOATING_IP'\openstack\logs\'${hyperv01%%[.]*}'\'
run_wsmancmd_with_retry 3 $hyperv01 $WIN_USER $WIN_PASS 'powershell -ExecutionPolicy RemoteSigned C:\OpenStack\cinder-ci\HyperV\scripts\export-eventlog.ps1'
#run_wsmancmd_with_retry 3 $hyperv01 $WIN_USER $WIN_PASS 'powershell -ExecutionPolicy RemoteSigned cp -Recurse -Container  C:\OpenStack\Logs\Eventlog\* \\'$DEVSTACK_FLOATING_IP'\openstack\logs\'${hyperv01%%[.]*}'\eventlog'

run_wsmancmd_with_retry 3 $hyperv01 $WIN_USER $WIN_PASS 'systeminfo >> '$logs_location'\systeminfo.log'
run_wsmancmd_with_retry 3 $hyperv01 $WIN_USER $WIN_PASS 'wmic qfe list >> '$logs_location'\windows_hotfixes.log'
run_wsmancmd_with_retry 3 $hyperv01 $WIN_USER $WIN_PASS 'pip freeze >> '$logs_location'\pip_freeze.log'
run_wsmancmd_with_retry 3 $hyperv01 $WIN_USER $WIN_PASS 'ipconfig /all >> '$logs_location'\ipconfig.log'

run_wsmancmd_with_retry 3 $hyperv01 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned get-netadapter ^| Select-object * >> '$logs_location'\get_netadapter.log'
run_wsmancmd_with_retry 3 $hyperv01 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned get-vmswitch ^| Select-object * >> '$logs_location'\get_vmswitch.log'
run_wsmancmd_with_retry 3 $hyperv01 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned get-WmiObject win32_logicaldisk ^| Select-object * >> '$logs_location'\disk_free.log'
run_wsmancmd_with_retry 3 $hyperv01 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned get-netfirewallprofile ^| Select-Object * >> '$logs_location'\firewall.log'
run_wsmancmd_with_retry 3 $hyperv01 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned get-process ^| Select-Object * >> '$logs_location'\get_process.log'
run_wsmancmd_with_retry 3 $hyperv01 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned get-service ^| Select-Object * >> '$logs_location'\get_service.log'

run_wsmancmd_with_retry 3 $hyperv01 $WIN_USER $WIN_PASS 'sc qc nova-compute >> '$logs_location'\nova_compute_service.log'
run_wsmancmd_with_retry 3 $hyperv01 $WIN_USER $WIN_PASS 'sc qc neutron-hyperv-agent >> '$logs_location'\neutron_hyperv_agent_service.log'

echo "Processing logs for $hyperv02"

#run_wsmancmd_with_retry 3 $hyperv02 $WIN_USER $WIN_PASS 'powershell -ExecutionPolicy RemoteSigned Copy-Item -Recurse C:\OpenStack\Log\* \\'$DEVSTACK_FLOATING_IP'\openstack\logs\'${hyperv02%%[.]*}'\'
run_wsmancmd_with_retry 3 $hyperv02 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned C:\OpenStack\cinder-ci\HyperV\scripts\export-eventlog.ps1'
#run_wsmancmd_with_retry 3 $hyperv02 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned cp -Recurse -Container  C:\OpenStack\Logs\Eventlog\* \\'$DEVSTACK_FLOATING_IP'\openstack\logs\'${hyperv02%%[.]*}'\eventlog'

run_wsmancmd_with_retry 3 $hyperv02 $WIN_USER $WIN_PASS 'systeminfo >> '$logs_location'\systeminfo.log'
run_wsmancmd_with_retry 3 $hyperv02 $WIN_USER $WIN_PASS 'wmic qfe list >> '$logs_location'\windows_hotfixes.log'
run_wsmancmd_with_retry 3 $hyperv02 $WIN_USER $WIN_PASS 'pip freeze >> '$logs_location'\pip_freeze.log'
run_wsmancmd_with_retry 3 $hyperv02 $WIN_USER $WIN_PASS 'ipconfig /all >> '$logs_location'\ipconfig.log'

run_wsmancmd_with_retry 3 $hyperv02 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned get-netadapter ^| Select-object * >> '$logs_location'\get_netadapter.log'
run_wsmancmd_with_retry 3 $hyperv02 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned get-vmswitch ^| Select-object * >> '$logs_location'\get_vmswitch.log'
run_wsmancmd_with_retry 3 $hyperv02 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned get-WmiObject win32_logicaldisk ^| Select-object * >> '$logs_location'\disk_free.log'
run_wsmancmd_with_retry 3 $hyperv02 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned get-netfirewallprofile ^| Select-Object * >> '$logs_location'\firewall.log'
run_wsmancmd_with_retry 3 $hyperv02 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned get-process ^| Select-Object * >> '$logs_location'\get_process.log'
run_wsmancmd_with_retry 3 $hyperv02 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned get-service ^| Select-Object * >> '$logs_location'\get_service.log'

run_wsmancmd_with_retry 3 $hyperv02 $WIN_USER $WIN_PASS 'sc qc nova-compute >> '$logs_location'\nova_compute_service.log'
run_wsmancmd_with_retry 3 $hyperv02 $WIN_USER $WIN_PASS 'sc qc neutron-hyperv-agent >> '$logs_location'\neutron_hyperv_agent_service.log'

echo "Processing logs for $ws2012r2"

#run_wsmancmd_with_retry 3 $ws2012r2 $WIN_USER $WIN_PASS 'powershell -ExecutionPolicy RemoteSigned Copy-Item -Recurse C:\OpenStack\Log\* \\'$DEVSTACK_FLOATING_IP'\openstack\logs\windows'
echo "Export eventlog entries to files"
run_wsmancmd_with_retry 3 $ws2012r2 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned C:\cinder-ci\windows\scripts\export-eventlog.ps1'
echo "Copy eventlog files"
#run_wsmancmd_with_retry 3 $ws2012r2 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned cp -Recurse -Container  C:\OpenStack\Log\Eventlog\* \\'$DEVSTACK_FLOATING_IP'\openstack\logs\windows\eventlog'
echo "Copy systeminfo"
run_wsmancmd_with_retry 3 $ws2012r2 $WIN_USER $WIN_PASS 'systeminfo >> '$logs_location_windows'\systeminfo.log'
echo "Copy windows updates status"
run_wsmancmd_with_retry 3 $ws2012r2 $WIN_USER $WIN_PASS 'wmic qfe list >> '$logs_location_windows'\windows_hotfixes.log'
echo "Copy pip freeze list"
run_wsmancmd_with_retry 3 $ws2012r2 $WIN_USER $WIN_PASS 'pip freeze >> '$logs_location_windows'\pip_freeze.log'
echo "Copy network configuration info"
run_wsmancmd_with_retry 3 $ws2012r2 $WIN_USER $WIN_PASS 'ipconfig /all >> '$logs_location_windows'\ipconfig.log'
    
echo "Copy network addapter information"
run_wsmancmd_with_retry 3 $ws2012r2 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned get-netadapter ^| Select-object * >> '$logs_location_windows'\get_netadapter.log'
echo "Copy disk partition info"
run_wsmancmd_with_retry 3 $ws2012r2 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned get-WmiObject win32_logicaldisk ^| Select-object * >> '$logs_location_windows'\disk_free.log'
echo "Copy firewall status"
run_wsmancmd_with_retry 3 $ws2012r2 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned get-netfirewallprofile ^| Select-Object * >> '$logs_location_windows'\firewall.log'
echo "Copy list of running processes"
run_wsmancmd_with_retry 3 $ws2012r2 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned get-process ^| Select-Object * >> '$logs_location_windows'\get_process.log'
echo "Copy list of windows services"
run_wsmancmd_with_retry 3 $ws2012r2 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned get-service ^| Select-Object * >> '$logs_location_windows'\get_service.log'
echo "Copy cinder volume service details"
run_wsmancmd_with_retry 3 $ws2012r2 $WIN_USER $WIN_PASS 'sc qc cinder-volume >> '$logs_location_windows'\cinder-volume_service.log'

set +f


echo "Collecting logs"

if [ -z "$DEBUG_JOB" ] || [ "$DEBUG_JOB" != "yes" ]; then
    LOGSDEST="/srv/logs/cinder/$ZUUL_CHANGE/$ZUUL_PATCHSET/$JOB_TYPE"
else
    LOGSDEST="/srv/logs/debug/cinder/$ZUUL_CHANGE/$ZUUL_PATCHSET/$JOB_TYPE"
fi

echo "Creating logs destination folder"
ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $LOGS_SSH_KEY logs@logs.openstack.tld "if [ ! -d $LOGSDEST ]; then mkdir -p $LOGSDEST; else rm -rf $LOGSDEST/*; fi"

#if [[ $JOB_TYPE != 'smb3_linux' ]] ;then
#	echo 'Getting the Hyper-V logs'
#	get_hyperv_logs
#fi

echo 'Collecting the devstack logs'
ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $DEVSTACK_SSH_KEY ubuntu@$DEVSTACK_FLOATING_IP "/home/ubuntu/bin/collect_logs.sh $hyperv01 $hyperv02 $ws2012r2"

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
