#!/bin/bash
basedir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
# Loading parameters
source $basedir/utils.sh
source /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt

# git prep
scp -r -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" -i $DEVSTACK_SSH_KEY $basedir/clonemap.yaml ubuntu@$DEVSTACK_IP:/home/ubuntu/
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "pip install zuul==2.5.2"
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "/home/ubuntu/.local/bin/zuul-cloner -m /home/ubuntu/clonemap.yaml -v git://git.openstack.org $ZUUL_PROJECT --zuul-branch $ZUUL_BRANCH --zuul-ref $ZUUL_REF --zuul-url $ZUUL_SITE/p --workspace /opt/stack"

# Run devstack
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "/home/ubuntu/bin/run_devstack.sh" 6
