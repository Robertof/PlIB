#!/usr/bin/perl

###############################################################
# @name..................................................plib #
# @realname.......................................PerL IrcBot #
# @author............................................Robertof #
# @mail.............................robertofrenna@myopera.com #
# @licence..........................................GNU/GPL 3 #
# @lang..................................................Perl #
# @requirements...IO::Socket::INET or IO::Socket::SSL for SSL #
#                            Enjoy                            #
###############################################################

package Plib::main;
use strict;
use warnings;
use Plib::functions;
use Plib::sockutil;
use threads;
use threads::shared;
use Term::ANSIColor qw(:constants);

$TERM::ANSIColor::AUTORESET = 1;
$| = 1;

# Main constructor
sub new {
	my ($cname, $nickname, $username, $realname, $idpass, $isOp, $debug, $usessl, $server, $port, $sighandling) = @_;
	$sighandling = 1 if not defined $sighandling;
	my $functions = Plib::functions->new();
	die ("PlIB error -- Missing parameters!\n") if not $functions->checkVars ($nickname, $username, $realname, $idpass, $isOp, $debug, $usessl, $server, $port);
	my $options = {
		"nickname"       => $nickname,
		"username"       => $username,
		"realname"       => $realname,
		"idpass"         => $idpass,
		"isOp"           => $isOp,
		"debug"          => $debug,
		"usessl"         => $usessl,
		"server"         => $server,
		"prefix"         => $server,
		"port"           => $port,
		"channels"       => 0,
		"functions"      => $functions,
		"hooked_modules" => {},
		"modules_deps"   => {},
		"hooked_events"  => {}
	};
	bless $options, $cname;
	$options->{"socket"} = Plib::sockutil->new ($server, $port, $usessl, $options);
	$options->{"rc-nick"}   = $functions->preg_quote ($options->{"nickname"});
	$options->{"flood"} = {};
	$options->{"blacklist"} = {};
	share ($options->{"flood"}); # For flood detection with threads
	share ($options->{"blacklist"}); # as above
	if ($sighandling) {
		$SIG{"INT"} = $SIG{"TERM"} = sub { $options->secureQuit ("Caught SIG" . $_[0]) }; # Signal catching
		$SIG{"HUP"} = "IGNORE";
	}
	return $options;
}

sub getPrefix {
	return BOLD "[" . $_[0]->{"prefix"} . "] " . RESET;
}

sub secureQuit {
	my ($self, $why) = @_;
	&{$self->evfunc("onkill")}($self);
	exit if not $self->{"floodthread"};
	print "\n" . $self->getPrefix . "[!] ${why}, killing flood thread..\n";
	$self->{"floodthread"}->kill ("TERM")->detach();
	#print $self->getPrefix . "[~] Unhooking modules.. ";
	#foreach (keys %{$self->{"hooked_modules"}}) {
	#	$self->unhook_module ($_);
	#	print "$_ ";
	#}
	#print "\n";
	if ($self->{"socket"}->{"sock"}) {
		print $self->getPrefix . "[~] Closing connection..\n";
		$self->{"socket"}->closeConnection ("${why}");
	}
	print $self->getPrefix . "[+] Well done, bye\n";
	exit 0;
}

# setChans function (required !)
sub setChans {
	my $self = shift;
	my $whatToReturn = {};
	my @arr = @_;
	if (ref ($_[0]) eq "ARRAY") {
		@arr = @{$_[0]};
	}
	foreach my $chan (@arr) {
		my @kc = split /:/, $chan;
		my $chan = $kc[0];
		$chan = "#" . $chan if (substr ($chan, 0, 1) ne "#");
		# Channel has a key
		if (scalar (@kc) > 1) {
			my $key = pop (@kc);
			$chan = join ":", @kc;
			$chan = "#" . $chan if (substr ($chan, 0, 1) !~ /[#&]/);
			$whatToReturn->{$chan} = $key;
		} else {
			$whatToReturn->{$chan} = 0;
		}
	}
	$self->{"channels"} = $whatToReturn;
	return 1;
}

sub isDebug {
	return $_[0]->{"debug"};
}

sub hook_modules {
	my $self = shift;
	print $self->getPrefix . "[~] Hooking modules: ";
	foreach my $moduleName (@_) {
		my $fpn = "Plib::modules::${moduleName}";
		my $depends;
		eval "require ${fpn}";
		die "\n" . $self->getPrefix . "[!] Error while hooking ${moduleName}: Sorry, your module doesn't exist / is not valid. It must be in 'modules' directory\n    and must have 'package Plib::modules::modulename' at the beginning.\n    Error: $@\n" if $@;
		eval "\$fpn = ${fpn}->new()";
		die "\n" . $self->getPrefix . "[!] Error while hooking ${moduleName}: Your module must have 'new' method.\n    Detailed error: $@\n" if $@;
		undef $@;
		$self->{"modules_deps"}->{$moduleName} = [];
		eval "\$depends = \$fpn->depends()";
		unless ($@) {
			if (ref ($depends) eq "ARRAY") {
				foreach (@{$depends}) {
					die ("\n" . $self->getPrefix . "[!] Module error (${moduleName}): dependency ${_} is not satisfied.\n") if (not exists $self->{"hooked_modules"}->{$_});
					push @{$self->{"modules_deps"}->{$moduleName}}, $_;
				}
			}
		} else { die "\n" . $self->getPrefix . "[!] Module ${moduleName}'s depends function error: $@\n" if $@ !~ /object method "depends"/i; }
		undef $@;
		eval "\$fpn->atInit (1);\$fpn->atWhile (1)";
		die "\n" . $self->getPrefix . "[!] Error while hooking ${moduleName}: Your module is not valid. It must have the methods 'atInit' and 'atWhile'.\n    Error: $@\n" if $@;
		undef $@;
		$self->{"hooked_modules"}->{$moduleName} = $fpn;
		eval "\$fpn->events (1);";
		$fpn->events (0, $self) if not $@;
		print "${moduleName} ";
	}
	print "\n" . $self->getPrefix . "[+] Successfully hooked all modules.\n";
}

sub check_dependencies {
	my ($self, $mtc) = @_;
	foreach (keys %{$self->{"modules_deps"}}) {
		return $_ if ($self->{"functions"}->in_array ($self->{"modules_deps"}->{$_}, $mtc));
	}
	return 0;
}

sub unhook_module {
	my ($self, $module, $suppress_dependency_check) = @_;
	return if not exists $self->{"hooked_modules"}->{$module};
	if (not $suppress_dependency_check and my $porn = $self->check_dependencies ($module)) {
		die ($self->getPrefix . "[-] Error: cannot unload module '${module}' because is required by '${porn}'");
	}
	#print $self->getPrefix . "[~] Unhooking module ${module}..\n";
	&{$self->evfunc("module_unhooked")}($self, $module);
	my $realname = "Plib::modules::${module}";
	eval "no ${realname}";
	delete $self->{"hooked_modules"}->{$module};
	delete $self->{"hooked_events"}->{$module} if exists $self->{"hooked_events"}->{$module};
	delete $self->{"modules_deps"}->{$module} if exists $self->{"modules_deps"}->{$module};
	#print $self->getPrefix . "[+] Done.\n";
}

# Modules only
sub hook_event {
	my ($self, $module, $event, $func) = @_;
	if (!$self->{"hooked_modules"}->{$module}) {
		print $self->getPrefix . "[DEBUG] hook_event function killed (reason: module '${module}' doesn't exist)\n";
		return;
	}
	$self->{"hooked_events"}->{$module}->{$event} = $func;
}

# Script only
sub evfunc {
	my ($self, $evname) = @_;
	# Prevent, if event is not found, script killing by adding
	# a default sub in return value.
	my $func = sub { return 1; };
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
	if (length ($what) > 400) {
		# Prevent too long messages
		$self->{"socket"}->send ("PRIVMSG ${to} :" . substr ($what, 0, 255) . "\r\n");
		$self->sendMsg ($to, substr ($what, 255));
	} else {
		$what = join ("\r\nPRIVMSG ${to} :", split /\n/, $what);
		$self->{"socket"}->send ("PRIVMSG ${to} :${what}\r\n");
	}
}

sub matchMsg {
	my ($self, $onWhat) = @_;
	my $allowQueries = ( defined $_[2] ? $_[2] : 1 );
	my $chlist = ( $allowQueries ? $self->{"rc-nick"} . "|" . $self->getAllChannels ("|", 0, "") : $self->getAllChannels ("|", 0, "") );
	if ($onWhat =~ /^:([^\s]+)!~?([^\s]+)@([^ ]+) PRIVMSG (${chlist}) :(.+)/i) {
		return {
					chan     => ( lc ($4) eq lc ($self->{"nickname"}) ? $self->{"functions"}->trim ($1) : $self->{"functions"}->trim ($4) ) ,
					message  => $self->{"functions"}->trim ($5) ,
					isPrivate=> ( lc ($4) eq lc ($self->{"nickname"}) ? 1 : 0 )
			   };
	} else {
		return 0;
	}
}

sub setFloodInfo {
	my ($self, $host, $floodCount) = @_;
	# [0] is flood-count, [1] is flood entry creating time
	$self->{"flood"}->{$host} = shared_clone ([$floodCount, time]);
}

sub startAll {
	my $self = shift;
	die $self->getPrefix . "Please run 'setChans (chan1, chan2:key, chan3)' first.\n" if (not $self->{"channels"});
	print $self->getPrefix . "[+] Bot info ..\n";
	print $self->getPrefix . "    Joining: " . $self->getAllChannels (", ", 0) . "\n";
	print $self->getPrefix . "    At: " . $self->{"server"} . ":" . $self->{"port"} . "\n";
	print $self->getPrefix . "    With modules: " . $self->{"functions"}->hashJoin ("", ", ", 0, 1, $self->{"hooked_modules"}) . "\n";
	print $self->getPrefix . "    And with nickname: " . $self->{"nickname"} . "\n\n";
	my $sockClass = $self->{"socket"}->startConnection;
	my $sock = $sockClass->getSock;
	&{$self->evfunc("conn_start")}($self, $sockClass);
	$sockClass->send ("USER " . $self->{"username"} . " 0 * :" . $self->{"realname"} . "\n");
	$sockClass->send ("NICK " . $self->{"nickname"} . "\n");
	$self->doWhile (1);
}

sub doWhile {
	my ($self, $execPlugins) = @_;
	my ($nick, $ident, $host, $chans);
	my $sockClass = $self->{"socket"};
	my $sock = $sockClass->getSock;
	&{$self->evfunc("floodchk_begin")}($self);
	if ( not defined $self->{"floodthread"} ) {
		$self->{"floodthread"} = threads->new (sub {
			my $class = shift;
			print $self->getPrefix . "[+] Flooding check thread started\n";
			while (1) {
				foreach (keys %{$self->{"flood"}}) {
					next if (ref ($self->{"flood"}->{$_}) ne "ARRAY" or $self->{"flood"}->{$_}->[0] eq 0);
					print $self->getPrefix . "[FLOOD] checking " . time . " - " . $self->{"flood"}->{$_}->[1] . "\n";
					if ( ( time - $self->{"flood"}->{$_}->[1] ) >= 3) {
						print $self->getPrefix . "[FLOOD] 3 seconds passed, deleting $_\n";
						delete $self->{"flood"}->{$_};
					}
				}
				# Check for bans
				foreach (keys %{$self->{"blacklist"}}) {
					if ( ( time - $self->{"blacklist"}->{$_} ) >= 120 ) {
						print $self->getPrefix . "[FLOOD] Un-blacklisting hostmask ${_}\n";
						delete $self->{"blacklist"}->{$_};
						#$class->sendMsg ($class->getAllChannels (",", 0), "Notice: hostmask ${_} un-blacklisted");
					}
				}
				sleep (1);
			}
		}, $self);
	}
	&{$self->evfunc("while_begin")}($self);
	while (my $ss = <$sock>) {
		print $self->getPrefix . $ss if $self->isDebug;
		$ss = $self->{"functions"}->trim ($ss);
		$sockClass->send ("PONG :$1\n") if ( $ss =~ /^PING :(.+)/si );
		# Fixed regex for matching nick, user and host.
		# It was matching :something test blabla bla some!worldisnice@notsomuch.com too :(
		($nick, $ident, $host) = ($self->{"functions"}->trim ($1), $self->{"functions"}->trim ($2), $self->{"functions"}->trim ($3)) if ($ss =~ /^:([^\s]+)!~?([^\s]+)@([^\s]+)/);
		# Match numeric 376 (end of motd) or 422 (no motd), and send join / identify commands
		if ($self->{"functions"}->matchServerNumeric (376, $ss) or $self->{"functions"}->matchServerNumeric (422, $ss)) {
			$self->sendMsg ("NickServ", "IDENTIFY " . $self->{"idpass"}) if $self->{"idpass"};
			&{$self->evfunc("post_identify")}($self);
			print $self->getPrefix . "[DEBUG] Matched server numeric\n" if $self->isDebug;
			$chans = $self->getAllChannels ("\nJOIN ", 1, " ");
			$chans =~ s/ 0$//gm;
			$sockClass->send ("JOIN " .  $chans . "\n");
			&{$self->evfunc("join")}($self);
			if ($execPlugins) {
				&{$self->evfunc("b_inmod")}($self);
				foreach (keys %{$self->{"hooked_modules"}}) {
					$self->{"hooked_modules"}->{$_}->atInit (0, $self);
				}
				&{$self->evfunc("a_inmod")}($self);
			}
		} else {
			# Check for flooding attempts, if yes, don't execute plugins
			if ($host) {
				if (exists $self->{"flood"}->{$host} and $self->{"flood"}->{$host}->[0] >= 3 and not exists $self->{"blacklist"}->{$host}) {
					print $self->getPrefix . "[FLOOD] Banning ${nick} (${host})\n";
					#$self->sendMsg ($self->getAllChannels (",", 0), "Notice: ${nick} (hostmask: ${host}) was blacklisted for flooding (blacklisted for 120 seconds)");
					$self->{"blacklist"}->{$host} = time;
					&{$self->evfunc("floodchk_ban")} ($self, $nick, $ident, $host);
				}
				
				if ($ss =~ /^:[^ ]+ KICK/i or not exists $self->{"blacklist"}->{$host}) {
					next if &{$self->evfunc("b_whmod")}($self, $ss, $nick, $ident, $host) ne 1;
					print $self->getPrefix . "[FLOOD] Step 2 - check passed\n";
					foreach (keys %{$self->{"hooked_modules"}}) {
						eval "\$self->{'hooked_modules'}->{$_}->atWhile (1)";
						if (not $@) {
							$self->{"hooked_modules"}->{$_}->atWhile (0, $self, $ss, $nick, $ident, $host);
						} else {
							&{$self->evfunc("invalid_mod")}($self);
							print $self->getPrefix . "[-] Module error: ${@}\n";
							delete $self->{"hooked_modules"}->{$_};
						}
					}
					&{$self->evfunc("a_whmod")}($self);
				}
				if ($ss =~ /^:[^\s]+!~?[^\s]+@[^ ]+ PRIVMSG/i) {
					$self->setFloodInfo ($host, 0) if not exists $self->{"flood"}->{$host} or ref ($self->{"flood"}->{$host}) ne "ARRAY";
					$self->{"flood"}->{$host}->[0] += 1;
					print $self->getPrefix . "[FLOOD] ${host}'s flood-count is now " . $self->{"flood"}->{$host}->[0] . " [step 3]\n";
					&{$self->evfunc("floodincrement")}($self);
				}
			}
		}
		($nick, $ident, $host) = ("", "", "");
	}
	&{$self->evfunc("while_end")}($self); # Useful for autoreconnect modules
}
1;
