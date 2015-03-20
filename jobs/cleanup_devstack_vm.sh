source $KEYSTONERC

set +e

echo "Releasing devstack floating IP"
nova remove-floating-ip "$NAME" "$DEVSTACK_FLOATING_IP"
echo "Removing devstack VM"
nova delete "$NAME"
echo "Deleting devstack floating IP"
nova floating-ip-delete "$DEVSTACK_FLOATING_IP"

set -e
