#!python
import re;
from datetime import datetime;
import time;

def datetimefromstring(stamp_string):

	# get a float of epoch time in seconds. have to divide by 1000 because dart timestamps are in ms
	stamp = float(stamp_string) / 1000

	# build a datetime object from the stamp
	return datetime.fromtimestamp(stamp)
def replaceMatch(match):
	return str(datetimefromstring(match.group(0)))

# open file
f = open('output/subject1/trial1/data.txt', 'r')

# get contents
contents = f.read()

# find trial start
stamp_string = re.search('TrialStart (\d{13})', contents).group(1)

print(re.subn("\d{13}", replaceMatch, contents))
#print(datetimefromstring(stamp_string))