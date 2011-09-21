# Isn't it obvious ;)
sub _ping_check {
	my $phost = shift;
	my $return = `ping -c 1 $phost &> /dev/null ; echo \$?`;
	chomp($return);
	return($return);
}

# Evaluate a nmap file (grepable format) and create a hash
sub _eval_nmap($) {
	my $file = shift;
	if ( ! -e $file) { return(1); }
	my %hosts;
	open(NMAPOUT, $file);
	while (<NMAPOUT>) {
		# Skip if comment
		if($_ =~ /^\#/) { next; }
		chomp($_);
		
		my @l = split(' ',$_);
		shift(@l);
		splice(@l,2,1); 
		
		my $addr = shift(@l);
		my $dnsname = shift(@l);
		$dnsname =~ s/(\(|\))//g;
		$hosts{$addr}{"dnsname"} = $dnsname;
		foreach my $port (@l) {
			my @portstate = split('/',$port);
			$hosts{$addr}{$portstate[0]} = "$portstate[1]";
		}
	}
	close(NMAPOUT); 
	return(%hosts);
}

# guess OS type by ports
sub _os_guess($) {
	my $host = shift;
	my $nc = `which nc`; chomp($nc);
	$nc = "$nc -w 1";
	my $ssh = `$nc $host 22 &>/dev/null ; echo \$?`; chomp($ssh);
	my $msrpc = `$nc $host 135 &>/dev/null ; echo \$?`; chomp($msrpc);
	
	if($msrpc == 0) {
		return('win');
	} elsif($ssh == 0) {
		return('linux');
	} else {
		return('unknown');
	}
}