#!/bin/bash
jen_date=$(date +%d/%m/%Y-%H:%M)
basedir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
export IS_DEBUG_JOB
set +e
$basedir/initialize_nodes.sh 2>&1
result_init=$?
echo "$ZUUL_PROJECT;$ZUUL_BRANCH;$jen_date;$ZUUL_CHANGE;$ZUUL_PATCHSET;init;$result_init" >> /home/jenkins-slave/cinder-2016-statistics.log
echo "Init job finished with exit code $result_init"

if [ $result_init -eq 0 ]; then
    jen_date=$(date +%d/%m/%Y-%H:%M)
    if [[ ! -z "$RUN_TESTS" ]] && [[ "$RUN_TESTS" == "no" ]]; then
        echo "Init phase done, not running tests"
        result_tempest=0
    else
        $basedir/run_tests.sh 2>&1
        result_tempest=$?
        echo "$ZUUL_PROJECT;$ZUUL_BRANCH;$jen_date;$ZUUL_CHANGE;$ZUUL_PATCHSET;run;$result_tempest" >> /home/jenkins-slave/cinder-2016-statistics.log
        echo "Tempest job finished with exit code $result_tempest"
    fi
fi

jen_date=$(date +%d/%m/%Y-%H:%M)
$basedir/collect_logs.sh 2>&1
result_collect=$?
echo "Collect logs job finished with exit code $result_collect"

if [ $result_init -eq 0 ] && [ $result_tempest -eq 0 ]; then
    exit 0
else
    exit 1
fi
