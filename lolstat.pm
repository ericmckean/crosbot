package lolstat;

use Coro;
use Coro::Timer qw(sleep);

sub putstats {
	my ($bot) = @_;
	my $lulz = 0;
	while (1) {
		sleep 1;
		$bot->putstat('lulz', $lulz);
	}
}

sub addto {
	my ($class, $bot) = @_;
	async { putstats($bot) };
}

1;
