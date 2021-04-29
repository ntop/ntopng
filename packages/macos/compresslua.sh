#!/bin/bash

#echo "$1"
../../pro/utils/snzip -c -i $1 -o $1r
/bin/rm -f $1
/bin/mv $1r $1
