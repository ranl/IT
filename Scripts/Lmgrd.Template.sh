#!/bin/bash
#
#            RUNLEVEL START STOP
# chkconfig: 345 90 20
# description: Lmgrd Start/Stop daemon
#
# Info:
# Init script for lmgrd license daemons with assist to view the status of the log file
#
# Install Instructions:
# Put the license file in $LICDIR/$NAME.lic where name is the name of the vendor (matlab, cadence, etc...)
# Dos2unix the licens file
# configure the LOGDIR directory
# configure the path to the multitail binary via the multitail variable
# Copy this script to /etc/init.t/Lmgrd.`vendor` (`vendor` = license file name without .lic)
# Notice Lo/Uppercase ....
# Change the run level and startup order in the chkconfig statment on the 3rd line (Should run after nfs+autofs+ypbind)
# chkconfig --add Lmgrd.`vendor`
# Verify Configuration: chkconfig --list Lmgrd.`vendor`

#################################
# Don't modify This Script !!!! #
#################################

###################
### Environment ###
###################

multitail=""
LICDIR=""
LOGDIR=""

NAME=`basename $0 | awk -F\. '{print $2}'`
LMGRDBIN="`which lmgrd`"
LMUTIL="`which lmutil`"
LMDOWN="$LMUTIL lmdown"
LICFILE="$LICDIR/$NAME.lic"
LOGFILE="$LOGDIR/$NAME.log"
LMGRDUSER='flexlm'
LMGRDPORT=`grep ^SERVER\ \`hostname\` ${LICFILE} | awk '{print $4}'`
LMCMDUP="$LMGRDBIN -c $LICFILE -l $LOGFILE"
LMCMDDOWN="$LMDOWN -c $LICFILE -q"
TAILSTRING="`which $multitail` $LOGFILE -r 1 -l \"date && ps -ef | grep ^"${LMGRDUSER}" | grep "\'$LMCMDUP\'"\" -rc 1 -l \"date && netstat -ntl | grep :"$LMGRDPORT"\""
LMGRDPID=`ps -ef | grep ^${LMGRDUSER} | grep "$LMCMDUP" | awk '{print $2}'`
ISBOUND=`netstat -nlp | grep :${LMGRDPORT} &> /dev/null ; echo $?`
ISPROC=`if [ -z "$LMGRDPID" ] ; then echo 1 ; else echo 0 ; fi`

#################
### Functions ###
#################
function FError()
{
case $1 in
	"syntax" )
		echo "usage: $0 { start | stop | status }"
		Tail_Cmd
		exit 1
	;;
	"file" )
		echo "ERROR: $2 Does not exists !"
		exit 1
	;;
	"exitstatup" )
		echo "ERROR: $NAME exited with status $ERR"
		echo "Command: su - $LMGRDUSER -c \"$LMCMDUP\""
		exit $ERR
	;;
	"exitstatdown" )
		echo "ERROR: $NAME exited with status $ERR"
		echo "Command: su - $LMGRDUSER -c \"$LMCMDDOWN\""
		exit $ERR
	;;
	"up" )
		echo "$NAME is not running !"
		if [ $ISBOUND == 0 ]
		then
			echo "$NAME is bound to Port = $LMGRDPORT but the process is not running"
			echo "Try in a couple of minutes ..."
		fi
		exit 1
	;;
	* )
		echo "Function FError error"
		exit 1
	;;
esac
}

function Tail_Cmd()
{
	echo ""
	echo "Can B Usefull ..."
	echo "$TAILSTRING"
}

#######################
### Starting Script ###
#######################
case $1 in 
	'start')
		if [ -x $LMGRDBIN ]
		then
			if [ -f "$LICFILE" ]
			then
				if [ -f "$LOGFILE" ]
				then
					su - $LMGRDUSER -c "rm -rf $LOGFILE"
				fi
				su - $LMGRDUSER -c "$LMCMDUP"
				ERR=$?
				if [ $ERR == 0 ]
				then
					echo "$NAME is up with exit status $ERR"
					Tail_Cmd
					exit $ERR
				else
					FError exitstatup
				fi
			else
				FError file $LICFILE
			fi
		else
			FError file $LMGRDBIN
		fi
        ;;
	'stop')
		if [ -n "$LMGRDPID" ]
		then
			if [ -x "$LMUTIL" ]
			then
				if [ -f "$LICFILE" ]
				then
					su - $LMGRDUSER -c "$LMCMDDOWN"
					ERR=$?
					if [ $ERR == 0 ]
					then
						echo "$NAME is down with exit status $ERR"
						Tail_Cmd
						exit $ERR
					else
						FError exitstatdown
					fi
				else
					FError file
				fi
			else
				FError file
			fi
		else
			FError up
		fi
        ;;
	'status')
		if [ $ISBOUND == 0 ]
		then
			echo "$NAME is bound to Port = $LMGRDPORT"
			if [ $ISPROC == 0 ]
			then
				echo "$NAME is up Pid = $LMGRDPID"
			else
				echo "$NAME is DOWN Pid = $LMGRDPID !"
			fi
			ERR=`expr $ISBOUND + $ISPROC`
			exit $ERR
		else
			echo "$NAME is NOT bound to Port = $LMGRDPORT !"
			if [ $ISPROC == 0 ]
			then
				echo "$NAME is up Pid = $LMGRDPID"
			else
				echo "$NAME is DOWN !"
			fi
			ERR=`expr $ISBOUND + $ISPROC`
			exit $ERR
		fi
	;;
	*)
		FError syntax
        ;;
esac
