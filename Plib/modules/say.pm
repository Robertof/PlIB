#!/usr/bin/perl
# Say
# Author: Robertof
# Description: say something to a channel/user.
# Usage: !say chan what
# WARNING: CONFIGURE MODULE IN 'NEW' METHOD!
# Licence: GNU/GPL v3

package Plib::modules::say;
use strict;
use warnings;

# /!\ CONFIGURE PLUGIN HERE !! /!\ #
sub new {
	# -- begin configuration -- #
	my @owners = ("Robertof"); # Who can say in private / channels ?
	my $acceptprivate = 1;     # Can the !say command be sent from private ?
	my $id_check = 1; # Should bot check if the owners are identified? (this makes 100% safe admin-functions of the plugin, but requires /msg nickserv identify)
	# -- end   configuration -- #
	my $options = {
		"owners"         => \@owners,
		"acceptprivate"  => $acceptprivate,
		"idchk"          => $id_check
	};
	bless $options, $_[0];
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
	if ($nick and $ident and $host and $info = $botClass->matchMsg ($sent, $self->{"acceptprivate"})) {
		if ($info->{"message"} =~ /^!say ([^\s]+) (.+)$/i and $self->havePerms ($nick, $botClass)) {
			$botClass->sendMsg ($1, $botClass->{"functions"}->trim ($2));
		}
	}
}

sub havePerms {
	my ($self, $nick, $mainClass) = @_;
	return 0 if not $mainClass->{"functions"}->in_array ($self->{"owners"}, $nick);
	return ( $self->{"idchk"} ? $mainClass->{"hooked_modules"}->{"idcheck"}->isIdentified ($nick, $mainClass) : 1 );
}

1;
