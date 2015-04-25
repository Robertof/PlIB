package Plib::modules::extrautilities;
use strict;
use warnings;
use HTML::Query;
use HTTP::Date ();
use JSON;
use LWP::UserAgent;
use threads;
use URI;
use URI::Escape;

use constant {
    YOUTUBE_API_KEY            => "CHANGE_ME",
    YOUTUBE_API_URL            => "https://www.googleapis.com/youtube/v3",
    YOUTUBE_VIDEO_URL          => "%s/videos",
    YOUTUBE_SEARCH_URL         => "%s/search",
    YOUTUBE_CHANNEL_URL        => "%s/channels",
    YOUTUBE_PLAYLIST_ITEMS_URL => "%s/playlistItems"
};

YOUTUBE_API_KEY eq "CHANGE_ME" and 
    die "ERROR: you have to change the 'YOUTUBE_API_KEY' constant to a valid key.\n" .
        "See here: https://developers.google.com/youtube/registering_an_application";

my $lwp = LWP::UserAgent->new;
sub new { $_[0] }
sub atInit { 1 }

sub atWhile
{
    my ($self, $isTest, $botClass, $sent, $nick, $ident, $host) = @_;
    return 1 if $isTest;
    my $info;
    if ($nick and $ident and $host and $info = $botClass->matchMsg ($sent, 0))
    {
        # YouTube stuff
        if ($info->{"message"} =~ /(?:https?:\/\/)?(?:www\.)?(?:youtube\.com\/watch(?:\?v=|\?.+?&v=)|youtu\.be\/)([a-zA-Z0-9_-]+)/)
        {
            threads->create (\&parse_video, $botClass, $info, "$1")->detach;
        }
        elsif ($info->{"message"} =~ /^!?yt (?:ch(?:an)?(?:nel)?|user) (.+)$/)
        {
            threads->create (\&parse_channel, $botClass, $info, "$1")->detach;
        }
        elsif ($info->{"message"} =~ /^!?yt last(?:videos?)? (.+)$/)
        {
            threads->create (\&get_last_videos, $botClass, $info, "$1", 3)->detach;
        }
        elsif ($info->{"message"} =~ /^!?yt best(video|hacker)$/)
        {
            my $map = { hacker => "u8qgehH3kEQ", video =>  "vf5foZnBTDU" };
            threads->create (\&parse_video, $botClass, $info, $map->{"$1"}, 1)->detach;
        }
        elsif ($info->{"message"} =~ /^!?yt (.+)$/)
        {
            threads->create (\&search_videos, $botClass, $info, "$1")->detach;
        }
        elsif ($info->{"message"} =~ /^!?yt$/)
        {
            $botClass->sendMsg ($info->{"chan"}, 'usage: yt $query, yt chan/channel/user $name, yt last/lastvideo[s] $name, yt bestvideo or just paste a YouTube link in the channel');
        }
        # Urbandictionary stuff
        elsif ($info->{"message"} =~ /^!?(?:dict|define) (.+?)(?:\s(\d+)$|$)/)
        {
            my ($term, $defNum) = ($1, (defined $2 ? $2 : 1));
            return if $defNum < 0 or $defNum > 10;
            threads->create (\&handle_dict_term, $botClass, $info, $term, $defNum)->detach;
        }
        elsif ($info->{"message"} =~ /^!?random(?:dict|term)$/)
        {
            threads->create (sub {
                my ($botClass, $info) = @_;
                $lwp->requests_redirectable (['GET']);
                my $_req = $lwp->head ("http://www.urbandictionary.com/random.php");
                my $target = $_req->header ('Location');
                if (!$target or $target !~ /\?term=(.+)/)
                {
                    $botClass->sendMsg ($info->{"chan"}, "server didn't send me to the heaven");
                    return;
                }
                my $term = uri_unescape ($1);
                $term =~ s/\+/ /g;
                handle_dict_term ($botClass, $info, $term, 1);
            }, $botClass, $info)->detach;
        }
        elsif ($info->{"message"} =~ /^!?(?:dict|define)$/)
        {
            $botClass->sendMsg ($info->{"chan"}, 'usage: randomterm/randomdict, dict/define $term, dict/define $term $definitionNum. Example: dict Roberto, define Giuseppe 2');
        }
    }
}

sub handle_dict_term
{
    my ($botClass, $info, $term, $definition) = @_;
    my $_target = "http://urbanup.com/" . uri_escape ($term);
    my $udpage = $lwp->get ("http://www.urbandictionary.com/define.php?term=" . uri_escape ($term));
    unless ($udpage->is_success)
    {
        $botClass->sendMsg ($info->{"chan"}, "can't reach urbandictionary.com :(");
        return;
    }
    my $definitions = HTML::Query->new (text => $udpage->decoded_content)->query (".meaning");
    if ($definitions->size < $definition)
    {
        $botClass->sendMsg ($info->{"chan"}, "no definition found for ${term}");
        return;
    }
    my $def = @{$definitions->get_elements()}[$definition -1]->as_trimmed_text;
    if (length $def > 800)
    {
        # try to perform an 'intelligent' truncation.
        # long story short: if possible, find a point starting from right
        # in the last 50 characters of the string, and truncate from that.
        my $base_str   = substr ($def, 0, (799 - length ($_target) - length (' - moar at: ')));# my $rev = reverse ($base_str);
        my $base_pos   = index (reverse ($base_str), '.'); #min (index ($rev, ' '), index ($rev, '.'), index ($rev, ';'), index ($rev, ','));
        if ($base_pos > 50) {
            $def = $base_str;
        } else {
            $def = substr ($base_str, 0, length ($base_str) - 1 - $base_pos);
        }
        $def .= " - more at: ${_target}";
    }
    $botClass->sendMsg ($info->{"chan"}, "definition for ${term}: " . $def);
}

sub get_last_videos
{
    my ($botClass, $info, $channelName, $n) = @_;
    # first request to /channels?part=contentDetails
    my $content_details = lwp_json_req ($botClass, $info, yt_url (YOUTUBE_CHANNEL_URL,
        part => "contentDetails", forUsername => $channelName,
        fields => "items/contentDetails")) || return;
    return $botClass->sendMsg ($info->{chan}, "Channel '$channelName' not found / request failed.")
        unless exists $content_details->{items} && scalar @{$content_details->{items}} > 0;
    # second request to /playlistItems?part=snippet
    my $playlist_items = lwp_json_req ($botClass, $info, yt_url (YOUTUBE_PLAYLIST_ITEMS_URL,
        part => "snippet", maxResults => $n, fields => "items/snippet",
        playlistId => $content_details->{items}[0]{contentDetails}{relatedPlaylists}{uploads})
    ) || return;
    return $botClass->sendMsg ($info->{chan}, "Channel '$channelName' has no videos.")
        unless exists $playlist_items->{items} && scalar @{$playlist_items->{items}} > 0;
    # produce the final result
    my @final;
    foreach my $item (@{$playlist_items->{items}})
    {
        push @final, sprintf ("\x0304%s\x03 (https://youtu.be/%s)",
            $item->{snippet}->{title}, $item->{snippet}->{resourceId}->{videoId});
    }
    $botClass->sendMsg ($info->{chan}, join (", ", @final));
}

sub parse_channel
{
    my ($botClass, $info, $channelName) = @_;
    my $data = lwp_json_req ($botClass, $info, yt_url (YOUTUBE_CHANNEL_URL,
        part => "snippet,statistics", forUsername => $channelName,
        fields => "items(id,snippet,statistics)")) || return;
    return $botClass->sendMsg ($info->{chan}, "Channel '$channelName' not found / request failed.")
        unless exists $data->{items} && scalar @{$data->{items}} > 0;
    my ($id, $snippet, $statistics) = @{$data->{items}[0]}{"id", "snippet", "statistics"};
    $botClass->sendMsg ($info->{chan}, sprintf (
        "\x0304%s\x03 / \x0304%s\x03 videos / \x0304%s\x03 subscribers / \x0304%s\x03 views / https://www.youtube.com/channel/%s",
        $snippet->{title},
        map ({ commify ($statistics->{"${_}Count"}) } qw[video subscriber view]),
        $id
    ));
}

sub parse_video
{
    my ($botClass, $info, $videoId, $incl_link) = @_;
    my $vid = lwp_json_req ($botClass, $info, yt_url (YOUTUBE_VIDEO_URL,
        part => "snippet,statistics,contentDetails", id => $videoId,
        fields => "items(contentDetails,snippet,statistics)")) || return;
    return $botClass->sendMsg ($info->{chan}, "Video '$videoId' not found / request failed.")
        unless exists $vid->{items} && scalar @{$vid->{items}} > 0;
    my ($snippet, $statistics, $content_details) = @{$vid->{items}[0]}{
        "snippet", "statistics", "contentDetails"
    };
    my ($likes, $dislikes) = map { $statistics->{"${_}Count"} } qw[like dislike];
    my $rating = ($likes == 0 && $dislikes == 0) ? 0 : int (0.5 + ($likes * 5) / ($likes + $dislikes));
    $botClass->sendMsg ($info->{"chan"}, sprintf (
        "\x0304%s\x03 / by \x0304%s\x03 / \x0304%s\x03 views / uploaded \x0304%s\x03 / duration: \x0304%s\x03 / rating: \x038%s\x03%s%s",
        $snippet->{title},
        $snippet->{channelTitle},
        commify ($statistics->{viewCount}),
        relative_time (time() - HTTP::Date::str2time ($snippet->{publishedAt})),
        iso8601_to_acceptable_duration ($content_details->{duration}),
        "\x{2605}" x $rating,
        "\x{2606}" x (5 - $rating),
        defined $incl_link ? " / https://youtu.be/$videoId" : ""
    ));
}

sub search_videos
{
    my ($botClass, $info, $query) = @_;
    my $res = lwp_json_req ($botClass, $info, yt_url (YOUTUBE_SEARCH_URL,
        part => "snippet", maxResults => 1, q => $query, type => "video",
        fields => "items/id")) || return;
    return $botClass->sendMsg ($info->{chan}, "Nothing found while searching for '$query' / request failed.")
        unless exists $res->{items} && scalar @{$res->{items}} > 0;
    parse_video ($botClass, $info, $res->{items}[0]{id}{videoId}, 1);
}

sub yt_url
{
    my ($url, %params) = @_;
    my $uri = URI->new (sprintf $url, YOUTUBE_API_URL);
    $uri->query_form (key => YOUTUBE_API_KEY, %params);
    $uri->as_string;
}

sub iso8601_to_acceptable_duration
{
    my $val = shift;
    $val =~ s/[PT]//g;
    lc $val;
}

sub commify
{
    my $text = reverse $_[0];
    $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
    return scalar reverse $text;
}

sub relative_time
{
    my $delta = shift;
    return $delta == 1 ? "one second ago" : "$delta seconds ago" if $delta < 60;
    return "a minute ago" if $delta < 120;
    return "@{[int(0.5 + $delta / 60)]} minutes ago" if $delta < 2700; # 45 minutes
    return "an hour ago" if $delta < 5400; # 90 minutes
    return "@{[int(0.5 + $delta / 3600)]} hours ago" if $delta < 86400;
    return "yesterday" if $delta < 172800; # 24 hours
    return "@{[int(0.5 + $delta / 86400)]} days ago" if $delta < 2592000; # 30 days
    if ($delta < 31104000) # 12 months
    {
        my $months = int (0.5 + $delta / 86400 / 30);
        return $months <= 1 ? "one month ago" : "$months months ago";
    }
    my $years = int (0.5 + $delta / 86400 / 365);
    $years <= 1 ? "one year ago" : "$years years ago";
}

sub lwp_json_req
{
    my ($botClass, $info, $url) = @_;
    my $req = $lwp->get ($url);
    unless ($req->is_success)
    {
        $botClass->sendMsg ($info->{chan}, "Can't reach the desired URL: " . $req->status_line);
        return;
    }
    my $parsed;
    eval { $parsed = decode_json $req->decoded_content; 1 } or
        $botClass->sendMsg ($info->{chan}, "Can't decode the JSON document: $@"), return;
    $parsed;
}
1;
