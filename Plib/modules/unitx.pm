#!/usr/bin/perl
# Another plugin
# This plugin hooks command 'aboutme' and 'aboutuser'
# and checks if user is registered
# on forum 'unitx.net'. If yes, 
# display his nickname, his title,
# his message number, his inscription date,
# and his reputation.
# Author: Robertof
# Language: Italian
# Requirements: LWP::Simple, URI::Escape, Plib::*
package Plib::modules::unitx;
use strict;
use warnings;
use LWP::Simple;
use URI::Escape;

sub new {
	return $_[0];
}

sub atInit {};
sub atWhile {
	my ($self, $isTest, $botClass, $sent, $nick, $ident, $host) = @_;
	return 1 if $isTest;
	my $info;
	if ($nick and $ident and $host and $info = $botClass->matchMsg ($sent)) {
		if ($info->{"message"} =~ /^!aboutme/i or $info->{"message"} =~ /^!aboutuser ([^\s]+)/i) {
			# Check if user exists
			$nick = $botClass->{"functions"}->trim ($1) if defined $1 and $1 ne "";
			my $isExt = 0;
			$isExt = 1 if $1;
			$botClass->sendMsg ($info->{"chan"}, ( $isExt ? "Sto controllando se Dio ha creato ${nick}.." : "Sto controllando se Dio ti ha creato.." ));
			my $searchpage = get ("http://unitx.net/userlist.php?username=" . uri_escape ($nick) . "&show_group=-1&sort_by=username&sort_dir=ASC&search=Invia");
			$searchpage =~ s/(\n|\r|\t)//g;
			if ($searchpage =~ /<tbody><tr><td class="tcl"><a href="profile.php\?id=(\d+)">(.+?)<\/a><\/td>.+?<td class="tc2">(.+?)<\/td><td class="tc3">(.+?)<\/td><td class="tcr">(.+?)<\/td>/i) {
				my $uid = $1;
				$botClass->sendMsg ($info->{"chan"}, ( $isExt ? "Okay, questo utente e' stato creato, il suo nickname sul forum e' " . strip_tags ($2) . ", il suo titolo e' \"${3}\" ed ha scritto ${4} messaggi. Si e' iscritto il ${5}." : "Okay, ti ha creato. Ti chiami '" . strip_tags ($2) . "' ed il tuo titolo e' \"${3}\". Hai scritto ${4} messaggi e ti sei iscritto il ${5}." ));
				$botClass->sendMsg ($info->{"chan"}, ( $isExt ? "Sto recuperando la reputazione di questo utente.." : "Sto recuperando la tua reputazione.." ));
				my $reppage = get ("http://unitx.net/reputation.php?uid=${uid}");
				$reppage =~ s/(\n|\r|\t)//g;
				if ($reppage =~ /\[\+(\d+) \/ \-(\d+)\]/) {
					my $rep = int ($1) - int ($2);
					my $fixedstr = "(${1} " . ( $1 ne 1 ? "punti positivi" : "punto positivo" ) . " - ${2} " . ( $2 ne 1 ? "punti negativi" : "punto negativo" ) . ")";
					$botClass->sendMsg ($info->{"chan"}, ( $isExt ? "La reputazione di questo utente e' ${rep} ${fixedstr}." : "La tua reputazione e' ${rep} ${fixedstr}." ));
				} else {
					$botClass->sendMsg ($info->{"chan"}, ( $isExt ? "Non sono riuscito a recuperare la reputazione di questo utente." : "Non sono riuscito a recuperare la tua reputazione." ));
				}
			} else {
				$botClass->sendMsg ($info->{"chan"}, "Non ti/lo ha creato :(");
			}
		}
	}
}

# Thx to perldoc
sub strip_tags {
	my $str = $_[0];
	$str =~ s/<(?:[^>'"]*|(['"]).*?\1)*>//gs;
	return $str;
}
1;
