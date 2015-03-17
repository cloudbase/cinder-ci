source $KEYSTONERC

set +e

echo "Releasing devstack floating IP"
nova remove-floating-ip "$NAME" "$FLOATING_IP"
echo "Removing devstack VM"
nova delete "$NAME"
echo "Deleting devstack floating IP"
nova floating-ip-delete "$FLOATING_IP"
echo "Releasing cinder floating ip"
nova remove-floating-ip "$CINDER_VM_NAME" "$CINDER_FLOATING_IP"
echo "Removing cinder VM"
nova delete "$CINDER_VM_NAME"
echo "Deleting cinder floating ip"
nova floating-ip-delete "$CINDER_FLOATING_IP"

set -e
