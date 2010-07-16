#!/usr/bin/perl
# PlIB - test plugin
# Author: Robertof

package Plib::plugins::firstplugin;
use strict;
use warnings;

sub new {
	return $_[0];
}

sub atInit {
	my ($self, $isTest, $botClass) = @_;
	return 1 if $isTest;
	$botClass->{"socket"}->send ("PRIVMSG " . $botClass->{"functions"}->hashJoin (",", "", 0, 1, $botClass->{"channels"}) . " :Hello world!\n");
}

sub atWhile {
	my ($self, $isTest, $botClass, $sent, $nick, $ident, $host) = @_;
	return 1 if $isTest;
	my $info;
	if ($nick and $ident and $host and $info = $botClass->matchMsg ($sent) and $info->{"message"} =~ /!info/i) {
		$botClass->{"socket"}->send ("PRIVMSG " . $info->{"chan"} . " :Hi, ${nick}. You wrote a message in " . $info->{"chan"} . ". Your hostmask is ${host} and your ident is ${ident}. Powered by PlIB O:\n");
	}
}

1;
