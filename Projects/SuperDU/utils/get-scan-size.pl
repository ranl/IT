#!/usr/bin/perl

# Info:
#
# Get scan size from _settings tables
#
# Output
# x >= 0 the scan existed in the tables and the output is its size in KB
# x == -1 the scan doesnt existed in the tables (wront output or a new scan)


use strict;
use DBI;
use DBD::mysql;
use File::Basename;
BEGIN {
  my $path2du = dirname($0);
  unshift(@INC,"$path2du/../conf");
}
use sdu qw(%mysql_settings);

## User Input
################
sub FSyntaxError($) {
	my $err = shift;
	print <<EOU;
     $err

     * Get scan size from _settings tables
     $0 [scan name]
     
     output explained
     x >= 0 the scan existed in the tables and the output is its size in KB
     x == -1 the scan doesnt existed in the tables (wront output or a new scan)
     
EOU
	exit(1);
}

if($#ARGV != 0) {
	FSyntaxError("Syntax error !");
}

my $scaname = "$ARGV[0]";

## Start Script
##################
my $connect = DBI->connect("dbi:mysql:$mysql_settings{'db'}:$mysql_settings{'server'}:$mysql_settings{'port'}", $mysql_settings{'user'}, $mysql_settings{'pw'}) or die "Cant connect to mysql server\n";
my $sth = $connect->prepare("SELECT size FROM $mysql_settings{'db'}._settings WHERE name='$scaname' LIMIT 0,1");
$sth->execute;

if($sth->rows == 0) {
	print "-1";
} else {
	while (my $ref = $sth->fetchrow_hashref()) {
		print $ref->{'size'};	
	}
	$sth->finish();
}

exit(0);
