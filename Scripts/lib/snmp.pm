sub _create_session(@) {
	my $snmp_host = shift;
	my $commu = shift;
	my $version = 1;
	my ($sess, $err) = Net::SNMP->session( -hostname => $snmp_host, -version => $version, -community => $commu);
	if (!defined($sess)) {
		return 1;
	}
	return $sess;
}

sub _get_oid_value(@) {
	my $sess = shift;
	my $local_oid = shift;
	my $r_return = $sess->get_request(-varbindlist => [$local_oid]);
	return($r_return->{$local_oid});
}