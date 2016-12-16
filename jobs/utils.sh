#!/bin/bash
exec_with_retry2 () {
    MAX_RETRIES=$1
    INTERVAL=$2

    COUNTER=0
    while [ $COUNTER -lt $MAX_RETRIES ]; do
        EXIT=0
        echo `date -u +%H:%M:%S`
        # echo "Running: ${@:3}"
        eval '${@:3}' || EXIT=$?
        if [ $EXIT -eq 0 ]; then
            return 0
        fi
    let COUNTER=COUNTER+1

        if [ -n "$INTERVAL" ]; then
            sleep $INTERVAL
        fi
    done
    return $EXIT
}

exec_with_retry () {
    CMD=${@:3}
    MAX_RETRIES=$1
    INTERVAL=$2

    exec_with_retry2 $MAX_RETRIES $INTERVAL $CMD
}

function run_wsman_cmd() {
    local host=$1
    local win_user=$2
    local win_password=$3
    local cmd=$4

    python /home/jenkins-slave/tools/wsman.py -u $win_user -p $win_password -U https://$host:5986/wsman $cmd
}

run_wsmancmd_with_retry () {
    MAX_RETRIES=$1
    HOST=$2
    USERNAME=$3
    PASSWORD=$4
    CMD=${@:5}

    exec_with_retry $MAX_RETRIES 10 "python /home/jenkins-slave/tools/wsman.py -U https://$HOST:5986/wsman -u $USERNAME -p $PASSWORD $CMD"
}

wait_for_listening_port () {
    HOST=$1
    PORT=$2
    TIMEOUT=$3
    exec_with_retry 30 10 "nc -z -w$TIMEOUT $HOST $PORT"
}

run_ssh_cmd () {
    SSHUSER_HOST=$1
    SSHKEY=$2
    CMD=$3
    ssh -t -o 'PasswordAuthentication no' -o 'StrictHostKeyChecking no' -o 'UserKnownHostsFile /dev/null' -i $SSHKEY $SSHUSER_HOST "$CMD" 
}

run_ssh_cmd_with_retry () {
    SSHUSER_HOST=$1
    SSHKEY=$2
    CMD=$3
    INTERVAL=$4
    MAX_RETRIES=20

    COUNTER=0
    while [ $COUNTER -lt $MAX_RETRIES ]; do
        EXIT=0
        run_ssh_cmd $SSHUSER_HOST $SSHKEY "$CMD" || EXIT=$?
        if [ $EXIT -eq 0 ]; then
            return 0
        fi
        let COUNTER=COUNTER+1

        if [ -n "$INTERVAL" ]; then
            sleep $INTERVAL
        fi
    done
    return $EXIT
}

run_ps_cmd_with_retry () {
    MAX_RETRIES=$1
    HOST=$2
    USERNAME=$3
    PASSWORD=$4
    CMD=${@:5}
    PS_EXEC_POLICY='-ExecutionPolicy RemoteSigned'

    run_wsmancmd_with_retry $MAX_RETRIES $HOST $USERNAME $PASSWORD "powershell $PS_EXEC_POLICY $CMD"
}

function join_hyperv (){
    run_wsmancmd_with_retry 3 $1 $2 $3 'powershell -ExecutionPolicy RemoteSigned Remove-Item -Recurse -Force C:\OpenStack\cinder-ci ; git clone https://github.com/herciunichita/cinder-ci C:\OpenStack\cinder-ci ; cd C:\OpenStack\cinder-ci ; git checkout newci >>\\'$FIXED_IP'\openstack\logs\create-environment-'$1'.log 2>&1'
    run_wsmancmd_with_retry 3 $1 $2 $3 'powershell -ExecutionPolicy RemoteSigned C:\OpenStack\cinder-ci\HyperV\scripts\teardown.ps1'
    run_wsmancmd_with_retry 3 $1 $2 $3 'powershell -ExecutionPolicy RemoteSigned C:\OpenStack\cinder-ci\HyperV\scripts\EnsureOpenStackServices.ps1 Administrator H@rd24G3t >>\\'$FIXED_IP'\openstack\logs\create-environment-'$1'.log 2>&1'
    [ "$IS_DEBUG_JOB" == "yes" ] && run_wsmancmd_with_retry 3 $1 $2 $3 '"powershell Write-Host Calling create-environment with devstackIP='$FIXED_IP' branchName=master buildFor=openstack/neutron '$IS_DEBUG_JOB' >>\\'$FIXED_IP'\openstack\logs\create-environment-'$1'.log 2>&1"'
    run_wsmancmd_with_retry 3 $1 $2 $3 '"powershell -ExecutionPolicy RemoteSigned C:\OpenStack\cinder-ci\HyperV\scripts\create-environment.ps1 -devstackIP '$FIXED_IP' -branchName master -buildFor openstack/neutron '$IS_DEBUG_JOB' >>\\'$FIXED_IP'\openstack\logs\create-environment-'$1'.log 2>&1"'
}

join_windows(){
    WIN_IP=$1
    WIN_USER=$2
    WIN_PASS=$3

    PARAMS="$WIN_IP $WIN_USER $WIN_PASS"
    # set -e
    #echo "Set paths for windows"
    #run_ps_cmd_with_retry 3 $PARAMS "\$env:Path += ';C:\Python27;C:\Python27\Scripts;C:\OpenSSL-Win32\bin;C:\Program Files (x86)\Git\cmd;C:\MinGW\mingw32\bin;C:\MinGW\msys\1.0\bin;C:\MinGW\bin;C:\qemu-img'; setx PATH \$env:Path "
    echo "Joining cinder windows node: $WIN_IP"
    echo "Ensure c:\cinder-ci folder exists and is empty."
    run_ps_cmd_with_retry 3 $PARAMS "if (Test-Path -Path C:\cinder-ci) {Remove-Item -Force -Recurse C:\cinder-ci\*} else {New-Item -Path C:\ -Name cinder-ci -Type directory}"
    echo "git clone cinder-ci"
    run_wsmancmd_with_retry 3 $PARAMS "git clone https://github.com/herciunichita/cinder-ci C:\cinder-ci"
    echo "cinder-ci: checkout newci and pull latest"
    run_ps_cmd_with_retry 3 $PARAMS "cd C:\cinder-ci; git checkout newci; git pull"
    echo "Adding zuuls to hosts"
    run_ps_cmd_with_retry 3 $PARAMS 'Add-Content C:\Windows\System32\drivers\etc\hosts \"`n10.21.7.213  zuul-cinder.openstack.tld\"'
    run_ps_cmd_with_retry 3 $PARAMS 'Add-Content C:\Windows\System32\drivers\etc\hosts \"`n10.9.1.27  zuul-ssd-0.openstack.tld\"'
    run_ps_cmd_with_retry 3 $PARAMS 'Add-Content C:\Windows\System32\drivers\etc\hosts \"`n10.9.1.29  zuul-ssd-1.openstack.tld\"'
    echo "Run gerrit-git-prep with zuul-site=$ZUUL_SITE zuul-ref=$ZUUL_REF zuul-change=$ZUUL_CHANGE zuul-project=$ZUUL_PROJECT"
    run_wsmancmd_with_retry 3 $PARAMS "bash C:\cinder-ci\windows\scripts\gerrit-git-prep.sh --zuul-site $ZUUL_SITE --gerrit-site $ZUUL_SITE --zuul-ref $ZUUL_REF --zuul-change $ZUUL_CHANGE --zuul-project $ZUUL_PROJECT"
    echo "Ensure service is configured with winuser=$WIN_USER and winpass=$WIN_PASS"
    run_ps_cmd_with_retry 3 $PARAMS "C:\cinder-ci\windows\scripts\EnsureOpenStackServices.ps1 $WIN_USER $WIN_PASS"
    echo "create cinder env on windows"
    run_ps_cmd_with_retry 3 $PARAMS "C:\cinder-ci\windows\scripts\create-environment.ps1 -devstackIP $FIXED_IP -branchName $ZUUL_BRANCH -buildFor $ZUUL_PROJECT -testCase $JOB_TYPE -winUser $WIN_USER -winPasswd $WIN_PASS"
}

function get_hyperv_logs() {
    
    echo "Prepare target folder on devstack VM"
    set +e
    ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $DEVSTACK_SSH_KEY ubuntu@$DEVSTACK_FLOATING_IP "sudo mkdir -p /openstack/logs/windows"
    ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $DEVSTACK_SSH_KEY ubuntu@$DEVSTACK_FLOATING_IP "sudo chown -R nobody:nogroup /openstack/logs/windows"
    ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $DEVSTACK_SSH_KEY ubuntu@$DEVSTACK_FLOATING_IP "sudo chmod -R 777 /openstack/logs/windows"
    set -f

    echo "WinRM connection details:"
    echo "Windows VM floating IP: $CINDER_FLOATING_IP"
    echo "Windows user: $WINDOWS_USER"
    echo "Windows password: $WINDOWS_PASSWORD"
    echo "Devstack floating IP: $DEVSTACK_FLOATING_IP"

    if exec_with_retry 3 30 "nc -z $CINDER_FLOATING_IP 5986"
    then
        echo "Export eventlog entries to files"
        run_wsmancmd_with_retry 3 $CINDER_FLOATING_IP $WINDOWS_USER $WINDOWS_PASSWORD 'powershell -executionpolicy remotesigned C:\cinder-ci\windows\scripts\export-eventlog.ps1'
        echo "Copy eventlog files"
        run_wsmancmd_with_retry 3 $CINDER_FLOATING_IP $WINDOWS_USER $WINDOWS_PASSWORD 'powershell -executionpolicy remotesigned cp -Recurse -Container  C:\OpenStack\Log\Eventlog\* \\'$DEVSTACK_FLOATING_IP'\openstack\logs\windows\'
    
        echo "Copy systeminfo"
        run_wsmancmd_with_retry 3 $CINDER_FLOATING_IP $WINDOWS_USER $WINDOWS_PASSWORD 'systeminfo >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\windows\systeminfo.log'
        echo "Copy windows updates status"
        run_wsmancmd_with_retry 3 $CINDER_FLOATING_IP $WINDOWS_USER $WINDOWS_PASSWORD 'wmic qfe list >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\windows\windows_hotfixes.log'
        echo "Copy pip freeze list"
        run_wsmancmd_with_retry 3 $CINDER_FLOATING_IP $WINDOWS_USER $WINDOWS_PASSWORD 'pip freeze >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\windows\pip_freeze.log'
        echo "Copy network configuration info"
        run_wsmancmd_with_retry 3 $CINDER_FLOATING_IP $WINDOWS_USER $WINDOWS_PASSWORD 'ipconfig /all >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\windows\ipconfig.log'
    
        echo "Copy network addapter information"
        run_wsmancmd_with_retry 3 $CINDER_FLOATING_IP $WINDOWS_USER $WINDOWS_PASSWORD 'powershell -executionpolicy remotesigned get-netadapter ^| Select-object * >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\windows\get_netadapter.log'
        echo "Copy disk partition info"
        run_wsmancmd_with_retry 3 $CINDER_FLOATING_IP $WINDOWS_USER $WINDOWS_PASSWORD 'powershell -executionpolicy remotesigned get-WmiObject win32_logicaldisk ^| Select-object * >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\windows\disk_free.log'
        echo "Copy firewall status"
        run_wsmancmd_with_retry 3 $CINDER_FLOATING_IP $WINDOWS_USER $WINDOWS_PASSWORD 'powershell -executionpolicy remotesigned get-netfirewallprofile ^| Select-Object * >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\windows\firewall.log'
        echo "Copy list of running processes"
        run_wsmancmd_with_retry 3 $CINDER_FLOATING_IP $WINDOWS_USER $WINDOWS_PASSWORD 'powershell -executionpolicy remotesigned get-process ^| Select-Object * >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\windows\get_process.log'
        echo "Copy list of windows services"
        run_wsmancmd_with_retry 3 $CINDER_FLOATING_IP $WINDOWS_USER $WINDOWS_PASSWORD 'powershell -executionpolicy remotesigned get-service ^| Select-Object * >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\windows\get_service.log'
        echo "Copy cinder volume service details"
        run_wsmancmd_with_retry 3 $CINDER_FLOATING_IP $WINDOWS_USER $WINDOWS_PASSWORD 'sc qc cinder-volume >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\windows\cinder-volume.log'
    else 
        echo "Windows VM unreachable!"
    fi    
}

post_build_restart_cinder_windows_services (){
    run_wsmancmd_with_retry 18 $1 $2 $3 '"powershell -ExecutionPolicy RemoteSigned C:\cinder-ci\windows\scripts\post-build-restart-services.ps1 2>&1"'
}

