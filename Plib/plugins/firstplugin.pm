#!/usr/bin/perl
###############################################################
# @name.....................................plib first plugin #
# @realname.......................................PerL IrcBot #
# @author............................................Robertof #
# @mail.....................................robertof@anche.no #
# @licence..........................................GNU/GPL 3 #
# @lang..................................................Perl #
# @requirements...IO::Socket::INET or IO::Socket::SSL for SSL #
# @isthisfinished.........................................yes #
#                            Enjoy                            #
###############################################################

package Plib::plugins::firstplugin;
use strict;
use warnings;

sub new {
	return $_[0];
}

sub atInit {
	my ($self, $isTest, $botClass) = @_;
	return 1 if $isTest;
	$botClass->sendMsg ($botClass->{"functions"}->hashJoin (",", "", 0, 1, $botClass->{"channels"}), "Hello world!");
}

sub atWhile {
	my ($self, $isTest, $botClass, $sent, $nick, $ident, $host) = @_;
	return 1 if $isTest;
	my $info;
	if ($nick and $ident and $host and $info = $botClass->matchMsg ($sent) and $info->{"message"} =~ /^!info/i) {
		$botClass->sendMsg ($info->{"chan"}, "Hi, ${nick}. You wrote a message in " . $info->{"chan"} . ". Your hostmask is ${host} and your ident is ${ident}. Powered by PlIB O:");
	}
}

1;
