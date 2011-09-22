#!/bin/bash

# INFO
# Script to backup paloalto device
# will be used from the localfilesystem for security reasons
# user needs to be superadmin
#
# https://${HOST1}/esp/restapi.esp?type=keygen&user=${USER}&password=${PW} --> for generating a key

## User Settings
key=''
host=''
keep=30
tempdir='/tmp'
MAILTO='IT@company.com'
backupdir='/path/to/backup/dir'
mailcmd="/bin/mail -s PaloAlto_backup_error $MAILTO"

## Functions
function ExitHandler()
{
	case $1 in
		"changedir")
			echo -en "Cant change to $backupdir\nexiting...\n" | $mailcmd
			exit 1
		;;
		"bperr")
			echo -en "Cant backup ${host}\nexiting...\n" | $mailcmd
			exit 1
		;;
	esac
}

DATESCRIPT=`date +%F_%H_%M_%S`

## Backup Process
cd "$tempdir"
curl --output ${host}.xml --insecure https://${host}/esp/restapi.esp\?type=config\&action=show\&key=${key} &> /dev/null
error=$?

## Validate Backup
if [ $error == 0 ]
then
	cd "$backupdir"
	if [ "`pwd`" != "$backupdir" ]
	then
		ExitHandler changedir
	fi
	
	mv "$tempdir/${host}.xml" ${host}_${DATESCRIPT}.xml
	chmod 700 *

	
	# Backup Rotation
	LOGS=`ls $backupdir | wc -l`
	if [ $LOGS -gt $keep ]
	then
		logs_2_delete=`expr $LOGS - $keep`
		ls $backupdir -t | tail -n $logs_2_delete | while read bp2del
		do
			rm -f "$backupdir/${bp2del}"
		done
	fi
else
	ExitHandler bperr
fi
