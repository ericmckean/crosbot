package stats::tree;

use Coro;
use Coro::Handle;
use Coro::Timer qw(sleep);
use AnyEvent::Socket;

sub checkstat {
	my ($bot) = @_;
	my $g = tcp_connect "chromiumos-status.appspot.com", 80, Coro::rouse_cb;
	my $fh = unblock +(Coro::rouse_wait)[0];

	if (not $fh) {
		$bot->putstat('tree', '?');
		return;
	}

	print $fh "GET /current HTTP/1.1\015\012";
	print $fh "Host: chromiumos-status.appspot.com\015\012";
	print $fh "\015\012";

	while (my $l = <$fh>) {
		$l =~ s/\r?\n//;
		if ($l =~ /<div class=\"status.*?\">(.+)<\/div>/i) {
			my $s = $1;
			$s =~ s/^\s*//;
			$s =~ s/\s*$//;
			$s =~ s/&quot;/"/g;
			$s =~ s/&lt;/</g;
			$s =~ s/&gt;/>/g;
			$s =~ s/&#39;/'/g;
			$bot->putstat('tree', $s);
			return;
		}
	}

	$bot->putstat('tree', '?');
}

sub dostats {
	my ($bot) = @_;
	while (1) {
		sleep 15;
		checkstat $bot;
	}
}

sub addto {
	my ($pkg, $bot) = @_;
	async { dostats $bot };
};

1;
