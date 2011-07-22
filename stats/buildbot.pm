package stats::buildbot;

use Coro;
use Coro::Handle;
use Coro::Timer qw(sleep);
use AnyEvent::Socket;

sub checkstats {
	my ($bot, $bbname) = @_;
	my $g = tcp_connect "build.chromium.org", 80, Coro::rouse_cb;
	my $fh = unblock +(Coro::rouse_wait)[0];

	my $fname = $bbname;
	$fname =~ s/ /-/g;
	$bbname =~ s/ /%20/g;

	if (not $fh) {
		$bot->putstat('buildbots', $fname, '?');
		return;
	}

	print $fh "GET /p/chromiumos/builders/$bbname HTTP/1.1\015\012";
	print $fh "Host: build.chromium.org\015\012";
	print $fh "\015\012";

	my $idle = '';

	while (my $l = <$fh>) {
		$l =~ s/\r?\n//;
		print "Response: '$l'\n";
		if ($l =~ /<h2>no current builds<\/h2>/i) { $idle = ' [idle]'; }
		if ($l =~ /\#(\d+)<\/a>: (.+)<\/li>/i) {
			$bot->putstat('buildbots', $fname, "$1: $2$idle");
			return;
		}
	}
	$bot->putstat('buildbots', $fname, '?');
}

sub dostats {
	my ($bot, $bbname) = @_;
	sleep(int(rand(10)));
	while (1) {
		sleep 15;
		checkstats $bot, $bbname;
	}
}

sub addto {
	my ($class, $bot, $bbname) = @_;
	async { dostats $bot, $bbname };
}

1;
