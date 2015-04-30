#!/usr/bin/python

import sys
import os
from xml.etree.ElementTree import iterparse #, dump # to dump xml nodes
from datetime import date, timedelta
import commands

days_to_subtract = 90
startdate = date.today()- timedelta(days=days_to_subtract)

cmd = 'svn -v -r {'+startdate.strftime('%Y-%m-%d')+'}":HEAD" --xml log > /tmp/changelog'

out = commands.getstatusoutput(cmd)

blacklist = ["cosmetic", "refresh", "inor change", "inor fix", "comments"]

iparse = iterparse('/tmp/changelog', ['start', 'end'])

for event, elem in iparse:
	if event == 'start' and elem.tag == 'log':
		logNode = elem
		break

logentries = (elem for event, elem in iparse if event == 'end' and elem.tag == 'logentry')

L = []
for logentry in logentries:
	L.append(logentry)

L.reverse()

for logentry in L:
	skip = 0
	for word in blacklist:
		if word in logentry.find('msg').text:
			skip = 1
			break
	
	if not skip:
		#dump(logentry) # to dump xml node
		dates = logentry.find('date').text.split('T')
		try:
			print "----------------------------------\nRevision r"+logentry.attrib['revision']+"\t"+dates[0]+" ("+logentry.find('author').text+")\n"+logentry.find('msg').text
		except UnicodeEncodeError:
			pass
	logNode.remove(logentry)

