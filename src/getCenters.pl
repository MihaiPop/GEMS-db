#!/usr/bin/perl

use strict;

my $VERSION = ' $Id: getCenters.pl,v 1.3 2012/06/28 00:13:31 mpop Exp $ ';

# Takes in a mapping from OTU Id to center and taxonomy information and a 
# fasta file of cluster centers, as well as a potential list of OTUs to be
# selected and outputs a new cluster center fasta file and taxonomy information
# for only the selected OTUs.


use Getopt::Long;
use ParseTab;
use Bio::SeqIO;

my $version = undef;
my $help = undef;
my $centers = undef;
my $otutax = undef;
my $select = undef;
my $prefix = undef;
my $useotu = undef;

my $result = GetOptions(
	"version" => \$version,
	"help" => \$help,
	"centers=s" => \$centers,
	"taxinfo=s" => \$otutax,
	"select=s" => \$select,
	"prefix=s" => \$prefix,
        "otuid" => \$useotu
);

if (defined $version){
	die ($VERSION . "\n");
}

if (defined $help
    || ! defined $result
    || ! defined $centers
    || ! defined $otutax
    || ! defined $prefix){
   die ("Usage: getCenters.pl --centers file.fa --taxinfo file.otutax.csv --prefix pref [--select sel.csv] [--otuid]\n" .
	"       file.fa - fasta file of OTU centers\n" . 
	"       file.otutax.csv - mapping from OTU ID to name of center sequence and taxonomy information\n" .
	"       pref - prefix of output files which will be named: pref.centers.fa, pref.otutax.csv\n" .
	"       sel.csv - optional file selecting a subset of OTUs. Must contain at column named OTU ID\n" .
        "       --otuid - use OTU id instead of center ID in output file\n");
}

my %sel;
if (defined $select){
	open(SEL, $select) || die ("Cannot open $select: $!\n");
	my $psel = new ParseTab(\*SEL);
	while (my $data = $psel->getRecord()){
		if (exists $$data{"OTU ID"}){
			$sel{$$data{"OTU ID"}} = 1;
		}
	}
	close(SEL);
}

my %centers;
my %ids;
open(OUTTAX, ">$prefix.otutax.csv") || die ("Cannot open $prefix.otutax.csv: $!\n");
open(TAX, $otutax) || die ("Cannot open $otutax: $!\n");
my $ptax = new ParseTab(\*TAX);
my @head = @{$ptax->getNameArray()};
print OUTTAX join("\t", @head), "\n";
while (my $data = $ptax->getRecord()){
	if (defined $select && ! exists $sel{$$data{"OTU ID"}}){
		next; # skip unselected OTUs
	}	
	print OUTTAX $$data{$head[0]};
	for (my $i = 1; $i <= $#head; $i++){
		print OUTTAX "\t", $$data{$head[$i]};
	}
	print OUTTAX "\n";
	$centers{$$data{"Center"}} = 1;
	$ids{$$data{"Center"}} = $$data{"OTU ID"};
}
close(OUTTTAX);
close(TAX);

my $incenters = Bio::SeqIO->new(-file=>$centers, -format=>'fasta');
my $outcenters = Bio::SeqIO->new(-file=>">$prefix.centers.fna", -format=>'fasta');
while (my $seq = $incenters->next_seq){
    if (exists $centers{$seq->id()}){
	my $seqid = $seq->id();
	if (defined $useotu) {
	    $seq->display_id($ids{$seqid});
	}
	$outcenters->write_seq($seq);
    }
}
$incenters->close();
$outcenters->close();
