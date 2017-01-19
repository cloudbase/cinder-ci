#!/bin/bash
# Loading functions
source /usr/local/src/cinder-ci-2016/jobs/utils.sh
set -e
source $KEYSTONERC

echo ws2012r2=$ws2012r2 | tee -a /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt
echo hyperv01=$hyperv01 | tee -a /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt
echo hyperv02=$hyperv02 | tee -a /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt

echo JOB_TYPE=$JOB_TYPE | tee -a /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt
echo ZUUL_PROJECT=$ZUUL_PROJECT | tee -a /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt
echo ZUUL_BRANCH=$ZUUL_BRANCH | tee -a /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt
echo ZUUL_CHANGE=$ZUUL_CHANGE | tee -a /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt
echo ZUUL_PATCHSET=$ZUUL_PATCHSET | tee -a /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt
echo ZUUL_UUID=$ZUUL_UUID | tee -a /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt
echo IS_DEBUG_JOB=$IS_DEBUG_JOB | tee -a /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt
echo DEVSTACK_SSH_KEY=$DEVSTACK_SSH_KEY | tee -a /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt

ZUUL_SITE=`echo "$ZUUL_URL" |sed 's/.\{2\}$//'`
echo ZUUL_SITE=$ZUUL_SITE | tee -a /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt

DEVSTACK_IMAGE="devstack-81v1"
echo DEVSTACK_IMAGE=$DEVSTACK_IMAGE | tee -a /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt

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

echo hyperv01_ip=$hyperv01_ip | tee -a /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt
echo hyperv02_ip=$hyperv02_ip | tee -a /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt

/usr/local/src/cinder-ci-2016/jobs/initialize_nodes.sh #>> /home/jenkins-slave/logs/devstack-build-log-$ZUUL_UUID-$JOB_TYPE 2>&1 &

OSTACK_PROJECT=`echo "$ZUUL_PROJECT" | cut -d/ -f2`

if [[ ! -z $IS_DEBUG_JOB ]] && [[ $IS_DEBUG_JOB == "yes" ]]; then
        echo "All build logs can be found in http://64.119.130.115/debug/$OSTACK_PROJECT/$ZUUL_CHANGE/$ZUUL_PATCHSET/$JOB_TYPE"
    else
        echo "All build log can be found in http://64.119.130.115/$OSTACK_PROJECT/$ZUUL_CHANGE/$ZUUL_PATCHSET/$JOB_TYPE"
fi

echo "Waiting to finish building envs"
wait $pid_devstack
echo "Finished building envs"
