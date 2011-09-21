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
# The purpose of this script is to scan a range of network addresses and nitify by mail about the following changes
# New host
# Host removed from network
# services has been changed
# 
# The script will use nmap to probe which hosts are alive and will scan them accordingly
# Linux: should have a $linuxport open & listenning
#        will scan by ssh (will need key authentication, passwordless) see $ssh variable
# Windows: should have the $winport port opened & listenning
#          will be scanned by a windows proxy server which insalled with ssh (key authentication) see $winssh variable
# 	   should have powershell installed and WMI access to the windows servers
# 
# Directories & Files
# $rootdir - will need to be a directory with rw permission
# $rootdir/var - will need to be a directory with rw permission
# $rootdir/hosts.cfg - will be used by nmap to know which hosts/network to scan (see man nmap)
# $rootdir/exclude.cfg - will be used by nmap to know which hosts/network to exclude (see man nmap)
# 
# $sendto - mail address to send the notification
# $rotation - how many scans to keep in rotation
# 
# Configure the script as you like via cron or other scheduler

### Modules
use strict;
use Mail::Send;

### Functions
sub _mailerr(@) {
	my ($subject,$sendto,$text) = @_;
	my $msg = Mail::Send->new(Subject => $subject, To => $sendto);
	my $fh = $msg->open;
	print $fh $text;
	$fh->close or die "couldn't send whole message: $!\n";
}
sub _eval_nmap($) {
	my $file = shift;
	if ( ! -e $file) { return(1); }
	my %hosts;
	open(NMAPOUT, $file);
	while (<NMAPOUT>) {
		# Skip if comment
		if($_ =~ /^\#/) { next; }
		chomp($_);
		
		my @l = split(' ',$_);
		shift(@l);
		splice(@l,2,1); 
		
		my $addr = shift(@l);
		my $dnsname = shift(@l);
		$dnsname =~ s/(\(|\))//g;
		$hosts{$addr}{"dnsname"} = $dnsname;
		foreach my $port (@l) {
			my @portstate = split('/',$port);
			$hosts{$addr}{$portstate[0]} = "$portstate[1]";
		}
	}
	close(NMAPOUT); 
	return(%hosts);
}

### Settings
my $rotation = 14; # how log to keep old scans
my $winport = 135; # which port will identifie windows station
my $linuxport = 22; # which port will identifie linux station
my $nmap = `which nmap`; chomp($nmap); # Location of nmap binary
my $ssh = 'ssh -o "ConnectTimeout 30" -o BatchMode=yes -o CheckHostIP=no -o PasswordAuthentication=no'; # ssh command
my $winssh = 'ssh -o "ConnectTimeout 30" -o BatchMode=yes -o CheckHostIP=no -o PasswordAuthentication=no -i /root/.ssh/id_rsa_administrator administrator@windows_sshproxy_server'; # how to connect to windows proxy
my @ports = ($linuxport,$winport);
my $ports_args = "@ports"; $ports_args =~ s/ /\,/g;
my $time = `date +\%F_\%H-\%M-\%S`; chomp($time);
my $devnull = '&> /dev/null';
my $stat;
my $s_win_srv_names = '.1.3.6.1.4.1.77.1.2.3.1.1';
my %errors = (
		'prob' => 0,
		'notscan' => [],
		'newhosts' => [],
		'removedhosts' => [],
		'srvdiff' => [],
);

### Mail
my $sendto = "some\@email.com";
my $subject = "Discovery Monitor Script";

### Dircetories
my $rootdir = "/path/to/working/directory";
my $nmapfilename = 'nmap-out.grep';
my $vardir = "$rootdir/var";
my $curr_dir = "$vardir/$time";
my $nmapfile = "$curr_dir/$nmapfilename";
my @all_scans = split("\n",`ls -t1 $vardir`);
my $latest_dir = "$vardir/$all_scans[0]" ; chomp($latest_dir);
my %latest_hosts = _eval_nmap("$latest_dir/$nmapfilename");


### Nmap Command
my $cmd = "$nmap -T4 --max-retries 2 -p $ports_args -iL $rootdir/hosts.cfg --excludefile $rootdir/exclude.cfg -oG $nmapfile $devnull";

### Creating Directory Stracture
my $cr8dir = <<EOF;
cd $vardir $devnull
mkdir $time $devnull
echo \$?
EOF
$stat = `$cr8dir`;
chomp($stat);
if($stat != 0 ) {
	print "Can't make Directory in $vardir\n";
	_mailerr($subject,$sendto,"Can't make Directory in $vardir\n");
	exit(1);
}

### Creating Nmap Scan
$stat = `$cmd ; echo \$?`;
chomp($stat);
if($stat != 0 ) {
	print "Nmap exited with error $stat\n";
	print "INFO: $cmd\n";
	_mailerr($subject,$sendto,"Nmap exited with error $stat\nINFO: $cmd\n");
	exit(1);
}

### Evaluating nmap scan
my %hosts = _eval_nmap($nmapfile);

### Getting Services Info
foreach my $key ( sort keys %hosts ) {
	
	### Windows
	if($hosts{$key}{$winport} eq "open") {
		# Grep Services VIA win2003-vm & WMI
		my @srv_list = split("\n",`$winssh 'echo "Get-Service -ComputerName $key | Select-Object -Property Name" | powershell -Command -'`);
		
		# Sort and store in file
		@srv_list = sort(@srv_list);
		open(HOSTOUT, ">>$curr_dir/$key");
		foreach my $srv (@srv_list) {
			chomp($srv);
			next if($srv =~ /^Name\s*$/);
			next if($srv =~ /^\s*$/);
			next if($srv =~ /^----\s*$/);
			print HOSTOUT "$srv\n";
		}
		close(HOSTOUT);
		
		# md5sum
		`md5sum $curr_dir/$key | awk '{print \$1}' > $curr_dir/$key.md5`;
	
	### Linux
	} elsif($hosts{$key}{$linuxport} eq "open") {
		# Get Services via SSH
		$stat = `$ssh $key ls -X /etc/init.d > $curr_dir/$key 2> /dev/null ; echo \$?`; chomp($stat);
		if($stat ne "0") {
			print "ERR: $key SSH\n";
			next;
		}
		
		# md5sum
		`md5sum $curr_dir/$key | awk '{print \$1}' > $curr_dir/$key.md5`;
	} else {
		push(@{$errors{'notscan'}},$key);
		$errors{'probe'} = 1;
		next;
	}
}


#####################################
### Comparing To Previous results ###
#####################################

### Based on the current scan
foreach my $key ( sort keys %hosts ) {
	### Skip if the host was not scanned
	if($hosts{$key}{$winport} ne "open" and $hosts{$key}{$linuxport} ne "open") { next; }

	### Compare with latest scan
	my $x = 0;
	foreach my $latest ( sort keys %latest_hosts ) {
		chomp($latest);
		if($key eq $latest) {
			$x = 1;
			last;
		}
	}
	# IF doesn't exists in the previous scan -> assume new host
	if($x == 0) {
# 		print "$key new host !\n";
		push(@{$errors{'newhosts'}},$key);
		$errors{'probe'} = 1;
	# If there is an entry in the latest scan -> check for services
	} else {
		my $curr_md5;
		open(CURR, "$curr_dir/$key.md5");
		while (<CURR>) {
			chomp($_);
			$curr_md5 = "$_";
			last;
		}
		close(CURR);
		my $latest_md5;
		open(CURR, "$latest_dir/$key.md5");
		while (<CURR>) {
			chomp($_);
			$latest_md5 = "$_";
			last;
		}
		close(CURR);
		
		if($curr_md5 ne $latest_md5) {
			push(@{$errors{'srvdiff'}},$key);
			$errors{'probe'} = 1;
		}
	}
}

### Based on the previous scan
foreach my $key ( sort keys %latest_hosts ) {
	### Skip if the host was not scanned
	if($latest_hosts{$key}{$winport} ne "open" and $latest_hosts{$key}{$linuxport} ne "open") { next; }

	### Compare with current scan
	my $x = 0;
	foreach my $current ( sort keys %hosts ) {
		chomp($current);
		if($key eq $current) {
			$x = 1;
			last;
		}
	}
	# IF doesn't exists in the current scan -> assume deleted host
	if($x == 0) {
		push(@{$errors{'removedhosts'}},$key);
		$errors{'probe'} = 1;
	}
}


### Scan Rotation
my $scansum = $#all_scans + 2;
if($scansum > $rotation) {
	my $delete = $scansum - $rotation;
	for (my $count = $delete; $count >= 1; $count--) {
		my $deldir = pop(@all_scans);
		my $rm = `cd $vardir && cd $deldir && rm -f * && cd .. && rmdir $deldir`;
	}
}


### Send Mail on changes
if($errors{'probe'} == 0) {
	exit(0);
}

my $msg = Mail::Send->new(Subject => $subject, To => $sendto);
my $fh = $msg->open;

print $fh "  Discovery Monitoring Script Results $time\n";
print $fh "*--------------------------------------------------------*\n\n";


if(@{$errors{'removedhosts'}}) {
	print $fh " Delete Hosts (doesn't exists in the current scan)\n";
	print $fh "*---------------------------------------------------*\n";
	foreach(@{$errors{'removedhosts'}}) {
		print $fh " $_\n";
	}
	print $fh "\n";
}

if(@{$errors{'srvdiff'}}) {
	print $fh " Hosts That have a change in their services\n";
	print $fh "*---------------------------------------------*\n";
	foreach(@{$errors{'srvdiff'}}) {
		print $fh " $_\n";
	}
	print $fh "\n";
}

if(@{$errors{'notscan'}}) {
	print $fh " Hosts that could not scan (maybe need to be excluded)\n";
	print $fh "*------------------------------------------------------*\n";
	foreach(@{$errors{'notscan'}}) {
		print $fh " $_\n";
	}
	print $fh "\n";
}

if(@{$errors{'newhosts'}}) {
	print $fh " New Hosts (doesn't exists in the previous scan):\n";
	print $fh "*----------------------------------------------------*\n";
	foreach(@{$errors{'newhosts'}}) {
		print $fh " $_\n";
	}
	print $fh "\n";
}
$fh->close or die "couldn't send whole message: $!\n";
