#!/bin/bash

SCRIPTS_DIR="${HOME}/ntopng/scripts"
HTTPDOCS_DIR="${HOME}/ntopng/httpdocs"
CALLBACKS_DIR="${HOME}/ntopng/scripts/callbacks"
DATA_DIR=""
USER="ntopng"

function setup_data_dir() {
    # the temp directory used, within $DIR
    # omit the -p parameter to create a temporal directory in the default location
    DATA_DIR=`mktemp -d -p /tmp`

    # check if tmp dir was created
    if [[ ! "$DATA_DIR" || ! -d "$DATA_DIR" ]]; then
	echo "Could not create data dir directory"
	exit 1
    fi

    chown -R ${USER}:${USER} "${DATA_DIR}"
}

function cleanup() {
    rm -rf "${DATA_DIR}"
}

trap cleanup EXIT

setup_data_dir

EXECUTABLE="./ntopng --scripts-dir ${SCRIPTS_DIR} --httpdocs-dir ${HTTPDOCS_DIR} --callbacks-dir ${CALLBACKS_DIR} --data-dir ${DATA_DIR} --shutdown-when-done --disable-login 1"

${EXECUTABLE} -i ./tests/pcap/ping_req_reply.pcap --test-script test_ping_req_reply.lua -F "nindex"
