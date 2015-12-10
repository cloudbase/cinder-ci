#!/bin/bash
# Loading functions
source /usr/local/src/cinder-ci/jobs/utils.sh
set -e
source $KEYSTONERC

# Building devstack as a threaded job
echo `date -u +%H:%M:%S` "Started to build devstack as a threaded job"
nohup /usr/local/src/cinder-ci/jobs/deploy_devstack_vm.sh > /home/jenkins-slave/logs/devstack-build-log-$JOB_TYPE-$ZUUL_UUID 2>&1 &
pid_devstack=$!

# Building cinder windows vm as a threaded job
echo `date -u +%H:%M:%S` "Started to build cinder windows as a threaded job"
nohup /usr/local/src/cinder-ci/jobs/deploy_cinder_windows_vm.sh > /home/jenkins-slave/logs/cinder-windows-build-log-$JOB_TYPE-$ZUUL_UUID 2>&1 &
pid_cnd_win=$!

# Waiting for devstack threaded job to finish
wait $pid_devstack
cat /home/jenkins-slave/logs/devstack-build-log-$JOB_TYPE-$ZUUL_UUID

# Waiting for cinder windows threaded job to finish
wait $pid_cnd_win
cat /home/jenkins-slave/logs/cinder-windows-build-log-$JOB_TYPE-$ZUUL_UUID

source /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt

post_build_restart_cinder_windows_services $CINDER_FLOATING_IP $WINDOWS_USER $WINDOWS_PASSWORD

