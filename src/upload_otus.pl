#!/usr/bin/perl

use DBI;
use ParseTab;
use XML::Parser;
use Term::ReadKey;

my $host = undef;
my $db = undef;

my $IGNORESINGLES = 1; # should be command line param

print STDERR "Usage: upload_otus.pl run.part [good list]\n";

##### XML PARSER STUFF
my $level = 0; # level in XML tree
my %otu_sample = (); # number of seqs per otu & sample
my @otus; # number of sequences per OTU
my %otutax; # taxon id for each OTU
my %otuidx; # mapping from OTU name to index in @otus array
my %sampleidx; # mapping from sample name to index in @samples array
my @samples; # number of sequences per sample
my $currentotu; # current OTU
my $currenttag; # current tag
##### END XML PARSER STUFF

##### TAXONOMY STUFF

my $TAXDIR = "ncbi/taxonomy"; # where the NCBI taxonomy resides
my @levels = ("superkingdom", "phylum", "class", "order", "family", "genus", "species", "strain");

# taxonomy preprocessing
my %parents;    # parent of a node
my %nodename;   # name of a tax id
my %namenode;   # tax id for a name
my %ranks;      # rank for node
my %merged;     # merged sequences

# read taxonomy information
print STDERR "Parsing taxonomy database\n";
open(MERGED, "$TAXDIR/merged.dmp") || die ("Cannot open $TAXDIR/merged.dmp:$!\n");
while (<MERGED>){
    chomp;
    my @fields = split('\|', $_);
    my $me = $fields[0]; $me =~ s/\s//g;
    my $parent = $fields[1]; $parent =~ s/\s//g;
    $merged{$me} = $parent;
}
close(MERGED);

open(NODES, "$TAXDIR/nodes.dmp") || die ("Cannot open $TAXDIR/nodes.dmp:$!\n");

while (<NODES>){
    chomp;
    my @fields = split('\|', $_);
    my $me = $fields[0]; $me =~ s/\s//g;
    my $parent = $fields[1]; $parent =~ s/\s//g;
    my $rank = $fields[2]; $rank =~ s/\s//g;
    $parents{$me} = $parent;
    $ranks{$me} = $rank;
#    $children{$parent} .= "$me ";
}
close(NODES);


open(NAMES, "$TAXDIR/names.dmp") || die ("Cannot open $TAXDIR/names.dmp:$!\n");
while (<NAMES>){
    chomp;
    my @fields = split('\|', $_);
    
    my $sname = $fields[3];  $sname =~ s/^\s*//; $sname =~ s/\s*$//;
    my $id = $fields[0];  $id =~ s/\s//g;
    my $name = $fields[1];   $name =~ s/^\s*//; $name =~ s/\s*$//;
    if ($sname eq "scientific name"){
        $nodename{$id} = $name;
    }
    $namenode{$name} = $id;
}
close(NAMES);

print STDERR "Done reading taxonomy DB\n";


##### END TAXONOMY STUFF

# the good otu file has a header line
# followed by one line per good OTU
my %good_otus = ();
if (defined $ARGV[1]){
    open (GOOD, $ARGV[1]) || die ("Cannot load good otu file: $!\n");
    <GOOD>; # skip header
    while (<GOOD>){
	chomp;
	my @fields = split('\t', $_);
	$good_otus{$fields[0]} = 1;
    }
    close(GOOD);
}

my $infile = $ARGV[0];
open(IN, $infile) || die ("Cannot open $infile: $!\n");
my $mp = new ParseTab(\*IN);

my $uname = undef; 
my $pass = undef;

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

# connect to DB
my $dbh = DBI->connect("dbi:mysql:host=$host;database=$db;", $uname, $pass);
die("User $uname cannot connect to database\n") unless defined $dbh;
$dbh->do("use gems;");

my %pref2name = ();

my $query = "select gems.454.file_num, gems.454.sample_id from gems.454;";
my $sth = $dbh->prepare($query) || die ("Could not prepare $query: $dbh->errstr");
$sth->execute() || die ("Could not execute $query: $dbh->errstr");
while (my @data = $sth->fetchrow_array()){
    if ($data[0] != 0){$pref2name{$data[0]} = $data[1];}
}

# I want to keep track of:
# taxid, sampleid,  #otus, #sequences
my %sampleotus = ();
my %sampleseqs = ();

my @taxids = ();
my %taxids = ();

#open(PART, $ARGV[0]) || die ("Cannot open $ARGV[0]:$!\n");
my $xml = new XML::Parser(Style => 'Stream');
$xml->setHandlers(Start => \&StartTag);
$xml->parsefile($ARGV[0]); # all the work happens here

# at this point %otu_sample contains # seqs for each pair of OTU and sample
while (my ($name, $count) = each %otu_sample){
    my ($otu, $sample) = split(' ', $name);
    if (defined $ARGV[1] && ! exists $good_otus{$otu}) {next;} # skip bad otus
    elsif ($IGNORESINGLES == 1 && $otus[$otu] <= 1) {next;} # skip singleton otus
    if ($otu ne "" && $sample ne ""){
	my $taxid = $otutax{$otu};
	my $taxname;
	if (int($taxid) == 0){
	    $taxid = 'NULL';
	    $taxname = 'NULL';
	} else {
	    $taxname = getFullTaxonomy($taxid);
	}
	$taxname =~ s/\'//g;
	my $query = "insert into gems.OTU (otu_id, sample_id, num_seq, taxid, taxname) values ($otu, $sample, $count, $taxid, \'$taxname\');";
	my $sth = $dbh->prepare($query) ||
	    die ("Could not prepare $query: $dbh->errstr");
	$sth->execute() || die ("Could not execute $query: $dbh->errstr");
    }
}
exit(0);

##### XML stuff
sub StartDocument
{
    print STDERR "start parsing\n";
}

sub EndDocument
{
    print STDERR "end parsing\n";
}

sub StartTag
{
    my ($expat, $tag, %attrs) = @_;
    
    if (lc($tag) ne "part"){
	die ("Found unknown tag: $tag\n");
    }
    #allowed tags - PART

    $currenttag = lc($tag);
    ++$level;
    $currentotu = $attrs{"NAME"};
    if (exists $attrs{"TAXID"}){
	$otutax{$currentotu} = $attrs{"TAXID"};
	$taxids{$attrs{"TAXID"}} = 1;
#	print "GOT TAXID ", $attrs{"TAXID"}, "\n";
    } else {
	$taxids{"nomatch"} = 1;
	$otutax{$currentotu} = "nomatch";
    }
# update list of OTUs I know about
    push @otus, 0;
    $otuidx{$currentotu} = $#otus;
}

sub EndTag
{
    --$level;
    $currentotu = undef;
    $currenttag = undef;
    # end of partition
}

sub Text
{
    if ($level == 2 && defined $currenttag && $currenttag eq "part") {
	my @names = split(/\s+/, $_);
	for (my $i = 0; $i <= $#names; $i++){
	    if ($names [$i] ne ""){
		++$otus[$otuidx{$currentotu}]; # add a new sequence to current OTU
		# find the sample the sequence belongs to
		my ($file, $idx) = split('_', $names[$i]);
		my $sam = $pref2name{$file};
		if (! defined $sam) {die ("Can't find sample for index $file, sequence $names[$i]\n");}
		if (! exists $sampleidx{$sam}){
		    push @samples, 0;
		    $sampleidx{$sam} = $#samples;
		}
		++$samples[$sampleidx{$sam}]; # add to count of sequences for this sample
		++$otu_sample{"${currentotu} ${sam}"}; # add to count of sequences shared by otu and sample
	    }
	}
    }
}

sub pi
{

}


##### TAXONOMY STUFF
# should eventually be a library

# get full taxonomy representation for node
sub getFullTaxonomy()
{
    my $id = shift;

    if (exists $merged{$id}){$id = $merged{$id};}
    
    my $taxonomy = "";
    while ($id != 1){
#	if (! exists $nodename{$id}){
#	    print STDERR "No name for $id\n";
#	    $id = 2;
#	}
        die ("No name for $id\n") unless exists $nodename{$id};
        $taxonomy = ";$nodename{$id}" . $taxonomy;
        die ("No parent for $id\n") unless exists $parents{$id};
        $id = $parents{$id};
    }
    return $taxonomy;
}

# get name of chosen taxonomic level
sub getLevelName()
{
    my $id = shift;
    my $level = shift;

    if (exists $merged{$id}) {$id = $merged{$id};}

    do {
        die ("No rank for $id\n") unless exists $ranks{$id};
        if ($ranks{$id} eq $level) {
#	if (! exists $nodename{$id}){
#	    print STDERR "No name for $id\n";
#	    $id = 2;
#	}
            die ("No name for $id\n") unless exists $nodename{$id};
            return $nodename{$id};
        }
        die ("No parent for $id\n") unless exists $parents{$id};
        $id = $parents{$id};
    } until ($id == 1);
    return undef;
}

# get taxid of chosen taxonomic level
sub getLevelId()
{
    my $id = shift;
    my $level = shift;

    if (exists $merged{$id}) {$id = $merged{$id};}

    do {
        die ("No rank for $id\n") unless exists $ranks{$id};
#	if ($level eq "kingdom"){
#	    print STDERR "$id:$level:$ranks{$id}\n";
#	}
        if ($ranks{$id} eq $level) {
            return $id;
        }
        die ("No parent for $id\n") unless exists $parents{$id};
        $id = $parents{$id};
    } until ($id == 1);
    return undef;
}


##### END TAXONOMY STUFF
