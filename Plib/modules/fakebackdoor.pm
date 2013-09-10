#!/usr/bin/perl
# Usage: !startbackdoor [chan] [user] [operating_system(between windows and linux)]
#        !stopbackdoor
package Plib::modules::fakebackdoor;
use warnings;
use strict;
use threads;

# /!\ CONFIGURE PLUGIN HERE !! /!\ #
sub new {
	# -- begin configuration -- #
	my @owners = ("Robertof"); # Who can use !startbackdoor and !stopbackdoor
	my $id_check = 1; # Should bot check if the owners are identified (this makes 100% safe admin-functions of the plugin, but requires /msg nickserv identify)
	# -- end   configuration -- #
	my $options = {
		"owners"         => \@owners,
		"idchk"          => $id_check,
		"thread"         => undef
	};
	bless $options, $_[0];
	return $options;
}

sub depends {
	return [] unless $_[0]->{"idchk"};
	return ["idcheck"];
}

sub atInit {}
sub atWhile {
	my ($self, $isTest, $botClass, $sent, $nick, $ident, $host) = @_;
	return 1 if $isTest;
	my $info;
	if ($nick and $ident and $host and $info = $botClass->matchMsg ($sent, 1)) {
		if ($info->{"message"} =~ /^!startbackdoor (#[^\s]+) ([^\s]+) (windows|linux) ([^\s]+) (.+?)$/i and $self->havePerms ($nick, $botClass)) {
			my ($chan, $user, $so, $provider, $subnet) = ($1, $2, $3, $4, $5);
			return $botClass->sendMsg ($info->{"chan"}, "Sorry: bot is already busy on ${chan}, 'backdooring' ${user}. Use !stopbackdoor to stop the bot!") if defined $self->{"thread"};
			$self->{"thread"} = threads->new (sub {
				my ($class, $bc, $ch, $usr, $os, $pr, $sub) = @_;
				$SIG{"KILL"} = sub { threads->exit(); };
				my @linux_backdoors = ("doom's bAckDo0rZ v2.3 By doom", "KerNel >2.6.17 rooT exPLoiT bY Linux Owning Team", "memCachingExploit by DangoHaurd", "n33dm0r3 b4ckd00r by NUKEALL");
				my @win32_backdoors = ("ultimatewinbackdoor v2.4 by ExLuser", "AdminRights Explua by WinCoder", "FuckWIN exploit v3.2 by FuckWin Team", "winKernelXplua by Kernel Debuggers", "BrainStorm's Windows Vuln by BrainStorm");
				my $backdoor = ($os eq "linux" ? $linux_backdoors[int(rand(4))] : $win32_backdoors[int(rand(4))]);
				$bc->sendMsg ($ch, "Injecting ${backdoor} in ${usr}'s PC (Internet provider: ${pr}, subnet: ${sub})...");
				sleep (int (rand (3)) + 3);
				$bc->sendMsg ($ch, "Successfully injected the executable! It was injected in RAM's address 0x" . $class->genRandomHexCode . "!");
				$bc->sendMsg ($ch, "[Exploit's output] " . ($os eq "linux" ? "Granting root rights.." : "Granting administrator rights.."));
				sleep (int (rand (2)) + 5);
				$bc->sendMsg ($ch, "[Exploit's output] Full " . ($os eq "linux" ? "root" : "administrator") . " rights granted!");
				sleep (2);
				$bc->sendMsg ($ch, "[Exploit's output] Injecting the backdoor in the Master Boot Record (MBR) ..");
				sleep (int (rand (3)) + 2);
				$bc->sendMsg ($ch, "[Exploit's output] Done!");
				$bc->sendMsg ($ch, "[Exploit's output] Waiting for my master's connection (listening on the port 1337) ...");
				sleep (int (rand (6)) + 9);
				$bc->sendMsg ($ch, "[Exploit's output] Connection detected ! Checking autenticity..");
				sleep (int (rand (2)) + 5);
				$bc->sendMsg ($ch, "[Exploit's output] Connection authenticated, waiting for commands..");
				sleep (int (rand (5)) + 4);
				$bc->sendMsg ($ch, "[Exploit's output] Running command '" . ($os eq "linux" ? "mkfs -t ext3 /dev/sda1" : "format C:") . "' with " . ($os eq "linux" ? "root" : "administrator") . " rights..");
				my @harddisks = ("Western Digital WD2500AAJS-07M0A0", "Maxtor FNCCLQ3", "Seagate Barracuda ST3500830AS");
				$bc->sendMsg ($ch, "[Exploit's output] [shell output] Making a new filesystem on hard disk " . ($os eq "linux" ? "/dev/sda1" : "C:") . " (" . $harddisks[int (rand (3))] . ") ...");
				my $i;
				for ($i = 1; $i <= 100; $i++) {
					$bc->sendMsg ($ch, "[Exploit's output] [shell output] [" . ("=" x ($i-1)) . ">" . (" " x (100 - $i)) . "] - ${i}% completed");
					$i += int (rand (20)) + 1;
					sleep (int (rand (6)) + 3);
				}
				if ($i > 100 || $i < 100) { $bc->sendMsg ($ch, "[Exploit's output] [shell output] [" . "=" x 100 . "] - 100% completed"); };
				sleep (2);
				$bc->sendMsg ($ch, "[Exploit's output] [shell output] Done! Hard disk " . ($os eq "linux" ? "/dev/sda1" : "C:") . " got a new " . ($os eq "linux" ? "ext3" : "ntfs") . " filesystem!");
				sleep (int (rand (2)) + 2);
				$bc->sendMsg ($ch, "[Exploit's output] Error at memory address 0x" . $class->genRandomHexCode . ": " . ($os eq "linux" ? "/dev/sda" : "C:") . " - device or resource not available");
				sleep (2);
				$bc->sendMsg ($ch, "[Exploit's output] Error at memory address 0x" . $class->genRandomHexCode . ": " . ($os eq "linux" ? "/home" : "C:\\WINDOWS") . " - no such file or directory");
				$bc->sendMsg ($ch, "[Exploit's output] MULTIPLE ERRORS DETECTED, SHUTDOWNING EXPLOIT. Please reboot the infected system!");
				sleep (2 + int (rand (2)));
				$bc->sendMsg ($ch, "[Exploit's output] Connection with my master lost (reason: killing all opened connections)");
				$bc->sendMsg ($ch, "Exploit terminated abnormally (exit code: 125), shutting down connections.");
				$class->yeahItsFinished ($class);
			}, $self, $botClass, $chan, $user, $so, $provider, $subnet);
		} elsif ($info->{"message"} =~ /^!stopbackdoor$/ and $self->havePerms ($nick, $botClass)) {
			$self->{"thread"}->kill ("KILL")->detach();
			$self->{"thread"} = undef;
		}
	}
}

sub havePerms {
	my ($self, $nick, $mainClass) = @_;
	return 0 if not $mainClass->{"functions"}->in_array ($self->{"owners"}, $nick);
	return ( $self->{"idchk"} ? $mainClass->{"hooked_modules"}->{"idcheck"}->isIdentified ($nick, $mainClass) : 1 );
}

sub genRandomHexCode {
	my @charmap = split //, "0123456789ABCDEF";
	my $str = "";
	for (1..8) {
		$str .= $charmap[int (rand (scalar (@charmap)))];
	}
	return $str;
}

sub yeahItsFinished {
	$_[1]->{"thread"}->kill ("KILL")->detach();
	$_[1]->{"thread"} = undef;
}
1;
