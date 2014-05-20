#!/usr/bin/perl

use strict;
my $VERSION = ' $Id: add_counts.pl,v 1.1 2013/10/21 13:52:08 mpop Exp $ ';

## Program that adds counts to the FASTA header lines
## for cluster centers based on 'otustats' file info

use Getopt::Long;
use Bio::SeqIO;
use Text::CSV;

my $version = undef;
my $help = undef;
my $centers = undef;
my $otustats = undef;
my $prefix = undef;

my $result = GetOptions(
    "version" => \$version,
    "help" => \$help,
    "centers=s" => \$centers,
    "otustats=s" => \$otustats,
    "prefix=s" => \$prefix
    );

if (defined $version){
    die ($VERSION . "\n");
    
    if (defined $help
	|| ! defined $result
	|| ! defined $centers
	|| ! defined $otustats
	|| ! defined $prefix){
	die ("Usage: add_counts.pl --centers file.fa --otustats file.otustats.csv --prefix pref\n" .
	     "       file.fa - fasta file of OTU centers\n" . 
	     "       file.otustats.csv - mapping from center names to # of sequences\n" .
	     "       pref - prefix of output files which will be named: pref.centers.fa, pref.otutax.csv\n" .
	     "");
    }
}

# otutstats
my %num_seq = (); # number of seqs for each center
my $stats = Text::CSV->new({sep_char => "\t"});
open(STAT, $otustats) || die("Cannot open $otustats: $!\n");
$stats->column_names($stats->getline(\*STAT));
while (my $data = $stats->getline_hr(\*STAT)){
    $num_seq{$$data{"Center"}} = $$data{'Seq #'};
}

# fasta file
my $in = Bio::SeqIO->new(-file=>$centers, -format=>'fasta');
my $out = Bio::SeqIO->new(-file=>">$prefix.centers.num.fna", -format=>'fasta');
while (my $seq = $in->next_seq){
    if (! exists($num_seq{$seq->id()})) {die ("Cannot find count for " . $seq->id() . " \n");}
    $seq->display_id($seq->id() . "/ab=" . $num_seq{$seq->id()});
    $out->write_seq($seq);
}
$in->close();
$out->close();
exit(0);
