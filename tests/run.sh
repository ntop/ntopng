#!/bin/bash
#
# Run all the available tests
#
if [ -x unit_tests ]; then
    echo "Executing unit tests."
    sudo  /etc/init.d/redis-server restart
    ./unit_tests
else
    echo "Skipping unit tests. Please compile them."
fi
echo "Executing integration tests."
cd ./e2e/rest; ./run.sh
