#!/usr/bin/perl

use strict;

my $VERSION = ' $Id: taxpart2summary-db.pl,v 1.21 2012/06/28 00:13:31 mpop Exp $ ';

# this program uses the NCBI taxonomy information together with blast
# output against RDP (or other database) to assign a taxonomy to a set of OTUs

use ParseTab;
use ParseTaxonomy;
use XML::Parser;
use Term::ReadKey;
use DBI;
use Getopt::Long;

# Taxonomy levels we'll use.
my @levels = ("superkingdom", "phylum", "class", "order", "family", "genus", "species", "strain");


my $TAXDIR = "ncbi/taxonomy"; # where the NCBI taxonomy resides
my $help = undef;
my $version = undef;
my $prefix = undef;
my $norm = undef;
my $host = undef;
my $mysql = 1;
my $postgres = undef;
my $db = undef;
my $taxInfoFile = undef;
my $otuCounts = undef;
my $otuFilter = undef;
my $query = undef;
my $queryfile = undef;

my $result = GetOptions(
    "help" => \$help,
    "version" => \$version,
    "norm" => \$norm,
    "host=s" => \$host,
    "mysql" => \$mysql,
    "postgres" => \$postgres,
    "db=s" => \$db,
    "taxdb=s" => \$TAXDIR,
    "prefix=s" => \$prefix,
    "otutable=s" => \$otuCounts,
    "otutaxinfo=s" => \$taxInfoFile,
    "filter=s" => \$otuFilter,
    "query=s" => \$query,
    "queryfile=s" => \$queryfile
    );

if (defined $version){
    die ($VERSION . "\n");
}

if (! defined $result 
    || defined $help
    || ! defined $prefix
    || (defined $otuCounts && ! defined $taxInfoFile)
    || (defined $taxInfoFile && ! defined $otuCounts)
    ) {
    die ("Usage: taxpart2summary-db.pl --prefix name [--norm]\n" .
	 "       outputs a series of files name.<taxlevel>.csv\n" .
	 "\n" .
	 "       Database host, type, and database can be specified with options: \n" .
	 "       --host, --mysql, --postgres, --db, respectively\n\n" .
	 "       Directory containing taxonomy database can be specified\ with option: \n" .
	 "       --taxdb\n" .
	 "\n\n" .
	 "       Alternatively, options --otutable, --otutaxinfo, --filter allow\n" .
	 "       the user to specify the otu counts within each sample [--otutable]\n" .
	 "       otu taxonomy information [--otutaxinfo] and list of good otus [--filter]\n" .
	 "       Only OTUs listed in the good list will be reported\n" .
	 "\n      If --query is provided it must return exactly 4 columns in the order:\n" .
	 "           1 - otu id\n" .
	 "           2 - sample id\n" . 
	 "           3 - num sequences\n" .
	 "           4 - taxonomy id\n" .
	 "        Alternatively query can be retrieved from file specified with --queryfile\n"
	);
}


# Read query from file
if (defined $queryfile){
    $query = "";
    open(QF, $queryfile) || die("Cannot open $queryfile: $!\n");
    while (<QF>){
	$query .= $_;
    }
    close(QF);
}


# Read username and password if using a database
my $uname = undef; 
my $pass = undef;

if (! defined $otuCounts) {
    print "User ($ENV{USER}): ";
    $uname = ReadLine 0;
    chomp $uname;
    if ($uname =~ /^\s*$/){
	$uname = $ENV{USER};
    }
    print "Password: ";
    ReadMode 'noecho';
    $pass = ReadLine 0;
    chomp $pass;
    ReadMode 'normal';
    print "\n";
}

my $type = "mysql";
if (defined $mysql){
    $postgres = undef;
    $type = "mysql";
} 
if (defined $postgres){
    $mysql = undef;
    $type = "postgres";
}

# connect to DB
my $dbh;
if (! defined $otuCounts){
    $dbh = DBI->connect("dbi:$type:host=$host;database=$db;", $uname, $pass);
    die("User $uname cannot connect to database\n") unless defined $dbh;
    $dbh->do("use $db;");
}

my $pt = new ParseTaxonomy($TAXDIR);

## MAIN

my %otu_sample = (); # number of seqs per otu & sample
my @otus; # number of sequences per OTU
my %otutax; # taxon id for each OTU
my %otuidx; # mapping from OTU name to index in @otus array
my %sampleidx; # mapping from sample name to index in @samples array
my @samples; # number of sequences per sample
my %sampleotus = (); # 
my %sampleseqs = (); #

my @taxids = (); # keys of %taxids 
my %taxids = (); #

print STDERR "Reading from file $otuCounts\n";
my %good_otus = undef;
# read OTU filter if one exists
if (defined $otuFilter){
    print STDERR "got filter $otuFilter\n";
    open(FILT, $otuFilter) || die ("Cannot open $otuFilter: $!\n");
    my $fp = new ParseTab(\*FILT);
    %good_otus = ();
    while (my $data = $fp->getRecord()){
	$good_otus{$$data{"OTU ID"}} = 1;
    }
    close(FILT);
}



# Get OTU information from database
if (! defined $query && defined $norm){
    $query = "select otu_id, sample_id, norm_num_seq, taxid from OTU_old;";
} elsif (! defined $query) {
    $query = "select otu_id, sample_id, num_seq, taxid from OTU_old;";
}    

my $sth;
if (! defined $otuCounts){
    print STDERR "Reading from database $db on server $host\n";
    $sth = $dbh->prepare($query) || die ("Could not prepare $query: $dbh->errstr");
    $sth->execute() || die ("Could not execute $query: $dbh->errstr");


    while (my @data = $sth->fetchrow_array()){
	my $otu_id = $data[0];
	my $sam_id = $data[1];
	my $num_seq = $data[2];
	my $tax_id = $data[3];

	if (defined $otuFilter && ! exists $good_otus{$otu_id}){next;}
	if (! defined $tax_id || $tax_id eq "NULL"){
	    $tax_id = "OTU_" . $otu_id;
	}
	
	$taxids{$tax_id} = 1;
	
	if (! exists $otuidx{$otu_id}){
	    push @otus, $num_seq;
	    $otuidx{$otu_id} = $#otus;
	} else {
	    $otus[$otuidx{$otu_id}] += $num_seq;
	}
	if (! exists $sampleidx{$sam_id}){
	    push @samples, $num_seq;
	    $sampleidx{$sam_id} = $#samples;
	} else {
	    $samples[$sampleidx{$sam_id}] += $num_seq;
	}
	$otutax{$otu_id} = $tax_id;
	$otu_sample{"$otu_id $sam_id"} = $num_seq;
    }
} else { # read data from file instead of DB
    # read taxonomy file
    open(TAXIFO, $taxInfoFile) || die ("Cannot open $taxInfoFile: $!\n");
    my $pt = new ParseTab(\*TAXIFO);
    while (my $data = $pt->getRecord()){
	if (defined $otuFilter && ! exists $good_otus{$$data{"OTU ID"}}){
#	    print STDERR "Skipping\n";
	    next; # skip OTUs we don't care about
	}
#	print STDERR "Got taxonomy for ", $$data{"OTU ID"}, "\n";
	my $tax_id = $$data{"NCBI ID"};
	if ($tax_id eq "NULL"){$tax_id = "OTU_" . $$data{"OTU ID"};}
	$taxids{$tax_id} = 1;
	$otutax{$$data{"OTU ID"}} = $tax_id;
    }
    close(TAXIFO);
    
# read otu table    
    open(OTUTAB, $otuCounts) || die ("Cannot open $otuCounts: $!\n");
    my $cp = new ParseTab(\*OTUTAB);
    my @sampleNames = @{$cp->getNameArray()};
    while (my $data = $cp->getRecord()){
	my $otu_id = $$data{$sampleNames[0]}; # OTU ID is first column
	if (defined $otuFilter && ! exists $good_otus{$otu_id}){
	    next; # skip OTUs we don't care about
	}
#	print STDERR "Got OTU ID $otu_id\n";
	for (my $i = 1; $i <= $#sampleNames; $i++){
	    my $sam_id = $sampleNames[$i];
	    my $num_seq = $$data{$sampleNames[$i]};
	    
	    if (! exists $otuidx{$otu_id}){
		push @otus, $num_seq;
		$otuidx{$otu_id} = $#otus;
	    } else {
		$otus[$otuidx{$otu_id}] += $num_seq;
	    }
	    if (! exists $sampleidx{$sam_id}){
		push @samples, $num_seq;
		$sampleidx{$sam_id} = $#samples;
	    } else {
		$samples[$sampleidx{$sam_id}] += $num_seq;
	    }
	    $otu_sample{"$otu_id $sam_id"} = $num_seq;
	}
    }
}

# at this point we have
# @samples contains # of sequences for each sample found in the input file
# @otus contains # of sequences for each otu found in the input file
# %otu_sample contains # of sequences shared by all pairs of otus and samples

# now we just need to generate reports

my $numseq = 0;
my $singles = 0;
for (my $i = 0; $i <= $#otus; $i++){
    if ($otus[$i] == 1) {$singles++;}
    $numseq += $otus[$i];
}

my $retest = 0;
for (my $i = 0; $i <= $#samples; $i++){
    $retest += $samples[$i];
}

if ($retest != $numseq) { 
    print STDERR "WARNING: different # of sequences in samples ($retest) than in OTUs ($numseq) - should be the same\n";
}

@taxids = keys %taxids; # all the taxids in our file

open(TAXONOMY, ">$prefix.otus.taxonomy.csv") ||
    die ("Cannot open $prefix.otus.taxonomy.csv: $!\n");
open(BYOTU, ">$prefix.otus.count.csv") || 
    die ("Cannot open $prefix.otus.count.csv: $!\n");
open(QIIME, ">$prefix.otus.qiime.csv") || 
    die ("Cannot open $prefix.otus.qiime.csv: $!\n");
open(BYOTUPER, ">$prefix.otus.percent.csv") || 
    die ("Cannot open $prefix.otus.percent.csv: $!\n");

my @otunames = keys %otuidx; @otunames = sort {$a <=> $b} @otunames;
my @samplenames = keys %sampleidx; @samplenames = sort {$a <=> $b} @samplenames;

# print header
print TAXONOMY "OTU\tTaxonomy\t";
print TAXONOMY join("\t", @levels), "\n";
print BYOTU "OTU";
print QIIME "#Full OTU Counts\n#OTU ID";
print BYOTUPER "OTU";
for (my $i = 0; $i <= $#samplenames; $i++){
    print BYOTU "\t$samplenames[$i]";
    print QIIME "\t$samplenames[$i]";
    print BYOTUPER "\t$samplenames[$i]";
}
print BYOTU "\n";
print QIIME "\tConsensus Lineage\n";
print BYOTUPER "\n";

# for each OTU print the counts and fractions
for (my $i = 0; $i <= $#otunames; $i++){
    print BYOTU $otunames[$i];
    print QIIME $otunames[$i];
    print BYOTUPER $otunames[$i];
    print TAXONOMY $otunames[$i];
 
#    print BYOTU "\t", $otutax{$otunames[$i]} eq "nomatch"?"nomatch":$pt->getFullTaxonomy($otutax{$otunames[$i]});
#    print BYOTUPER "\t", $otutax{$otunames[$i]} eq "nomatch"?"nomatch":$pt->getFullTaxonomy($otutax{$otunames[$i]});
   for (my $j = 0; $j <= $#samplenames; $j++){
	my $num = $otu_sample{"$otunames[$i] $samplenames[$j]"}; # total number of sequences in otu in sample
	my $tot = $samples[$sampleidx{$samplenames[$j]}]; # total # of sequences in sample
	print BYOTU "\t", sprintf("%f", $num); 
	print QIIME "\t", sprintf("%d", int($num + 0.5)); # qiime expects integers
	print BYOTUPER "\t", $tot != 0 ? (100.0 * $num / $tot) : 0;
	if ($num != 0) {
	    ++$sampleotus{$otutax{$otunames[$i]}}{$samplenames[$j]};
	}
	$sampleseqs{$otutax{$otunames[$i]}}{$samplenames[$j]} += $num;
    }
    print QIIME "\t", ($otutax{$otunames[$i]} =~ /^OTU_/)?$otutax{$otunames[$i]}:$pt->getFullTaxonomy($otutax{$otunames[$i]}), "\n";
    print TAXONOMY  "\t", ($otutax{$otunames[$i]} =~ /^OTU_/)?$otutax{$otunames[$i]}:$pt->getFullTaxonomy($otutax{$otunames[$i]});
    for (my $lev = 0; $lev <= $#levels; $lev++){
	my $id = $pt->getLevelName($otutax{$otunames[$i]}, $levels[$lev]);
	if (defined $id) {
	    print TAXONOMY "\t", $id;
	} else {
	    print TAXONOMY "\tNA";
	}
    }
    print TAXONOMY "\n";
    print BYOTU "\n";
    print BYOTUPER "\n";
}

close(BYOTU);
close(QIIME);
close(BYOTUPER);
close(TAXONOMY);

my %lastlevel = (); # record last valid taxonomic level for each id

## Now it's time to print
my $cur = $#levels; # current taxonomic level
while ($cur > 0){
    open(OUT, ">$prefix.$levels[$cur].count.csv") || die ("Cannot open $prefix.$levels[$cur].count.csv:$!\n");
    
    # same info as in sampleotus just at current level
    my %taxotu = ();
    my %taxseq = ();
    my %tax = ();
    my %tax2id = ();

    for (my $ti = 0; $ti <= $#taxids; $ti++){
	my $id;
	if ($levels[$cur] eq "strain" || 
	    $taxids[$ti] =~ /^OTU_/){
	    $id = $taxids[$ti];
	} else {
	    $id = $pt->getLevelId($taxids[$ti], $levels[$cur]);
	    if (! defined $id){
		print STDERR "Cannot find $levels[$cur] for $taxids[$ti]\n";
		if (defined $lastlevel{$taxids[$ti]}){
		    $id = $pt->getLevelId($taxids[$ti], $lastlevel{$taxids[$ti]});
		} else {
		    $id = $taxids[$ti];
		}
	    } else {
		$lastlevel{$taxids[$ti]} = $levels[$cur];
	    }
	}

	if ($id eq "unknown" || $id eq "nomatch" || $id =~ /^OTU_/){
	    $tax{$id} = $id;
	    $tax2id{$id} = $id;
	} else {
	    $tax{$id} = $pt->getFullTaxonomy($id);
	    $tax2id{$pt->getFullTaxonomy($id)} = $id;
	}

	for (my $f = 0; $f <= $#samplenames; $f++){
#	    $taxotu{$id}{$samplenames[$f]} += $sampleotus{$taxids[$ti]}{$samplenames[$f]};
	    $taxseq{$id}{$samplenames[$f]} += $sampleseqs{$taxids[$ti]}{$samplenames[$f]};
	}
    }

    my @tax = sort {$tax{$a} cmp $tax{$b}} keys %tax;

# header line

## Here we'll print all levels before it, one by one.
    print OUT "Full Taxonomy";
    for (my $i = 0; $i <= $cur; $i++){
	print OUT "\t$levels[$i]";
    }
    for (my $f = 0; $f <= $#samplenames; $f++){
	print OUT "\t$samplenames[$f]";
    }
    print OUT "\n";

    for (my $t = 0; $t <= $#tax; $t++){
	print OUT $tax{$tax[$t]}; # print taxonomy
	for (my $i = 0; $i <= $cur; $i++){
	    if (defined $pt->getLevelName($tax2id{$tax{$tax[$t]}}, $levels[$i])){
		print OUT "\t", $pt->getLevelName($tax2id{$tax{$tax[$t]}}, $levels[$i]);
	    } else {
		print OUT "\tNA";
	    }
	}
	for (my $f = 0; $f <= $#samplenames; $f++){
	    print OUT "\t", $taxseq{$tax[$t]}{$samplenames[$f]};
	}
	print OUT "\n";
    }

    close(OUT);
    $cur--;
}

exit(0);

