#!/usr/bin/env bash

#####################################################
# Created by cryptopool.builders for crypto use...
#####################################################
# Needs to be ran after the first reboot of the system after permissions are set
#####################################################

source /etc/multipool.conf

sleep 5
yiimp checkup > /dev/null 2>&1 || true

# Prevents error when trying to log in to admin panel the first time...
# (the log folder has default ACLs so both the web server and the YiiMP
# screens can write to the files created in it)
touch "$STORAGE_ROOT/yiimp/site/log/debug.log"

# Delete me no longer needed after it runs the first time

sudo rm -f "$STORAGE_ROOT/yiimp/first_boot.sh"
