#!/usr/bin/perl

use strict;

my $VERSION = ' $Id: countcodes.pl,v 1.3 2012/07/13 18:34:16 mpop Exp $ ';

####
#
# Change the following line to point to location of Perl libraries
#
####

use Bio::Seq;
use Bio::SeqIO;
use Getopt::Long;

my $infile = undef;
my $help = undef;
my $version = undef;
my $len = 8;

my $result = GetOptions(
	"help" => \$help,
	"version" => \$version,
	"len=i" => \$len,
	"in=s" => \$infile);

if (defined $version) {
	die ($VERSION . "\n");
}

if (defined $help
    || ! defined $result
    || ! defined $infile) {
 die ("Usage: countcodes --in file.fa [--len <nn>]\n" .
      "  - counts barcodes of length --len (default 8) which prefix \n" .
      "  the records in file file.fa\n");
}     

my %barcodes = ();

my $in = Bio::SeqIO->new(-file => $infile,
                         -format => 'fasta', 
                         -alphabet => 'dna');
if (! defined $in) {die ("Cannot open $infile\n");}

while (my $seq = $in->next_seq()){
    my $data = uc($seq->seq());

    my $first = substr($data, 0, $len);
    
   $barcodes{$first}++;
}
close FA;

my @codes = keys %barcodes;
@codes = sort {$barcodes{$b} <=> $barcodes{$a}} @codes;

for (my $i = 0; $i <= $#codes; $i++){
	print $codes[$i], "\t", $barcodes{$codes[$i]}, "\n";
}
exit(0);
