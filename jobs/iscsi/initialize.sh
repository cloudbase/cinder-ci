#!/bin/bash
# Loading functions
source /usr/local/src/cinder-ci-2016/jobs/utils.sh
set -e
source $KEYSTONERC

#Get IP addresses of the two Hyper-V hosts
hyperv01_ip=`run_wsman_cmd $hyperv01 $WIN_USER $WIN_PASS 'powershell -ExecutionPolicy RemoteSigned (Get-NetIPAddress -InterfaceAlias "*br100*" -AddressFamily "IPv4").IPAddress' 2>&1 | grep -E -o '10\.250\.[0-9]{1,2}\.[0-9]{1,3}'` 
hyperv02_ip=`run_wsman_cmd $hyperv02 $WIN_USER $WIN_PASS 'powershell -ExecutionPolicy RemoteSigned (Get-NetIPAddress -InterfaceAlias "*br100*" -AddressFamily "IPv4").IPAddress' 2>&1 | grep -E -o '10\.250\.[0-9]{1,2}\.[0-9]{1,3}'`
set -e

echo `timestamp` "Data IP of $hyperv01 is $hyperv01_ip"
echo `timestamp` "Data IP of $hyperv02 is $hyperv02_ip"

if [[ ! $hyperv01_ip =~ ^10\.250\.[0-9]{1,2}\.[0-9]{1,3} ]]; then
    echo "Did not receive a good IP for Hyper-V host $hyperv01 : $hyperv01_ip"
    exit 1
fi
if [[ ! $hyperv02_ip =~ ^10\.250\.[0-9]{1,2}\.[0-9]{1,3} ]]; then
    echo "Did not receive a good IP for Hyper-V host $hyperv02 : $hyperv02_ip"
    exit 1
fi

echo `timestamp` "Started to build devstack as a threaded job"

# Deploy devstack vm
nohup /usr/local/src/cinder-ci-2016/jobs/deploy_devstack_vm.sh $hyperv01_ip $hyperv02_ip > /home/jenkins-slave/logs/devstack-build-log-$ZUUL_UUID 2>&1 &
pid_devstack=$!
# Deploy Windows Cinder vm
#source /usr/local/src/cinder-ci/jobs/deploy_cinder_windows_vm.sh

nohup /usr/local/src/cinder-ci-2016/jobs/build_hyperv.sh $hyperv01_ip $JOB_TYPE > /home/jenkins-slave/logs/hyperv-$hyperv01-build-log-$ZUUL_UUID 2>&1 &
pid_hv1=$!

nohup /usr/local/src/cinder-ci-2016/jobs/build_hyperv.sh $hyperv02_ip $JOB_TYPE > /home/jenkins-slave/logs/hyperv-$hyperv02-build-log-$ZUUL_UUID 2>&1 &
pid_hv2=$!

nohup /usr/local/src/cinder-ci-2016/jobs/build_windows.sh $ws2012r2 $JOB_TYPE "$hyperv01,$hyperv02" > /home/jenkins-slave/logs/ws2012-build-log-$ZUUL_UUID 2>&1 &
pid_ws2016=$!

TIME_COUNT=0
PROC_COUNT=4

echo `timestamp` "Start waiting for parallel init jobs."

finished_devstack=0;
finished_hv01=0;
finished_hv02=0;
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
    if [[ $finished_hv02 -eq 0 ]]; then
        ps -p $pid_hv02 > /dev/null 2>&1 || finished_hv02=$?
        [[ $finished_hv02 -ne 0 ]] && PROC_COUNT=$(( $PROC_COUNT - 1 )) && echo `date -u +%H:%M:%S` "Finished building $hyperv02"
    fi
    if [[ $PROC_COUNT -gt 0 ]]; then
        sleep 1m
        TIME_COUNT=$(( $TIME_COUNT +1 ))
    fi
done

echo `timestamp` "Finished waiting for the parallel init jobs."
echo `timestamp` "We looped $TIME_COUNT times, and when finishing we have $PROC_COUNT threads still active"

OSTACK_PROJECT=`echo "$ZUUL_PROJECT" | cut -d/ -f2`

if [[ ! -z $IS_DEBUG_JOB ]] && [[ $IS_DEBUG_JOB == "yes" ]]; then
        echo "All build logs can be found in http://64.119.130.115/debug/$OSTACK_PROJECT/$JOB_TYPE/$ZUUL_CHANGE/$ZUUL_PATCHSET/"
    else
        echo "All build log can be found in http://64.119.130.115/$OSTACK_PROJECT/$JOB_TYPE/$ZUUL_CHANGE/$ZUUL_PATCHSET/"
fi

if [[ $PROC_COUNT -gt 0 ]]; then
    kill -9 $pid_devstack > /dev/null 2>&1
    kill -9 $pid_hv01 > /dev/null 2>&1
    kill -9 $pid_hv02 > /dev/null 2>&1
    kill -9 $pid_ws2012 > /dev/null 2>&1
    echo "Not all build threads finished in time, initialization process failed."
    exit 1
fi
