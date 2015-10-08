#!/bin/bash

job_type=$1

set -x
set -e
sudo ifconfig eth0 promisc up
# sudo ifconfig eth1 promisc up
# sudo ifconfig eth2 promisc up

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

DEVSTACK_LOGS="/opt/stack/logs/screen"
LOCALRC="/home/ubuntu/devstack/localrc"
LOCALCONF="/home/ubuntu/devstack/local.conf"
PBR_LOC="/opt/stack/pbr"
# Clean devstack logs
sudo rm -f "$DEVSTACK_LOGS/*"
sudo rm -rf "$PBR_LOC"

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
    git fetch https://plucian@review.openstack.org/openstack/cinder refs/changes/13/158713/18
    cherry_pick FETCH_HEAD
    cherry_pick 82f169a0aec3fe5ba3f4fa87f36fe365ecf8f108
    cherry_pick 4fef430adbd6c1e40a885040b347e4c9c394c161
fi

cd /opt/stack/nova
# Nova volume attach race condition fix
git fetch https://plucian@review.openstack.org/openstack/nova refs/changes/19/187619/3
cherry_pick FETCH_HEAD

cd /home/ubuntu/devstack

./unstack.sh

# stack.sh output log
STACK_LOG="/opt/stack/logs/stack.sh.txt"
# keep this many rotated stack.sh logs
STACK_ROTATE_LIMIT=6
rotate_log $STACK_LOG $STACK_ROTATE_LIMIT

sed -i "s#PIP_GET_PIP_URL=https://bootstrap.pypa.io/get-pip.py#PIP_GET_PIP_URL=http://dl.openstack.tld/get-pip.py#g" /home/ubuntu/devstack/tools/install_pip.sh

# 8 Oct 2015 # workaround for https://bugs.launchpad.net/nova/+bug/1503974
set +e
pushd /opt/stack/nova
git config --global user.name "microsoft-iscsi-ci"
git config --global user.email "microsoft_cinder_ci@microsoft.com"
git fetch https://review.openstack.org/openstack/nova refs/changes/67/232367/4 && git cherry-pick FETCH_HEAD || echo "Could be that patch/set changed or it was merged in master!"
popd
set -e

set -o pipefail
./stack.sh 2>&1 | tee $STACK_LOG
