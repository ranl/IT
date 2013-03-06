#!/usr/bin/env python

import argparse
import subprocess
import re
import json

# Functions
def myShell(cmd):
    """
    will execute the cmd in a Shell and will return the hash res
    res['out'] -> array of the stdout (bylines)
    res['err'] -> same as above only stderr
    res['exit'] -> the exit code of the command
    """

    res = {}
    proc = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, stdin=None)
    tmp = proc.communicate()
    res['out'] = tmp[0].splitlines()
    res['err'] = tmp[1].splitlines()
    res['exit'] = proc.returncode
    return res


# Parser
parser = argparse.ArgumentParser(description="return vim JMX a property of the specified queue")
parser.add_argument("srv", type=str, help="hostname or ip of the ActiveMQ server")
parser.add_argument("queue", type=str, help="full queue name")
parser.add_argument("prop", type=str, help="property name")
args = parser.parse_args()

# Settings
activemq = "/opt/activemq/latest/bin/activemq-admin"
port = "1099"
cmd = "timeout 10 "+activemq+" query --jmxurl service:jmx:rmi:///jndi/rmi://"+args.srv+":"+port+"/jmxrmi -QQueue="+args.queue+" --view "+args.prop

# Start script
output = myShell(cmd)
if output['exit'] != 0:
	print 0
	exit(1)

res = 0
str2search = '^'+args.prop+' = '
for line in output['out']:
	if re.search(str2search, line):
		res = line.split(" = ")[1]
		break

print res
