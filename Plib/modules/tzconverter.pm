package Plib::modules::tzconverter;
use strict;
use warnings;
use POSIX;
use Time::Timezone;

my $curr_tz_str = strftime("%Z", localtime());

sub new { $_[0]; }
sub atInit { return 1; }

sub atWhile
{
    my ($self, $isTest, $botClass, $sent, $nick, $ident, $host) = @_;
    return 1 if $isTest;
    my $info;
    if ($nick and $ident and $host and $info = $botClass->matchMsg ($sent, 0))
    {
        # Matches:
        #  2am to GMT
        #  2am PST to GMT
        #  13:45 to CEST
        #  21 to CEST
        if ($info->{"message"} =~ /^(\d+(?::\d+)?\s*([ap]m)?)\s*([a-z]+)?\s*([+-]\s*\d+)?\s*to\s*([a-z]+)?\s*([+-]\s*\d+)?$/i)
        {
            my ($from_time, $from_12hrs, $from_tz, $from_tz_offset, $to_tz, $to_tz_offset) = ($1, $2, $3, $4, $5, $6);
            return if !defined $to_tz;
            my $parsed_from_tz = tz_offset ($from_tz);
            my $parsed_to_tz   = tz_offset ($to_tz);
            return $botClass->sendMsg ($info->{chan}, "Invalid timezone") if (!defined $parsed_from_tz || !defined $parsed_to_tz);
            $parsed_from_tz   += int ($from_tz_offset) * 3600 if ($from_tz && $from_tz_offset);
            $parsed_to_tz     += int ($to_tz_offset)   * 3600 if ($to_tz   && $to_tz_offset);
            my $fnal_tz_offset = $parsed_to_tz - $parsed_from_tz;
            return $botClass->sendMsg ($info->{chan}, "No change from the source and target time (offset is 0)") if $fnal_tz_offset == 0;
            my ($hours, $minutes) = split /:/, $from_time;
            ($hours, $minutes) = (to_int ($hours), to_int ($minutes || 0));
            return $botClass->sendMsg ($info->{chan}, "Incorrect time format (wtf man!)") if ($hours < 0 || $minutes < 0 || $minutes > 59 || (defined $from_12hrs && $hours > 12) || $hours > 23);
            my $hours_24      = !defined ($from_12hrs) || lc ($from_12hrs) eq "am" ? $hours : $hours + 12;
            my $shifted_hours = ($hours_24 * 3600 + $fnal_tz_offset) / 3600 % 24;
            my $tz_offset_hr  = int ($fnal_tz_offset / 3600);
            $botClass->sendMsg ($info->{chan}, sprintf ("%s %s%s -> %s %s%s (%s%dh)", format_time ($hours_24, $minutes, defined $from_12hrs), $from_tz || $curr_tz_str, $from_tz_offset || "", format_time ($shifted_hours, $minutes, defined $from_12hrs), $to_tz, $to_tz_offset || "", $tz_offset_hr >= 0 ? "+" : "-", abs $tz_offset_hr));
        }
    }
}

sub format_time
{
    my ($h, $m, $want_12hrs) = @_;
    sprintf ("%02d:%02d%s", $want_12hrs ? to12h ($h) : $h, $m, $want_12hrs ? $h < 12 ? "am" : "pm" : "");
}

sub to12h
{
    $_[0] % 12 || 12;
}

sub to_int
{
    local $_ = shift;
    /(\d+)/;
    $1;
}
1;
