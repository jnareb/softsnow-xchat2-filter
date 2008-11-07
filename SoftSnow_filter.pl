#!/usr/bin/perl

use strict;
use warnings;


my $scriptName    = "SoftSnow XChat2 Filter";
my $scriptVersion = "2.0.4";
my $scriptDescr   = "Filter out file server announcements and IRC SPAM";

my $B = "\cB"; # bold
my $U = "\cU"; # underline
my $C = "\cC"; # start of color sequence

### config ###
my $filter_file = Xchat::get_info("xchatdir") . "/SoftSnow_filter.conf";

my $filter_turned_on = 0;  # was default turned ON
my $limit_to_server  = ''; # don't limit to server (host)
my $use_filter_allow = 0;  # use overrides
### end config ###

my $command_list = 'ON|OFF|STATUS|SERVER|SERVERON|ALL|HELP|DEBUG|PRINT|ALLOW|ADD|DELETE|SAVE|LOAD';

my $scriptHelp = <<"EOF";
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
/FILTER SHOW   [<num>] - show rule number <num>, or last rule
/FILTER VERSION - prints the name and version of this script
/FILTER without parameter is equivalent to /FILTER STATUS
EOF

Xchat::register($scriptName, $scriptVersion, $scriptDescr);

Xchat::hook_command("FILTER", \&filter_command_handler,
                    { help_text => $scriptHelp });
Xchat::hook_server("PRIVMSG", \&privmsg_handler);

Xchat::print("Loading ${B}$scriptName $scriptVersion${B}\n".
             " For help: ${B}/FILTER HELP${B}\n");


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

	return isFiltered($text) ? Xchat::EAT_ALL : Xchat::EAT_NONE;
}

# ------------------------------------------------------------

sub save_filter {
	my $fh;

	unless (open $fh, '>', $filter_file) {
		Xchat::print("${B}FILTER:${B} Couldn't open file to save filter: $!\n");
		return;
	};

	Xchat::print("${B}FILTER SAVE >$filter_file${B}\n");
	foreach my $regexp (@filter_deny) {
		Xchat::print("/".$regexp."/ saved\n");
		print $fh $regexp."\n";
	}
	Xchat::print("${B}FILTER SAVED ----------${B}\n");

	unless (close $fh) {
		Xchat::print("${B}FILTER:${B} Couldn't close file to save filter: $!\n");
		return;
	};

	return 1;
}

sub load_filter {
	my $fh;

	Xchat::print("${B}FILTER:${B} ...loading filter patterns\n");
	unless (open $fh, '<', $filter_file) {
		Xchat::print("${B}FILTER:${B} Couldn't open file to load filter: $!\n");
		return;
	};

	@filter_deny = <$fh>;
	map (chomp, @filter_deny);

	unless (close $fh) {
		Xchat::print("${B}FILTER:${B} Couldn't close file to load filter: $!\n");
		return;
	};

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
	my $num = shift || $#filter_deny;

	splice @filter_deny, $num, 1;
}

# ============================================================
# ------------------------------------------------------------
# ............................................................

sub cmd_version {
	Xchat::print("${B}$scriptName $scriptVersion${B}\n");
	Xchat::print(" * URL: http://github.com/jnareb/softsnow-xchat2-filter\n");
	Xchat::print(" * URL: http://gitorious.org/projects/softsnow-xchat2-filter\n");
	Xchat::print(" * URL: http://repo.or.cz/w/softsnow_xchat2_filter.git\n");
}

sub cmd_status {
	my $server = shift;

	if ($filter_turned_on) {
		Xchat::print("Filter is turned ${B}ON${B}\n");
	} else {
		Xchat::print("Filter is turned ${B}OFF${B}\n");
	}
	if ($limit_to_server) {
		if ($server eq $limit_to_server) {
			Xchat::print("Filter is limited to ${B}current${B} ".
			             "server $limit_to_server\n");
		} else {
			Xchat::print("Filter is limited to server ".
			             "$limit_to_server != $server\n");
		}
	}
	if ($use_filter_allow) {
		Xchat::print("Filter is using ALLOW rules (before DENY)\n");
	}
}

sub cmd_debug {
	Xchat::print("${B}FILTER DEBUG ----------${B}\n");
	Xchat::print("Channel:   ".Xchat::get_info("channel")."\n");
	Xchat::print("Host:      ".Xchat::get_info("host")."\n");
	Xchat::print("Server:    ".Xchat::get_info("server")."\n");
	Xchat::print("Server Id: ".Xchat::get_info("id")."\n");
	Xchat::print("Network:   ".Xchat::get_info("network")."\n");
	Xchat::print("\n");
	Xchat::printf("%3u %s rules\n", scalar(@filter_allow), "allow");
	Xchat::printf("%3u %s rules\n", scalar(@filter_deny),  "deny");
	Xchat::print("${B}FILTER DEBUG ----------${B}\n");
}

sub cmd_server_limit {
	my $server = shift;

	if ($server) {
		# adding limiting to given (single) server
		if ($limit_to_server) {
			Xchat::print("${B}FILTER:${B} Changing server from $limit_to_server to $server\n");
		} else {
			Xchat::print("${B}FILTER:${B} Limiting filtering to server $server\n");
		}
		$limit_to_server = $server;

	} else {
		# removing limiting to server
		if ($limit_to_server) {
			Xchat::print("Filter: Removing limit to server $limit_to_server\n");
		}
		$limit_to_server = '';

	}
}

sub cmd_print_rules {
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
}

sub cmd_add_rule {
	my $rule = shift;

	if ($rule) {
		add_rule($rule);
		Xchat::print("${B}FILTER RULE [$#filter_deny]:${B} /$rule/\n");
	} else {
		Xchat::print("Syntax: ${B}/FILTER ADD ${U}rule${U}${B} to add\n")
	}
}

sub cmd_delete_rule {
	my $num = shift;

	# strip whitespace
	$num =~ s/^\s*(.*?)\s*$/$1/g if $num;
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
		# default
		{
			Xchat::print("${B}FILTER:${B} deleting /".$filter_deny[$num]."/\n");
			delete_rule($num);
			Xchat::print("${B}FILTER:${B} deleted successfully rule $num\n");
		}
	}
}

sub cmd_show_rule {
	my $num = shift;

		$num =~ s/^\s*(.*?)\s*$/$1/g if $num;

	if (defined $num && $num !~ /^\d+$/) {
		Xchat::print("${B}FILTER:${B} $num is not a number\n");
	}	elsif (defined $num && !defined $filter_deny[$num]) {
		Xchat::print("${B}FILTER:${B} rule $num does not exist\n");
	} else {
		Xchat::print("${B}FILTER:${B} ".(defined $num ? "[$num]" : "last").
		             " rule /".$filter_deny[defined $num ? $num : -1]."/\n");
	}
}

# ============================================================
# ============================================================
# ============================================================

sub filter_command_handler {
	my $cmd = $_[0][1]; # 1st parameter (after FILTER)
	my $arg = $_[1][2]; # 2nd word to the last word
	my $server = Xchat::get_info("host");


	if (!$cmd || $cmd =~ /^STATUS$/i) {
		cmd_status($server);

	} elsif ($cmd =~ /^ON$/i) {
		$filter_turned_on = 1;
		Xchat::print("Filter turned ${B}ON${B}\n");

	} elsif ($cmd =~ /^OFF$/i) {
		$filter_turned_on = 0;
		Xchat::print("Filter turned ${B}OFF${B}\n");

	} elsif ($cmd =~ /^SERVER$/i) {
		cmd_server_limit($server);

	} elsif ($cmd =~ /^SERVERON$/i) {
		cmd_server_limit($server);

		$filter_turned_on = 1;
		Xchat::print("Filter turned ${B}ON${B}\n");

	} elsif ($cmd =~ /^ALL$/i) {
		cmd_server_limit(undef);

	} elsif ($cmd =~ /^HELP$/i) {
		Xchat::print($scriptHelp);

	} elsif ($cmd =~ /^VERSION$/i) {
		cmd_version();

	} elsif ($cmd =~ /^DEBUG$/i || $cmd =~ /^INFO$/i) {
		cmd_debug();

	} elsif ($cmd =~ /^(?:PRINT|LIST)$/i) {
		cmd_print_rules();

	} elsif ($cmd =~ /^ALLOW$/i) {
		$use_filter_allow = !$use_filter_allow;
		Xchat::print("${B}FILTER:${B} ALLOW rules ".
		             ($use_filter_allow ? "enabled" : "disabled")."\n");

	} elsif ($cmd =~ /^ADD$/i) {
		cmd_add_rule($arg);

	} elsif ($cmd =~ /^DEL(?:ETE)$/i) {
		cmd_delete_rule($arg);

	} elsif ($cmd =~ /^SHOW$/i) {
		cmd_show_rule($arg);

	} elsif ($cmd =~ /^SAVE$/i) {
		save_filter();
		Xchat::print("${B}FILTER:${B} saved DENY rules to $filter_file\n");

	} elsif ($cmd =~ /^(RE)?LOAD$/i) {
		load_filter();
		Xchat::print("${B}FILTER:${B} loaded DENY rules from $filter_file\n");

	} else {
		Xchat::print("Unknown command ${B}/FILTER $_[1][1]${B}\n") if $cmd;
	}
	return 1;
}

Xchat::print("${B}$scriptName $scriptVersion${B} loaded\n");

1;
