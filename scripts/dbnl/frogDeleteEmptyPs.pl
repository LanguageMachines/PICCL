#!/usr/bin/perl -w
# frogDeleteEmptyPs: remove paragraph tags without text (cause problems for frog)
# usage: frogDeleteEmptyPs file
# 20160614 erikt(at)xs4all.nl

use XML::Twig;
use strict;

# get the file name
my $command = $0;
my $prefix = "X";

# get the file name
if (not defined $ARGV[0] or $ARGV[0] eq "") {
   die "usage: $command file\n";
}
my $file = shift(@ARGV);

# define xml actions: 1 process tags with process; 2 print format
my $twig = new XML::Twig( 
   twig_handlers => { _default_ => \&process },
   pretty_print => 'indented',
   keep_encoding => 1 ,
   expand_external_ents => -1
); 

# process file
$twig->parsefile($file);
# set doctype
$twig->set_doctype("folia");
# show results
$twig->flush();

exit(0);

# tag processing function: add id attribute
sub process {
   my ($twig,$tag)= @_;
   if ($tag->name eq "p") {
      my $text = $tag->text;
      $text =~ s/^\s+//;
      $text =~ s/\s+$//;
      if ($text eq "") { $tag->cut; }
   }
}
