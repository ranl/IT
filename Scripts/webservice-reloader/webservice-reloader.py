#!/usr/bin/env python

'''
Description:
This script will use a url to determine the the server is available via http request to a url
if the url is not available -> it will issue the command cmd
'''

# Python Libs
from optparse import OptionParser
import urllib2
import subprocess
import pprint
import time
import signal
import sys

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

def echo(str):
    if opts.verbose:
        print str

def prepareOpts():
    parser = OptionParser()
    parser.add_option("-u", "--url", dest="url", type="string", help="url to check")
    parser.add_option("-g", "--grep", dest="grep", type="string", help="string to grep in the URL")
    parser.add_option("-c", "--cmd", dest="cmd", type="string", help="command to execute on failure")
    parser.add_option("-t", "--timeout", dest="timeout", type="int", help="how many seconds to wait for each http request", default=5)
    parser.add_option("-r", "--retries", dest="retries", type="int", help="how many time to try before failing", default=5)
    parser.add_option("-s", "--sleep", dest="sleep", type="int", help="number of seconds to wait between each iteration", default=300)
    parser.add_option("-v", "--verbose", action="store_true", dest="verbose", help="verbose")
    (opts, args) = parser.parse_args()
    if opts.url is None or opts.cmd is None:
        parser.print_help()
        print __doc__
        exit(1)
    return opts

def wget():
    echo('issuing http requests:')
    out = None
    for i in range(1, opts.retries):
        echo('issuing http request: {0}'.format(i))
        try:
            out = urllib2.urlopen(opts.url,timeout=opts.timeout).read().splitlines()
        except:
            out = None
            time.sleep(2)
        else:
            echo('http request succeeded')
            break
    return out

def grep():
    if opts.grep == None:
        if out != None:
            echo('no need to grep -> exit')
            return True
    else:
        if out != None:
            echo('grepping ...')
            for row in out:
                if opts.grep in row:
                    echo('found {0} in {1}'.format(opts.grep, row))
                    return True
    return False

def signal_handler(signal, frame):
    echo('Captured SIGINT, exiting ...')
    sys.exit(0)

# Main
signal.signal(signal.SIGINT, signal_handler)
opts = prepareOpts()
echo('Verbose is on')

while True:
    out = wget()
    if grep():
        echo('looks good -> doing nothing ...')
    else:
        echo('could not grep {0}'.format(opts.grep))
        echo('executing cmd: {0}'.format(opts.cmd))
        cmdres = myShell(opts.cmd)
        if opts.verbose:
            pp = pprint.PrettyPrinter(indent=4)
            pp.pprint(cmdres)
        ex = cmdres['exit']
    time.sleep(opts.sleep)

exit(0)
