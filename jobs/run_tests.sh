#!/bin/bash
source /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt

echo "Running tests on devstack: $DEVSTACK_FLOATING_IP"
ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $DEVSTACK_SSH_KEY ubuntu@$DEVSTACK_FLOATING_IP "source /home/ubuntu/devstack/openrc admin admin && /home/ubuntu/bin/run-all-tests.sh $JOB_TYPE"
exit $?

