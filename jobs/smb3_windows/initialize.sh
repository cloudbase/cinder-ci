#!/bin/bash
source /usr/local/src/cinder-ci/jobs/utils.sh
set -e

source $KEYSTONERC

# Deploy devstack vm
source /usr/local/src/cinder-ci/jobs/deploy_devstack_vm.sh

update_local_conf "/usr/local/src/cinder-ci/jobs/smb3_windows/local-conf-extra"

DEVSTACK_VM_STATUS="NOT_OK"
COUNT=0
while [ $DEVSTACK_VM_STATUS != "OK" ]
do
    if [ $COUNT -le 5 ]
    then
        COUNT=$(($COUNT + 1))
        set +e
        if (`nova list | grep "$NAME" > /dev/null 2>&1`)
        then 
            nova delete "$NAME"
            sleep 60
        fi
        set -e
        deploy_cinder_vm
        if [ $? -ne 0 ]
        then
            echo "Failed to deploy cinder vm! Failed at: deploy_cinder_vm"
            break
        fi
    
        prepare_networking
        if [ $? -ne 0 ]
        then
            echo "Failed to prepare networking for cinder vm! Failed at: prepare_networking"
            break
        fi
    
        prepare_devstack
        if [ $? -ne 0 ]
        then    
            echo "Failed to prepare devstack on cinder vm! Failed at: prepare_devstack"
            break
        fi
    
        run_devstack
        if [ $? -ne 0 ]
        then
            echo "Failed to install devstack on cinder vm! Failed at: run_devstack"
            break
        else
            DEVSTACK_VM_STATUS="OK"
        fi
    else
        echo "Counter for devstack deploy has been reached! Build has failed."
        exit 1
    fi
done

# Deploy Windows Cinder vm
source /usr/local/src/cinder-ci/jobs/deploy_cinder_windows_vm.sh
