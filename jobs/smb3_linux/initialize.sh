#!/bin/bash
source /usr/local/src/cinder-ci/jobs/utils.sh
set -e

source $KEYSTONERC

# Deploy devstack vm
source /usr/local/src/cinder-ci/jobs/deploy_devstack_vm.sh

# Set up the smbfs shares list
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP \
    $DEVSTACK_SSH_KEY "sudo mkdir -p /etc/cinder && sudo chown ubuntu /etc/cinder" 1
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP \
    $DEVSTACK_SSH_KEY "sudo echo //$DEVSTACK_FLOATING_IP/openstack/volumes -o guest > /etc/cinder/smbfs_shares_config" 1

run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP \
    $DEVSTACK_SSH_KEY "sudo apt-get --assume-yes install cifs-utils"

update_local_conf "/usr/local/src/cinder-ci/jobs/smb3_linux/local-conf-extra"

run_devstack
