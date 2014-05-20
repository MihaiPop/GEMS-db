#!/usr/bin/perl

# This script takes a cluster partition file (in XML) and 
# the results of mapping the cluster centers to a reference database
# and creates a tab-delimited file with the following information
#
# OTU ID  Center ID  NCBI ID NCBI taxonomy Reference ID  Reference taxonomy
#
# The last column is only added if a mapping from reference ids to taxonomy
# is also provided


use XML::Parser;
use Getopt::Long;
use Text::CSV;
use ParseTaxonomy;

use strict;

my $VERSION = ' $Id: otublasttable.pl,v 1.7 2013/06/17 08:00:56 mpop Exp $ ';

my %otucenter; # OTU for each center
my %dbref2tax; # taxonomy of db reference;
my %center2dbref; # center id to db reference id;
my %dbref2ncbi; # ncbi id of db reference;

# for XML parser
my $currenttag;
my $currentotu;
my $level;

# for taxonomy
my @levels = ("superkingdom", "phylum", "class", "order", 
	      "family", "genus", "species", "strain");

# command line options
my $partfile = undef;
my $clustfile = undef;
my $blastout = undef;
my $taxdir = "ncbi/taxonomy"; # location of NCBI taxonomy
my $taxinfo = undef;
my $help = undef;
my $version = undef;

my $result = GetOptions("partition=s" => \$partfile,
    "clusters=s" => \$clustfile,
    "blastout=s" => \$blastout,
    "taxdb:s" => \$taxdir,
    "taxinfo=s" => \$taxinfo,
    "help" => \$help,
    "version" => \$version);

## Print version
if (defined $version){
    die ($VERSION . "\n");
}

## Print usage if incorrect parameters or help
if (! $result 
    || (! defined $partfile && ! defined $clustfile) 
    || ! defined $blastout
    || ! defined $taxinfo 
    || $help ) {
    die (
"Usage: otublasttable.pl [--partition <file>.part|--clusters <file>.otustats.csv] --blastout <blast.out> \n" .
"                        --taxinfo = <dbtaxinfo> [--taxdb = <taxdir>]\n" . 
"   <file>.part - XML partition file mapping OTUs to centers\n" .
"   <file>.otustats.csv - tab delimited info on clusters\n" . 
"   <blast.out> - tab-delimited output of mapping otu centers to db\n" .
"   <dbtaxinfo> - mapping of db ids to taxonomy information\n" .
"   <taxdir>    - location of NCBI-like taxonomy database.\n" . 
"                 <taxdir> must contain at least the  nodes.dmp and " . 
"                 names.dmp files\n"
	);
}

my $taxp = new ParseTaxonomy($taxdir);

my $xml = new XML::Parser(Style => 'Stream');

if (defined $partfile){
    $xml->setHandlers(Start => \&StartTag);
    $xml->parsefile($partfile); # all the work happens here
} else {
    # work off a cluster stats file 
    # expect at least columns "OTU ID" and "Center"
    my $tab = Text::CSV->new({sep_char => "\t"});
    open(IN, $clustfile) || die ("Cannot open $clustfile: $!\n");
    $tab->column_names($tab->getline(\*IN));
    while (my $data = $tab->getline_hr(\*IN)){
	$otucenter{$$data{"Center"}} = $$data{"OTU ID"};
    }
    close(IN);
}

# at this point we have
# otucenter filled in

open(BLAST, $blastout) || die ("Cannot open blast results $blastout: $!\n");
while (<BLAST>){
  chomp;
#  my ($center, $refid) = split('\t', $_);
  my @fields = split('\t', $_);
  $center2dbref{$fields[0]} = $fields[1];
}
close(BLAST);

if (defined $taxinfo){
  open(TAXINFO, $taxinfo) || die ("Cannot open taxonomy $taxinfo: $!\n");
  while (<TAXINFO>){
    chomp;
    my @fields = split('\t', $_);
   # I assume the fields are:
   # ref ID, ncbi taxid, ncbi name, ref taxonomy, taxonomic rank
   $dbref2tax{$fields[0]} = $fields[3]; 
   $dbref2ncbi{$fields[0]} = $fields[1];
  }
  close(TAXINFO);
}

print "OTU ID\tCenter\tNCBI ID\tNCBI taxonomy\tDB ID\tDB taxonomy\n";
while (my ($center, $otu) = each %otucenter){
  print "$otu\t$center";
  if (! exists $center2dbref{$center}){
	print "\tNULL\tNULL\tNULL\tNULL\n";
  } else {
     if (! exists $dbref2ncbi{$center2dbref{$center}}){
 	print "\tNULL\tNULL";
     } else {
	print "\t$dbref2ncbi{$center2dbref{$center}}\t",
	$taxp->getFullTaxonomy($dbref2ncbi{$center2dbref{$center}});
     }
     print "\t", $center2dbref{$center};
     if (! exists $dbref2tax{$center2dbref{$center}}){
	print "\tNULL\n";
     } else {
       print "\t", $dbref2tax{$center2dbref{$center}}, "\n";
     }
  }
}

exit(0);

###################
# XML Parser stuff
###################
sub StartDocument
{
    print STDERR "start parsing\n";
}

sub EndDocument
{
    print STDERR "end parsing\n";
}

sub StartTag
{
    my ($expat, $tag, %attrs) = @_;
    
    if (lc($tag) ne "part"){
        die ("Found unknown tag: $tag\n");
    }
    #allowed tags - PART

    $currenttag = lc($tag);
    ++$level;
    $currentotu = $attrs{"NAME"};
    if (exists $attrs{"CENTER"}){
        $otucenter{$attrs{"CENTER"}} = $currentotu;
    }
}

sub EndTag
{
    --$level;
    $currentotu = undef;
    $currenttag = undef;
    # end of partition
}

sub Text
{
}

sub pi
{
}

