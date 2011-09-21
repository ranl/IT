#!/usr/bin/env perl

use strict;
use Carp;
use warnings;

# Info
#
# used to let users "lock" a specific path in the repository without the needs-lock property
# note: this script looks directly on the path and does not care about externals links

# Functions
sub usage {
  warn "@_\n" if @_;
  die "usage: $0 /path/to/svnlook REPOS TXN-NAME path/to/Trunk.lck user password http_path";
}
# Getting Parameters
&usage unless @ARGV == 8;

my $svnlook = shift;
my $repos = shift;
my $txn = shift;
my $trunk_lock = shift;
my $trunk_dir = "$trunk_lock";
$trunk_dir =~ s/Trunk.lck//g;
my $svn_user = shift;
my $svn_pass = shift;
my $http_path = shift;
my @files_type = split(" ",shift);

# Svnlook
foreach my $program ($svnlook) {
	if (-e $program) {
		unless (-x $program) {
			&usage("required program `$program' is not executable, edit $0.\n");              
		}
	} else {
		&usage("required program `$program' does not exist, edit $0.\n");
	}
}

# Verifying Path
unless (-e $repos)
  {
    &usage("$0: repository directory `$repos' does not exist.");
  }
unless (-d $repos)
  {
    &usage("$0: repository directory `$repos' is not a directory.");
  }

# Getting User
my $AUTHOR = `$svnlook author $repos -t $txn `;
chomp($AUTHOR);

# Verifyng Lock File
my $tmp_lck_exists = `/usr/bin/wget --user=$svn_user --http-passwd=$svn_pass $http_path/$trunk_lock -q -O /dev/null ; echo $?`;
if($tmp_lck_exists == 1) {
	warn "$http_path/sw/Phy/FwDev/Trunk/Trunk.lck Does not exists, please contact the IT Department";
	exit(1);
}
my $locked_by = `svnlook lock $repos $trunk_lock | grep ^Owner: | awk '{print \$2}'`;
chomp($locked_by);
if($locked_by) {
	if($locked_by eq $AUTHOR) {
		exit(0);
	}
	my $islocked = 1;
} else {
	my $islocked = 0;
	exit(0);
}

# Go to Temp Directory
my $tmp_dir = '/tmp';
chdir($tmp_dir) or die "$0: cannot chdir `$tmp_dir': $!\n";

# All Commited files
my @files_added;
my @changed = split("\n",`$svnlook changed $repos -t $txn`);
foreach(@changed) {
	my @tmp_arr = split("   ",$_);
	foreach my $file_type (@files_type) {
		if ($tmp_arr[0] =~ /^$file_type/) {
			push(@files_added,$tmp_arr[1]);
		}
	}
}

# Getting Array of files within the $trunk_dir
my @errors;
foreach my $path ( @files_added ) {
	if($path =~ /^$trunk_dir/) {
		push(@errors,$path);
	}
}

# Breaking the commit in case of non svn:needs-lock files
if(@errors) {
	warn "\n";
	warn "The Path $trunk_lock is locked by $locked_by\n";
	warn "Can't commit the following files:\n";
	foreach(@errors) {
		warn "$_\n";
	}
	
	exit(1);
}
