#!/bin/bash

SCRIPTS_DIR="${HOME}/ntopng/scripts"
HTTPDOCS_DIR="${HOME}/ntopng/httpdocs"
CALLBACKS_DIR="${HOME}/ntopng/scripts/callbacks"
EXECUTABLE="./ntopng --scripts-dir ${SCRIPTS_DIR} --httpdocs-dir ${HTTPDOCS_DIR} --callbacks-dir ${CALLBACKS_DIR} --shutdown-when-done --disable-login 1"

${EXECUTABLE} -i ./tests/pcap/ping_req_reply.pcap --test-script test_ping_req_reply.lua -F "nindex"

