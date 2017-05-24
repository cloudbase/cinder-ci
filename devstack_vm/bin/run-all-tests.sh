#!/bin/bash

#cinder-specific job type parameter 
job_type=$1

source /home/ubuntu/devstack/functions
TEMPEST_CONFIG=/opt/stack/tempest/etc/tempest.conf

project="openstack/cinder"
tests_dir=${2:-"/opt/stack/tempest"}
parallel_tests=${3:-8}
max_attempts=${4:-3}
test_suite=${5:-"default"}
log_file=${6:-"/home/ubuntu/tempest/subunit-output.log"}
results_html_file=${7:-"/home/ubuntu/tempest/results.html"}
tempest_output_file="/home/ubuntu/tempest/tempest-output.log"
subunit_stats_file="/home/ubuntu/tempest/subunit_stats.log"
TEMPEST_DIR="/home/ubuntu/tempest"

basedir="/home/ubuntu/bin"

project_name=$(basename $project)

mkdir -p $TEMPEST_DIR

pushd $basedir

. $basedir/utils.sh

echo "Started unning tests."

echo "Activating virtual env."
set +u
source $tests_dir/.tox/tempest/bin/activate
set -u

if [ ! -d "$tests_dir/.testrepository" ]; then
    push_dir
    cd $tests_dir

    echo "Initializing testr"
    testr init
    pop_dir
fi

#Set tempest config options:
IMAGE_REF=`iniget $TEMPEST_CONFIG compute image_ref`
iniset $TEMPEST_CONFIG compute image_ref_alt $IMAGE_REF
iniset $TEMPEST_CONFIG compute volume_device_name "sdb"
iniset $TEMPEST_CONFIG compute min_compute_nodes 2
iniset $TEMPEST_CONFIG compute build_timeout 60
iniset $TEMPEST_CONFIG compute ssh_timeout 90
iniset $TEMPEST_CONFIG compute allow_tenant_isolation True

iniset $TEMPEST_CONFIG compute-feature-enabled rdp_console true
iniset $TEMPEST_CONFIG compute-feature-enabled block_migrate_cinder_iscsi False

iniset $TEMPEST_CONFIG volume build_timeout 60
iniset $TEMPEST_CONFIG volume-feature-enabled manage_volume False

iniset $TEMPEST_CONFIG scenario img_dir "/home/ubuntu/devstack/files/images"
iniset $TEMPEST_CONFIG scenario img_file "cirros-0.3.3-x86_64.vhdx"
iniset $TEMPEST_CONFIG scenario img_disk_format vhdx

iniset $TEMPEST_CONFIG orchestration build_timeout 90
iniset $TEMPEST_CONFIG boto build_timeout 60

set +e

tests_file=$(tempfile)
$basedir/get-tests.sh $project_name $tests_dir $test_suite $job_type > $tests_file
cp $tests_file $basedir/normal_tests.txt

$basedir/parallel-test-runner.sh $tests_file $tests_dir $log_file \
    $parallel_tests $max_attempts || true

if [[ $job_type == "iscsi" ]]; then
    isolated_tests_file=$basedir/isolated-tests-iscsi.txt
    if [ -f "$isolated_tests_file" ]; then
        echo "Running isolated tests from: $isolated_tests_file"
        log_tmp=$(tempfile)
        $basedir/parallel-test-runner.sh $isolated_tests_file $tests_dir $log_tmp \
            $parallel_tests $max_attempts 1 || true

        cat $log_tmp >> $log_file
        rm $log_tmp
    fi
else
	isolated_tests_file=$basedir/isolated-tests.txt
	if [ -f "$isolated_tests_file" ]; then
		echo "running isolated tests from: $isolated_tests_file"
		log_tmp=$(tempfile)
		$basedir/parallel-test-runnner.sh $isolated_tests_file $tests_dir $log_tmp \
			$parallel_tests $max_attempts 1 || true
		cat $log_tmp >> $log_file
		rm $log_tmp
	fi
fi

rm $tests_file

echo "Generating HTML report..."
python $basedir/subunit2html.py $log_file $results_html_file

cat $log_file | subunit-trace -n -f > $tempest_output_file 2>&1 || true

subunit-stats $log_file > $subunit_stats_file
exit_code=$?

echo "Total execution time: $SECONDS seconds."

popd
set -e

exit $exit_code
