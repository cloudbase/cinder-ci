#!/bin/bash

source /usr/local/src/cinder-ci-2016/jobs/utils.sh
source /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt

# Functions section
update_local_conf (){
    if [ $JOB_TYPE = "smb3_linux" ]
    then 
        EXTRA_OPTS_PATH="/usr/local/src/cinder-ci-2016/jobs/smb3_linux/local-conf-extra"
    elif [ $JOB_TYPE = "smb3_windows" ]
        then
            EXTRA_OPTS_PATH="/usr/local/src/cinder-ci-2016/jobs/smb3_windows/local-conf-extra"
        elif [ $JOB_TYPE = "iscsi" ]
            then            
                EXTRA_OPTS_PATH="/usr/local/src/cinder-ci-2016/jobs/iscsi/local-conf-extra"
            else 
                echo "No proper JOB_TYPE received!"
                exit 1
    fi
    scp -v -r -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" \
        -i $DEVSTACK_SSH_KEY $EXTRA_OPTS_PATH \
        ubuntu@$DEVSTACK_FLOATING_IP:/home/ubuntu/devstack
    run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY \
        "cat /home/ubuntu/devstack/local-conf-extra >> /home/ubuntu/devstack/local.conf" 12
}
# Main section

NAME="cnd-dvs-$ZUUL_CHANGE-$ZUUL_PATCHSET"

case "$JOB_TYPE" in
         iscsi)
            NAME="$NAME-is"
            ;;
        smb3_windows)
            NAME="$NAME-sw"
            ;;
        smb3_linux)
            NAME="$NAME-sl"
            ;;
esac

if [[ ! -z $IS_DEBUG_JOB ]] && [[ $IS_DEBUG_JOB = "yes" ]]; then 
	NAME="$NAME-dbg"
fi

export NAME=$NAME
echo NAME=$NAME | tee -a /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt
echo "exporting JOB_TYPE=$JOB_TYPE and ZUUL_UUID=$ZUUL_UUID"
export ZUUL_UUID
export JOB_TYPE

NET_ID=$(nova net-list | grep 'private' | awk '{print $2}')
echo NET_ID=$NET_ID | tee -a /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt

VM_OK=1
while [ $VM_OK -ne 0 ]; do
    echo "Deploying devstack $NAME"
    VMID=$(nova boot --config-drive true --flavor cinder.linux --image $DEVSTACK_IMAGE --key-name default --security-groups devstack --nic net-id="$NET_ID" --nic net-id="$NET_ID" "$NAME" --poll | awk '{if (NR == 21) {print $4}}')
    NOVABOOT_EXIT=$?

    if [ $NOVABOOT_EXIT -ne 0 ]
    then
        echo "Failed to create devstack VM: $VMID"
       nova show "$VMID"
       exit 1
    fi

    export VMID=$VMID

    echo "Fetching devstack VM fixed IP address"
    FIXED_IP=$(nova show "$VMID" | grep "private network" | awk '{print $5}')
    export FIXED_IP="${FIXED_IP//,}"

    COUNTER=0
    while [ -z "$FIXED_IP" ]
    do
        if [ $COUNTER -ge 10 ]
        then
           echo "Failed to get fixed IP"
            echo "nova show output:"
            nova show "$VMID"
            echo "nova console-log output:"
            nova console-log "$VMID"
            echo "neutron port-list output:"
            neutron port-list -D -c device_id -c fixed_ips | grep $VMID
            exit 1
        fi
        sleep 15
        FIXED_IP=$(nova show "$VMID" | grep "private network" | awk '{print $5}')
	export FIXED_IP="${FIXED_IP//,}"
        COUNTER=$(($COUNTER + 1))
    done

    echo "nova show output:"
    nova show "$VMID"

    echo "Wait for answer on port 22 on devstack"
    sleep 30

    #exec_with_retry 25 30 "nc -z -w3 $DEVSTACK_FLOATING_IP 22"
    set +e
    wait_for_listening_port $FIXED_IP 22 20
    status=$?
    set -e
    if [ $status -eq 0 ]; then
        VM_OK=0
    else
        echo "VM connectivity NOT OK, rebooting VM"
        nova reboot "$VMID"
        sleep 90
        set +e
        wait_for_listening_port $FIXED_IP 22 20
        status=$?
        set -e
        if [ $status -eq 0 ]; then
            VM_OK=0
            echo "VM connectivity OK"
        else
            #exec_with_retry "nova floating-ip-disassociate $VMID $FLOATING_IP" 15 5
            echo "nova console-log $VMID:"; nova console-log "$VMID"; echo "Failed listening for ssh port on devstack"
            echo "Deleting VM $VMID"
            nova delete $VMID
        fi
    fi
done
 
DEVSTACK_FLOATING_IP=$FIXED_IP
echo DEVSTACK_FLOATING_IP=$FIXED_IP | tee -a /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt
echo FIXED_IP=$FIXED_IP | tee -a /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt
echo VMID=$VMID | tee -a  /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt
# Since we now have all the infos necessary for building HyperV and ws2012 nodes go ahead and build em
echo "Starting building HyperV and ws2012 nodes"

export LOG_DIR='C:\Openstack\logs\'
nohup /usr/local/src/cinder-ci-2016/jobs/build_hyperv.sh $hyperv01 $JOB_TYPE > /home/jenkins-slave/logs/hyperv-$hyperv01-build-log-$ZUUL_UUID-$JOB_TYPE.log 2>&1 &
pid_hv01=$!

nohup /usr/local/src/cinder-ci-2016/jobs/build_hyperv.sh $hyperv02 $JOB_TYPE > /home/jenkins-slave/logs/hyperv-$hyperv02-build-log-$ZUUL_UUID-$JOB_TYPE.log 2>&1 &
pid_hv02=$!

nohup /usr/local/src/cinder-ci-2016/jobs/build_windows.sh $ws2012r2 $JOB_TYPE "$hyperv01,$hyperv02" > /home/jenkins-slave/logs/ws2012-build-log-$ZUUL_UUID-$JOB_TYPE.log 2>&1 &
pid_ws2012=$!

echo "Copy scripts to devstack VM"
scp -v -r -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" -i $DEVSTACK_SSH_KEY /usr/local/src/cinder-ci-2016/devstack_vm/* ubuntu@$DEVSTACK_FLOATING_IP:/home/ubuntu/

echo "Copy devstack_params file to devstack VM"
scp -v -r -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" -i $DEVSTACK_SSH_KEY /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt ubuntu@$DEVSTACK_FLOATING_IP:/home/ubuntu/bin/devstack_params.sh

# Repository section
echo "setup apt-cacher-ng:"
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY 'echo "Acquire::http { Proxy \"http://10.20.1.32\" };" | sudo tee --append /etc/apt/apt.conf.d/90-apt-proxy.conf' 12
echo "clean any apt files:"
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "sudo rm -rfv /var/lib/apt/lists/*" 12
echo "apt-get update:"
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "sudo apt-get update --assume-yes" 12
echo "apt-get upgrade:"
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY 'sudo DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical apt-get -q -y -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" upgrade' 12
echo "apt-get cleanup:"
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "sudo apt-get autoremove --assume-yes" 12

#set timezone to UTC
echo "Set local time to UTC on devstack"
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "sudo ln -fs /usr/share/zoneinfo/UTC /etc/localtime" 12

echo "Ensure cifs-utils is present"
set +e
exit_code_cifs=0
echo "Allowing 30 seconds sleep for /var/lib/dpkg/lock to release"
sleep 30
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "sudo apt-get install cifs-utils -y -o Debug::pkgProblemResolver=true -o Debug::Acquire::http=true -f" 12
if [ $? -ne 0 ]; then
    sleep 5
    run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "sudo wget http://10.20.1.14:8080/cifs-utils_6.0-1ubuntu2_amd64.deb -O /tmp/cifs-utils_6.0-1ubuntu2_amd64.deb && sudo dpkg --install /tmp/cifs-utils_6.0-1ubuntu2_amd64.deb" 12
    exit_code_cifs=$?
fi
set -e
if [ $exit_code_cifs -ne 0 ]; then
    exit 1
fi

echo "Update git repos to latest"
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "/home/ubuntu/bin/update_devstack_repos.sh --branch $ZUUL_BRANCH --build-for $ZUUL_PROJECT" 6

echo "Ensure configs are copied over"
scp -v -r -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" -i $DEVSTACK_SSH_KEY /usr/local/src/cinder-ci-2016/devstack_vm/devstack/* ubuntu@$DEVSTACK_FLOATING_IP:/home/ubuntu/devstack

run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "mkdir -p -m 777 /openstack/volumes" 6

#get locally the vhdx files used by tempest
echo "Downloading the images for devstack"
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "mkdir -p /home/ubuntu/devstack/files/images/" 6
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "wget http://10.20.1.14:8080/cirros-0.3.3-x86_64.vhdx -O /home/ubuntu/devstack/files/images/cirros-0.3.3-x86_64.vhdx" 6

echo "Reserve VLAN range for test"
set +e
VLAN_RANGE=`/usr/local/src/cinder-ci-2016/vlan_allocation.py -a $VMID`
echo "VLAN range selected is $VLAN_RANGE"
if [ ! -z "$VLAN_RANGE" ]; then
    run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "sed -i 's/TENANT_VLAN_RANGE.*/TENANT_VLAN_RANGE='$VLAN_RANGE'/g' /home/ubuntu/devstack/local.conf" 3
fi
set -e

echo "Run gerrit-git-prep on devstack"
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY  "/home/ubuntu/bin/gerrit-git-prep.sh --zuul-site $ZUUL_SITE --gerrit-site $ZUUL_SITE --zuul-ref $ZUUL_REF --zuul-change $ZUUL_CHANGE --zuul-project $ZUUL_PROJECT" 6

# Set up the smbfs shares list
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "sudo mkdir -p /etc/cinder && sudo chown ubuntu /etc/cinder" 6
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "sudo echo //$DEVSTACK_FLOATING_IP/openstack/volumes -o guest > /etc/cinder/smbfs_shares_config" 6
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY 'mkdir -p /openstack/logs; chmod 777 /openstack/logs; sudo chown nobody:nogroup /openstack/logs' 6

# Update local conf
update_local_conf
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "sed -i '3 i\branch=$ZUUL_BRANCH' /home/ubuntu/devstack/local.sh"

nohup /usr/local/src/cinder-ci-2016/jobs/build_devstack.sh >> /home/jenkins-slave/logs/build-devstack-log-$ZUUL_UUID-$JOB_TYPE.log 2>&1 &
pid_devstack=$!

TIME_COUNT=0
PROC_COUNT=4

echo `timestamp` "Start waiting for parallel init jobs."

finished_devstack=0;
finished_hv01=0;
finished_hv02=0;
finished_ws2012=0;

while [[ $TIME_COUNT -lt 60 ]] && [[ $PROC_COUNT -gt 0 ]]; do
    if [[ $finished_devstack -eq 0 ]]; then
        ps -p $pid_devstack > /dev/null 2>&1 || finished_devstack=$?
        [[ $finished_devstack -ne 0 ]] && PROC_COUNT=$(( $PROC_COUNT - 1 )) && echo `date -u +%H:%M:%S` "Finished building devstack"
    fi
    if [[ $finished_hv01 -eq 0 ]]; then
        ps -p $pid_hv01 > /dev/null 2>&1 || finished_hv01=$?
        [[ $finished_hv01 -ne 0 ]] && PROC_COUNT=$(( $PROC_COUNT - 1 )) && echo `date -u +%H:%M:%S` "Finished building $hyperv01"
    fi
    if [[ $finished_ws2012 -eq 0 ]]; then
        ps -p $pid_ws2012 > /dev/null 2>&1 || finished_ws2012=$?
        [[ $finished_ws2012 -ne 0 ]] && PROC_COUNT=$(( $PROC_COUNT - 1 )) && echo `date -u +%H:%M:%S` "Finished building $ws2012r2"
    fi
    if [[ $finished_hv02 -eq 0 ]]; then
        ps -p $pid_hv02 > /dev/null 2>&1 || finished_hv02=$?
        [[ $finished_hv02 -ne 0 ]] && PROC_COUNT=$(( $PROC_COUNT - 1 )) && echo `date -u +%H:%M:%S` "Finished building $hyperv02"
    fi
    if [[ $PROC_COUNT -gt 0 ]]; then
        sleep 1m
        TIME_COUNT=$(( $TIME_COUNT +1 ))
    fi
done

echo `timestamp` "Finished waiting for the parallel init jobs."
echo `timestamp` "We looped $TIME_COUNT times, and when finishing we have $PROC_COUNT threads still active"

OSTACK_PROJECT=`echo "$ZUUL_PROJECT" | cut -d/ -f2`

if [[ ! -z $IS_DEBUG_JOB ]] && [[ $IS_DEBUG_JOB == "yes" ]]
    then
        echo "All build logs can be found in http://64.119.130.115/debug/$OSTACK_PROJECT/$ZUUL_CHANGE/$ZUUL_PATCHSET/"
    else
        echo "All build logs can be found in http://64.119.130.115/$OSTACK_PROJECT/$ZUUL_CHANGE/$ZUUL_PATCHSET/"
fi

if [[ $PROC_COUNT -gt 0 ]]; then
    kill -9 $pid_devstack > /dev/null 2>&1
    kill -9 $pid_hv01 > /dev/null 2>&1
    kill -9 $pid_hv02 > /dev/null 2>&1
    echo "Not all build threads finished in time, initialization process failed."
    exit 1
fi

echo "Post init on cinder node: $ws2012r2"
post_build_restart_cinder_windows_services $ws2012r2 $WIN_USER $WIN_PASS
echo "Post init on compute01 node: $hyperv01"
post_build_restart_hyperv_services $hyperv01 $WIN_USER $WIN_PASS
echo "Post init on compute02 node: $hyperv02"
post_build_restart_hyperv_services $hyperv02 $WIN_USER $WIN_PASS

echo "Test that we have one cinder volume active"
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY 'source /home/ubuntu/keystonerc; CINDER_COUNT=$(openstack volume service list | grep cinder-volume | grep -c -w up); if [ "$CINDER_COUNT" == 1 ];then openstack volume service list ; else openstack volume service list; exit 1;fi' 20

if [[ "$ZUUL_BRANCH" == "master" ]] || [[ "$ZUUL_BRANCH" == "stable/ocata" ]]; then
    run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "url=\$(grep transport_url /etc/nova/nova-dhcpbridge.conf | awk '{print \$3}'); nova-manage cell_v2 simple_cell_setup --transport-url \$url >> /opt/stack/logs/screen/create_cell.log"
fi

# Run post_stack
echo "Run post_stack scripts on devstack"
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "source /home/ubuntu/keystonerc && /home/ubuntu/bin/post_stack.sh" 6
if [ $? -ne 0 ]
then
    echo "Failed post_stack!"
    exit 1
else
    DEVSTACK_VM_STATUS="OK"
    echo "Initialize part finished"
fi
