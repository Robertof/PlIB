#!/usr/bin/perl

###############################################################
# @name..................................................plib #
# @realname.......................................PerL IrcBot #
# @author............................................Robertof #
# @mail.....................................robertof@anche.no #
# @licence..........................................GNU/GPL 3 #
# @lang..................................................Perl #
# @requirements...IO::Socket::INET or IO::Socket::SSL for SSL #
# @isthisfinished.........................................yes #
#                            Enjoy                            #
###############################################################

package Plib::functions;
use strict;
use warnings;

sub new {
	return $_[0];
}

sub checkVars {
	shift;
	foreach (@_) {
		return 0 if not defined $_;
	}
	return 1;
}

# Usage: hashJoin (keyvalueSeparator, valueSeparator, onlyValues, onlyKeys, hash)
# Example:
# print $x->hashJoin (' => ', ', ', 0, 0, {ciao => 'mondo'})
# Works only with hash references

sub hashJoin {
	my ($self, $kvsep, $valsep, $onlyVals, $onlyKeys, $hash) = @_;
	my $retval;
	foreach my $key (keys %{$hash}) {
		$retval .= $key . $kvsep . $hash->{$key} . $valsep if not $onlyKeys and not $onlyVals;
		$retval .= $hash->{$key} . $valsep if $onlyVals and not $onlyKeys;
		$retval .= $key . $valsep if $onlyKeys and not $onlyVals;
	}
	return substr ($retval, 0, (length ($retval) - length ($valsep)));
}

# Thx to phpjs for this function
sub preg_quote {
	my $str = $_[1];
	$str =~ s/([\\\.\+\*\?\[\^\]\$\(\)\{\}\=\!<>\|\:])/\\$1/g;
	return $str;
}

sub matchServerNumeric {
	my ($self, $rcnick, $rcserver, $numeric, $onWhat) = @_;
	return 1 if ($onWhat =~ /^:${rcserver} ${numeric} ${rcnick}/im);
	return 0;
}

sub trim {
	my $str = $_[1];
	$str =~ s/^(\n|\r|\r\n|\s)//;
	$str =~ s/(\n|\r|\r\n|\s)$//;
	return $str;
}
1;
