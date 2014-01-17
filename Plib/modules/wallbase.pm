package Plib::modules::wallbase;
use strict;
use warnings;
use HTML::Query;
use LWP::UserAgent;
use URI::Escape;
use threads;

my $lwp = LWP::UserAgent->new;

sub new { return $_[0]; }
sub atInit { return 1; }

sub atWhile
{
    my ($self, $isTest, $botClass, $sent, $nick, $ident, $host) = @_;
    return 1 if $isTest;
    my $info;
    if ($nick and $ident and $host and $info = $botClass->matchMsg ($sent, 0))
    {
        if ($info->{"message"} =~ /^wp random\s?(\d+x\d+)?$/)
        {
            my $res = $1 || '0x0';
            print $res, "\n";
            threads->create (\&print_stuff, $botClass, $info, $res, "")->detach;
        }
        elsif ($info->{"message"} =~ /^wp\s?(\d+x\d+)?\s?(.+)$/)
        {
            my $res = $1 || '0x0';
            #threads->create (sub {
            #    my ($botClass, $info, $res, $query) = @_;
            #    my $list = parse_wallbase_list ($botClass, $info, "http://wallbase.cc/random?section=wallpapers&q=" . uri_escape ($2) . "&res_opt=eqeq&res=${res}&board=21");
            #    $botClass->sendMsg ($info->{"chan"}, join (", ", $list));
            #}, $botClass, $info, $res, $2)->detach;
            threads->create (\&print_stuff, $botClass, $info, $res, $2)->detach;
        }
    }
}

sub print_stuff
{
    my ($botClass, $info, $res, $query) = @_;
    my $params = "?section=wallpapers&q=" . uri_escape ((substr ($query, 0, 1) eq "=" ? "=(" . substr ($query, 1) . ")" : $query)) . "&res_opt=eqeq&res=${res}&order_mode=desc&order=random";
    print $params, "\n";
    $botClass->sendMsg ($info->{"chan"}, join (", ", @{parse_wallbase_list ($botClass, $info, "http://wallbase.cc/" . ($query eq "" ? "random" : "search") . $params)}));
}

sub parse_wallbase_list
{
    my ($botClass, $info, $link, $_limit) = @_;
    my $kawaii = $lwp->get ($link);
    my $limit = $_limit || 5;
    unless ($kawaii->is_success)
    {
        $botClass->sendMsg ($info->{"chan"}, "Cannot request ${link} :(");
        return [];
    }
    my $data = HTML::Query->new (text => $kawaii->decoded_content)->query (".thumbnail");
    if ($data->size < 1)
    {
        $botClass->sendMsg ($info->{"chan"}, "No results.");
        return [];
    }
    my @elms  = $data->get_elements();
    # http://thumbs.wallbase.cc//rozne/thumb-2303045.jpg
    my $links = []; my $i = 0; my $kanzo;
    foreach (@elms)
    {
        push @$links, "http://walb.es/${1}" . (($kanzo = parse_tags ($_->attr ('data-tags'))) ? " (${kanzo})" : "") if $_->attr('id') =~ /thumb(\d+)/;
        last if ++$i >= $limit;
    }
    return $links;
}

sub parse_tags
{
    my ($raw_tags, $ret, $i) = (shift, "", 0);
    while ($raw_tags =~ /([^|]+)\|\d+\|\d+/g)
    {
        $ret .= "$1, ";
        last if ++$i >= 3;
    }
    return substr ($ret, 0, -2);
}