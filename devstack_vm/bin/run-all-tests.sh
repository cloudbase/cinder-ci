#!/bin/bash

#cinder-specific job type parameter 
job_type=$1

project=${1:-"openstack/cinder"}
tests_dir=${2:-"/opt/stack/tempest"}
parallel_tests=${3:-4}
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
source $tests_dir/.tox/full/bin/activate
set -u

if [ ! -d "$tests_dir/.testrepository" ]; then
    push_dir
    cd $tests_dir

    echo "Initializing testr"
    testr init
    pop_dir
fi

tests_file=$(tempfile)
$basedir/get-tests.sh $project_name $tests_dir $test_suite $JOB_TYPE > $tests_file

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

exit $exit_code
