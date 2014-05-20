#!/usr/bin/perl

use strict;

my $VERSION  = ' $Id: filter_OTUs.pl,v 1.3 2012/12/10 10:14:28 mpop Exp $ ';

# Takes an OTU statistics table and filters it according to # of samples
# and number of sequences

my $MINSEQ = 20;
my $MINSAM = 5;


use ParseTab;
use Getopt::Long;

my $version = undef;
my $help = undef;
my $infile = undef;
my $prefix = undef;

my $result = GetOptions(
    "version" => \$version,
    "help" => \$help,
    "infile=s" => \$infile,
    "prefix=s" => \$prefix,
    "minseq=i" => \$MINSEQ,
    "minsam=i" => \$MINSAM) ;

if (defined $version){
    die ($VERSION . "\n");
}

if (defined $help
    || ! defined $result
    || ! defined $prefix
    || ! defined $infile){
    die ("Usage: filter_OTUs.pl --infile <prefix>.otus.count.csv --prefix PREF\n" .
	 "  Outputs a file <prefix>.otus.good.list containing all OTUs\n" .
	 "  that have more than a count of $MINSEQ (--minseq) in one sample *OR* that occur\n" .
	 "  in more than $MINSAM (--minsam) samples\n");
}

my $outname = "$prefix.otus.good.csv";
open (OUT, ">$outname") || die ("Cannot open $outname: $!\n");
print OUT "OTU ID\tSeq #\tSample #\n";

open(IN, $infile) || die ("Cannot open $infile: $!\n");

my $pt = new ParseTab(\*IN);

#my @nameArray = @{$pt->getNameArray()};

while (my $data = $pt->getRecord()){
    my $otuname = $$data{"OTU ID"}; # first column is the name
    my $numseq = $$data{"Seq #"};
    my $numsam = $$data{"Sample #"};
    if ($numseq >= $MINSEQ || $numsam >= $MINSAM){
	print OUT $otuname, "\t", $numseq, "\t", $numsam, "\n";
    }
}

close(OUT);
close(IN);
exit(0);
