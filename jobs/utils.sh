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
    exec_with_retry 15 10 "nc -z -w$TIMEOUT $HOST $PORT"
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
    run_wsmancmd_with_retry 3 $1 $2 $3 'powershell if (-Not (test-path '$LOG_DIR')){mkdir '$LOG_DIR'}'
    run_wsmancmd_with_retry 3 $1 $2 $3 'powershell -ExecutionPolicy RemoteSigned Remove-Item -Recurse -Force C:\OpenStack\cinder-ci ; git clone https://github.com/rbuzatu90/cinder-ci C:\OpenStack\cinder-ci ; cd C:\OpenStack\cinder-ci ; git checkout cambridge-2016 >> '$LOG_DIR'\create-environment.log 2>&1'
    run_wsmancmd_with_retry 3 $1 $2 $3 'powershell -ExecutionPolicy RemoteSigned C:\OpenStack\cinder-ci\HyperV\scripts\teardown.ps1'
    run_wsmancmd_with_retry 3 $1 $2 $3 'powershell -ExecutionPolicy RemoteSigned C:\OpenStack\cinder-ci\HyperV\scripts\EnsureOpenStackServices.ps1 Administrator H@rd24G3t >> '$LOG_DIR'\create-environment.log 2>&1'
    [ "$IS_DEBUG_JOB" == "yes" ] && run_wsmancmd_with_retry 3 $1 $2 $3 '"powershell Write-Host Calling create-environment with devstackIP='$FIXED_IP' branchName=master buildFor=openstack/neutron '$IS_DEBUG_JOB' >> '$LOG_DIR'\create-environment.log 2>&1"'
    run_wsmancmd_with_retry 3 $1 $2 $3 '"powershell -ExecutionPolicy RemoteSigned C:\OpenStack\cinder-ci\HyperV\scripts\create-environment.ps1 -devstackIP '$FIXED_IP' -branchName master -buildFor openstack/neutron '$IS_DEBUG_JOB' >> '$LOG_DIR'\create-environment.log 2>&1"'
}

join_windows(){
    WIN_IP=$1
    WIN_USER=$2
    WIN_PASS=$3
    HYPERV_NODES=$4

    PARAMS="$WIN_IP $WIN_USER $WIN_PASS"
    # set -e
    echo "Set paths for windows"
    run_ps_cmd_with_retry 3 $PARAMS "\$env:Path += ';C:\qemu-img'; setx PATH \$env:Path "
    echo "Joining cinder windows node: $WIN_IP"
    run_wsmancmd_with_retry 3 $PARAMS 'powershell -ExecutionPolicy RemoteSigned if (-Not (test-path '$LOG_DIR')){mkdir '$LOG_DIR'}'
    run_wsmancmd_with_retry 3 $PARAMS 'powershell -ExecutionPolicy RemoteSigned Remove-Item -Recurse -Force C:\OpenStack\cinder-ci ; git clone https://github.com/rbuzatu90/cinder-ci C:\OpenStack\cinder-ci ; cd C:\OpenStack\cinder-ci ; git checkout cambridge-2016 >> '$LOG_DIR'\010-clone_ci_repo.log 2>&1'
    #echo "Teardown first"
    run_wsmancmd_with_retry 3 $PARAMS 'powershell -ExecutionPolicy RemoteSigned C:\openstack\cinder-ci\windows\scripts\teardown.ps1'
    echo "Disable firewall for cinder-volume"
    run_ps_cmd_with_retry 3 $PARAMS 'netsh.exe advfirewall set allprofiles state off'
    #run_ps_cmd_with_retry 3 $PARAMS '"C:\cinder-ci\windows\scripts\create-environment.ps1 -devstackIP '$FIXED_IP' -branchName '$ZUUL_BRANCH' -buildFor '$ZUUL_PROJECT' -testCase '$JOB_TYPE' -winUser '$WIN_USER' -winPasswd '$WIN_PASS' -hypervNodes '$HYPERV_NODES' >>\\'$FIXED_IP'\openstack\logs\create-environment-'$WIN_IP'.log 2>&1"'
    echo "calling initial_cleanup.ps1 -devstackIP $FIXED_IP -branchName $ZUUL_BRANCH -buildFor $ZUUL_PROJECT -testCase $JOB_TYPE -winUser $WIN_USER -winPasswd $WIN_PASS -hypervNodes $HYPERV_NODES redir to '$LOG_DIR'"
    run_ps_cmd_with_retry 3 $PARAMS '"C:\openstack\cinder-ci\windows\scripts\initial_cleanup.ps1 -devstackIP '$FIXED_IP' -branchName '$ZUUL_BRANCH' -buildFor '$ZUUL_PROJECT' -testCase '$JOB_TYPE' -winUser '$WIN_USER' -winPasswd '$WIN_PASS' -hypervNodes '$HYPERV_NODES''
    run_ps_cmd_with_retry 3 $PARAMS '"C:\openstack\cinder-ci\windows\scripts\ensure_ci_repo.ps1 -devstackIP '$FIXED_IP' -branchName '$ZUUL_BRANCH' -buildFor '$ZUUL_PROJECT' -testCase '$JOB_TYPE' -winUser '$WIN_USER' -winPasswd '$WIN_PASS' -hypervNodes '$HYPERV_NODES' >> '$LOG_DIR'\030-ensure_ci_repo.log 2>&1"'
    echo "Ensure service is configured with winuser=$WIN_USER and winpass=$WIN_PASS"
    run_ps_cmd_with_retry 3 $PARAMS '"C:\openstack\cinder-ci\windows\scripts\EnsureOpenStackServices.ps1 '$WIN_USER' '$WIN_PASS' >> '$LOG_DIR'\020-ensure_openstack_services.log 2>&1"'
    run_ps_cmd_with_retry 3 $PARAMS '"C:\openstack\cinder-ci\windows\scripts\ensure_python.ps1 -devstackIP '$FIXED_IP' -branchName '$ZUUL_BRANCH' -buildFor '$ZUUL_PROJECT' -testCase '$JOB_TYPE' -winUser '$WIN_USER' -winPasswd '$WIN_PASS' -hypervNodes '$HYPERV_NODES' >> '$LOG_DIR'\040-ensure_pytong.log 2>&1"'
    run_ps_cmd_with_retry 3 $PARAMS '"C:\openstack\cinder-ci\windows\scripts\ensure_pip_pkgs.ps1 -devstackIP '$FIXED_IP' -branchName '$ZUUL_BRANCH' -buildFor '$ZUUL_PROJECT' -testCase '$JOB_TYPE' -winUser '$WIN_USER' -winPasswd '$WIN_PASS' -hypervNodes '$HYPERV_NODES' >> '$LOG_DIR'\050-ensure_pip_pkgs.log 2>&1"'
    echo "Run gerrit-git-prep on $PARAMS with zuul-site=$ZUUL_SITE zuul-ref=$ZUUL_REF zuul-change=$ZUUL_CHANGE zuul-project=$ZUUL_PROJECT"
    run_wsmancmd_with_retry 3 $PARAMS "bash C:\openstack\cinder-ci\windows\scripts\gerrit-git-prep.sh --zuul-site $ZUUL_SITE --gerrit-site $ZUUL_SITE --zuul-ref $ZUUL_REF --zuul-change $ZUUL_CHANGE --zuul-project $ZUUL_PROJECT"
    echo "installin cinder"
    run_ps_cmd_with_retry 3 $PARAMS '"C:\openstack\cinder-ci\windows\scripts\install_cinder.ps1 -devstackIP '$FIXED_IP' -branchName '$ZUUL_BRANCH' -buildFor '$ZUUL_PROJECT' -testCase '$JOB_TYPE' -winUser '$WIN_USER' -winPasswd '$WIN_PASS' -hypervNodes '$HYPERV_NODES' >> '$LOG_DIR'\060-install_cinder.log 2>&1"'
    echo "creating config"
    run_ps_cmd_with_retry 3 $PARAMS '"C:\openstack\cinder-ci\windows\scripts\create_config.ps1 -devstackIP '$FIXED_IP' -branchName '$ZUUL_BRANCH' -buildFor '$ZUUL_PROJECT' -testCase '$JOB_TYPE' -winUser '$WIN_USER' -winPasswd '$WIN_PASS' -hypervNodes '$HYPERV_NODES' >> '$LOG_DIR'\070-create_config.log 2>&1"'
    echo "starting services"
    run_ps_cmd_with_retry 3 $PARAMS '"C:\openstack\cinder-ci\windows\scripts\start_services.ps1 -devstackIP '$FIXED_IP' -branchName '$ZUUL_BRANCH' -buildFor '$ZUUL_PROJECT' -testCase '$JOB_TYPE' -winUser '$WIN_USER' -winPasswd '$WIN_PASS' -hypervNodes '$HYPERV_NODES' >> '$LOG_DIR'\080-start_services.log 2>&1"'
}


post_build_restart_cinder_windows_services (){
    run_wsmancmd_with_retry 5 $1 $2 $3 '"powershell -ExecutionPolicy RemoteSigned C:\openstack\cinder-ci\windows\scripts\post-build-restart-services.ps1 >> '$LOG_DIR'\create-environment-post-build.log 2>&1"'
}

function timestamp(){
    echo `date -u +%H:%M:%S`
}

