#!/usr/bin/perl

###############################################################
# @name..................................................plib #
# @realname.......................................PerL IrcBot #
# @author............................................Robertof #
# @mail.....................................robertof@anche.no #
# @licence..........................................GNU/GPL 3 #
# @lang..................................................Perl #
# @requirements...IO::Socket::INET or IO::Socket::SSL for SSL #
# @isthisfinished.........................................yes #
#                            Enjoy                            #
###############################################################

package Plib::main;
use strict;
use warnings;
use Plib::functions;
use Plib::sockutil;
use threads;
use threads::shared;

# Main constructor
sub new {
	my ($cname, $nickname, $username, $realname, $idpass, $isOp, $debug, $usessl, $server, $port) = @_;
	my $functions = Plib::functions->new();
	die ("Plib error -- Missing parameters!\n") if not $functions->checkVars ($nickname, $username, $realname, $idpass, $isOp, $debug, $usessl, $server, $port);
	my $options = {
		"nickname"       => $nickname,
		"username"       => $username,
		"realname"       => $realname,
		"idpass"         => $idpass,
		"isOp"           => $isOp,
		"debug"          => $debug,
		"usessl"         => $usessl,
		"server"         => $server,
		"port"           => $port,
		"channels"       => 0,
		"functions"      => $functions,
		"hooked_modules" => {},
		"hooked_events"  => {}
	};
	bless $options, $cname;
	$options->{"socket"} = Plib::sockutil->new ($server, $port, $usessl, $options);
	$options->{"rc-server"} = $functions->preg_quote ($options->{"server"});
	$options->{"rc-nick"}   = $functions->preg_quote ($options->{"nickname"});
	$options->{"flood"} = {};
	share ($options->{"flood"}); # For flood detection with threads
	$SIG{"INT"} = sub { $options->secureQuit ("Caught SIGINT") };
	return $options;
}

sub secureQuit {
	my ($self, $why) = @_;
	print "\n[!] ${why}, killing flood thread..\n";
	$self->{"floodthread"}->kill ("KILL")->detach();
	if ($self->{"socket"}->{"sock"}) {
		print "[~] Closing connection..\n";
		$self->{"socket"}->closeConnection ("${why}, closing connection");
	}
	print "[+] Well done, bye\n";
	exit 0;
}

# setChans function (required !)
sub setChans {
	my $self = shift;
	my $whatToReturn = {};
	foreach my $chan (@_) {
		my @kc = split /:/, $chan;
		my $chan = $kc[0];
		$chan = "#" . $chan if (substr ($chan, 0, 1) ne "#");
		# Channel has a key
		if (scalar (@kc) > 1) {
			my $key = pop (@kc);
			$chan = join ":", @kc;
			$chan = "#" . $chan if (substr ($chan, 0, 1) ne "#");
			$whatToReturn->{$chan} = $key;
		} else {
			$whatToReturn->{$chan} = 0;
		}
	}
	$self->{"channels"} = $whatToReturn;
	print "[DEBUG] Function 'setChans' called from module 'main', channels to join: " . $self->{"functions"}->hashJoin ("", ", ", 0, 1, $whatToReturn) . "\n" if $self->isDebug;
	return 1;
}

sub isDebug {
	return $_[0]->{"debug"};
}

sub hook_modules {
	my $self = shift;
	foreach my $moduleName (@_) {
		print "[~] Hooking module $moduleName..\n";
		my $fpn = "Plib::modules::${moduleName}";
		eval "require ${fpn}";
		die "[!] Sorry, your module doesn't exist / is not valid. It must be in 'modules' directory\n    and must have 'package Plib::modules::modulename' at the beginning.\n    Error: $@\n" if $@;
		eval "${fpn}->atInit (1);${fpn}->atWhile (1)";
		die "[!] Your module is not valid. It must have the methods 'atInit' and 'atWhile'.\n    Error: $@\n" if $@;
		eval "\$fpn = ${fpn}->new()";
		die "[!] Your module must have 'new' method.\n    Detailed error: $@\n" if $@;
		print "[~] Hooking module events..\n";
		eval "${fpn}->events (1);";
		$fpn->events (0, $self) if not $@;
		$self->{"hooked_modules"}->{$moduleName} = $fpn;
		print "[+] Hooked module ${moduleName} :D\n";
	}
}

# Modules only
sub hook_event {
	my ($self, $module, $event, $func) = @_;
	print "[DEBUG] Module '${event}' is hooking event '${event}'..\n";
	$self->{"hooked_events"}->{$module}->{$event} = $func;
	print "[DEBUG] Event hooked.\n";
}

# Script only
sub evfunc {
	my ($self, $evname) = @_;
	# Prevent, if event is not found, script killing by adding
	# a default empty sub in return value.
	my $func = sub {};
	foreach (keys %{$self->{"hooked_events"}}) {
		if (exists $self->{"hooked_events"}->{$_}->{$evname}) {
			$func = $self->{"hooked_events"}->{$_}->{$evname};
			last;
		}
	}
	return $func;
}

sub getAllChannels {
	my ($self, $chanSeparator, $withKey, $keySeparator) = @_;
	return ($withKey ? $self->{"functions"}->hashJoin ($keySeparator, $chanSeparator, 0, 0, $self->{"channels"}) : $self->{"functions"}->hashJoin ("", $chanSeparator, 0, 1, $self->{"channels"}));
}

sub sendMsg {
	my ($self, $to, $what) = @_;
	$what =~ s/\r//g;
	if (length ($what) > 255) {
		# Prevent too long messages
		# (tester of this part are welcome)
		$self->{"socket"}->send ("PRIVMSG ${to} :" . substr ($what, 0, 255) . "\r\n");
		$self->sendMsg ($to, substr ($what, 255));
	} else {
		$what = join ("\r\nPRIVMSG ${to} :", split /\n/, $what);
		$self->{"socket"}->send ("PRIVMSG ${to} :${what}\r\n");
	}
}

sub matchMsg {
	my ($self, $onWhat) = @_;
	my $chlist = $self->getAllChannels ("|", 0, "");
	if ($onWhat =~ /^(:?.+?!~?.+?@[^ ]+) PRIVMSG (${chlist}) :(.+)/i) {
		return {
					userinfo => $self->{"functions"}->trim ($1) ,
					chan     => $self->{"functions"}->trim ($2) ,
					message  => $self->{"functions"}->trim ($3)
			   };
	} else {
		return 0;
	}
}

sub getUserData {
	my ($self, $onWhat) = @_;
	if ($onWhat =~ /^:?(.+?)!~?(.+?)@([^ ]+).+/) {
		return {
					nick => $self->{"functions"}->trim ($1),
					ident=> $self->{"functions"}->trim ($2),
					host => $self->{"functions"}->trim ($3)
			   };
	} else {
		return 0;
	}
}

sub startAll {
	my $self = shift;
	die "Please run 'setChans (chan1, chan2:key, chan3)' first.\n" if (not $self->{"channels"});
	print "[+] Bot info ..\n";
	print "    Joining: " . $self->getAllChannels (", ", 0) . "\n";
	print "    At: " . $self->{"server"} . ":" . $self->{"port"} . "\n";
	print "    With modules: " . $self->{"functions"}->hashJoin ("", ", ", 0, 1, $self->{"hooked_modules"}) . "\n";
	print "    And with nickname: " . $self->{"nickname"} . "\n\n";
	$self->{"floodthread"} = threads->new (sub {
		print "[+] Flooding check thread started\n";
		while (1) {
			foreach (keys %{$self->{"flood"}}) {
				delete $self->{"flood"}->{$_};
			}
			sleep (3);
		}
	});
	my $sockClass = $self->{"socket"}->startConnection;
	my $sock = $sockClass->getSock;
	&{$self->evfunc("conn_start")}($self);
	$sockClass->send ("USER " . $self->{"username"} . " 0 * :" . $self->{"realname"} . "\n");
	$sockClass->send ("NICK " . $self->{"nickname"} . "\n");
	&{$self->evfunc("while_begin")}($self);
	$self->doWhile;
}

sub doWhile {
	my $self = $_[0];
	my ($nick, $ident, $host, $chans);
	my $sockClass = $self->{"socket"};
	my $sock = $sockClass->getSock;
	while (my $ss = <$sock>) {
		print $ss if $self->isDebug;
		$ss = $self->{"functions"}->trim ($ss);
		$sockClass->send ("PONG :$1\n") if ( $ss =~ /^PING :(.+)/si );
		($nick, $ident, $host) = ($self->{"functions"}->trim ($1), $self->{"functions"}->trim ($2), $self->{"functions"}->trim ($3)) if ($ss =~ /^:?(.+?)!~?(.+?)@([^ ]+).+/);
		# Match numeric 376 (end of motd) or 422 (no motd), and send join / identify commands + exec modules
		if ($self->{"functions"}->matchServerNumeric ($self->{"rc-nick"}, $self->{"rc-server"}, 376, $ss) or $self->{"functions"}->matchServerNumeric ($self->{"rc-nick"}, $self->{"rc-server"}, 422, $ss)) {
			$self->send ( "PRIVMSG NickServ :IDENTIFY $self->{'idpass'}\n" ) if ($self->{"idpass"});
			&{$self->evfunc("identify")}($self);
			print "[DEBUG] Matched server numeric\n" if $self->isDebug;
			$chans = $self->getAllChannels ("\nJOIN ", 1, " ");
			$chans =~ s/ 0$//gm;
			$sockClass->send ("JOIN " .  $chans . "\n");
			&{$self->evfunc("join")}($self);
			&{$self->evfunc("b_inmod")}($self);
			foreach (keys %{$self->{"hooked_modules"}}) {
				$self->{"hooked_modules"}->{$_}->atInit (0, $self);
			}
			&{$self->evfunc("a_inmod")}($self);
		} else {
			# Check for flooding attempts, if yes, don't execute plugins
			if ($host) {
				$self->{"flood"}->{$host} = 0 if (not exists $self->{"flood"}->{$host});
				if ($self->{"flood"}->{$host} <= 1) {
					&{$self->evfunc("b_whmod")}($self);
					foreach (keys %{$self->{"hooked_modules"}}) {
						eval "\$self->{'hooked_modules'}->{$_}->atWhile (1)";
						if (not $@) {
							$self->{"hooked_modules"}->{$_}->atWhile (0, $self, $ss, $nick, $ident, $host);
						} else {
							&{$self->evfunc("invalid_mod")}($self);
							delete $self->{"hooked_modules"}->{$_};
						}
					}
					&{$self->evfunc("a_whmod")}($self);
				} else {
					&{$self->evfunc("floodattempt")} ($self, $nick, $ident, $host);
				}
				$self->{"flood"}->{$host} += 1 if $self->{"flood"}->{$host};
				&{$self->evfunc("floodincrement")}($self);
			}
		}
	}
	&{$self->evfunc("while_end")}($self); # Useful for autoreconnect plugins
}
1;
