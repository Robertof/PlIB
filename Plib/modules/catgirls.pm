#!/usr/bin/perl
# PlIB most awesome plugin.
# Author: alfateam123
# Licence: WTFPL (hey, it's an 'hello world' plugin!)

package Plib::modules::catgirls;
use strict;
use warnings;

use XML::FeedPP;
use List::Util qw(shuffle); 

my $hasLoaded=0;
my @posts;
my @shownPosts;
#I NEED MOAR SOURCES!
my @sources=(
             "http://catgirlsdoingcatthings.tumblr.com/rss",
             "http://nocatgirls.tumblr.com/rss",
             "http://tangopapatango.tumblr.com/rss",
             "http://notd.tumblr.com/rss"
             );

#version 0.2 will include a NSFW filter.

sub new {
	return $_[0];
}

sub atInit {
	#BEWARE: this function is not called if 
	#the plugin is loaded after PlIB startup
	#(aka !dml load catgirls)

	my ($self, $isTest, $botClass) = @_;
	return 1 if $isTest;
	#$botClass->sendMsg ($botClass->getAllChannels (",", 0), "Hello world!");
}

sub atWhile {
	my ($self, $isTest, $botClass, $sent, $nick, $ident, $host) = @_;
	return 1 if $isTest;

    unless ($hasLoaded)
    {
    	&loadCatgirls;
    	$hasLoaded=1;
    }

	my $info;
	if ($nick and $ident and $host and $info = $botClass->matchMsg ($sent)){
		if ($info->{"message"} =~ /^I want a catgirl!$/i 
		    or $info->{"message"} =~ /^nyaa\?$/i
		    or $info->{"message"} =~ /^A catgirl is fine too!$/i
		    ) {
			$botClass->sendMsg($info->{"chan"}, randomCatgirl());
	    }
	    elsif ($info->{"message"} =~ /^Check a catgirl! (.*)/i){
	    	my $lostCatgirl = $1;
	    	$botClass->sendMsg($info->{"chan"}, ">> ".$lostCatgirl." <<".checkACatgirl($lostCatgirl));
	    }
	    elsif($info->{"message"} =~ /^Reload the catgirls!$/i){
	    	$botClass->sendMsg($info->{"chan"}, "*activates Catgirl Finder* it may take a while...");
	    	&loadCatgirls;
	    	$botClass->sendMsg($info->{"chan"}, "ok, I got 'em all!");
	    }
	    elsif($info->{"message"} =~ /^Get older catgirls!/){
	    	$botClass->sendMsg($info->{"chan"}, "this functionality is not available at the time.")
	    }
	    elsif ($info->{"message"} =~ /^CATGIRLS!$/i)
	    {
	    	#the help
	    	$botClass->sendMsg($info->{"chan"}, "Commands you can issue:");
	    	$botClass->sendMsg($info->{"chan"}, "*) nyaa? | I want a catgirl! | A catgirl is fine too : get a random catgirl");
	   		$botClass->sendMsg($info->{"chan"}, "*) Reload the catgirls! : reload the archive. useful for long-running bots");
	   		$botClass->sendMsg($info->{"chan"}, "*) Get older catgirls! : finds moar catgirls");
	   		$botClass->sendMsg($info->{"chan"}, "*) Check a catgirl! [url] : for debugging purposes. if in doubt, try launching 'Reload the catgirls!' command");
	    }
    }
}

sub checkACatgirl{
	my $lostCatgirl=shift;

	foreach my $catgirl (@posts)
	{
		return "gotcha!" if $catgirl eq $lostCatgirl;
	}
	return "we lost a catgirl ç_ç";
}

sub getLinkOnly{
	my $description=shift;

	$description =~ m/http:\/\/([^>"]*)/i;
	return "http://".$1;
}

sub loadCatgirls{
	foreach my $source (@sources)
	{
		my $feed=XML::FeedPP->new($source);
		#version 0.2: I must find a better way of taking photos
		foreach my $post ($feed->get_item())
		{
			#not everyone leaves the default "Photo" title.
			my $title=$post->title;
			if (   $title =~ /Photo/i
			    or $title =~ /No Catgirls Here/i
			    or $title =~ /pixiv/i
			    ) {
				my $link=getLinkOnly($post->description());
				push(@posts, $link);
			}
		}
	}
	#just to do something funny.
	@posts=shuffle @posts;
	@shownPosts=();
}

sub randomCatgirl{
	my $posts_length=scalar @posts;
	return "WTF" if $posts_length<1;

	my $index=int(rand($posts_length));
	my $message=$posts[$index];
	#done in order to avoid "reposts"
	splice @posts, $index, 1;
	push(@shownPosts, $message);

    #doing some checks
    #maybe I need a better heuristic. this reloads
    #the archive when half of posts are shown.
    &loadCatgirls if (scalar @posts < scalar @shownPosts);

	return $message;
}

1;
