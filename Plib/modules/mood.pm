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
		"moodtent" => 0
	};
	bless $moodinfo, $_[0];
	return $moodinfo;
}

sub atInit {};
sub atWhile {
	my ($self, $isTest, $botClass, $sent, $nick, $ident, $host) = @_;
	return 1 if $isTest;
	my ($info, $m);
	if ($nick and $ident and $host and $info = $botClass->matchMsg ($sent)) {
		if ($m = $self->matchPlibMess ($botClass, $info->{"message"})) {
			my $lol = $botClass->{"functions"}->trim ($m);
			if ($lol =~ /(gay|sei scemo|idiota|cretino|stupid|idiot|fucking|stronzo|afamm|die|crepa|muori|schifoso|merda|coglione)/i) {
				if ($self->{"moodtent"} >= 3) {
					$self->{"mood"} = "sad" if $self->{"mood"} eq "neutral";
					$self->{"mood"} = "neutral" if $self->{"mood"} eq "happy";
					$self->{"moodtent"} = 0;
					$botClass->sendMsg ($info->{"chan"}, chr (1) . "ACTION is now " . $self->{"mood"} . " :(" . chr (1));
				} else {
					my @phrases = ("you hurt me :(", "you're bad!", "don't hurt me, kthxbye");
					my $phrase = int (rand (3));
					$botClass->sendMsg ($info->{"chan"}, "${nick}: " . $phrases[$phrase]);
					$self->{"moodtent"} += 1;
				}
			} elsif ($lol =~ /(sei bravo|you are good|you're good|good|simpatico|written well|scritto bene|ben fatto|intelligente|figo)/i) {
				if ($self->{"moodtent"} >= 3) {
					$self->{"mood"} = "happy" if $self->{"mood"} eq "neutral";
					$self->{"mood"} = "neutral" if $self->{"mood"} eq "sad";
					$self->{"moodtent"} = 0;
					$botClass->sendMsg ($info->{"chan"}, chr (1) . "ACTION is now " . $self->{"mood"} . chr (1));
				} else {
					my @phrases = ("thank you", "you're good", ":*");
					my $phrase = int (rand (3));
					$botClass->sendMsg ($info->{"chan"}, "${nick}: " . $phrases[$phrase]);
					$self->{"moodtent"} += 1;
				}
			}
		} elsif ($info->{"message"} =~ /^!mood$/) {
			$botClass->sendMsg ($info->{"chan"}, chr (1) . "ACTION is " . $self->{"mood"} . chr (1));
		}
	}
}

sub matchPlibMess {
	my ($self, $botClass, $matchOn) = @_;
	return $1 if ($matchOn =~ /^$botClass->{'rc-nick'} ?[,;: ]?(.+)/i);
	return 0;
}
1;
