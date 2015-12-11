#!/bin/bash
# Loading functions
source /usr/local/src/cinder-ci/jobs/utils.sh
set -e
source $KEYSTONERC

# Deploy devstack vm
source /usr/local/src/cinder-ci/jobs/deploy_devstack_vm.sh
