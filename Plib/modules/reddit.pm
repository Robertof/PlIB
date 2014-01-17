#!/usr/bin/env perl
package Plib::modules::reddit;
use strict;
use warnings;
use LWP::UserAgent;
use JSON;
use URI::Escape;

my $lwp = LWP::UserAgent->new ( agent => 'Robertof_/reddit-postinfo-fetcher/v0.1' );

sub new { return $_[0]; }
sub atInit { return 1; }

sub atWhile
{
    my ($self, $isTest, $botClass, $sent, $nick, $ident, $host) = @_;
    return 1 if $isTest;
    my $info;
    if ($nick and $ident and $host and $info = $botClass->matchMsg ($sent, 0))
    {
        if ($info->{"message"} =~ /^(?:https?:\/\/)?(?:.+?\.)?(?:reddit\.com)?\/?r\/([a-zA-Z0-9-_]+)|\s(?:https?:\/\/)?(?:.+?\.)?(?:reddit\.com)?\/r\/([a-zA-Z0-9-_]+)$|\s(?:https?:\/\/)?(?:.+?\.)?(?:reddit\.com)?\/r\/([a-zA-Z0-9-_]+)\s/)
        {
            threads->create (\&parse_subreddit, $botClass, $info, $^N)->detach;
        }
        elsif ($info->{"message"} =~ /^(?:https?:\/\/)?(?:.+?\.)?(?:reddit\.com)?\/?us?e?r?\/([a-zA-Z0-9-_]+)|\s(?:https?:\/\/)?(?:.+?\.)?(?:reddit\.com)?\/us?e?r?\/([a-zA-Z0-9-_]+)$|\s(?:https?:\/\/)?(?:.+?\.)?(?:reddit\.com)?\/us?e?r?\/([a-zA-Z0-9-_]+)\s/)
        {
            threads->create (\&parse_user, $botClass, $info, $^N)->detach;
        }
        elsif ($info->{"message"} =~ /(?:https?:\/\/)?(?:.+?\.)?(?:reddit\.com(?:\/r\/[^\/]+\/comments)?|redd\.it)\/([a-zA-Z0-9]+)/)
        {
            return if $1 eq 'r';
            threads->create (\&parse_post_from_id, $botClass, $info, $1)->detach;
        }
    }
}

sub parse_post_from_id
{
    my ($botClass, $info, $id, $preparsed_post) = @_;
    my $json;
    unless (defined $preparsed_post)
    {
        my $text = $lwp->get ("http://www.reddit.com/comments/" . uri_escape (substr ($id, 0, 32)) . ".json?limit=1&depth=1&sort=top");
        if (!$text->is_success)
        {
            $botClass->sendMsg ($info->{"chan"}, "I'm sorry, but an error occurred while fetching your data.");
            return;
        }
        $json = eval { decode_json $text->decoded_content };
        if (!$json || (ref ($json) eq 'HASH' && exists $json->{"error"}))
        {
            $botClass->sendMsg ($info->{"chan"}, "I'm sorry, but an error occurred while decoding your data." . ( (ref ($json) eq 'HASH' && exists $json->{"error"}) ? " Error: " . $json->{"error"} : "" ));
            return;
        }
    }
    my $post = defined $preparsed_post ? $preparsed_post : $json->[0]->{"data"}->{"children"}->[0]->{"data"};
    my $total_upvotes = $post->{"ups"} + $post->{"downs"};
    $botClass->sendMsg ($info->{"chan"}, sprintf ("\x02%s\x02%s / by %s / %s (%.1f%% ups, %.1f%% downs) / \x02%d\x02 comments / %s", $post->{"title"}, ( $post->{"over_18"} ? " (\x02\x034NSFW\x03\x02)" : "" ) . ( defined $preparsed_post ? " @ \x02http://redd.it/" . $post->{"id"} . "\x02" : "" ) . ( $post->{"stickied"} ? " (\x02\x038stickied\x03\x02)" : "" ), $post->{"author"}, proper_plural ($post->{"score"}, "point", "\x02", "\x02"), (100 * int ($post->{"ups"})) / $total_upvotes, (100 * int ($post->{"downs"})) / $total_upvotes, $post->{"num_comments"}, ( $post->{"is_self"} ? "\x02self post\x02" : "url: \x02" . $post->{"url"} . "\x02" )));
    return if defined $preparsed_post;
    if ($post->{"is_self"} && $post->{"selftext"} ne "") {
        $botClass->sendMsg ($info->{"chan"}, sprintf ("\x02%s\x02 said: %s", $post->{"author"}, truncate_text_to ($post->{"selftext"}, 150)));
    } elsif ($post->{"num_comments"} > 0) {
        my $comment = $json->[1]->{"data"}->{"children"}->[0]->{"data"};
        $botClass->sendMsg ($info->{"chan"}, sprintf ("Top comment (%s, %s) by \x02%s\x02: %s", ($comment->{"score_hidden"} ? "hidden score" : proper_plural ($comment->{"ups"} - $comment->{"downs"}, "point", "\x02", "\x02")), proper_particular_plural (int ($comment->{"replies"}->{"data"}->{"children"}->[0]->{"data"}->{"count"}), "reply", "replies", "\x02", "\x02"), $comment->{"author"}, truncate_text_to ($comment->{"body"}, 150)));
    }
}

sub parse_subreddit
{
    my ($botClass, $info, $subreddit_name) = @_;
    #print uri_escape($subreddit_name);
    my $raw = $lwp->get ("http://www.reddit.com/r/" . uri_escape ($subreddit_name) . ".json?limit=1&sort=hot");
    if (!$raw->is_success)
    {
        $botClass->sendMsg ($info->{"chan"}, "I'm sorry, but an error occurred while fetching your data.");
        return;
    }
    my $json = eval { decode_json $raw->decoded_content };
    if (!$json || ref ($json) ne 'HASH' || exists $json->{"error"} || !exists $json->{"data"}->{"children"} || ref ($json->{"data"}->{"children"}) ne 'ARRAY' || scalar (@{$json->{"data"}->{"children"}}) == 0)
    {
        $botClass->sendMsg ($info->{"chan"}, "I'm sorry, but an error occurred while decoding your data.");
        return;
    }
    my $c = 0;
    foreach (@{$json->{"data"}->{"children"}})
    {
        last if (++$c == 3);
        parse_post_from_id ($botClass, $info, undef, $_->{"data"});
    }
}

sub parse_user
{
    my ($botClass, $info, $username) = @_;
    my $raw = $lwp->get ("http://www.reddit.com/user/" . uri_escape ($username) . "/about.json");
    if (!$raw->is_success)
    {
        $botClass->sendMsg ($info->{"chan"}, "I'm sorry, but an error occurred while fetching your data.");
        return;
    }
    my $json = eval { decode_json $raw->decoded_content };
    if (!$json || ref ($json) ne 'HASH' || exists $json->{"error"} || !exists $json->{"data"} || ref ($json->{"data"}) ne "HASH")
    {
        $botClass->sendMsg ($info->{"chan"}, "I'm sorry, but an error occurred while decoding your data.");
        return;
    }
    $botClass->sendMsg ($info->{"chan"}, sprintf ("\x02%s\x02 / link karma: \x02%d\x02 / comment karma: \x02%d\x02 / has fapped on reddit at least once: \x02%s\x02 / created on \x02%s\x02%s", $json->{"data"}->{"name"}, $json->{"data"}->{"link_karma"}, $json->{"data"}->{"comment_karma"}, ( $json->{"data"}->{"over_18"} ? "yes" : "no" ), gmtdate_to_human_readable ($json->{"data"}->{"created_utc"}), ( $json->{"data"}->{"is_gold"} ? " / \x02\x038Gold member\x03\x02" : "")));

}

sub proper_plural
{
    my ($n, $noun, $prepend, $append) = @_;
    return (defined $prepend ? $prepend : '') . $n . (defined $append ? $append : '') . ' ' . $noun . ($n != 1 && 's');
}

sub proper_particular_plural
{
    my ($n, $singular, $plural, $prepend, $append) = @_;
    return (defined $prepend ? $prepend : '') . ($n == 0 ? 'no' : $n) . (defined $append ? $append : '') . ' ' . ($n != 1 ? $plural : $singular);
}

sub truncate_text_to
{
    my ($text, $n) = @_;
    $text =~ s/\n\n*/ /g;
    return $text if $n <= 6 or length $text <= $n;
    my $base_str = substr ($text, 0, $n - 6); # 6 === ' [...]'
    # temporary hack since reverse() is quite a faggot
    my $base_pos = index_multisearch (join ('', reverse (split (//, $base_str))), int (0.4 * length ($base_str)), '.', ';', '(', ',', ':', ' ');
    if ($base_pos == -1)
    {
        $text = $base_str;
    }
    else
    {
        $text = substr ($base_str, 0, length ($base_str) - 1 - $base_pos);
    }
    $text =~ s/\s+$//;
    $text .= ' [...]';
    return $text;
}

sub index_multisearch
{
    my ($text, $less_than, @strings) = @_;
    foreach (@strings)
    {
        my $tmp = index ($text, $_);
        return $tmp if ($tmp != -1 && $tmp <= $less_than);
    }
    return -1;
}

sub gmtdate_to_human_readable
{
    my ($day, $month, $year) = (localtime ($_[0]))[3 .. 5];
    return "${day}/" . ($month + 1) . "/" . ($year + 1900);
}
1;