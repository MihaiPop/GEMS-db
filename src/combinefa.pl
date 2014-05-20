#!/usr/bin/perl

use strict; 

####
#
# Change the following line to point to location of Perl libraries
#
####

use Text::CSV;
use Bio::SeqIO;
use Getopt::Long;

my $VERSION  = ' $Id: combinefa.pl,v 1.3 2012/02/22 16:53:55 mpop Exp $ ';

# takes a series of fasta files and combines them into a single
# file that contains all the sequences.
# in the process it renames all sequences as:
#    <filenum>_<seqnum>
# and <filenum> represents the index of the file being processed and 
# <seqnum> represents the index of the sequence within the file.
# 
# This program also requires a tab-delimited file that contains a
# mapping between file names and sample ids 
#
# The output consists of:
#    <code>.fna - fasta file with all the sequences

my $prefix = undef;
my $index = undef;
my $dir = ".";
my $help = undef;
my $version = undef;
my $code = undef;

my $result = GetOptions("prefix:s" => \$code,
			"index=s" => \$index,
			"basedir:s" => \$dir,
			"help" => \$help,
			"version" => \$version
    );

if (defined $version) {
    die ($VERSION . "\n");
}

if (! $result || ! defined $index || defined $help) {
    die ("Usage: combinefa.pl [-prefix pref] -index index.csv -basedir dir\n" .
	 "       index.csv is a tab-delimited file that contains at least\n" .
	 "       the fields \"Sample ID\", \"Filename\", \"File \#\"\n" .
	 "       dir is the parent directory for the filenames found in index.csv [default .]\n" .
	 "       pref is the prefix of the output file - automatically generated if not provided\n"
	);
}

if (! defined $code) {
	$code =  sprintf("%06d", int(rand(1000000))); 
}

print STDERR "Prefix is $code\n";
print STDERR "Index is $index\n";
print STDERR "Fasta file: $code.fna\n";

my $fastafn = "$code.fna";

my $startnum = 0;
my $filenum = 0;  # which file we're processing
my $seqnum = 0; # which sequence we're processing

# parse index file to build hash from file names to numbers, and assign
# new numbers if necessary
my $out = Bio::SeqIO->new(-file => ">$fastafn", -format => 'fasta');

open(IDX, $index) || die ("Cannot open $index: $!\n");
my $pi = Text::CSV->new({sep_char=>"\t"});
$pi->column_names($pi->getline(\*IDX));

while (my $data = $pi->getline_hr(\*IDX)){
    if ($$data{"Filename"} =~ /^\s*$/){
	next;
    } # no need to look at record with no filename
    if (int($$data{"File \#"}) == 0){
	print STDERR "File $$data{Filename} has no number ??\n";
	next;
    }
    my $seqnum = 0;
    my $filenum = $$data{"File \#"};
    my $pf = Bio::SeqIO->new(-file => "$dir/$$data{Filename}", -format=> 'fasta' ); 
    while (my $seq = $pf->next_seq) {
	++$seqnum;
	my $newid = "${filenum}_${seqnum}";
	$seq->display_id($newid);
	$out->write_seq($seq);
    }
    $pf->close();

}
$out->close();
close(IDX);
close(OUT);

exit(0);
