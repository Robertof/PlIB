#!/usr/bin/perl

###############################################################
# @name..................................................plib #
# @realname.......................................PerL IrcBot #
# @author............................................Robertof #
# @mail.....................................robertof@anche.no #
# @licence..........................................GNU/GPL 3 #
# @lang..................................................Perl #
# @requirements...IO::Socket::INET or IO::Socket::SSL for SSL #
# @isthisfinished.........................................yes #
#                            Enjoy                            #
###############################################################

use strict;
use warnings;
use Plib::main;
# Usage: new (nick, user, real, idpass, isop, debug, usessl, server, port)
# !! WARNING !! Use class->setChans (chan1:key, chan2:key, chan3, chan4, ecc.) to add chans to join !!
my $plib = Plib::main->new ("Plib", "plib", "PerL IrcBot", "", 0, 1, 1, "irc.unitx.net", 6697);
$plib->setChans ("#Unit-X");
### ↓↓↓↓↓ OPTIONAL MODULES ↓↓↓↓↓                                     ###
#   Usage: $mainclass->hook_modules (module1, module2, module3 ecc.) ###
$plib->hook_modules ("firstplugin", "idcheck", "dml", "autorejoin", "fastkill", "autoreconnect");
#
$plib->startAll;
