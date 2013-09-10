#!/usr/bin/perl
# Name: KARMA module!
# Author: Robertof
# Usage: nick++ , nick-- , nick[:, ] ?(\+\+|--)
#        !karma user
# Licence: GNU/GPL v3
# Requires YAML::XS (yeah, this script uses a yaml database)
package Plib::modules::karma;
use strict;
use warnings;
use YAML::XS;

sub new {
	# ! CONFIGURATION ! #
	my $db = "./Plib/modules/databases/karma/karma.yaml"; # Path to YAML database file - do not change this if not needed
	my $admins = ["Robertof"]; # Who can delete/change karma ?
	my $enable_functions = { # 1 = function enabled, 0 = function disabled
		chkarma    => 1, # (the possibility of changing the karma for every user by admins)
		resetkarma => 1, # (the possibility of resetting the karma for some user by admins)
	}; 
	my $id_check = 1; # Should bot check if the admins are identified? (this makes 100% safe admin-functions of the plugin, but requires /msg nickserv identify)
	# ! END CONF.     ! #
	# Load YAML db
	open FH, "<", $db or die "Error while reading DB file: $!\n";
	# Get content
	my $content;
	$content .= $_ while (<FH>);
	close FH;
	# Parse yaml file
	my $parsed = Load $content;
	# Check if Load returned undef
	$parsed = {} if not defined $parsed;
	# Open the filehandle for writing, then bless all
	my $fh;
	open $fh, ">>", $db or die "Error while opening DB file for writing: $!\n";
	my $final_hash = {
		"db"         => $db,
		"admins"     => $admins,
		"enfunc"     => $enable_functions,
		"idchk"      => $id_check,
		"karma"      => $parsed,
		"filehandle" => $fh
	};
	#die Dumper ($final_hash);
	bless $final_hash, $_[0];
	return $final_hash;
}
sub atInit { return 1; }
sub atWhile {
	my ($self, $isTest, $botClass, $sent, $nick, $ident, $host) = @_;
	return 1 if $isTest;
	my $info;
	if ($nick and $ident and $host and $info = $botClass->matchMsg ($sent, 0)) {
		if ($info->{"message"} =~ /^([a-z0-9\[\]\\`_\^\{\|\}]+)(?:[,: ] )?(\+\+|--)$/i) {
			# TODO: check if the user is in the current chan
			my ($user, $action) = (lc ($1), $2);
			return $botClass->sendMsg ($info->{"chan"}, "${user}: try with ${user}-- ;)") if (lc ($user) eq lc ($nick) and $action eq "++");
			return $botClass->sendMsg ($info->{"chan"}, "${nick}: you can't vote twice!") if (defined $self->{"karma"}->{$user} and lc ($host) eq $self->{"karma"}->{$user}->[1] and $self->{"karma"}->{$user}->[2] eq $action);
			$botClass->sendMsg ($info->{"chan"}, ($action eq "++" ? "${nick}: thx! <3" : "${nick}: fuck you -.-")) if (lc ($user) eq lc ($botClass->{"nickname"}));
			$self->{"karma"}->{$user} = [0, "", ""] if not exists $self->{"karma"}->{$user};
			$self->chkarma ($user, $host, $action);
			delete $self->{"karma"}->{$user} if ($self->{"karma"}->{$user} eq "0");
			$self->resetFilePos;
			print {$self->{"filehandle"}} &Dump ($self->{"karma"});
		} elsif ($info->{"message"} =~ /^!(?:karma|k) ?([a-zA-Z0-9\[\]\\`_\^\{\|\}]+)?$/i) {
			my $user = ( defined $1 ? $1 : $nick );
			$botClass->sendMsg ($info->{"chan"}, "${user}'" . (lc (substr ($user, (length ($user) - 1))) eq "s" ? "" : "s") . " karma" . ((defined $self->{"karma"}->{lc ($user)} and $self->{"karma"}->{lc ($user)}->[0] > 9000) ? " is over 9000!11!11!one (" . $self->{"karma"}->{lc ($user)}->[0] . ")" : ": " . ($self->{"karma"}->{lc ($user)} ? $self->{"karma"}->{lc ($user)}->[0] : "0")));
		}
	} 
	if ($info = $botClass->matchMsg ($sent, 1)) {
		if ($info->{"message"} =~ /^!resetkarma ([a-z0-9\[\]\\`_\^\{\|\}]+)$/i and $self->havePerms ($nick, $botClass) and $self->{"enfunc"}->{"resetkarma"}) {
			my $user = lc ($1);
			delete $self->{"karma"}->{$user} if exists $self->{"karma"}->{$user};
			$self->resetFilePos;
			print {$self->{"filehandle"}} &Dump ($self->{"karma"});
			$botClass->sendMsg ($info->{"chan"}, "Done, sir");
		} elsif ($info->{"message"} =~ /^!chkarma ([a-z0-9\[\]\\`_\^\{\|\}]+) (-?\d+)$/i and $self->havePerms ($nick, $botClass) and $self->{"enfunc"}->{"chkarma"}) {
			my ($user, $newkarma) = (lc ($1), $2);
			$self->{"karma"}->{$user}->[0] = (int ($newkarma) + 1);
			$self->chkarma ($user, "", "chkarma");
			delete $self->{"karma"}->{$user} if ($self->{"karma"}->{$user} eq "0");
			$self->resetFilePos;
			print {$self->{"filehandle"}} &Dump ($self->{"karma"});
			$botClass->sendMsg ($info->{"chan"}, "Done, sir");
		}
	}
}

sub resetFilePos {
	my $self = shift;
	truncate ($self->{"filehandle"}, 0);
	seek ($self->{"filehandle"}, 0, 0);
}

sub chkarma {
	my ($self, $user, $hostmask, $action) = @_;
	if ($action eq "++") {
		$self->{"karma"}->{$user}->[0] += 1;
	} else {
		$self->{"karma"}->{$user}->[0] -= 1;
	}
	$self->{"karma"}->{$user}->[1]  = lc ($hostmask);
	$self->{"karma"}->{$user}->[2]  = $action;
	return 1;
}

sub havePerms {
	my ($self, $nick, $mainClass) = @_;
	return 0 if not $mainClass->{"functions"}->in_array ($self->{"admins"}, $nick);
	return ( $self->{"idchk"} ? $mainClass->{"hooked_modules"}->{"idcheck"}->isIdentified ($nick, $mainClass) : 1 );
}
1;
