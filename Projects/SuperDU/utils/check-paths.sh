#!/bin/bash

UtilPath=`dirname $0`
tempscript=/tmp/pathCheck.$RANDOM

cd "$UtilPath" || exit 1

echo \#\!/bin/bash > "${tempscript}"
cat ../conf/paths.cfg | grep -v ^# | grep -v ^$ | awk -F, '{print $4}' | grep -v none | sed 's/^/\.\//g' | sed 's/$/ --verbose/g' >> ${tempscript}
bash "${tempscript}"

rm -f "${tempscript}"
