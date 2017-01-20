DEVSTACK_LOG_DIR="/opt/stack/logs"
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

TAR=$(which tar)
GZIP=$(which gzip)
