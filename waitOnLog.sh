#!/bin/bash
root=/Volumes/home
# root=~/Google\ Drive
# root=~/Desktop/unison-transfer

# wait for trace file to exist
echo waiting for block $1
if [ $3 != "auto" ]; then
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

echo got block $1, processing
./logToData.sh $1 $2 $3