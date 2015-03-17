#!/bin/bash

source /home/ubuntu/keystonerc

CINDER_COUNT=$(cinder service-list | grep cinder-volume | grep -c -w up); 

if [ "$CINDER_COUNT" != 1 ]
then
    exit 1
fi
