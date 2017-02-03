#!/bin/bash
source /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt

if [[ ! -z $RUN_TESTS ]] && [[ $RUN_TESTS == "no" ]]; then
    echo "Init phase done, not running tests"
    exit 0
else
    echo "Running tests on devstack: $DEVSTACK_FLOATING_IP"
    source /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt
    ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $DEVSTACK_SSH_KEY ubuntu@$DEVSTACK_FLOATING_IP "source /home/ubuntu/keystonerc && /home/ubuntu/bin/run-all-tests.sh $JOB_TYPE"
    exit $?
fi
