#!/bin/bash

# Info:
# 
# This script is used to query win2003 dhcp server reserved ips

idfile='/root/.ssh/id_rsa_administrator'
winssh='administrator@sshproxy'
dhcpserver='x.x.x.x'
tmpfile=/tmp/$RANDOM
tmpreserve=/tmp/$RANDOM

function dump_reserve() {
	ssh -i $idfile $winssh "cmd /c \"netsh dhcp server $dhcpserver dump\""|grep reservedip | tr A-Z a-z | awk '{print $8" "$9" "$10}' | sed -e 's/\"//g' -e 's/\.altair$//g' -e 's/\.$//g' > $tmpreserve 2> /dev/null
}

dialog --title "Please Wait..." --infobox "\ngetting reservedip info\n$winssh -> $tmpreserve" 6 50 ; dump_reserve ;

while [ 0 ]
do
	dialog --backtitle "DHCP Server Menu" --nocancel --menu "DHCP Server Menu:" 10 50 5 \
	1 "List Reserved Ip" \
	2 "Search by MAC Address" \
	3 "Search by Hostname" \
	9 "Exit" 2> $tmpfile
	ans=$(cat $tmpfile)
	case "$ans" in
		1) # List Reserved Ip
			dialog --textbox $tmpreserve 22 70
		;;
		2) # Search by MAC Address
			dialog --inputbox "Enter MAC Address:" 8 50 2>$tmpfile
			mac=$(cat $tmpfile)
			mac=`echo $mac | tr A-Z a-z | sed 's/\(:\|-\)//g'`
			grep $mac $tmpreserve > $tmpfile
			dialog --textbox $tmpfile 22 70
		;;
		3) # Search by Hostname
			dialog --inputbox "Enter hostname:" 8 50 2>$tmpfile
			host=$(cat $tmpfile)
			host=`echo $host | tr A-Z a-z`
			grep $host $tmpreserve | sort -k 3 > $tmpfile
			dialog --textbox $tmpfile 22 70
		;;
		*) # Exit
			echo "Exiting..."
			break
		;;
	esac
done


# Cleanup
rm -f $tmpreserve $tmpfile &> /dev/null
