#!/bin/bash
#
windows_node=$1
JOB_TYPE=$2
HYPERV_NODES=$3

# Loading all the needed functions
source /usr/local/src/cinder-ci/jobs/utils.sh

# Loading parameters
source /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt

# building HyperV node
echo $hyperv_node
join_windows $windows_node $WIN_USER $WIN_PASS $HYPERV_NODES

echo "Test that we have one cinder volume active"
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY 'source /home/ubuntu/keystonerc; CINDER_COUNT=$(cinder service-list | grep cinder-volume | grep -c -w up); if [ "$CINDER_COUNT" == 1 ];then cinder service-list; else cinder service-list; exit 1;fi' 20
