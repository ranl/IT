#!/usr/bin/env python

import argparse
import subprocess
import re

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
parser = argparse.ArgumentParser(description="check if the clientid is configured as a subscriber on the queue")
parser.add_argument("srv", type=str, help="hostname or ip of the ActiveMQ server")
parser.add_argument("queue", type=str, help="the name of the queue")
parser.add_argument("client", type=str, help="clientid to grep")
args = parser.parse_args()

# Settings
activemq = "/opt/activemq/latest/bin/activemq-admin"
port = "1099"
cmd = "timeout 10 "+activemq+" query --jmxurl service:jmx:rmi:///jndi/rmi://"+args.srv+":"+port+"/jmxrmi -QQueue="+args.queue+" --view Subscriptions"

# Start script
output = myShell(cmd)
if output['exit'] != 0:
	print 0
	exit(1)

found = False
for line in output['out']:
	if re.search('^Subscriptions', line) and re.search('clientId='+args.client+'-', line):
		found = True
		break

if found:
	print 1
else:
	print 0

