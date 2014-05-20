#!/usr/bin/perl


use strict;
my $VERSION = ' $Id: add_file.pl,v 1.4 2012/05/15 16:50:37 mpop Exp $ ';


####
#
# Change the following line to point to location of Perl libraries
#
####

use ParseTab;
use Getopt::Long;

my $help = undef;
my $version = undef;
my $samplefile = undef;
my $dir = undef;


my $result = GetOptions(
    "help" => \$help,
    "version" => \$version,
    "dir=s" => \$dir,
    "index=s" => \$samplefile
    );

if (defined $version){
    die ($VERSION . "\n");
}

if (! defined $result 
    || defined $help
    || ! defined $dir
    || ! defined $samplefile
    ) {
    die ("Usage: add_file.pl --index sample_info.csv --dir dir > sample_info2.csv\n" .
	 "Takes in a .csv file describing a sequencing batch and adds\n" .
	 "information about the location of the files in dir.  Assumes each\n" .
	 "file name ends in SAMPLEID.clean.fa, where SAMPLEID is the id for the sample\n" . 
	 "\nThe input files must be tab-delimited, with a header line\n" .
	 "and contain the following columns:\n" .
	 "sample_info.csv - Sample ID\n" .
	 "\nThe output file will contain the same fields as sample info\n" .
	 "with the addition of a Filename and # seqs. column if one didnt exist\n");
}

my %sam2file;
my %sam2seqs;

opendir(DIR, $dir) || die("Cannot open $dir:$!\n");
while (my $fn = readdir(DIR)){
    if ($fn =~ /([^\.]+)\.clean.fa/){
	my $sam = $1;
	my $num = `grep -c '>' $dir/$fn`;
	chomp $num;
	$sam2file{$sam} = "$dir/$fn";
	$sam2seqs{$sam} = $num;
    }
}
close(DIR);

open(SAM, $samplefile) || die ("Cannot open $samplefile: $!\n");

my $sp = new ParseTab(\*SAM);

my @names = @{$sp->getNameArray()};
my $filefound = 0;
my $seqnofound = 0;
for (my $i = 0; $i <= $#names; $i++){
    if ($names[$i] eq "Filename"){$filefound=1;}
    if ($names[$i] eq "# seqs."){$seqnofound = 1;}
}

if ($filefound== 0) {
    push @names, "Filename";
}
if ($seqnofound == 0){
    push @names, "# seqs.";
}
print join("\t", @names), "\n";

while (my $data = $sp->getRecord()){
    if (! exists $$data{"Sample ID"} || $$data{"Sample ID"} =~ /^\s*$/) {
#	print "No sample\n";
	next;
    }
    my $sam = $$data{"Sample ID"};

    $$data{Filename} = $sam2file{$sam};
    $$data{"# seqs."} = $sam2seqs{$sam};
    delete $sam2file{$sam};

    print $$data{$names[0]};
    for (my $i = 1; $i <= $#names; $i++){
	print "\t", $$data{$names[$i]};
    }
    print "\n";
}
close(SAM);

# if any files whose barcodes were not in the sample file
while (my ($sam, $file) = each %sam2file){
    my %info = ();
    $info{"Sample ID"} = $sam;
    $info{"Filename"} = $sam2file{$sam};
    $info{"# seqs."} = $sam2seqs{$sam};
    print $info{$names[0]};
    for (my $i = 1; $i <= $#names; $i++){
	print "\t", $info{$names[$i]};
    }
    print "\n";
}

exit(0);

