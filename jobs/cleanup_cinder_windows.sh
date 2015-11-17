#!/bin/bash
source $KEYSTONERC
source utils.sh

get_hyperv_logs

if [[ -z $DEBUG_JOB ]] || [[ $DEBUG_JOB != 'yes' ]] ;then
    set +e

    echo "Releasing cinder floating ip"
    nova remove-floating-ip "$WIN_VMID" "$CINDER_FLOATING_IP"
    echo "Removing cinder VM"
    nova delete "$WIN_VMID"
    echo "Deleting cinder floating ip"
    nova floating-ip-delete "$CINDER_FLOATING_IP"

    set -e
fi
