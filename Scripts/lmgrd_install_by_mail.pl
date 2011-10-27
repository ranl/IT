#!/usr/bin/env perl


# Info:
# This script should run from a cron job and it does the following
# Checks a mailbox via IMAP to get the first unread mail in the inbox, all the attachments are gets extracted to $attachDir which will need to be created
# it searchs for the license file change the Server_Name and install it in the appropriate location & restart the license server daemon
# 
# Note:
# This script is pretty customized so you will probably need to change it a bit.
# It's not meant to work out of the box
# 
# Please configure the #settings section and take a look at the script before launching it

# 
# 
# THIS WONT WORK OUT OF THE BOX, PLEASE TAKE A LOOK AT THE SCRIPT BEFORE LAUNCHING IT !!!!!!!!!
# 


use strict;
use MIME::Parser;
use Mail::IMAPTalk qw(:utf8support);
use File::Basename;
use Getopt::Std;
my %opts; my $res;

# Settings
my $LicPath = '';
my $logPath = '';
my $ServerHostname = '';
my $lmport = '';
my $initDscript = '/etc/init.d/lmgrd';
my $mailto = '';


my $scriptDir = dirname($0);
my $attachDir = "$scriptDir/attach";
my $lockfile = "$scriptDir/lock";
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
$year += 1900;
$mon += 1;
my $date = "$year-$mon-$mday\_$hour:$min:$sec";

# create/check lock file
if( -e $lockfile ) {
	print "lock file exists, quitting...\n";
	exit(1);
} else {
	system("touch $lockfile");
}


sub connexion {
	print "Connecting to IMAP server at ".$_[0].":".$_[1]."...\n";
	# ouverture de la connexion avec IMAP::Talk
	my $imap = Mail::IMAPTalk->new(
		Server => $_[0],
		Port => $_[3],
		Username => $_[1],
		Password => $_[2],
		Separator => '.',
		RootFolder => 'Inbox',
		CaseInsensitive => 1,
		ParseOption => 'DecodeUTF8',
	)
	|| die "Connection failed. Reason: $@";

	# select the IMAP folder and the last not seen message
	$imap->select($_[4]) || die $@;
	my $MsgId = $imap->search('not', 'seen')->[0];
	
	if ($MsgId) {
		# Fetch the message body as a MIME object
		my $MsgTxt = $imap->fetch($MsgId, "body[]")->{$MsgId}->{body} || die "Can't fetch the message !";
		print "IMAP connection successful !\n";
		$imap->store('1:*', '+flags', '(\\deleted)');
		$imap->expunge();
		return ($MsgTxt);
	} else {
		die "No new message in the mailbox\n";
	}
}

sub parseur {
	# Create a new MIME::Parser object
	my $parser = new MIME::Parser;
	# Tolerant mode
	$parser->ignore_errors(1);
	# Output to a file
	$parser->output_to_core(0);
	# Output to a per message folder
	$parser->output_dir("$attachDir");
	# Prefix for the extracted message
	$parser->output_prefix("msg");
	# Parsing the message
	my $entity = $parser->parse_data($_[0]);
	my $error = ($@ || $parser->last_error);
	if ($error) {
		print $error."\n";
	}
}

# command line options
getopts('s:l:p:P:F:', \%opts);
die("\n -- Mail_extract--\n".
"\n".
" Mail_Extract take off the attachement from the last arrived message in an IMAP box\n".
" Files are in the ./extracted directory\n".
"\n".
"Usage: $0 {Mode} [options]\n".
"\n".
" Required :\n".
" -s [server] Name or IP address of the IMAP server\n".
" -l [login] Login of the IMAP mailbox\n".
" -p [password] IMAP password\n".
" Options :\n".
" -P [port] IMAP port (default : 143)\n".
" -F [folder] IMAP folder to fetch (default : INBOX)\n".
"")
unless ($opts{'s'} && $opts{'l'} && $opts{'p'}
|| ($opts{'s'} && $opts{'l'} && $opts{'p'} && $opts{'P'})
|| ($opts{'s'} && $opts{'l'} && $opts{'p'} && $opts{'F'})
|| ($opts{'s'} && $opts{'l'} && $opts{'p'} && $opts{'P'} && $opts{'F'})
);
$opts{'P'}=143 unless $opts{'P'};
$opts{'F'}='INBOX' unless $opts{'F'};

# establish IMAP connection
$res = connexion ($opts{'s'},$opts{'l'},$opts{'p'},$opts{'P'},$opts{'F'});
# parse the message
parseur ($res);

# parse license file
chdir($attachDir) or die "dir doesnot exists";
my @files = split("\n",`ls License*t`);
my $licfile = shift(@files);
my $islicok = 0;

# check if license file is valid
unless($licfile) {
	system("echo file name of the attachment is not as expected | mail -s \"License file was not installed - not valid license file\" $mailto");
	exit(1);
}

my $stringcheck = "";
$stringcheck = `grep -q Cadence_SERVER $licfile`; chomp($stringcheck);
if($stringcheck) {
	system("echo could not find the string Cadence_SERVER | mail -s \"License file was not installed - not valid license file\" $mailto");
	exit(1);
}

# install license file
system("dos2unix $licfile");
system("sed -i -e 's/Cadence_SERVER/$ServerHostname/g' $licfile");
system("ssh $ServerHostname $initDscript stop &> /dev/null");
system("sleep 2");
system("mv $LicPath $LicPath.$date");
system("mv $licfile $cadenceLicPath");
system("ssh $cadenceServer $initDscript start &> /dev/null");
system("rm -f *");

# notify on outcome
system("sleep 90");
my $error = `lmutil lmstat -c $lmport\@$ServerHostname &> /dev/null ; echo \$?`; chomp($error);
if($error) {
	system("cat $logPath | mail -s \"License file installed with error\" $mailto");
} else {
	system("lmutil lmstat -a -c $lmport\@$cadenceServer | mail -s \"License file installed\" $mailto");
}

# remove lock file
chdir($scriptDir) or die "dir doesnot exists";
system("rm -f $lockfile");
