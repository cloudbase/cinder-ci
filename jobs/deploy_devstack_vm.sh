#!/bin/bash

source /usr/local/src/cinder-ci/jobs/utils.sh

# Functions section
update_local_conf (){
    if [ $JOB_TYPE = "smb3_linux" ]
    then 
        EXTRA_OPTS_PATH="/usr/local/src/cinder-ci/jobs/smb3_linux/local-conf-extra"
    elif [ $JOB_TYPE = "smb3_windows" ]
        then
            EXTRA_OPTS_PATH="/usr/local/src/cinder-ci/jobs/smb3_windows/local-conf-extra"
        elif [ $JOB_TYPE = "iscsi" ]
            then            
                EXTRA_OPTS_PATH="/usr/local/src/cinder-ci/jobs/iscsi/local-conf-extra"
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

if [[ ! -z $DEBUG_JOB ]] && [[ $DEBUG_JOB = "yes" ]]; then 
	NAME="$NAME-dbg"
fi
export NAME=$NAME

DEVSTACK_VM_STATUS="NOT_OK"
COUNT=0
while [ $DEVSTACK_VM_STATUS != "OK" ]
do
if [ $COUNT -le 3 ]
then
    COUNT=$(($COUNT + 1))
    set +e
    if (`nova list | grep "$NAME" > /dev/null 2>&1`); then nova delete "$NAME"; fi
    set -e
    echo NAME=$NAME > /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt
    echo ZUUL_BRANCH=$ZUUL_BRANCH >> /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt

    echo DEVSTACK_SSH_KEY=$DEVSTACK_SSH_KEY >> /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt

    NET_ID=$(nova net-list | grep 'private' | awk '{print $2}')
    echo NET_ID=$NET_ID >> /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt

    echo NAME=$NAME
    echo NET_ID=$NET_ID
    
    devstack_image="devstack-78v2"
    echo "Image used is: $devstack_image"
    
    echo "Deploying devstack $NAME"
    VMID=$(nova boot --availability-zone cinder --flavor cinder.linux --image $devstack_image --key-name default --security-groups devstack --nic net-id="$NET_ID" "$NAME" --poll | awk '{if (NR == 21) {print $4}}')
    export VMID=$VMID
    echo VMID=$VMID >>  /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt
    echo VMID=$VMID

    if [ $? -ne 0 ]
    then
        echo "Failed to create devstack VM: $VMID"
       nova show "$VMID"
       exit 1
    fi

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
    echo "nova console-log output:"
    nova console-log "$VMID"

    echo FIXED_IP=$FIXED_IP >> /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt

    DEVSTACK_FLOATING_IP=$(nova floating-ip-create public | awk '{print $2}' | sed '/^$/d' | tail -n 1 ) || echo "Failed to allocate floating IP"
    if [ -z "$DEVSTACK_FLOATING_IP" ]
    then
        exit 1
    fi
    echo DEVSTACK_FLOATING_IP=$DEVSTACK_FLOATING_IP >> /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt

    exec_with_retry 15 5 "nova add-floating-ip $VMID $DEVSTACK_FLOATING_IP"

    nova show "$VMID"

    echo "Wait for answer on port 22 on devstack"
    exec_with_retry 25 30 "nc -z -w3 $DEVSTACK_FLOATING_IP 22"
    if [ $? -ne 0 ]
    then
        echo "Failed listening for ssh port on devstack."
        nova console-log "$VMID"
        exit 1
    fi

    # Add 1 more interface after successful SSH
    nova interface-attach --net-id "$NET_ID" "$VMID"

    echo "Copy scripts to devstack VM"
    scp -v -r -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" -i $DEVSTACK_SSH_KEY /usr/local/src/cinder-ci/devstack_vm/* ubuntu@$DEVSTACK_FLOATING_IP:/home/ubuntu/
    
    # Repository section
    echo "setup apt-cacher-ng:"
    run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY 'echo "Acquire::http { Proxy \"http://10.0.110.1:3142\" };" | sudo tee --append /etc/apt/apt.conf.d/90-apt-proxy.conf' 12
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
        run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "sudo wget http://10.0.110.1/cifs-utils_6.0-1ubuntu2_amd64.deb -O /tmp/cifs-utils_6.0-1ubuntu2_amd64.deb && sudo dpkg --install /tmp/cifs-utils_6.0-1ubuntu2_amd64.deb" 12
        exit_code_cifs=$?
    fi
    set -e
    if [ $exit_code_cifs -ne 0 ]; then
        exit 1
    fi

    echo "Update git repos to latest"
    run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "/home/ubuntu/bin/update_devstack_repos.sh --branch $ZUUL_BRANCH --build-for $ZUUL_PROJECT" 6

    echo "Ensure configs are copied over"
    scp -v -r -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" -i $DEVSTACK_SSH_KEY /usr/local/src/cinder-ci/devstack_vm/devstack/* ubuntu@$DEVSTACK_FLOATING_IP:/home/ubuntu/devstack

    ZUUL_SITE=`echo "$ZUUL_URL" |sed 's/.\{2\}$//'`
    echo ZUUL_SITE=$ZUUL_SITE >> /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt

    run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "mkdir -p -m 777 /openstack/volumes" 6

    #get locally the vhdx files used by tempest
    echo "Downloading the images for devstack"
    run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "mkdir -p /home/ubuntu/devstack/files/images/" 6
    run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "wget http://10.0.110.1/cirros-0.3.3-x86_64.img -O /home/ubuntu/devstack/files/images/cirros-0.3.3-x86_64.img" 6

    # Set ZUUL IP in hosts file
    ZUUL_CINDER="10.21.7.213"
    if  ! grep -qi zuul /etc/hosts ; then
        run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "echo '$ZUUL_CINDER zuul-cinder.openstack.tld' | sudo tee -a /etc/hosts"
        run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "echo '10.9.1.27 zuul-ssd-0.openstack.tld' | sudo tee -a /etc/hosts"
        run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "echo '10.9.1.29 zuul-ssd-1.openstack.tld' | sudo tee -a /etc/hosts"
    fi

    echo "Reserve VLAN range for test"
    set +e
    VLAN_RANGE=`/usr/local/src/cinder-ci/vlan_allocation.py -a $VMID`
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

    # Update local conf
    update_local_conf
    
    # Add zuul branch to local.sh
    run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "sed -i '3 i\branch=$ZUUL_BRANCH' /home/ubuntu/devstack/local.sh"
    
    # Run devstack
    echo "Run stack.sh on devstack"
    run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "source /home/ubuntu/keystonerc && /home/ubuntu/bin/run_devstack.sh $JOB_TYPE $ZUUL_BRANCH" 6
    if [ $? -ne 0 ]
    then
        echo "Failed to install devstack on cinder vm!"
        exit 1
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
    fi
else
    echo "Counter for devstack deploy has been reached! Build has failed."
    exit 1
fi
done
