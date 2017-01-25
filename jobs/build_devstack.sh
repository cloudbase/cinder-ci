#!/bin/bash
# Loading parameters
source /usr/local/src/cinder-ci-2016/jobs/utils.sh
source /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt

# Run devstack
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "source /home/ubuntu/keystonerc && /home/ubuntu/bin/run_devstack.sh" 6
