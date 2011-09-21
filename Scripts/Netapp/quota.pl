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

# Info:
#
# Quota summary to the current user via snmp

use strict;
use Net::SNMP;
my %vols;
my @qtrees;
my @output_q;
my @output_u;

### Snmp Settings
##################
my $s_volume_id_table = ".1.3.6.1.4.1.789.1.4.4.1.2";
my $s_qtree_id_table = ".1.3.6.1.4.1.789.1.5.10.1.5";
my $s_quota_entry = ".1.3.6.1.4.1.789.1.4.6.1";
my $s_quota_entry_usrid = "$s_quota_entry.3";
my $s_quota_entry_type = "$s_quota_entry.2";
my $s_quota_entry_qtree = "$s_quota_entry.14";
my $s_quota_entry_used = "$s_quota_entry.5";
my $s_quota_entry_limit = "$s_quota_entry.8";
my $filer = 'filer1.altair';
my $community = 'altair-snmp';

### User Info
################
my $uid = `echo \$UID`;
chomp($uid);
my $username = `whoami`;
chomp($username);

### Functions
###############
sub _byte_size {
	use constant K => 1024;
	use constant M => K * K;
	use constant G => M * K;
	use constant T => G * K;
	require  Math::Round;
	import Math::Round qw( nearest );
 
	my ($KBytes) = @_;
	return "${KBytes} KB" if $KBytes < K;
	return nearest(1, $KBytes / K ) . " MB" if $KBytes < M;
	return nearest(0.1, $KBytes / M ) . " GB" if $KBytes < G;
	return nearest(0.01, $KBytes / G ) . " TB" if $KBytes < T;
}

sub _create_session {
	my $version = 1;
	my ($sess, $err) = Net::SNMP->session( -hostname => $filer, -version => $version, -community => $community);
	if (!defined($sess)) {
		print "Can't create SNMP session to $filer\n";
		exit(1);
	}
	return $sess;
}

# Establish SNMP Session
our $snmp_session = _create_session;

### Create %vols hash
my $r_vol_tbl = $snmp_session->get_table($s_volume_id_table);
foreach my $key ( keys %$r_vol_tbl) {
		my @tmp_arr = split(/$s_volume_id_table\./, $key);
		$vols{ $tmp_arr[1] } = "$$r_vol_tbl{$key}";
}

### Creating @qtrees array
my $r_qtree_tbl = $snmp_session->get_table($s_qtree_id_table);
foreach my $key ( keys %$r_qtree_tbl) {
	if("$$r_qtree_tbl{$key}" ne ".") {
		my @tmp_arr = split(/\./, $key);
		push(@qtrees,["$tmp_arr[13]","$tmp_arr[14]","$$r_qtree_tbl{$key}"]);
		
	}
}

### Create @output_* arrays
foreach my $array (@qtrees) {
	my $quota_tree;
	my $quota_user;
	my $vol = "@$array[0]";
	my $qtree = "@$array[2]";
	my $r_quota_type_tbl = $snmp_session->get_table("$s_quota_entry_type\.$vol");
	my $r_quota_user_tbl = $snmp_session->get_table("$s_quota_entry_usrid\.$vol");
	
	foreach my $key ( keys %$r_quota_type_tbl) {
		my @quota_oids_arr = split(/$s_quota_entry_type\.$vol/, $key);
		my $quota_oid = "@quota_oids_arr[1]";
		my $raw_oid = ".$vol$quota_oid";
		my $r_qtree_name = $snmp_session->get_request(-varbindlist => ["$s_quota_entry_qtree$raw_oid"]);
		my $qtree_name = $r_qtree_name->{"$s_quota_entry_qtree$raw_oid"};
		
		if($$r_quota_type_tbl{$key} == 3) {
			if("$qtree_name" eq "$qtree") {
				$quota_tree = "$raw_oid";
			}
		} elsif($$r_quota_type_tbl{$key} == 1) {
			if("$qtree_name" eq "$qtree") {
				my $r_uid = $snmp_session->get_request(-varbindlist => ["$s_quota_entry_usrid$raw_oid"]);
				my $user_uid = $r_uid->{"$s_quota_entry_usrid$raw_oid"};
				if("$user_uid" eq "$uid") {
					$quota_user = "$raw_oid";
				}
			}
		}
	}
	
	my @quota_result_user = _get_quota($quota_user);
	my @quota_result_tree = _get_quota($quota_tree);
	if("$quota_user" ne "" and "$quota_tree" ne "") {
		push(@output_q,["$qtree","$quota_result_tree[0]","$quota_result_user[0]","$quota_result_tree[2]","$quota_result_tree[1]"]);
	} elsif("$quota_tree" ne "" and "$quota_user" eq "") {
		push(@output_q,["$qtree","$quota_result_tree[0]","0 KB","$quota_result_tree[2]","$quota_result_tree[1]"]);
	} elsif("$quota_tree" eq "" and "$quota_user" ne "") {
		push(@output_u,["$qtree","$quota_result_user[0]","$quota_result_user[2]","$quota_result_user[1]"]);
	}
}

### Print Report
print " $username Quota\n";
print "--------------------\n";
printf(" %-19.19s\t%-10.10s\t%-10.10s\t%-10.10s\n", "Qtree", "Used", "Free", "Limit");
print("---------------------------------------------------------------\n");
for my $arr (@output_u) {
	printf("%-19.19s\t%-10.10s\t%-10.10s\t%-10.10s\n", @$arr[0], @$arr[1], @$arr[2], @$arr[3]);
}
print "\n\n";
print " Directory Quota\n";
print "------------------\n";
printf(" %-19.19s\t%-10.10s\t%-10.11s\t%-10.10s\t%-10.10s\n", "Qtree", "Total Used", "Used By You", "Free", "Limit");
print("--------------------------------------------------------------------------------\n");
for my $arr (@output_q) {
	printf("%-19.19s\t%-10.10s\t%-10.10s\t%-10.10s\t%-10.10s\n", @$arr[0], @$arr[1], @$arr[2], @$arr[3], @$arr[4]);
}

### Functions
###############
sub _get_quota {
	my ($oid) = @_;
	my $kb_used_oid = "$s_quota_entry_used$oid";
	my $kb_limit_oid = "$s_quota_entry_limit$oid";
	my $result = $snmp_session->get_request(-varbindlist => [$kb_used_oid, $kb_limit_oid]);
	my $used = _byte_size($result->{$kb_used_oid});
	my $limit = _byte_size($result->{$kb_limit_oid});
	my $free;
	if($result->{$kb_limit_oid} == 0) {
		$free = 0;
	} else {
		$free = $result->{$kb_limit_oid} - $result->{$kb_used_oid};
	}
	my $free_h = _byte_size($free);
	my @return = ("$used","$limit","$free_h","$result->{$kb_used_oid}","$result->{$kb_limit_oid}","$free");
	return @return;
}

exit();
