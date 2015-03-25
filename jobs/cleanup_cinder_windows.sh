#!/bin/bash
source $KEYSTONERC

set +e

echo "Releasing cinder floating ip"
nova remove-floating-ip "$CINDER_VM_NAME" "$CINDER_FLOATING_IP"
echo "Removing cinder VM"
nova delete "$CINDER_VM_NAME"
echo "Deleting cinder floating ip"
nova floating-ip-delete "$CINDER_FLOATING_IP"

set -e
