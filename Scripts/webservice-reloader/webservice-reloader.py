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
import time
import signal
import sys
import logging
import os

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

def prepareOpts():
    parser = OptionParser()
    parser.add_option("-u", "--url", dest="url", type="string", help="url to check")
    parser.add_option("-g", "--grep", dest="grep", type="string", help="string to grep in the URL")
    parser.add_option("-c", "--cmd", dest="cmd", type="string", help="command to execute on failure")
    parser.add_option("-t", "--timeout", dest="timeout", type="float", help="how many seconds to wait for each http request", default=5)
    parser.add_option("-r", "--retries", dest="retries", type="int", help="how many time to try before failing", default=5)
    parser.add_option("-s", "--sleep", dest="sleep", type="int", help="number of seconds to wait between each iteration", default=60)
    parser.add_option("-d", "--disable", dest="disable", type="int", help="number of iteration to wait after command execution", default=5)
    parser.add_option("-l", "--log", dest="log", type="string", help="email to send notification on command execution", default=None)
    (opts, args) = parser.parse_args()
    if opts.url is None or opts.cmd is None:
        parser.print_help()
        print __doc__
        exit(1)
    return opts

def wget():
    log.debug('issuing http requests:')
    out = None
    for i in range(1, opts.retries+1):
        log.debug('issuing http request: {0}'.format(i))
        try:
            out = urllib2.urlopen(opts.url,timeout=opts.timeout).read().splitlines()
        except:
            out = None
            time.sleep(2)
        else:
            log.debug('http request succeeded')
            break
    return out

def grep():
    if opts.grep == None:
        if out != None:
            log.debug('no need to grep -> exit')
            return True
    else:
        if out != None:
            log.debug('grepping ...')
            for row in out:
                if opts.grep in row:
                    log.debug('found {0} in {1}'.format(opts.grep, row))
                    return True
    return False

def signal_handler(signal, frame):
    log.debug('Captured SIGINT, exiting ...')
    sys.exit(0)

def getlogger(logfile=None):
    name = os.path.basename(sys.argv[0])
    if logfile:
        logging.basicConfig(datefmt='%d-%m-%Y %I:%M:%S',
                            format='%(asctime)s %(levelname)s: %(message)s',
                            level=logging.DEBUG,
                            filename=logfile,
                            )
    else:
        logging.basicConfig(datefmt='%d-%m-%Y %I:%M:%S',
                            format='%(asctime)s %(levelname)s: %(message)s',
                            level=logging.DEBUG,
                            )
    return logging.getLogger(name)   

# Main
aftercmd = 0
signal.signal(signal.SIGINT, signal_handler)
opts = prepareOpts()
log = getlogger(opts.log)

while True:
    if aftercmd == 0:
        out = wget()
        if grep():
            log.debug('looks good -> doing nothing ...')
        else:
            log.debug('could not grep {0}'.format(opts.grep))
            log.debug('executing cmd: {0}'.format(opts.cmd))
            cmdres = myShell(opts.cmd)
            log.debug(cmdres)
            ex = cmdres['exit']
            aftercmd = opts.disable
    else:
        log.debug('command was exceuted before iteration, waiting {0} iterations'.format(aftercmd))
        aftercmd-=1
    time.sleep(opts.sleep)

exit(0)
