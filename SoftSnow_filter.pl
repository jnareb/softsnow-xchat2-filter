#!/usr/bin/perl

# SoftSnow XChat2 filter script
#
## Summary:
##
# Filter out fileserver announcements and SPAM on IRC
#
## Description:
##
# This script started as an upgrade to the SoftSnow filter script
# from http://dukelupus.pri.ee/softsnow/ircscripts/scripts.shtml
#   or http://softsnow.griffin3.com/ircscripts/scripts.shtml
# (originally http://www.softsnow.biz/softsnow_filter/filter.shtml)
# It borrows some ideas from filter-ebooks (#ebooks Xchat2 filter
# script) by KiBo, and its older version by RJVJR, mainly moving
# from the old IRC:: interface to the new Xchat2 API.
#
# Tested on #ebooks channel on IRCHighWay (irc.irchighway.net)
#
# Use '/FILTER HELP' (or '/HELP FILTER') to list all commands.
# By default filter is turned off: use '/FILTER ON' to start
# filtering contents, use '/FILTERWINDOW ON' to log filtered
# lines to '(filtered)' window.
#
#
## Install:
##
# Place SoftSnow_filter.pl in your ~/.xchat directory
#
## URL (repositories):
# * http://github.com/jnareb/softsnow-xchat2-filter
# * http://gitorious.org/projects/softsnow-xchat2-filter
# * http://repo.or.cz/w/softsnow_xchat2_filter.git
#
## ChangeLog (main points only):
##
# Version 1.2:
# * Original version of SoftSnow filter this one is based on
# Version 1.2.2:
# * Add /FILTER command, to turn filter off and on, and to limit
#   filtering to current IRC server only
# Version 1.2.3:
# * Allow to save and load filter rules from file (UNIX only)
# * Add ALLOW rules, for example to show '@search' while filtering '@'
# Version 2.0.1:
# * Use new XChat2 API (Xchat:: instead of IRC::)
# Version 2.0.5:
# * More secure saving rules to a file (always save whole file)
# Version 2.1.0:
# * Allow printing (logging) filtered content to '(filtered)' window
#   via 'Channel Message' text event, with nick of sender
# Version 2.1.3:
# * /FILTERWINDOW command to control and query of logging filtered
#   contents to separate '(filtered)' window
# Version 2.2.0:
# * /FILTER DEBUG shows now some filter statistics
#
## TODO:
##
# * Add GUI and MENU (would require XChat >= 2.4.5)
# * Change format of saved rules to 'm/.../' or 'qr{...}';
#   see YAML (YAML::Types) and Data::Dumper code and output
# * Save and read config together with filter rules
# * Autosave (and autoread) configuration, if turned on
# * Read default config and rules from __DATA__, add reset
# * Save filter rules usage statistics
# * Import filter rules from filter-ebooks3.3FINAL script
# * Limit filter to specified channels (or all channels)
# * Filter private SPAM (SPAM sent to you, but not other)
# * ? Don't accept DCC from users not on common channel 
# * ? Do not accept files, or dangerous files, from regular users
# * Color nicks in '(filtered)' window according to matched rule
# * Add command to clear '(filtered)' window
# * Add option to strip codes from logged filtered lines
# * Limit number of lines in '(filtered)' window
# * ? Perhaps something about '@find' and '!find' results?
# * Triggers, for example automatic /dccallow + resubmit,
#   if request fails (due to double '.' in filename, etc.)

use strict;
use warnings;

use File::Temp qw(tempfile);
use File::Copy qw(move);
use Text::Balanced qw(extract_quotelike);

my $scriptName    = "SoftSnow XChat2 Filter";
my $scriptVersion = "2.2.2-pre1";
my $scriptDescr   = "Filter out file server announcements and IRC SPAM";

my $B = chr  2; # bold
my $U = chr 31; # underline
my $C = chr  3; # start of color sequence
my $R = chr 22; # reverse
my $O = chr 15; # reset

### config ###
my $filter_file = Xchat::get_info("xchatdir") . "/SoftSnow_filter.conf";

my $filter_turned_on = 0;  # is filter is turned on
my $limit_to_server  = ''; # if true limit to given server (host)
my $use_filter_allow = 0;  # use overrides (ALLOW before DENY)

my $filtered_to_window = 0;
my $filter_window = "(filtered)";
### end config ###

my $filter_commands = 'ON|OFF|STATUS|SERVER|SERVERON|ALL|HELP|DEBUG|CLEARSTATS|SORT|PRINT|ALLOW|ADD|DELETE|SAVE|LOAD';

my $filter_help = <<"EOF";
${B}/FILTER $filter_commands${B}
/FILTER ON|OFF - turns filtering on/off
/FILTER HELP - prints this help message
/FILTER STATUS - prints if filter is turned on, and with what limits
/FILTER DEBUG - shows some info; used in debuggin the filter
/FILTER CLEARSTATS - reset filter statistics
/FILTER SORT - sort deny rules to have more often matched rules first
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
/FILTER WINDOW <arg>... - same as /FILTERWINDOW <arg>...
/FILTER without parameter is equivalent to /FILTER STATUS
EOF

my $filterwindow_commands = 'ON|OFF|CLOSE|HELP|STATUS|DEBUG';

my $filterwindow_help = <<"EOF";
${B}/FILTERWINDOW $filterwindow_commands${B}
/FILTERWINDOW ON|OFF - turns saving filtered content to ${U}$filter_window${U}
/FILTERWINDOW CLOSE  - close ${U}$filter_window${U} (and turn off logging)
/FILTERWINDOW STATUS - prints if saving to ${U}$filter_window${U} is turned on
/FILTERWINDOW HELP   - prints this help message
/FILTERWINDOW DEBUG  - shows some info; used in debugging this part of filter
/FILTERWINDOW without parameter is equivalent to /FILTERWINDOW STATUS
EOF

Xchat::register($scriptName, $scriptVersion, $scriptDescr);

Xchat::hook_command("FILTER", \&filter_command_handler,
                    { help_text => $filter_help });
Xchat::hook_command("FILTERWINDOW", \&filterwindow_command_handler,
                    { help_text => $filterwindow_help });
Xchat::hook_server("PRIVMSG", \&privmsg_handler);

Xchat::print("Loading ${B}$scriptName $scriptVersion${B}...\n");


# GUI, windows, etc.
if ($filtered_to_window) {
	Xchat::command("QUERY $filter_window");
}

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
# Subroutines translating between regexps and stringifications
# qr/<sth>/i <-> q/(?i)<sth>/ <-> '(?i-xsm:<sth>)'
# see YAML::Types and Data::Dumper code and output

use constant _QR_TYPES => {
	'' => sub { qr{$_[0]} },
	x  => sub { qr{$_[0]}x },
	i  => sub { qr{$_[0]}i },
	ix => sub { qr{$_[0]}ix },
};

# converts '(?i-xsm:re)' or '(?i)re' to qr{re}i, etc.
# modified code based on 'regexp' from YAML/Types.pm
sub stringify_to_re {
	my $text = shift;

	return qr{$text} unless $text =~
		/(?:
			# clustering, with flag modifiers
			# e.g. (?i-xsm:^abra . kadabra)
			^\(\?([\-xism]*):(.*)\)\z
			|
			# pattern-match modifier
			# e.g. (?i)^abra . kadabra
			^\(\?([xi]+)\)(.*)\z
		)/sx;
	my ($flags, $re) = ($1 || $3, defined $2 ? $2 : $4);
	$flags =~ s/-.*//;
	$flags = 'ix' if $flags eq 'xi';

	my $sub = _QR_TYPES->{$flags} || sub { qr{$_[0]} };
	my $qr = &$sub($re);

	return $qr;
}

# converts 'qr/re/i' or 'm/re/i' to qr{re}i, etc.
sub str_repr_to_re {
	my $str = shift;
	my ($op,$re,$flags) = (extract_quotelike($str))[3,5,10];
	return qr{$str} unless (defined $op && $op =~ /^(?:qr|m)$/ && $re);

	my $sub = _QR_TYPES->{$flags} || sub { qr{$_[0]} };
	my $qr = &$sub($re);

	return $qr;
}

# . . . . . . . . . . . . . . . . . . . . . . . . . . . .

# return regexp string in the 'qr/<regexp>/<flags>' form
sub re_to_str_repr {
	my $regexp = shift;
	return $regexp unless (ref($regexp) eq 'Regexp');

	my $out = "$regexp";     # stringification
	$out =~ s,([\/]),\\$1,g; # quote delimiters and quoting char
	return "qr/$out/" unless $out =~ /^\(\?([\-xism]*):(.*)\)\z/s;
	my ($flags, $re) = ($1, $2);
	$flags =~ s/-.*//;
	return "qr/$re/$flags";
}

# return regexp string in the old '(?<flags>)<regexp>' form
sub re_to_stringify_mod {
	my $regexp = shift;
	return $regexp unless (ref($regexp) eq 'Regexp');

	my $out = "$regexp";     # stringification
	#$out =~ s,[\],\\,g;     # quote quoting char
	return $out unless $out =~ /^\(\?([\-xism]*):(.*)\)\z/s;
	my ($flags, $re) = ($1, $2);
	$flags =~ s/-.*//;
	return $flags ? "(?$flags)$re" : $re;
}

# return regexp string in canonical '(?i-xsm:<regexp>)' form
sub re_to_stringify {
	return "$_[0]";
}

# . . . . . . . . . . . . . . . . . . . . . . . . . . . .

# converts '(?i-xsm:re)' (stringification) to 'qr/re/i'
sub re_string_to_str_repr {
	my $text = shift;

	return $text unless $text =~ /^\(\?([\-xism]*):(.*)\)\z/sx;
	my ($flags, $re) = ($1, $2);
	$flags =~ s/-.*//;

	return "qr/$re/$flags";
}

# ------------------------------------------------------------

my @filter_allow = (
	qr/^\@search\s/,
);

my @filter_deny = (
	qr/\@/,
	qr/^\s*\!/,
	qr/slot\(s\)/,
	#qr/~&~&~/,

	#xdcc
	qr/^\#\d+/,

	#fserves
	qr/fserve.*trigger/i,
	qr/trigger.*\!/i,
	qr/trigger.*\/ctcp/i,
	qr/type\:\s*\!/i,
	qr/file server online/i,

	#ftps
	qr/ftp.*l\/p/i,

	#CTCPs
	qr/SLOTS/,
	qr/MP3 /,

	#messages for when a file is received/failed to receive
	qr/DEFINITELY had the right stuff to get/i,
	qr/has just received/i,
	qr/I have just received/i,

	#mp3 play messages
	qr/is listening to/,
	qr/\]\-MP3INFO\-\[/,

	#spammy scripts
	qr/\]\-SpR\-\[/,
	qr/We are BORG/,

	#general messages
	qr/brave soldier in the war/,
);

my $nlines      = 0; # how many lines we passed through filter
my $nfiltered   = 0; # how many lines were filtered
my $checklensum = 0; # how many rules to check to catch filtered
my $nallow      = 0; # how many lines matched ALLOW rule
my %stats = (); # histogram: how many times given rule was used

# return 1 (true) if text given as argument is to be filtered out
sub isFiltered {
	my $text = shift;
	my $regexp = '';

	#strip colour, underline, bold codes, etc.
	$text = Xchat::strip_code($text);

	# count all filtered lines;
	$nlines++;

	if ($use_filter_allow) {
		foreach $regexp (@filter_allow) {
			if ($text =~ $regexp) {
				$nallow++;
				return 0;
			}
		}
	}

	my $nrules_checked = 0;
	foreach $regexp (@filter_deny) {
		$nrules_checked++;

		if ($text =~ $regexp) {
			# filter statistic
			$nfiltered++;
			$checklensum += $nrules_checked;
			if (exists $stats{$regexp}) {
				$stats{$regexp}++;
			} else {
				$stats{$regexp} = 1;
			}

			return 1;
		}
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
	my ($address, $msgtype, $channel) = @{$_[0]};
	my ($nick, $user, $host) = ($address =~ /^:([^!]*)!([^@]+)@(.*)$/);

	my $text = $_[1][3]; # Get server message

	my $server = Xchat::get_info("host");

	#-- EXAMPLE RAW COMMANDS: --
	#chanmsg: [':epitaph!~epitaph@CPE00a0241892b7-CM014480119187.cpe.net.cable.rogers.com', 'PRIVMSG', '#werd', ':mah', 'script', 'is', 'doing', 'stuff.']
	#action:  [':rlz!railz@bzq-199-176.red.bezeqint.net', 'PRIVMSG', '#werd', ':\x01ACTION', 'hugs', 'elhaym', '\x01']
	#private: [':olene!oqd@girli.sh', 'PRIVMSG', 'epinoodle', ':hey']


	return Xchat::EAT_NONE unless $filter_turned_on;
	if ($limit_to_server) {
		return Xchat::EAT_NONE unless $server eq $limit_to_server;
	}
	# do not filter out private messages
	return Xchat::EAT_NONE unless ($channel =~ /^#/);

	$text =~ s/^://;

	if (isFiltered($text)) {
		if (defined $nick && $filtered_to_window) {
			#Xchat::print($text, $filter_window)

			my $ctx = Xchat::get_context();
			Xchat::set_context($filter_window);
			Xchat::emit_print('Channel Message', $nick, $text);
			Xchat::set_context($ctx);
		}
		#return Xchat::EAT_XCHAT;
		return Xchat::EAT_ALL;
	}
	return Xchat::EAT_NONE;
}


# ------------------------------------------------------------

sub save_filter {
	my ($fh, $tmpfile) = tempfile($filter_file.'.XXXXXX', UNLINK=>1);

	unless ($fh) {
		Xchat::print("${B}FILTER:${B} ".
		             "Couldn't open temporary file $tmpfile to save filter: $!\n");
		return;
	};

	Xchat::print("${B}FILTER SAVE >$filter_file${B}\n");
	foreach my $regexp (@filter_deny) {
		my $str = re_to_stringify_mod($regexp);
		Xchat::print(re_to_str_repr($regexp)." saved as $str\n");
		print $fh "$str\n";
	}

	unless (close $fh) {
		Xchat::print("${B}FILTER:${B} Couldn't close file to save filter: $!\n");
		return;
	};
	#move($tmpfile, $filter_file);
	rename($tmpfile, $filter_file);
	Xchat::print("${B}FILTER SAVED ----------${B}\n");

	return 1;
}

sub load_filter {
	my $fh;

	Xchat::print("${B}FILTER:${B} ...loading filter patterns\n");
	unless (open $fh, '<', $filter_file) {
		Xchat::print("${B}FILTER:${B} Couldn't open file to load filter: $!\n");
		return;
	};

	@filter_deny = map { chomp($_); stringify_to_re($_); } <$fh>;

	unless (close $fh) {
		Xchat::print("${B}FILTER:${B} Couldn't close file to load filter: $!\n");
		return;
	};

	Xchat::print("${B}FILTER DENY START ----------${B}\n");
	for (my $i = 0; $i <= $#filter_deny; $i++) {
		Xchat::print(" [$i]: ".re_to_str_repr($filter_deny[$i])."\n");
	}
	Xchat::print("${B}FILTER DENY END ------------${B}\n");
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

sub slquote {
	my $text = shift;

	$text =~ s!([\/])!\$1!g;

	return $text;
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
	Xchat::print("${B}FILTER DEBUG START ----------${B}\n");
	Xchat::print("Channel:   ".Xchat::get_info("channel")."\n");
	Xchat::print("Host:      ".Xchat::get_info("host")."\n");
	Xchat::print("Server:    ".Xchat::get_info("server")."\n");
	Xchat::print("Server Id: ".Xchat::get_info("id")."\n");
	Xchat::print("Network:   ".Xchat::get_info("network")."\n");

	Xchat::print("\n");
	Xchat::printf("%3u %s rules\n", scalar(@filter_allow), "allow");
	Xchat::printf("%3u %s rules\n", scalar(@filter_deny),  "deny");

	my %deny_idx = ();
	# %deny_idx = map { $filter_deny[$_] => $_ } 0..$#filter_deny;
	@deny_idx{ @filter_deny } = (0..$#filter_deny);
	Xchat::print("\n");
	Xchat::print("filtered lines   = $nfiltered out of $nlines\n");
	if ($nlines > 0) {
		Xchat::printf("filtered ratio   = %f (%5.1f%%)\n",
		              $nfiltered/$nlines, 100.0*$nfiltered/$nlines);
	}
	if ($nfiltered > 0) {
		Xchat::print("average to match = ".$checklensum/$nfiltered."\n");
		foreach my $rule (sort { $stats{$b} <=> $stats{$a} } keys %stats) {
			Xchat::printf("%5u: %5.1f%% [%2u] %s\n",
			              $stats{$rule}, 100.0*$stats{$rule}/$nfiltered,
			              $deny_idx{$rule}, re_string_to_str_repr($rule));
		}
	}
	if ($use_filter_allow || $nallow > 0) {
		Xchat::print("allow matches    = $nallow\n");
	}
	Xchat::print("${B}FILTER DEBUG END ------------${B}\n");
}

sub cmd_clear_stats {
	$nlines      = 0;
	$nfiltered   = 0;
	$checklensum = 0;
	$nallow      = 0;
	%stats = ();

	Xchat::print("${B}FILTER:${B} stats cleared\n");
}

sub cmd_sort_by_stats {
	use sort 'stable';

	@filter_deny =
		sort { ($stats{$b} || 0) <=> ($stats{$a} || 0) }
		@filter_deny;

	Xchat::print("${B}FILTER:${B} DENY rules sorted by their use descending\n");
}

sub cmd_server_limit {
	my $server = shift;

	if ($server) {
		# adding limiting to given (single) server
		if ($limit_to_server) {
			Xchat::print("${B}FILTER:${B} Changing server from $limit_to_server to $server\n");
			Xchat::print("[FILTER LIMITED TO SERVER ${B}$server${B} (WAS TO $limit_to_server)]",
			             $filter_window);
		} else {
			Xchat::print("${B}FILTER:${B} Limiting filtering to server $server\n");
			Xchat::print("[FILTER LIMITED TO SERVER ${B}$server${B} (WAS UNLIMITED)]",
			             $filter_window);
		}
		$limit_to_server = $server;

	} else {
		# removing limiting to server
		if ($limit_to_server) {
			Xchat::print("${B}FILTER:${B} Removing limit to server $limit_to_server\n");
			Xchat::print("[FILTER ${B}NOT LIMITED${B} TO SERVER (WAS TO $limit_to_server)]",
			             $filter_window);
		}
		$limit_to_server = '';

	}
}

sub cmd_print_rules {
	Xchat::print("${B}FILTER PRINT START ----------${B}\n");
	Xchat::print("${B}ALLOW${B}".($use_filter_allow ? ' (on)' : ' (off)')."\n");

	for (my $i = 0; $i <= $#filter_allow; $i++) {
		Xchat::printf("[$2i]: %s\n", $i, re_to_str_repr($filter_allow[$i]));
	}
	Xchat::print("${B}DENY${B}\n");
	for (my $i = 0; $i <= $#filter_deny; $i++) {
		Xchat::printf("[$2i]: %s\n", $i, re_to_str_repr($filter_deny[$i]));
	}
	Xchat::print("${B}FILTER PRINT END ------------${B}\n");
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
			Xchat::print("${B}FILTER:${B} deleting ".
			             re_to_str_repr($filter_deny[-1])."/\n");
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
			Xchat::print("${B}FILTER:${B} deleting ".
			             re_to_str_repr($filter_deny[$num])."\n");
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
		             " rule ".re_to_str_repr($filter_deny[defined $num ? $num : -1])."\n");
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
		Xchat::print("[FILTER TURNED ${B}ON${B}]",
		             $filter_window);

	} elsif ($cmd =~ /^OFF$/i) {
		$filter_turned_on = 0;
		Xchat::print("Filter turned ${B}OFF${B}\n");
		Xchat::print("[FILTER TURNED ${B}OFF${B}]",
		             $filter_window);

	} elsif ($cmd =~ /^SERVER$/i) {
		cmd_server_limit($server);

	} elsif ($cmd =~ /^SERVERON$/i) {
		cmd_server_limit($server);

		Xchat::print("[FILTER TURNED ${B}ON${B}]",
		             $filter_window)
			if (!$filter_turned_on);
		$filter_turned_on = 1;
		Xchat::print("Filter turned ${B}ON${B}\n");

	} elsif ($cmd =~ /^ALL$/i) {
		cmd_server_limit(undef);

	} elsif ($cmd =~ /^HELP$/i) {
		Xchat::print($filter_help);
		Xchat::print($filterwindow_help);

	} elsif ($cmd =~ /^VERSION$/i) {
		cmd_version();

	} elsif ($cmd =~ /^DEBUG$/i || $cmd =~ /^INFO$/i) {
		cmd_debug();

	} elsif ($cmd =~ /^CLEARSTAT(?:S)?$/i) {
		cmd_clear_stats();

	} elsif ($cmd =~ /^SORT$/i) {
		cmd_sort_by_stats();

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

	} elsif ($cmd =~ /^WINDOW$/i) {
		return filterwindow_command_handler(
			[ 'FILTERWINDOW',          @{$_[0]}[2..$#{$_[0]}] ],
			[ "FILTERWINDOW $_[1][2]", @{$_[1]}[2..$#{$_[1]}] ],
			$_[2]
		);

	} else {
		Xchat::print("Unknown command ${B}/FILTER $_[1][1]${B}\n") if $cmd;
	}
	return 1;
}

sub filterwindow_command_handler {
	my $cmd = $_[0][1]; # 1st parameter (after FILTER)
	#my $arg = $_[1][2]; # 2nd word to the last word
	my $ctx = Xchat::find_context($filter_window);

	if (!$cmd || $cmd =~ /^STATUS$/i) {
		Xchat::print(($filtered_to_window ? "Show" : "Don't show").
		             " filtered content in ".
		             (defined $ctx ? "open" : "closed").
		             " window ${B}$filter_window${B}\n");

	} elsif ($cmd =~ /^DEBUG$/i) {
		my $ctx_info = Xchat::context_info($ctx);
		Xchat::print("${B}FILTERWINDOW DEBUG START ----------${B}\n");
		Xchat::print("filtered_to_window = $filtered_to_window\n");
		Xchat::print("filter_window      = $filter_window\n");
		if (defined $ctx) {
			Xchat::print("$filter_window is ${B}open${B}\n");
			Xchat::print("$filter_window: network   => $ctx_info->{network}\n")
				if defined $ctx_info->{'network'};
			Xchat::print("$filter_window: host      => $ctx_info->{host}\n")
				if defined $ctx_info->{'host'};
			Xchat::print("$filter_window: channel   => $ctx_info->{channel}\n");
			Xchat::print("$filter_window: server_id => $ctx_info->{id}\n")
				if defined $ctx_info->{'id'};
		} else {
			Xchat::print("$filter_window is ${B}closed${B}\n");
		}
		# requires XChat >= 2.8.2
		#Xchat::print("'Channel Message' format:     ".
		#             Xchat::get_info("event_text Channel Message")."\n");
		#Xchat::print("'Channel Msg Hilight' format: ".
		#             Xchat::get_info("event_text Channel Msg Hilight")."\n");
		Xchat::print("${B}FILTERWINDOW DEBUG END ------------${B}\n");

	} elsif ($cmd =~ /^ON$/i) {
		Xchat::command("QUERY $filter_window");
		Xchat::print("${B}----- START LOGGING FILTERED CONTENTS -----${B}\n",
		             $filter_window)
			if !$filtered_to_window;

		$filtered_to_window = 1;
		Xchat::print("Filter shows filtered content in ${B}$filter_window${B}\n");

	} elsif ($cmd =~ /^(?:OFF|CLOSE)$/i) {
		Xchat::print("${B}----- STOP LOGGING FILTERED CONTENTS ------${B}\n",
		             $filter_window)
			if $filtered_to_window;
		Xchat::command("CLOSE", $filter_window)
			if ($cmd =~ /^CLOSE$/i);

		$filtered_to_window = 0;
		Xchat::print("Filter doesn't show filtered content in ${B}$filter_window${B}\n");
		Xchat::print("${B}FILTER:${B} ${B}$filter_window${B} closed\n")
			if ($cmd =~ /^CLOSE$/i);

	} elsif ($cmd =~ /^HELP$/i) {
		Xchat::print($filterwindow_help);

	} else {
		Xchat::print("Unknown command ${B}/FILTERWINDOW $_[1][1]${B}\n") if $cmd;
		Xchat::print("${B}${U}USAGE:${U} /FILTERWINDOW $filterwindow_commands${B}\n");
	}

	return 1;
}

# ======================================================================
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# ----------------------------------------------------------------------

Xchat::print("${B}$scriptName $scriptVersion${B} loaded\n",
             " For help: ${B}/FILTER HELP${B}\n");

1;
