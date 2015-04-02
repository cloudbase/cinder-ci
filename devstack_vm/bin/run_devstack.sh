#!/bin/bash

set -x
set -e
sudo ifconfig eth1 promisc up
sudo ifconfig eth2 promisc up

HOSTNAME=$(hostname)

sudo sed -i '2i127.0.0.1  '$HOSTNAME'' /etc/hosts

#Update six to latest version
sudo pip install -U six
sudo pip install -U kombu

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
git remote add downstream https://github.com/alexpilotti/cinder-ci-fixes
#git remote add downstream https://github.com/petrutlucian94/cinder
git fetch downstream
git cherry-pick d99a73a6410a4a63b4818f387d7c561ca268db2f
git cherry-pick d9e5d12258bac06e436605da7e3928808f9c98e0
git cherry-pick c0ed2ab8cc6b1197e426cd6c58c3b582624d1cfd
git cherry-pick 01fd56078bc4d73236dab02f6df0bd38b344834c
git cherry-pick ae508692c7978e19743211290c1b2a8dfa63f75d
git cherry-pick 184506b6db02f9f7e620ce340b74e391cc200f41
git cherry-pick 73cb62a862ecf005192c5563d5782416dcf4aec9
git cherry-pick 554810c3224c01edf7755f9b5809f59f5f73df23

cd /home/ubuntu/devstack

./unstack.sh

nohup ./stack.sh > /opt/stack/logs/stack.sh.txt 2>&1 &
pid=$!
wait $pid
cat /opt/stack/logs/stack.sh.txt

