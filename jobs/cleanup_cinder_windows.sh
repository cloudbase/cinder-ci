#!/bin/bash
source $KEYSTONERC
source /usr/local/src/cinder-ci/jobs/utils.sh

get_hyperv_logs

if [[ -z $DEBUG_JOB ]] || [[ $DEBUG_JOB != 'yes' ]] ;then
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
fi
