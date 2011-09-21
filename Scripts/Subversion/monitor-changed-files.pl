#!/usr/bin/env perl

# Info
#
# Send mail notification on files being commited
# 
# Need to create a file $monitored_files
# Example:
# path/to/file,email@gmail.com,email@gmail.com

# Enviroment variable gathered from hook scripts
$svnlook = "$ENV{'SVNLOOK'}";
$REPO_NAME = "$ENV{'REPO_NAME'}";
$REPO = "$ENV{'REPOS'}";

$monitored_files="/path/to/list/file.cfg";
$info_file = "/tmp/$REPO_NAME.txt";

open (IN,"$monitored_files")||die "can't access $monitored_files";
@modified=split("\n",`$svnlook changed $REPO`);

while (<IN>)
{
	if (!/^\#/)
	{
	chomp;
	@line=split(",",$_);
	$pre_defiend=$line[0];
	foreach (@modified){
		chomp $_;
		@tmp=split(" ",$_);
		$changed=@tmp[1];
			if ($changed =~ /^$pre_defiend/)
			{
				foreach (@line)
				{
						get_change_details();
						chomp $_;
						`/bin/mail -s "$changed had changed in repository" $_ < $info_file`;
				}
			}
		}
	}
}
close IN;

sub get_change_details()
{
	`touch $info_file`;
	$author=`$svnlook author $REPO`;
	$log=`$svnlook log $REPO`;
	open (OUT,">$info_file")||die "can't open to $info_file";
	print OUT "\n\nChanged file:\n$changed\n\nLast changed by:\n$author\nLog message:\n$log";
	close OUT;
}
