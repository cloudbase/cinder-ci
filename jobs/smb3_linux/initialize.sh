#!/bin/bash
# Loading functions
source /usr/local/src/cinder-ci/jobs/utils.sh
set -e
source $KEYSTONERC

# Building devstack as a threaded job
echo `date -u +%H:%M:%S` "Started to build devstack as a threaded job"
nohup /usr/local/src/cinder-ci/jobs/deploy_devstack_vm.sh > /home/jenkins-slave/logs/devstack-build-log-$JOB_TYPE-$ZUUL_UUID 2>&1 &
pid_devstack=$!

# Waiting for devstack threaded job to finish
wait $pid_devstack
cat /home/jenkins-slave/logs/devstack-build-log-$JOB_TYPE-$ZUUL_UUID

