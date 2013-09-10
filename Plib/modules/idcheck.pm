#!/usr/bin/perl
# Autorejoin plugin
# Author: Robertof
# Description: check if an user is identified. Provides isIdentified function for all uses
# Need configuration: YES , in NEW method
# Licence: GNU/GPL v3

package Plib::modules::idcheck;
use strict;
use warnings;
use Plib::functions;
# /!\ CONFIGURE PLUGIN HERE !! /!\ #
sub new {
	# -- begin configuration -- #
	my $is_identified_cmd = 1; # Should module provide !identified [nick] command?
	# -- end   configuration -- #
	my $options = {
		"iicmd" => $is_identified_cmd
	};
	bless $options, $_[0];
	return $options;
}

sub atInit {};
sub atWhile {
	my ($self, $isTest, $botClass, $sent, $nick, $ident, $host) = @_;
	return 1 if $isTest;
	# Hook command if $self->iicmd is true.
	if ($self->{"iicmd"} ne 0) {
		my $info;
		if ($nick and $ident and $host and $info = $botClass->matchMsg ($sent, 1) and $info->{"message"} =~ /^!identified ([^\s]+)$/) {
			$botClass->sendMsg ($info->{"chan"}, ($self->isIdentified ($1, $botClass) ? "${1} is identified." : "${1} is not identified / registered."));
		}
	}
}

sub isIdentified {
	my ($self, $nick, $class) = @_;
	my $identified = "NONE";
	my $sock = $class->{"socket"}->getSock;
	print "[IDCHK] Checking ${nick}..\n";
	my $tmp = Plib::functions->new()->preg_quote ($nick);
	print $sock "WHOIS ${nick}\n";
	while (<$sock>) {
		print "[IDCHK - 1st] $_";
		if ($_ =~ /^:[^\s]+ 307 [^\s]+ [^\s]+ :/i) { # 307 is always the correct reply for saying that a nick is identified
			$identified = 1;
			last;
		#[IDCHK - 1st] :aperture.esper.net 330 PlIB Robertof Robertof :is logged in as
		} elsif ($_ =~ /^:[^\s]+ \d+ [^\s]+ [^\s]+ $tmp :is logged in as/i) {
			$identified = 1;
			last;
		} elsif ($_ =~ /^:[^\s]+ 318 [^\s]+ [^\s]+ :/i) {
			last; # Check with 2nd method
		}
	}
	if ($identified eq "NONE") {
		print "[IDCHK] Checking ${nick} with 2nd method..\n";
		print $sock "PRIVMSG NickServ :INFO ${nick}\n";
		while (<$sock>) {
			print "[IDCHK - 2nd] $_";
			if ($_ =~ /^:NickServ![^\s]+@[^\s]+ .+?(is currently online|in questo momento|online)/i) {
				$identified = 1;
				last;
			} elsif ($_ =~ /^:NickServ![^\s]+@[^\s]+ NOTICE.+?(isn't registered|non e' registrato|registrato|registered)/i) {
				$identified = 0;
				last;
			} elsif ($_ =~ /^:NickServ![^\s]+@[^\s]+ NOTICE [^\s]+ :Registered :/) {
				$identified = 1;
				last;
			} elsif ($_ =~ /^:[^\s]+ 401 [^\s]+ [^\s]+ :/i) {
				$identified = 1; # No nickserv no party, which means that the server doesn't have services, which means that everyone is allowed to do everything
				last;
			} elsif ($_ =~ /^:NickServ![^\s]+@[^\s]+ NOTICE.+?(last quit|lingua|seen|quit)/i) {
				$identified = 0;
				last;
			}
		}
	}
	return $identified;
}
1;
