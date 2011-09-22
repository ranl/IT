#!/bin/bash

#####################################
#####################################
### ______               _     =) ###
### | ___ \             | |       ###
### | |_/ / __ _  _ __  | |       ###
### |    / / _` || '_ \ | |       ###
### | |\ \| (_| || | | || |____   ###
### \_| \_|\__,_||_| |_|\_____/   ###
#####################################
#####################################

# Info
#
# Script to backup fortigate FW
#
# Configuration needed to be done at the fortigate device
# http://kc.fortinet.com/default.asp?id=2002&Lang=1&SID=

# Settings

Fortigate_Ip="192.168.0.1"
BACKUPDIR="/path/to/backup/dir"
MAILTO="IT@company.com"

function FError()
{
	echo "Syntax Error !"
	echo "$0 [logs to keep]"
	exit 1
}

function FScp()
{
	scp root@$Fortigate_Ip:sys_config ${BACKUPDIR}/sys_config.${DATESCRIPT}
}

function FBackRotate()
{
	LOGS=`ls $BACKUPDIR | wc -l`
	if [ $LOGS -gt $LOGALLOWED ]
	then
		logs_2_delete=`expr $LOGS - $LOGALLOWED`
		ls $BACKUPDIR -t | tail -n $logs_2_delete | while read bp2del
		do
			rm -f "${BACKUPDIR}/${bp2del}"
		done
	fi
}

if [ $# != 1 ]
then
	FError
fi

DATESCRIPT=`date +%F_%H_%M_%S`
ERR=0
LOGALLOWED="$1"


# Checking Connection
ping -c 1 $Fortigate_Ip &> /dev/null
if [ $? != 0 ]
then
	echo "$Fortigate_Ip is down..."
	echo "Can't complete backup operation..."
	echo "Exiting 1"
	echo "$Fortigate_Ip is down" | /bin/mail -s "$Fortigate_Ip Backup Problem at $DATESCRIPT !!!" $MAILTO
	exit 1
fi

# Scp
FScp
if [ $? == 0 ]
then
	FBackRotate
	logger -p local5.info "$Fortigate_Ip Backup has Completed Succesfully at $DATESCRIPT"
else
	logger -p local5.crit "$Fortigate_Ip Backup Problem at $DATESCRIPT !!!"
	echo "Err" | /bin/mail -s "$Fortigate_Ip Backup Problem at $DATESCRIPT !!!" $MAILTO
fi

