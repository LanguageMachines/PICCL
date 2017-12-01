#!/usr/bin/perl -w
# teiAddIds: add id attribute to tei file
# usage: teiAddIds file
# 20130702 erikt(at)xs4all.nl

use XML::Twig;
use strict;

my $command = $0;
my $outDir = ".";

# get the file name
if ((not defined $ARGV[0] or $ARGV[0] eq "") or (not defined $ARGV[1] or $ARGV[1] eq "")) {
   die "usage: $command tei_file oztfile\n";
}
my $file = $ARGV[0];
my $oztFile = $ARGV[1];
my %oztFiles = ();
&readOZTs();
my $oztCounter = 0;
my $divCounter = 0;
my $cleanFile = $file;
$cleanFile =~ s/\.xml$//;
$cleanFile =~ s/.*\///;
$cleanFile =~ s/^\s*//;
$cleanFile =~ s/\s*$//;
my $idno = $cleanFile;

# define xml action (process tags with process) and print format
my $twig = new XML::Twig(
   twig_handlers => { _default_ => \&process },
   pretty_print => 'indented',
   keep_encoding => 1
);
# include unique number in each id
my $counter = 1;

# process file
$twig->parsefile($file);

# show results
if (open(OUTFILE,">$idno.ids.xml" )) {  #,"| gzip -c > $outDir/$idno.xml.gz")) {
   $twig->flush(\*OUTFILE);
   close(OUTFILE);
}

# sanity check
if (defined $oztFiles{$idno} and $oztCounter != $oztFiles{$idno}) {
   print "$command: unexpected number of ozts in file $file: $oztCounter rather than ".$oztFiles{$idno}."\n";
}

exit(0);

# tag processing function: add id attribute & split off dependent titles
sub process {
   my ($twig,$tag)= @_;
   #strip quotes in attributes, may lead to malformed XML!
   my $atts = $tag->atts;
   foreach my $att (keys %{$atts}) {
       my $value = $tag->att($att);
       $value =~ s/"//g;
       $tag->set_att($att => $value);
   }
   # store the path of this tag in a list
   my @id = $twig->context;
   # add name of tag to list of id elements
   push(@id,$tag->name);
   # add name of counter to list of id elements
   push(@id,$counter);
   unshift(@id,$idno);
   # head tags of type h2 should be changed to <p>
   # to avoid having two head tags in a chapter (h2 and standard h3)
   if ($tag->name eq "head" and defined
       $tag->{'att'}->{'rend'} and $tag->{'att'}->{'rend'} eq "h2") {
      my $new = XML::Twig::Elt->new('p');
      my $text = $tag->text;
      $new->set_text($text);
      $new->paste(before=>$tag);
      $tag->cut;
      $tag = $new;
   }
   # set id value to string of id elements
   # ids consist of a tree on ancestor tags
   # divs of type chapter with descendant head of type h3
   # will be put in a separate documents (ozt: onzelfstandige titels)
   if (not defined $oztFiles{$idno} or
      not defined $tag->parent or
      $tag->parent->name ne "body" or
      $tag->name ne "div" or
      not defined $tag->{'att'}->{'type'} or
      $tag->{'att'}->{'type'} ne "chapter") {
#print "DEBUGA: $idno ".$tag->name."\n";
      if ($tag->name ne "t") { $tag->set_att('xml:id' => join(".",@id)); }
      # (why is type=="act" special?)
      if (defined $oztFiles{$idno} and
          defined $tag->parent and
          $tag->parent->name eq "body" and
          $tag->name eq "div" and
          defined $tag->{'att'}->{'type'} and
          $tag->{'att'}->{'type'} eq "act") {
         $divCounter++;
      }
   } else {
#print "DEBUGB: $idno\n";
      # divs in ozt files with type chapter need another id format
      # in order to make links with the metadata possible
      $divCounter++;
      my @heads = $tag->descendants('head');
      my $h3Found = 0;
      foreach my $h (@heads) {
         if (defined $h->{'att'}->{'rend'} and $h->{'att'}->{'rend'} eq "h3") {
            $h3Found = 1;
            last;
         }
      }
      foreach my $h (@heads) {
         if (defined $h->{'att'}->{'rend'}) { $h ->del_att('rend'); }
         &saveNotes($h);
         my $new = XML::Twig::Elt->new('t',$h->text);
         $h->set_text("");
         $new->paste(first_child=>$h);
      }
      if (not $h3Found) {
         if ($tag->name ne "t") { $tag->set_att('xml:id' => join(".",@id)); }
      } else {
         while ($divCounter !~ /..../) { $divCounter = "0$divCounter"; }
         my $childId = $idno."_".$divCounter;
         if ($tag->name ne "t") { $tag->set_att('xml:id' => $childId."_div"); }
         $oztCounter++;
         my $oztTwig = new XML::Twig(keep_encoding => 1);
         my $oztRoot = XML::Twig::Elt->new('TEI.2');
         $oztTwig->set_root($oztRoot);
         my $oztText = XML::Twig::Elt->new('text');
         $oztText->paste(last_child=>$oztRoot);
         my $oztBody = XML::Twig::Elt->new('body');
         $oztBody->paste(last_child=>$oztText);
         foreach my $childTag ($tag->descendants) {
            if (defined $childTag->{'att'}->{'xml:id'}) {
               $childTag->{'att'}->{'xml:id'} =~ s/^$idno/$childId/;
            }
         }
         my $new = XML::Twig::Elt->new('external');
         $new->{'att'}->{'include'} = "no";
         $new->{'att'}->{'xml:id'} = $childId;
         $new->{'att'}->{'src'} = $childId.".xml";
         $new->paste(before=>$tag);
         $tag->cut;
         $tag->paste(last_child=>$oztBody);
         if (open(OUTFILE,">$outDir/$childId.xml")) {
            print OUTFILE <<THEEND;
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE TEI.2 PUBLIC "-//DBNL//DTD TEI.2 XML//NL" "http://www.dbnl.org/xml/dtd/teixlite.dtd">
THEEND
            $oztTwig->flush(\*OUTFILE);
            close(OUTFILE);
         }
      }
   }
   # increment counter for next tag
   $counter++;
   # set document id value if it is available
## if ($tag->name eq "idno" and
##      (not defined $tag->{'att'}->{'type'} or
##      $tag->{'att'}->{'type'} eq "titelcode")) {
##    my $parent = $tag->parent;
##    if (defined $parent and $parent->name eq "publicationStmt" and $tag->text !~ /^\s*$/ and $tag->text !~ /^[xX]*$/) {
##       $idno = $tag->text;
##    }
## }
   # rend attributes should be deleted except in head tags (these are deleted somewhere else)
   if ($tag->name ne "head" and defined $tag->{'att'}->{'rend'}) { $tag ->del_att('rend'); }
   # list label tags should be changed to attributes of items
   if ($tag->name eq "item" and $tag->parent->name eq "list") {
      if (defined $tag->sibling(-1) and $tag->sibling(-1)->name eq "label") {
         my $n = $tag->sibling(-1)->text;
         $n =~ s/"/'/g;
         $tag->set_att('n' => $n);
         $tag->sibling(-1)->cut;
      }
   }
   # paragraph content should be embedded in t contexts (note: this aggressively grabs
   # the text and ignores embedded elements!)
   if ($tag->name eq "p") {
      my @children = $tag->children;
      #but there may be a relevant structure element wrapped in a needless paragraph
      if (@children and $#children == 0 and (($children[0]->name eq "table") or ($children[0]->name eq "list"))) {
          #move it outside
          my $child = $children[0];
          $child->cut;
          $child->paste(after=>$tag);
          $tag->cut;
      } else {
          &saveNotes($tag);
          my $text = $tag->text;
          $text =~ s/&nbsp;/ /g;
          # ^\s*$ does not work here: empty strings remain
          if ($text !~ /[A-Za-z0-9]/) { $tag->cut; }
          else {
             $tag->set_tag('t');
             my $id = $tag->{'att'}->{'xml:id'};
             $tag->del_att("xml:id");
             # $tag->{'att'}->{'xml:id'} = $id.".t";
             $tag->set_text($text);
             my $newp = XML::Twig::Elt->new('p');
             $newp->paste(after=>$tag);
             $newp->{'att'}->{'xml:id'} = $id;
             $tag->cut;
             $tag->paste(first_child=>$newp);
          }
      }
   }
}

# read name of files that need to be split
sub readOZTs {
   if (not open(INFILE,$oztFile)) {
      die "$command: cannot read ozt file $oztFile\n";
   }
   while (<INFILE>) {
      my $line = $_;
      chomp($line);
      my ($file,$count) = split(/\s+/,$line);
      if (not defined $count or $count !~ /^\d+$/) {
         die "$command: unexpected line in file $oztFile: $line\n";
      }
      $oztFiles{$file} = $count;
   }
   close(INFILE);
}

# move notes to parent to avoid mix with rest of text
sub saveNotes {
   my $tag = shift(@_);
   if (not defined $tag) { die "$command: usage: saveNotes(tag)\n"; }
   # save internal notes
   my @notes = $tag->descendants('note');
   if (@notes) {
      my $p = $tag->parent;
      if (not defined $p) { die "$command: error: environment ".$tag->name." without parent\n"; }
      foreach my $n (@notes) {
         $n->cut;
         $n->paste(last_child=>$p);
      }
   }
   return();
}

