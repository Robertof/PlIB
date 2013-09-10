#!/usr/bin/perl
# Poll module / Italian
# Author: Robertof
# Description: none
# Usage: !poll start [time_limit] msg , !poll stop , !poll vote yes, !poll vote no
# WARNING: CONFIGURE MODULE IN 'NEW' METHOD!
# Licence: GNU/GPL v3

package Plib::modules::poll;
use strict;
use warnings;
use threads;
use threads::shared;

# /!\ CONFIGURE PLUGIN HERE !! /!\ #
sub new {
	# -- begin configuration -- #
	my @owners = ("Robertof", "Doch", "stoke", "Kn0t", "Omniscent", "nessuno"); # Who can start/stop pools
	my $id_check = 1; # Should bot check if the owners are identified (this makes 100% safe admin-functions of the plugin, but requires /msg nickserv identify)
	# -- end   configuration -- #
	my $options = {
		"owners"         => \@owners,
		"idchk"          => $id_check,
		"active_poll"    => 0
	};
	bless $options, $_[0];
	share ($options->{"active_poll"});
	return $options;
}

sub depends {
	return [] unless $_[0]->{"idchk"};
	return ["idcheck"];
}

sub atInit {};
sub atWhile {
	my ($self, $isTest, $botClass, $sent, $nick, $ident, $host) = @_;
	return 1 if $isTest;
	my $info;
	if ($nick and $ident and $host and $info = $botClass->matchMsg ($sent, 0)) {
		if ($info->{"message"} =~ /^!poll (start|stop)(\s\d+)?(\s.+)?$/i and $self->havePerms ($nick, $botClass)) {
			my ($action, $time_limit, $message) = (lc ($1), ((defined ($3) and substr ($2, 1) ne "") ? int (substr ($2, 1)) : 300), (defined ($3) ? substr ($3, 1) : (defined ($2) ? substr ($2, 1) : undef)));
			if ($action eq "start" and not defined $message) {
				$botClass->sendMsg ($info->{"chan"}, "${nick}: devi specificare il testo del sondaggio");
				return;
			} elsif ($action eq "stop" and not $self->{"active_poll"}) {
				$botClass->sendMsg ($info->{"chan"}, "${nick}: non c'è nessun sondaggio da terminare!");
				return;
			} elsif ($action eq "start" and $self->{"active_poll"}) {
				$botClass->sendMsg ($info->{"chan"}, "${nick}: un sondaggio è attualmente attivo. Usa !poll stop per terminarlo!");
				return;
			} elsif ($time_limit < 60) {
				$botClass->sendMsg ($info->{"chan"}, "${nick}: il tempo limite da te scelto (${time_limit} secondi) è troppo basso (min 60 secondi)");
				return;
			} elsif ($time_limit > 600) {
				$botClass->sendMsg ($info->{"chan"}, "${nick}: il tempo limite da te scelto (${time_limit} secondi) è troppo alto (max 600 secondi)");
				return;
			} elsif ($botClass->{"functions"}->trim ($message) eq "" and $action eq "start") {
				$botClass->sendMsg ($info->{"chan"}, "${nick}: devi specificare un testo valido.");
				return;
			}
			if ($action eq "start") {
				$botClass->sendMsg ($info->{"chan"}, "** ${nick} ha avviato un sondaggio: ${message} **");
				$botClass->sendMsg ($info->{"chan"}, "** ${time_limit} secondi (" . ($time_limit % 60 == 0 ? ($time_limit / 60) : sprintf ("%.2f", ($time_limit / 60))) . " minuti) di tempo per rispondere: !poll vote no per votare no e !poll vote yes per votare sì. **");
				$self->{"active_poll"} = shared_clone ([$info->{"chan"}, $time_limit, $message, {}, {}, undef]); # channel, time limit, msg, list of hostmasks who voted yes, the same for no, thread
				$self->genThread ($botClass);
			} else {
				my $yes_count = scalar (keys ($self->{"active_poll"}->[3]));
				my $no_count  = scalar (keys ($self->{"active_poll"}->[4]));
				$botClass->sendMsg ($self->{"active_poll"}->[0], "** ${nick} ha terminato il sondaggio **");
				$botClass->sendMsg ($self->{"active_poll"}->[0], "** Voti: SÌ: " . $yes_count . ", NO: " . $no_count . "; risultato: " . ($yes_count > $no_count ? "i SÌ vincono" : ($yes_count < $no_count ? "i NO vincono" : "parità!")) . " **");
				#$self->{"active_poll"}->[5]->detach() unless $self->{"active_poll"}->[5]->is_detached();
				$self->{"active_poll"} = 0;
			}
		} elsif ($info->{"message"} =~ /^!poll vote (yes|no)$/i and $self->{"active_poll"}) {
			my $action = lc ($1);
			if (exists $self->{"active_poll"}->[3]->{$host} or
			    exists $self->{"active_poll"}->[4]->{$host}) {
				$botClass->sendMsg ($info->{"chan"}, "${nick}: hai già votato per questo sondaggio!");
				return;
			}
			if ($action eq "yes") {
				$self->{"active_poll"}->[3]->{$host} = 1;
				$botClass->sendMsg ($info->{"chan"}, "${nick} ha votato SÌ!");
			} else {
				$self->{"active_poll"}->[4]->{$host} = 1;
				$botClass->sendMsg ($info->{"chan"}, "${nick} ha votato NO!");
			}
		} elsif ($info->{"message"} =~ /^!poll voteself (yes|no)$/i and $self->{"active_poll"} and $self->havePerms ($nick, $botClass)) {
			my $act = lc ($1);
			if ($act eq "yes") {
				$self->{"active_poll"}->[3]->{int(rand(50))+3} = 1;
				$botClass->sendMsg ($info->{"chan"}, "Ho votato sì!");
			} else {
				$self->{"active_poll"}->[4]->{int(rand(50))+3} = 1;
				$botClass->sendMsg ($info->{"chan"}, "Ho votato no!");
			}
		}
	}
}

sub havePerms {
	my ($self, $nick, $mainClass) = @_;
	return 0 if not $mainClass->{"functions"}->in_array ($self->{"owners"}, $nick);
	return ( $self->{"idchk"} ? $mainClass->{"hooked_modules"}->{"idcheck"}->isIdentified ($nick, $mainClass) : 1 );
}

sub genThread {
	my $self = shift;
	my $bc   = shift;
	$self->{"active_poll"}->[5] = shared_clone (threads->new (
		sub {
			my ($daMainClass) = @_;
			if (not $self->{"active_poll"}) {
				threads->detach();
				threads->exit();
			}
			my $max_time     = $self->{"active_poll"}->[1];
			my $current_time = 0;
			while (1) {
				if ($current_time >= $max_time) {
					my $yes_count = scalar (keys ($self->{"active_poll"}->[3]));
					my $no_count  = scalar (keys ($self->{"active_poll"}->[4]));
					$daMainClass->sendMsg ($self->{"active_poll"}->[0], "** Tempo limite raggiunto! **");
					$daMainClass->sendMsg ($self->{"active_poll"}->[0], "** Voti: SÌ: " . $yes_count . ", NO: " . $no_count . "; risultato: " . ($yes_count > $no_count ? "i SÌ vincono" : ($yes_count < $no_count ? "i NO vincono" : "parità!")) . " **");
					$self->{"active_poll"} = 0;
					threads->detach();
					threads->exit();
				}
				$current_time += 1;
				sleep (1);
			}
		}
	, $bc));
}
1;
