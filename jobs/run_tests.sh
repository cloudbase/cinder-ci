export FAILURE=0
echo "Running tests"
ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $DEVSTACK_SSH_KEY ubuntu@$FLOATING_IP "source /home/ubuntu/keystonerc && /home/ubuntu/bin/run_tests.sh" 
