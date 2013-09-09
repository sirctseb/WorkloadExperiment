#!/bin/bash
root=/Volumes/cjbest
# root=~/Google\ Drive
# root=~/Desktop/unison-transfer

# wait for trace file to exist
echo waiting for block $2, trial $1
if [ $4 != "auto" ]; then
	while [ ! -f "${root}/Research/temp/trace.txt" ] || [ ! -f "${root}/Research/temp/log.txt" ] || [ ! -f "${root}/Research/temp/Utilization_Each_Module.result" ] || [ ! -f "${root}/Research/temp/Utilization_Each_SubNetwork.result" ]
	do
		sleep 2
	done
else
	while [ ! -f "${root}/Research/temp/trace.txt" ] || [ ! -f "${root}/Research/temp/log.txt" ]
	do
		sleep 2
	done
fi

echo got block $2, trial $1, processing
./logToData.sh $1 $2 $3 $4