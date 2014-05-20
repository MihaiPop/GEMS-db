#!/usr/bin/perl

use strict;

my $VERSION = ' $Id: clusters2part.pl,v 1.4 2012/03/13 19:06:00 mpop Exp $ ';

# parses a collection of files constructed by the 16S pipeline and
# constructs a partition file containing all the OTUs

# as input takes a directory and looks for all files called *.list or *.fn.list
# if the .list file contains just one sequence it becomes one OTU
# otherwise it reads the clusters from *.fn.list

# a second parameter is the cutoff %identity, by default 0.03

use Getopt::Long;

my $TAX = undef;
my $clusterfile = undef;
my $prefix = undef;
my $version = undef;
my $help = undef;

my $result = GetOptions(
    "clusters=s" => \$clusterfile,
    "prefix=s" => \$prefix,
    "version" => \$version,
    "help" => \$help
    );

if (defined $version){
    die ($VERSION . "\n");
}

if (! $result || defined $help || ! defined $clusterfile || ! defined $prefix){
    die (
	"Usage: clusters2part --clusters <file>.cluster --prefix <name>\n" .
	"       <file>.cluster - output from dnaclust program\n" .
	"       <name> - prefix for output file\n"
	);
}

my $otuid = 0;

open(IN, $clusterfile) || die ("Cannot open $clusterfile: $!\n");
open(OUT, ">$prefix.part") || die ("Cannot open $prefix.part: $!\n");

print OUT "<?xml version=\"1.0\"?>\n";
print OUT "<PART\n";
print OUT "NAME = \"$prefix\"\n";
print OUT "TYPE = \"TOP\"\n";
print OUT "METHOD = \"dnaclust\"\n";
print OUT ">\n";

while (<IN>){
    chomp;
    
    ++$otuid;
    
    my @seqs = split(/\s+/, $_);
    my $center = $seqs[0];

    print OUT "  <PART\n";
    print OUT "  NAME = \"$otuid\"\n";
    print OUT "  TYPE = \"OTU\"\n";
    print OUT "  CENTER = \"$center\"\n";
    print OUT "  >\n";
    for (my $i = 0; $i <= $#seqs; $i++){
	print OUT "  $seqs[$i]\n";
    }
    print OUT "  </PART>\n";
}
close(IN);
print OUT "</PART>\n";    
close(OUT);

exit(0);
