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

run_wsmancmd_with_retry () {
    HOST=$1
    USERNAME=$2
    PASSWORD=$3
    CMD=${@:4}

    exec_with_retry 18 10 "python /var/lib/jenkins/jenkins-master/wsman.py -U https://$HOST:5986/wsman -u $USERNAME -p $PASSWORD $CMD"
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
    HOST=$1
    USERNAME=$2
    PASSWORD=$3
    CMD=${@:4}
    PS_EXEC_POLICY='-ExecutionPolicy RemoteSigned'

    run_wsmancmd_with_retry $HOST $USERNAME $PASSWORD "powershell $PS_EXEC_POLICY $CMD"
}

function get_hyperv_logs() {
        
        set +e
        ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $DEVSTACK_SSH_KEY ubuntu@$DEVSTACK_FLOATING_IP "sudo mkdir -p /openstack/logs/windows"
        ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $DEVSTACK_SSH_KEY ubuntu@$DEVSTACK_FLOATING_IP "sudo chown -R nobody:nogroup /openstack/logs/windows"
        ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $DEVSTACK_SSH_KEY ubuntu@$DEVSTACK_FLOATING_IP "sudo chmod -R 777 /openstack/logs/windows"
        set -f


  run_wsmancmd_with_retry $CINDER_FLOATING_IP $WINDOWS_USER $WINDOWS_PASSWORD 'powershell -executionpolicy remotesigned C:\cinder-ci\windows\scripts\export-eventlog.ps1'
  run_wsmancmd_with_retry $CINDER_FLOATING_IP $WINDOWS_USER $WINDOWS_PASSWORD 'powershell -executionpolicy remotesigned cp -Recurse -Container  C:\OpenStack\Logs\Eventlog \\'$DEVSTACK_FLOATING_IP'\openstack\logs\windows\'
  run_wsmancmd_with_retry $CINDER_FLOATING_IP $WINDOWS_USER $WINDOWS_PASSWORD 'systeminfo >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\windows\systeminfo.log'
  run_wsmancmd_with_retry $CINDER_FLOATING_IP $WINDOWS_USER $WINDOWS_PASSWORD 'wmic qfe list >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\windows\windows_hotfixes.log'
  run_wsmancmd_with_retry $CINDER_FLOATING_IP $WINDOWS_USER $WINDOWS_PASSWORD 'pip freeze >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\windows\pip_freeze.log'
  run_wsmancmd_with_retry $CINDER_FLOATING_IP $WINDOWS_USER $WINDOWS_PASSWORD 'ipconfig /all >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\windows\ipconfig.log'

  run_wsmancmd_with_retry $CINDER_FLOATING_IP $WINDOWS_USER $WINDOWS_PASSWORD 'powershell -executionpolicy remotesigned get-netadapter ^| Select-object * >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\windows\get_netadapter.log'
  run_wsmancmd_with_retry $CINDER_FLOATING_IP $WINDOWS_USER $WINDOWS_PASSWORD 'powershell -executionpolicy remotesigned get-WmiObject win32_logicaldisk ^| Select-object * >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\windows\disk_free.log'
  run_wsmancmd_with_retry $CINDER_FLOATING_IP $WINDOWS_USER $WINDOWS_PASSWORD 'powershell -executionpolicy remotesigned get-netfirewallprofile ^| Select-Object * >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\windows\firewall.log'
  run_wsmancmd_with_retry $CINDER_FLOATING_IP $WINDOWS_USER $WINDOWS_PASSWORD 'powershell -executionpolicy remotesigned get-process ^| Select-Object * >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\windows\get_process.log'
  run_wsmancmd_with_retry $CINDER_FLOATING_IP $WINDOWS_USER $WINDOWS_PASSWORD 'powershell -executionpolicy remotesigned get-service ^| Select-Object * >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\windows\get_service.log'

  run_wsmancmd_with_retry $CINDER_FLOATING_IP $WINDOWS_USER $WINDOWS_PASSWORD 'sc qc nova-compute >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\windows\nova_compute_service.log'
  run_wsmancmd_with_retry $CINDER_FLOATING_IP $WINDOWS_USER $WINDOWS_PASSWORD 'sc qc neutron-hyperv-agent >> \\'$DEVSTACK_FLOATING_IP'\openstack\logs\windows\neutron_hyperv_agent_service.log'

}

post_build_restart_cinder_windows_services (){
    run_wsmancmd_with_retry $1 $2 $3 '"powershell -ExecutionPolicy RemoteSigned C:\cinder-ci\windows\scripts\post-build-restart-services.ps1 2>&1"'
}

