#!/usr/bin/perl
# no doc!?1?!?!?

package Plib::modules::urandom;
sub new { return $_[0]; }
sub atInit{}
sub atWhile {
	my ($self, $isTest, $botClass, $sent, $nick, $ident, $host) = @_;
	return 1 if $isTest;
	if ($nick and $ident and $host and $info = $botClass->matchMsg ($sent)) {
		if ($info->{"message"} =~ /^!urandom$/i) {
			my $omgstr = `head -1 /dev/urandom`;
			my @os     = split /\n/, $omgstr;
			$omgstr    = substr ($omgstr, 0, 100);
			$botClass->sendMsg ($info->{"chan"}, $omgstr);
		}
	}
}
1;
