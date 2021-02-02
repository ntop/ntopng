#!/bin/bash

RC=0

TESTS_PATH="${PWD}"

NTOPNG_TEST_DATADIR="${TESTS_PATH}/data"
NTOPNG_TEST_CONF="${NTOPNG_TEST_DATADIR}/ntopng.conf"
NTOPNG_TEST_CUSTOM_PROTOS="${NTOPNG_TEST_DATADIR}/protos.txt"
NTOPNG_TEST_REDIS="2"
NTOPNG_TEST_LOCALNETS="192.168.1.0/24"

DEFAULT_PCAP="test_01.pcap"

ntopng_cleanup() {
    # Make sure no other process is running
    killall -9 ntopng > /dev/null 2>&1 || true

    # Cleanup old test stuff
    redis-cli -n "${NTOPNG_TEST_REDIS}" "flushdb" > /dev/null 2>&1
    rm -rf "${NTOPNG_TEST_DATADIR}"
}

ntopng_init_conf() {
    # Prepare a custom protocols file to also check for custom protocols
    mkdir -p "${NTOPNG_TEST_DATADIR}"

    echo "-d=${NTOPNG_TEST_DATADIR}" > ${NTOPNG_TEST_CONF}
    echo "-r=@${NTOPNG_TEST_REDIS}" >> ${NTOPNG_TEST_CONF}
    echo "-p=${NTOPNG_TEST_CUSTOM_PROTOS}" >> ${NTOPNG_TEST_CONF}
    echo "-N=ntopng_test" >> ${NTOPNG_TEST_CONF}
    echo "-m=${NTOPNG_TEST_LOCALNETS}" >> ${NTOPNG_TEST_CONF}
    echo "--shutdown-when-done" >> ${NTOPNG_TEST_CONF}
    echo "--disable-login=1" >> ${NTOPNG_TEST_CONF}
    echo "--dont-change-user" >> ${NTOPNG_TEST_CONF}
    echo "--pid=/tmp/ntopng.pid" >> ${NTOPNG_TEST_CONF}

    cat <<EOF >> "${NTOPNG_TEST_CUSTOM_PROTOS}"
# charles
host:"charles"@Charles

# sebastian
host:"sebastian"@Sebastian

# lando
host:"lando"@Lando
EOF
}

#
# Run ntopng
# Params:
# $1 - Pcap files (Optional)
# $2 - Pre Script (Optional) 
# $3 - Post Script (Optional) 
# $4 - Script Output file
# $5 - ntopng Output file
#
ntopng_run() {
    if [ ! -z "${1}" ]; then
        # TODO handle folder with multiple PCAPs
        echo "-i=${TESTS_PATH}/pcap/${PCAP}" >> ${NTOPNG_TEST_CONF}
    else
        # Default PCAP
        echo "-i=${TESTS_PATH}/pcap/${DEFAULT_PCAP}" >> ${NTOPNG_TEST_CONF}
    fi

    if [ ! -z "${2}" ]; then
        echo "--test-script-pre=bash ${2} >> ${4}" >> ${NTOPNG_TEST_CONF}
    fi

    if [ ! -z "${3}" ]; then
        echo "--test-script=bash ${3} >> ${4}" >> ${NTOPNG_TEST_CONF}
    fi

    # Start the test

    cd ../../; ./ntopng ${NTOPNG_TEST_CONF} | grep "ERROR:\|WARNING:" > ${5}

    cd ${TESTS_PATH}
}

#
# Run tests and compare the output with the expected output
#
run_tests() {

    # Read tests
    NUM_TESTS=`/bin/ls tests/*.yaml | wc -l`
    TESTS=`cd tests; /bin/ls *.yaml`
    I=1

    for T in ${TESTS}; do 
        TEST=${T%.yaml}

	echo "[${I}/${NUM_TESTS}] Test '${TEST}' "
        ((I=I+1))

        # Cleanup ntopng
        ntopng_cleanup

        # Init ntopng configuration
        ntopng_init_conf

        # Init paths
        TMP_FILE=$(mktemp)
        NTOPNG_LOG=${TMP_FILE}.ntopng
        SCRIPT_OUT=${TMP_FILE}.out
        OUT_JSON=${TMP_FILE}.json
        OUT_DIFF=${TMP_FILE}.diff
        PRE_TEST=${TMP_FILE}.pre
        POST_TEST=${TMP_FILE}.post
        IGNORE=${TMP_FILE}.ignore

        # Parsing YAML
        PCAP=`cat tests/${TEST}.yaml | shyaml -q get-value input`
        cat tests/${TEST}.yaml | shyaml -q get-value pre > ${PRE_TEST}
        cat tests/${TEST}.yaml | shyaml -q get-value post > ${POST_TEST}
        cat tests/${TEST}.yaml | shyaml -q get-values ignore > ${IGNORE}

        # Run the test
        ntopng_run "${PCAP}" "${PRE_TEST}" "${POST_TEST}" "${SCRIPT_OUT}" "${NTOPNG_LOG}"

        if [ -s "${NTOPNG_LOG}" ]; then
            # ntopng Error/Warning

            echo "[!] NTOPNG ERROR IN '${TEST}'"
            cat "${NTOPNG_LOG}"
            RC=1

        elif [ ! -f result/${TEST}.out ]; then

            echo "[i] SAVING OUTPUT"

            # Output not present, setting current output as expected
            cat ${SCRIPT_OUT} | jq -cS . > result/${TEST}.out

        else

            # NOTE: using jq as sometimes the json is sorted differently
            cat ${SCRIPT_OUT} | jq -cS . > ${OUT_JSON}

            # Comparison of two JSONs in bash, see
            # https://stackoverflow.com/questions/31930041/using-jq-or-alternative-command-line-tools-to-compare-json-files/31933234#31933234
           
            diff --side-by-side --suppress-common-lines \
                    <(jq -S 'def post_recurse(f): def r: (f | select(. != null) | r), .; r; def post_recurse: post_recurse(.[]?); (. | (post_recurse | arrays) |= sort)' "result/${TEST}.out") \
                    <(jq -S 'def post_recurse(f): def r: (f | select(. != null) | r), .; r; def post_recurse: post_recurse(.[]?); (. | (post_recurse | arrays) |= sort)' "${OUT_JSON}") \
                    > "${OUT_DIFF}"

            if [ -s "${IGNORE}" ]; then
                TMP_OUT_DIFF=${OUT_DIFF}.1
                cat ${OUT_DIFF} | grep -v -f "${IGNORE}" > ${TMP_OUT_DIFF}
                cat ${TMP_OUT_DIFF} > ${OUT_DIFF}
                /bin/rm -f ${TMP_OUT_DIFF}
            fi

            if [ `cat "${OUT_DIFF}" | wc -l` -eq 0 ]; then
                echo "[i] OK"
            else
                echo "[!] OUTPUT ERROR IN '${TEST}'"
                cat "${OUT_DIFF}"
                RC=1
            fi

        fi

        /bin/rm -f ${SCRIPT_OUT} ${NTOPNG_LOG} ${OUT_DIFF} ${OUT_JSON} ${PRE_TEST} ${POST_TEST} ${IGNORE}
    done

    ntopng_cleanup
}

run_tests

exit $RC
