#!/usr/bin/env perl

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
# Send an mail the printers paper count via snmp

use strict;
use Net::SNMP;


my $sendmail = "/usr/sbin/sendmail -t";
my $reply_to = "Reply-to: IT\@gmail.com";
my $subject = "Subject: Printer Counters";
my $send_to = 'To: blabla@blabla.com';
my $send_to_cc = 'Cc: yadayada@ggg.com';

my %oid = (
  "desc" => ".1.3.6.1.2.1.25.3.2.1.3.1",
  "hp" => ".1.3.6.1.2.1.43.10.2.1.4.1.1",
  "xerox" => ".1.3.6.1.4.1.253.8.53.13.2.1.6.1.20.1",
);

# Multidimentional array [printer-dns-name,snmp-community]
my @config =(	["x.x.x.x","public"],
		["y.y.y.y","public"],
	);

open(SENDMAIL, "|$sendmail") or die "Cannot open $sendmail: $!";
print SENDMAIL $reply_to,"\n";
print SENDMAIL $subject,"\n";
print SENDMAIL $send_to,"\n";
print SENDMAIL $send_to_cc,"\n";
print SENDMAIL "Content-type: text/plain\n\n";
print SENDMAIL "*--- Printer Counters ---*\n\n";
foreach my $row_arr (@config){
	my $snmp_sess = _create_session(@$row_arr[0],@$row_arr[1]);
	my $desc = _get_oid_value($snmp_sess,$oid{'desc'});
	my $counter;
	if($desc =~ /hp/i) {
		$counter = _get_oid_value($snmp_sess,$oid{'hp'});
	} elsif($desc =~ /xerox/i) {
		$counter = _get_oid_value($snmp_sess,$oid{'xerox'});
	}
	print SENDMAIL "$desc :  $counter\n\n";
	$snmp_sess->close;
}
print SENDMAIL "\n\nIf somethings seemed to be not right please contact IT\@gmail.com";
close(SENDMAIL); 
