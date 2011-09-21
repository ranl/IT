our $sge_settings = '/path/to/latest.sh';
our $sge_cmd = "source $sge_settings";
our @queue2exclude = ("nagios.q");

sub _get_sge_current_master() {
	my $act = `$sge_cmd ; cat \$SGE_ROOT/\$SGE_CELL/common/act_qmaster`;
	chomp($act);
	return($act);
}

sub _get_sge_queues() {
	return(split('\n',`$sge_cmd ; qconf -sql`));
}

sub _get_sge_exec_host() {
	return(split('\n',`$sge_cmd ; qconf -sel`));
}

sub _get_sge_admin_host() {
	return(split('\n',`$sge_cmd ; qconf -sh`));
}

sub _get_sge_submit_host() {
	return(split('\n',`$sge_cmd ; qconf -ss`));
}

sub _get_sge_users_jobs() {
	my $xml = new XML::Simple;
	my $qstat_out = `$sge_cmd ; qstat -xml -u \\*`;
	my $data = $xml->XMLin($qstat_out);
	my %jobs_owned;
	foreach my $job (@{$data->{queue_info}->{job_list}}) {
		unless($jobs_owned{$$job{'JB_owner'}}) {
			$jobs_owned{$$job{'JB_owner'}}{'r'} = 0;
			$jobs_owned{$$job{'JB_owner'}}{'p'} = 0;
		}
		$jobs_owned{$$job{'JB_owner'}}{'r'}++ ;
	}
	foreach my $job (@{$data->{job_info}->{job_list}}) {
		unless($jobs_owned{$$job{'JB_owner'}}) {
			unless($jobs_owned{$$job{'JB_owner'}}) { $jobs_owned{$$job{'JB_owner'}}{'r'} = 0; }
			$jobs_owned{$$job{'JB_owner'}}{'p'} = 0;
		}
		$jobs_owned{$$job{'JB_owner'}}{'p'}++ ;
	}

	return(%jobs_owned);
}

sub _get_sge_all_jobs() {
	my $xml = new XML::Simple;
	my $qstat_out = `$sge_cmd ; qstat -xml -u \\*`;
	my $data = $xml->XMLin($qstat_out);
	my %return;
	$return{'running'} = $#{$data->{queue_info}->{job_list}} + 1;
	$return{'pending'} = $#{$data->{job_info}->{job_list}} + 1;
	$return{'all'} = $return{'running'} + $return{'pending'};
	
	return(%return);
}

sub _get_sge_queue_usage() {
	my $xml = new XML::Simple;
	my $qstat_out = `$sge_cmd ; qstat -g c -xml`;
	my $data = $xml->XMLin($qstat_out);
	my %return;
	foreach my $queue (keys %{$data->{cluster_queue_summary}}) {
		$return{$queue}{'used'} = $data->{cluster_queue_summary}->{$queue}->{'used'};
		$return{$queue}{'available'} = $data->{cluster_queue_summary}->{$queue}->{'available'};
	}
	return(%return);
}

sub _get_sge_host_queues() {
	my $xml = new XML::Simple;
	my $qstat_out = `$sge_cmd ; qhost -q -xml`;
	my $data = $xml->XMLin($qstat_out);
	my %return;
	foreach my $execd (keys (%{$data->{host}})) {
		if("$execd" eq "global") { next; }
		$return{$execd} = ();
		foreach my $queue (keys (%{$data->{host}->{$execd}->{"queue"}})) {
			if("$queue" eq "queuevalue") { next; }
			if("$queue" eq "name") { next;}
			if(_is_exclude($queue,@queue2exclude)) { next;}
			my $queue_state = $data->{host}->{$execd}->{"queue"}->{$queue}->{"queuevalue"}->{"state_string"}->{"content"};
			if($queue_state) {
				if($queue_state =~ /d/) { next;}
			}
			
			push(@{$return{$execd}},$queue);
		}

	}
	return(%return);
}

sub _get_sge_queue_hosts() {
	my $xml = new XML::Simple;
	my $qstat_out = `$sge_cmd ; qhost -q -xml`;
	my $data = $xml->XMLin($qstat_out);
	my %return;
	foreach my $execd (keys (%{$data->{host}})) {
		if("$execd" eq "global") { next; }
		foreach my $queue (keys (%{$data->{host}->{$execd}->{"queue"}})) {
			if("$queue" eq "queuevalue") { next; }
			if("$queue" eq "name") { next;}
			if(_is_exclude($queue,@queue2exclude)) { next;}
			my $queue_state = $data->{host}->{$execd}->{"queue"}->{$queue}->{"queuevalue"}->{"state_string"}->{"content"};
			if($queue_state) {
				if($queue_state =~ /d/) { next;}
			}
			
			push(@{$return{$queue}},$execd);
		}

	}
	return(%return);
}