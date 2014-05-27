#!/usr/bin/env perl
package Plib::modules::metacpan;
use strict;
use warnings;
use JSON;
use LWP::UserAgent;
use threads;

my $lwp = LWP::UserAgent->new (agent => "PlIB::MetaCPAN/1.0");
my $mc_mod_link = "http://api.metacpan.org/v0/module/";
#my $mc_pod_link = ""

sub new { $_[0] }
sub atInit { 1 }

sub atWhile
{
    my ($self, $isTest, $botClass, $sent, $nick, $ident, $host) = @_;
    return 1 if $isTest;
    my $info;
    if ($nick and $ident and $host and $info = $botClass->matchMsg ($sent, 0))
    {
        return if $nick eq "csbot2";
        if ($info->{message} =~ /^(?:meta)?cpan$/i) {
            $botClass->sendMsg ($info->{"chan"}, "MetaCPAN plugin / Usage: [ 'Module::Name', 'perldoc Module::Name', 'cpan search Query' ]");
        }
        elsif ($info->{message} =~ /^perldoc ((?:\w+::){1,}\w+)$/) {
            $botClass->sendMsg ($info->{"chan"}, "https://metacpan.org/pod/${1}");
        }
        elsif ($info->{message} =~ /^(?:meta)?cpan search ([^\s]+)$/) {
            threads->new (\&mod_search, $botClass, $info, $1)->detach;
        }
        elsif ($info->{message} =~ /((?:\w+::){1,}\w+)/) {
            threads->new (\&mod_info, $botClass, $info, $1)->detach;
        }
    }
}

sub mod_info
{
    my ($botClass, $info, $modname) = @_;
    my $req = $lwp->get ($mc_mod_link . $modname);
    return $botClass->sendMsg ($info->{chan}, "Something bad happened while fetching the module page :(") if (!$req->is_success && $req->code != 404);
    my $parsed;
    eval { $parsed = decode_json $req->decoded_content };
    return $botClass->sendMsg ($info->{chan}, "Something bad happened while decoding the module info :(") if $@;
    if (exists $parsed->{code}) {
        return $botClass->sendMsg ($info->{chan}, "'${modname}' is not an existent Perl module.") if $req->code == 404;
        return $botClass->sendMsg ($info->{chan}, "Server returned " . $parsed->{code} . " " . $parsed->{message});
    }
    my $response = $modname;
    $response .= " v" . $parsed->{version};
    $response .= ": " . $parsed->{abstract} if exists $parsed->{abstract};
    $response .= " / by " . (ref ($parsed->{author}) eq 'ARRAY' ? $parsed->{author}->[0] : $parsed->{author});
    $response .= " / https://metacpan.org/pod/${modname}";
    $botClass->sendMsg ($info->{chan}, $response);
}

sub mod_search
{
    my ($botClass, $info, $query) = @_;
    my $req = $lwp->get ("https://metacpan.org/search/autocomplete?q=${query}");
    return $botClass->sendMsg ($info->{chan}, "[ ':(' ]") unless $req->is_success;
    my $parsed;
    eval { $parsed = decode_json $req->decoded_content };
    return $botClass->sendMsg ($info->{chan}, "[ ':((' ]") if $@;
    my $res = '[ '; my $n = 0;
    foreach (@{$parsed})
    {
        last if ($n++ == 5);
        $res .= "'" . $_->{documentation} . "', ";
    }
    $res = ($res ne '[ ' ? (substr ($res, 0, -2) . " ") : $res) . "]";
    $botClass->sendMsg ($info->{chan}, $res);
}

1;