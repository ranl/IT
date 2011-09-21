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
# Notify on quota space from a specific nis group
# Configure the variables under Settings
# 
# On line 129 configure a way to get the users email

# Settings
use strict;
use Net::SNMP;
my $s_volume_id_table = ".1.3.6.1.4.1.789.1.4.4.1.2";
my $s_quota_entry = ".1.3.6.1.4.1.789.1.4.6.1";
my $s_quota_entry_usrid = ".1.3.6.1.4.1.789.1.4.6.1.3";
my $s_quota_entry_qtree = ".1.3.6.1.4.1.789.1.4.6.1.14";
my $s_quota_entry_used = ".1.3.6.1.4.1.789.1.4.6.1.5";
my $s_quota_entry_limit = ".1.3.6.1.4.1.789.1.4.6.1.8";
my $community = 'public';
my $filer = 'fileraddr';
my @results;
my $sendmail = "/usr/sbin/sendmail -t";
my $reply_to = "Reply-to: root\@mgmt";
my $send_to = 'To: mailaddr@gmail.com';

sub FSyntaxError {
	print "Syntax Error !\n";
	print "$0 -g=[nis group] -v=[volume] -q=[qtree] -f=[space left in KB] (-dry) \n";
	print "-dry - Don't generate mail msgs\n";
	exit(1);
}

if($#ARGV lt 3 or $#ARGV gt 4) {
        FSyntaxError;
}

# Gather input from user
my $group;
my $vol;
my $qtree;
my $dry = 0;
my $left;
my $left_h;

while(@ARGV) {
	my $temp = shift(@ARGV);
	if($temp =~ /^-g/) {
		my @temp1 = split("=",$temp);
		$group = "@temp1[1]";
	} elsif($temp =~ /^-v/) {
		my @temp1 = split("=",$temp);
		$vol = "@temp1[1]";
	} elsif($temp =~ /^-q/) {
		my @temp1 = split("=",$temp);
		$qtree = "@temp1[1]";
	} elsif($temp =~ /^-f/) {
		my @temp1 = split("=",$temp);
		$left = "@temp1[1]";
		$left_h = _byte_size($left);
	} elsif("$temp" eq "-dry") {
		$dry = 1;
	} else {
		FSyntaxError;
	}
}

# Functions
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
	return nearest(0.01, $KBytes / G ) . " TB" if $KBytes < P;
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
my $snmp_session = _create_session;

# List of Users
my @users = split(",",`ypcat group | grep ^$group: | awk -F\: '{print \$4}'`);

# Getting Volume Id
my $r_vol_tbl = $snmp_session->get_table($s_volume_id_table);
my $volume_oid;
foreach my $key ( keys %$r_vol_tbl) {
	if("$$r_vol_tbl{$key}" eq "$vol") {
		my @volume_oids_arr = split(/$s_volume_id_table/, $key);
		$volume_oid = "$volume_oids_arr[1]";
	}
}
my $r_user_quota_tbl = $snmp_session->get_table($s_quota_entry_usrid . $volume_oid);


# Looping through @users
foreach my $user (@users) {
	chomp($user);
	my $uid = `ypcat passwd | grep ^$user: | awk -F\: '{print \$3}'`;
	chomp($uid);
	my $full = `ypcat passwd | grep ^$user: | awk -F\: '{print \$5}'`;
	chomp($full);
	my $email = "configure a way to get to users email";
	my $user_quota_oid;
	
	# Getting User's Quota Entry
	foreach my $key ( keys %$r_user_quota_tbl) {
		if("$$r_user_quota_tbl{$key}" eq "$uid") {
			my @user_quota_oids_arr = split(/$s_quota_entry_usrid$volume_oid/, $key);
			my $r_qtree_name = $snmp_session->get_request(-varbindlist => ["$s_quota_entry_qtree$volume_oid$user_quota_oids_arr[1]"]);
			if("$r_qtree_name->{$s_quota_entry_qtree . $volume_oid . $user_quota_oids_arr[1]}" eq "$qtree") {
				$user_quota_oid = $user_quota_oids_arr[1];
			}
		}
	}
	
	# Getting Qtree Info
	my $userkb_used_oid = $s_quota_entry_used . $volume_oid . $user_quota_oid;
	my $userkb_limit_oid = $s_quota_entry_limit . $volume_oid . $user_quota_oid;
	my $result = $snmp_session->get_request(-varbindlist => [$userkb_used_oid, $userkb_limit_oid]);
	my $used = _byte_size($result->{$userkb_used_oid});
	my $limit = _byte_size($result->{$userkb_limit_oid});
	my $free = $result->{$userkb_limit_oid} - $result->{$userkb_used_oid};
	my $free_h = _byte_size($free);
	if($free < $left) {
		push(@results,["$user","$free_h","$email"]);
	}
}
if($dry == 0) {
	if($#results != -1) {
		foreach(@results) {
			print "@$_\n";
			open(SENDMAIL, "|$sendmail") or die "Cannot open $sendmail: $!";
			print SENDMAIL $reply_to,"\n";
			print SENDMAIL "Subject: Quota Notification ($qtree)\n";
			print SENDMAIL $send_to," $email\n";
			print SENDMAIL "Content-type: text/plain\n\n";
			print SENDMAIL "Quota Issues Summary for @$_[0] in $qtree:\n\n";
			print SENDMAIL "@$_[1] space left in $qtree\t@$_[2]\n";
			close(SENDMAIL); 
		}
	}
}
