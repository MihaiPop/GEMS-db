#!/usr/bin/perl

use strict;

my $VERSION = ' $Id: aggregateClinical.pl,v 1.8 2012/11/13 21:14:40 mpop Exp $ ';

# this program takes a count table and a clinical file and outputs
# a new table where the columns are aggregated by clinical status.

use ParseTab;
use Getopt::Long;
use Statistics::Descriptive;

my $help = undef;
my $version = undef;
my $prefix = undef;
my $otuCounts = undef;
my $clinical = undef;
my $param = undef;

my $result = GetOptions(
    "help" => \$help,
    "version" => \$version,
    "prefix=s" => \$prefix,
    "in=s" => \$otuCounts,
    "clinical=s" => \$clinical,
    "param=s" => \$param
    );

if (defined $version){
    die ($VERSION . "\n");
}

if (! defined $result 
    || defined $help
    || ! defined $prefix
    || ! defined $otuCounts
    || ! defined $clinical
    || ! defined $param
    ) {
    die ("Usage: aggregateClinical.pl --prefix name --clinical clin.csv --in otus.count.csv --param param\n" .
	 "       outputs a new file name.byclinical.csv that contains\n" .
	 "       aggregate counts (# samples, total count, average count,\n".
	 "standard deviation) for each value of the clinical parameter chosen\n" .
	 " with --param\n"
	);
}

# here we record the clinical information;
open(CLIN, $clinical) || 
    die ("Cannot open $clinical: $!\n");

my $clintab = new ParseTab(\*CLIN);

my %id2clin = ();
my %headPar = ();
while (my $data = $clintab->getRecord()){
    if (! exists $$data{$param}){
	die ("Cannot find parameter $param in clinical file $clinical\n");
    }

    $id2clin{$$data{"Sample ID"}} = $$data{$param};
    $headPar{$$data{$param}} = 1;
}

close(CLIN);

# now the hard work starts.
my @header = keys %headPar;
my %clinstat = ();
open(OUT, ">$prefix.byclin.csv") ||
    die ("Cannot open $prefix.byclin.csv: $!\n");
print OUT "OTU";
for (my $i = 0; $i <= $#header; $i++){
    $clinstat{$header[$i]} = Statistics::Descriptive::Full->new();
    print OUT "\t$header[$i] num\t$header[$i] sum\t$header[$i] mean\t$header[$i] stdev";
}
print OUT "\n";

open(IN, $otuCounts) ||
    die ("Cannot open $otuCounts: $!\n");
my $intab = new ParseTab(\*IN);

my %error;
while (my $data = $intab->getRecord()){
    print OUT $$data{"OTU"};
    while (my ($id, $clin) = each %id2clin){
	if (! exists $$data{$id}){
	    if (! exists $error{$id}){
		print STDERR "Cannot find $id in otu table\n";
		$error{$id} = 1;
	    }
	    next;
	}
	$clinstat{$clin}->add_data($$data{$id});
    }
    for (my $i = 0; $i <= $#header; $i++){
	print OUT "\t", $clinstat{$header[$i]}->count();
	print OUT "\t", $clinstat{$header[$i]}->sum();
	print OUT "\t", $clinstat{$header[$i]}->trimmed_mean(0.02);
	print OUT "\t", $clinstat{$header[$i]}->standard_deviation();
	$clinstat{$header[$i]} = Statistics::Descriptive::Full->new();
    }
    print OUT "\n";
}
close(OUT);
