#!/usr/bin/perl

use strict;

my $VERSION = ' $Id: taxpart2counts.pl,v 1.7 2012/03/13 19:06:00 mpop Exp $ ';

# This program creates a count table based on a partition file and
# mapping from sample IDs to file names
#
# Also produced are two files with overall statistics about the samples/OTUs
# the first contains just overall stats, the second lists, for every OTU
# the total number of sequences and samples represented by that OTU


####
#
# Change the following line to point to location of Perl libraries
#
####

use ParseTab;
use XML::Parser;
use Getopt::Long;

my $version = undef;
my $help = undef;
my $partfile = undef;
my $indexfile = undef;
my $prefix = undef;
my $samIDfield = "Sample ID";

my $result = GetOptions(
    "version" => \$version,
    "help" => \$help,
    "part=s" => \$partfile,
    "index=s" => \$indexfile,
    "prefix=s" => \$prefix,
    "idfield=s" => \$samIDfield
    );

if (defined $version){
    die($VERSION . "\n");
}

if (! defined $result
    || defined $help
    || ! defined $partfile
    || ! defined $indexfile
    || ! defined $prefix){
    die("Usage: taxpart2counts.pl --part <file>.part --index file_key --prefix name\n" .
	"                         [--idfield id_field]\n" .
	"       outputs files: \n" .
	"            name.otus.count.csv - rows are OTUS and columns are samples\n" .
	"            name.stats.txt - overall statistics about the data\n" .
	"            name.outstats.csv - count statistics on a per-otu basis\n" .
	"       file_key is a file that maps seqname prefix to sample id\n" .
	"       the key must be tab-delimited and contain columns headed\n" .
	"            Sample ID, and File \#\n" .
	"       optional parameter [id_field] specifies the column in the file key\n" .
	"       corresponding to the sample id (instead of the default Sample ID)\n" .
	"\n");
}

##### XML PARSER STUFF
my $level = 0; # level in XML tree
my %otu_sample = (); # number of seqs per otu & sample
my @otus; # number of sequences per OTU
my %otutax; # taxon id for each OTU
my %otuidx; # mapping from OTU name to index in @otus array
my %sampleidx; # mapping from sample name to index in @samples array
my %otucenters = (); # mapping from OTUs to centers
my @samples; # number of sequences per sample
my $currentotu; # current OTU
my $currenttag; # current tag
##### END XML PARSER STUFF

## MAIN

my %pref2name = ();

# parse key to file name
open(KEY, $indexfile) || die ("Cannot open $indexfile: $!\n");
my $pt = new ParseTab(\*KEY);

while (my $data = $pt->getRecord()){
    if ($$data{"File \#"} ne ""){
	$pref2name{$$data{"File \#"}} = $$data{$samIDfield};
    }
}
close(KEY);

# I want to keep track of:
# taxid, sampleid,  #otus, #sequences
my %sampleotus = ();
my %sampleseqs = ();

my @taxids = ();
my %taxids = ();

#open(PART, $ARGV[0]) || die ("Cannot open $ARGV[0]:$!\n");
my $xml = new XML::Parser(Style => 'Stream');
$xml->setHandlers(Start => \&StartTag);
$xml->parsefile($partfile); # all the work happens here

# at this point we have
# @samples contains # of sequences for each sample found in the input file
# @otus contains # of sequences for each otu found in the input file
# %otu_sample contains # of sequences shared by all pairs of otus and samples

# now we just need to generate reports

open(STATS, ">$prefix.stats.txt") || die ("Cannot open $prefix.stats.txt: $!\n");
open(OTUSTATS, ">$prefix.otustats.csv") || die ("Cannot open $prefix.otustats.csv: $!\n");
print OTUSTATS "OTU ID\tCenter\tSeq #\tSample #\n";
print STATS "Input partition: $partfile \n";
print STATS "Sample information: $indexfile \n";
print STATS "Run date: ", `date`;
print STATS "\n";
print STATS sprintf("%-30s","Number of samples: "), sprintf("%10d\n", $#samples + 1), "\n";
print STATS sprintf("%-30s", "Number of otus: "), sprintf("%10d\n", $#otus + 1), "\n";

my $numseq = 0;
my $singles = 0;
for (my $i = 0; $i <= $#otus; $i++){
    if ($otus[$i] == 1) {$singles++;}
    $numseq += $otus[$i];
}

my $retest = 0;
for (my $i = 0; $i <= $#samples; $i++){
    $retest += $samples[$i];
}

if ($retest != $numseq) { print STATS "WARNING: different # of sequences in samples than in OTUs - should be the same\n";}

print STATS sprintf("%-30s", "Number of singleton OTUs: "), 
    sprintf("%10d\n", $singles), "\n";
print STATS sprintf("%-30s", "Number of non-singleton OTUs: "), 
    sprintf("%10d\n",$#otus + 1 - $singles), "\n";
print STATS sprintf("%-30s", "Number of sequences: "), 
    sprintf("%10d\n", $numseq);

close(STATS);

@taxids = keys %taxids; # all the taxids in our file

open(BYOTU, ">$prefix.otus.count.csv") || 
    die ("Cannot open $prefix.otus.count.csv: $!\n");

my @otunames = keys %otuidx; @otunames = sort {$a <=> $b} @otunames;
my @samplenames = keys %sampleidx; @samplenames = sort {$a <=> $b} @samplenames;

# print header
print BYOTU "OTU";
for (my $i = 0; $i <= $#samplenames; $i++){
    print BYOTU "\t$samplenames[$i]";
}
print BYOTU "\n";

# for each OTU print the counts and fractions
for (my $i = 0; $i <= $#otunames; $i++){
    print BYOTU $otunames[$i];
    print OTUSTATS $otunames[$i], "\t", $otucenters{$otunames[$i]};
    my $totseq = 0;
    my $totsam = 0;
    for (my $j = 0; $j <= $#samplenames; $j++){
	my $num = $otu_sample{"$otunames[$i] $samplenames[$j]"}; # total number of sequences in otu in sample
#	my $tot = $samples[$sampleidx{$samplenames[$j]}]; # total # of sequences in sample
	print BYOTU "\t", sprintf("%d", $num); 
	$totseq += $num;
	if ($num != 0) {
	    $totsam++;
#	    ++$sampleotus{$otutax{$otunames[$i]}}{$samplenames[$j]};
	}
#	$sampleseqs{$otutax{$otunames[$i]}}{$samplenames[$j]} += $num;
    }
    print BYOTU "\n";
    print OTUSTATS "\t$totseq\t$totsam\n";
}

close(BYOTU);
close(OTUSTATS);
exit(0);

##### XML stuff
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
    if (exists $attrs{"TAXID"}){
	$otutax{$currentotu} = $attrs{"TAXID"};
	$taxids{$attrs{"TAXID"}} = 1;
    } else {
	$taxids{"nomatch"} = 1;
	$otutax{$currentotu} = "nomatch";
    }
    if (exists $attrs{"CENTER"}){
	$otucenters{$currentotu} = $attrs{"CENTER"};
    } else {
	$otucenters{$currentotu} = "NA";
    }
# update list of OTUs I know about
    if ($level == 2){
	push @otus, 0;
	$otuidx{$currentotu} = $#otus;
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
    if ($level == 2 && defined $currenttag && $currenttag eq "part") {
	my @names = split(/\s+/, $_);
	for (my $i = 0; $i <= $#names; $i++){
	    if ($names [$i] ne ""){
		++$otus[$otuidx{$currentotu}]; # add a new sequence to current OTU
		# find the sample the sequence belongs to
		my ($file, $idx) = split('_', $names[$i]);
		my $sam = $pref2name{$file};
		if (! defined $sam) {die ("Can't find sample for index $file, sequence $names[$i]\n");}
		if (! exists $sampleidx{$sam}){
		    push @samples, 0;
		    $sampleidx{$sam} = $#samples;
		}
		++$samples[$sampleidx{$sam}]; # add to count of sequences for this sample
		++$otu_sample{"${currentotu} ${sam}"}; # add to count of sequences shared by otu and sample
	    }
	}
    }
}

sub pi
{

}
