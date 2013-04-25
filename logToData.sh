#!/bin/bash
mv ~/Google\ Drive/Research/temp/log.txt .
perl clockToStamp.pl
mv out.txt output/subject21/block$1/trial0/data.txt
mv log.txt output/subject21/block$1/trial0/log.txt
mv ~/Google\ Drive/Research/temp/trace.txt output/subject21/block$1/trial0/trace.txt

