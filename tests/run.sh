#!/bin/bash
#
# Run all the available tests
#
if [ -x unit_test ]; then
    echo "Executing unit tests."
    ./unit_test
else
    echo "Skipping unit tests. Please compile them."
fi
echo "Executing integration tests."
git submodule init
git submodule update
cd ./ntopng-e2e-tests/rest; ./run.sh
