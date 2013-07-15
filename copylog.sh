#!/bin/bash
cp ~/Google\ Drive/Research/temp/log.txt log.txt
perl clockToStamp.pl
cp out.txt output/subject9/block0/trial0/data.txt
cp out.txt ~/Google\ Drive/Research/temp/data.txt