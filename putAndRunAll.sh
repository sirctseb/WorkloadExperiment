#!/bin/bash
BLOCKS=${3:-1 2 3 4 5 6 7 8 9 10 11 12 13 14}
TRIALS=${4:-480}

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
go run convert_times.go -s $1 -i $TRIALS

growlnotify -m "totally done"