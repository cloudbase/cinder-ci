#!/bin/bash
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
. $DIR/config.sh
. $DIR/utils.sh
. $DIR/devstack_params.sh

function emit_error() {
    echo "ERROR: $1"
    exit 1
}

function emit_warning() {
    echo "WARNING: $1"
    return 0
}

function archive_devstack() {
    #Start collecting the devstack logs:
    if [ ! -d "$LOG_DST_DEVSTACK" ]
    then
        mkdir -p "$LOG_DST_DEVSTACK" || emit_error "L30: Failed to create $LOG_DST_DEVSTACK"
    fi

    for i in `ls -A $DEVSTACK_LOGS`
    do
        if [ -h "$DEVSTACK_LOGS/$i" ]
        then
                REAL=$(readlink "$DEVSTACK_LOGS/$i")
                $GZIP -c "$REAL" > "$LOG_DST_DEVSTACK/$i.gz" || emit_warning "Failed to archive devstack logs"
        fi
    done

    $GZIP -c "$MEMORY_STATS" > "$LOG_DST_DEVSTACK/memory_usage.log.gz" || emit_warning "Failed to archive memory_stat.log" 
    for stack_log in `ls -A $DEVSTACK_LOG_DIR | grep "stack.sh.txt" | grep -v "gz"` 
    do
        $GZIP -c "$DEVSTACK_LOG_DIR/$stack_log" > "$LOG_DST_DEVSTACK/$stack_log.gz" || emit_warning "Failed to archive devstack log"     
    done
    $GZIP -c "$MEMORY_STATS" > "$LOG_DST_DEVSTACK/memory_usage.log.gz" || emit_warning "Failed to archive memory_stat.log"
    $GZIP -c "$DEVSTACK_BUILD_LOG" > "$LOG_DST_DEVSTACK/stack.sh.log.gz" || emit_warning "Failed to archive devstack log"
    $GZIP -c "$IOSTAT_LOG" > "$LOG_DST_DEVSTACK/iostat.log.gz" || emit_warning "Failed to archive iostat.log"
    $GZIP -c /var/log/mysql/error.log > "$LOG_DST_DEVSTACK/mysql_error.log.gz" || emit_warning "Failed to archive mysql_error.log"
    $GZIP -c /var/log/cloud-init.log > "$LOG_DST_DEVSTACK/cloud-init.log.gz" || emit_warning "Failed to archive cloud-init.log"
    $GZIP -c /var/log/cloud-init-output.log > "$LOG_DST_DEVSTACK/cloud-init-output.log.gz" || emit_warning "Failed to archive cloud-init-output.log"
    $GZIP -c /var/log/dmesg > "$LOG_DST_DEVSTACK/dmesg.log.gz" || emit_warning "Failed to archive dmesg.log"
    $GZIP -c /var/log/kern.log > "$LOG_DST_DEVSTACK/kern.log.gz" || emit_warning "Failed to archive kern.log"
    $GZIP -c /var/log/syslog > "$LOG_DST_DEVSTACK/syslog.log.gz" || emit_warning "Failed to archive syslog.log"
    mkdir -p "$LOG_DST_DEVSTACK/rabbitmq" || emit_warning "Failed to create rabbitmq directory"
    cp /var/log/rabbitmq/* "$LOG_DST_DEVSTACK/rabbitmq" || emit_warning "Failed to copy rabbitmq logs"
    sudo rabbitmqctl status > "$LOG_DST_DEVSTACK/rabbitmq/status.txt" 2>&1 || emit_warning "Failed to create rabbitmq stats"
    $GZIP $LOG_DST_DEVSTACK/rabbitmq/*
    
    #Start collecting the devstack configs:
    for i in cinder glance keystone neutron nova 
    do
        mkdir -p $CONFIG_DST_DEVSTACK/$i
        for j in `ls -A /etc/$i`
        do
            if [ -d "/etc/$i/$j" ]
            then
                $TAR cvzf "$CONFIG_DST_DEVSTACK/$i/$j.tar.gz" "/etc/$i/$j"
            else
                $GZIP -c "/etc/$i/$j" > "$CONFIG_DST_DEVSTACK/$i/$j.gz"
            fi
        done
    done

    $GZIP -c /home/ubuntu/devstack/local.conf > "$CONFIG_DST_DEVSTACK/local.conf.gz" || emit_warning "Failed to archive local.conf"
    $GZIP -c /opt/stack/tempest/etc/tempest.conf > "$CONFIG_DST_DEVSTACK/tempest.conf.gz"|| emit_warning "Failed to archive tempest.conf"
    df -h > "$CONFIG_DST_DEVSTACK/df.txt" 2>&1 || emit_warning "Failed to generate df.txt.txt"
    $GZIP "$CONFIG_DST_DEVSTACK/df.txt" || emit_warning "Failed to archive df.txt"
    
    iptables-save > "$CONFIG_DST_DEVSTACK/iptables.txt" 2>&1 || emit_warning "Failed to generate iptables.txt"
    $GZIP "$CONFIG_DST_DEVSTACK/iptables.txt" || emit_warning "Failed to archive iptables.txt"
    dpkg-query -l > "$CONFIG_DST_DEVSTACK/dpkg-l.txt" 2>&1 || emit_warning "Failed to generate dpkg.txt"
    $GZIP "$CONFIG_DST_DEVSTACK/dpkg-l.txt" || emit_warning "Failed to archive dpkg.txt"
    pip freeze > "$CONFIG_DST_DEVSTACK/pip-freeze.txt" 2>&1 || emit_warning "Failed to generate pip-freeze.txt"
    $GZIP "$CONFIG_DST_DEVSTACK/pip-freeze.txt" || emit_warning "Failed to archive pip-freeze.txt"
    ps axwu > "$CONFIG_DST_DEVSTACK/pidstat.txt" 2>&1 || emit_warning "Failed to generate pidstat.txt"
    $GZIP "$CONFIG_DST_DEVSTACK/pidstat.txt" || emit_warning "Failed to archive pidstat.txt"
    ifconfig -a -v > "$CONFIG_DST_DEVSTACK/ifconfig.txt" 2>&1 || emit_warning "Failed to generate ifconfig.txt"
    $GZIP "$CONFIG_DST_DEVSTACK/ifconfig.txt" || emit_warning "Failed to archive ifconfig.txt"
    sudo ovs-vsctl -v show > "$CONFIG_DST_DEVSTACK/ovs_bridges.txt" 2>&1 || emit_warning "Failed to generate ovs_bridges.txt"
    $GZIP "$CONFIG_DST_DEVSTACK/ovs_bridges.txt" || emit_warning "Failed to archive ovs_bridges.txt"
    #/var/log/kern.log
    #/var/log/rabbitmq/
    #/var/log/syslog
}


function archive_windows_logs() {
    if [ ! -d "$LOG_DST_WIN" ]; then
        mkdir -p "$LOG_DST_WIN"
    fi
    for file in `find "$LOG_DST_WIN" -type f`
    do
        $GZIP $file
    done
}

function archive_windows_configs(){
    if [ ! -d "$CONFIG_DST_WIN" ]; then
        mkdir -p "$CONFIG_DST_WIN"
    fi
    for file in `find "$CONFIG_DST_WIN" -type f`
    do
        $GZIP $file
    done

}

function archive_tempest_files() {
    if [ ! -d "$TEMPEST_LOGS" ]; then
        mkdir -p "$TEMPEST_LOGS"
    fi
    pushd "$TEMPEST_LOGS"
    find . -type f -exec gzip "{}" \;
    popd
    cp -r "$TEMPEST_LOGS" "$LOG_DST"
}

if [ "$IS_DEBUG_JOB" != "yes" ]; then
    echo "Stop devstack services"
    cd /home/ubuntu/devstack
    ./unstack.sh
fi

set +e

echo "Getting Hyper-V logs from $hyperv01 , $hyperv02 and $ws2012r2"
get_win_files $hyperv01_ip "\OpenStack\logs" "$LOG_DST_WIN/$hyperv01-compute01"
get_win_files $hyperv02_ip "\OpenStack\logs" "$LOG_DST_WIN/$hyperv02-compute02"
get_win_files $ws2012r2_ip "\OpenStack\logs" "$LOG_DST_WIN/$ws2012r2-cinder"

echo "Getting Hyper-V configs from $hyperv01 , $hyperv02 and $ws2012r2" 
get_win_files $hyperv01_ip "\OpenStack\etc" "$CONFIG_DST_WIN/$hyperv01-compute01"
get_win_files $hyperv02_ip "\OpenStack\etc" "$CONFIG_DST_WIN/$hyperv02-compute02"
get_win_files $ws2012r2_ip "\OpenStack\etc" "$CONFIG_DST_WIN/$ws2012r2-cinder"

# For security reasons ??
rm -f $DIR/devstack_params.sh

archive_devstack
archive_windows_configs
archive_windows_logs
archive_tempest_files

set -e

pushd "$LOG_DST"
$TAR -czf "$LOG_DST.tar.gz" . || emit_error "Failed to archive aggregate logs"
popd

exit 0
