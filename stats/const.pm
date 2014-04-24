package stats::const;

my $stats = {
	'troopers' => 'email chrome-infra?',
	'waterfall' => 'http://build.chromium.org/p/chromiumos/waterfall',
};

sub addto {
	my ($class, $bot) = @_;
	foreach my $stat (keys %$stats) {
		$bot->putstat($stat, $stats->{$stat});
	}
}

1;
