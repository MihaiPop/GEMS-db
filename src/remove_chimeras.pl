#!/usr/bin/perl

use strict;
my $VERSION = ' $Id: remove_chimeras.pl,v 1.1 2013/10/23 14:45:13 mpop Exp $ ';

## Program that subsets a otustats file based on chimera info from uchime

use Getopt::Long;
use Text::CSV;

my $version = undef;
my $help = undef;
my $otustats = undef;
my $prefix = undef;
my $chimeras = undef;

my $result = GetOptions(
    "version" => \$version,
    "help" => \$help,
    "chimeras=s" => \$chimeras,
    "otustats=s" => \$otustats,
    "prefix=s" => \$prefix
    );

if (defined $version){
    die ($VERSION . "\n");
}    
if (defined $help
    || ! defined $result
    || ! defined $chimeras
    || ! defined $otustats
    || ! defined $prefix){
    die ("Usage: remove_chimeras.pl --chimeras file.uchime.out --otustats file.otustats.csv --prefix pref\n" .
	 "       file.uchime.out - output from uchime\n" . 
	 "       file.otustats.csv - mapping from center names to # of sequences\n" .
	 "       pref - prefix of output files which will be named: pref.otustats.csv\n" .
	 "");
}

my %remove = (); # centers to be removed
# uchime
open(UCHIME, $chimeras) || die ("Cannot open $chimeras: $!\n");
while (<UCHIME>){
    chomp;
    my @fields = split('\t', $_);
    if ($fields[$#fields] eq 'Y'){
	my $name = $fields[1];
	$name =~ s/\/.*//; # remove abundance info
	$remove{$name} = 1;
    }
}
close(UCHIME);

open(OUT, ">$prefix.otustats.csv") || die ("Cannot open $prefix.otustats.csv: $!\n");

# otutstats
my %num_seq = (); # number of seqs for each center
my $stats = Text::CSV->new({sep_char => "\t"});
open(STAT, $otustats) || die("Cannot open $otustats: $!\n");
my $head = $stats->getline(\*STAT);
print OUT "OTU ID\tCenter\tSeq #\tSample #\n";
$stats->column_names($head);
while (my $data = $stats->getline_hr(\*STAT)){
    if (exists $remove{$$data{"Center"}}){next;} # skip chimeras
    print OUT $$data{"OTU ID"}, "\t";
    print OUT $$data{"Center"}, "\t";
    print OUT $$data{"Seq #"}, "\t";
    print OUT $$data{"Sample #"}, "\n";
}

close(OUT);
exit(0);
