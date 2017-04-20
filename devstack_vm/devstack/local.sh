#!/bin/bash
set -e

source /home/ubuntu/devstack/functions
source /home/ubuntu/devstack/functions-common

if [ "$branch" == "stable/newton" ] || [ "$branch" == "stable/liberty" ] || [ "$branch" == "stable/mitaka" ]; then
    nova flavor-delete 42
    nova flavor-delete 84
fi

if [ "$branch" == "stable/newton" ] || [ "$branch" == "stable/ocata" ]; then
cat <<EOT >> /home/ubuntu/bin/excluded-tests-smb3_windows.txt
# This driver does not support snapshotting in-use volumes
tempest.api.volume.test_volumes_snapshots.VolumesV1SnapshotTestJSON.test_snapshot_create_with_volume_in_use
tempest.api.volume.test_volumes_snapshots.VolumesV1SnapshotTestJSON.test_snapshot_create_offline_delete_online
tempest.api.volume.test_volumes_snapshots.VolumesV1SnapshotTestJSON.test_snapshot_delete_with_volume_in_use
tempest.api.volume.test_volumes_snapshots.VolumesSnapshotTestJSON.test_snapshot_create_with_volume_in_use
tempest.api.volume.test_volumes_snapshots.VolumesSnapshotTestJSON.test_snapshot_create_offline_delete_online
tempest.api.volume.test_volumes_snapshots.VolumesSnapshotTestJSON.test_snapshot_delete_with_volume_in_use
EOT
fi

nova flavor-create m1.nano 42 96 1 1

nova flavor-create m1.micro 84 128 2 1

# Add DNS config to the private network
subnet_id=`neutron net-show private | grep subnets | awk '{print $4}'`
neutron subnet-update $subnet_id --dns_nameservers list=true 8.8.8.8 8.8.4.4

# Disable STP on bridge
# ovs-vsctl set bridge br-eth1 stp_enable=true

# Workaround for the missing volume type id. TODO: remove this after it's fixed.
# This is also used for the wrong extra_specs format issue
cinder type-create blank
