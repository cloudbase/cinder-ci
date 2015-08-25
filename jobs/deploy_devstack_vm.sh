#!/bin/bash
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
    export NAME="cinder-devstack-$ZUUL_UUID-$JOB_TYPE"
    echo NAME=$NAME > /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt

    echo DEVSTACK_SSH_KEY=$DEVSTACK_SSH_KEY >> /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt

    NET_ID=$(nova net-list | grep 'private' | awk '{print $2}')
    echo NET_ID=$NET_ID >> /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt

    echo NAME=$NAME
    echo NET_ID=$NET_ID

    echo "Deploying devstack $NAME"
    nova boot --availability-zone cinder --flavor cinder.linux --image devstack-62v3 --key-name default --security-groups devstack --nic net-id="$NET_ID" "$NAME" --poll

    if [ $? -ne 0 ]
    then
        echo "Failed to create devstack VM: $NAME"
       nova show "$NAME"
       exit 1
    fi

    echo "Fetching devstack VM fixed IP address"
    export FIXED_IP=$(nova show "$NAME" | grep "private network" | awk '{print $5}')

    COUNTER=0
    while [ -z "$FIXED_IP" ]
    do
        if [ $COUNTER -ge 10 ]
        then
           echo "Failed to get fixed IP"
            echo "nova show output:"
            nova show "$NAME"
            echo "nova console-log output:"
            nova console-log "$NAME"
            echo "neutron port-list output:"
            neutron port-list -D -c device_id -c fixed_ips | grep $VM_ID
            exit 1
        fi
        sleep 15
        export FIXED_IP=$(nova show "$NAME" | grep "private network" | awk '{print $5}')
        COUNTER=$(($COUNTER + 1))
    done

    echo FIXED_IP=$FIXED_IP >> /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt

    DEVSTACK_FLOATING_IP=$(nova floating-ip-create public | awk '{print $2}' | sed '/^$/d' | tail -n 1 ) || echo "Failed to allocate floating IP"
    if [ -z "$DEVSTACK_FLOATING_IP" ]
    then
        exit 1
    fi
    echo DEVSTACK_FLOATING_IP=$DEVSTACK_FLOATING_IP >> /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt

    export VMID=`nova show $NAME | grep -w id | awk '{print $4}'`

    echo VM_ID=$VMID >> /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt
    echo VM_ID=$VMID

    exec_with_retry 15 5 "nova add-floating-ip $NAME $DEVSTACK_FLOATING_IP"

    nova show "$NAME"

    echo "Wait for answer on port 22 on devstack"
    exec_with_retry 25 30 "nc -z -w3 $DEVSTACK_FLOATING_IP 22"
    if [ $? -ne 0 ]
    then
        echo "Failed listening for ssh port on devstack."
        nova console-log "$NAME"
        exit 1
    fi

    # Add 2 more interfaces after successful SSH
    #echo "Adding two more network interfaces to devstack VM"
    #nova interface-attach --net-id "$NET_ID" "$NAME"
    #nova interface-attach --net-id "$NET_ID" "$NAME"

    echo "Copy scripts to devstack VM"
    scp -v -r -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" -i $DEVSTACK_SSH_KEY /usr/local/src/cinder-ci/devstack_vm/* ubuntu@$DEVSTACK_FLOATING_IP:/home/ubuntu/

    # Repository section
    echo "setup apt-cacher-ng:"
    run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY 'echo "Acquire::http { Proxy \"http://10.21.7.214:3142\" };" | sudo tee --append /etc/apt/apt.conf.d/90-apt-proxy.conf' 12
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
        run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "sudo wget http://dl.openstack.tld/cifs-utils_6.0-1ubuntu2_amd64.deb -O /tmp/cifs-utils_6.0-1ubuntu2_amd64.deb && sudo dpkg --install /tmp/cifs-utils_6.0-1ubuntu2_amd64.deb" 12
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
    run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "wget http://dl.openstack.tld/cirros-0.3.3-x86_64.img -O /home/ubuntu/devstack/files/images/cirros-0.3.3-x86_64.img" 6

    echo "Run gerrit-git-prep on devstack"
    run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY  "/home/ubuntu/bin/gerrit-git-prep.sh --zuul-site $ZUUL_SITE --gerrit-site $ZUUL_SITE --zuul-ref $ZUUL_REF --zuul-change $ZUUL_CHANGE --zuul-project $ZUUL_PROJECT" 6

    # Set up the smbfs shares list
    run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "sudo mkdir -p /etc/cinder && sudo chown ubuntu /etc/cinder" 6
    run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "sudo echo //$DEVSTACK_FLOATING_IP/openstack/volumes -o guest > /etc/cinder/smbfs_shares_config" 6

    # Update local conf
    update_local_conf

    # Run devstack
    echo "Run stack.sh on devstack"
    run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "source /home/ubuntu/keystonerc && /home/ubuntu/bin/run_devstack.sh $JOB_TYPE" 6
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
