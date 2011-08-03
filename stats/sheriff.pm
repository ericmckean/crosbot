package stats::sheriff;

use Coro;
use Coro::Handle;
use Coro::Timer qw(sleep);
use Fcntl;
use AnyEvent::Socket;
use IO::Handle '_IONBF';

sub checkstat {
	my ($bot, $suffix) = @_;
	my $g = tcp_connect "build.chromium.org", 80, Coro::rouse_cb;
	my $fh = unblock +(Coro::rouse_wait)[0];
	my $sheriffs = '?';

	if (not $fh) {
		return $sheriffs;
	}

	print $fh "GET /p/chromiumos/sheriff$suffix.js HTTP/1.1\015\012";
	print $fh "Host: build.chromium.org\015\012";
	print $fh "\015\012";

	my $buf;
	my $n;
	while ($fh->read($n, 1) and $n ne ')') {
		$buf .= $n;
	}

	if ($buf =~ /document\.write\('(.*)'/) {
		$sheriffs = $1;
	}

	return $sheriffs;
}

sub checkstats {
	my ($bot) = @_;
	my $s0 = checkstat($bot, '');
	my $s1 = checkstat($bot, '2');
	$bot->putstat('sheriffs', "$s0, $s1");
}

sub dostats {
	my ($bot) = @_;
	checkstats $bot;
	while (1) {
		sleep 60;
		checkstats $bot;
	}
}

sub addto {
	my ($class, $bot) = @_;
	async { dostats $bot };
}

1;
