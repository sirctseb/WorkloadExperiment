#!/bin/bash
./logToData.sh $1 $2
go run convert_times.go -s $2 -i 240
