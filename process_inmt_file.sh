#!/bin/bash

destdir=`dirname $1`
base=`basename $1`
basename="${base%.*}"

cat $1 |grep WSR |awk '{if (NF > 10) {print $6" "$16}}' |awk 'BEGIN{FS="."}{print "0."$2" 0."$4}' > ${destdir}/${basename}.scores
