our $ldap_host = "ldap.com";
our $ldap_bind_dn = "CN=LDAP Query User,OU=Some OU,DC=domainname";
our $ldap_bind_passwd = "";
our $ldap_user = "";

sub _get_ad_entries(@) {
	my $host = shift;
	my $bind_dn = shift;
	my $bind_passwd = shift;
	my $base = shift;
	my $scope = shift;
	my $filter = shift;
	my $attrs = shift;
	my @return;
	
	my $ldap = Net::LDAP->new ( $host ) or die "$@";
	my $mesg = $ldap->bind ( $bind_dn, password => $bind_passwd, version => 3 );
	my $result = $ldap->search ( base => $base, scope => $scope, attrs => $attrs, filter => $filter);
	my @entries = $result->entries;
	foreach my $entr ( @entries ) {
		my $dn = $entr->dn;
		foreach my $attr ( sort $entr->attributes ) {
			next if ( $attr =~ /;binary$/ );
			my $cn = $entr->get_value($attr);
			push(@return,"\L$cn");
		}
	}
	return(@return);
	$ldap->unbind;
}

sub _get_lastlogin_entries(@) {
	my $host = shift;
	my $bind_dn = shift;
	my $bind_passwd = shift;
	my $base = shift;
	my $scope = shift;
	my $filter = shift;
	my $attrs = ["lastLogonTimestamp"];
	my $days_old = shift;
	my @return;

	my $ldap = Net::LDAP->new ( $host ) or die "$@";
	my $mesg = $ldap->bind ( $bind_dn, password => $bind_passwd, version => 3 );
	my $result = $ldap->search ( base => $base, scope => $scope, attrs => $attrs, filter => $filter);
	my @entries = $result->entries;
	foreach my $entr ( @entries ) {
		my $dn = $entr->dn;
		foreach my $attr ( sort $entr->attributes ) {
			next if ( $attr =~ /;binary$/ );
			my $lastLoginTime = $entr->get_value($attr);
			my @formatedll = split('-',POSIX::strftime( "%F", localtime(($lastLoginTime/10000000)-11644473600)));
			my $Dd = Delta_Days($formatedll[0],$formatedll[1],$formatedll[2],$script_time[2],$script_time[1],$script_time[0]);
			if($Dd >= $days_old) {
				push(@return,["$dn","@formatedll","$Dd"]);
			}
		}
	}
	
	return(@return);
	$ldap->unbind;
}

sub _get_mail_addr($) {
	my $username = shift;
	my @mail = _get_ad_entries($ldap_host,$ldap_bind_dn,$ldap_bind_passwd,"DC=altair","sub","(&(!(userAccountControl:1.2.840.113556.1.4.803:=2))(objectClass=user)(sAMAccountName=$username))",["mail"]);
	return($mail[0]);
}