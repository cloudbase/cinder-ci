#!/bin/bash
basedir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
# Loading functions
source $basedir/../utils.sh
set -e
source $KEYSTONERC

# Deploy devstack vm
source $basedir/../deploy_devstack_vm.sh
