#!perl -w

use strict;

my $scriptName = "SoftSnow XChat Filter";

IRC::register($scriptName, "1.2", "", "");

#IRC::add_command_handler("amsg", "amsg_command_handler");
IRC::add_message_handler("PRIVMSG", "privmsg_handler");

IRC::print("Loading $scriptName\n");

my $code_bold   = chr 2;
my $code_under  = chr 31;
my $code_colour = chr 3;

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

  #adverts, requests
  return 1 if ($text =~ /\@/ || $text =~ /^\s*\!/);
  return 1 if ($text =~ /slot\(s\)/);

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

  my $address = shift @params;
  my $constant = shift @params;
  my $chan= shift @params;

  #IRC::print("privmsg_handler: params=", @params, ":::\n");
  my $text = join ' ', @params;

  $text =~ s/^://;

  #IRC::print("privmsg_handler: address=$address\n");
  #IRC::print("privmsg_handler: chan=$chan\n");
  #IRC::print("privmsg_handler: constant=$constant\n");
  #IRC::print("privmsg_handler: text=$text\n");

  return (isFiltered($text));
}

1;
