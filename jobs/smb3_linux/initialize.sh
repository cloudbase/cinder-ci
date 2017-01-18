#!/bin/bash
# Loading functions
source /usr/local/src/cinder-ci-2016/jobs/utils.sh
set -e
source $KEYSTONERC

# Deploy devstack vm
source /usr/local/src/cinder-ci-2016/jobs/deploy_devstack_vm.sh
