#!python
import re;
from datetime import datetime;
import time;

# open file
f = open('output/subject1/trial1/data.txt', 'r')

# get contents
contents = f.read()

# find trial start
stamp_string = re.search('TrialStart (\d{13})', contents).group(1)

# get a float of epoch time in seconds. have to divide by 1000 because dart timestamps are in ms
stamp = float(stamp_string) / 1000

# build a datetime object from the stamp
start_date = datetime.fromtimestamp(float(stamp_string)/1000)

print(start_date)