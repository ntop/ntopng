#!/bin/sh

READER="../example/ndpiReader -p ../example/protos.txt -c ../example/categories.txt"

RC=0
TESTS=`cd tests; /bin/ls *.test`

build_results() {
    for f in $TESTS; do 
	#echo $f
	# create result files if not present
	if [ ! -f result/$f.out ]; then
	    CMD=`bash tests/$f | jq -cS . > result/$f.out`
	fi
    done
}

#
# NOTE
# Use jq as sometimes the json is sorted differently
#
check_results() {
    for f in $TESTS; do 
	if [ -f result/$f.out ]; then
	    CMD=`bash tests/$f | jq -cS . > /tmp/test.out`
	    NUM_DIFF=`diff result/$f.out /tmp/test.out | wc -l`
	    
	    if [ $NUM_DIFF -eq 0 ]; then
		printf "%-32s\tOK\n" "$f"
	    else
		printf "%-32s\tERROR\n" "$f"
		echo "$CMD"
		diff result/$f.out /tmp/test.out
		RC=1
	    fi

	    /bin/rm /tmp/test.out
	fi
    done
}

build_results
check_results

exit $RC
