#!/usr/bin/perl
# Autorejoin plugin
# Author: Robertof
# Description: rejoin automatically when kicked on a channel
# Licence: GNU/GPL v3

package Plib::modules::autorejoin;
use strict;
use warnings;

sub new { return $_[0]; }
sub atInit {};
sub atWhile {
	my ($self, $isTest, $botClass, $sent, $nick, $ident, $host) = @_;
	return 1 if $isTest;
	my $chlist = $botClass->getAllChannels ("|", 0);
	$chlist = $botClass->{"functions"}->trim ($chlist);
	if ($sent =~ /^:?.+?!~?.+?@[^ ]+ KICK (${chlist}) $botClass->{'rc-nick'} :.+/im or $sent =~ /^:[^ ]+ KICK (${chlist}) $botClass->{'rc-nick'} :.+/im) {
		my $chankey = $botClass->{"channels"}->{$1};
		$botClass->{"socket"}->send ("JOIN ${1}" . ( $chankey ? " ${chankey}" : "" ) . "\n");
	}
}

1;
