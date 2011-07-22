package stats::sheriff;

use Coro;
use Coro::Handle;
use Coro::Timer qw(sleep);
use AnyEvent::Socket;

sub checkstats {
	my ($bot) = @_;
	my $g = tcp_connect "build.chromium.org", 80, Coro::rouse_cb;
	my $fh = unblock +(Coro::rouse_wait)[0];

	print "sheriff: ready...\n";

	if (not $fh) {
		$bot->putstat('sheriff', 'sheriff', '?');
		return;
	}

	print $fh "GET /p/chromiumos/sheriff.js HTTP/1.1\015\012";
	print $fh "Host: build.chromium.org\015\012";
	print $fh "\015\012";

	print "sheriff: request...\n";

	local $/ = undef;
	while (my $l = <$fh>) {
		print "Response: '$l'\n";
		if ($l =~ /^document\.write\('(.*)'\)/) {
			my $sheriffs = $1;
			$bot->putstat('sheriff', 'sheriff', $sheriffs);
			return;
		}
	}
	$bot->putstat('sheriff', 'sheriff', '?');
}

sub dostats {
	my ($bot) = @_;
	checkstats $bot;
	while (1) {
		sleep 15;
		checkstats $bot;
	}
}

sub addto {
	my ($class, $bot) = @_;
	async { dostats $bot };
}

1;
