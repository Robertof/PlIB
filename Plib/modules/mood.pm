#!/usr/bin/perl
# Bot mood
# Author: Robertof
# Description: bot mood :D
# Usage: insult or praise bot || !mood
# Licence: GNU/GPL v3

package Plib::modules::mood;
use warnings;
use strict;

sub new {
	my $moodinfo = {
		"mood" => "neutral",
		"moodtent" => 0,
		"rage" => 0
	};
	bless $moodinfo, $_[0];
	return $moodinfo;
}

sub events {
	my ($s, $test, $class) = @_;
	return if $test;
	$class->hook_event ("mood", "b_whmod", sub {
		my ($mc, $sent, $nick) = @_;
		if ($mc->{"hooked_modules"}->{"mood"}->{"rage"}) {
			my $info;
			my $phrases = [
				"SEI UN FOTTUTO BASTARDO",
				"TI ODIO, VAFFANCULO",
				"CREPA",
				"MUORI SOTTO UN TRENO",
				"TI AUGURO DI AVERE UN FUTURO PESSIMO",
				"VAFFANCULO",
				"CHIEDIMI SCUSA, BASTARDO SENZA PALLE!"
			];
			if ($info = $mc->matchMsg ($sent)) {
				if (lc ($nick) eq lc ($mc->{"hooked_modules"}->{"mood"}->{"rage"})) {
					my $r = int (rand ((scalar (@{$phrases})-1)));
					$mc->sendMsg ($info->{"chan"}, "${nick}: " . $phrases->[$r]);
				}
			}
		}
		return 1;
	});
}

sub atInit {};
sub atWhile {
	my ($self, $isTest, $botClass, $sent, $nick, $ident, $host) = @_;
	return 1 if $isTest;
	my ($info, $m);
	if ($nick and $ident and $host and $info = $botClass->matchMsg ($sent)) {
		if ($m = $self->matchPlibMess ($botClass, $info->{"message"})) {
			my $lol = $botClass->{"functions"}->trim ($m);
			if ($lol =~ /(gay|sei scemo|idiota|cretino|stupid|idiot|fucking|stronzo|afamm|die|crepa|muori|schifoso|merda|coglione|vaffanculo|stronzo|minchione|ti odio)/i) {
				if ($self->{"moodtent"} >= 2) {
					return if $self->{"rage"} ne 0;
					if ($self->{"mood"} eq "ultra-sad") {
						$botClass->sendMsg ($info->{"chan"}, "${nick}, ti odio! Mi hai offeso! Me ne vado! :'(");
						$botClass->{"nickname"} = "PlIB_INCAZZATO";
						$botClass->{"rc-nick"}  = $botClass->{"functions"}->preg_quote ($botClass->{"nickname"});
						$botClass->{"socket"}->send ("PART " . $info->{"chan"} . "\n");
						$botClass->{"socket"}->send ("NICK " . $botClass->{"nickname"} . "\n");
						sleep (5);
						$botClass->{"socket"}->send ("JOIN " . $info->{"chan"} . "\n");
						$botClass->sendMsg ($info->{"chan"}, "SONO INCAZZATO. SI', CON TE, CARO ${nick}");
						$botClass->sendMsg ($nick, "MORIRAI");
						$self->{"rage"} = $nick;
						return;
					}
					$self->{"mood"} = "ultra-sad" if $self->{"mood"} eq "sad";
					$self->{"mood"} = "sad" if $self->{"mood"} eq "neutral";
					$self->{"mood"} = "neutral" if $self->{"mood"} eq "happy";
					$self->{"moodtent"} = 0;
					$botClass->sendMsg ($info->{"chan"}, chr (1) . "ACTION is now " . $self->{"mood"} . " :'(" . chr (1));
				} else {
					my @phrases = ("fuck you!", "you're bad!", "shut the fuck up!", "mothafucka'!", "bitch!", "pussygirl!", "dumbass!", "dumbfuck!", "hipster!", "http://www.youtube.com/watch?v=pC2mv1oWXNQ");
					my $phrase = int (rand (scalar (@phrases)));
					$botClass->sendMsg ($info->{"chan"}, "${nick}: " . $phrases[$phrase]);
					$self->{"moodtent"} += 1;
				}
			} elsif ($lol =~ /(sei bravo|you are good|you're good|good|simpatico|written well|scritto bene|ben fatto|intelligente|figo|scusa|ti amo|tvb)/i) {
				print "[DEBUG] matching ${nick} with " . $self->{"rage"} . "\n";
				if (lc ($nick) eq lc ($self->{"rage"})) {
					$botClass->sendMsg ($info->{"chan"}, "Ok ${nick}, ti perdono: non farlo piu' che mi offendi :(");
					$botClass->{"nickname"} = "PlIB";
					$botClass->{"rc-nick"}  = $botClass->{"functions"}->preg_quote ($botClass->{"nickname"});
					$botClass->{"socket"}->send ("NICK " . $botClass->{"nickname"} . "\n");
					$self->{"rage"} = 0;
					$self->{"mood"} = "happy";
					return;
				}
				elsif ($self->{"rage"}) { return; }
				if ($self->{"moodtent"} >= 2) {
					$self->{"mood"} = "happy" if $self->{"mood"} eq "neutral";
					$self->{"mood"} = "neutral" if $self->{"mood"} eq "sad";
					$self->{"mood"} = "sad" if $self->{"mood"} eq "ultra-sad";
					$self->{"mood"} = "ultra-sad" if $self->{"mood"} eq "depressed";
					$self->{"moodtent"} = 0;
					$botClass->sendMsg ($info->{"chan"}, chr (1) . "ACTION is now " . $self->{"mood"} . chr (1));
				} else {
					my @phrases = ("thank you", "you're good", ":*", "<3");
					my $phrase = int (rand (3));
					$botClass->sendMsg ($info->{"chan"}, "${nick}: " . $phrases[$phrase]);
					$self->{"moodtent"} += 1;
				}
			}
		} elsif ($info->{"message"} =~ /^!mood$/) {
			$botClass->sendMsg ($info->{"chan"}, chr (1) . "ACTION is " . $self->{"mood"} . chr (1));
		} elsif ($info->{"message"} =~ /^!resetmood$/) {
			$self->{"rage"} = 0;
			$self->{"mood"} = "happy";
		}
	}
}

sub matchPlibMess {
	my ($self, $botClass, $matchOn) = @_;
	return $1 if ($matchOn =~ /^$botClass->{'rc-nick'} ?[,;: ]?(.+)/i);
	return 0;
}
1;
