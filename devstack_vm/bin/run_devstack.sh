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
    cherry_pick d9e5d12258bac06e436605da7e3928808f9c98e0
    cherry_pick c0ed2ab8cc6b1197e426cd6c58c3b582624d1cfd
    cherry_pick 01fd56078bc4d73236dab02f6df0bd38b344834c
    cherry_pick 5ea88ec3fb90a520126743669697c957dccf7e96
    cherry_pick ba51ca2f0dc46565cdd825c689607521ddea6c28
    cherry_pick 401b44d6f9d45b74a688a6dc70dbefc9346a9fe4
    cherry_pick 88313c535d4430fb7771965b7ab7f56a61d3aa6c
fi

cd /home/ubuntu/devstack

./unstack.sh

nohup ./stack.sh > /opt/stack/logs/stack.sh.txt 2>&1 &
pid=$!
wait $pid
cat /opt/stack/logs/stack.sh.txt

