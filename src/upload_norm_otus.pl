#!/usr/bin/perl

use DBI;
use ParseTab;
use XML::Parser;
use Term::ReadKey;

my $host = undef;
my $db = undef;

my $IGNORESINGLES = 1; # should be command line param

print STDERR "Usage: upload_norm_otus.pl norm.tsv goodlist\n Assumes norm.tsv has sample_ids as columns and OTUs as rows\n";
print STDERR " goodlist is a list of good OTUs - all others are excluded\n";

my %good_otus = ();
if (defined $ARGV[1]){
	open(GOOD, $ARGV[1]) || die ("Cannot load good otu file: $!\n");
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

my $query = "update gems.OTU set norm_num_seq=? where otu_id =? and sample_id =?;";
my $sth = $dbh->prepare($query) ||
    die ("Could not prepare $query: $dbh->errstr");

my @names = @{$mp->getNameArray()};
#print "Got names ", join(" ", @names), "\n";

while (my $data = $mp->getRecord()){
 #   print "Hello\n";
    my $otu = $$data{$names[0]}; 
    if (defined $ARGV[1] && ! exists $good_otus{$otu}){next;} # not a good OTU
    print STDERR "Updating otu $otu\n";
    for (my $i = 1; $i <= $#names; $i++){
	my $sample_id = $names[$i];
	my $normcnt = $$data{$sample_id};
#	print "Updating $sample_id $otu $normcnt\n";
	$sth->execute($normcnt, $otu, $sample_id) || die ("Could not execute $query: $dbh->errstr");
	#select(undef,undef,undef,0.1)
    }
}
exit(0);
