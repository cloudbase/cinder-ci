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
    /usr/local/src/cinder-ci/vlan_allocation.py -r $VMID
    echo "Deleting devstack intermediate log"
    rm -f /home/jenkins-slave/logs/devstack-build-log-$JOB_TYPE-$ZUUL_UUID
    set -e
fi
