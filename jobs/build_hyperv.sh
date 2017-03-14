#!/bin/bash
#
basedir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
hyperv_node=$1
JOB_TYPE=$2
# Loading all the needed functions
source $basedir/utils.sh

# Loading parameters
source /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt
echo FIXED_IP=$FIXED_IP
export LOG_DIR='C:\Openstack\logs\'
export FIXED_IP

# building HyperV node
echo $hyperv_node
join_hyperv $hyperv_node $WIN_USER $WIN_PASS

