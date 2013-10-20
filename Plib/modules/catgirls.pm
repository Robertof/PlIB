#!/usr/bin/perl
# PlIB most awesome plugin.
# Author: alfateam123
# Licence: WTFPL (hey, it's an 'hello world' plugin!)

package Plib::modules::catgirls;
use strict;
use warnings;

use JSON;
use XML::FeedPP;
use List::Util qw(shuffle); 
my $hasLoaded=0;
my @posts;
my @shownPosts;
#now they are read from file.
my @sources=();
my @unloaded_sources=();

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
		    or $info->{"message"} =~ /nyaa\?/i
		    or $info->{"message"} =~ /A catgirl is fine too!/i
		    ) {
			  $botClass->sendMsg($info->{"chan"}, randomCatgirl());
	    }
	    elsif ($info->{"message"} =~ /Check a catgirl! (.*)/i){
	    	my $lostCatgirl = $1;
	    	$botClass->sendMsg($info->{"chan"}, ">> ".$lostCatgirl." <<".checkACatgirl($lostCatgirl));
	    }
	    elsif($info->{"message"} =~ /Reload the catgirls!/i){
	    	$botClass->sendMsg($info->{"chan"}, "*activates Catgirl Finder* it may take a while...");
	    	&loadCatgirls;
	    	$botClass->sendMsg($info->{"chan"}, "ok, I got 'em all!");
        #bugfix  #5 start
        unless(scalar @unloaded_sources == 0)
        {
            my $unloaded_msg="These catgirl sources are closed or unreachable: ";
            foreach my $bad_source (@unloaded_sources)
            {
                $bad_source = isolateSource($bad_source);
                $unloaded_msg .=" $bad_source ~";
            }
            $unloaded_msg =~ s/ ~$/. /;
            $unloaded_msg.= "We are sad, you can't see all the catgirls you requested. Try to fix the sources using \"remove a source!\" and \"add a source!\"";
            $botClass->sendMsg($info->{"chan"}, $unloaded_msg);
        }
        #end bugfix #5
	    }
	    elsif($info->{"message"} =~ /Get older catgirls!/i){
	    	$botClass->sendMsg($info->{"chan"}, "this functionality is not available at the time.")
	    }
      elsif($info->{"message"} =~ /Gimme the sources!/i)
      {
        $botClass->sendMsg($info->{"chan"}, "The sources are: ".printSources());
      }
	    elsif($info->{"message"} =~ /Add a source! (.*)/i){
        $botClass->sendMsg($info->{"chan"}, addSource($1));
      }
      elsif($info->{"message"} =~ /Remove a source! (.*)/i){
        $botClass->sendMsg($info->{"chan"}, removeSource($1));
      }
      elsif ($info->{"message"} =~ /^CATGIRLS!$/i)
	    {
	    	#the help
	    	$botClass->sendMsg($info->{"chan"}, "Commands you can issue:");
	    	$botClass->sendMsg($info->{"chan"}, "*) nyaa? | I want a catgirl! | A catgirl is fine too : get a random catgirl");
	   		$botClass->sendMsg($info->{"chan"}, "*) Reload the catgirls! : reload the archive. useful for long-running bots");
	   		$botClass->sendMsg($info->{"chan"}, "*) Get older catgirls! : finds moar catgirls");
        $botClass->sendMsg($info->{"chan"}, "*) Gimme the sources! : lists the sources ");
        $botClass->sendMsg($info->{"chan"}, "*) Add a source! [RSS Tumblr Feed] : adds a source to the sources");
        $botClass->sendMsg($info->{"chan"}, "*) Remove a source! [Tumblr name] : removes a source from the sources. example for \"Tumblr name\": http://fredrin.tumblr.com --> fredrin");
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
  @posts = (); #I forgot it. >_>
  @shownPosts = ();
  @sources=loadSources();
  @unloaded_sources=();
	foreach my $source (@sources)
	{
    #bugfix #5 start
    #old: my $feed = XML::FeedPP->new($source);
    my $feed;
    eval{
		  $feed = XML::FeedPP->new($source);
    };
    if ($@)
    {
        push(@unloaded_sources, $source);
        next; 
    }
    #end bugfix #5
		#version 0.2: I must find a better way of taking photos
		foreach my $post ($feed->get_item())
		{
			#not everyone leaves the default "Photo" title.
			my $title = $post->title;
			if (#   $title =~ /Photo/i
			    #or $title =~ /No Catgirls Here/i
			    #or $title =~ /pixiv/i
            $post->description =~ /<img src="http:\/\/([^>"]*)"/
			    ) {
				my @cat = (getLinkOnly($post->description), $post->guid);
				push(@posts, @cat);
			}
		}
	}

    #bugfix #1: [duplicates, maybe?] start
    #quite-linear solution, guaranteed to remove duplication of links.
    #my %set=();
    #foreach my $link (@posts)
    #{
    #    $set{$link}=1;
    #}
    #@posts=keys %set;

    my %unique_image_links=();
    my $lposts= scalar @posts;
    my $i=0;
    while($i<$lposts)
    {
        my $image_link=$posts[$i];
        my $tumblr_link=$posts[$i+1];
        $unique_image_links{$image_link}=$tumblr_link;
        $i+=2;
    }

    my @links=keys %unique_image_links;
    $i=scalar @links;
    @posts=();
    while($i>=0)
    {
        push(@posts, ($links[$i], $unique_image_links{$links[$i]}));
        $i--;
    }
    #end bugfix #1

}

sub randomCatgirl{
	my $posts_length=scalar @posts;
	return "WTF" if $posts_length<1;

    my $index=int(rand($posts_length));
    #we want link_to_original (link to tumblr), and
    #we know that link_to_original is in even positions.
    $index-- if $index&1; 

    my $message=$posts[$index] . ' (' . $posts[$index+1] . ')';

    #done in order to avoid "reposts"
    push(@shownPosts, $posts[$index]);
    push(@shownPosts, $posts[$index+1]);
	splice @posts, $index, 2; #we have to remove the tumblr link too.

	#doing some checks
	#maybe I need a better heuristic. this reloads
	#the archive when half of posts are shown.
	&loadCatgirls if (scalar @posts < scalar @shownPosts);

	return $message;
}

sub printSources{
    my $sourceList="";
    foreach my $source (@sources)
    {
        chomp $source;
        $source =~ m/http:\/\/(.*)\.tumblr\.com\/rss/;
        $sourceList.="$1 ($source) ~ ";
    }
    $sourceList =~ s/ ~ $//; #removing last ~
    return $sourceList;
}

sub loadSources{
    open (SOURCES, "<", "./Plib/modules/databases/catgirls/sources.txt") || return ("can't read the sources!",);
    my @tumblr_names=<SOURCES>;
    my @read_sources=();
    
    foreach my $name (@tumblr_names)
    {
      chomp $name;
      push @read_sources, "http://$name.tumblr.com/rss";
    }
    return @read_sources;
}

sub addSource{
    my $newSource=shift;
    #"dat case sensitiveness!"  
    $newSource = lc $newSource;
    #end 
    $newSource =~ s/^\s+|\s+$//g;
    return "JUST THE TUMBLR NAME, YOU SMART ASS!" if $newSource =~ /^http/;
    return "$newSource is already a source!" if findSource("http://$newSource.tumblr.com/rss")>-1;

    push @sources, "http://$newSource.tumblr.com/rss";
    
    open SOURCES, ">>", "./Plib/modules/databases/catgirls/sources.txt" or
        return "can't open the source database!";
    print SOURCES $newSource."\n";
    close SOURCES;
    #bugfix #6 start
    return "We'll look for catgirls there. Thanks for your suggestion!";
    #end bugfix #6
}

sub removeSource{
   my $oldSource = shift;
   #"dat case sensitiveness!"  
   $oldSource = lc $oldSource;
   #end 
   $oldSource=~ s/^\s+|\s+$//g;
   my $oldSourceUrl="http://$oldSource.tumblr.com/rss";
   return "$oldSource is not even a source!" unless findSource($oldSourceUrl)>-1;
   
   my $index=findSource($oldSourceUrl);
   splice(@sources, $index, 1);
   open SOURCES, ">", "./Plib/modules/databases/catgirls/sources.txt" or return "can't open the source database!";
   foreach my $source (@sources)
   {
     $source =~ m/http:\/\/(.*)\.tumblr\.com\/rss/;
     print SOURCES $1."\n";
   }
   close SOURCES;
    #bugfix #6 start
    return "We'll no longer look for catgirls there anymore. Thanks for your suggestion!";
    #end bugfix #6
}

sub findSource{
   my $sourceLookingFor=shift;
   my $index=0;
   foreach my $source (@sources)
   {
      return $index if $source eq $sourceLookingFor;
      $index++;
   }
   return -1;
}

#bugfix #5 start
#not directly related with the bugfix
#used only for show the source name
sub isolateSource{
    my $url = shift;
    $url =~ m/http\:\/\/(.*)\.tumblr.com/;
    return $1;
}
#end bugfix #5

1;
