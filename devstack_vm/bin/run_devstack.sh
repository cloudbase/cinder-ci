#!/bin/bash

job_type=$1

set -x
set -e
sudo ifconfig eth1 promisc up
sudo ifconfig eth2 promisc up

HOSTNAME=$(hostname)

sudo sed -i '2i127.0.0.1  '$HOSTNAME'' /etc/hosts

# Add pip cache for devstack
mkdir -p $HOME/.pip
echo "[global]" > $HOME/.pip/pip.conf
echo "trusted-host = dl.openstack.tld" >> $HOME/.pip/pip.conf
echo "index-url = http://dl.openstack.tld:8080/root/pypi/+simple/" >> $HOME/.pip/pip.conf
echo "[install]" >> $HOME/.pip/pip.conf
echo "trusted-host = dl.openstack.tld" >> $HOME/.pip/pip.conf
echo "find-links =" >> $HOME/.pip/pip.conf
echo "    http://dl.openstack.tld/wheels" >> $HOME/.pip/pip.conf

sudo mkdir -p /root/.pip
sudo cp $HOME/.pip/pip.conf /root/.pip/
sudo chown -R root:root /root/.pip

# Update pip to latest
sudo easy_install -U pip

#Update six to latest version
sudo pip install -U six
sudo pip install -U kombu

#Ensure subunit is available
set +e
sudo apt-get install subunit -y -o Debug::pkgProblemResolver=true -o Debug::Acquire::http=true -f
# moreutils is needed for tc (timestamp)
sudo apt-get install moreutils -y -o Debug::pkgProblemResolver=true -o Debug::Acquire::http=true -f
# sysstat needed for iostat
sudo apt-get install sysstat -y -o Debug::pkgProblemResolver=true -o Debug::Acquire::http=true -f
set -e

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
    git remote add downstream https://github.com/petrutlucian94/cinder
    git fetch downstream
    git checkout -b testBranch
    set -e
    cherry_pick 04fbfd1aa7c4fead321bf91fd60bd8ee0c1c482f
    cherry_pick 82f169a0aec3fe5ba3f4fa87f36fe365ecf8f108
    cherry_pick 4fef430adbd6c1e40a885040b347e4c9c394c161
fi

cd /opt/stack/nova
# Nova volume attach race condition fix
git fetch https://plucian@review.openstack.org/openstack/nova refs/changes/19/187619/2
cherry_pick FETCH_HEAD

cd /home/ubuntu/devstack

./unstack.sh
set -o pipefail
./stack.sh 2>&1 | tee /opt/stack/logs/stack.sh.txt
