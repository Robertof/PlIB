#!/usr/bin/perl
# Dynamic Modules Loader
# Author: Robertof
# Description: loads modules dynamically from IRC.
# Usage: !dml load/unload modulename or !dml list to list modules
# WARNING: CONFIGURE MODULE IN 'NEW' METHOD!
# Licence: GNU/GPL v3

package Plib::modules::dml;
use strict;
use warnings;

# /!\ CONFIGURE PLUGIN HERE !! /!\ #
sub new {
	# -- begin configuration -- #
	my $restricted = 0; # Only owners can load/unload/list modules ?
	# Configure this only if you have 'restricted' =  0
	my $guestcanUnload = 0; # Can non-owners unload modules?
	my $guestcanLoad   = 0; # Can non-owners load modules?
	my $guestcanDepends= 0; # Can non-owners show modules dependencies?
	my $guestcanListMod= 1; # Can non-owners list modules?
	my @owners = ("Robertof"); # Warning: owners can unload and load modules without
	                           # any limit
	my $id_check = 1; # Should bot check if the owners are identified (this makes 100% safe admin-functions of the plugin, but requires /msg nickserv identify)
	# -- end   configuration -- #
	my $options = {
		"restricted"     => $restricted,
		"guestcanunload" => $guestcanUnload,
		"guestcanload"   => $guestcanLoad,
		"guestcandepends"=> $guestcanDepends,
		"guestcanlistmod"=> $guestcanListMod,
		"owners"         => \@owners,
		"idchk"          => $id_check
	};
	bless $options, $_[0];
	return $options;
}

sub depends {
	return [] unless $_[0]->{"idchk"};
	return ["idcheck"];
}

sub atInit {};
sub atWhile {
	my ($self, $isTest, $botClass, $sent, $nick, $ident, $host) = @_;
	return 1 if $isTest;
	my $info;
	if ($nick and $ident and $host and $info = $botClass->matchMsg ($sent, 1)) {
		if ($info->{"message"} =~ /^!dml (load|unload|depends) ([^\s]+)$/i) {
			# Sanitize module name
			my $action = lc ($1);
			my $mname = $2;
			$mname =~ s/(;|\s|\.)//g;
			if ($mname =~ /^dml$/i and $action eq "unload") {
				$botClass->sendMsg ($info->{"chan"}, "Hey, are you crazy!?");
				return 1;
			}
			# Check perms..
			if ($self->havePerms ($botClass, $nick, $action)) {
				if ($action eq "depends" and exists $botClass->{"hooked_modules"}->{$mname}) {
					$botClass->sendMsg ($info->{"chan"}, "${mname}'s dependencies are: " . (scalar (@{$botClass->{"modules_deps"}->{$mname}}) <= 0 ? "none" : join (", ", @{$botClass->{"modules_deps"}->{$mname}})));
				} elsif (not exists $botClass->{"hooked_modules"}->{$mname} and $action eq "depends") {
					$botClass->sendMsg ($info->{"chan"}, "Module ${mname} is not loaded");
				} elsif ($action eq "load" and exists $botClass->{"hooked_modules"}->{$mname}) {
					$botClass->sendMsg ($info->{"chan"}, "Error: module is already loaded");
				} elsif ($action eq "unload" and not exists $botClass->{"hooked_modules"}->{$mname}) {
					$botClass->sendMsg ($info->{"chan"}, "Error: module is already unloaded / doesn't exist");
				} else {
					$botClass->sendMsg ($info->{"chan"}, ( $action eq "load"  ? "L" : "Unl" ) . "oading module '${mname}'..");
					my $realmname = "Plib::modules::${mname}";
					# Check if module exists / unloads successfully
					eval "require ${realmname}" if $action eq "load";
					if ($action eq "unload" and (my $p0rn = $botClass->check_dependencies ($mname))) {
						$botClass->sendMsg ($info->{"chan"}, "Error: cannot unload module '${mname}': it's a dependency of '${p0rn}'");
						return;
					}
					eval "no ${realmname}" if $action eq "unload";
					if (not $@) {
						# Module is valid / has unloaded
						$botClass->hook_modules ($mname) if $action eq "load";
						$botClass->unhook_module ($mname) if $action eq "unload";
						$botClass->{"hooked_modules"}->{$mname}->atInit (0, $botClass) if $action eq "load";
						$botClass->sendMsg ($info->{"chan"}, "Successfully " . ( $action eq "unload" ? "un" : "" ) . "loaded '${mname}'\n");
					} else {
						$botClass->sendMsg ($info->{"chan"}, "Module doesn't exist / Returned an error: $@");
						eval "no ${realmname}";
					}
				}
			} else {
				$botClass->sendMsg ($info->{"chan"}, "${nick}: you can't ${action} modules!");
			}
		} elsif ($info->{"message"} =~ /^!dml list$/i) {
			if ($self->havePerms ($botClass, $nick, "listmod")) {
				$botClass->sendMsg ($info->{"chan"}, "Loaded modules: " . $botClass->{"functions"}->hashJoin ("", ", ", 0, 1, $botClass->{"hooked_modules"}));
			} else {
				$botClass->sendMsg ($info->{"chan"}, "${nick}: you can't list modules!");
			}
		}
	}
}

sub havePerms {
	my ($self, $mainClass, $who, $forwhat) = @_;
	return 0 if ($self->{"restricted"} and not $mainClass->{"functions"}->in_array ($self->{"owners"}, $who));
	return 0 if (not $self->{"restricted"} and not $self->{"guestcan${forwhat}"} and not $mainClass->{"functions"}->in_array ($self->{"owners"}, $who));
	return ($self->{"idchk"} ? $mainClass->{"hooked_modules"}->{"idcheck"}->isIdentified ($who, $mainClass) : 1);
}

1;
