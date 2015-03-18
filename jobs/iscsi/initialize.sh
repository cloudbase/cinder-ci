 source /usr/local/src/cinder-ci/jobs/utils.sh

join_cinder(){
    set +e
    WIN_USER=$1
    WIN_PASS=$2
    URL=$3

    PARAMS="$URL $WIN_USER $WIN_PASS"
    set -e
    run_ps_cmd_with_retry $PARAMS "\$env:Path += ';C:\Python27;C:\Python27\Scripts;C:\OpenSSL-Win32\bin;"\
"C:\Program Files (x86)\Git\cmd;C:\MinGW\mingw32\bin;C:\MinGW\msys\1.0\bin;C:\MinGW\bin;C:\qemu-img'; setx PATH \$env:Path "
    run_ps_cmd_with_retry $PARAMS "git clone https://github.com/cloudbase/cinder-ci C:\cinder-ci"
    run_ps_cmd_with_retry $PARAMS "cd C:\cinder-ci; git checkout cinder"
    run_ps_cmd_with_retry $PARAMS "bash C:\cinder-ci\windows\scripts\gerrit-git-prep.sh"\
" --zuul-site $ZUUL_SITE --gerrit-site $ZUUL_SITE --zuul-ref $ZUUL_REF --zuul-change $ZUUL_CHANGE --zuul-project cinder"
    run_ps_cmd_with_retry $PARAMS "C:\cinder-ci\windows\scripts\create-environment.ps1 -devstackIP $FIXED_IP -branchName $ZUUL_BRANCH -buildFor $ZUUL_PROJECT"
}

source $KEYSTONERC

UUID=$(python -c "import uuid; print uuid.uuid4().hex")
export NAME="cinder-devstack-$UUID"
echo NAME=$NAME > devstack_params_$ZUUL_CHANGE.txt

DEVSTACK_FLOATING_IP=$(nova floating-ip-create public | awk '{print $2}' | sed '/^$/d' | tail -n 1 ) || echo "Failed to allocate floating IP" 
if [ -z "$DEVSTACK_FLOATING_IP" ]
then
    exit 1
fi
echo DEVSTACK_FLOATING_IP=$DEVSTACK_FLOATING_IP >> devstack_params_$ZUUL_CHANGE.txt
echo DEVSTACK_SSH_KEY=$DEVSTACK_SSH_KEY >> devstack_params_$ZUUL_CHANGE.txt

NET_ID=$(nova net-list | grep 'private' | awk '{print $2}')
echo NET_ID=$NET_ID >> devstack_params_$ZUUL_CHANGE.txt

echo DEVSTACK_FLOATING_IP=$DEVSTACK_FLOATING_IP
echo NAME=$NAME 
echo NET_ID=$NET_ID 

echo "Deploying devstack $NAME" 
nova boot --availability-zone cinder --flavor m1.medium --image devstack --key-name default --security-groups devstack --nic net-id="$NET_ID" "$NAME" --poll 

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

echo FIXED_IP=$FIXED_IP >> devstack_params_$ZUUL_CHANGE.txt

export VMID=`nova show $NAME | grep -w id | awk '{print $4}'`

echo VM_ID=$VMID >> devstack_params_$ZUUL_CHANGE.txt
echo VM_ID=$VMID 

exec_with_retry "nova add-floating-ip $NAME $DEVSTACK_FLOATING_IP" 15 5

nova show "$NAME" 

echo "Wait for answer on port 22 on devstack"
wait_for_listening_port $DEVSTACK_FLOATING_IP 22 5 || { nova console-log "$NAME" ; exit 1; }
sleep 5

#set timezone to UTC
echo "Set local time to UTC on devstack"
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "sudo ln -fs /usr/share/zoneinfo/UTC /etc/localtime" 1

echo "Copy scripts to devstack VM"
scp -v -r -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" -i $DEVSTACK_SSH_KEY /usr/local/src/cinder-ci/devstack_vm/* ubuntu@$DEVSTACK_FLOATING_IP:/home/ubuntu/ 

echo "Update git repos to latest"
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "/home/ubuntu/bin/update_devstack_repos.sh --branch $ZUUL_BRANCH --build-for $ZUUL_PROJECT" 1

echo "Ensure configs are copied over"
scp -v -r -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" -i $DEVSTACK_SSH_KEY /usr/local/src/cinder-ci/devstack_vm/devstack/* ubuntu@$DEVSTACK_FLOATING_IP:/home/ubuntu/devstack 

ZUUL_SITE=`echo "$ZUUL_URL" |sed 's/.\{2\}$//'`
echo ZUUL_SITE=$ZUUL_SITE >> devstack_params_$ZUUL_CHANGE.txt

echo "Run gerrit-git-prep on devstack"
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY  "/home/ubuntu/bin/gerrit-git-prep.sh --zuul-site $ZUUL_SITE --gerrit-site $ZUUL_SITE --zuul-ref $ZUUL_REF --zuul-change $ZUUL_CHANGE --zuul-project $ZUUL_PROJECT" 1

# run devstack
echo "Run stack.sh on devstack"
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY 'source /home/ubuntu/keystonerc; /home/ubuntu/bin/run_devstack.sh' 5  

# run post_stack
echo "Run post_stack scripts on devstack"
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "source /home/ubuntu/keystonerc && /home/ubuntu/bin/post_stack.sh" 5

export CINDER_VM_NAME="cinder-windows-$UUID"
echo CINDER_VM_NAME=$CINDER_VM_NAME >> devstack_params_$ZUUL_CHANGE.txt

echo "Deploying cinder windows VM $CINDER_VM_NAME"
nova boot --availability-zone cinder --flavor m1.cinder --image cinder --key-name default --security-groups default --nic net-id="$NET_ID" "$CINDER_VM_NAME" --poll 

if [ $? -ne 0 ]
then
    echo "Failed to create cinder VM: $CINDER_VM_NAME" 
    nova show "$CINDER_VM_NAME" 
    exit 1
fi

#work around restart issue
echo "Fetching cinder VM status " 
export CINDER_STATUS=$(nova show $CINDER_VM_NAME | grep "status" | awk '{print $4}')
COUNT=0
while [ $CINDER_STATUS != "SHUTOFF" ]
do
    if [ $COUNT -ge 50 ]
    then
        echo "Failed to get $CINDER_VM_NAME status" 
        nova show "$CINDER_VM_NAME" 
        exit 1
    fi
    sleep 20
    export CINDER_STATUS=$(nova show $CINDER_VM_NAME | grep "status" | awk '{print $4}')
    COUNT=$(($COUNT + 1))
done
echo "Starting $CINDER_VM_NAME" 
nova start $CINDER_VM_NAME 


echo "Fetching cinder VM fixed IP address" 
export CINDER_FIXED_IP=$(nova show "$CINDER_VM_NAME" | grep "private network" | awk '{print $5}')
echo $CINDER_FIXED_IP 
COUNT=0
while [ -z "$CINDER_FIXED_IP" ]
do
    if [ $COUNT -ge 20 ]
    then
        echo "Failed to get fixed IP" 
        echo "nova show output:" 
        nova show "$CINDER_FIXED_IP" 
        echo "nova console-log output:" 
        nova console-log "$CINDER_FIXED_IP" 
        echo "neutron port-list output:" 
        neutron port-list -D -c device_id -c fixed_ips | grep $VM_ID 
        exit 1
    fi
    sleep 15
    export FIXED_IP=$(nova show "$CINDER_VM_NAME" | grep "private network" | awk '{print $5}') 
    COUNT=$(($COUNT + 1))
done

CINDER_FLOATING_IP=$(nova floating-ip-create public | awk '{print $2}' | sed '/^$/d' | tail -n 1 ) || echo "Failed to allocate floating IP" 
if [ -z "$CINDER_FLOATING_IP" ]
then
    exit 1
fi
echo CINDER_FLOATING_IP=$CINDER_FLOATING_IP >> devstack_params_$ZUUL_CHANGE.txt

echo "Fetching windows VM password"
WINDOWS_PASSWORD=$(nova get-password $CINDER_VM_NAME $DEVSTACK_SSH_KEY) 
echo $WINDOWS_PASSWORD
COUNT=0
while [ -z "$WINDOWS_PASSWORD" ]
do
    if [ $COUNT -ge 30 ]
    then
        echo "Failed to get password" 
        exit 1
    fi
    sleep 20
    WINDOWS_PASSWORD=$(nova get-password $CINDER_VM_NAME $DEVSTACK_SSH_KEY)
    COUNT=$(($COUNT + 1))
done

nova add-floating-ip $CINDER_VM_NAME $CINDER_FLOATING_IP

echo WINDOWS_USER=$WINDOWS_USER >> devstack_params_$ZUUL_CHANGE.txt
echo WINDOWS_PASSWORD=$WINDOWS_PASSWORD >> devstack_params_$ZUUL_CHANGE.txt
echo CINDER_FIXED_IP=$CINDER_FIXED_IP >> devstack_params_$ZUUL_CHANGE.txt

echo "Waiting for answer on winrm port for windows VM"
wait_for_listening_port $CINDER_FLOATING_IP 5986 10 || { nova console-log "$CINDER_VM_NAME" ; exit 1; }
sleep 5

#join cinder host
echo "Start cinder on windows and register with devstack"
join_cinder $WINDOWS_USER $WINDOWS_PASSWORD $CINDER_FLOATING_IP

# check cinder-volume status
echo "Test that we have one cinder volume active"
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY 'source /home/ubuntu/keystonerc; CINDER_COUNT=$(cinder service-list | grep cinder-volume | grep -c -w up); if [ "$CINDER_COUNT" == 1 ];then cinder service-list; else cinder service-list; exit 1;fi' 20
