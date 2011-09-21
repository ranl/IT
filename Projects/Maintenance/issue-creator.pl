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

########################################################## INFO ###########################################################
# This script is used to create a maintenance jira when configured
# The script needs to run once a day, it searches for *.xml files in the conf directory where the script file is located
# Sample configuration file is conf/template.xml.
# <createnow>   - a comma separated filed which stores the days to open the isse - d-m
# <project>     - Jira project key
# <type>        - ID od the issue type (can be found in the SQL database under the issuetype table)
# <summary>     - Summary field
# <assignee>    - assignee field
# <description> - description field
# 
#
# Hash Example (not needed in this script ....)
# my %issue_hash = (
#     'project' => 'IT',
#     'type' => 77,
#     'summary' => 'Issue created via XMLRPC 2',
#     'assignee' => 'ran',
#     'customFieldValues' => [{'customfieldId' => 'customfield_10352', 'values' => ['IT Assistance On Sitting Place Movment']}],
#     'description' => 'Created with a Perl client 2'
# );
# Note ! - for the field to be populate itd has to be visible in the creation screen
# 
# 
# the conf directory will need to have rw permission and be at the same directory as this script, or configure via $confdir
# Configure the script to run ONCE a day via cron or other scheduler
###########################################################################################################################

use strict;
use Data::Dumper;
use XMLRPC::Lite;
use File::Basename;
require XML::Simple;

# Settings
my $jira_user = 'jirausr';
my $jira_pass = 'password';
my $jiraxml = 'http://jira/rpc/xmlrpc';

my ($scriptname, $scriptdir) =  fileparse($0);
my $confdir = "$scriptdir/conf";
my @timeData = localtime(time);
my $month = $timeData[4] + 1;
my $dom = $timeData[3];
my $dow = $timeData[6];
my $today = "$dom-$month";
my $xml = new XML::Simple;

# Jira Login
my $jira = XMLRPC::Lite->proxy($jiraxml);
my $auth = $jira->call("jira1.login", $jira_user, $jira_pass)->result();

# Loop Through conf dir
my @files = <$confdir/*.xml>; 
foreach my $file (@files) {
	# Open Configuration File
	my $data = $xml->XMLin($file);

	# if is weekly and sunday create the issue
	if($$data{'weekly'} == 1 and $dow == 0) {
                # Create Issue
                my $call = $jira->call("jira1.createIssue", $auth, $data);

                # Verify if the issue was created successfully
                my $fault = $call->fault();
                if (defined $fault) {
                        die $call->faultstring();
                } else {
                        print "issue created\n";
                }
		next;
	}
	
	# Loop through the times configured
	my @cr8times = split(',',"$$data{'createnow'}");
	foreach(@cr8times) {
		if($_ eq $today) {
			# Create Issue
			my $call = $jira->call("jira1.createIssue", $auth, $data);

			# Verify if the issue was created successfully
			my $fault = $call->fault();
			if (defined $fault) {
				die $call->faultstring();
			} else {
				print "issue created\n";
			}
		}
	}
}

# Jira Logout
$jira->call("jira1.logout", $auth);
exit;
