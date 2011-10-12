#!/usr/bin/perl

use strict;
use File::Basename;
use DBI;
use DBD::mysql;
use Data::Dumper;
BEGIN {
  my $path2du = dirname($0);
  unshift(@INC,"$path2du/conf");
}
use sdu;
my $wrkdir = dirname($0);

###### Settings
my ($scriptname, $wrkdirp) =  fileparse($0);
my @childs;
my %scan_index;
my $vardir = "$wrkdir/var";
my $lockfile = "$vardir/.lock";
our $log_file = "$vardir/log";
my $perf = "$vardir/perf.csv";
my $debug_file = "$vardir/debug";
my $config_dir = "$wrkdir/conf";
my $utilsPath = "$wrkdir/utils";
my $path_config_file = 'paths.cfg'; $path_config_file = "$config_dir/$path_config_file";
my $du_exclude = "$config_dir/du_exclude.cfg";
my $du = "du -P -k -X $du_exclude";
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
	system("echo `date +\%F_\%T`,$msg >> $log_file");
}
sub _get_size_of_dir_from_out_file(@) {
	my ($dirname, $dir_id) = @_;
	my $return;
	if($dir_id) {
		my $outfile = _escape_char("$vardir/$dirname/$dir_id.out");
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

###### Verifying location of script configuration files and directories
unless( -d $wrkdir ) { print "Directory $wrkdir does not exists\n"; exit(1); }
unless( -d $vardir ) { print "Directory $vardir does not exists\n"; exit(1); }
unless( -d $config_dir ) { print "Directory $config_dir does not exists\n"; exit(1); }
unless( -f $du_exclude ) { print "Du exclude file $du_exclude does not exists\n"; exit(1); }
chdir($wrkdir) or die "Cant change directory to $wrkdir\n$!\n";
chdir($vardir) or die "Cant change directory to $vardir\n$!\n";
chdir($config_dir) or die "Cant change directory to $config_dir\n$!\n";

###### Check if there is another scan running
if( -e $lockfile ) {
	print "Another scan is taking place, quiting...\n";
	exit(1);
} else {
	`touch $lockfile`;
}

###### Getting paths from configuration files
open(CONFIG, "<$path_config_file") or die "Cant open $path_config_file\n";
my $count = 0;
my %path_2_scan;
while(<CONFIG>) {
	$count++;
	chomp($_);
	if($_ =~ /^#/) { next; };
	if($_ =~ /^$/) { next; };
	my @line = split(",",$_);
	chomp($line[0]);
	chomp($line[1]);
	chomp($line[2]);
	chomp($line[3]);
	# removing ending slashes
	$line[1] =~ s/\/*$//g;
	
	# Validate Config Line
	if($line[0] eq '_settings') { print "Cant create a scan with name _settings, please correct\nline $count: @line"; next; };
	if($#line != 3) { print "configuration syntax error in line $count\nline $count: @line is missing some configuration\n"; exit(1); };
	if($line[1] !~ /^\//) { print "please config only absolute paths\nline $count: $line[1]\n"; exit(1); };
	chdir($line[1]) or die "Cant change directory to $line[1]\nline $count: $line[1]\n";
	unless($line[2] =~ /^\d*$/ and $line[2] >= 0) { print "depth must be an integer and >= 0\nline $count: $line[2]\n"; exit(1); }
	
	my @script_splitted = split(" ",$line[3]);
	if($script_splitted[0] ne "none") {
		my $which_script = `which --skip-alias --skip-functions \'$utilsPath/$script_splitted[0]\' 2> /dev/null` ; chomp($which_script);
		if( $which_script eq "" ) { print "script was not found\nline $count: $line[3]\n"; exit(1); };
		unless( -x $which_script ) { print "script has to be executable\nline $count: $line[3]\n"; exit(1); };
	}
	
	foreach my $root (keys %path_2_scan) {
		if(lc($line[0]) eq lc($root)) { print "duplicate entries (not case sensitive)\nline $count: $line[0]\n"; exit(1); };
		if($line[1] eq $path_2_scan{$root}{'directory'}) { print "duplicate entries\nline $count: $line[1]\n"; exit(1); };
	}
	
	
	# Add to hash
	$path_2_scan{$line[0]};
	$path_2_scan{$line[0]}{'directory'} = $line[1];
	$path_2_scan{$line[0]}{'depth'} = $line[2];
	$path_2_scan{$line[0]}{'script'} = $line[3];
	$path_2_scan{$line[0]}{'check'} = 0;
	
}
close(CONFIG);

print Dumper(%path_2_scan);

# Verifying that there is no Collision with the paths 
foreach my $root (keys %path_2_scan) {
	foreach(keys %path_2_scan) {
		if( $path_2_scan{$root}{'directory'} =~ /^$path_2_scan{$_}{'directory'}\// ) {
			print "Paths Collision\n\t$path_2_scan{$root}{'directory'}\n\t$path_2_scan{$_}{'directory'}\n";
			exit(1);
		}
	}
}

###### Verifying DB
my $connect_test = DBI->connect("dbi:mysql:$mysql_settings{'db'}:$mysql_settings{'server'}:$mysql_settings{'port'}", $mysql_settings{'user'}, $mysql_settings{'pw'}) or die "Cant connect to mysql server\n";
$connect_test->disconnect();


###### Start Script ######
# Truncate $vardir
chdir($vardir) or die "Cant change directory to $vardir\n$!\n";
system("rm -rf * &> /dev/null");
chdir('/tmp');

###### Checking if scan will be made
_logger("Checking if scan will be made");
foreach my $root (keys %path_2_scan) {

	# Lets see if there is a way to check this scan
	if($path_2_scan{$root}{'script'} eq "none" or $path_2_scan{$root}{'script'} eq "") {
		next;
	}
	
	# check it
	my $exitCode = `$utilsPath/$path_2_scan{$root}{'script'} &> /dev/null ; echo \$?`; chomp($exitCode);
	$path_2_scan{$root}{'check'} = $exitCode;
	_logger("Checking $root - $exitCode");
	if($exitCode == 2) {
		_logger("ERR: Checking $root - $exitCode - config problem");
	}
}

###### Getting dirs
_logger("Getting Directories");
foreach my $root (keys %path_2_scan) {
	if($path_2_scan{$root}{'check'} != 0) {
		next;
	}
	
	_logger("Getting Directories - $root");
	
	$path_2_scan{$root}{'dirs'} = ();
	$path_2_scan{$root}{'root_dirs'} = ();
	
	_get_dirs(\@{$path_2_scan{$root}{'root_dirs'}},\@{$path_2_scan{$root}{'dirs'}},$path_2_scan{$root}{'directory'},$path_2_scan{$root}{'depth'} - 1,0,"yes");
	if($path_2_scan{$root}{'depth'} > 0) {
		push(@{$path_2_scan{$root}{'root_dirs'}},$path_2_scan{$root}{'directory'});
	}
	
	@{$path_2_scan{$root}{'dirs'}} = sort(@{$path_2_scan{$root}{'dirs'}});
	@{$path_2_scan{$root}{'root_dirs'}} = sort {$b cmp $a} @{$path_2_scan{$root}{'root_dirs'}};
}
`touch $debug_file`;
open(DEBUG, ">$debug_file") or die "Cant open $debug_file\n";
print DEBUG Dumper(%path_2_scan);
close(DEBUG);

###### Start Job dispatch
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
$year += 1900;
$mon += 1;
my $fromdate = "$year-$mon-$mday $hour:$min:$sec";

_logger("Start job dispatching");
our $num_of_current_jobs = 0;
foreach my $scan (keys %path_2_scan) {
	if($path_2_scan{$scan}{'check'} != 0) {
		next;
	}
	
	my $c_wd = "$vardir/$scan";
	mkdir($c_wd);
	
	my $index = -1;
	foreach my $current ( @{$path_2_scan{$scan}{'dirs'}} ) {
		$index++;
		$scan_index{$scan}{$current} = $index;
		# Make sure that no more than $dispatcher{'maxjobs'} is beeing executed
		while($num_of_current_jobs == $dispatcher{'maxjobs'}) {
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
			my $du_exit = `$du \'$current\' > \'$c_wd/$index.out\' 2>> \'$c_wd/log\' ; echo \$?`; chomp($du_exit);
			exit(0);
		} else {
			die "couldn’t fork: $!\n";
		}
	}
}

# Wait for remaining forks
_logger("Wait for remaining forks");
while (wait() != -1) { sleep(5); }

###### Calculate root dirs  $root_file  
_logger("Calculate root dirs");
foreach my $scan (keys %path_2_scan) {
	if($path_2_scan{$scan}{'check'} != 0) {
		next;
	}
	
	my $c_wd = "$vardir/$scan";
	my $root_file = "$c_wd/roots"; `touch \'$root_file\'`;

	foreach my $root_dir ( @{$path_2_scan{$scan}{'root_dirs'}} ) {
		my $current_dir_size = 0;
		my $root_dir_escaped =  _escape_char("$root_dir");
		my $sed_dir = "$root_dir";
		$sed_dir =~ s/(\,|\ |\(|\)|\"|\*|\^|\!|\`|\[|\]|\;|\:|\?|\$|\{|\}|\@|\&|\>|\<|\||\+|\%|\~|\=|\/|\')/\\$1/g;
		
		# Calculate child directories from DU
		foreach my $scandir (keys %{$scan_index{$scan}}) {
			if($scandir =~ /^$sed_dir\//) {
			my $child_size = _get_size_of_dir_from_out_file($scan,$scan_index{$scan}{$scandir});
				if($child_size > 0) {
					# Add directory size
					$current_dir_size += $child_size;
				}	
			# Removing Childs from index	
			delete($scan_index{$scan}{$scandir});
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
		`echo -en '$current_dir_size\t$root_dir_escaped\n' >> \'$root_file\'`;
	}
}

###### Load data to Mysql Server
my ($sec1,$min1,$hour1,$mday1,$mon1,$year1,$wday1,$yday1,$isdst1) = localtime(time);
$year1 += 1900;
$mon1 += 1;
my $todate = "$year1-$mon1-$mday1 $hour1:$min1:$sec1";
_logger("Load data to Mysql Server");
my $connect = DBI->connect("dbi:mysql:$mysql_settings{'db'}:$mysql_settings{'server'}:$mysql_settings{'port'}", $mysql_settings{'user'}, $mysql_settings{'pw'}) or die "Cant connect to mysql server\n";
chdir($vardir);
foreach my $scan (keys %path_2_scan) {
	if($path_2_scan{$scan}{'check'} != 0) {
		next;
	}
	
	chdir("$vardir/$scan");
	my $path = $path_2_scan{$scan}{'directory'};
	
	# Delete & Recreate Table and _settings entry
	$connect->do("DROP TABLE IF EXISTS `$mysql_settings{'db'}`.`$scan` ;");
	$connect->do("CREATE TABLE `$mysql_settings{'db'}`.`$scan` (id int(11) NOT NULL auto_increment, path varchar(255) NOT NULL, parent varchar(255) NOT NULL, size bigint(20) NOT NULL, PRIMARY KEY  (id)) ENGINE=MyISAM DEFAULT CHARSET=latin1;");

	my $sth = $connect->prepare("DELETE FROM $mysql_settings{'db'}._settings where name = '$scan' and ( path LIKE '$path/%' or path = '$path' )");
	$sth->execute();
	$sth->finish();
	
	my $roots_escaped = "";
	if($path_2_scan{$scan}{'depth'} == 0) {
		$roots_escaped =  _escape_char("$vardir/$scan/1.out");
	} else {
		$roots_escaped =  _escape_char("$vardir/$scan/roots");
	}
	my $scan_size = `tail -n 1 \'$roots_escaped\' | awk '{print \$1}'`; chomp($scan_size);
	my $inert_qtree = "INSERT INTO $mysql_settings{'db'}._settings (name, path, size, fromdate, todate) VALUES ('$scan', '$path', '$scan_size', '$fromdate', '$todate' ) ON DUPLICATE KEY UPDATE size='$scan_size',fromdate='$fromdate',todate='$todate'";
	my $inert_h = $connect->prepare($inert_qtree);
	$inert_h->execute();
	
	# Load Data
	my @out_files = `ls *.out roots`;
	foreach my $outfile (@out_files) {
		open(OUTFILE, "<$outfile");
		while(<OUTFILE>) {
			my $line = $_; chomp($line);
			my @splitted = split("\t",$line);
			$splitted[1] =~ s/\/$//g;
			$splitted[1] =~ s/\'/\\\'/g;
			push(@splitted,dirname($splitted[1]));
			
			my $query = "INSERT INTO $mysql_settings{'db'}.$scan (id, path, parent, size) VALUES (DEFAULT, '$splitted[1]', '$splitted[2]', '$splitted[0]')";
			my $query_handle = $connect->prepare($query);
			$query_handle->execute();
		}
		close(OUTFILE);
	}
}
$connect->disconnect();




###### Exit nicely ######
_logger("Bye Bye");
# Removing lock file
unlink($lockfile);
exit(0);
