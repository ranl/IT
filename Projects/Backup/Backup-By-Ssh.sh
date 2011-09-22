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

# Info:
#
# The Main script of the ssh-backup environment
# should be used from cron

# Stuff to repair
# create tar on the backup server directly

# Settings
REMOTEHOST=$1
LOGALLOWED=$2
mailprog='/bin/mail'
script_shell='/bin/bash'
BACKUPSOURCE=/path/to/Backup/directory
BP_SCRIPTSPATH=/path/to/scripts/directory
LOCALDIR=/tmp/backup-from-`hostname` # directory to be created on the remote host to store backup files (for example mysqldump files..)
MAILTO="IT@company.com"
COMMON_FILES="/etc /var/log/messages /root /var/spool/cron /var/www $LOCALDIR"
COMMON_EXCLUDE="/etc/selinux /etc/gconf"
SYSLOG_LOCAL="local5"
SYSLOG_TAG="sshbb"

function FError()
{
	echo "Syntax !"
	echo "$0 [server name to backup from] [how many copies to save]"
	exit 1
}

function FScp
{
	scp $REMOTEHOST:$REMOTEBACKUP $BACKUPDIR/`basename $REMOTEBACKUP`.$DATESCRIPT
}

function FBackRotate
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

# Verifying Syntax
if [ $# != 3 ]
then
	FError
fi

var_dir=$BP_SCRIPTSPATH/var
HOST_SCRIPTPATH=$BP_SCRIPTSPATH/scripts/$REMOTEHOST
BACKUPDIR=${BACKUPSOURCE}/${REMOTEHOST}
REMOTEBACKUP=/tmp/$REMOTEHOST.tbz
DATESCRIPT=`date +%F_%H_%M_%S`
REMOTELOG=/tmp/${REMOTEHOST}_ssh_backup_log.$DATESCRIPT


# Checking Directory Backup Exists
if [ ! -d $BACKUPDIR ]
then
	echo "The Destination Backup Directory $BACKUPDIR Does not exists, pls create one"
	exit 1
fi

# Checking Connection
ping $REMOTEHOST -c 2 &> /dev/null
if [ $? != 0 ]
then
	echo "$REMOTEHOST is down..."
	echo "Can't complete backup operation..."
	echo "Exiting 1"
	echo "$REMOTEHOST is down" | $mailprog -s "$REMOTEHOST Backup Problem at $DATESCRIPT !!!" $MAILTO
	exit 1
fi

# Creating Script File
SCRIPTPATH="$var_dir/${REMOTEHOST}"
echo $script_shell > "${SCRIPTPATH}"
for i in REMOTEHOST REMOTEBACKUP DATESCRIPT REMOTELOG LOCALDIR COMMON_FILES COMMON_EXCLUDE
do
	set | grep ^${i}= >> "${SCRIPTPATH}"
done
cat "$BP_SCRIPTSPATH/header" >> "${SCRIPTPATH}"
if [ -f "$HOST_SCRIPTPATH" ]
then
	cat "$HOST_SCRIPTPATH" >> "${SCRIPTPATH}"
fi
cat "$BP_SCRIPTSPATH/footer" >> "${SCRIPTPATH}"


# Creating Tar File
ssh $REMOTEHOST "$SCRIPTPATH"

# Scp the Tar file / Notify Status by Mail
if [ $? == 0 ]
then
	FScp
	FBackRotate
	logger -p $SYSLOG_LOCAL.info -t $SYSLOG_TAG "$REMOTEHOST Backup has Completed Succesfully at $DATESCRIPT, Log is located in $REMOTEHOST:$REMOTELOG"
else
	FScp
	FBackRotate
	logger -p $SYSLOG_LOCAL.crit -t $SYSLOG_TAG "$REMOTEHOST Backup Problem at $DATESCRIPT !!!, Log is located in $REMOTEHOST:$REMOTELOG"
	echo "$REMOTEHOST script is located at $SCRIPTPATH" | $mailprog -s "$REMOTEHOST Backup Problem at $DATESCRIPT !!!" $MAILTO
fi

# Deleting Generated Script
[ if "$SCRIPTPATH" ] && rm -f "$SCRIPTPATH"

# Exiting
exit
