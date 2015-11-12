#!/bin/bash
source $KEYSTONERC

if [[ -z $DEBUG_JOB ]] || [[ $DEBUG_JOB != 'yes' ]] ;then
    set +e

    echo "Releasing devstack floating IP"
    nova remove-floating-ip "$VMID" "$DEVSTACK_FLOATING_IP"
    echo "Removing devstack VM"
    nova delete "$VMID"
    echo "Deleting devstack floating IP"
    nova floating-ip-delete "$DEVSTACK_FLOATING_IP"

    set -e
fi
