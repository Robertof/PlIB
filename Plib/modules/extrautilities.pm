package Plib::modules::extrautilities;
use strict;
use warnings;
use Encode;
use HTML::Query;
use LWP::UserAgent;
use threads;
use URI::Escape;
use WebService::GData::YouTube;
use WebService::GData::Base;

my $yt  = WebService::GData::YouTube->new;
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
        # YouTube stuff
        if ($info->{"message"} =~ /(?:https?:\/\/)?(?:www\.)?(?:youtube\.com\/watch(?:\?v=|\?.+?&v=)|youtu\.be\/)([a-zA-Z0-9_-]+)/)
        {
            parse_video ($botClass, $info, $1);
        }
        elsif ($info->{"message"} =~ /^!?yt (?:ch(?:an)?(?:nel)?|user) (.+)$/)
        {
            my $profile;
            $yt->{_request} = new WebService::GData::Base();
            eval { $profile = $yt->get_user_profile ($1); };
            if (my $err = $@)
            {
                $botClass->sendMsg ($info->{"chan"}, "An error occurred while looking for a profile: " . $err->code);
                return;
            }
            my $nick = $profile->{"_feed"}->{'yt$username'}->{"display"}; my $displayName = $profile->{"_feed"}->{"title"}->{"text"};
            $botClass->sendMsg ($info->{"chan"}, sprintf ("%s / %d subscribers / %d views / http://www.youtube.com/channel/%s",
                ($displayName . ($displayName ne $nick ? " / aka ${nick}" : "") , $profile->statistics->subscriber_count, $profile->statistics->total_upload_views, $profile->{'_feed'}->{'yt$channelId'}->{'$t'})));
        }
        elsif ($info->{"message"} =~ /^!?yt last(?:video)? (.+)$/)
        {
            my $videos;
            $yt->{_request} = new WebService::GData::Base();
            eval { $videos = $yt->get_user_videos ($1); };
            if (my $err = $@)
            {
                $botClass->sendMsg ($info->{"chan"}, "An error occurred while looking for ${1}'s videos: " . $err->code);
                return;
            }
            if (scalar (@$videos) eq 0)
            {
                $botClass->sendMsg ($info->{"chan"}, "The user didn't upload any videos.");
                return;
            }
            output_video_info ($botClass, $info, $videos->[0], 1);
        }
        elsif ($info->{"message"} =~ /^!?yt bestvideo$/)
        {
            parse_video ($botClass, $info, "vf5foZnBTDU", 1);
        }
        elsif ($info->{"message"} =~ /^!?yt (.+)$/)
        {
            my $videos;
            eval { $yt->query->q($1)->limit (1, 0); $videos = $yt->search_video(); };
            if (my $err = $@)
            {
                $botClass->sendMsg ($info->{"chan"}, "An error occurred while searching: " . $err->code);
                return;
            }
            if (scalar (@$videos) eq 0)
            {
                $botClass->sendMsg ($info->{"chan"}, "No results.");
                return;
            }
            output_video_info ($botClass, $info, $videos->[0], 1);
        }
        elsif ($info->{"message"} =~ /^!?yt$/)
        {
            $botClass->sendMsg ($info->{"chan"}, 'usage: yt $query, yt chan/channel/user $name, yt last/lastvideo $name, yt bestvideo or just paste a YouTube link in the channel');
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

sub parse_video
{
    my ($botClass, $info, $id, $flag) = @_;
    my $video;
    $yt->{_request} = new WebService::GData::Base(); # fix a bug with the library
    eval { $video = $yt->get_video_by_id ($id); };
    if (my $err = $@)
    {
        $botClass->sendMsg ($info->{"chan"}, "An error occurred while fetching video data: " . $err->code);
        return;
    }
    output_video_info ($botClass, $info, $video, $flag);
}

sub output_video_info
{
    my ($botClass, $info, $video, $incl_lnk) = @_;
    my $likes = $video->rating->{"numLikes"};
    my $dislikes = $video->rating->{"numDislikes"};
    $botClass->sendMsg ($info->{"chan"}, sprintf ("%s / by %s / %d views / Duration: %s / %d likes / %d dislikes%s",
        Encode::decode ("utf8", $video->title), $video->uploader, $video->view_count, yt_date ($video->duration), $likes, $dislikes, (defined $incl_lnk ? " / \x02http://youtu.be/" . $video->video_id : "")));
}

sub yt_date
{
    my $duration = shift;
    my $res = sprintf ("%02d:%02d:%02d:%02d", (gmtime $duration)[7, 2, 1, 0]);
    $res =~ s/^00:// while ($res =~ /^00:/);
    $res = "00:" . $res if $duration < 60;
    $res;
}
1;