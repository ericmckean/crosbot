package stats::const;

my $stats = {
	'troopers' => 'djmm, scottz, bradnelson, maruel (EST), kliegs (EST)',
};

sub addto {
	my ($class, $bot) = @_;
	foreach my $stat (keys %$stats) {
		$bot->putstat($stat, $stats->{$stat});
	}
}

1;
