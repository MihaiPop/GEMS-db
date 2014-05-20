#!/usr/bin/perl

use strict;

my $VERSION = ' $Id: s95norm.pl,v 1.4 2012/04/25 14:40:25 mpop Exp $ ';

#####################################################
# This script performs quantile normalization of a count
# table.  Specifically, for each sample it computes the
# 95th quantile, aggregates all counts below this value,
# then scales all samples to ensure that the aggregat
# counts are equal across samples.
######################################################



use ParseTab;
use Statistics::Descriptive;
use Getopt::Long;

my $MINFEAT = 20; # minimum number of features required for normalization
my $OMITLOW = 0;   # set to 1 to omit features with < 1 normalized value
my $TOINT = 0;     # set to 1 to round all features to the nearest integer
my $KMER = undef;
my $prefix = "UNNAMED";
my $infile = undef;
my $help = undef;
my $version = undef;
my $quantile = 95;
my $opt = undef;
my $scale = 1000;

my $result = GetOptions(
    "in=s" => \$infile,
    "help" => \$help,
    "version" => \$version,
    "prefix=s" => \$prefix,
    "quantile=s" => \$quantile,
    "scale=s" => \$scale,
    "opt=s" => \$opt
    );

if (defined $version){
    die ($VERSION . "\n");
}

if (! defined $result 
    || defined $help 
    || ! defined $infile){
    die ("Usage: s95norm.pl --in <name>.csv --prefix <prefix> --opt [int|low|int,low] [--quantile <nn>] [--scale <nn]\n" .
	 "Output will be <prefix>.s95.csv - the normalized count table\n" . 
	 "   as well as <prefix>.norm.csv - table containing per-sample s95 and q95 information\n" .
	 "Optional parameter --opt can be\n" .
	 "     int - all numbers rounded to nearest integer\n" .
	 "     low - all counts < q95 for a sample are removed\n" .
	 "   or a combination thereof (without spaces), e.g., \'int,low\'\n\n" .
	 "By default program uses 95% percentile, however this number can be set\n" .
	 "  with option --quantile\n" .
	 "Values are scaled by 1000, or the value provided by parameter --scale\n"
);
}

if (defined $opt && $opt =~ /int/){
    $TOINT = 1;
}
if (defined $opt && $opt =~ /low/){
    $OMITLOW = 1;
}

open (IN, $infile) || die ("Cannot open $infile: $!\n");
open (OUT, ">$prefix.s95.csv") || die ("Cannot open $prefix.s95.csv: $!\n");
open (NORMOUT, ">$prefix.norm.csv") || die ("Cannot open $prefix.norm.csv: $!\n");

print NORMOUT "Sample ID\tnum\tq95\ts95\n";

my $pt = new ParseTab(\*IN);
die ("Cannot create parser for $infile\n") unless defined $pt;

# here rows are OTUs and columns are samples
# want to process column by column and compute quantiles

my @headers = @{$pt->getNameArray()};
#print join(",", @headers), "\n";
my @dataarray = ();
my $row = 0;
while (my $data = $pt->getRecord()){
    for (my $c = 0; $c <= $#headers; $c++){
	$dataarray[$row][$c] = $$data{$headers[$c]};
#	print "Adding $$data{$headers[$c]} in $row $c for $headers[$c]\n";
    }
    $row++;
}

print STDERR "Got $row rows and ", $#headers + 1, " columns\n";
# Now the array should have all the useful info

my $s95stats = Statistics::Descriptive::Full->new();
my @s95array = ();
my @q95array = ();

# go column by column
for (my $c = 1; $c <= $#headers; $c++){
    my $colstat = Statistics::Descriptive::Full->new();
    for (my $row = 0; $row <= $#dataarray; $row++) {
	if ($dataarray[$row][$c] > 0) {
	    $colstat->add_data($dataarray[$row][$c]);
	}
    }

    # check that I have enough features (100??)
    $MINFEAT = int (100  / (100 - $quantile));
    if ($colstat->count() < $MINFEAT){
	print STDERR "Sample $headers[$c] has too few features: ", $colstat->count, "\n";
	print NORMOUT "$headers[$c]\t", $colstat->count(), "\t0\t0\n";
	next;
    }
    
    # compute 95th quantile
    my $q95 = $colstat->percentile($quantile);
    my @sorted = $colstat->get_data();
   # print join(":", @sorted), "\n";
    my $s95 = 0;
    for (my $i = 0; $i <= $#sorted && $sorted[$i] <= $q95; $i++){
	$s95 += $sorted[$i];
    }
    $s95stats->add_data($s95);
    $s95array[$c] = $s95;
    $q95array[$c] = $q95;
    print NORMOUT "$headers[$c]\t", $colstat->count(), "\t$q95\t$s95\n";
  #  last;
}

close NORMOUT;
# Now we normalize everything by the median S95.

my @normarray = ();  # output array - normalized
my @normhead = ();   # output headers (may lose samples)
#my $medS95 = $s95stats->median();

my $curcol = 1;
for (my $c = 1; $c <= $#headers; $c++){
    if (! defined $s95array[$c]){next;} # skip samples with too few features
    my $rowsum = 0;
    for (my $row = 0; $row <= $#dataarray; $row++){
	$rowsum += $dataarray[$row][$c];
	$normarray[$row][$curcol] = $dataarray[$row][$c] * $scale/ $s95array[$c];   # normalization: value * median s95 / column s95
	if ($OMITLOW == 1 && $dataarray[$row][$c] < $q95array[$c]){
	    $normarray[$row][$curcol] = 0;
	}
	if ($TOINT == 1){
	    $normarray[$row][$curcol] = POSIX::floor($normarray[$row][$curcol] + 0.5);  # rounds to nearest integer
	}
	$normhead[$curcol] = $headers[$c];
    }
    $curcol++;
}

# Now the current array should have all the proper values.
# One more test - get rid of all rows that have only zeroes.

# print header
print OUT join("\t", @normhead), "\n";

for (my $row = 0; $row <= $#dataarray; $row++){
    my $empty = 1;
    for (my $c = 1; $c <= $#normhead; $c++) {
	if ($normarray[$row][$c] != 0){
	    $empty = 0; 
	}
    }
    if ($empty == 1){next;} # skip row
    print OUT $dataarray[$row][0]; # print OTU name;
    for (my $c = 1; $c <= $#normhead; $c++){
	if ($TOINT == 1) {
	    print OUT "\t", sprintf("%d", $normarray[$row][$c]);
	} else {
	    print OUT "\t", sprintf("%.2f", $normarray[$row][$c]);
	}
    }
    print OUT "\n";
}

close(OUT);
exit(0);
