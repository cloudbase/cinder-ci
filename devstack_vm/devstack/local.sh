#!/bin/bash
set -e

source /home/ubuntu/devstack/functions
source /home/ubuntu/devstack/functions-common

if [ "$branch" == "stable/newton" ] || [ "$branch" == "stable/liberty" ] || [ "$branch" == "stable/mitaka" ]; then
    nova flavor-delete 42
    nova flavor-delete 84
fi

nova flavor-create m1.nano 42 96 1 1

nova flavor-create m1.micro 84 128 2 1

# Add DNS config to the private network
subnet_id=`neutron net-show private | grep subnets | awk '{print $4}'`
neutron subnet-update $subnet_id --dns_nameservers list=true 8.8.8.8 8.8.4.4

# Disable STP on bridge
# ovs-vsctl set bridge br-eth1 stp_enable=true

# Workaround for the missing volume type id. TODO: remove this after it's fixed.
# This is also used for the wrong extra_specs format issue
cinder type-create blank
