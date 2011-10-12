#!/usr/bin/perl

# This Script will scan a directory via du with more than one instance
# Be carefull this could overload your system if not executed cautiously

use strict;
use Getopt::Long; Getopt::Long::Configure('bundling');

sub _syntax($){
	my $err = shift;
	print <<EOU;
$err
Syntax:
	-e
	  exclude string as in du --exclude
	-p
	  directory to scan
	-d
	  how deep to scan
	-m
	  max # of du instances (don't put a large number unless you know whan you are doing)
EOU
exit(1);
}

my %opt;
my $result = GetOptions(\%opt,
        'exclude|e=s',
        'path|p=s',
        'depth|d=i',
        'maxjobs|m=i',
);
_syntax("Missing -p")  unless defined $opt{'path'};
_syntax("Missing -d")  unless defined $opt{'depth'};
_syntax("Missing -m")  unless defined $opt{'maxjobs'};
my $du;
if(defined $opt{'exclude'}) {
	$du = "du -P -k --exclude='$opt{'exclude'}'";
} else {
	$du = "du -P -k";
}

###### Settings
my @childs;
my %scan_index;
my $tmpdir = rand(5); $tmpdir = "/tmp/du_$tmpdir";
###### Functions
sub _get_dirs(@) {
	my $return_root=shift;
	my $return=shift;
	my $location=shift;
	my $depth=shift;
	my $f=shift;
	my $start = shift;
	my $get_dirs = "find -P . -maxdepth 1 -path '*/.snapshot' -prune -o -type d -printf '\%P\\n' | sed '1d'";

	chdir("$location");
	my @dirs = split("\n",`$get_dirs`);
	if($start eq "yes" and $depth == -1) {
		push(@$return,"$location/$_");
	} else {
		if($f < $depth) {
			$f++;
			foreach(@dirs) {
				push(@$return_root,"$location/$_");
				_get_dirs(\@{$return_root},\@{$return},"$location/$_",$depth,$f);
			}
		} elsif($f == $depth) {
			foreach(@dirs) {
				push(@$return,"$location/$_");
			}
		}
	}
}
sub _logger($) {
	my $msg = shift;
	system("echo `date +\%F_\%T`,$msg");
}
sub _get_size_of_dir_from_out_file(@) {
	my ($dir_id) = @_;
	my $return;
	if($dir_id) {
		my $outfile = _escape_char("$tmpdir/$dir_id.out");
		$return = `tail -n 1 \'$outfile\' | awk '{print \$1}'`; chomp($return);
	} else {
		$return = -1;
	}
	return($return);
}
sub _escape_char($) {
	my $return = shift;
	$return =~ s/\'/\'\\\'\'/g;
	return($return);
}



###### Start Script ######
mkdir($tmpdir) or die "Can't mkdir $tmpdir";
chdir($tmpdir);

###### Getting dirs
#_logger("Getting Directories");
my @dirs;
my @root_dirs;

_get_dirs(\@root_dirs,\@dirs,$opt{'path'},$opt{'depth'} - 1,0,"yes");
if($opt{'depth'} > 0) {
	push(@root_dirs,$opt{'path'});
}

@dirs = sort(@dirs);
@root_dirs = sort {$b cmp $a} @root_dirs;

###### Start Job dispatch
#_logger("Start job dispatching");
our $num_of_current_jobs = 0;
my $index = -1;
foreach my $current ( @dirs ) {
	$index++;
	$scan_index{$current} = $index;
	# Make sure that no more than $dispatcher{'maxjobs'} is beeing executed
	while($num_of_current_jobs == $opt{'maxjobs'}) {
		wait();
		$num_of_current_jobs--;
	}
	
	# Create child and wait 5 seconds
	my $pid = fork();
	if ($pid) {
		# parent
		$num_of_current_jobs++;	
	} elsif ($pid == 0) {
		# child
		$current =~ s/\'/\'\\\'\'/g;
		my $du_exit = `$du \'$current\' > \'$tmpdir/$index.out\' 2>> \'$tmpdir/log\' ; echo \$?`; chomp($du_exit);
		exit(0);
	} else {
		die "couldn’t fork: $!\n";
	}
}

# Wait for remaining forks
#_logger("Wait for remaining forks");
while (wait() != -1) { sleep(5); }

###### Calculate root dirs  $root_file  
#_logger("Calculate root dirs");
my $root_file = "$tmpdir/roots"; `touch \'$root_file\'`;
open (ROOTS, ">>$root_file");
foreach my $root_dir ( @root_dirs ) {
	my $current_dir_size = 0;
	my $root_dir_escaped =  _escape_char("$root_dir");
	my $sed_dir = "$root_dir";
	$sed_dir =~ s/(\,|\ |\(|\)|\"|\*|\^|\!|\`|\[|\]|\;|\:|\?|\$|\{|\}|\@|\&|\>|\<|\||\+|\%|\~|\=|\/|\')/\\$1/g;
	
	# Calculate child directories from DU
	foreach my $scandir (keys %scan_index) {
		if($scandir =~ /^$sed_dir\//) {
		my $child_size = _get_size_of_dir_from_out_file($scan_index{$scandir});
			if($child_size > 0) {
				# Add directory size
				$current_dir_size += $child_size;
			}	
		# Removing Childs from index	
		delete($scan_index{$scandir});
		}
		
	}
	
	# Calculate files from the directory
	my @files_in_c_dir = split("\n",`find -P \'$root_dir_escaped\' -maxdepth 1 -path '*/.snapshot' -prune -o -type f -printf "\%k\\n"`);
	foreach(@files_in_c_dir) {
		$current_dir_size = $current_dir_size + $_;
	}
	
	# Calculate root dirs
	my $root_slashes = $root_dir =~ tr/\///;
	my @root_child_root = split("\n",`grep -v ^0  \'$root_file\'`);
	foreach(@root_child_root) {
		my @line = split(" ",$_);
		my $child_slashes = $line[1] =~ tr/\///;
		$child_slashes--;
		if($child_slashes == $root_slashes and $line[1] =~ /^$sed_dir\// ) {
			$current_dir_size = $current_dir_size + $line[0];
		}
	}
	
		
	# Dump root_dir size out files
	print ROOTS "$current_dir_size\t$root_dir_escaped\n";
}
close(ROOTS);

# Output to STDOUT
chdir($tmpdir);
print `cat *.out roots`;

# Clenup
system("rm -rf $tmpdir");

###### Exit nicely ######
#_logger("Bye Bye");
exit(0);
