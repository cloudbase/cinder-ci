#!/bin/bash

job_type=$1
zuul_change=$2

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

if [ $job_type != "iscsi" ]; then
    set +e
    #git remote add downstream https://github.com/alexpilotti/cinder-ci-fixes
    git remote add downstream https://github.com/petrutlucian94/cinder
    git fetch downstream
    set -e
    if [ $zuul_change != "171484" ]; then
        git cherry-pick d99a73a6410a4a63b4818f387d7c561ca268db2f
    fi
    git cherry-pick d9e5d12258bac06e436605da7e3928808f9c98e0
    git cherry-pick c0ed2ab8cc6b1197e426cd6c58c3b582624d1cfd
    git cherry-pick 01fd56078bc4d73236dab02f6df0bd38b344834c
    git cherry-pick 5ea88ec3fb90a520126743669697c957dccf7e96
    git cherry-pick ba51ca2f0dc46565cdd825c689607521ddea6c28
    git cherry-pick 401b44d6f9d45b74a688a6dc70dbefc9346a9fe4
    git cherry-pick 88313c535d4430fb7771965b7ab7f56a61d3aa6c
fi

cd /home/ubuntu/devstack

./unstack.sh

nohup ./stack.sh > /opt/stack/logs/stack.sh.txt 2>&1 &
pid=$!
wait $pid
cat /opt/stack/logs/stack.sh.txt

