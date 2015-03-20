#!/bin/bash
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

test_for_cinder () {

    if [ -f "$EXCLUDED_TESTS" ]; then
        exclude_tests=(`awk 'NF && $1!~/^#/' $EXCLUDED_TESTS`)
    fi
    exclude_regex=$(array_to_regex ${exclude_tests[@]})

    testr list-tests tempest.api.volume | grep -v $exclude_regex > "$RUN_TESTS_LIST" || echo "failed to generate list of tests"
    testr list-tests tempest.cli.simple_read_only.test_cinder | grep -v $exclude_regex >> "$RUN_TESTS_LIST" || echo "failed to generate list of tests"
}


cd /opt/stack/tempest

testr init

TEMPEST_DIR="/home/ubuntu/tempest"
EXCLUDED_TESTS="$TEMPEST_DIR/excluded_tests.txt"
RUN_TESTS_LIST="$TEMPEST_DIR/test_list.txt"
mkdir -p "$TEMPEST_DIR"

echo "test_volume_create_get_update_delete_as_clone" > $EXCLUDED_TESTS
echo "test_volume_create_get_update_delete_from_image" >> $EXCLUDED_TESTS

test_for_cinder


testr run --parallel --subunit  --load-list=$RUN_TESTS_LIST |  subunit-2to1  > /home/ubuntu/tempest/subunit-output.log 2>&1
cat /home/ubuntu/tempest/subunit-output.log | /opt/stack/tempest/tools/colorizer.py > /home/ubuntu/tempest/tempest-output.log 2>&1
# testr exits with status 0. colorizer.py actually sets correct exit status
RET=$?
cd /home/ubuntu/tempest/
python /home/ubuntu/bin/subunit2html.py /home/ubuntu/tempest/subunit-output.log

exit $RET

