#!/bin/bash
basedir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
# Loading parameters
source $basedir/utils.sh
source /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt

# Run devstack
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "/home/ubuntu/bin/run_devstack.sh" 6
