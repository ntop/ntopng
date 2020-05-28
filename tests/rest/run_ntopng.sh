#!/bin/sh

NTOPNG_TEST_DATADIR="/var/lib/ntopng_test"
NTOPNG_TEST_CUSTOM_PROTOS="${NTOPNG_TEST_DATADIR}/protos.txt"
NTOPNG_TEST_REDIS="2"
NTOPNG_TEST_LOCALNETS="192.168.1.0/24"

# Make sure no other process is running
killall -9 ntopng || true
# sleep 5

# Cleanup old test stuff
redis-cli -n "${NTOPNG_TEST_REDIS}" "flushdb"
rm -rf "${NTOPNG_TEST_DATADIR}"
rm -rf "{NTOPNG_TEST_CUSTOM_PROTOS}"

# Prepare a custom protocols file to also check for custom protocols
mkdir -p "${NTOPNG_TEST_DATADIR}"
cat <<EOF >> "${NTOPNG_TEST_CUSTOM_PROTOS}"
# charles
host:"charles"@Charles

# sebastian
host:"sebastian"@Sebastian

# lando
host:"lando"@Lando
EOF

# Start the test
cd ../../; ./ntopng -d "${NTOPNG_TEST_DATADIR}" -r "@${NTOPNG_TEST_REDIS}" -p "${NTOPNG_TEST_CUSTOM_PROTOS}" -N "ntopng_test" -m "${NTOPNG_TEST_LOCALNETS}" -i tests/rest/pcap/test_01.pcap -i tests/rest/pcap/test_02.pcap --disable-login 1
