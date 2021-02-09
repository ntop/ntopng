#!/bin/bash
#
# Running this script without parameters, all tests in the tests folder will be executed.
#
# ./run.sh
#
# In order to run a specific test, provide the name of the test with the -y option.
#
# ./run.sh -y=get_host_active_01
#
# Clone the packager repository in the same folder to enable notifications
#

TESTS_PATH="${PWD}"
NTOPNG_ROOT="../.."

NTOPNG_TEST_DATADIR="${TESTS_PATH}/data"
NTOPNG_TEST_CONF="${NTOPNG_TEST_DATADIR}/ntopng.conf"
NTOPNG_TEST_CUSTOM_PROTOS="${NTOPNG_TEST_DATADIR}/protos.txt"
NTOPNG_TEST_REDIS="2"

DEFAULT_PCAP="test_01.pcap"

MAIL_FROM=""
MAIL_TO=""
DISCORD_WEBHOOK=""
TEST_NAME=""

DEBUG_LEVEL=0

NOTIFICATIONS_ON=false
if [ -d packager ]; then
    source packager/utils/alerts.sh
    NOTIFICATIONS_ON=true
fi

function usage {
    echo "Usage: run.sh [-y=<test file>] [-f=<mail from>] [-t=<mail to>] [-d=<discord webhook>] [-D=<debug level>]"
    exit 0
}

for i in "$@"
do
    case $i in
	-f=*|--mail-from=*)
	    MAIL_FROM="${i#*=}"
	    ;;

	-t=*|--mail-to=*)
	    MAIL_TO="${i#*=}"
	    ;;

	-d=*|--discord-webhook=*)
	    DISCORD_WEBHOOK="${i#*=}"
	    ;;

	-y=*|--test=*)
	    TEST_NAME="${i#*=}"
	    ;;

	-D=*|--debug=*)
	    DEBUG_LEVEL=${i#*=}
	    ;;

	-h|--help)
	    usage
	    exit 0
	    ;;

	*)
	    # unknown option
	    ;;
    esac
done

if [ "${NOTIFICATIONS_ON}" = true ]; then
    if [ -z "$MAIL_FROM" ] || [ -z "$MAIL_TO" ] ; then
        echo "Warning: please specify -f=<from> -t=<to> to send alerts by mail"
    fi

    if [ -z "$DISCORD_WEBHOOK" ] ; then
        echo "Warning: please specify -d=<discord webhook url> to send alerts to Discord"
    fi
fi

# Send a success alert
function send_success {
    TITLE="${1}"
    MESSAGE="${2}"

    if [ "${NOTIFICATIONS_ON}" = true ]; then
        sendSuccess "${TITLE}" "${MESSAGE}" ""
    else
        echo "[i] ${TITLE}: ${MESSAGE}"
    fi
}

# Send an error alert
function send_error {
    TITLE="${1}"
    MESSAGE="${2}"
    FILE_PATH="${3}"

    if [ "${NOTIFICATIONS_ON}" = true ]; then
        if [ ! -z "${FILE_PATH}" ]; then
            TITLE="${TITLE}: ${MESSAGE}"
        fi

        sendError "${TITLE}" "${MESSAGE}" "${FILE_PATH}"
    else
        echo "[!]  ${TITLE}: ${MESSAGE}"

        if [ ! -z "${FILE_PATH}" ]; then
            cat "${FILE_PATH}"
        fi
    fi
}

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
    echo "--shutdown-when-done" >> ${NTOPNG_TEST_CONF}
    echo "--disable-login=1" >> ${NTOPNG_TEST_CONF}
    echo "--dont-change-user" >> ${NTOPNG_TEST_CONF}
    echo "--pid=./ntopng.pid" >> ${NTOPNG_TEST_CONF}

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
# $6 - Local networks
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

    if [ ! -z "${6}" ]; then
        echo "-m=${6}" >> ${NTOPNG_TEST_CONF}
    fi

    # Start the test

    cd ${NTOPNG_ROOT};

    if [ "${DEBUG_LEVEL}" -gt "0" ]; then
        ./ntopng ${NTOPNG_TEST_CONF}
    else
        ./ntopng ${NTOPNG_TEST_CONF} 2>&1 | grep "ERROR:\|WARNING:\|Direct leak" > ${5}
    fi

    cd ${TESTS_PATH}
}

RC=0

#
# Run tests and compare the output with the expected output
# Params:
# $1 - List of tests to run
#
run_tests() {
    TESTS="${1}"
    TESTS_ARR=( $TESTS )
    NUM_TESTS=${#TESTS_ARR[@]}
    NUM_SUCCESS=0

    if [ ! -f "${NTOPNG_ROOT}/ntopng" ]; then
        send_error "Unable to run tests" "ntopng binary not found, unable to run the tests"
	exit 1
    fi

    I=1
    for T in ${TESTS}; do 
        TEST=${T%.yaml}

	echo "[>] Running test '${TEST}' (${I}/${NUM_TESTS})"
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
        LOCALNET=`cat tests/${TEST}.yaml | shyaml -q get-value localnet`
        cat tests/${TEST}.yaml | shyaml -q get-value pre > ${PRE_TEST}
        cat tests/${TEST}.yaml | shyaml -q get-value post > ${POST_TEST}
        cat tests/${TEST}.yaml | shyaml -q get-values ignore > ${IGNORE}

        # Run the test
        ntopng_run "${PCAP}" "${PRE_TEST}" "${POST_TEST}" "${SCRIPT_OUT}" "${NTOPNG_LOG}" "${LOCALNET}"

        if [ -s "${NTOPNG_LOG}" ]; then
            # ntopng Error/Warning

            send_error "ntopng Error" "ntopng generated errors or warnings running '${TEST}'" "${NTOPNG_LOG}"
            RC=1

        elif [ ! -s "${SCRIPT_OUT}" ]; then

	    send_error "Test Failure" "No output produced by the test '${TEST}'"
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
                ((NUM_SUCCESS=NUM_SUCCESS+1))
                echo "[i] OK"
            else
                send_error "Test Failure" "Unexpected output from the test '${TEST}'" "${OUT_DIFF}"
                RC=1
            fi

        fi

        /bin/rm -f ${SCRIPT_OUT} ${NTOPNG_LOG} ${OUT_DIFF} ${OUT_JSON} ${PRE_TEST} ${POST_TEST} ${IGNORE}
    done

    if [ "${NUM_SUCCESS}" == "${NUM_TESTS}" ]; then
        send_success "ntopng TESTS completed successfully" "All tests completed successfully with the expected output."
    fi

    ntopng_cleanup
}

run_all_tests() {
    # Read tests
    TESTS=`cd tests; /bin/ls *.yaml`
    run_tests "${TESTS}"
}

if [ -z "${TEST_NAME}" ]; then
    run_all_tests
else
    run_tests "${TEST_NAME}.yaml"
fi

exit $RC
