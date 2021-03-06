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
# Show user data from AD

use strict;
use Net::LDAP;

my $ldap_host = "";
my $base = "";
my $scope = "";
my $attrs = ["telephoneNumber","physicalDeliveryOfficeName","name","mail","sAMAccountName"];
my $bind_dn = "";
my $bind_passwd = "";
my $usr_input;
my $printf = " %-15.15s\t%-9.9s\t%-12.12s\t%-35.35s\t%-10.10s\n";
my $sep = '*----------------------------------------------------------------------------------------------------------*';

my $ldap = Net::LDAP->new ( $ldap_host ) or die "$@";
my $mesg = $ldap->bind ( "$bind_dn", password => "$bind_passwd", version => 3 );

my $result = $ldap->search ( base => "$base", scope => "sub", attrs => $attrs, filter => '(&(!(objectClass=computer))(objectClass=user))');
my $href = $result->as_struct;
my @arrayOfDNs  = sort keys %$href;

if($#ARGV == -1) {
       $usr_input = "no";
} else {
	if($ARGV[0] eq "help") {
		print "Syntax: $0\n";
		print "$0 help\n";
		print "$0\n";
		print "$0 'Search String'\n";
		exit(1);
	} else {
		$usr_input = $ARGV[0];
	}
}

print "$sep\n";
printf($printf, "Name", "Office", "Cellular", "Mail", "Username");
print "$sep\n";

foreach ( @arrayOfDNs ) {
#	print $_, "\n";
	my $valref = $$href{$_};

	# get an array of the attribute names
	# passed for this one DN.
	my @arrayOfAttrs = sort keys %$valref; #use Attr hashes

	my $attrName;
	my $name = "Na";
	my $mail = "Na";
	my $physicalDeliveryOfficeName = "Na";
	my $telephonenumber = "Na";
	my $SAM = "Na";
	foreach $attrName (@arrayOfAttrs) {
		chomp($attrName);
		# skip any binary data: yuck!
		next if ( $attrName =~ /;binary$/ );
		
		# get the attribute value (pointer) using the
		# attribute name as the hash
		
		my $attrVal =  @$valref{$attrName};
		if("$attrName" eq "telephonenumber") {
			$telephonenumber = "@$attrVal";
		} 
		if("$attrName" eq "mail") {
			$mail = "@$attrVal";
		}
		if("$attrName" eq "physicaldeliveryofficename") {
			$physicalDeliveryOfficeName = "@$attrVal";
		}
		if("$attrName" eq "name") {
			$name = "@$attrVal";
		}
		if("$attrName" eq "samaccountname") {
			$SAM = "@$attrVal";
		}
	}
	
	if($usr_input eq "no") {
		printf($printf, $name,$physicalDeliveryOfficeName,$telephonenumber,$mail,$SAM);
	} else {
		if($name =~ /$usr_input/i) {
			printf($printf, $name,$physicalDeliveryOfficeName,$telephonenumber,$mail,$SAM);
		}
	}
}

print "$sep\n";



$ldap->unbind;
