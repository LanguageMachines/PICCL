#!/usr/bin/perl -w
# frogIds: hide ids starting with _ (_ => X_) or unhide them (X_ => _)
# usage: frogIds file [NODECODE]
# note: NODECODE argument prevents former head tags being named head again
# 20130702 erikt(at)xs4all.nl

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
   if ($tag->name eq "head" and defined $tag->{'att'}->{'xml:id'}) {
      # frog has problems with head tags: temporarily rename them to p
      my $newP = XML::Twig::Elt->new('p');
      my @children = $tag->children();
      foreach my $c (@children) { $c->cut; $c->paste('last_child',$newP); }
      my $id = $tag->{'att'}->{'xml:id'};
      $newP->set_att('xml:id' => $id);
      $newP->paste(before=>$tag);
      $tag->cut;
      $tag = $newP;
   } elsif (not defined $ARGV[0] and defined $tag->{'att'}->{'xml:id'}) {
      my $id = $tag->{'att'}->{'xml:id'};
      if ($id =~ /\.head\.\d+$/) {
         # so the tag is not named head but its id indicates it was once: rename it
         my $newH = XML::Twig::Elt->new('head');
         my @children = $tag->children();
         foreach my $c (@children) { $c->cut; $c->paste('last_child',$newH); }
         $newH->set_att('xml:id' => $id);
         $newH->paste(before=>$tag);
         $tag->cut;
         $tag = $newH;
      }
   }
}
