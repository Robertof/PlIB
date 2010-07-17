#!/usr/bin/perl
# PlIB first plugin
# Author: Robertof
# Licence: WTFPL (hey, it's an 'hello world' plugin!)


package Plib::modules::firstplugin;
use strict;
use warnings;

sub new {
	return $_[0];
}

sub atInit {
	my ($self, $isTest, $botClass) = @_;
	return 1 if $isTest;
	$botClass->sendMsg ($botClass->getAllChannels (",", 0), "Hello world!");
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
