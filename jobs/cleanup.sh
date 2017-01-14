#!/bin/bash
source /usr/local/src/cinder-ci/jobs/utils.sh
source /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt

echo "Collecting logs"

/usr/local/src/cinder-ci/jobs/collect_logs.sh

if [ -z "$DEBUG_JOB" ] || [ "$DEBUG_JOB" != "yes" ]; then
    echo "Not a debug job, cleaning up environment."
    source /home/jenkins-slave/tools/keystonerc_admin
    nova delete $VMID
    /usr/local/src/cinder-ci/vlan_allocation.py -r $VMID
    
    run_wsmancmd_with_retry 3 $hyperv01 $WIN_USER $WIN_PASS 'powershell -ExecutionPolicy RemoteSigned C:\OpenStack\cinder-ci\HyperV\scripts\teardown.ps1'
    run_wsmancmd_with_retry 3 $hyperv02 $WIN_USER $WIN_PASS 'powershell -ExecutionPolicy RemoteSigned C:\OpenStack\cinder-ci\HyperV\scripts\teardown.ps1'
    run_wsmancmd_with_retry 3 $ws2012r2 $WIN_USER $WIN_PASS 'powershell -ExecutionPolicy RemoteSigned C:\cinder-ci\windows\scripts\teardown.ps1'
else
    echo "Not cleaning up because debug job variable is set to true."
fi

echo "Cleaning up devstack params file"
rm -f /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt
