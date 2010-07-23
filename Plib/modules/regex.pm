#!/usr/bin/perl
package Plib::modules::regex;
use strict;
use warnings;

sub new {
	return $_[0];
}

sub atInit {}

sub atWhile {
	my ($self, $isTest, $botClass, $sent, $nick, $ident, $host) = @_;
	return 1 if $isTest;
	my $info;
	if ($nick and $ident and $host and $info = $botClass->matchMsg ($sent)) {
		if ($info->{"message"} =~ /(.+?) =~ (.+)/i) {
			my ($str, $regex) = ($1, $2);
			print "Matching $regex withd $str\n";
			$str =~ s/'/\'/g;
			$regex =~ s/\//\\\//g;
			my $res = eval "'${str}' =~ /${regex}/";
			$botClass->sendMsg ($info->{"chan"}, "Not a valid regex") if $@;
			if (not $@) {
				$botClass->sendMsg ($info->{"chan"}, "1") if $res;
				$botClass->sendMsg ($info->{"chan"}, "0") if not $res;
			}
		}
	}
}

1;
