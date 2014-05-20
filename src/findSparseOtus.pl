#!/usr/bin/perl

my $VERSION = ' $Id: findSparseOtus.pl,v 1.1 2012/03/06 21:35:27 mpop Exp $ ';

# Program reads an OTU count table and normalization info for each sample
# and outputs OTUs which exceeds the 95th quantile in at least one sample


use ParseTab;
use Getopt::Long;

my $help = undef;
my $version = undef;
my $counts = undef;
my $normfile = undef;
my $prefix = undef;

my $result = GetOptions(
	"help" => \$help,
	"version" => \$version,
	"counts=s" => \$counts,
	"norm=s" => \$normfile,
	"prefix=s" => \$prefix
);

if (defined $version){
	die ($VERSION . "\n");
}

if (defined $help
    || ! defined $result
    || ! defined $counts
    || ! defined $normfile
    || ! defined $prefix) {
	die ("Usage: findSparseOtus --count <file>.otus.count.csv --norm <file>.normalization.stats.csv --prefix <file>\n" .
             "     <file>.otus.count.csv - OTU count table.  Has 1 row per OTU and one column per sample\n" .
             "     <file>.normalization.stats.csv - table of normalization parameters.  Must have at least two columns labeled Sample ID and q95\n" .
             "     Output will be file named <file>.otus.abundant.list listing all OTUs that exceed q95 in at least one sample as well as the number of samples where this OTU is abundant\n"); 
}


my %q95;

open(NORM, $normfile) || die ("Cannot open $normfile: $!\n");
my $pnorm = new ParseTab(\*NORM);
while (my $data = $pnorm->getRecord()){
    $q95{$$data{"Sample ID"}} = $$data{"q95"};
}
close(NORM);

open(OUT, ">$prefix.otus.abundant.list") || die("Cannot open $prefix.otus.abundant.list: $!\n");
print OUT "OTU ID\t#samples\n";
open(COUNT, $counts) || die ("Cannot open $counts: $!\n");
my $pt = new ParseTab(\*COUNT);
my @namearray = @{$pt->getNameArray()};
while (my $data = $pt->getRecord()){
    my $otu = $$data{$namearray[0]};
    my $ok = 0;
    for (my $i = 1; $i <= $#namearray; $i++){
	if (! exists $q95{$namearray[$i]}){
	    print STDERR "Missing info on sample $namearray[$i]\n";
	    next;
	}
	if ($$data{$namearray[$i]} >= $q95{$namearray[$i]}){
	    $ok++;
	}
    }
    if ($ok > 0){
	print OUT $otu, "\t", $ok, "\n";
    }
}
close(COUNT);
