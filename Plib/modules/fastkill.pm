#!/usr/bin/perl
# Fast kill
# Author: Robertof
# Description: kill & restart bot from irc
# Usage: ^C (kill) or ^R (restart)
# WARNING: CONFIGURE MODULE IN 'NEW' METHOD!
# Licence: GNU/GPL v3

package Plib::modules::fastkill;
use warnings;

# /!\ CONFIGURE PLUGIN HERE !! /!\ #
sub new {
	# -- begin configuration -- #
	my @owners = ("Robertof"); # Who can kill and restart bot?
	# -- end   configuration -- #
	my $options = {
		"owners" => \@owners
	};
	bless $options, $_[0];
	return $options;
}

sub atInit {};
sub atWhile {
	my ($self, $isTest, $botClass, $sent, $nick, $ident, $host) = @_;
	return 1 if $isTest;
	my $info;
	if ($nick and $ident and $host and $info = $botClass->matchMsg ($sent)) {
		if ($self->in_array ($self->{"owners"}, $nick)) {
			if ($info->{"message"} =~ /^\^C$/) {
				$botClass->sendMsg ($info->{"chan"}, "Gotta go, bye!");
				$botClass->secureQuit ("Bye guys");
			} elsif ($info->{"message"} =~ /^\^R$/) {
				$botClass->sendMsg ($info->{"chan"}, "Restarting bot :O");
				system ("perl $0 >/dev/null &");
				$botClass->secureQuit ("SIGINT");
			}
		}
	}
}
	
# Thx to go4expert
sub in_array {
	my ($self, $arr, $search_for) = @_;
	foreach my $value (@$arr) {
		return 1 if $value eq $search_for;
	}
	return 0;
}
1;
