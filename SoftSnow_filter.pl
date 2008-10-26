#!/usr/bin/perl -w

use strict;

my $scriptName    = "SoftSnow XChat Filter";
my $scriptVersion = "1.2.2";

IRC::register($scriptName, $scriptVersion, "", "");

#IRC::add_command_handler("amsg", "amsg_command_handler");
IRC::add_command_handler("filter",  "filter_command_handler");
IRC::add_message_handler("PRIVMSG", "privmsg_handler");

my $code_bold   = chr 2;
my $code_under  = chr 31;
my $code_colour = chr 3;

my $command_list = 'ON|OFF|STATUS|HELP|SERVER|ALL';

IRC::print("Loading $code_bold$scriptName $scriptVersion$code_bold\n"
	  ." Commands: ${code_bold}/FILTER ${command_list}${code_bold}\n");

my $filter_turned_on = 0; # was default turned ON
my $limit_to_server  = 0; # don't limit to server

if ($filter_turned_on) {
  IRC::print("Filter turned ${code_bold}ON${code_bold}\n");
} else {
  IRC::print("Filter turned ${code_bold}OFF${code_bold}\n");
}
if ($limit_to_server) {
  IRC::print("Filtering limited to server $limit_to_server\n")
}

my @filter = 
  (
   /\@/, 
   /^\s*\!/, 
   /slot\(s\)/, 
   /~&~&~/,
  
  #xdcc
  /^\#\d+/, 
  
  #fserves
  /fserve.*trigger/i, 
  /trigger.*\!/i, 
  /trigger.*\/ctcp/i, 
  /type\:\s*\!/i, 
  /file server online/i, 
  
  #ftps
  /ftp.*l\/p/i, 
  
  #CTCPs
  /SLOTS/, 
  /MP3 /, 
  
  #messages for when a file is received/failed to receive
  /DEFINITELY had the right stuff to get/i, 
  /has just received/i, 
  /I have just received/i, 
  
  #mp3 play messages
  /is listening to/, 
  /\]\-MP3INFO\-\[/, 
  
  #spammy scripts
  /\]\-SpR\-\[/, 
  /We are BORG/, 
  
  #general messages
  /brave soldier in the war/
);

sub isFiltered {
  my $text = $_[0];

  #strip colour, bold codes
  $text =~ s/$code_bold//go;
  $text =~ s/$code_under//go;
  $text =~ s/$code_colour\d+(,\d+)?//go;

  #debug
  #for (my $i=0; $i < length $text; $i++){
  #  IRC::print("$i=[" . ord(substr($text,$i,1)) . "]=" . substr($text,$i,1) . "\n");
  #}

#  if (/MP3/){
#    IRC::print("isFiltered : text=". $text. "\n");
#  }

  foreach ($regexp in @filter) {
    return 1 if ($text =~ $regexp);
  }

  #adverts, requests
  return 1 if ($text =~ /\@/ || $text =~ /^\s*\!/);
  return 1 if ($text =~ /slot\(s\)/);
  return 1 if ($text =~ /~&~&~/);

  #xdcc
  return 1 if ($text =~ /^\#\d+/);

  #fserves
  return 1 if ($text =~ /fserve.*trigger/i);
  return 1 if ($text =~ /trigger.*\!/i);
  return 1 if ($text =~ /trigger.*\/ctcp/i);
  return 1 if ($text =~ /type\:\s*\!/i);
  return 1 if ($text =~ /file server online/i);

  #ftps
  return 1 if ($text =~ /ftp.*l\/p/i);

  #CTCPs
  return 1 if ($text =~ /SLOTS/);
  return 1 if ($text =~ /MP3 /);


  #messages for when a file is received/failed to receive
  return 1 if ($text =~ /DEFINITELY had the right stuff to get/i);
  return 1 if ($text =~ /has just received/i);
  return 1 if ($text =~ /I have just received/i);

  #mp3 play messages
  return 1 if ($text =~ /is listening to/);
  return 1 if ($text =~ /\]\-MP3INFO\-\[/);

  #spammy scripts
  return 1 if ($text =~ /\]\-SpR\-\[/);
  return 1 if ($text =~ /We are BORG/);

  #general messages
  return 1 if ($text =~ /brave soldier in the war/);


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

  my $server = IRC::get_info(3);

  my $address = shift @params;
  my $constant = shift @params;
  my $chan= shift @params;

  #IRC::print("privmsg_handler: params=", @params, ":::\n");
  my $text = join ' ', @params;


  return 0 unless $filter_turned_on;
  if ($limit_to_server) {
    return 0 unless $server == $limit_to_server;
  }

  $text =~ s/^://;

  #IRC::print("privmsg_handler: address=$address\n");
  #IRC::print("privmsg_handler: chan=$chan\n");
  #IRC::print("privmsg_handler: constant=$constant\n");
  #IRC::print("privmsg_handler: text=$text\n");

  return isFiltered($text);
}

sub filter_command_handler ( $ ) {
  my ($arg) = $_[0];
  my $server = IRC::get_info(3);

  #IRC::print("/filter arg: |$arg|\n");
  if ($arg =~ /^ON\b/i) {
    $filter_turned_on = 1;
    IRC::print("Filter turned ON\n");

  } elsif ($arg =~ /^OFF\b/i) {
    $filter_turned_on = 0;
    IRC::print("Filter turned OFF\n");

  } elsif ($arg =~ /^STATUS\b/i) {
    if ($filter_turned_on) {
      IRC::print("Filter is turned ON\n");
    } else {
      IRC::print("Filter is turned OFF\n");
    }
    if ($limit_to_server) {
      IRC::print("Filtering limited to server $server\n");
    }

  } elsif ($arg =~ /^SERVER\b/i) {
    if ($limit_to_server) {
      IRC::print("Filter: Changing server from $limit_to_server to $server\n");
    } else {
      IRC::print("Filter: Limiting filtering to server $server\n");
    }
    $limit_to_server = $server;

  } elsif ($arg =~ /^ALL\b/i) {
    if ($limit_to_server) {
      IRC::print("Filter: Removing limit to server $limit_to_server\n");
    }
    $limit_to_server = 0;

  } elsif ($arg =~ /^HELP\b/i) {
    IRC::print("/FILTER $command_list\n".
	       "/FILTER SERVER - limits filtering to current server\n".
	       "/FILTER ALL - resumes filtering everywhere\n".
	       "/FILTER without parameter toggles filter\n");
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
