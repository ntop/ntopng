#!/bin/bash

TARGET_DIR=$1

if [ -z "$TARGET_DIR" ]; then
    echo "Usage: copylibs.sh <target dir>"
    exit
fi

TMPFILE="/tmp/findlibs"
TMPFILEALL="/tmp/findlibsall"

function findlibs {
    otool -L $1 | tail -n +2 | cut -d '(' -f 1 | tr -d '[:blank:]' | grep -v "^/usr/lib/" | grep -v "^/System/Library/" >> $2
}

/bin/rm -f $TMPFILE $TMPFILEALL

findlibs /usr/local/bin/redis-server $TMPFILE
findlibs ../../ntopng $TMPFILE

cp $TMPFILE $TMPFILEALL

while read p; do
    # echo "** Processing $p"
    findlibs $p $TMPFILEALL
done <$TMPFILE

sort -u $TMPFILEALL > $TMPFILE

#
# One more try for nested dependencies
#

for LOOP in 1 2 3
do
    /bin/rm -f $TMPFILEALL
    
    while read p; do
	# echo "** Processing $p"
	findlibs $p $TMPFILEALL
    done <$TMPFILE
    
    sort -u $TMPFILEALL > $TMPFILE
done

# Now copy the libraries to the target directory

while read p; do
    # echo "** cp $p $TARGET_DIR"
    cp $p $TARGET_DIR
done <$TMPFILE


/bin/rm -f $TMPFILE $TMPFILEALL
