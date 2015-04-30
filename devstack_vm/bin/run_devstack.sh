#!/bin/bash

job_type=$1

set -x
set -e
sudo ifconfig eth1 promisc up
sudo ifconfig eth2 promisc up

HOSTNAME=$(hostname)

sudo sed -i '2i127.0.0.1  '$HOSTNAME'' /etc/hosts

#Update six to latest version
sudo pip install -U six
sudo pip install -U kombu

#Ensure subunit is available
sudo apt-get install -y subunit

DEVSTACK_LOGS="/opt/stack/logs/screen"
LOCALRC="/home/ubuntu/devstack/localrc"
LOCALCONF="/home/ubuntu/devstack/local.conf"
PBR_LOC="/opt/stack/pbr"
# Clean devstack logs
rm -f "$DEVSTACK_LOGS/*"
rm -rf "$PBR_LOC"

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
sudo easy_install -U pip

# Revert the driver disable patch
cd /opt/stack/cinder
git config --global user.email "microsoft_cinder_ci@microsoft.com"
git config --global user.name "Microsoft Cinder CI"

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
    #git remote add downstream https://github.com/alexpilotti/cinder-ci-fixes
    git remote add downstream https://github.com/petrutlucian94/cinder
    git fetch downstream
    git checkout -b testBranch
    set -e
    cherry_pick 3df6cd5be8b432d7646625a78ea71fbac5c85305
    cherry_pick c63cb654262170cfbb0f804193265977b5aa5ae0
    cherry_pick d1e88a318226849a0c111594acb79000ab4b1a74
    cherry_pick d685c7e71197b4805239c0063ee5a8f7857e6de1
fi

cd /home/ubuntu/devstack

./unstack.sh

nohup ./stack.sh > /opt/stack/logs/stack.sh.txt 2>&1 &
pid=$!
wait $pid
cat /opt/stack/logs/stack.sh.txt

