#!/bin/bash

job_type=$1

set -x
set -e
sudo ifconfig eth0 promisc up
sudo ifconfig eth1 promisc up
sudo dhclient -v eth1

# sudo ifconfig eth2 promisc up

HOSTNAME=$(hostname)

sudo sed -i '2i127.0.0.1  '$HOSTNAME'' /etc/hosts

# Add pip cache for devstack
mkdir -p $HOME/.pip
echo "[global]" > $HOME/.pip/pip.conf
echo "trusted-host = 10.0.110.1" >> $HOME/.pip/pip.conf
echo "index-url = http://10.0.110.1:8080/cloudbase/CI/+simple/" >> $HOME/.pip/pip.conf
echo "[install]" >> $HOME/.pip/pip.conf
echo "trusted-host = 10.0.110.1" >> $HOME/.pip/pip.conf

sudo mkdir -p /root/.pip
sudo cp $HOME/.pip/pip.conf /root/.pip/
sudo chown -R root:root /root/.pip

#Update packages to latest version
sudo easy_install -U pip
sudo pip install -U six
sudo pip install -U kombu

DEVSTACK_LOGS="/opt/stack/logs/screen"
LOCALRC="/home/ubuntu/devstack/localrc"
LOCALCONF="/home/ubuntu/devstack/local.conf"
PBR_LOC="/opt/stack/pbr"
# Clean devstack logs
sudo rm -f "$DEVSTACK_LOGS/*"
sudo rm -rf "$PBR_LOC"
cp /etc/hosts $DEVSTACK_LOGS/hosts.txt


MYIP=$(/sbin/ifconfig eth0 2>/dev/null| grep "inet addr:" 2>/dev/null| sed 's/.*inet addr://g;s/ .*//g' 2>/dev/null)

if [ -e "$LOCALCONF" ]
then
    	[ -z "$MYIP" ] && exit 1
        sed -i 's/^HOST_IP=.*/HOST_IP='$MYIP'/g' "$LOCALCONF"
fi

if [ -e "$LOCALRC" ]
then
    	[ -z "$MYIP" ] && exit 1
        sed -i 's/^HOST_IP=.*/HOST_IP='$MYIP'/g' "$LOCALRC"
fi


cd /home/ubuntu/devstack
git pull

# Revert the driver disable patch
cd /opt/stack/cinder
git config --global user.email "microsoft_cinder_ci@microsoft.com"
git config --global user.name "Microsoft Cinder CI"

rotate_log () {
    local file="$1"
    local limit=$2
    if [ -f $file ] ; then
        if [ -f ${file}.${limit} ] ; then
            rm ${file}.${limit}
        fi

        for (( CNT=$limit; CNT > 1; CNT-- )) ; do
            if [ -f ${file}.$(($CNT-1)) ]; then
                mv ${file}.$(($CNT-1)) ${file}.${CNT} || echo "Failed to run: mv ${file}.$(($CNT-1)) ${file}.${CNT}"
            fi
        done

        # Renames current log to .1
        mv $file ${file}.1
        touch $file
    fi
}

function cherry_pick(){
    commit=$1
    set +e
    git cherry-pick $commit

    if [ $? -ne 0 ]
    then
        echo "Ignoring failed git cherry-pick $commit"
        git checkout --force
    fi

    set -e
}

if [ $job_type != "iscsi" ]; then
    set +e
    git remote add downstream https://github.com/petrutlucian94/cinder
    git fetch downstream
    git checkout -b testBranch
    set -e
    cherry_pick 56b1194332c29504ab96da35cf4f56143f0bd9cd
    cherry_pick 19341815884e235704f672ec377cdef9b1b5cb73
    cherry_pick 6f2fbf3fbef0f0bc3a21a495a2e60825adf8b848
fi

cd /opt/stack/nova
# Nova volume attach race condition fix
git fetch https://plucian@review.openstack.org/openstack/nova refs/changes/19/187619/3
cherry_pick FETCH_HEAD

cd /home/ubuntu/devstack

./unstack.sh

#Fix for unproper ./unstack.sh
screen_pid=$(ps auxw | grep -i screen | grep -v grep | awk '{print $2}')
if [[ -n $screen_pid ]] 
then
    kill -9 $screen_pid
    #In case there are "DEAD ????" screens, we remove them
    screen -wipe
fi

# stack.sh output log
STACK_LOG="/opt/stack/logs/stack.sh.txt"
# keep this many rotated stack.sh logs
STACK_ROTATE_LIMIT=6
rotate_log $STACK_LOG $STACK_ROTATE_LIMIT

sed -i "s#PIP_GET_PIP_URL=https://bootstrap.pypa.io/get-pip.py#PIP_GET_PIP_URL=http://10.0.110.1/get-pip.py#g" /home/ubuntu/devstack/tools/install_pip.sh

set -o pipefail
./stack.sh 2>&1 | tee $STACK_LOG
