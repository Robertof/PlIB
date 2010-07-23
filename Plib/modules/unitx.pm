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
		if ($info->{"message"} =~ /^!aboutme$/i or $info->{"message"} =~ /^!aboutuser ([^\s]+)$/i) {
			# Check if user exists
			$nick = $botClass->{"functions"}->trim ($1) if defined $1 and $1 ne "";
			my $isExt = 0;
			$isExt = 1 if $1;
			$botClass->sendMsg ($info->{"chan"}, ( $isExt ? "Sto controllando se Dio ha creato ${nick}.." : "Sto controllando se Dio ti ha creato.." ));
			my $searchpage = get ("http://unitx.net/userlist.php?username=" . uri_escape ($nick) . "&show_group=-1&sort_by=username&sort_dir=ASC&search=Invia");
			$searchpage =~ s/(\n|\r|\t)//g;
			if ($searchpage =~ /<tbody><tr><td class="tcl"><a href="profile\.php\?id=(\d+)">(.+?)<\/a><\/td>.+?<td class="tc2">(.+?)<\/td><td class="tc3">(.+?)<\/td><td class="tcr">(.+?)<\/td>/i) {
				my $uid = $1;
				$botClass->sendMsg ($info->{"chan"}, ( $isExt ? "Okay, questo utente e' stato creato, il suo nickname sul forum e' " . $self->strip_tags ($2) . ", il suo titolo e' \"${3}\" ed ha scritto ${4} messaggi. Si e' iscritto il ${5}." : "Okay, ti ha creato. Ti chiami '" . $self->strip_tags ($2) . "' ed il tuo titolo e' \"${3}\". Hai scritto ${4} messaggi e ti sei iscritto il ${5}." ));
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
		} elsif ($info->{"message"} =~ /^!aboutopic (.+)$/) {
			my $searchfor = $1;
			$botClass->sendMsg ($info->{"chan"}, "Sto cercando il post con la keyword '${searchfor}'. Attenzione: sara' preso solo il primo risultato.");
			my $searchpage = get ("http://www.unitx.net/search.php?action=search&keywords=${searchfor}&author=&forum=-1&search_in=topic&sort_by=0&sort_dir=DESC&show_as=topics&search=Invia");
			$searchpage =~ s/(\n|\r|\t)//g;
			if ($searchpage =~ /<a href="viewtopic\.php\?id=(\d+)">(.+?)<\/a>.+?<span class="byuser">di&nbsp;(.+?)<\/span>.+?<td class="tc2">(.+?)<\/td><td class="tc3">(\d+)<\/td><td class="tcr">(.+?)<\/td>/i) {
				my ($id, $name, $author, $section, $responses, $lastmsg) = ($1, $2, $3, $4, int ($5), $self->strip_tags ($6));
				my @dateauthor = split /di&nbsp;/, $lastmsg;
				$botClass->sendMsg ($info->{"chan"}, "Ho trovato un post di nome '${name}'. E' stato scritto da ${author} in " . $self->strip_tags ($section) . ". " . ($responses ne 1 ? "Ci sono ${responses} risposte" : "C'e' ${responses} risposta") . ", e l'ultima risale a" . ($dateauthor[0] =~ /^[aeiou]/i ? "d" : "lle") . " " . substr ($dateauthor[0], 0, (length ($dateauthor[0]) - 1)) . ", da parte di " . $dateauthor[1] . ". Link: http://unitx.net/viewtopic.php?id=${id}");
			} else {
				$botClass->sendMsg ($info->{"chan"}, "Topic non esistente / hai cannato qualcosa");
			} 
		}
	}
}

# Thx to perldoc
sub strip_tags {
	my $str = $_[1];
	$str =~ s/<(?:[^>'"]*|(['"]).*?\1)*>//gs;
	return $str;
}

#sub post_request {
	#my ($self, $page, $host, $content) = @_;
	#my $sock = IO::Socket::INET->new (
		#PeerHost => $host,
		#PeerPort => 80,
		#Proto    => "tcp"
	#) or return 0;
	#print $sock "POST ${page} HTTP/1.1\r\n";
	#print $sock "Host: ${host}\r\n";
	#print $sock "Connection: close\r\n";
	#print $sock "Content-Length: " . length ($content) . "\r\n";
	#print $sock "Content-Type: application/x-www-form-urlencoded\r\n\r\n";
	#print {$sock} $content;
	#print $sock "\r\n";
	#my $ret;
	#while (<$sock>) {
		#$ret .= $_;
	#}
	#return $ret;
#}
1;
