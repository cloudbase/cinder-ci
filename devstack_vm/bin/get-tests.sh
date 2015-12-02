#!/bin/bash
set -e

array_to_regex()
{
    local ar=(${@})
    local regex=""

    for s in "${ar[@]}"
    do
        if [ "$regex" ]; then
            regex+="\\|"
        fi
        regex+="^"$(echo $s | sed -e 's/[]\/$*.^|[]/\\&/g')
    done
    echo $regex
}

project=$1
tests_dir=$2
test_suite=${3:-"default"}
job_type=$4

include_tests_file="/home/ubuntu/bin/included-tests.txt"
include_tests=(`awk 'NF && $1!~/^#/' $include_tests_file`)
include_regex=$(array_to_regex ${include_tests[@]})

#determine which tests to exclude/isolate based on the job type
if [ "$job_type" == "iscsi" ]; then
	exclude_tests_file="/home/ubuntu/bin/excluded-tests-"$job_type".txt"
	isolated_tests_file="/home/ubuntu/bin/isolated-tests-"$job_type".txt"
else
	exclude_tests_file="/home/ubuntu/bin/excluded-tests.txt"
	isolated_tests_file="/home/ubuntu/bin/isolated-tests.txt"
fi


if [ -f "$exclude_tests_file" ]; then
    exclude_tests=(`awk 'NF && $1!~/^#/' $exclude_tests_file`)
fi

if [ -f "$isolated_tests_file" ]; then
    isolated_tests=(`awk 'NF && $1!~/^#/' $isolated_tests_file`)
fi

exclude_tests=( ${exclude_tests[@]} ${isolated_tests[@]} )
exclude_regex=$(array_to_regex ${exclude_tests[@]})

cd $tests_dir

if [ ! "$exclude_regex" ]; then
    exclude_regex='^$'
fi

testr list-tests | grep $include_regex | grep -v $exclude_regex
