package Plib::modules::g2play;
use strict;
use warnings;
use IO::Socket::INET;
use HTML::Query;
use JSON;
use URI::Escape;
use Data::Dumper;
use DateTime;
use Date::Calc qw(Delta_DHMS);

my $json = JSON->new->allow_nonref->utf8;
my $_cookies;
my $storedArray = [];

sub new {
    return $_[0];
}
sub atInit {}
sub atWhile {
    my ($self, $isTest, $botClass, $sent, $nick, $ident, $host) = @_;
    return 1 if $isTest;
    my $info;
    if ($nick and $ident and $host and $info = $botClass->matchMsg ($sent, 0))
    {
        if ($info->{"message"} =~ /^!getcurrentoffer$/)
        {
            print "Fetching g2play's homepage\n";
            my $homepage = do_get_request ("www.g2play.net", "/store/");
            if (ref ($homepage) ne "HASH" or $homepage->{"headers"} eq "") { $botClass->sendMsg ($info->{"chan"}, "Things fucked up"); return; }
            if (!$_cookies) { $_cookies = matchCookies ($homepage->{"headers"}); }
            my $selector = HTML::Query->new (text => $homepage->{"content"});
            my $prodName = $selector->query ("#non-product");
            if ($prodName->size < 1) {
                $botClass->sendMsg ($info->{"chan"}, "No offers available");
                return;
            }
            my $price    = $selector->query (".non-label-info .currency");
            my $keysLeft = $selector->query (".non-label-info");
            my ($day, $month, $year, $hour, $min);
            my $cnt = $homepage->{"content"};
            $cnt =~ /'day': (\d+)/; $day = $1;
            $cnt =~ /'month': (\d+)/; $month = $1;
            $cnt =~ /'year': (\d+)/; $year = $1;
            $cnt =~ /'hour': (\d+)/; $hour = $1;
            $cnt =~ /'min': (\d+)/; $min = $1;
            my $dt = DateTime->now->set_time_zone ('UTC');
            my ($diffd, $diffh, $diffm, $diffs) = Delta_DHMS ($dt->year(), $dt->month(), $dt->day(), $dt->hour(), $dt->minute(), $dt->second(), $year, $month, $day, $hour, $min, 0);
            #$botClass->sendMsg ($info->{"chan"}, "Got ${day}/${month}/${year} at ${hour}:${min} | difference: ${diffd}, ${diffh}, ${diffm}, ${diffs}");
            if ($diffd eq 0 and $diffh eq 0 and $diffm eq 0 and $diffs eq 0) {
                $botClass->sendMsg ($info->{"chan"}, "Assertion failed: the difference between the dates is zero");
                return;
            }
            my $dateStr = "";
            $dateStr .= "${diffd} day(s), " if ($diffd ne 0);
            $dateStr .= "${diffh} hour(s), " if ($diffh ne 0);
            $dateStr .= "${diffm} minute(s), " if ($diffm ne 0);
            $dateStr .= "${diffs} second(s), " if ($diffs ne 0);
            $dateStr  = substr ($dateStr, 0, (length ($dateStr) - 2));
            $dateStr .= " left";
            my @kL = $keysLeft->get_elements();
            $botClass->sendMsg ($info->{"chan"}, "Current offer: " . filterProductName ($prodName->first->as_trimmed_text) . ", discounted at " . $price->first->as_trimmed_text . " if you buy something >= 5e, " . $kL[1]->as_trimmed_text . " keys left, ${dateStr}");
        }
        elsif ($info->{"message"} =~ /^!getoffers\s?(\d+)?$/)
        {
            my $startingPage = ((defined $1 and $1 =~ /^([0-9]+)$/) ? $1 : 1);
            if ($startingPage <= 0) { $startingPage = 1; }
            my $homepage = do_get_request ("www.g2play.net", "/store/");
            if (ref ($homepage) ne "HASH" or $homepage->{"headers"} eq "") { $botClass->sendMsg ($info->{"chan"}, "Things fucked up"); return; }
            if (!$_cookies) { $_cookies = matchCookies ($homepage->{"headers"}); }
            my $banners = HTML::Query->new (text => $homepage->{"content"})->query (".baner");
            my @prices  = $banners->query (".baner-price")->get_elements;
            my @rbanne  = $banners->get_elements;
            if (scalar (@prices) ne $banners->size) {
                $botClass->sendMsg ($info->{"chan"}, "Assertion failed: BANNER_COUNT (" . $banners->size . ") != PRICES_COUNT (" . scalar(@prices) . ")");
                return;
            }
            # ---
            my $showFrom = ($startingPage - 1) * 5;
            my $showTo   = $startingPage * 5;
            print "Showing stuff from ${showFrom} to ${showTo}\n";
            if ($showTo < $showFrom or $showTo > $banners->size) {
                $botClass->sendMsg ($info->{"chan"}, "Invalid showTo / showFrom variables, aka something fucked up");
                return;
            }
            my $res = "Hello sweet lord, those are the latest discounts: ";
            for (my $i = $showFrom; $i < $showTo; $i++) {
                $res .= filterProductName ($rbanne[$i]->attr ("alt")) . " (" . chr (2) . $prices[$i]->as_trimmed_text . "€" . chr(2) . "); ";
            }
            $res = substr ($res, 0, (length ($res) - 2));
            $res .= ". Use \x02!getoffers " . ($startingPage + 1) . "\x02 to get more discounts";
            $botClass->sendMsg ($info->{"chan"}, $res);
        }
        elsif ($info->{"message"} =~ /^!getprice (.+)$/)
        {
            my $product = $1;
            if (!$_cookies) {
                print "Fetching cookies\n";
                my $obj = do_get_request ("www.g2play.net", "/store/");
                if (ref ($obj) ne "HASH" or $obj->{"headers"} eq "") { $botClass->sendMsg ($info->{"chan"}, "Things fucked up"); return; }
                $_cookies = matchCookies ($obj->{"headers"});
                if (!$_cookies) { $botClass->sendMsg ($info->{"chan"}, "One does not simply return empty cookies"); return; }
            }
            if ($product =~ /^[0-9]+$/) {
                if (scalar (@{$storedArray}) eq 0) {
                    $botClass->sendMsg ($info->{"chan"}, "Excuse me sir, but you should at least search once with !getPrice query");
                    return;
                }
                if (!defined ($storedArray->[int ($product)])) {
                    $botClass->sendMsg ($info->{"chan"}, "Excuse me sir, but you should provide a valid id");
                    return;
                }
                my $price = getPriceGivenLink ($storedArray->[$product]->[1]);
                if ($price eq -1) {
                    $botClass->sendMsg ($info->{"chan"}, "Excuse me sir, but I couldn't retrieve the price for some reason");
                    return;
                }
                $botClass->sendMsg ($info->{"chan"}, "The price of " . $storedArray->[$product]->[0] . " is " . $price);
                return;
            }
            #my $req = $ua->post ("http://www.g2play.net/store/suggestions.php", { "query" => $product });
            my $req = do_post_request ("www.g2play.net", "/store/suggestions.php", $_cookies, getPostQSFromHash ({"query"=>$product}));
            if (ref ($req) ne "HASH") {
                $botClass->sendMsg ($info->{"chan"}, "Something bad failed");
                return;
            }
            if ($req->{"content"} eq "" or $req->{"content"} eq "false") {
                $botClass->sendMsg ($info->{"chan"}, "I'm sorry sir, but your search produced 0 results");
                return;
            }
            my $js = $json->decode ($req->{"content"});
            if ($js eq 0) {
                $botClass->sendMsg ($info->{"chan"}, "I'm sorry sir, but your search produced 0 results");
                return;
            }
            if (ref ($js) ne "ARRAY") {
                $botClass->sendMsg ($info->{"chan"}, "I'm sorry sir, but the server sent something I couldn't understand");
                print Dumper ($js) . "\n";
                print $req->{"content"};
                return;
            }
            if (scalar (@{$js}) eq 1)
            {
                my $pr = getPriceGivenLink ($js->[0]->{"url"});
                my $prodName = filterProductName ($js->[0]->{"product"});
                if ($pr eq -1) {
                    $botClass->sendMsg ($info->{"chan"}, "Excuse me sir, but I couldn't retrieve the price for some reason");
                    return;
                }
                $botClass->sendMsg ($info->{"chan"}, "The price of ${prodName} is " . chr(2) . "${pr}" . chr(2));
                return;
            }
            my $res = "Dear sir, I've found the following results: ";
            my $currIndex = 0;
            foreach (@{$js})
            {
                if ($_->{"forsale"} eq "Y" and $_->{"avail"} eq "Y")
                {
                    my $prodName = filterProductName ($_->{"product"});
                    $storedArray->[$currIndex] = [ $prodName, $_->{"url"} ];
                    $res .= $prodName . " (id " . chr (2) . $currIndex++ . chr (2) . "), ";
                }
            }
            $res = substr ($res, 0, (length ($res) - 2));
            $botClass->sendMsg ($info->{"chan"}, $res);
        }
    }
}

sub filterProductName
{
    my $prodName = shift;
    $prodName =~ s/<(?:[^>'"]*|(['"]).*?\1)*>//gs;
    $prodName =~ s/(steam key|ea origin key|origin key)//ig;
    $prodName =~ s/\s\s+/ /g;
    $prodName =~ s/^\s+|\s+$//g;
    return $prodName;
}

sub getPriceGivenLink
{
    my $link = shift;
    print "Requesting ${link}\n";
    $link =~ s/^http:\/\/www\.g2play\.net//;
    my $datreq = do_get_request ("www.g2play.net", $link, $_cookies);
    if (ref ($datreq) ne "HASH") {
        print $datreq;
        return -1;
    }
    my @sel = HTML::Query->new (text => $datreq->{"content"})->query ("#product_price")->get_elements();
    if (scalar (@sel) < 1) {
        return -1;
    }
    return $sel[0]->as_trimmed_text . "€";
}

sub do_get_request {
    my ($target_hostname, $target_path, $cookies) = @_;
    my $daSocket = IO::Socket::INET->new (
        PeerHost => $target_hostname,
        PeerPort => 80,
        Proto    => "tcp"
    );
    if (not $daSocket) {
        return ("Error while connecting to ${target_hostname}: ${!}");
    }
    print $daSocket "GET ${target_path} HTTP/1.1\r\n";
    print $daSocket "Host: ${target_hostname}\r\n";
    print $daSocket "User-Agent: Mozilla/5.0 (Windows NT 6.1; WOW64; rv:25.0) Gecko/20130709 Firefox/25.0\r\n";
    print $daSocket "Cookie: ${cookies}\r\n" if $cookies;
    print $daSocket "Connection: close\r\n\r\n";
    my $daContent = "";
    $daContent .= $_ while (<$daSocket>);
    my @_trolo  = split /\r\n\r\n/, $daContent;
    my $headers = shift @_trolo;
    my $content = join ("\r\n\r\n", @_trolo);
    my @_tro2   = split /\n/, $content;
    shift @_tro2;
    pop @_tro2;
    return { "headers" => $headers , "content" => join ("\n", @_tro2) };
}

sub do_post_request {
    my ($target_hostname, $target_path, $cookies, $postdata) = @_;
    my $daSocket = IO::Socket::INET->new (
        PeerHost => $target_hostname,
        PeerPort => 80,
        Proto    => "tcp"
    );
    if (not $daSocket) {
        return  ("Error while connecting to ${target_hostname}: ${!}");
    }
    print $daSocket "POST ${target_path} HTTP/1.1\r\n";
    print $daSocket "Host: ${target_hostname}\r\n";
    print $daSocket "User-Agent: Mozilla/5.0 (Windows NT 6.1; WOW64; rv:25.0) Gecko/20130709 Firefox/25.0\r\n";
    print $daSocket "Cookie: ${cookies}\r\n" if $cookies;
    print $daSocket "Content-Length: " . length ($postdata) . "\r\n";
    print $daSocket "Content-Type: application/x-www-form-urlencoded\r\n";
    print $daSocket "Connection: close\r\n\r\n";
    print {$daSocket} $postdata;
    my $daContent = "";
    $daContent .= $_ while (<$daSocket>);
    my @_trolo  = split /\r\n\r\n/, $daContent;
    my $headers = shift @_trolo;
    my $content = join ("\r\n\r\n", @_trolo);
    my @_tro2   = split /\n/, $content;
    shift @_tro2;
    pop @_tro2;
    return { "headers" => $headers , "content" => join ("\n", @_tro2) };
}

sub matchCookies {
    my $headers = shift;
    my @matches = $headers =~ /^Set-Cookie: ([^=]+)=([^;]+);/gim;
    my $finalhash = {};
    for (my $i = 0; $i < scalar (@matches); $i += 2) {
        $finalhash->{$matches [$i]} = $matches [ ($i + 1) ];
    }
    return $finalhash;
}

sub getCookieStringFromHash {
    my $hashref = shift;
    my $str     = "";
    foreach (keys %{$hashref}) {
        $str .= "${_}=" . $hashref->{$_} . "; ";
    }
    $str = substr ($str, 0, (length ($str) - 2)); #strip ;[space]
    return $str;
}

sub getPostQSFromHash {
    my $hashref = shift;
    my $str = "";
    foreach (keys %{$hashref}) {
        $str .= uri_escape ($_) . "=". uri_escape ($hashref->{$_}) . "&";
    }
    $str = substr ($str, 0, (length ($str) - 1));
    return $str;
}
1;