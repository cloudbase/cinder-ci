#!/bin/bash
basedir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
# Loading functions
source $basedir/utils.sh

echo JOB_TYPE=$JOB_TYPE | tee /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt
echo ZUUL_PROJECT=$ZUUL_PROJECT | tee -a /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt
echo ZUUL_BRANCH=$ZUUL_BRANCH | tee -a /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt
echo ZUUL_CHANGE=$ZUUL_CHANGE | tee -a /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt
echo ZUUL_PATCHSET=$ZUUL_PATCHSET | tee -a /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt
echo ZUUL_URL=$ZUUL_URL | tee -a /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt
echo ZUUL_UUID=$ZUUL_UUID | tee -a /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt
echo IS_DEBUG_JOB=$IS_DEBUG_JOB | tee -a /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt
echo DEVSTACK_SSH_KEY=$DEVSTACK_SSH_KEY | tee -a /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt
echo WIN_USER=$WIN_USER >> /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt
echo WIN_PASS=$WIN_PASS >> /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt

ESXI_HOST=$NODE_NAME
OPN_PROJECT=${ZUUL_PROJECT#*/}
DEVSTACK_NAME="dvs-$OPN_PROJECT-$ZUUL_CHANGE-$ZUUL_PATCHSET"
HV1_NAME="hv1-$OPN_PROJECT-$ZUUL_CHANGE-$ZUUL_PATCHSET"
WIN_NAME="win2016-$OPN_PROJECT-$ZUUL_CHANGE-$ZUUL_PATCHSET"

if [[ ! -z $IS_DEBUG_JOB ]] && [[ $IS_DEBUG_JOB == "yes" ]]; then
    DEVSTACK_NAME="$DEVSTACK_NAME-dbg"
    HV1_NAME="$HV1_NAME-dbg"
    WIN_NAME="$WIN_NAME-dbg"
    DEBUG="--debug-job"
fi

export DEVSTACK_NAME=$DEVSTACK_NAME
export HV1_NAME=$HV1_NAME
export WIN_NAME=$WIN_NAME
export ESXI_HOST=$ESXI_HOST

echo DEVSTACK_NAME=$DEVSTACK_NAME | tee -a /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt
echo HV1_NAME=$HV1_NAME | tee -a /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt
echo WIN_NAME=$WIN_NAME | tee -a /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt
echo ESXI_HOST=$ESXI_HOST | tee -a /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt

export ZUUL_UUID
export JOB_TYPE

echo "Deploying devstack $NAME"

# make sure we use latest esxi scripts
scp -r -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" -i $DEVSTACK_SSH_KEY $basedir/../esxi/* root@$ESXI_HOST:/vmfs/volumes/datastore1/

# Build the env
run_ssh_cmd_with_retry root@$ESXI_HOST $DEVSTACK_SSH_KEY "/vmfs/volumes/datastore1/build-env.sh --project $ZUUL_PROJECT --zuul-change $ZUUL_CHANGE --zuul-patchset $ZUUL_PATCHSET $LIVE_MIGRATION $DEBUG"
status=$?
if [ $status -ne 0 ]; then
    echo "Something went wrong with the creations of VMs. Bailing out!"
    exit 1
fi
echo "Fetching VMs fixed IP address"

DEVSTACK_IP=$(run_ssh_cmd_with_retry root@$ESXI_HOST $DEVSTACK_SSH_KEY "/vmfs/volumes/datastore1/get-vm-ip.sh $DEVSTACK_NAME")
HV1_IP=$(run_ssh_cmd_with_retry root@$ESXI_HOST $DEVSTACK_SSH_KEY "/vmfs/volumes/datastore1/get-vm-ip.sh $HV1_NAME")
WIN_IP=$(run_ssh_cmd_with_retry root@$ESXI_HOST $DEVSTACK_SSH_KEY "/vmfs/volumes/datastore1/get-vm-ip.sh $WIN_NAME")

#export FIXED_IP="${FIXED_IP//,}"
export DEVSTACK_IP="$DEVSTACK_IP"
export HV1_IP="$HV1_IP"
export WIN_IP="$WIN_IP"
    
COUNT=1
while [ -z "$DEVSTACK_IP" ] || [ -z "$HV1_IP" ] || [ -z "$WIN_IP" ] || [ "$DEVSTACK_IP" == "unset" ] || [ "$HV1_IP" == "unset" ] || [ "$WIN_IP" == "unset" ]; do
    if [ $COUNT -lt 15 ]; then
        sleep 15
        DEVSTACK_IP=$(run_ssh_cmd_with_retry root@$ESXI_HOST $DEVSTACK_SSH_KEY "/vmfs/volumes/datastore1/get-vm-ip.sh $DEVSTACK_NAME")
        HV1_IP=$(run_ssh_cmd_with_retry root@$ESXI_HOST $DEVSTACK_SSH_KEY "/vmfs/volumes/datastore1/get-vm-ip.sh $HV1_NAME")
        WIN_IP=$(run_ssh_cmd_with_retry root@$ESXI_HOST $DEVSTACK_SSH_KEY "/vmfs/volumes/datastore1/get-vm-ip.sh $WIN_NAME")

        export DEVSTACK_IP="$DEVSTACK_IP"
        export HV1_IP="$HV1_IP"
	export WIN_IP="$WIN_IP"
        COUNT=$(($COUNT + 1))
    else
        echo "Failed to get all fixed IPs"
        echo "We got:"
        echo "$DEVSTACK_NAME has IP $DEVSTACK_IP"
        echo "$HV1_NAME has IP $HV1_IP"
        echo "$WIN_NAME has IP $WIN_IP"
        exit 1
    fi
done

echo "Devstack management IP is : $DEVSTACK_IP"
echo "Hyper-V management IP is : $HV1_IP"
echo "Windows management IP is : $WIN_IP"

echo "VMs details:"
echo "------------------------------------------------------"
echo "------------------------------------------------------"
echo "DEVSTACK VM:"
run_ssh_cmd_with_retry root@$ESXI_HOST $DEVSTACK_SSH_KEY "/vmfs/volumes/datastore1/get-vm-details.sh $DEVSTACK_NAME"
echo "------------------------------------------------------"
echo "------------------------------------------------------"
echo "HYPER-V VM:"
run_ssh_cmd_with_retry root@$ESXI_HOST $DEVSTACK_SSH_KEY "/vmfs/volumes/datastore1/get-vm-details.sh $HV1_NAME"
echo "------------------------------------------------------"
echo "------------------------------------------------------"
echo "------------------------------------------------------"
echo "------------------------------------------------------"
echo "WIN VM:"
run_ssh_cmd_with_retry root@$ESXI_HOST $DEVSTACK_SSH_KEY "/vmfs/volumes/datastore1/get-vm-details.sh $WIN_NAME"
echo "------------------------------------------------------"
echo "------------------------------------------------------"

sleep 60

echo "Probing for connectivity on IP $DEVSTACK_IP"
set +e
wait_for_listening_port $DEVSTACK_IP 22 30
probe_status=$?
set -e
if [ $probe_status -eq 0 ]; then
    VM_OK=0
    echo "VM connectivity OK"

else
    echo "VM connectivity NOT OK, bailing out!"
    exit 1
fi

echo DEVSTACK_IP=$DEVSTACK_IP | tee -a /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt
echo HV1_IP=$HV1_IP | tee -a /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt
echo WIN_IP=$WIN_IP | tee -a /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt
echo ws2012r2=$WIN_IP | tee -a /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt
echo hyperv01=$HV1_IP | tee -a /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt

hyperv01=$HV1_IP
ws2012r2=$WIN_IP

update_local_conf (){
    if [ $JOB_TYPE = "smb3_linux" ]
    then
        EXTRA_OPTS_PATH="$basedir/smb3_linux/local-conf-extra"
    elif [ $JOB_TYPE = "smb3_windows" ]
        then
            EXTRA_OPTS_PATH="$basedir/smb3_windows/local-conf-extra"
        elif [ $JOB_TYPE = "iscsi" ]
            then
                EXTRA_OPTS_PATH="$basedir/iscsi/local-conf-extra"
            else
                echo "No proper JOB_TYPE received!"
                exit 1
    fi
    scp -r -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" \
        -i $DEVSTACK_SSH_KEY $EXTRA_OPTS_PATH \
        ubuntu@$DEVSTACK_FLOATING_IP:/home/ubuntu/devstack
    run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY \
        "cat /home/ubuntu/devstack/local-conf-extra >> /home/ubuntu/devstack/local.conf" 12
}

# Set ip for data network and bring up the interface
echo "Setting data network IP for $DEVSTACK_NAME to 10.10.1.1/24 on interface eth1" 1
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_IP $DEVSTACK_SSH_KEY 'echo "auto eth1" | sudo tee -a /etc/network/interfaces' 1
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_IP $DEVSTACK_SSH_KEY 'echo "iface eth1 inet static" | sudo tee -a /etc/network/interfaces' 1
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_IP $DEVSTACK_SSH_KEY 'echo "     address 10.10.1.1" | sudo tee -a /etc/network/interfaces' 1
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_IP $DEVSTACK_SSH_KEY 'echo "     netmask 255.255.255.0" | sudo tee -a /etc/network/interfaces' 1
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_IP $DEVSTACK_SSH_KEY 'sudo ifup eth1' 1
echo "Network configuration for $DEVSTACK_NAME is:"
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_IP $DEVSTACK_SSH_KEY 'ifconfig -a' 1

export DEVSTACK_FLOATING_IP=$DEVSTACK_IP
export FIXED_IP=$DEVSTACK_IP

echo DEVSTACK_FLOATING_IP=$DEVSTACK_IP | tee -a /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt
echo FIXED_IP=$DEVSTACK_IP | tee -a /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt
# Since we now have all the infos necessary for building HyperV and ws2012 nodes go ahead and build em
echo "Starting building HyperV and ws2012 nodes"

export LOG_DIR='C:\Openstack\logs\'

echo "Copy scripts to devstack VM"
scp -r -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" -i $DEVSTACK_SSH_KEY $basedir/../devstack_vm/* ubuntu@$DEVSTACK_FLOATING_IP:/home/ubuntu/

echo "Copy devstack_params file to devstack VM"
scp -r -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" -i $DEVSTACK_SSH_KEY /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt ubuntu@$DEVSTACK_FLOATING_IP:/home/ubuntu/bin/devstack_params.sh

# Repository section
echo "setup apt-cacher-ng:"
#run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY 'echo "Acquire::http { Proxy \"http://10.20.1.36:8000\" };" | sudo tee --append /etc/apt/apt.conf.d/90-apt-proxy.conf' 12
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
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "sudo apt-get install cifs-utils smbclient -y -o Debug::pkgProblemResolver=true -o Debug::Acquire::http=true -f" 12
if [ $? -ne 0 ]; then
    sleep 5
    run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "sudo wget http://144.76.59.195:8088/cifs-utils_6.0-1ubuntu2_amd64.deb -O /tmp/cifs-utils_6.0-1ubuntu2_amd64.deb && sudo dpkg --install /tmp/cifs-utils_6.0-1ubuntu2_amd64.deb" 12
    exit_code_cifs=$?
fi
set -e
if [ $exit_code_cifs -ne 0 ]; then
    exit 1
fi

echo "Update git repos to latest"
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "/home/ubuntu/bin/update_devstack_repos.sh --branch $ZUUL_BRANCH --build-for $ZUUL_PROJECT" 6

run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "sudo mkdir -p -m 777 /openstack/volumes" 6

#get locally the vhdx files used by tempest
echo "Downloading the images for devstack"
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "mkdir -p /home/ubuntu/devstack/files/images/" 6
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "wget http://144.76.59.195:8088/cirros-0.3.3-x86_64.vhdx -O /home/ubuntu/devstack/files/images/cirros-0.3.3-x86_64.vhdx" 6

set -e

# Set up the smbfs shares list
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "sudo mkdir -p /etc/cinder && sudo chown ubuntu /etc/cinder" 6
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "sudo echo //$DEVSTACK_FLOATING_IP/openstack/volumes -o guest > /etc/cinder/smbfs_shares_config" 6
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY 'sudo mkdir -p /openstack/logs; sudo chmod 777 /openstack/logs; sudo chown nobody:nogroup /openstack/logs' 6

# Update local conf
update_local_conf
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "sed -i '3 i\branch=$ZUUL_BRANCH' /home/ubuntu/devstack/local.sh"

# make sure timezone is set to utc
run_wsman_cmd $HV1_IP $WIN_USER $WIN_PASS 'powershell -ExecutionPolicy RemoteSigned set-timezone -id UTC'
run_wsman_cmd $WIN_IP $WIN_USER $WIN_PASS 'powershell -ExecutionPolicy RemoteSigned set-timezone -id UTC'

# Create vswitch br100 and add data IP
echo "Creating vswitch br100 on $HV1_NAME"
run_wsman_cmd $HV1_IP $WIN_USER $WIN_PASS 'powershell -ExecutionPolicy RemoteSigned New-VMSwitch -Name br100 -AllowManagementOS $true -NetAdapterName \"Ethernet1\"'
echo "Adding IP address 10.10.1.2 to br100 vswitch"
run_wsman_cmd $HV1_IP $WIN_USER $WIN_PASS 'powershell -ExecutionPolicy RemoteSigned New-NetIPAddress -InterfaceAlias \"vEthernet (br100)\" -IPAddress \"10.10.1.2\" -PrefixLength 24'

sleep 20

HV1_DATA_IP=$(run_wsman_cmd $HV1_IP $WIN_USER $WIN_PASS 'powershell -ExecutionPolicy RemoteSigned (Get-NetIPAddress -InterfaceAlias \"vEthernet (br100)\" -AddressFamily IPv4).IPAddress')
export HV1_DATA_IP=$HV1_DATA_IP

echo "Data IP address for $HV1_NAME is $HV1_DATA_IP"

nohup $basedir/build_devstack.sh >> /home/jenkins-slave/logs/build-devstack-log-$ZUUL_UUID-$JOB_TYPE.log 2>&1 &
pid_devstack=$!

nohup $basedir/build_hyperv.sh $hyperv01 $JOB_TYPE > /home/jenkins-slave/logs/hyperv-$hyperv01-build-log-$ZUUL_UUID-$JOB_TYPE.log 2>&1 &
pid_hv01=$!

nohup $basedir/build_windows.sh $ws2012r2 $JOB_TYPE "$hyperv01" > /home/jenkins-slave/logs/ws2012-build-log-$ZUUL_UUID-$JOB_TYPE.log 2>&1 &
pid_ws2012=$!

TIME_COUNT=0
PROC_COUNT=3

echo `timestamp` "Start waiting for parallel init jobs."

finished_devstack=0;
finished_hv01=0;
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
        echo "All build logs can be found in http://cloudbase-ci.com/debug/$OSTACK_PROJECT/$ZUUL_CHANGE/$ZUUL_PATCHSET/"
    else
        echo "All build logs can be found in http://cloudbase-ci.com/$OSTACK_PROJECT/$ZUUL_CHANGE/$ZUUL_PATCHSET/"
fi

if [[ $PROC_COUNT -gt 0 ]]; then
    kill -9 $pid_devstack > /dev/null 2>&1
    kill -9 $pid_hv01 > /dev/null 2>&1
    kill -9 $pid_ws2012 > /dev/null 2>&1
    echo "Not all build threads finished in time, initialization process failed."
    exit 1
fi

echo "Post init on cinder node: $ws2012r2"
post_build_restart_cinder_windows_services $ws2012r2 $WIN_USER $WIN_PASS
echo "Post init on compute01 node: $hyperv01"
post_build_restart_hyperv_services $hyperv01 $WIN_USER $WIN_PASS

echo "Test that we have one cinder volume active"
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY 'source /home/ubuntu/devstack/openrc admin admin; CINDER_COUNT=$(openstack volume service list | grep cinder-volume | grep -c -w up); if [ "$CINDER_COUNT" == 1 ];then openstack volume service list ; else openstack volume service list; exit 1;fi' 20

run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY 'mkdir /opt/stack/logs/screen || echo /opt/stack/logs/screen already present' 1

if [[ "$ZUUL_BRANCH" == "master" ]] || [[ "$ZUUL_BRANCH" == "stable/ocata" ]] || [[ "$ZUUL_BRANCH" == "stable/pike" ]]; then
    run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "nova-manage cell_v2 discover_hosts --verbose"
fi

# Run post_stack
echo "Run post_stack scripts on devstack"
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "source /home/ubuntu/devstack/openrc admin admin && /home/ubuntu/bin/post_stack.sh" 6
if [ $? -ne 0 ]
then
    echo "Failed post_stack!"
    exit 1
else
    DEVSTACK_VM_STATUS="OK"
    echo "Initialize part finished"
fi
