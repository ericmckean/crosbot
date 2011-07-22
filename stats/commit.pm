package stats::commit;

use Coro;
use Coro::Handle;
use Coro::Timer qw(sleep);
use AnyEvent::Socket;

sub checkstats {
	my ($bot) = @_;
	my $g = tcp_connect "build.chromium.org", 80, Coro::rouse_cb;
	my $fh = unblock +(Coro::rouse_wait)[0];

	if (not $fh) {
		$bot->putstat('commits', 'last-commit', '?');
		return;
	}

	print $fh "GET /p/chromiumos/waterfall HTTP/1.1\015\012";
	print $fh "Host: build.chromium.org\015\012";
	print $fh "\015\012";

	while (my $l = <$fh>) {
		if ($l =~ /class=\"Change\"><a href=\"\S+\" title=\"(.*?)\">(.*?)<\/a><br>(\S+)<\/td>/i) {
			my ($title, $who, $hash) = ($1, $2, $3);
			$who =~ s/&lt;/</g;
			$who =~ s/&gt;/>/g;
			$who =~ s/&quot;/"/g;
			$who =~ s/&#39;/'/g;
			$bot->putstat('commits', 'last-commit', "$hash: $who '$title'");
			return;
		}
	}
	$bot->putstat('commits', 'last-commit', '?');
}

sub dostats {
	my ($bot) = @_;
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
