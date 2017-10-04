#!/bin/bash

source /home/ubuntu/devstack/openrc admin admin

NOVA_COUNT=$(nova service-list | awk '{if (NR > 3) {print $2 " " $10 }}' | grep -c "nova-compute up")

if [ "$NOVA_COUNT" != 1 ]
then
    exit 1
fi

