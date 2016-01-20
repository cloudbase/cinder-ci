#!/bin/bash
source $KEYSTONERC
source utils.sh

get_hyperv_logs

if [[ -z $DEBUG_JOB ]] || [[ $DEBUG_JOB != 'yes' ]] ;then
    set +e
    echo "Saving pip freeze"
    run_wsmancmd_with_retry $CINDER_FLOATING_IP $WINDOWS_USER $WINDOWS_PASSWORD 'pip freeze >> \\'$DEVSTACK_FLOATING_IP'\openstack\config\pip_freeze.log'
    echo "Releasing cinder floating ip"
    nova remove-floating-ip "$WIN_VMID" "$CINDER_FLOATING_IP"
    echo "Removing cinder VM"
    nova delete "$WIN_VMID"
    echo "Deleting cinder floating ip"
    nova floating-ip-delete "$CINDER_FLOATING_IP"
    echo "Deleting cinder windows intermediate log"
    rm -f /home/jenkins-slave/logs/cinder-windows-build-log-$JOB_TYPE-$ZUUL_UUID
    set -e
fi
