#!/usr/bin/perl
# Ignore module
# Author: Robertof
# Description: ignores an user without executing 'while' plugins when his nick is detected.
# Usage: !ignore (add|del|list) [user]
# WARNING: CONFIGURE MODULE IN 'NEW' METHOD!
# Licence: GNU/GPL v3

package Plib::modules::ignore;

use warnings;
use strict;

# /!\ CONFIGURE PLUGIN HERE !! /!\ #
sub new {
	# -- begin configuration -- #
	my @owners = ("Robertof"); # Who can ignore and deignore an user ?
	my $id_check = 1; # Should bot check if the owners are identified (this makes 100% safe admin-functions of the plugin, but requires /msg nickserv identify)
	my $guestCanList = 0;      # Can non-owners list ignores?
	# -- end   configuration -- #
	my $options = {
		"guestcanlist"   => $guestCanList,
		"owners"         => \@owners,
		"idchk"          => $id_check,
		"list"           => {}
	};
	bless $options, $_[0];
	return $options;
}

sub depends {
	return [] unless $_[0]->{"idchk"};
	return ["idcheck"];
}

sub events {
	my ($s, $test, $class) = @_;
	return if $test;
	$class->hook_event ("ignore", "b_whmod", sub {
		my ($mc, $sent, $nick) = @_;
		$nick = lc ($nick);
		return 1 if $sent !~ /^:([^\s]+)!~?([^\s]+)@([^ ]+) (PRIVMSG|NOTICE)/i;
		return 1 if not exists $mc->{"hooked_modules"}->{"ignore"}->{"list"}->{$nick};
		return 0 if exists $mc->{"hooked_modules"}->{"ignore"}->{"list"}->{$nick};
		return 1;
	});
}

sub atInit {};
sub atWhile {
	my ($self, $isTest, $botClass, $sent, $nick, $ident, $host) = @_;
	return 1 if $isTest;
	my $info;
	if ($nick and $ident and $host and $info = $botClass->matchMsg ($sent, 1)) {
		if ($info->{"message"} =~ /^!ignore (add|del|list) ?([^\s]+)?$/i) {
			my $action = lc ($1);
			my $user = ( $2 ? lc ($2) : "" );
			return 0 if ($action =~ /(add|del)/ and not $user);
			return 0 if not $self->havePerms ($nick, $action, $botClass);
			if ($action eq "list") {
				return if $botClass->{"functions"}->hashJoin ("", ", ", 0, 1, $self->{"list"}) eq "";
				$botClass->sendMsg ($info->{"chan"}, "Ignore list: " . $botClass->{"functions"}->hashJoin ("", ", ", 0, 1, $self->{"list"}));
			} elsif ($action eq "add") {
				return if exists $self->{"list"}->{$user};
				$self->{"list"}->{$user} = 1;
				$botClass->sendMsg ($info->{"chan"}, "Now I will ignore ${user}.");
			} elsif ($action eq "del") {
				return if not exists $self->{"list"}->{$user};
				delete $self->{"list"}->{$user};
				$botClass->sendMsg ($info->{"chan"}, "Now I won't ignore ${user}.");
			}
		}
	}
}

sub havePerms {
	my ($self, $who, $forwhat, $mainClass) = @_;
	return 0 if $forwhat eq "list" and not $self->{"guestcanlist"} and not $mainClass->{"functions"}->in_array ($self->{"owners"}, $who);
	return 0 if not $mainClass->{"functions"}->in_array ($self->{"owners"}, $who) and $forwhat ne "list";
	return ( $self->{"idchk"} ? $mainClass->{"hooked_modules"}->{"idcheck"}->isIdentified ($who, $mainClass) : 1 );
}

1;
