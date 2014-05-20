#!/usr/bin/perl

use strict;
my $VERSION = ' $Id: demultiplexFasta.pl,v 1.5 2012/11/13 21:14:21 mpop Exp $ ';

####
#
# Change the following line to point to location of Perl libraries
#
####

use Bio::Seq;
use Bio::SeqIO;
use ParseTab;
use Getopt::Long;


# kmer/barcode length
# will be set when reading barcode file
my $KMER = undef;
my $prefix = "UNNAMED";
my $infile = undef;
my $help = undef;
my $version = undef;
my $barcodeFile = undef;

my $result = GetOptions(
    "in=s" => \$infile,
    "help" => \$help,
    "version" => \$version,
    "prefix=s" => \$prefix,
    "barcodes=s" => \$barcodeFile
    );

if (defined $version){
    die ($VERSION . "\n");
}

if (! defined $result 
    || defined $help 
    || ! defined $infile
    || ! defined $barcodeFile){
    die ("Usage: demultiplexFasta.pl --in file.fa --barcodes barcodes.csv [--prefix name]\n" .
	 "       Inputs are a fasta file\n".
	 "        and a TAB-delimited spreadsheet mapping sample IDs to barcode sequences\n" .
         "       Outputs will be \n " .
         "           <name>.NONE.list - a list of all sequences\n" .
         "           that do not have a recognizable barcode\n" .
         "           <name>.<sampleID>.fa - a fasta file containing all demultiplexed\n" .
         "           sequences for that sample ID, excluding barcode\n");
}

my %barcodes = ();
my %files = ();

open(BC, $barcodeFile) || die ("Cannot open barcodes $barcodeFile: $!\n");
my $pb = new ParseTab(\*BC);
while (my $dat = $pb->getRecord()){
    my $bc = $$dat{"Barcode"};
    my $name = $$dat{"Sample ID"};
    if (! defined $KMER) {$KMER = length($bc);}
    $barcodes{$bc} = $name;	
    print "Got barcode $bc for sample $name\n";
    $files{$name} = Bio::SeqIO->new(
	-file => ">$prefix.$name.fa",
	-format=>'fasta',
	-flush => 0);
    if (! defined $files{$name}) {die("Cannot open $prefix.$name.fa\n");}
}
open(NONE, ">$prefix.NONE.list")|| 
    die ("Cannot open $prefix.NONE.list");

close(BC);

my $in = Bio::SeqIO->new(
    -file => $infile,
    -format => 'fasta',
    -alphabet => 'dna'
    );
if (! defined $in) {die ("Cannot open $infile\n");}

my @codes = keys %barcodes;

while (my $seq = $in->next_seq()){
    my $head = $seq->display_id();
    my $data = uc($seq->seq());

    my $first = substr($data, 0, $KMER);
    
    for (my $i = 0; $i <= $#codes; $i++){ 
	my $bc = $codes[$i];
	if ($bc eq $first){
	    $files{$barcodes{$bc}}->write_seq($seq->trunc($KMER + 1, $seq->length));
	    goto DONE;
	}
    }
    print NONE $head, "\t", substr($data, 0, $KMER), "\n";
  DONE:

}
close FA;

while (my ($bc, $nm) = each %barcodes){
    $files{$nm}->close();
}
close NONE;
exit(0);
