#!/bin/bash

root=/Volumes/cjbest
# root=~/Google\ Drive
# root=~/Desktop/unison-transfer

mv "${root}/Research/temp/log.txt" .
perl clockToStamp.pl
mv out.txt output/subject$3/block$2/trial$1/data.txt
mv log.txt output/subject$3/block$2/trial$1/log.txt
mv "${root}/Research/temp/trace.txt" output/subject$3/block$2/trial$1/trace.txt
if [ $4 != "auto" ]; then
	mv "${root}/Research/temp/Utilization_Each_Module.result" output/subject$3/block$2/trial$1/module.txt
	mv "${root}/Research/temp/Utilization_Each_SubNetwork.result" output/subject$3/block$2/trial$1/subnetwork.txt
	perl resultXMLtoCSV.pl output/subject$3/block$2/trial$1/module.txt
	perl -pi -e "s/^\n//" output/subject$3/block$2/trial$1/module.txt
	perl resultXMLtoCSV.pl output/subject$3/block$2/trial$1/subnetwork.txt
	perl -pi -e "s/^\n//" output/subject$3/block$2/trial$1/subnetwork.txt
fi
