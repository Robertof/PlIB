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

package Plib::sockutil;
use strict;
use warnings;

sub new {
	my ($cname, $sockaddr, $sockport, $isSSL, $mainHash) = @_;
	die ("Plib sockutil error -- Missing parameters!\n") if not Plib::functions::checkVars ($sockaddr, $sockport, $isSSL, $mainHash);
	my $options = {
		"addr" => $sockaddr,
		"port" => $sockport,
		"ssl"  => $isSSL,
		"mhash"=> $mainHash
	};
	bless $options, $cname;
	return $options;
}

sub startConnection {
	# This will return 'self'
	my $self = $_[0];
	print $self->{"mhash"}->getPrefix . "[~] Opening connection to '".$self->{"addr"}.":".$self->{"port"}."' with".(($self->{"ssl"})?"":"out")." SSL\n";
	# Load right modules
	my $sock;
	if ($self->{"ssl"}) {
		eval qq{use IO::Socket::SSL};
		die $self->{"mhash"}->getPrefix . "[!] Error: if you want to use SSL, you must install module IO::Socket::SSL.\nError: ${@}\n" if $@;
		require IO::Socket::SSL;
		$sock = IO::Socket::SSL->new(
			PeerHost => $self->{"addr"},
			PeerPort => $self->{"port"},
			Proto    => "tcp",
			Timeout  => 10
		) or die ($self->{"mhash"}->getPrefix . "[-] Fatal error for 'IO::Socket::SSL': " . IO::Socket::SSL::errstr() . "\n");
	} else {
		eval qq{use IO::Socket::INET};
		die $self->{"mhash"}->getPrefix . "[!] Error: you must install module 'IO::Socket::INET'.\nError: ${@}\n" if $@;
		require IO::Socket::INET;
		$sock = IO::Socket::INET->new (
			PeerHost => $self->{"addr"},
			PeerPort => $self->{"port"},
			Proto    => "tcp",
			Timeout  => 10
		) or die ($self->{"mhash"}->getPrefix . "[-] Fatal error for 'IO::Socket::INET': ${!}\n");
	}
	print $self->{"mhash"}->getPrefix . "[+] Connection opened successfully.\n";
	$self->{"sock"} = $sock;
	return $self;
}

sub send {
	my ($self, $what) = @_;
	if ($self->{"sock"}) {
		print {$self->{"sock"}} $what;
		return 1;
	}
	return 0;
}

sub closeConnection {
	my ($self, $quitMessage) = @_;
	$self->send ("QUIT :${quitMessage}\n");
	close $self->{"sock"} if $self->{"sock"};
	# Remove sock variable
	delete $self->{"sock"};
	return 1;
}

sub getSock {
	my $self = $_[0];
	if ($self->{"sock"}) {
		return $self->{"sock"};
	}
	return 0;
}
1;
