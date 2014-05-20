#!/usr/bin/perl

my $VERSION = ' $Id: qc_check.pl,v 1.5 2013/10/21 13:51:39 mpop Exp $ ';

####
#
# Change the following line to point to location of Perl libraries
#
####

use Bio::Seq;
use Bio::SeqIO;
use ParseTab;
use Getopt::Long;

my $DUST = "mdust ";
my $DUSTPAR = "-c -v 15";

# minimum cycles to accept a sequence
# 75 for 454 FLX
my $CYCLES = 75;

# kmer/barcode length
# will be set when reading barcode file
my $KMER = undef;

my $prefix = undef;
my $infile = undef;
my $help = undef;
my $version = undef;
my $nodust = undef;

my $result = GetOptions(
    "in=s" => \$infile,
    "help" => \$help,
    "version" => \$version,
    "mincycles=s" => \$CYCLES,
    "prefix=s" => \$prefix,
    "nodust" => \$nodust
    );

if (defined $version){
    die ($VERSION . "\n");
}

if (! defined $result 
    || defined $help 
    || ! defined $infile){
    die ("Usage: qc_check.pl --nodust --in file.fa [--prefix name] [--mincycles cycles]\n" .
	 "       Outputs will be \n " .
	 "           <name>.bad.list - a list of all sequences\n" .
	 "           that do not pass quality controls\n" .
	 "           <name>.fa - a fasta file containing all good sequences\n" .
	 "\n" .
	 "       The quality checks are as follows:\n" .
	 "           - the sequence cannot have any ambiguity codes\n" .
	 "           - the sequence has to be longer than <cycles> [default 75]\n" .
	 "             flows of the 454 instrument\n" .
	 "           - the sequence cannot have any long homopolymers (>15bp)\n" .
	"           -nodust - skips low complexity check\n" .
	 "\n" .
	 "       Other options: --help, --version\n"
	);
}

my %barcodes = ();
my %files = ();
my $flow = "TACG";
#my $primer = $ARGV[2];

if (! defined $prefix) {$prefix = "UNNAMED";}

open(BAD, ">$prefix.BAD.list");

my %homopolymers;

if (! defined $nodust){
open(DUST, "$DUST $infile $DUSTPAR |") ||
    die ("Cannot run $DUST $infile $DUSTPAR\n");
while (<DUST>){
    chomp;
    my @fields = split(/\s+/, $_);
    $homopolymers{$fields[0]} = 1;
    print BAD $_ . "\tDUST\n";  # sequence has a homopolymer
}
close(DUST);
}

my $in = Bio::SeqIO->new(-file => $infile, 
			-format => 'fasta', 
                        -alphabet => 'dna');
if (! defined $in) { die("Cannot open $infile\n");}

my $out = Bio::SeqIO->new(-file => ">$prefix.fa", 
                          -format => 'fasta', 
                          -flush => 0);
if (! defined $out) { die("Cannot open $prefix.fa\n");}


while (my $seq = $in->next_seq()){

# here I get header and body information form the seq record
    $head = $seq->display_id();
    if (exists $homopolymers{$head}){next;} # sequence excluded

    $head =~ s/ .*$//;
    $data = uc($seq->seq());

    # If even one N - toss it out
    if (index($data, "N") >= 0){
	print BAD $head, "\t", substr($data, 0, 8), "\tHAS N\n";
	next;
    }
    
    # Count cycles
    my $ci = 0; 
    my $nc = 0;
    my $si = 0;
    while ($si < length($data)) {
	while (substr($data, $si, 1) ne substr($flow, $ci, 1)){
	    $ci++;
	    if ($ci > 3) {
		$ci = 0;
		$nc++;
	    }
	}
	$si++;
    }

    if ($nc < $CYCLES) {
	print BAD $head, "\t", $nc, "\tSHORT\n";
	next;
    }
    $out->write_seq($seq);
}
close BAD;
$in->close();
$out->close();

# done
exit(0);
