source /usr/local/src/cinder-ci/jobs/utils.sh

source $KEYSTONERC

# Deploy devstack vm
source /usr/local/src/cinder-ci/jobs/deploy_devstack_vm.sh

# Set up the smbfs shares list
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP \
    $DEVSTACK_SSH_KEY "echo $DEVSTACK_FLOATING_IP > /etc/cinder/smbfs_shares_config" 1

update_local_conf "/usr/local/src/cinder-ci/jobs/smb3_linux/local-conf-extra"

run_devstack
