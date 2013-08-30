#!/bin/bash

# usage: putAndRunAll.sh SUBJECT_NUM [auto, BLOCK_LIST="1 2 3 4 5 6 7 8 9 10"]

# for each block in BLOCK_LIST, putModel.sh is called with that block and SUBJECT_NUM
# then waitOnLog.sh is called with the block, SUBJECT_NUM, and the optional auto parameter
# after all of these, the convert_times.go script is run for SUBJECT_NUM
BLOCKS=${3:-1 2 3 4 5 6 7 8 9 10}

for block in $BLOCKS; do
	growlnotify -m "putting block $block"
	echo putting block $block;
	# write model file
	./putmodel.sh $block $1;
	# wait until log exists, then process and copy it to output
	./waitOnLog.sh $block $1 $2;
done

echo aggregating
growlnotify -m "ran all blocks, aggregating"
go run convert_times.go -s $1

growlnotify -m "totally done"