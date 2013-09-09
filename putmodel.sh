#!/bin/bash

# usage: putmodel.sh TRIAL_NUMBER BLOCK_NUMBER SUBJECT_NUMBER

# copies the model file for the given subject and block to Research/temp in the root directory below

root=/Volumes/cjbest
# root=~/Google\ Drive
# root=~/Desktop/unision-transfer
cp output/subject$3/block$2/trial$1/QN_ACTR_Model_Initialization.txt "${root}/Research/temp"
