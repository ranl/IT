#!/usr/bin/perl

# Info:
#
# calculate the qtree from the filer via rsh
# 
# Configuration
# rsh access from this server
# each qtree needs to have a quota defenition in the filer
# - Even with no limit
#
# Exit status
# 0 - scan
# 1 - do not scan
# 2 - configuration is wrong

use strict;
use File::Basename;
use Getopt::Long; Getopt::Long::Configure('bundling');
my $path2utils = dirname($0);

## User Input
################
sub FSyntaxError($) {
	my $err = shift;
	print <<EOU;
     $err

     * check if a specific qtree in a netapp volume is larger then the size of the scan
     Syntax:
	 -H = Ip/Dns Name of the filer
	 -S = Scan name
         -V = volume name
         -Q = qtree name
         -D = diff in kb
         --verbose
               Will print information, only use for debugging
EOU
	exit(2);
}

my %opt;
my $result = GetOptions(\%opt,
	'host|H=s',
	'vol|V=s',
	'qtree|Q=s',
	'scan|S=s',
	'diff|D=s',
	'verbose|v',
);

FSyntaxError("Missing -H")  unless defined $opt{'host'};
FSyntaxError("Missing -V")  unless defined $opt{'vol'};
FSyntaxError("Missing -Q")  unless defined $opt{'qtree'};
FSyntaxError("Missing -S")  unless defined $opt{'scan'};
FSyntaxError("Missing -D")  unless defined $opt{'diff'};
my $scan_size = `$path2utils/get-scan-size.pl $opt{'scan'}`; chomp($scan_size);

sub _verbose(@) {
	my $msg = shift;
	if ($opt{'verbose'}) {
		print $msg;
	}
}

## Start Script
##################

if($scan_size == -1) {
	_verbose("there is no rows in the _settings table, assuming 1st scan -> ok\n");
	exit(0);
} else {
	my $quota_size = "none";
	my @rsh = split("\n",`rsh $opt{'host'} quota report 2> /dev/null | grep ^tree`);
	foreach(@rsh) {
		my @line = split(" ",$_);
		if($line[2] eq $opt{'vol'} and $line[3] eq $opt{'qtree'}) {
			$quota_size = $line[4];
		}
	}

	if($quota_size == "none") {
		_verbose("no quota report found for /$opt{'vol'}/$opt{'qtree'} on filer $opt{'host'} -> config problem\n");
		exit(2);
	}

	my $diff = abs($scan_size - $quota_size);
	if($diff > $opt{'diff'}) {
		_verbose("diff has passed |$scan_size - $quota_size| = $diff gt $opt{'diff'} -> ok\n");
		exit(0);
	} else {
		_verbose("diff has not passed |$scan_size - $quota_size| = $diff !> $opt{'diff'} -> wont scan\n");
		exit(1);
	}
}

