#!/usr/bin/perl -w
# teiExtractText: extract text with relevant tags from tei file
# usage: teiExtractText file
# 1.0 - 20130702 erikt(at)xs4all.nl
# 2.0 - 2017 various fixes by proycon(at)anaproy.nl
# 3.0 - 2019 updated for FoLiA v2 by proycon(at)anaproy.nl

use XML::Twig;
use strict;
use utf8;
use Sys::Hostname;

my $version = "3.0";

my $command = $0;
my $addedCounter = 0;
# get the file name
if (not defined $ARGV[0] or $ARGV[0] eq "") {
   die "usage: $command file\n";
}
my $file = $ARGV[0];
my $idno = $file;
$idno =~ s/\.xml$//;
$idno =~ s/.*\///;
# define xml actions: 1 tags to be processed; 2 actions; 3 print format
my $twig = new XML::Twig(
   keep_encoding => 1,  # keeps &nbsp; from becoming &amp;nbsp; also neccssary for UTF-8
   twig_roots    => {
                        'bibl' => 1 ,      # convertToP
                        'cell' => 1 ,      # convertToP
                        'cit' => 1 ,       # convert to div
                        'cf' => 1 ,        # convert to div
                        'chapter' => 1 ,        # convert to div
                        'div' => 1 ,       # remove attribute
                        'external' => 1 ,       # copy
                        'figDesc' => 1 ,   # move to grandparent
                        'figure' => 1 ,    # various
                        'head' => 1 ,      # various
                        'head1' => 1 ,      # various
                        'head2' => 1 ,      # various
                        'head3' => 1 ,      # various
                        'head4' => 1 ,      # various
                        'head5' => 1 ,      # various
                        'hi' => 1 ,        # delete but keep content
                        'publicationStmt/idno' => 1, # for id;
                        'interp' => 1 ,    # remove
                        'interpGrp' => 1 , # remove
                        'item' => 1 ,      # various
                        'l' => 1 ,         # convertToP
                        'label' => 1 ,     # delete
                        'lb' => 1 ,        # delete
                        'lg' => 1 ,        # copy
                        'list' => 1 ,      # delete when empty
                        'name' => 1 ,      # delete but keep content
                        'note' => 1 ,      # move to grandparent
                        'poem' => 1 ,      # convertToDiv
                        'p' => 1 ,         # copy
                        'q' => 1 ,         # change name
                        'pb' => 1 ,        # delete
                        'ref' => 1 ,       # copy
                        'row' => 1 ,       # delete when empty
                        'signed' => 1 ,    # convertToP
                        'sp' => 1 ,        # convertToDiv
                        'speaker' => 1 ,   # copy
                        'stage' => 1 ,     # convertToP
                        't' => 1 ,         # remove all internal tags
                        'table' => 1 ,     # delete when empty
                        'teiHeader' => 1,  # delete
                        'text' => 1,       # copy
                        'lg/tune' => 1,    # tune
                        'tune' => 1,       # tune
                        'xref' => 1        # convertToP
                  } ,
   twig_handlers => {
                        'bibl' => \&convertToP,
                        'cell' => \&processItem,
                        'cf' => \&convertToDiv,
                        'cit' => \&convertToDiv,
                        'chapter' => \&convertToDiv,
                        'div' => \&divDeleteAttr,
                        'external' => \&processExternal,
                        'figDesc' => \&processItem,
                        'figure' => \&processFigure,
                        'head' => \&processHead,
                        'head1' => \&processHead,
                        'head2' => \&processHead,
                        'head3' => \&processHead,
                        'head4' => \&processHead,
                        'head5' => \&processHead,
                        'hi' => \&processHi,
                        'publicationStmt/idno' => \&processIdno,
                        'interp' => \&cut,
                        'interpGrp' => \&cut,
                        'item' => \&processItem,
                        'l' => \&processL,
                        'label' => \&cut,
                        'lb' => \&cut,
                        'lg' => \&processLg,
                        'list' => \&processStructure,
                        'name' => \&processHi,
                        'note' => \&processNote,
                        'p' => \&processStructure,
                        'poem' => \&convertToDiv,
                        'q' => \&processQ,
                        'pb' => \&cut,
                        'ref' => \&copy,
                        'row' => \&processStructure,
                        'signed' => \&convertToP,
                        'sp' => \&processSp,
                        'speaker' => \&copy,
                        'stage' => \&processStage,
                        't' => \&processT,
                        'table' => \&processStructure,
                        'teiHeader' => \&cut,
                        'lg/tune' => \&processL,
                        'tune' => \&processTune,
                        'xref' => \&convertToP
                      } ,
   pretty_print  => 'indented'
);

# process file
# $twig->parsefile($file); # useful for debugging
$twig->parsefile($file);
# show results
$file =~ s/.*\/_*//;
if ($idno eq "") {
    print STDERR "Empty ID not valid! ($file)";
    exit(1);
}
my $host = hostname;
my $user = $ENV{LOGNAME} || $ENV{USER} || getpwuid($<);
print <<THEEND;
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE FoLiA [ <!ENTITY nbsp " "> <!ENTITY lsquo "`"> <!ENTITY rsquo "’"> <!ENTITY ldquo '"'> <!ENTITY rdquo '"'> <!ENTITY eacute 'é'> <!ENTITY euml 'ë'> <!ENTITY egrave 'è'> <!ENTITY uuml 'ü'> <!ENTITY iuml 'ï'> <!ENTITY ouml 'ö'> <!ENTITY ecirc 'ê'> <!ENTITY ugrave 'ù'>  <!ENTITY aacute 'á'> <!ENTITY agrave 'à'> <!ENTITY ocirc 'ô'> <!ENTITY acirc 'â'> <!ENTITY epsilon 'ε'> <!ENTITY Euml 'Ë'> <!ENTITY otilde 'õ'> <!ENTITY atilde 'ã'> <!ENTITY ntilde 'ñ'> <!ENTITY plusmn '±'> <!ENTITY times '×'> <!ENTITY Egrave 'È'> <!ENTITY sect '§'> <!ENTITY Uuml 'Ü'> <!ENTITY Auml 'Ä'> <!ENTITY scaron 'š'> <!ENTITY yacute 'ý'> <!ENTITY Ouml 'Ö'> <!ENTITY omicron 'ο'> <!ENTITY lambda 'λ'> <!ENTITY tau 'τ'> <!ENTITY rho 'ρ'> <!ENTITY sigmaf 'ς'> <!ENTITY Pi 'Π'> <!ENTITY nu 'ν'> <!ENTITY theta 'θ'> <!ENTITY omega 'ω'> <!ENTITY delta 'δ'> <!ENTITY alpha 'α'> <!ENTITY kappa 'κ'> <!ENTITY beta 'β'> <!ENTITY gamma 'γ'> <!ENTITY sigma 'σ'> <!ENTITY mu 'μ'> <!ENTITY psi 'ψ'> <!ENTITY chi 'χ'> <!ENTITY upsilon 'υ'> <!ENTITY iota 'ι'> <!ENTITY igrave 'ì'> <!ENTITY ograve 'ò'> <!ENTITY ccedil 'ç'> <!ENTITY ucirc 'û'> <!ENTITY auml 'ä'> <!ENTITY icirc 'î'> <!ENTITY oacute 'ó'> <!ENTITY pi 'π'> <!ENTITY Theta 'Θ'> <!ENTITY dagger '†'> <!ENTITY Omicron "Ο"> <!ENTITY Mu 'Μ'> <!ENTITY Iota 'Ι'> <!ENTITY Sigma 'Σ'> <!ENTITY Delta 'Δ'> <!ENTITY Alpha 'Α'> <!ENTITY Omega 'Ω'> <!ENTITY Nu 'Ν'> <!ENTITY uacute 'ú'> <!ENTITY iacute 'í'> <!ENTITY phi 'φ'> <!ENTITY eta 'η'> <!ENTITY Epsilon 'Ε'> <!ENTITY zeta 'ζ'> <!ENTITY Tau 'Τ'> <!ENTITY Eta 'Η'> <!ENTITY nacute 'ń'> <!ENTITY acute '´'> <!ENTITY Oslash 'Ø'> <!ENTITY ndash '–'> <!ENTITY AElig 'Æ'> <!ENTITY frac12 '½'> <!ENTITY copy '©'> <!ENTITY fnof 'ƒ'> ]>
<FoLiA xmlns="http://ilk.uvt.nl/folia" xml:id="$idno" generator="teiExtractText.pl" version="2.0.3">
  <metadata type="native">
   <annotations>
    <text-annotation set="https://raw.githubusercontent.com/proycon/folia/master/setdefinitions/text.foliaset.ttl" />
    <division-annotation set="https://raw.githubusercontent.com/proycon/folia/master/setdefinitions/nederlab-div.foliaset.ttl" />
    <event-annotation set="https://raw.githubusercontent.com/proycon/folia/master/setdefinitions/nederlab-events.foliaset.ttl" />
    <paragraph-annotation />
   </annotations>
   <provenance>
    <processor xml:id="proc0.piccl" name="PICCL" version="0.7.7" host="${host}" user="${user}">
     <processor xml:id="proc0.nederlab" name="nederlab.nf">
      <processor xml:id="proc0.teiExtractText.pl" name="teiExtractText.pl" version="${version}">
       <processor xml:id="proc0.TEI.source" name="${file}" src="${file}" type="datasource" format="text/tei+xml" />
      </processor>
     </processor>
    </processor>
   </provenance>
  </metadata>
THEEND
print "  <text xml:id=\"${idno}_text\">";
my $root = $twig->root->first_child('text')->first_child('body');
foreach my $div ($root->children) {
   if ($div->text !~ /^\s*$/ or $div->name eq "external") {
      $div->print;
   }
}
print "\n   </text>\n</FoLiA>\n";

exit(0);

sub normspaces {
    my $text = $_[0];
    $text =~ s/[\t\r\n\s]+/ /g;
    return $text;
}

sub convertToDiv {
   my ($twig,$tag) = @_;
   my $atts = $tag->atts;
   foreach my $att (keys %{$atts}) {
      if ($att ne "xml:id" and $att ne "class") { $tag->del_att($att); }
   }
   if (not defined $tag->{'att'}->{'class'}) {
      $tag->set_att("class",$tag->name);
   }
   $tag->set_name('div');
   if ($tag->text =~ /^\s*$/) { $tag->cut; }
   else {
      foreach my $c ($tag->children) {
         if ($c->name eq "#PCDATA") {
            my $newT = new XML::Twig::Elt("t",normspaces($c->text));
            $c->set_text("");
            if (normspaces($c->text) != "") {
                $newT->paste("last_child",$c);
            }
            $c->set_name("p");
            $addedCounter++;
            $c->set_att("xml:id","addedByTET-".$addedCounter);
         }
      }
   }
}

sub convertToP {
   my ($twig,$tag) = @_;
   $tag->set_name('p');
   my $atts = $tag->atts;
   foreach my $att (keys %{$atts}) {
      if ($att ne "xml:id" and $att ne "class") { $tag->del_att($att); }
   }
   &processStructure($twig,$tag);
   my @children = $tag->children;
   if ($tag->text =~ /^\s*$/) { $tag->cut; }
   elsif (not &relevant(@children)) {
      my $newT = new XML::Twig::Elt("t",normspaces($tag->text));
      $tag->set_text("");
      $newT->paste("last_child",$tag);
   }
}

sub processExternal {
   my ($twig,$tag) = @_;
   my $atts = $tag->atts;
   foreach my $att (keys %{$atts}) {
      if ($att eq "xml:id" ) { $tag->del_att($att); }
   }
}

sub copy {
   my ($twig,$tag) = @_;
   return();
}

sub cut {
   my ($twig,$tag) = @_;
   $tag->cut;
}

sub divDeleteAttr {
   my ($twig,$tag) = @_;
   my $atts = $tag->atts;
   foreach my $att (keys %{$atts}) {
      if ($att ne "xml:id" and $att ne "class" and $att ne "type") { $tag->del_att($att); }
   }
   if ($tag->name eq 'div') {
      if (defined $tag->{'att'}->{'type'}) {
         if ($tag->{'att'}->{'type'} eq "scene") { $tag->set_name("event"); }
         $tag->set_att("class",$tag->{'att'}->{'type'});
         $tag->del_att('type');
      }
      if (defined $tag->{'att'}->{'xml:id'} and $tag->{'att'}->{'xml:id'} eq $idno) {
         $tag->set_att('xml:id',$idno."_div");
      }
      if ($tag->text =~ /^\s*$/) { $tag->cut; }
   }
   my @children = $tag->children;
   foreach my $child (@children) {
      if ($child->name eq "#PCDATA") {
         $child->set_name("p");
         $addedCounter++;
         $child->set_att("xml:id","addedByTET-".$addedCounter);
         my $text = $child->text;
         $child->set_text("");
         if (normspaces($text) != "") {
             my $newT = new XML::Twig::Elt("t",normspaces($text));
             $newT->paste("last_child",$child);
        }
      }
   }
}

sub deleteWhenEmpty {
   my ($twig,$tag) = @_;
   my $atts = $tag->atts;
   foreach my $att (keys %{$atts}) {
      if ($att ne "xml:id" and $att ne "class") { $tag->del_att($att); }
   }
   my @children = $tag->children;
   if (not @children) { $tag->cut; }
   elsif ($tag->name eq "table" and $#children == 0 and $children[0]->name eq "#PCDATA") {
      # $tag->cut;
      $tag->set_name("p");
      $children[0]->set_name("t");
   }
}

sub empty {
   my ($twig,$tag) = @_;
   $tag->set_text("");
}

sub moveToGrandParent {
   my ($twig,$tag,$position) = @_;
   if (not defined $tag) {
      die "$command: found undefined tag value; twig = $twig\n";
   }
   if (not defined $tag->parent) {
      die "$command: moveToGrandParent: cannot move node without parent: ".$tag->name."\n";
   }
   my $parent = $tag->parent;
   if (not defined $parent) { return; }
   if ($parent->name eq "div") {
      # if the parent is already a div, there is no reason to move the tag
      return;
   }
   my $grandParent = $parent->parent;
   if (not defined $grandParent) { return; }
   if (defined $grandParent and defined $tag) {
      $tag->cut;
      if (not defined $position or $position ne "before") { $tag->paste("last_child" => $grandParent); }
      else { $tag->paste("before" => $parent); }
      if (defined $tag and $grandParent->name ne "div") { &moveToGrandParent($twig,$tag); }
   }
}

sub processNote {
   my ($twig,$tag) = @_;
   my $atts = $tag->atts;
   foreach my $att (keys %{$atts}) {
      if ($att ne "xml:id" and $att ne "class") { $tag->del_att($att); }
   }
#  my $newElement = new XML::Twig::Elt('ref',"");
#  $newElement->set_att('type','note');
#  my $tagId = $tag->{'att'}->{'xml:id'};
#  $newElement->set_att('id',$tagId);
#  $newElement->paste('before',$tag);
   &addT($twig,$tag);
   if (defined $tag->parent) {
      &moveToGrandParent($twig,$tag);
   }
}

sub processIdno {
   my ($twig,$tag) = @_;
   if ($tag->{'att'}->{'type'} eq 'titelcode') {
      if ($tag->text =~ /^\s*$/) { warn("$command: empty id number: should not happen!\n"); }
      $idno = $tag->text;
   }
}

sub processHi {
   my ($twig,$tag) = @_;
   if ($tag->parent->name eq "div") {
      $tag->set_name("p");
      my $text = $tag->text;
      $tag->set_text("");
      my $newT = new XML::Twig::Elt("t",normspaces($text));
      $newT->paste("last_child",$tag);
   }
}

sub processHead {
   my ($twig,$tag) = @_;
   my $atts = $tag->atts;
   foreach my $att (keys %{$atts}) {
      if ($att ne "xml:id" and $att ne "class") { $tag->del_att($att); }
   }
   my $parent = $tag->parent;
   $tag->set_name('head');
   if ($tag->text =~ /^\s*$/) { $tag->cut; }
   else {
      my $newElement = new XML::Twig::Elt('t',normspaces($tag->text));
      my $text = $tag->text;
      $tag->set_text("");
      $newElement->paste("last_child" => $tag);
      if ($parent->name =~ /^(lg|list|table)$/) {
         $tag->set_name('p');
         &moveToGrandParent($twig,$tag,"before");
      }
   }
}

sub processL {
   my ($twig,$tag) = @_;
   my $text = $tag->text;
   $text =~ s/\&nbsp;/ /g;
   if ($text =~ /^\s*$/) { $tag->cut; }
   else {
      my $atts = $tag->atts;
      foreach my $att (keys %{$atts}) {
         if ($att ne "xml:id" and $att ne "class") { $tag->del_att($att); }
      }
      $tag->set_name('t-str');
      $tag->set_text(normspaces($tag->text));
      my $newElement = new XML::Twig::Elt('br');
      $newElement->paste('last_child',$tag);
   }
}

sub processStage {
   my ($twig,$tag) = @_;
   $tag->set_name('event');
   $tag->set_att("class","stage");
   # $tag->set_text($tag->text);
   if ($tag->text =~ /^\s*$/) { $tag->cut; }
   else {
       #my $newElement = new XML::Twig::Elt('t',normspaces($tag->text));
      my @children = $tag->children;
      $tag->set_text("");
      foreach my $c (@children) {
         if ($c->name eq "ref") {
            $c->paste("last_child",$tag);
         }
      }
      #$newElement->paste('last_child',$tag);
      if ($tag->parent->name eq "sp") {
         # ref trace: not yet possible in FoLiA
#        my $ref = new XML::Twig::Elt('ref',"");
#        $ref->set_att("id",$tag->{'att'}->{'xml:id'});
#        $ref->set_att("type","event");
#        $ref->paste('last_child',$tag->parent);
         my $grandParent = $tag->parent->parent;
         $tag->cut;
         $tag->paste('last_child',$grandParent);
      }
   }
}

sub processItem {
   my ($twig,$tag) = @_;
   my $atts = $tag->atts;
   foreach my $att (keys %{$atts}) {
      if ($att ne "xml:id" and $att ne "class") { $tag->del_att($att); }
   }
   # $tag->set_name('p');
   my $content = $tag->text;
   $content =~ s/&nbsp;/ /g;
   $content =~ s/^\s+//g;
   $content =~ s/\s+$//g;
   if ($content eq "") { $tag->cut; }
   else {
      my $newT = new XML::Twig::Elt("t",normspaces($content));
      my @children = $tag->children;
      $tag->set_text("");
      $newT->paste("last_child",$tag);
      foreach my $c (@children) {
         if ($c->name eq "ref") {
            $c->paste("last_child",$tag);
         }
      }
   }
}

sub processFigure {
   my ($twig,$tag) = @_;
   # $tag->del_att('rend');
   if ($tag->text =~ /^\s*$/) { $tag->cut; }
   else {
      $tag->set_name('p');
      $tag->set_text(normspaces($tag->text));
      &processStructure($twig,$tag);
      &addT($twig,$tag);
   }
}

sub processQ {
   my ($twig,$tag) = @_;
   my $atts = $tag->atts;
   foreach my $att (keys %{$atts}) {
      if ($att ne "xml:id" and $att ne "class") { $tag->del_att($att); }
   }
   $tag->set_name('p');
   $tag->set_att("class","quote");
   &processStructure($twig,$tag);
   &addT($twig,$tag);
}

sub processLg {
   my ($twig,$tag) = @_;
   $tag->set_name('event');
   $tag->set_att("class",$tag->{'att'}->{'type'});
   my $atts = $tag->atts;
   foreach my $att (keys %{$atts}) {
      if ($att ne "xml:id" and $att ne "class") { $tag->del_att($att); }
   }
   my $newElement = new XML::Twig::Elt("t","");
   my @lines = $tag->children;
   my $found = 0;
   foreach my $line (@lines) {
      if ($line->name eq "t-str") {
         $line->cut;
         if ($line->text !~ /^\s*$/) {
            $line->paste('last_child',$newElement);
            $found++;
         }
      }
      if ($line->name eq "br") {
         $line->cut;
         $line->paste('last_child',$newElement);
      }
   }
   if ($found) {
       $newElement->paste('last_child',$tag);
   }
}

sub processSp {
   my ($twig,$tag) = @_;
   $tag->set_name('event');
   my $atts = $tag->atts;
   foreach my $att (keys %{$atts}) {
      if ($att ne "xml:id" and $att ne "class") { $tag->del_att($att); }
   }
   #my $newElement = new XML::Twig::Elt("t","");
   #$newElement->set_att('xml:id',$tag->{'att'}->{'xml:id'}.".t");
   $tag->set_att('class',"speakerturn");
   if (not defined $tag->first_child("speaker")) {
      $tag->set_att('actor',"UNKNOWN");
   } else {
      my $speakerTag = $tag->first_child("speaker");
      $speakerTag->set_name('event');;
      $speakerTag->set_att("class","stage"); # remove internal tags
      my $speakerText = $speakerTag->text;
      $speakerText =~ s// /g;
      if ($speakerText =~ /^\s*$/) { $speakerTag->cut; }
      else {
         $speakerTag->set_text(""); # remove internal tags
         my $newT = new XML::Twig::Elt("t",normspaces($speakerText));
         $newT->paste(last_child => $speakerTag);
         $speakerTag->cut;
         $speakerTag->paste(before => $tag);
         $tag->set_att('actor',$speakerText);
         if (defined $tag->first_child("speaker")) {
            die "$command: error: duplicate speaker found in file $file\n";
         }
      }
   }
   #my @lines = $tag->children;
   #foreach my $line (@lines) {
   #   if ($line->name eq "utt" or $line->name eq "ref") {
   #      $line->cut;
   #      if ($line->text !~ /^\s*$/ or $line->name eq "ref") {
   #         $line->paste('last_child',$newElement);
   #      }
   #   }
   #}
   #if ($newElement->text ne "") {
   #   $newElement->paste('last_child',$tag);
   #}
}

sub processStructure {
   my ($twig,$tag) = @_;
   my $atts = $tag->atts;
   foreach my $att (keys %{$atts}) {
      if ($att ne "xml:id" and $att ne "class") { $tag->del_att($att); }
   }
}


sub processT {
   my ($twig,$tag) = @_;
   my $atts = $tag->atts;
   foreach my $att (keys %{$atts}) {
      if ($att ne "xml:id" and $att ne "class") { $tag->del_att($att); }
   }
   if ($tag->text =~ /^\s*$/) { $tag->cut; }
   else {
      my $text = $tag->text;
      $tag->del_att("xml:id");
      $tag->set_text(normspaces($text));
      if ($text =~ /^\s*$/) { $tag->cut; }
   }
}

sub addT {
   my ($twig,$tag) = @_;
   # create new child element t
   # move paragraph text t from p to t
   my $content = $tag->text;
   $content =~ s/&nbsp;/ /g;
   $content =~ s/^\s+//g;
   $content =~ s/\s+$//g;
   if ($content eq "") { $tag->cut; }
   else {
      my $atts = $tag->atts;
      foreach my $att (keys %{$atts}) {
         if ($att ne "xml:id" and $att ne "class") { $tag->del_att($att); }
      }
      my $newElement = new XML::Twig::Elt("t",normspaces($content));
      my @children = $tag->children;
      $tag->set_text("");
      $newElement->paste('last_child',$tag);
      foreach my $c (@children) {
         if ($c->name eq "ref") {
            $c->paste("last_child",$tag);
         }
      }
   }
}

sub processTune {
   my ($twig,$tag) = @_;
   my $atts = $tag->atts;
   foreach my $att (keys %{$atts}) {
      if ($att ne "xml:id" and $att ne "class") { $tag->del_att($att); }
   }
   $tag->set_name("p");
   my $newT = new XML::Twig::Elt("t",normspaces($tag->text));
   $tag->set_text("");
   $newT->paste('last_child',$tag);
}

sub relevant {
   my @children = @_;
   my %skip = qw(name 1 hi 1);
   $skip{"#PCDATA"} = 1;
   for (my $i=0;$i<=$#children;$i++) {
      if (not defined $skip{$children[$i]->name}) { return(1); }
   }
   return(0);
}
