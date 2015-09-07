#!/bin/bash
TAR=$(which tar)
GZIP=$(which gzip)

DEVSTACK_LOGS="/opt/stack/logs/screen"
DEVSTACK_BUILD_LOG="/opt/stack/logs/stack.sh.txt"
MEMORY_STATS="/opt/stack/logs/memory_usage.log"
IOSTAT_LOG="/opt/stack/logs/iostat.log"
WIN_LOGS="/openstack/logs"
TEMPEST_LOGS="/home/ubuntu/tempest"
WIN_CONFIGS="/openstack/config/etc"

LOG_DST="/home/ubuntu/aggregate"
LOG_DST_DEVSTACK="$LOG_DST/devstack_logs"
LOG_DST_WIN="$LOG_DST/windows_logs"
CONFIG_DST_DEVSTACK="$LOG_DST/devstack_config"
CONFIG_DST_WIN="$LOG_DST/windows_config"

function emit_error() {
    echo "ERROR: $1"
    exit 1
}

function emit_warning() {
    echo "WARNING: $1"
    return 0
}

function archive_devstack() {
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
    $GZIP -c "$DEVSTACK_BUILD_LOG" > "$LOG_DST_DEVSTACK/stack.sh.log.gz" || emit_warning "Failed to archive devstack log"
    $GZIP -c "$MEMORY_STATS" > "$LOG_DST_DEVSTACK/memory_usage.log.gz" || emit_warning "Failed to archive memory_stat.log"
    $GZIP -c "$IOSTAT_LOG" > "$LOG_DST_DEVSTACK/iostat.log.gz" || emit_warning "Failed to archive iostat.log"
    for i in cinder glance keystone neutron nova openvswitch openvswitch-switch
    do
        mkdir -p $CONFIG_DST_DEVSTACK/$i
        for j in `ls -A /etc/$i`
        do
            if [ -d /etc/$i/$j ]
            then
                $TAR cvzf "$CONFIG_DST_DEVSTACK/$i/$j.tar.gz" "/etc/$i/$j"
            else
                $GZIP -c "/etc/$i/$j" > "$CONFIG_DST_DEVSTACK/$i/$j.gz"
            fi
        done
    done
    $GZIP -c /home/ubuntu/devstack/local.conf > "$CONFIG_DST_DEVSTACK/local.conf.gz"
    $GZIP -c /opt/stack/tempest/etc/tempest.conf > "$CONFIG_DST_DEVSTACK/tempest.conf.gz"
    df -h > "$CONFIG_DST_DEVSTACK/df.txt" 2>&1 && $GZIP "$CONFIG_DST_DEVSTACK/df.txt"
    iptables-save > "$CONFIG_DST_DEVSTACK/iptables.txt" 2>&1 && $GZIP "$CONFIG_DST_DEVSTACK/iptables.txt"
    dpkg-query -l > "$CONFIG_DST_DEVSTACK/dpkg-l.txt" 2>&1 && $GZIP "$CONFIG_DST_DEVSTACK/dpkg-l.txt"
    pip freeze > "$CONFIG_DST_DEVSTACK/pip-freeze.txt" 2>&1 && $GZIP "$CONFIG_DST_DEVSTACK/pip-freeze.txt"
    ps axwu > "$CONFIG_DST_DEVSTACK/pidstat.txt" 2>&1 && $GZIP "$CONFIG_DST_DEVSTACK/pidstat.txt"
    #/var/log/kern.log
    #/var/log/rabbitmq/
    #/var/log/syslog
}

function archive_windows_logs() {
    if [ -d "$WIN_LOGS" ]
    then
        mkdir -p "$LOG_DST_WIN"

        for i in `ls -A "$WIN_LOGS"`
        do
            if [ -d "$WIN_LOGS/$i" ]
            then            
                mkdir -p "$LOG_DST_WIN/$i"
                for j in `ls -A "$WIN_LOGS/$i"`;
                do
                    $GZIP -c "$WIN_LOGS/$i/$j" > "$LOG_DST_WIN/$i/$j.gz" || emit_warning "Failed to archive $WIN_LOGS/$i/$j"
                done
            else
                $GZIP -c "$WIN_LOGS/$i" > "$LOG_DST_WIN/$i.gz" || emit_warning "Failed to archive $WIN_LOGS/$i"
            fi
        done
    fi
}

function archive_windows_configs(){
    if [ -d "$WIN_CONFIGS" ]
    then
        mkdir -p $CONFIG_DST_WIN
        for i in `ls -A "$WIN_CONFIGS"`
        do
            $GZIP -c "$WIN_CONFIGS/$i" > "$CONFIG_DST_WIN/$i.gz" || emit_warning "Failed to archive $WIN_CONFIGS/$i"
        done
    fi
}

function archive_tempest_files() {
    for i in `ls -A $TEMPEST_LOGS`
    do
        $GZIP "$TEMPEST_LOGS/$i" -c > "$LOG_DST/$i.gz" || emit_error "Failed to archive tempest logs"
    done
}

# Clean

if [[ -z $1 ]] || [[ $1 != "yes" ]]; then
    pushd /home/ubuntu/devstack
    ./unstack.sh
    popd
fi

[ -d "$LOG_DST" ] && rm -rf "$LOG_DST"
mkdir -p "$LOG_DST"

archive_devstack
archive_windows_configs
archive_windows_logs
archive_tempest_files

pushd "$LOG_DST"
$TAR -czf "$LOG_DST.tar.gz" . || emit_error "Failed to archive aggregate logs"
popd

exit 0

