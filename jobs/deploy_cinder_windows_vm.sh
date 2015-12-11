#!/bin/bash

source /usr/local/src/cinder-ci/jobs/utils.sh

join_cinder(){
    WIN_USER=$1
    WIN_PASS=$2
    WIN_IP=$3

    PARAMS="$WIN_IP $WIN_USER $WIN_PASS"
    # set -e
    echo "Set paths for windows"
    run_ps_cmd_with_retry $PARAMS "\$env:Path += ';C:\Python27;C:\Python27\Scripts;C:\OpenSSL-Win32\bin;C:\Program Files (x86)\Git\cmd;C:\MinGW\mingw32\bin;C:\MinGW\msys\1.0\bin;C:\MinGW\bin;C:\qemu-img'; setx PATH \$env:Path "
    echo "Ensure c:\cinder-ci folder exists and is empty."
    run_ps_cmd_with_retry $PARAMS "if (Test-Path -Path C:\cinder-ci) {Remove-Item -Force -Recurse C:\cinder-ci\*} else {New-Item -Path C:\ -Name cinder-ci -Type directory}"
    echo "git clone cinder-ci"
    run_wsmancmd_with_retry $PARAMS "git clone https://github.com/cloudbase/cinder-ci C:\cinder-ci"
    echo "cinder-ci: checkout master and pull latest"
    run_ps_cmd_with_retry $PARAMS "cd C:\cinder-ci; git checkout master; git pull"
    echo "Adding zuul to hosts"
    ZUUL_CINDER="10.21.7.213"
    run_ps_cmd_with_retry $PARAMS "Add-Content C:\Windows\System32\drivers\etc\hosts \"\`n${ZUUL_CINDER} zuul-cinder.openstack.tld\""
    echo "Run gerrit-git-prep"
    run_wsmancmd_with_retry $PARAMS "bash C:\cinder-ci\windows\scripts\gerrit-git-prep.sh --zuul-site $ZUUL_SITE --gerrit-site $ZUUL_SITE --zuul-ref $ZUUL_REF --zuul-change $ZUUL_CHANGE --zuul-project $ZUUL_PROJECT"
    echo "Ensure service is configured"
    run_ps_cmd_with_retry $PARAMS "C:\cinder-ci\windows\scripts\EnsureOpenStackServices.ps1 $WINDOWS_USER $WINDOWS_PASSWORD"
    echo "create cinder env on windows"
    run_ps_cmd_with_retry $PARAMS "C:\cinder-ci\windows\scripts\create-environment.ps1 -devstackIP $FIXED_IP -branchName $ZUUL_BRANCH -buildFor $ZUUL_PROJECT -testCase $JOB_TYPE -winUser $WINDOWS_USER -winPasswd $WINDOWS_PASSWORD"
}

CINDER_VM_NAME="cnd-win-$ZUUL_CHANGE-$ZUUL_PATCHSET"

case "$JOB_TYPE" in
        iscsi)
            CINDER_VM_NAME="$CINDER_VM_NAME-is"
            ;;

        smb3_windows)
            CINDER_VM_NAME="$CINDER_VM_NAME-sw"
            ;;

        smb3_linux)
            CINDER_VM_NAME="$CINDER_VM_NAME-sl"
            ;;
esac

if [[ ! -z $DEBUG_JOB ]] && [[ $DEBUG_JOB = "yes" ]]; then 
        CINDER_VM_NAME="$CINDER_VM_NAME-dbg"
fi

export CINDER_VM_NAME=$CINDER_VM_NAME

echo CINDER_VM_NAME=$CINDER_VM_NAME >> /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt

echo "Deploying cinder windows VM $CINDER_VM_NAME"

WINDOWS_VM_STATUS="NOT_OK"
BOOT_COUNT=0
NET_ID=$(nova net-list | grep 'private' | awk '{print $2}')

while [ $WINDOWS_VM_STATUS != "OK" ]
do
    set +e
    if (`nova list | grep "$CINDER_VM_NAME" > /dev/null 2>&1`); then nova delete "$CINDER_VM_NAME"; fi
    set -e
    sleep 20

    WIN_VMID=$(nova boot --availability-zone cinder --flavor cinder.windows --image cinder --key-name default --security-groups default --nic net-id="$NET_ID" "$CINDER_VM_NAME" --poll | awk '{if (NR == 21) {print $4}}')
    export WIN_VMID=$WIN_VMID
    echo WIN_VMID=$WIN_VMID >>  /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt
    echo WIN_VMID=$WIN_VMID

    if [ $? -ne 0 ]
    then
        echo "Failed to create cinder VM: $WIN_VMID"
        nova show "$WIN_VMID"
        break
    fi
    
    #work around restart issue
    echo "Fetching cinder VM status "
    export CINDER_STATUS=$(nova show $WIN_VMID | grep "status" | awk '{print $4}')
    COUNT=0
    while [ $CINDER_STATUS != "SHUTOFF" ]
    do
        if [ $COUNT -ge 60 ]
        then
            echo "Failed to get $WIN_VMID status"
            nova show "$WIN_VMID"
            break
        fi
        sleep 10
        export CINDER_STATUS=$(nova show $WIN_VMID | grep "status" | awk '{print $4}')
        COUNT=$(($COUNT + 1))
    done
    sleep 5
    echo "Printing details about $WIN_VMID "
    nova show "$WIN_VMID"
    if [ $CINDER_STATUS != "ACTIVE" ]
    then
        echo "Starting $WIN_VMID"
        nova start $WIN_VMID
        sleep 15
        nova show "$WIN_VMID"
        export CINDER_STATUS=$(nova show $WIN_VMID | grep "status" | awk '{print $4}')
        echo "Cinder VM Status is: $CINDER_STATUS"
    fi

    echo "Fetching cinder VM fixed IP address"
    export CINDER_FIXED_IP=$(nova show "$WIN_VMID" | grep "private network" | awk '{print $5}')
    echo $CINDER_FIXED_IP
    COUNT=0
    while [ -z "$CINDER_FIXED_IP" ]
    do
        if [ $COUNT -ge 12 ]
        then
            echo "Failed to get fixed IP"
            echo "nova show output:"
            nova show "$CINDER_FIXED_IP"
            echo "nova console-log output:"
            nova console-log "$CINDER_FIXED_IP"
            echo "neutron port-list output:"
            neutron port-list -D -c device_id -c fixed_ips | grep $WIN_VMID
            break
        fi
        sleep 10
        export CINDER_FIXED_IP=$(nova show "$WIN_VMID" | grep "private network" | awk '{print $5}')
        COUNT=$(($COUNT + 1))
    done

    echo "Fetching windows VM password"
    WINDOWS_PASSWORD=$(nova get-password $WIN_VMID $DEVSTACK_SSH_KEY)
    echo $WINDOWS_PASSWORD
    COUNT=0
    while [ -z "$WINDOWS_PASSWORD" ]
    do
        if [ $COUNT -ge 30 ]
        then
            echo "VM Status:"
            nova show $WIN_VMID
            echo "Console log:"
            nova console-log $WIN_VMID
            echo "VM Password:"
            echo "WINDOWS_PASSWORD=$WINDOWS_PASSWORD"
            echo "Failed to get password"
            break
        fi
        sleep 10
        date
        echo "Count: $COUNT"
        WINDOWS_PASSWORD=$(nova get-password $WIN_VMID $DEVSTACK_SSH_KEY)
        echo "WINDOWS_PASSWORD=$WINDOWS_PASSWORD"
        COUNT=$(($COUNT + 1))
    done
    date
    echo "Count: $COUNT"
    echo "Windows Password: $WINDOWS_PASSWORD"

    if [ -z "$WINDOWS_PASSWORD" ]
    then
        BOOT_COUNT=$(($BOOT_COUNT + 1))
        if [ $BOOT_COUNT -ge 10 ]
        then
            echo "Failed to get a working VM in $BOOT_COUNT tries."
            nova show $WIN_VMID
            echo "Console log:"
            nova console-log $WIN_VMID
            echo "Failed to get password"
            exit 1
        fi
        echo "Retrying booting a Windows VM"
    else
        WINDOWS_VM_STATUS="OK"
    fi
done

CINDER_FLOATING_IP=$(nova floating-ip-create public | awk '{print $2}' | sed '/^$/d' | tail -n 1 ) || echo "Failed to allocate floating IP"
if [ -z "$CINDER_FLOATING_IP" ]
then
    exit 1
fi
echo CINDER_FLOATING_IP=$CINDER_FLOATING_IP >> /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt

sleep 30

nova add-floating-ip $WIN_VMID $CINDER_FLOATING_IP

echo WINDOWS_USER=$WINDOWS_USER >> /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt
echo WINDOWS_PASSWORD=$WINDOWS_PASSWORD >> /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt
echo CINDER_FIXED_IP=$CINDER_FIXED_IP >> /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt
echo WINDOWS_USER=$WINDOWS_USER
echo WINDOWS_PASSWORD=$WINDOWS_PASSWORD

echo "Waiting for answer on winrm port for windows VM"
wait_for_listening_port $CINDER_FLOATING_IP 5986 20 || { nova console-log "$WIN_VMID" ; exit 1; }
sleep 5

ZUUL_SITE=`echo "$ZUUL_URL" |sed 's/.\{2\}$//'`

#source /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt

#join cinder host
echo "Start cinder on windows and register with devstack"
join_cinder $WINDOWS_USER $WINDOWS_PASSWORD $CINDER_FLOATING_IP

# check cinder-volume status
echo "Test that we have one cinder volume active"
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY 'source /home/ubuntu/keystonerc; CINDER_COUNT=$(cinder service-list | grep cinder-volume | grep -c -w up); if [ "$CINDER_COUNT" == 1 ];then cinder service-list; else cinder service-list; exit 1;fi' 20
