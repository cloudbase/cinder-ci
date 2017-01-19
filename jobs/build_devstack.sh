# Loading parameters
source /usr/local/src/cinder-ci-2016/jobs/library.sh
source /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt

# Run devstack
echo "Run stack.sh on devstack with params JOB_TYPE=$JOB_TYPE ZUUL_BRANCH=$ZUUL_BRANCH hv1=$hyperv01 hv2=$hyperv02 hyperv01_ip=$hyperv01_ip hyperv02_ip=$hyperv02_ip"
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY "source /home/ubuntu/keystonerc && /home/ubuntu/bin/run_devstack.sh $JOB_TYPE $ZUUL_BRANCH $hyperv01_ip $hyperv02_ip2" 6
