#!/bin/sh
#
# Service Reloader
#
# chkconfig: 345 CHKCONFIG-START CHKCONFIG-STOP
#
# Description:
# This script will use a url to determine the the server is available via http request to a url
# if the url is not available -> it will issue the command cmd
# the webservice-reloader.py file should be in the system's path


# General Settings
. /etc/rc.d/init.d/functions
export DAEMON="$(basename $0)"
export PIDFILE=/var/run/$DAEMON.pid
export lockfile="/var/lock/subsys/$DAEMON"
log=/dev/null
source /etc/sysconfig/$DAEMON &> /dev/null
[ -z "$URL" ] && {
  echo -n $"Missing URL variable in /etc/sysconfig/$DAEMON"
	failure
	echo
	exit 1
}

# Defaults
[ -z "$CMD" ] && CMD=true
[ -z "$TIMEOUT" ] && TIMEOUT=5
[ -z "$RETRIES" ] && RETRIES=5
[ -z "$SLEEP" ] && SLEEP=60
[ -z "$DISABLE" ] && DISABLE=5
[ -z "$DEBUG" ] && log=/var/log/$DAEMON


# Functions
function _start()
{
	echo -n $"Starting $DAEMON: "
	status -p $PIDFILE $lockfile &> /dev/null
	if [ $? == 0 ]
	then
		echo -n "is already up ..."
		success
		echo
		exit 0
	else
		python -u /usr/bin/webservice-reloader.py -u "$URL" -g "$GREP" -c "$CMD" -t "$TIMEOUT" -r "$RETRIES" -s "$SLEEP" -d "$DISABLE" &> "${log}" &
    echo $! > $PIDFILE
    sleep 2
		ps -p $(cat $PIDFILE 2> /dev/null) &> /dev/null
		if [ $? == 0 ]
		then
			touch $lockfile
			success
			echo
			exit 0
		else
			rm -f $PIDFILE &> /dev/null
			failure
			echo
			exit 1
		fi
	fi
}

function _stop()
{
	echo -n $"Stopping $DAEMON: "
	status -p $PIDFILE $lockfile &> /dev/null
	if [ $? != 3 ]
	then
		kill -9 $(cat $PIDFILE 2> /dev/null)
		if [ $? == 0 ]
		then
			rm -f $PIDFILE $lockfile
			success
			echo
			exit 0
		else
			failure
			echo
			exit 1
		fi
	else
		echo -n "is already down ..."
		success
		echo
		exit 0
	fi
}

function _status()
{
	status -p $PIDFILE $lockfile
        exit $?
}

function _condrestart()
{
       [ -e $lockfile ] && $0 restart
}

function _usage()
{
        echo "Usage: $0 {start|stop|restart|condrestart|status}"
        exit 1
}

# Case
case "$1" in
  start)
	_start
	;;
  stop)
	_stop
	;;
  restart)
        $0 stop
        $0 start
        exit $?
	;;
  condrestart)
	;;
  status)
	_status
	;;
  *)
	_usage
	;;
esac
