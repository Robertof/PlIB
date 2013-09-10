#!/usr/bin/perl
# Name: IsDown
# Description: checks if a site is down or up.
# Author: Robertof

package Plib::modules::isdown;
use strict;
use warnings;
use LWP::UserAgent;

sub new { return $_[0]; }
sub atInit { return 1; }
sub atWhile {
	my ($self, $isTest, $botClass, $sent, $nick, $ident, $host) = @_;
	return 1 if $isTest;
	my $info;
	if ($nick and $ident and $host and $info = $botClass->matchMsg ($sent, 1) and $info->{"message"} =~ /^!is(?:up|down) (https?:\/\/(?:www\.)?[^\s\.\/]+\.[^\s\.\/]+(?:\.[^\s\.\/]+)?)$/i) {
		my $lwp = LWP::UserAgent->new;
		$lwp->timeout (5);
		$botClass->sendMsg ($info->{"chan"}, "${1}: HEAD request status: " . ($lwp->head ($1)->is_success ? "OK - up & running" : "FAIL - site down or it doesn't exist. NOTE: LWP's timeout is set to 5 seconds, so if a website takes up to 5 seconds to load for me it's offline"));
	}
}

1;
