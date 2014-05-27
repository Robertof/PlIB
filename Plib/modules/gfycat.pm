package Plib::modules::gfycat;
use strict;
use warnings;
use JSON;
use LWP::UserAgent;

my $lwp = LWP::UserAgent->new (agent => "PlIB - PerL IrcBot");
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
        if ($info->{message} =~ m#(https?://[^\s]+\.gif)#i) {
            my $m = $1;
            threads->new (sub {
                my ($botClass, $info, $link) = @_;
                my $req = $lwp->get ("http://gfycat.com/cajax/checkUrl/${link}");
                eval {
                    die "can't call gfycat's API" unless $req->is_success;
                    my $gison = decode_json $req->decoded_content;
                    die "invalid JSON content" unless exists $gison->{urlKnown};
                    $botClass->sendMsg ($info->{"chan"}, "FTFY: " . $gison->{gfyUrl})
                        if ($gison->{urlKnown} && exists $gison->{gfyUrl});
                };
                #$botClass->sendMsg ($info->{chan}, $@) if $@; # suppress debug
            }, $botClass, $info, $m)->detach;
        }
    }
}

1;