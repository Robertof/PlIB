#!/usr/bin/perl
# PlIB's Googlefight module
# Description: battles given keywords based on amount of google search results and announces the winner
# BASED ON: rbot's plugin googlefight
# Originally written by: Raine Virta <rane@kapsi.fi>
# Usage: !googlefight keyword1 keyword2 [keyword3 ...]

package Plib::modules::googlefight;
use strict;
use warnings;
use LWP::UserAgent;
use URI::Escape;

sub new { return $_[0]; }
sub atInit { return 1; }
sub atWhile {
	my ($self, $isTest, $botClass, $sent, $nick, $ident, $host) = @_;
	return 1 if $isTest;
	my $info;
	if ($nick and $ident and $host and $info = $botClass->matchMsg ($sent) and $info->{"message"} =~ /^!(?:googlefight|gf) (.+)$/i) { #yeah, must use .+ here for splitting with spaces
		my @splitted = split / /, $1;
		return $botClass->sendMsg ($info->{"chan"}, "Max 10 keywords!") if (scalar (@splitted) > 10);
		return $botClass->sendMsg ($info->{"chan"}, "Min 2 keywords!") if (scalar (@splitted) < 2);
		my $results = {};
		my $res;
		my $lwp = LWP::UserAgent->new;
		$lwp->timeout (10);
		$lwp->agent ("Mozilla/5.0 (X11; U; Linux x64; it; rv:1.9.2.13) Gecko/20110207 Firefox/4.0");
		foreach my $_keyword (@splitted) {
			# <div id=resultStats>About 27,800,000 results<nobr>
			$_keyword =  lc ($_keyword);
			$_keyword =~ s/_/ /g;
			next if (exists $results->{$_keyword});
			if ($_keyword eq "freddy 156") { $_keyword = "freddy_156"; }
			$res = $lwp->get ("http://www.google.com/search?hl=en&safe=off&btnG=Search&q=" . uri_escape ($_keyword));
			return $botClass->sendMsg ($info->{"chan"}, "Couldn't request google page, $!") if (not $res->is_success);
			if ($res->decoded_content =~ /About ([^\s]+) results/) {
				my $__x = $1;
				$__x =~ s/,//g;
				if ($_keyword eq "mastercontrol90") { $__x = -2400; }
				$results->{$_keyword} = int ($__x);
			}
		}
		my @keywords = sort { $results->{$b} <=> $results->{$a} } keys %{$results};
		return $botClass->sendMsg ($info->{"chan"}, "Min 2 keywords!") if (scalar (@keywords) < 2);
		my $str = "";
		foreach (@keywords) {
			$str .= "${_} (" . $results->{$_} . " results) vs. ";
		}
		$botClass->sendMsg ($info->{"chan"}, substr ($str, 0, (length ($str) - 5)));
		$botClass->sendMsg ($info->{"chan"}, ".. and the winner is: " . $keywords[0] . " with " . $results->{$keywords[0]} . " results!");
	}
}

1;
