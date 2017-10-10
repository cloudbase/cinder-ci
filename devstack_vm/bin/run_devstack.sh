#!/bin/bash
basedir="/home/ubuntu/bin"
. $basedir/utils.sh
. $basedir/devstack_params.sh

set -x
set -e
sudo ifconfig eth1 promisc up
#sudo ip -f inet r replace default via 10.250.0.1 dev eth0

#HOSTNAME=$(hostname)

#sudo sed -i '2i127.0.0.1  '$HOSTNAME'' /etc/hosts

# Add pip cache for devstack
mkdir -p $HOME/.pip
echo "[global]" > $HOME/.pip/pip.conf
echo "trusted-host = 144.76.59.195" >> $HOME/.pip/pip.conf
echo "index-url = http://144.76.59.195:8099/cloudbase/CI/+simple/" >> $HOME/.pip/pip.conf
echo "[install]" >> $HOME/.pip/pip.conf
echo "trusted-host = 144.76.59.195" >> $HOME/.pip/pip.conf

sudo mkdir -p /root/.pip
sudo cp $HOME/.pip/pip.conf /root/.pip/
sudo chown -R root:root /root/.pip

#Update packages to latest version
sudo pip install -U six
sudo pip install -U kombu
sudo pip install -U pbr

DEVSTACK_LOGS="/opt/stack/logs/screen"
LOCALRC="/home/ubuntu/devstack/localrc"
LOCALCONF="/home/ubuntu/devstack/local.conf"
PBR_LOC="/opt/stack/pbr"
# Clean devstack logs
sudo rm -f "$DEVSTACK_LOGS/*"
sudo rm -rf "$PBR_LOC"

MYIP=$(/sbin/ifconfig eth0 2>/dev/null| grep "inet addr:" 2>/dev/null| sed 's/.*inet addr://g;s/ .*//g' 2>/dev/null)

if [ -e "$LOCALCONF" ]
then
    	[ -z "$MYIP" ] && exit 1
        sed -i 's/^HOST_IP=.*/HOST_IP='$MYIP'/g' "$LOCALCONF"
fi

if [ -e "$LOCALRC" ]
then
    	[ -z "$MYIP" ] && exit 1
        sed -i 's/^HOST_IP=.*/HOST_IP='$MYIP'/g' "$LOCALRC"
fi

# exclude in-use snapshots tests for stable branches, this feature is only supported in pike
if [ "$ZUUL_BRANCH" == "stable/newton" ] || [ "$ZUUL_BRANCH" == "stable/ocata" ]; then
cat <<EOT >> /home/ubuntu/bin/excluded-tests-smb3_windows.txt
#test_volume_boot_pattern
tempest.scenario.test_volume_boot_pattern.TestVolumeBootPattern.test_create_ebs_image_and_check_boot
tempest.scenario.test_volume_boot_pattern.TestVolumeBootPattern.test_volume_boot_pattern
tempest.scenario.test_volume_boot_pattern.TestVolumeBootPatternV2.test_create_ebs_image_and_check_boot
tempest.scenario.test_volume_boot_pattern.TestVolumeBootPatternV2.test_volume_boot_pattern

#volume.admin.test_volume_types.VolumeTypes
tempest.api.volume.admin.test_volume_types.VolumeTypesV1Test.test_volume_crud_with_volume_type_and_extra_specs
tempest.api.volume.admin.test_volume_types.VolumeTypesV1Test.test_volume_type_create_get_delete
tempest.api.volume.admin.test_volume_types.VolumeTypesV1Test.test_volume_type_encryption_create_get_delete
tempest.api.volume.admin.test_volume_types.VolumeTypesV1Test.test_volume_type_list
tempest.api.volume.admin.test_volume_types.VolumeTypesV2Test.test_volume_crud_with_volume_type_and_extra_specs
tempest.api.volume.admin.test_volume_types.VolumeTypesV2Test.test_volume_type_create_get_delete
tempest.api.volume.admin.test_volume_types.VolumeTypesV2Test.test_volume_type_encryption_create_get_delete
tempest.api.volume.admin.test_volume_types.VolumeTypesV2Test.test_volume_type_list

# This driver does not support snapshotting in-use volumes
tempest.api.volume.test_volumes_snapshots.VolumesV1SnapshotTestJSON.test_snapshot_create_with_volume_in_use
tempest.api.volume.test_volumes_snapshots.VolumesV1SnapshotTestJSON.test_snapshot_create_offline_delete_online
tempest.api.volume.test_volumes_snapshots.VolumesV1SnapshotTestJSON.test_snapshot_delete_with_volume_in_use
tempest.api.volume.test_volumes_snapshots.VolumesSnapshotTestJSON.test_snapshot_create_with_volume_in_use
tempest.api.volume.test_volumes_snapshots.VolumesSnapshotTestJSON.test_snapshot_create_offline_delete_online
tempest.api.volume.test_volumes_snapshots.VolumesSnapshotTestJSON.test_snapshot_delete_with_volume_in_use
EOT
fi

cd /home/ubuntu/devstack
git pull

# Revert the driver disable patch
cd /opt/stack/cinder
git config --global user.email "microsoft_cinder_ci@microsoft.com"
git config --global user.name "Microsoft Cinder CI"

cd /opt/stack/tempest
git_timed fetch git://git.openstack.org/openstack/tempest refs/changes/13/433213/3
cherry_pick FETCH_HEAD

cd /home/ubuntu/devstack

./unstack.sh

#Fix for unproper ./unstack.sh
screen_pid=$(ps auxw | grep -i screen | grep -v grep | awk '{print $2}')
if [[ -n $screen_pid ]] 
then
    kill -9 $screen_pid
    #In case there are "DEAD ????" screens, we remove them
    screen -wipe
fi

# stack.sh output log
STACK_LOG="/opt/stack/logs/stack.sh.txt"
# keep this many rotated stack.sh logs
STACK_ROTATE_LIMIT=6
rotate_log $STACK_LOG $STACK_ROTATE_LIMIT

#sed -i "s#PIP_GET_PIP_URL=https://bootstrap.pypa.io/get-pip.py#PIP_GET_PIP_URL=http://10.20.1.14:8080/get-pip.py#g" /home/ubuntu/devstack/tools/install_pip.sh

#Requested by Claudiu Belu, temporary hack:
sudo pip install -U /opt/stack/networking-hyperv

#set -o pipefail
#./stack.sh 2>&1 | tee $STACK_LOG

nohup ./stack.sh > $STACK_LOG 2>&1 &
pid=$!
wait $pid
cat $STACK_LOG

#TCP_PORTS=(80 137 443 3260 3306 5000 5355 5672 6000 6001 6002 8000 8003 8004 8080 8773 8774 8775 8776 8777 9191 9292 9696 35357)
#firewall_manage_ports $hyperv01_ip add enable ${TCP_PORTS[@]}
#firewall_manage_ports $hyperv02_ip add enable ${TCP_PORTS[@]}
#firewall_manage_ports $ws2012r2_ip add enable ${TCP_PORTS[@]}
