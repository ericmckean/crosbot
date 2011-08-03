package stats::buildbot;

use Coro;
use Coro::Handle;
use Coro::Timer qw(sleep);
use AnyEvent::Socket;

sub checkbot {
	my ($bbname) = @_;
	my $g = tcp_connect "build.chromium.org", 80, Coro::rouse_cb;
	my $fh = unblock +(Coro::rouse_wait)[0];

	my $fname = $bbname;
	$fname =~ s/ /-/g;
	$bbname =~ s/ /%20/g;

	if (not $fh) {
		return "?";
	}

	print $fh "GET /p/chromiumos/builders/$bbname HTTP/1.1\015\012";
	print $fh "Host: build.chromium.org\015\012";
	print $fh "\015\012";

	my $idle = '';

	while (my $l = <$fh>) {
		$l =~ s/\r?\n//;
		if ($l =~ /<h2>no current builds<\/h2>/i) { $idle = ' [idle]'; }
		if ($l =~ /\#(\d+)<\/a>: (.+)<\/li>/i) {
			return "$2$idle";
		}
	}
	return "?";
}

sub checkbots {
	my ($bot) = @_;
	my @bots = ('x86 generic full', 'x86 pineview binary', 'x86 pineview full',
	            'x86 generic pre flight queue', 'arm generic binary',
	            'arm generic full', 'arm tegra2 binary', 'arm tegra2 full');
	my $states;
	my @bad;
	foreach my $b (@bots) {
		my $r = checkbot($b);
		$states->{$b} = $r;
		print "$b: $r\n";
		if ($r =~ /failed/) {
			push @bad, $b;
		}
		sleep 1;
	}

	$bot->putstat('bots', sprintf("%d total, %d bad", scalar(@bots), scalar(@bad)));
	$bot->putstat('sickbots', join(', ', @bad));
}

sub dostats {
	my ($bot, $bbname) = @_;
	checkbots $bot;
	while (1) {
		sleep 15;
		checkbots $bot;
	}
}

sub addto {
	my ($class, $bot, $bbname) = @_;
	async { dostats $bot, $bbname };
}

1;
