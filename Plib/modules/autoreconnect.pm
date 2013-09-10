#!/usr/bin/perl
# Autoreconnect plugin
# Author: Robertof
# Description: autoreconnect automatically when killed (or when script is not killed with secureQuit)
# Licence: GNU/GPL v3

package Plib::modules::autoreconnect;
use strict;
use warnings;

sub new { return $_[0]; }
sub atInit {};
sub events {
	my ($s, $test, $class) = @_;
	return if $test;
	$class->hook_event ("autoreconnect", "while_end", sub {
		print "[!] Bot killed, quitted, or something like this. Autoreconnecting.\n";
		my $botClass = shift;
		$botClass->{"socket"}->closeConnection ("Why are you reading this message?");
		my $sockClass = $botClass->{"socket"}->startConnection;
		my $sock = $sockClass->getSock;
		&{$botClass->evfunc("conn_start")}($botClass, $sockClass);
		$sockClass->send ("USER " . $botClass->{"username"} . " 0 * :" . $botClass->{"realname"} . "\n");
		$sockClass->send ("NICK " . $botClass->{"nickname"} . "\n");
		&{$botClass->evfunc("while_begin")}($botClass);
		$botClass->doWhile (0);
	});
}

sub atWhile {}

1;
