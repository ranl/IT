#!/usr/local/perl/5.10.0/bin/perl

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
# Show's quota report in a nicer way via rsh

# Functions
sub _byte_size {
	use constant K => 1024;
	use constant M => K * K;
	use constant G => M * K;
	use constant P => G * K;
	require  Math::Round;
	import Math::Round qw( nearest );
 
	my ($KBytes) = @_;
	return "${KBytes} KB" if $KBytes < K;
	return nearest(1, $KBytes / K ) . " MB" if $KBytes < M;
	return nearest(0.1, $KBytes / M ) . " GB" if $KBytes < G;
	return nearest(0.01, $KBytes / G ) . " PB" if $KBytes < P;
}

# Settings
use strict;
my $rsh = "/usr/bin/rsh";
my $filer = "filer1";
my $quota_cmd = "$rsh $filer quota report | sed '1,3d'";
my $header = "#################################################\n# Type\tId\tVol\tQtree\tUsed\tLimit   #\n#################################################";

# Gathering Data
my @raw = split("\n",`$quota_cmd`);

# Display Data
my $counter = 0;
print "$header\n";
foreach my $line (@raw) {
	if($counter == 10) {
		$counter = 0;
		print "$header\n";
	}
	$counter++;
	my @tmp_arr = split(" ",$line);
	my $used = _byte_size($tmp_arr[4]);
	my $limit = _byte_size($tmp_arr[5]);
	print "$tmp_arr[0]\t$tmp_arr[1]\t$tmp_arr[2]\t$tmp_arr[3]\t$used\t$limit\n";
}


