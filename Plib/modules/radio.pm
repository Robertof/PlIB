package Plib::modules::radio;
use strict;
use warnings;
use LWP::UserAgent;

my $lwp    = LWP::UserAgent->new;
my $target = "http://radio.niggazwithattitu.de/?proxyAPI=true";

sub new { $_[0]; }
sub atInit { return 1; }

sub atWhile
{
    my ($self, $isTest, $botClass, $sent, $nick, $ident, $host) = @_;
    return 1 if $isTest;
    my $info;
    if ($nick and $ident and $host and $info = $botClass->matchMsg ($sent, 0))
    {
        if ($info->{"message"} =~ /(csong|what is playing?'?|current song|is there some wub|wubbing)\??/) {
            threads->create (sub {
                my $cw = $lwp->get ($target);
                unless ($cw->is_success) {
                    $botClass->sendMsg ($info->{"chan"}, "Something bad happened while fetching da' stuff.");
                    return;
                }
                my $cnt = $cw->content;
                #print $cnt, "\n";
                my ($num, $name);
                if ($cnt =~ /<listeners>(\d+)</) {
                    $num = $1;
                }
                if ($cnt =~ /<fullname>(.+?)<\/fullname>/) {
                    $name = $1;
                }
                #print $num, "\n", $name, "\n";
                unless ($num or $name) {
                    $botClass->sendMsg ($info->{"chan"}, "Mmh.. it appears that sum regexp failed.. sadface");
                    return;
                }
                $botClass->sendMsg ($info->{"chan"}, "Currently playin': ${name}; listeners: ${num}");
            })->detach;
        }
    }
}

1;