package crosbot;

use AnyEvent::Socket;
use Coro;
use Coro::Handle;

sub cmd_admin {
	my ($self, $src, $dest, $rest) = @_;
	if (defined $rest) {
		if (not $self->isadmin($src)) {
			$self->reply("Admin access required");
			return;
		}
		my @ap = split(/ /, $rest);
		foreach my $a (@ap) {
			if ($a =~ /^\+(\S+)/) {
				push @{$self->{admins}}, lc $1;
			} elsif ($a =~ /^-(\S+)/) {
				$self->{admins} = [ grep { lc($1) ne lc($_) } @{$self->{admins}} ];
			}
		}
	}
	$self->reply("%s", join(' ', $self->{owner}, @{$self->{admins}}));
}

sub cmd_announce {
	my ($self, $src, $dest, $rest) = @_;
	if (not $self->isadmin($src)) {
		$self->reply("Admin access required");
		return;
	}
	if ($dest !~ /^#/) {
		$self->reply("This command can only be used in a channel.");
		return;
	}

	if (defined $rest) {
		my @ap = split(/ /, $rest);
		foreach my $a (@ap) {
			if ($a =~ /^\+(\S+)/) {
				push @{$self->{announce}->{$1}}, $dest;
			} elsif ($a =~ /^-(\S+)/) {
				$self->{announce}->{$1} = [ grep { lc($dest) ne lc($_) } @{$self->{announce}->{$1}} ];
			}
		}
	}

	my @p = ();
	foreach my $a (sort keys %{$self->{announce}}) {
		if (grep { lc($_) eq lc($dest) } @{$self->{announce}->{$a}}) {
			push @p, $a;
		}
	}

	$self->reply('announcing %s', (@p ? join(' ', @p) : '<none>'));
}

sub cmd_help {
	my ($self, $src, $dest, $rest) = @_;
	$self->reply('admin [[+-]<nick>]*, announce [[+-]<class>]*, help, ping,	quiet, speak, stat <stat-name>');
}

sub cmd_ping {
	my ($self, $src, $dest, $rest) = @_;
	$self->reply('pong!');
}

sub cmd_quiet {
	my ($self, $src, $dest, $rest) = @_;
	if (not $self->isadmin($src)) {
		$self->reply('Admin access required');
		return;
	}
	if ($dest !~ /^#/) {
		$self->reply('This command can only be used on a channel.');
		return;
	}
	$self->{quiets}->{lc $dest} = 1;
}

sub cmd_raw {
	my ($self, $src, $dest, $rest) = @_;
	if (not $self->isowner($src)) {
		$self->reply('Owner access required');
		return;
	}
	$self->raw('%s', $rest);
}

sub cmd_speak {
	my ($self, $src, $dest, $rest) = @_;
	if (not $self->isadmin($src)) {
		$self->reply('Admin access required');
		return;
	}
	if ($dest !~ /^#/) {
		$self->reply('This command can only be used on a channel.');
		return;
	}
	delete $self->{quiets}->{lc $dest};
}
	

sub cmd_stat {
	my ($self, $src, $dest, $stat) = @_;
	if (not defined $stat) {
		$self->reply("Stats: %s", join(' ', sort keys %{$self->{stats}}));
		return;
	}
	if (not exists $self->{stats}->{$stat}) {
		$self->reply("No such stat: '%s'", $stat);
	} else {
		$self->reply("%s: %s", $stat, $self->{stats}->{$stat});
	}
}

sub new {
	my ($class, %conf) = @_;
	my $self = {};
	$self->{pass} = delete $conf{pass};
	$self->{host} = delete $conf{host};
	$self->{port} = delete $conf{port} || 6667;
	$self->{nick} = delete $conf{nick};
	$self->{user} = delete $conf{user} || 'crosbot';
	$self->{name} = delete $conf{name} || 'crosbot';
	$self->{chans} = delete $conf{chans} || [];
	$self->{owner} = delete $conf{owner};
	$self->{admins} = delete $conf{admins} || [];
	$self->{stats} = {};
	$self->{quiets} = {};
	$self->{announce} = {};

	$self->{cmds} = {
		admin => \&cmd_admin,
		announce => \&cmd_announce,
		help => \&cmd_help,
		ping => \&cmd_ping,
		quiet => \&cmd_quiet,
		raw => \&cmd_raw,
		speak => \&cmd_speak,
		stat => \&cmd_stat,
	};

	bless $self, $class;
	return $self;
}

sub isadmin {
	my ($self, $who) = @_;
	if (not $self->{cmdsrcid}) { return 0; }
	my @ae = grep { lc($_) eq lc($who) } @{$self->{admins}};
	return (lc($who) eq $self->{owner}) || @ae;
}

sub isowner {
	my ($self, $who) = @_;
	return $self->{cmdsrcid} && (lc($who) eq $self->{owner});
}

sub raw {
	my ($self, $fmt, @args) = @_;
	my $s = $self->{sock};
	my $m = sprintf($fmt, @args);
	print $s "$m\n";
	print "crosbot -> $m\n";
};

sub putstat {
	my ($self, $class, $name, $val) = @_;
	printf "crosbot: putstat %s '%s'\n", $name, $val;
	if ($self->{stats}->{$name} eq $val) { return; }
	$self->{stats}->{$name} = $val;
	if (not exists $self->{announce}->{$class}) { return; }

	foreach my $c (@{$self->{announce}->{$class}}) {
		if (defined($self->{quiets}->{lc $c})) { next; }
		$self->raw("PRIVMSG %s :%s became '%s'", $c, $name, $val);
	}
}

sub reply {
	my ($self, $fmt, @args) = @_;
	if (defined $self->{cmdchan} and $self->{quiets}->{lc($self->{cmdchan})}) {
		return;
	}
	$self->raw("%s%s", $self->{cmdrepl}, sprintf($fmt, @args));
}

sub cmd {
	my ($self, $id, $src, $dest, $cmd, $rest) = @_;
	$self->{cmdsrcid} = $id;
	if ($dest =~ /^#/) {
		$self->{cmdchan} = $dest;
		$self->{cmdrepl} = "PRIVMSG $dest :$src: ";
	} else {
		$self->{cmdrepl} = "NOTICE $src :";
		delete $self->{cmdchan};
	}

	if (exists $self->{cmds}->{$cmd}) {
		my $c = $self->{cmds}->{$cmd};
		$c->($self, $src, $dest, $rest);
	} else {
		$self->reply("No such command '%s'. Try 'help'.", $cmd);
	}
}

sub connected {
	my ($self) = @_;
	$self->raw('CAP REQ identify-msg');
	foreach my $c (@{$self->{chans}}) {
		$self->raw('JOIN %s', $c);
	}
}

sub msged {
	my ($self, $src, $dest, $msg) = @_;
	my $id = ($msg =~ /^\+/ ? 1 : 0);
	$msg =~ s/^.//;

	if ($dest =~ /^#/ and $msg !~ /^crosbot: /) { return; }
	$msg =~ s/^crosbot: //;

	my ($cmd, $rest) = split(/ /, $msg, 2);
	$self->cmd($id, $src, $dest, $cmd, $rest);
}

sub line {
	my ($self, $line) = @_;
	print "crosbot <- $line\n";
	if ($line =~ /^PING (.+)/) {
		$self->raw('PONG %s', $1);
	} elsif ($line =~ /^\S+ 001/) {
		$self->connected();
	} elsif ($line =~ /^:(\S+)!\S+ PRIVMSG (\S+) :(.+)/) {
		$self->msged($1, $2, $3);
	}
}

sub connect {
	my ($self) = @_;

	while (1) {
		print "crosbot: connect\n";

		tcp_connect($self->{host}, $self->{port}, Coro::rouse_cb);
		$self->{sock} = unblock +(Coro::rouse_wait)[0];
		if (not $self->{sock}) {
			sleep 60;
			next;
		}

		$self->raw('PASS %s:%s', $self->{nick}, $self->{pass});
		$self->raw('NICK %s', $self->{nick});
		$self->raw('USER %s "" "" :%s', $self->{user}, $self->{name});

		my $s = $self->{sock};
		while (my $l = <$s>) {
			$l =~ s/\r?\n//;
			$self->line($l);
		}
		sleep 60;
	}
}

sub run {
	my ($self) = @_;
	print "running...\n";
	async { $self->connect };
}

1;
