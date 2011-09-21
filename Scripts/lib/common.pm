# Search for a string in an array (usually for excluding hosts, queue or whatever)
sub _is_exclude(@) {
	my $return = 0;
	my $value = shift;
	my @x_list = @_;
	foreach(@x_list) {
		if($value =~ /$_/) {
			$return++;
			last;
		}
	}
	return($return);
}

# Convert from bytes to human readable format
sub _byte_size($) {
	use constant K => 1024;
	use constant M => K * K;
	use constant G => M * K;
	use constant T => G * K;
	use constant P => T * K;
	
	require  Math::Round;
	import Math::Round qw( nearest );
	
	my ($KBytes) = @_;
	return "${KBytes} B" if $KBytes < K;
	return nearest(1, $KBytes / K ) . " KB" if $KBytes < M;
	return nearest(0.1, $KBytes / M ) . " MB" if $KBytes < G;
	return nearest(0.01, $KBytes / G ) . " GB" if $KBytes < T;
	return nearest(0.001, $KBytes / T ) . " TB" if $KBytes < P;
}

