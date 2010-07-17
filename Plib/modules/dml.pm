#!/usr/bin/perl
# Dynamic Modules Loader
# Author: Robertof
# Description: loads modules dynamically from IRC.
# Usage: !dml load/unload modulename or !dml list to list modules
# WARNING: CONFIGURE MODULE IN 'NEW' METHOD!
# Licence: GNU/GPL v3

package Plib::modules::dml;

# /!\ CONFIGURE PLUGIN HERE !! /!\ #
sub new {
	# -- begin configuration -- #
	my $restricted = 0; # Only owners can load/unload/list modules ?
	# Configure this only if you have 'restricted' =  0
	my $guestcanUnload = 0; # Can non-owners unload modules?
	my $guestcanLoad   = 0; # Can non-owners load modules?
	my $guestcanListMod= 1; # Can non-owners list modules?
	my @owners = ("Robertof"); # Warning: owners can unload and load modules without
	                           # any limit
	# -- end   configuration -- #
	my $options = {
		"restricted"     => $restricted,
		"guestcanunload" => $guestcanUnload,
		"guestcanload"   => $guestcanLoad,
		"guestcanlistmod"=> $guestcanListMod,
		"owners"         => \@owners
	};
	bless $options, $_[0];
	return $options;
}

sub atInit {};
sub atWhile {
	my ($self, $isTest, $botClass, $sent, $nick, $ident, $host) = @_;
	return 1 if $isTest;
	my $info;
	if ($nick and $ident and $host and $info = $botClass->matchMsg ($sent)) {
		if ($info->{"message"} =~ /^!dml (load|unload) ([^\s]+)/i) {
			# Sanitize module name
			my $action = lc ($1);
			my $mname = $2;
			$mname =~ s/(;|\s|\.)//g;
			# Check perms..
			if ($self->havePerms ($nick, $action)) {
				if ($action eq "load" and exists $botClass->{"hooked_modules"}->{$mname}) {
					$botClass->sendMsg ($info->{"chan"}, "Error: module is already loaded");
				} elsif ($action eq "unload" and not exists $botClass->{"hooked_modules"}->{$mname}) {
					$botClass->sendMsg ($info->{"chan"}, "Error: module is already unloaded");
				} else {
					$botClass->sendMsg ($info->{"chan"}, ( $action eq "load"  ? "L" : "Unl" ) . "oading module '${mname}'..");
					my $realmname = "Plib::modules::${mname}";
					# Check if module exists / unloads successfully
					eval "require ${realmname}" if $action eq "load";
					
					delete $botClass->{"hooked_modules"}->{$mname} if $action eq "unload";
					eval "no ${realmname}" if $action eq "unload";
					if (not $@) {
						# Module is valid / has unloaded
						$botClass->{"hooked_modules"}->{$mname} = $realmname if $action eq "load";
						$botClass->sendMsg ($info->{"chan"}, "Successfully " . ( $action eq "unload" ? "un" : "" ) . "loaded '${mname}'\n");
					} else {
						$botClass->sendMsg ($info->{"chan"}, "Module doesn't exist");
					}
				}
			} else {
				$botClass->sendMsg ($info->{"chan"}, "Permission denied");
			}
		} elsif ($info->{"message"} =~ /^!dml list/i) {
			if ($self->havePerms ($nick, "listmod")) {
				$botClass->sendMsg ($info->{"chan"}, "Loaded modules: " . $botClass->{"functions"}->hashJoin ("", ", ", 0, 1, $botClass->{"hooked_modules"}));
			} else {
				$botClass->sendMsg ($info->{"chan"}, "Permission denied");
			}
		}
	}
}

sub havePerms {
	my ($self, $who, $forwhat) = @_;
	return 0 if ($self->{"restricted"} and not $self->in_array ($self->{"owners"}, $who));
	return 0 if (not $self->{"restricted"} and not $self->{"guestcan${forwhat}"} and not $self->in_array ($self->{"owners"}, $who));
	return 1;
}
	
# Thx to go4expert
sub in_array {
	my ($self, $arr, $search_for) = @_;
	foreach my $value (@$arr) {
		return 1 if $value eq $search_for;
	}
	return 0;
}

1;
