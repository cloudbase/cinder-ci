#!/bin/bash
source $KEYSTONERC
source utils.sh

if [[ -z $DEBUG_JOB ]] || [[ $DEBUG_JOB != 'YES' ]] ;then
    get_hyperv_logs
    set +e
    echo "Releasing cinder floating ip"
    nova remove-floating-ip "$WIN_VMID" "$CINDER_FLOATING_IP"
    echo "Removing cinder VM"
    nova delete "$WIN_VMID"
    echo "Deleting cinder floating ip"
    nova floating-ip-delete "$CINDER_FLOATING_IP"
    echo "Deleting cinder windows intermediate log"
    rm -f /home/jenkins-slave/logs/cinder-windows-build-log-$JOB_TYPE-$ZUUL_UUID
    set -e
else
    get_hyperv_logs $DEBUG_JOB
fi
