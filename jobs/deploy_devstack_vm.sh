#!/bin/bash
run_devstack (){
    # run devstack
    echo "Run stack.sh on devstack"
    run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "source /home/ubuntu/keystonerc; /home/ubuntu/bin/run_devstack.sh $JOB_TYPE" 5 

    # run post_stack
    echo "Run post_stack scripts on devstack"
    run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "source /home/ubuntu/keystonerc && /home/ubuntu/bin/post_stack.sh" 5
}

update_local_conf (){
    local EXTRA_OPTS_PATH=$1
    scp -v -r -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" \
        -i $DEVSTACK_SSH_KEY $EXTRA_OPTS_PATH \
        ubuntu@$DEVSTACK_FLOATING_IP:/home/ubuntu/devstack
    run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY \
        "cat /home/ubuntu/devstack/local-conf-extra >> /home/ubuntu/devstack/local.conf" 1
}
set -e
#UUID=$(python -c "import uuid; print uuid.uuid4().hex")
export NAME="cinder-devstack-$ZUUL_UUID-$JOB_TYPE"
echo NAME=$NAME > /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt

echo DEVSTACK_SSH_KEY=$DEVSTACK_SSH_KEY >> /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt

NET_ID=$(nova net-list | grep 'private' | awk '{print $2}')
echo NET_ID=$NET_ID >> /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt

echo DEVSTACK_FLOATING_IP=$DEVSTACK_FLOATING_IP
echo NAME=$NAME
echo NET_ID=$NET_ID

echo "Deploying devstack $NAME"
nova boot --availability-zone cinder --flavor cinder.linux --image devstack --key-name default --security-groups devstack --nic net-id="$NET_ID" "$NAME" --poll

if [ $? -ne 0 ]
then
    echo "Failed to create devstack VM: $NAME"
    nova show "$NAME"
    exit 1
fi

echo "Fetching devstack VM fixed IP address"
export FIXED_IP=$(nova show "$NAME" | grep "private network" | awk '{print $5}')

COUNT=0
while [ -z "$FIXED_IP" ]
do
    if [ $COUNT -ge 10 ]
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
    COUNT=$(($COUNT + 1))
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
wait_for_listening_port $DEVSTACK_FLOATING_IP 22 5 || { nova console-log "$NAME" ; exit 1; }
sleep 5

# Add 2 more interfaces after successful SSH
echo "Adding two more network interfaces to devstack VM"
nova interface-attach --net-id "$NET_ID" "$NAME"
nova interface-attach --net-id "$NET_ID" "$NAME"

echo "Copy scripts to devstack VM"
scp -v -r -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" -i $DEVSTACK_SSH_KEY /usr/local/src/cinder-ci/devstack_vm/* ubuntu@$DEVSTACK_FLOATING_IP:/home/ubuntu/

#echo "Add known to be working repos"
#run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "sudo cp /home/ubuntu/cbs_sources.list /etc/apt/sources.list.d/" 1

echo "clean any apt files:"
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "sudo rm -rf /var/lib/apt/lists/*" 1
echo "apt-get update:"
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "sudo apt-get update -y" 1
echo "apt-get upgrade:"
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY 'sudo DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical apt-get -q -y -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" upgrade' 1

echo "apt-get cleanup:"
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "sudo apt-get autoremove -y" 1

#set timezone to UTC
echo "Set local time to UTC on devstack"
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "sudo ln -fs /usr/share/zoneinfo/UTC /etc/localtime" 1

echo "Ensure cifs-utils is present"
set +e
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "sudo apt-get install cifs-utils -y -o Debug::pkgProblemResolver=true -o Debug::Acquire::http=true -f" 3
if [ $? -ne 0 ]; then
    run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "sudo wget http://dl.openstack.tld/cifs-utils_6.0-1ubuntu2_amd64.deb -O /tmp/cifs-utils_6.0-1ubuntu2_amd64.deb"
    run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "sudo dpkg --install /tmp/cifs-utils_6.0-1ubuntu2_amd64.deb"
    exit_code=$?
fi
set -e
if [ $exit_code -ne 0 ]; then
    exit 1
fi

echo "Update git repos to latest"
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "/home/ubuntu/bin/update_devstack_repos.sh --branch $ZUUL_BRANCH --build-for $ZUUL_PROJECT" 1

echo "Ensure configs are copied over"
scp -v -r -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" -i $DEVSTACK_SSH_KEY /usr/local/src/cinder-ci/devstack_vm/devstack/* ubuntu@$DEVSTACK_FLOATING_IP:/home/ubuntu/devstack

ZUUL_SITE=`echo "$ZUUL_URL" |sed 's/.\{2\}$//'`
echo ZUUL_SITE=$ZUUL_SITE >> /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt

run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "mkdir -p -m 777 /openstack/volumes"

#get locally the vhdx files used by tempest
echo "Downloading the images for devstack"
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "mkdir -p /home/ubuntu/devstack/files/images/"
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "wget http://dl.openstack.tld/cirros-0.3.3-x86_64.img -O /home/ubuntu/devstack/files/images/cirros-0.3.3-x86_64.img"
# run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "wget http://dl.openstack.tld/Fedora-x86_64-20-20140618-sda.vhdx -O /home/ubuntu/devstack/files/images/Fedora-x86_64-20-20140618-sda.vhdx"

echo "Run gerrit-git-prep on devstack"
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY  "/home/ubuntu/bin/gerrit-git-prep.sh --zuul-site $ZUUL_SITE --gerrit-site $ZUUL_SITE --zuul-ref $ZUUL_REF --zuul-change $ZUUL_CHANGE --zuul-project $ZUUL_PROJECT" 1
