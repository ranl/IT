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

# Info:
# Calculate qtree size via rsh+quota
# rsh access to the filer needs to be configured

# Functions
sub FSyntaxError {
	print "Syntax Error !\n";
	print "$0 [filer address] ][vol] [qtree]\n";
	exit(1);
}

sub _byte_size {
	use constant K => 1024;
	use constant M => K * K;
	use constant G => M * K;
	use constant T => G * K;
	require  Math::Round;
	import Math::Round qw( nearest );
 
	my ($KBytes) = @_;
	return "${KBytes} KB" if $KBytes < K;
	return nearest(1, $KBytes / K ) . " MB" if $KBytes < M;
	return nearest(0.1, $KBytes / M ) . " GB" if $KBytes < G;
	return nearest(0.01, $KBytes / G ) . " TB" if $KBytes < P;
}

# User Data
if($#ARGV != 2) {
        FSyntaxError;
}
my $vol = "$ARGV[0]";
my $qtree = "$ARGV[1]";
my $filer = "$ARGV[2]";

# Settings
use strict;
my $rsh = "/usr/bin/rsh";
my $quota_cmd = "$rsh $filer quota report | sed '1,3d' | grep ^user\ ";
my $vol_cmd = "$rsh $filer vol status -b | sed '1,2d' | awk '{print \$1}'";
my $qtree_cmd = "$rsh $filer qtree status $vol | awk '{print \$2}'";
my $SUM = 0;
my $ERR;

# Verifying Vol
$ERR = 1;
my @vols = split("\n",`$vol_cmd`);
foreach(@vols) {
	chomp($_);
	if("$_" eq "$vol") {
		$ERR = 0;
		last;
	}
}
if($ERR == 1) {
	print "Volume $vol doesn't exists ...\n";
	exit(1);
}

# Verifying Qtree
$ERR = 1;
my @qtrees = split("\n",`$qtree_cmd`);
foreach(@qtrees) {
	chomp($_);
	if("$_" eq "$qtree") {
		$ERR = 0;
		last;
	}
}
if($ERR == 1) {
	print "Qtree $qtree doesn't exists ...\n";
	exit(1);
}

# Gathering Data
my @raw = split("\n",`$quota_cmd`);

# Display Data
foreach my $line (@raw) {
	my @row = split(" ",$line);
	if(("$row[2]" eq "$vol") && ("$row[3]" eq "$qtree")) {
		if(("$row[3]" ne "-") && ("$row[1]" ne "*")) {
			print "$row[1]\t",_byte_size($row[4]),"\n";
			$SUM = $SUM + $row[4];
		}
	}
}

print "=================\nSummary: ",_byte_size($SUM),"\n";
