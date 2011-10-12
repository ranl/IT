#!/usr/bin/perl

# Info:
#
# calculate the df from the filer via rsh
# 
# Configuration
# rsh access from this server
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
	'scan|S=s',
	'diff|D=s',
	'verbose|v',
);

FSyntaxError("Missing -H")  unless defined $opt{'host'};
FSyntaxError("Missing -V")  unless defined $opt{'vol'};
FSyntaxError("Missing -S")  unless defined $opt{'scan'};
FSyntaxError("Missing -D")  unless defined $opt{'diff'};
my $scan_size = `$path2utils/get-scan-size.pl $opt{'scan'}`; chomp($scan_size);

if($opt{'vol'} !~ /\/$/) {
	$opt{'vol'} = "$opt{'vol'}/";
}

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
	my $size = "none";
	my @rsh = split("\n",`rsh $opt{'host'} df -k 2> /dev/null | sed '1d' | grep -v \.snapshot | grep ^$opt{'vol'}\ `);
	if($#rsh > 0) {
		_verbose("couldnt determine the size of the volume, more than one entry returned -> config problem\n");
		exit(2);
	} elsif($#rsh == -1) {
		_verbose("couldnt find the size of the volume, no entries returned -> config problem\n");
		exit(2);
	} else {
		my @tmparr = split(" ",$rsh[0]);
		$size = $tmparr[2];
		$size =~ s/KB//g;
	}

	my $diff = abs($scan_size - $size);
	if($diff > $opt{'diff'}) {
		_verbose("diff has passed |$scan_size - $size| = $diff gt $opt{'diff'} -> ok\n");
		exit(0);
	} else {
		_verbose("diff has not passed |$scan_size - $size| = $diff !> $opt{'diff'} -> wont scan\n");
		exit(1);
	}
}

