#!/bin/bash
join_cinder(){
    set +e
    WIN_USER=$1
    WIN_PASS=$2
    WIN_IP=$3

    PARAMS="$WIN_IP $WIN_USER $WIN_PASS"
    # set -e
    echo "Set paths for windows"
    run_ps_cmd_with_retry $PARAMS "\$env:Path += ';C:\qemu2\qemu-img;C:\Python27;C:\Python27\Scripts;C:\OpenSSL-Win32\bin;C:\Program Files (x86)\Git\cmd;C:\MinGW\mingw32\bin;C:\MinGW\msys\1.0\bin;C:\MinGW\bin;C:\qemu-img'; setx PATH \$env:Path "
    echo "Ensure c:\cinder-ci folder exists and is empty."
    run_ps_cmd_with_retry $PARAMS "if (Test-Path -Path C:\cinder-ci) {Remove-Item -Force -Recurse C:\cinder-ci\*} else {New-Item -Path C:\ -Name cinder-ci -Type directory}"
    echo "git clone cinder-ci"
    run_wsmancmd_with_retry $PARAMS "git clone https://github.com/cloudbase/cinder-ci C:\cinder-ci"
    echo "cinder-ci: checkout master and pull latest"
    run_ps_cmd_with_retry $PARAMS "cd C:\cinder-ci; git checkout master; git pull"
    echo "Run gerrit-git-prep"
    run_wsmancmd_with_retry $PARAMS "bash C:\cinder-ci\windows\scripts\gerrit-git-prep.sh --zuul-site $ZUUL_SITE --gerrit-site $ZUUL_SITE --zuul-ref $ZUUL_REF --zuul-change $ZUUL_CHANGE --zuul-project $ZUUL_PROJECT"
    echo "Ensure service is configured"
    run_ps_cmd_with_retry $PARAMS "C:\cinder-ci\windows\scripts\EnsureOpenStackServices.ps1 $WINDOWS_USER $WINDOWS_PASSWORD"
    echo "create cinder env on windows"
    run_ps_cmd_with_retry $PARAMS "C:\cinder-ci\windows\scripts\create-environment.ps1 -devstackIP $FIXED_IP -branchName $ZUUL_BRANCH -buildFor $ZUUL_PROJECT -testCase $JOB_TYPE"
}

export CINDER_VM_NAME="cinder-windows-$UUID"
echo CINDER_VM_NAME=$CINDER_VM_NAME >> /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt

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
echo CINDER_FLOATING_IP=$CINDER_FLOATING_IP >> /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt

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

echo WINDOWS_USER=$WINDOWS_USER >> /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt
echo WINDOWS_PASSWORD=$WINDOWS_PASSWORD >> /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt
echo CINDER_FIXED_IP=$CINDER_FIXED_IP >> /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt
echo WINDOWS_USER=$WINDOWS_USER
echo WINDOWS_PASSWORD=$WINDOWS_PASSWORD

echo "Waiting for answer on winrm port for windows VM"
wait_for_listening_port $CINDER_FLOATING_IP 5986 10 || { nova console-log "$CINDER_VM_NAME" ; exit 1; }
sleep 5

#join cinder host
echo "Start cinder on windows and register with devstack"
join_cinder $WINDOWS_USER $WINDOWS_PASSWORD $CINDER_FLOATING_IP

# check cinder-volume status
echo "Test that we have one cinder volume active"
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY 'source /home/ubuntu/keystonerc; CINDER_COUNT=$(cinder service-list | grep cinder-volume | grep -c -w up); if [ "$CINDER_COUNT" == 1 ];then cinder service-list; else cinder service-list; exit 1;fi' 20
