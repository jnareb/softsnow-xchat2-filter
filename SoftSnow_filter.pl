#!/usr/bin/perl

use strict;
use warnings;

### config ### 
my $filter_file = Xchat::get_info("xchatdir") . "/SoftSnow_filter.conf";
### end config ###

my $scriptName    = "SoftSnow XChat2 Filter";
my $scriptVersion = "2.0";
my $scriptDescr   = "Filter out file server announcements and IRC SPAM";

Xchat::register($scriptName, $scriptVersion, $scriptDescr);

Xchat::hook_command("FILTER", \&filter_command_handler);
Xchat::hook_server("PRIVMSG", \&privmsg_handler);

my $B = chr 2;  # bold
my $U = chr 31; # underline
my $C = chr 3;  # color

my $command_list = 'ON|OFF|STATUS|SERVER|SERVERON|ALL|HELP|DEBUG|PRINT|ALLOW|ADD|DELETE|SAVE|LOAD';

Xchat::print("Loading ${B}$scriptName $scriptVersion${B}\n".
             " For help: ${B}/FILTER HELP${B}\n");

my $filter_turned_on = 0; # was default turned ON
my $limit_to_server  = 0; # don't limit to server (host)
my $use_filter_allow = 0; # use overrides

# information about (default) options used
if ($filter_turned_on) {
	Xchat::print("Filter turned ${B}ON${B}\n");
} else {
	Xchat::print("Filter turned ${B}OFF${B}\n");
}
if ($limit_to_server) {
	Xchat::print("Filter limited to server $limit_to_server\n")
}
if ($use_filter_allow) {
	Xchat::print("Filter uses ALLOW rules\n");
}

# ------------------------------------------------------------

my @filter_allow = (
	q/^\@search\s/,
);

my @filter_deny = (
	q/\@/,
	q/^\s*\!/,
	q/slot\(s\)/,
	#q/~&~&~/,

	#xdcc
	q/^\#\d+/,

	#fserves
	q/(?i)fserve.*trigger/,
	q/(?i)trigger.*\!/,
	q/(?i)trigger.*\/ctcp/,
	q/(?i)type\:\s*\!/,
	q/(?i)file server online/,

	#ftps
	q/(?i)ftp.*l\/p/,

	#CTCPs
	q/SLOTS/,
	q/MP3 /,

	#messages for when a file is received/failed to receive
	q/(?i)DEFINITELY had the right stuff to get/,
	q/(?i)has just received/,
	q/(?i)I have just received/,

	#mp3 play messages
	q/is listening to/,
	q/\]\-MP3INFO\-\[/,

	#spammy scripts
	q/\]\-SpR\-\[/,
	q/We are BORG/,

	#general messages
	q/brave soldier in the war/,
);

# return 1 (true) if text given as argument is to be filtered out
sub isFiltered {
	my $text = shift;
	my $regexp = '';

	#strip colour, underline, bold codes, etc.
	$text = Xchat::strip_code($text);

	if ($use_filter_allow) {
		foreach $regexp (@filter_allow) {
			return 0 if ($text =~ /$regexp/);
		}
	}

	foreach $regexp (@filter_deny) {
		return 1 if ($text =~ /$regexp/);
	}

	return 0;
}

#called when someone says something in the channel
#1: address of speaker
#2: PRIVMSG constant
#3: channel
#4: text said (prefixed with :)
sub privmsg_handler {
	# $_[0] - array reference containing the IRC message or command
	#         and arguments broken into words
	# $_[1] - array reference containing the Nth word to the last word
	#my ($address, $constant, $chan) = @{$_[0]};
	my $text = $_[1][3]; # Get server message

	my $server = Xchat::get_info("host");


	return Xchat::EAT_NONE unless $filter_turned_on;
	if ($limit_to_server) {
		return Xchat::EAT_NONE unless $server eq $limit_to_server;
	}

	$text =~ s/^://;

	return isFiltered($text) ? Xchat::EAT_XCHAT : Xchat::EAT_NONE;
}

# ------------------------------------------------------------

sub save_filter {
	open F, ">$filter_file"
		or do {
			Xchat::print("${B}FILTER:${B} Couldn't open file to save filter: $!\n");
			return 1;
		};

	Xchat::print("${B}FILTER SAVE >$filter_file${B}\n");
	foreach my $regexp (@filter_deny) {
		Xchat::print("/".$regexp."/ saved\n");
		print F $regexp."\n";
	}
	Xchat::print("${B}FILTER SAVED ----------${B}\n");
	close F 
		or do {
			Xchat::print("${B}FILTER:${B} Couldn't close file to save filter: $!\n");
			return 1;
		};
	return 1;
}

sub load_filter {
	Xchat::print("${B}FILTER:${B} ...loading filter patterns\n");
	open F, "<$filter_file"
		or do {
			Xchat::print("${B}FILTER:${B} Couldn't open file to load filter: $!\n");
			return 1;
		};
	@filter_deny = <F>;
	map (chomp, @filter_deny);
	close F;

	Xchat::print("${B}FILTER DENY ----------${B}\n");
	for (my $i = 0; $i <= $#filter_deny; $i++) {
		Xchat::print(" [$i]: /".$filter_deny[$i]."/\n");
	}
	Xchat::print("${B}FILTER DENY ----------${B}\n");
}

sub add_rule ( $ ) {
	my $rule = shift;

	# always ading rules at the end
	push @filter_deny, $rule;
}

sub delete_rule ( $ ) {
	my $num = shift;

	# we have checked that $num is inside the boundaries
	@filter_deny = (@filter_deny[0..$num-1],@filter_deny[$num+1..$#filter_deny]);
}

# ============================================================
# ============================================================
# ============================================================

sub filter_command_handler ( $ ) {
	my ($arg) = $_[1][1]; # 1st word to the last word
	my $server = Xchat::get_info("host");

	#Xchat::print("/filter arg: |$arg|\n");
	if ($arg =~ /^ON\b/i) {
		$filter_turned_on = 1;
		Xchat::print("Filter turned ON\n");

	} elsif ($arg =~ /^OFF\b/i) {
		$filter_turned_on = 0;
		Xchat::print("Filter turned OFF\n");

	} elsif ($arg =~ /^STATUS\b/i || !$arg) {
		if ($filter_turned_on) {
			Xchat::print("Filter is turned ${B}ON${B}\n");
		} else {
			Xchat::print("Filter is turned ${B}OFF${B}\n");
		}
		if ($limit_to_server) {
			Xchat::print("Filter is limited to ".
			             ($server eq $limit_to_server ? "${B}current${B} " : "" ).
			             "server $limit_to_server");
		}
		if ($use_filter_allow) {
			Xchat::print("Filter is using ALLOW rules (before DENY)\n");
		}

	} elsif ($arg =~ /^SERVER\b/i) {
		if ($limit_to_server) {
			Xchat::print("${B}FILTER:${B} Changing server from $limit_to_server to $server\n");
		} else {
			Xchat::print("${B}FILTER:${B} Limiting filtering to server $server\n");
		}
		$limit_to_server = $server;

	} elsif ($arg =~ /^SERVERON\b/i) {
		if ($limit_to_server) {
			Xchat::print("${B}FILTER:${B} Changing server from $limit_to_server to $server\n");
		} else {
			Xchat::print("${B}FILTER:${B} Limiting filtering to server $server\n");
		}
		$limit_to_server = $server;

		$filter_turned_on = 1;
		Xchat::print("Filter turned ${B}ON${B}\n");
	} elsif ($arg =~ /^ALL\b/i) {
		if ($limit_to_server) {
			Xchat::print("Filter: Removing limit to server $limit_to_server\n");
		}
		$limit_to_server = 0;

	} elsif ($arg =~ /^HELP\b/i) {
		Xchat::print(<<"EOF");
${B}/FILTER $command_list${B}
/FILTER ON|OFF - turns filtering on/off
/FILTER HELP - prints this help message
/FILTER STATUS - prints if filter is turned on, and with what limits
/FILTER DEBUG - shows some info; used in debuggin the filter
/FILTER PRINT - prints all the rules
/FILTER ALLOW - toggle use of ALLOW rules (before DENY).
/FILTER SERVER - limits filtering to current server (host)
/FILTER SERVERON - limits to server and turns filter on
/FILTER ALL - resumes filtering everywhere i.e. removes limits
/FILTER SAVE - saves the rules to the file $filter_file
/FILTER LOAD - loads the rules from the file, replacing existing rules
/FILTER ADD <rule> - add rule at the end of the DENY rules
/FILTER DELETE [<num>] - delete rule number <num>, or last rule
/FILTER VERSION - prints the name and version of this script
/FILTER without parameter is equivalent to /FILTER STATUS
EOF

	} elsif ($arg =~ /^VERSION\b/i) {
		Xchat::print("${B}$scriptName $scriptVersion${B}\n");

	} elsif ($arg =~ /^DEBUG\b/i || $arg =~ /^INFO\b/i) {
		Xchat::print("${B}FILTER DEBUG ----------${B}\n");
		Xchat::print("Channel: ".Xchat::get_info("channel")."\n");
		Xchat::print("Server:  ".Xchat::get_info("server")."\n");
		Xchat::print("Network: ".Xchat::get_info("network")."\n");
		Xchat::print("Host:    ".Xchat::get_info("host")."\n");
		Xchat::print("${B}FILTER DEBUG ----------${B}\n");

	} elsif ($arg =~ /^PRINT/i) {
		Xchat::print("${B}FILTER PRINT ----------${B}\n");
		Xchat::print("${B}ALLOW${B}".($use_filter_allow ? ' (on)' : ' (off)')."\n");
		for (my $i = 0; $i <= $#filter_allow; $i++) {
			Xchat::print("[$i]: /".$filter_allow[$i]."/\n");
		}
		Xchat::print("${B}DENY${B}\n");
		for (my $i = 0; $i <= $#filter_deny; $i++) {
			Xchat::print("[$i]: /".$filter_deny[$i]."/\n");
		}
		Xchat::print("${B}FILTER PRINT ----------${B}\n");

	} elsif ($arg =~ /^ALLOW/i) {
		$use_filter_allow = !$use_filter_allow;
		Xchat::print("${B}FILTER:${B} ALLOW rules ".
		             ($use_filter_allow ? "enabled" : "disabled")."\n");

	} elsif ($arg =~ /^ADD\s+(.*)/i) {
		if ($1) {
			add_rule($1);
			Xchat::print("${B}FILTER RULE [$#filter_deny]:${B} /$1/\n");
		} else {
			Xchat::print("Syntax: ${B}/FILTER ADD ${U}rule${U}${B} to add\n")
		}

	} elsif ($arg =~ /^DELETE(.*)/i) {
		my $num = $1;
		$num =~ s/^\s*(.*?)\s*$/$1/g;
	SWITCH: {
			unless ($num) {
				Xchat::print("${B}FILTER:${B} deleting /".$filter_deny[-1]."/\n");
				$#filter_deny--;
				Xchat::print("${B}FILTER:${B} deleted successfully last rule\n");
				last SWITCH;
			}
			if ($num !~ /^\d+$/) { 
				Xchat::print("${B}FILTER:${B} $num is not a number\n");
				last SWITCH;
			}
			if ($num < 0 || $num > $#filter_deny) {
				Xchat::print("${B}FILTER:${B} $num outside range [0,$#filter_deny]\n");
				last SWITCH;
			}
			Xchat::print("${B}FILTER:${B} deleting /".$filter_deny[$num]."/\n");
			delete_rule($num);
			Xchat::print("${B}FILTER:${B} deleted successfully rule $num\n");
		}

	} elsif ($arg =~ /^SAVE/i) {
		save_filter();
		Xchat::print("${B}FILTER:${B} saved DENY rules to $filter_file\n");

	} elsif ($arg =~ /^(RE)?LOAD/i) {
		load_filter();
		Xchat::print("${B}FILTER:${B} loaded DENY rules from $filter_file\n");

	} else {
		Xchat::print("/filter arg: |$arg|\n") if $arg;
	}
	return 1;
}

1;
