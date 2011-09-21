#!/usr/bin/env perl

# Info
# Send SMS via G$ device (used to monitor UPS)

use strict;

sub FSyntaxError {
	print "Syntax Error !\n";
	print "$0 [phone #] [text message]\n";
	print "Example:\n$0 '+97250000000' 'Hello There ...'\n";
	exit(1);
}

if($#ARGV != 1) {
	FSyntaxError;
}

my $URL = "http://g4/sendsms";
my $User = "admin";
my $Pass = "admin";
my $Number = @ARGV[0];
my $Message = @ARGV[1];

$Number =~ s/(.|\n)/sprintf("%%%02lx", ord $1)/eg;
$Message =~ s/(.|\n)/sprintf("%%%02lx", ord $1)/eg;

system("wget $URL --user=$User --password=$Pass --post-data 'number=$Number&text=$Message&action=submit' -q -O /dev/null");
