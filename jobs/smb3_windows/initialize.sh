#!/bin/bash
# Loading functions
source /usr/local/src/cinder-ci/jobs/utils.sh
set -e
source $KEYSTONERC

#Get IP addresses of the two Hyper-V hosts

set +e
IFS='' read -r -d '' PSCODE <<'_EOF'
$NetIPAddr = Get-NetIPAddress | Where-Object {$_.InterfaceAlias -like "*br100*" -and $_.AddressFamily -like "IPv4"}
$IPAddr = $NetIPAddr.IPAddress
Write-Host $IPAddr
_EOF
HYPERV_GET_DATA_IP=`echo "$PSCODE" | iconv -f ascii -t utf16le | base64 -w0`
hyperv01_ip=`run_wsman_cmd $hyperv01 $WIN_USER $WIN_PASS "powershell -ExecutionPolicy RemoteSigned -EncodedCommand $HYPERV_GET_DATA_IP" 2>&1 | grep -E -o '10\.250\.[0-9]{1,2}\.[0-9]{1,3}'`
hyperv02_ip=`run_wsman_cmd $hyperv02 $WIN_USER $WIN_PASS "powershell -ExecutionPolicy RemoteSigned -EncodedCommand $HYPERV_GET_DATA_IP" 2>&1 | grep -E -o '10\.250\.[0-9]{1,2}\.[0-9]{1,3}'`
set -e

echo `date -u +%H:%M:%S` "Data IP of $hyperv01 is $hyperv01_ip"
echo `date -u +%H:%M:%S` "Data IP of $hyperv02 is $hyperv02_ip"
if [[ ! $hyperv01_ip =~ ^10\.250\.[0-9]{1,2}\.[0-9]{1,3} ]]; then
    echo "Did not receive a good IP for Hyper-V host $hyperv01 : $hyperv01_ip"
    exit 1
fi
if [[ ! $hyperv02_ip =~ ^10\.250\.[0-9]{1,2}\.[0-9]{1,3} ]]; then
    echo "Did not receive a good IP for Hyper-V host $hyperv02 : $hyperv02_ip"
    exit 1
fi

# Deploy devstack vm
source /usr/local/src/cinder-ci/jobs/deploy_devstack_vm.sh $hyperv01_ip $hyperv02_ip
# Deploy Windows Cinder vm
#source /usr/local/src/cinder-ci/jobs/deploy_cinder_windows_vm.sh

source /usr/local/src/cinder-ci/jobs/build_hyperv.sh $hyperv01 $JOB_TYPE
source /usr/local/src/cinder-ci/jobs/build_hyperv.sh $hyperv02 $JOB_TYPE