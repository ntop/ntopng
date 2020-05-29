#!/bin/bash

RC=0
TESTS=`cd tests; /bin/ls *.test`

build_results() {
    for f in $TESTS; do 
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
            TMP_OUT=$(mktemp)
            TMP_OUT_DIFF=$(mktemp)

            CMD=`bash tests/$f | jq -cS . > ${TMP_OUT}`

            # Comparison of two JSONs in bash, see
            # https://stackoverflow.com/questions/31930041/using-jq-or-alternative-command-line-tools-to-compare-json-files/31933234#31933234
           
            diff --side-by-side --suppress-common-lines \
                <(jq -S 'def post_recurse(f): def r: (f | select(. != null) | r), .; r; def post_recurse: post_recurse(.[]?); (. | (post_recurse | arrays) |= sort)' "result/$f.out") \
                <(jq -S 'def post_recurse(f): def r: (f | select(. != null) | r), .; r; def post_recurse: post_recurse(.[]?); (. | (post_recurse | arrays) |= sort)' "${TMP_OUT}") \
                > "${TMP_OUT_DIFF}"

            if [ -f "tests/$f.ignore" ]; then
                TMP_TMP_OUT_DIFF=$(mktemp)
                cat ${TMP_OUT_DIFF} | grep -v -f "tests/$f.ignore" > ${TMP_TMP_OUT_DIFF}
                cat ${TMP_TMP_OUT_DIFF} > ${TMP_OUT_DIFF}
            fi

            if [ `cat "${TMP_OUT_DIFF}" | wc -l` -eq 0 ]; then
                printf "%-32s\tOK\n" "$f"
            else
                printf "%-32s\tERROR\n" "$f"
                cat "${TMP_OUT_DIFF}"
                RC=1
            fi

            /bin/rm ${TMP_OUT} ${TMP_OUT_DIFF}
        fi
    done
}

build_results
check_results

exit $RC
