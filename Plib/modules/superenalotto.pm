#!/usr/bin/perl
# Name: Superenalotto module
# Description: makes 6 random numbers between 1-90 for superenalotto.
# Usage: !superenalotto
# Language: Italian

package Plib::modules::superenalotto;
use strict;
use warnings;

sub new { return $_[0]; }
sub atInit { return 1; }
sub atWhile {
	my ($self, $isTest, $botClass, $sent, $nick, $ident, $host) = @_;
	return 1 if $isTest;
	my $info;
	if ($nick and $ident and $host and $info = $botClass->matchMsg ($sent, 1) and $info->{"message"} =~ /^!superenalotto$/i) {
		my @numbers;
		my @found;
		for (1..6) {
			my $num = int (rand (91));
			while ($botClass->{"functions"}->in_array (\@found, $num)) { $num = int (rand (91)); };
			push @numbers, $num;
			push @found, $num;
		}
		$botClass->sendMsg ($info->{"chan"}, "${nick}: gioca i seguenti numeri, ti porteranno fortuna: " . join (", ", @numbers) . ". Parola di " . $botClass->{"nickname"});
	}
}

1;
