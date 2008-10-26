#!/usr/bin/perl -w

use strict;

### config ### 
my $filter_file = "$ENV{'HOME'}/.xchat/SoftSnow_filter.conf";
### end config ###

my $scriptName    = "SoftSnow XChat Filter";
my $scriptVersion = "1.2.6";

IRC::register($scriptName, $scriptVersion, "", "");

#IRC::add_command_handler("amsg", "amsg_command_handler");
IRC::add_command_handler("filter",  "filter_command_handler");
IRC::add_message_handler("PRIVMSG", "privmsg_handler");

my $B = chr 2;  # bold
my $U = chr 31; # underline
my $C = chr 3;  # color

my $command_list = 'ON|OFF|STATUS|SERVER|SERVERON|ALL|HELP|DEBUG|PRINT|ALLOW|ADD|DELETE|SAVE|LOAD';

IRC::print("Loading ${B}$scriptName $scriptVersion${B}\n".
	   " For help: ${B}/FILTER HELP${B}\n");

my $filter_turned_on = 0; # was default turned ON
my $limit_to_server  = 0; # don't limit to server (host)
my $use_filter_allow = 0; # use overrides

# information about (default) options used
if ($filter_turned_on) {
  IRC::print("Filter turned ${B}ON${B}\n");
} else {
  IRC::print("Filter turned ${B}OFF${B}\n");
}
if ($limit_to_server) {
  IRC::print("Filter limited to server $limit_to_server\n")
}
if ($use_filter_allow) {
  IRC::print("Filter uses ALLOW rules\n")
}

# ------------------------------------------------------------

my @filter_allow =
  (
   q/^\@search\s/
  );

my @filter_deny =
  (
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
   q/brave soldier in the war/
  );

sub isFiltered {
  my $text = $_[0];
  my $regexp = '';

  #strip colour, underline, bold codes
  $text =~ s/${B}//go; # code bold
  $text =~ s/${U}//go; # code under
  $text =~ s/${C}\d+(,\d+)?//go; # code colour

  #debug
  #for (my $i=0; $i < length $text; $i++){
  #  IRC::print("$i=[" . ord(substr($text,$i,1)) . "]=" . substr($text,$i,1) . "\n");
  #}

#  if (/MP3/){
#    IRC::print("isFiltered : text=". $text. "\n");
#  }

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
#return 0 to allow the text to be printed, 1 to filter it
sub privmsg_handler {
  $_[0] =~ s/\s{2,}/ /g;
  #if ($_[0] =~ /MP3/){
  #  IRC::print("MP3 LINE is $_[0]\n");
  #}
  my @params = split / /, $_[0];

  my $server = IRC::get_info(7); # host to be more exact; better for autoreconnect

  my $address = shift @params;
  my $constant = shift @params;
  my $chan= shift @params;

  #IRC::print("privmsg_handler: params=", @params, ":::\n");
  my $text = join ' ', @params;


  return 0 unless $filter_turned_on;
  if ($limit_to_server) {
    return 0 unless $server eq $limit_to_server;
  }

  $text =~ s/^://;

  #IRC::print("privmsg_handler: address=$address\n");
  #IRC::print("privmsg_handler: chan=$chan\n");
  #IRC::print("privmsg_handler: constant=$constant\n");
  #IRC::print("privmsg_handler: text=$text\n");

  return isFiltered($text);
}

# ------------------------------------------------------------

sub save_filter {
  open F, ">$filter_file"
    or do {
      IRC::print("${B}FILTER:${B} Couldn't open file to save filter: $!\n");
      return 1;
    };
  #print F "# $alias_file - config for alias.pl\n";
  IRC::print("${B}FILTER SAVE >$filter_file${B}\n");
  foreach my $regexp (@filter_deny) {
    IRC::print("/".$regexp."/ saved\n");
    print F $regexp."\n";
  }
  IRC::print("${B}FILTER SAVED ----------${B}\n");
  close F 
    or do {
      IRC::print("${B}FILTER:${B} Couldn't close file to save filter: $!\n");
      return 1;
    };
  return 1;
}

sub load_filter {
  IRC::print("${B}FILTER:${B} ...loading filter patterns\n");
  open F, "<$filter_file"
    or do {
      IRC::print("${B}FILTER:${B} Couldn't open file to load filter: $!\n");
      return 1;
    };
  @filter_deny = <F>;
  map (chomp, @filter_deny);
  close F;

  IRC::print("${B}FILTER DENY ----------${B}\n");
  for (my $i = 0; $i <= $#filter_deny; $i++) {
    IRC::print(" [$i]: /".$filter_deny[$i]."/\n");
  }
  IRC::print("${B}FILTER DENY ----------${B}\n");
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
  my ($arg) = $_[0];
  my $server = IRC::get_info(7);

  #IRC::print("/filter arg: |$arg|\n");
  if ($arg =~ /^ON\b/i) {
    $filter_turned_on = 1;
    IRC::print("Filter turned ON\n");

  } elsif ($arg =~ /^OFF\b/i) {
    $filter_turned_on = 0;
    IRC::print("Filter turned OFF\n");

  } elsif ($arg =~ /^STATUS\b/i || !$arg) {
    if ($filter_turned_on) {
      IRC::print("Filter is turned ${B}ON${B}\n");
    } else {
      IRC::print("Filter is turned ${B}OFF${B}\n");
    }
    if ($limit_to_server) {
      IRC::print("Filter is limited to ".
		 ($server eq $limit_to_server ? "${B}current${B} " : "" ).
		 "server $limit_to_server");
    }
    if ($use_filter_allow) {
      IRC::print("Filter is using ALLOW rules (before DENY)\n");
    }

  } elsif ($arg =~ /^SERVER\b/i) {
    if ($limit_to_server) {
      IRC::print("${B}FILTER:${B} Changing server from $limit_to_server to $server\n");
    } else {
      IRC::print("${B}FILTER:${B} Limiting filtering to server $server\n");
    }
    $limit_to_server = $server;

  } elsif ($arg =~ /^SERVERON\b/i) {
    if ($limit_to_server) {
      IRC::print("${B}FILTER:${B} Changing server from $limit_to_server to $server\n");
    } else {
      IRC::print("${B}FILTER:${B} Limiting filtering to server $server\n");
    }
    $limit_to_server = $server;

    $filter_turned_on = 1;
    IRC::print("Filter turned ${B}ON${B}\n");
  } elsif ($arg =~ /^ALL\b/i) {
    if ($limit_to_server) {
      IRC::print("Filter: Removing limit to server $limit_to_server\n");
    }
    $limit_to_server = 0;

  } elsif ($arg =~ /^HELP\b/i) {
    IRC::print("${B}/FILTER $command_list${B}\n".
	       "/FILTER ON|OFF - turns filtering on/off\n".
	       "/FILTER HELP - prints this help message\n".
	       "/FILTER STATUS - prints if filter is turned on, and with what limits\n".
	       "/FILTER DEBUG - shows some info; used in debuggin the filter\n".
	       "/FILTER PRINT - prints all the rules\n".
	       "/FILTER ALLOW - toggle use of ALLOW rules (before DENY)\n".
	       "/FILTER SERVER - limits filtering to current server (host))\n".
	       "/FILTER SERVERON - limits to server and turns filter on\n".
	       "/FILTER ALL - resumes filtering everywhere i.e. removes limits\n".
	       "/FILTER SAVE - saves the rules to the file $filter_file\n".
	       "/FILTER LOAD - loads the rules from the file, replacing existing rules\n".
	       "/FILTER ADD <rule> - add rule at the end of the DENY rules\n".
	       "/FILTER DELETE [<num>] - delete rule number <num>, or last rule\n".
	       "/FILTER VERSION - prints the name and version of this script\n".
	       "/FILTER without parameter is equivalent to /FILTER STATUS\n");

  } elsif ($arg =~ /^VERSION\b/i) {
    IRC::print("${B}$scriptName $scriptVersion${B}\n");

  } elsif ($arg =~ /^DEBUG\b/i || $arg =~ /^INFO\b/i) {
    IRC::print("${B}FILTER DEBUG ----------${B}\n");
    IRC::print("Channel: ".IRC::get_info(2)."\n");
    IRC::print("Server:  ".IRC::get_info(3)."\n");
    IRC::print("Network: ".IRC::get_info(6)."\n");
    IRC::print("Host:    ".IRC::get_info(7)."\n");
    IRC::print("${B}FILTER DEBUG ----------${B}\n");

  } elsif ($arg =~ /^PRINT/i) {
    IRC::print("${B}FILTER PRINT ----------${B}\n");
    IRC::print("${B}ALLOW${B}".($use_filter_allow ? ' (on)' : ' (off)')."\n");
    for (my $i = 0; $i <= $#filter_allow; $i++) {
      IRC::print("[$i]: /".$filter_allow[$i]."/\n");
    }
    IRC::print("${B}DENY${B}\n");
    for (my $i = 0; $i <= $#filter_deny; $i++) {
      IRC::print("[$i]: /".$filter_deny[$i]."/\n");
    }
    IRC::print("${B}FILTER PRINT ----------${B}\n");

  } elsif ($arg =~ /^ALLOW/i) {
    $use_filter_allow = !$use_filter_allow;
    IRC::print("${B}FILTER:${B} ALLOW rules ".
	       ($use_filter_allow ? "enabled" : "disabled")."\n");

  } elsif ($arg =~ /^ADD\s+(.*)/i) {
    if ($1) {
      add_rule($1);
      IRC::print("${B}FILTER RULE [$#filter_deny]:${B} /$1/\n");
    } else {
      IRC::print("Syntax: ${B}/FILTER ADD ${U}rule${U}${B} to add\n")
    }

  } elsif ($arg =~ /^DELETE(.*)/i) {
    my $num = $1;
    $num =~ s/^\s*(.*?)\s*$/\1/g;
  SWITCH: {
      unless ($num) {
	IRC::print("${B}FILTER:${B} deleting /".$filter_deny[-1]."/\n");
	$#filter_deny--;
	IRC::print("${B}FILTER:${B} deleted successfully last rule\n");
	last SWITCH;
      }
      if ($num !~ /^\d+$/) { 
	IRC::print("${B}FILTER:${B} $num is not a number\n");
	last SWITCH;
      }
      if ($num < 0 || $num > $#filter_deny) {
	IRC::print("${B}FILTER:${B} $num outside range [0,$#filter_deny]\n");
	last SWITCH;
      }
      IRC::print("${B}FILTER:${B} deleting /".$filter_deny[$num]."/\n");
      delete_rule($num);
      IRC::print("${B}FILTER:${B} deleted successfully rule $num\n");
    }

  } elsif ($arg =~ /^SAVE/i) {
    save_filter();
    IRC::print("${B}FILTER:${B} saved DENY rules to $filter_file\n");

  } elsif ($arg =~ /^(RE)?LOAD/i) {
    load_filter();
    IRC::print("${B}FILTER:${B} loaded DENY rules from $filter_file\n");

  } else {
    IRC::print("/filter arg: |$arg|\n") if $arg;
#     if ($filter_turned_on) {
#       $filter_turned_on = 0;
#       IRC::print("Filter turned OFF\n");
#     } else {
#       $filter_turned_on = 1;
#       IRC::print("Filter turned ON\n");
#     }
  }
  return 1;
}

1;
