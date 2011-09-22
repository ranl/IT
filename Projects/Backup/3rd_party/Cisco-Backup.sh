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
# This script will backup the switch configuration via ftp
# 
## Cisco Configuration
# conf t
# username cisco_backup_user privilege 0 password 7 PASSWORD
# privilege exec level 0 copy startup-config ftp:
# ip ftp username cisco_backup_user
# ip ftp password 7 PASSWORD
# exit
#
# SCP Keyauth
# conf t
# (config)#ip scp server enable
# (config)#ip ssh pubkey-chain
# (conf-ssh-pubkey)#username pipi
# (conf-ssh-pubkey-user)#key-string
# (conf-ssh-pubkey-data)#key from id_rsa.pub
# (conf-ssh-pubkey-data)#exit

# Please note that the $Ftp_Dest directory content will be delete every scan !!!!!!!!!!

# Settings
SWITCHES="x.x.x.x y.y.y.y z.z.z.z switchname.fqdn"
User="cisco_backup_user"
Pass="password"
Backup_Server=`/sbin/ifconfig eth0 | grep "inet addr:" | awk '{print $2}'  | awk -F\: '{print $2}'`
Ftp_Dest=`grep ^$User /etc/passwd | awk -F\: '{print $6}'` # Please note that the $Ftp_Dest directory content will be delete every scan !!!!!!!!!!
BACKUPDIR="/path/to/backup/dir"
LOGALLOWED="14"
MAILTO="IT@company.com"

# Start Backup
ERRMSG=""
ERRSUM=0
DATESCRIPT=`date +%F_%H_%M_%S`

for switch in $SWITCHES
do
	ping -c 1 $switch &> /dev/null
	if [ $? == 0 ]
	then
		(sleep 2;echo $User; sleep 2;echo $Pass; sleep 2 ;echo "copy startup-config ftp:"; sleep 2;echo $Backup_Server; sleep 2;echo "${switch}_startup-config"; sleep 5;echo "exit") | telnet $switch
		if [ $? == 0 ]
		then
			ERRSUM=1
			if [ "$ERRMSG" == "" ]
			then
				ERRMSG="$switch"
			else
				ERRMSG="$ERRMSG, $switch"
			fi
		fi
	fi
done

# Zip'em all
cd "$Ftp_Dest"
tar jcf Cisco_Backup.tbz.${DATESCRIPT} *
mv Cisco_Backup.tbz.${DATESCRIPT} $BACKUPDIR/
if [ "`pwd`" == "$Ftp_Dest" ]
then
	rm -rf *
fi

# Notify if error
if [ $ERRSUM == 1 ]
then
	echo -en Switches with errors: $ERRMSG\\n\\nOld backups were not deleted\\n | /bin/mail -s "Cisco-Backup Error !" $MAILTO
	exit 1
fi

# Backup Rotation
LOGS=`ls $BACKUPDIR | wc -l`
if [ $LOGS -gt $LOGALLOWED ]
then
	logs_2_delete=`expr $LOGS - $LOGALLOWED`
	ls $BACKUPDIR -t | tail -n $logs_2_delete | while read bp2del
	do
		rm -f "${BACKUPDIR}/${bp2del}"
	done
fi
