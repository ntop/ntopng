#!/bin/sh

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

	    # Comparison of two JSONs in bash, see
	    # https://stackoverflow.com/questions/31930041/using-jq-or-alternative-command-line-tools-to-compare-json-files/31933234#31933234
	    JSON_EQUAL=`jq --argfile a result/$f.out --argfile b /tmp/test.out -n 'def post_recurse(f): def r: (f | select(. != null) | r), .; r; def post_recurse: post_recurse(.[]?); ($a | (post_recurse | arrays) |= sort) as $a | ($b | (post_recurse | arrays) |= sort) as $b | $a == $b'`
	    
	    if [ "${JSON_EQUAL}" = "true" ]; then
		printf "%-32s\tOK\n" "$f"
	    else
		printf "%-32s\tERROR\n" "$f"
		echo `diff result/$f.out /tmp/test.out | wc -l`
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
