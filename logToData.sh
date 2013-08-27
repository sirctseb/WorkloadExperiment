#!/bin/bash

root=/Volumes/cjbest
# root=~/Google\ Drive
# root=~/Desktop/unison-transfer

mv "${root}/Research/temp/log.txt" .
perl clockToStamp.pl
mv out.txt output/subject$2/block$1/trial0/data.txt
mv log.txt output/subject$2/block$1/trial0/log.txt
mv "${root}/Research/temp/trace.txt" output/subject$2/block$1/trial0/trace.txt
if [ $3 != "auto" ]; then
	mv "${root}/Research/temp/Utilization_Each_Module.result" output/subject$2/block$1/module.txt
	mv "${root}/Research/temp/Utilization_Each_SubNetwork.result" output/subject$2/block$1/subnetwork.txt
	perl resultXMLtoCSV.pl output/subject$2/block$1/module.txt
	perl -pi -e "s/^\n//" output/subject$2/block$1/module.txt
	perl resultXMLtoCSV.pl output/subject$2/block$1/subnetwork.txt
	perl -pi -e "s/^\n//" output/subject$2/block$1/subnetwork.txt
fi
