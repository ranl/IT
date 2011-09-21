#!/usr/bin/env perl

use strict;
use Carp;
use warnings;

# Info
#
# pre-commit
# check if all the files have the needs-lock property, if not the commit will fail

# Functions
sub usage {
  warn "@_\n" if @_;
  die "usage: $0 /path/to/svnlook REPOS TXN-NAME\n";
}
# Getting Parameters
&usage unless @ARGV == 4;

my $svnlook = shift;
my $repos = shift;
my $txn = shift;

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
# Go to Temp Directory
my $tmp_dir = '/tmp';
chdir($tmp_dir) or die "$0: cannot chdir `$tmp_dir': $!\n";

# Figure out what files have added using svnlook.
my @files_added;

my @changed = split("\n",`$svnlook changed $repos -t $txn`);
foreach(@changed) {
	my @tmp_arr = split("   ",$_);
	if ($tmp_arr[0] =~ /^A$/) {
                if($tmp_arr[1] !~ /\/$/) {
                        push(@files_added,$tmp_arr[1]);
                }
	}
}

# Getting Array of files without svn:needs-lock
my $errors;
my @errors_lock;
my @errors_special;
foreach my $path ( @files_added ) {
	my $needs_lock;
	my $special;
	foreach my $prop (`$svnlook proplist $repos -t $txn --verbose "$path"`) {
		if($prop =~ /^\s*svn:special/) {
			$special = "True";
		}			
		if($prop =~ /^\s*svn:needs-lock/) {
			$needs_lock = "True";
		}
	}
	if(not $special) {
		if(not $needs_lock) {
			$errors = 1;
			push(@errors_lock,"$path");
		}
	} else {
		if($needs_lock) {
			$errors = 1;
			push(@errors_special,"$path");
		}
	}
}

# Breaking the commit in case of non svn:needs-lock files
if($errors) {
	warn "\n";
	if(@errors_special) {
		warn "You can't add the property svn:needs-lock to a symlink:\n";
	}
	warn "\n";
	if(@errors_lock) {
		warn "You must add the property svn:needs-lock the any regular file:\n";
	}
	
	exit(1);
}
