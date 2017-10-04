#!/bin/bash

source /home/ubuntu/devstack/openrc admin admin

CINDER_COUNT=$(openstack volume service list | grep cinder-volume | grep -c -w up); 

if [ "$CINDER_COUNT" != 1 ]
then
    exit 1
fi
