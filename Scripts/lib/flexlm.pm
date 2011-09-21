sub _get_expired_licenses(@) {
	my @return;
	my $flexlm_file = shift;
	my $no_of_days = shift;
	my $now = time();
	my @features = split("\n",`grep ^FEATURE\  $flexlm_file`);
	foreach my $feature (@features) {
		my @row = split(" ",$feature);
		
		my $expiration=str2time($row[4]);
		my $days_to_expiration=$expiration-$now;
		$days_to_expiration/=86400;
		$days_to_expiration=int($days_to_expiration);
		
		if ($days_to_expiration == 0 || $days_to_expiration < 0) {
			push(@return,["$row[2]","$row[1]","ALREADY EXPIRED"]);
		}
		if ($days_to_expiration < $no_of_days && $days_to_expiration > 0)
		{
			push(@return,["$row[2]","$row[1]","Will EXPIRE IN $days_to_expiration DAYS"]);
		}
	}
	
	return(@return);
}