#!/usr/bin/perl

my $VERSION = ' $Id: upload_otutaxinfo.pl,v 1.3 2012/02/29 21:13:12 mpop Exp $ ';

use DBI;
use ParseTab;
use Term::ReadKey;
use Getopt::Long;


my $infile = undef;
my $help = undef;
my $version = undef;
my $db = undef;
my $mysql = 1;
my $postgres = undef;
my $host = undef;
my $good = undef;
my %goodOTUs = ();

my $result = GetOptions(
    "help" => \$help,
    "version" => \$version,
    "in=s" => \$infile,
    "host=s" => \$host,
    "db=s" => \$db,
    "mysql" => \$mysql,
    "postgres" => \$postgres,
    "goodlist=s" => \$good
    );

if (defined $version){
    die ($VERSION . "\n");
}

if (! defined $result
    || defined $help
    || ! defined $infile){
    die (
	"Usage: upload_otutaxinfo.pl --in otutax.info.csv \n" .
	"       [--db database] [--goodlist good.otus.list] \n" .
	"       uploads the information about OTUs found in otutax.info.csv\n" .
	"       into the database specified with option --db\n" .
	"       \n" . 
	"       if --goodlist option is used, only uploads otus in that list\n".
	"       \n" .
	"       Type of database can be selected with options --mysql or --postgres\n" .
	"       Database server can be selected with option --host\n"
	);
}

if (defined $mysql){
    $postgres = undef;
}

if (defined $postgres){
    $mysql = undef;
}

if (defined $good){
    open(GOOD, $good) || die ("Cannot open $good: $!\n");
    my $gp = new ParseTab(\*GOOD);
    while (my $data = $gp->getRecord()){
	$goodOTUs{$$data{"OTU ID"}} = 1;
    }
    close(GOOD);
}

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

my $dbtype = (defined $mysql) ? "mysql" : "postgres";

# connect to DB
my $dbh = DBI->connect("dbi:$dbtype:host=$host;database=$db;", $uname, $pass);
die("User $uname cannot connect to $dbtype database $db on host $host\n") unless defined $dbh;
$dbh->do("use $db;");

while (my $data = $mp->getRecord()){
    my $sample_id = $$data{"OTU ID"};
    if (defined $good && ! exists $goodOTUs{$sample_id}) {next;}
    if (! defined $sample_id || $sample_id eq ""){die ("Sample ID required\n");}
    if (int($sample_id) == 0 ){next;}
    my $query1 = "insert into $db.OTU_info (otu_id, ";
    my $query2 = ") values ($sample_id, ";
    my $query3 = "on duplicate key update ";

    if ($$data{"Center"} ne ""){
	$query1 .= "center_name, ";
	$query3 .= "center_name = \'$$data{Center}\', ";
	$query2 .= "\'$$data{Center}\', ";
    }
    if ($$data{"NCBI ID"} ne "" && $$data{"NCBI ID"} ne "NULL"){
	$query1 .= "taxid, ";
	$query2 .= $$data{"NCBI ID"} . ", ";
	$query3 .= "taxid = ". $$data{"NCBI ID"} . ", ";
    }
    if ($$data{"NCBI taxonomy"} ne "" && $$data{"NCBI taxonomy"} ne "NULL"){
	my $tax = $$data{"NCBI taxonomy"};
	$tax =~ s/'/\\'/g;
	$query1 .= "taxname, ";
	$query2 .= "\'" . $tax . "\', ";
	$query3 .= "taxname = \'" . $tax . "\', ";
    }
    if ($$data{"DB ID"} ne "" && $$data{"DB ID"} ne "NULL"){
	$query1 .= "refid, ";
	$query2 .= "\'" . $$data{"DB ID"} . "\', ";
	$query3 .= "refid = \'" . $$data{"DB ID"} . "\', ";
    }
    if ($$data{"DB taxonomy"} ne "" && $$data{"DB taxonomy"} ne "NULL"){
	my $tax = $$data{"DB taxonomy"};
	$tax =~ s/'/\\'/g;
	$query1 .= "ref_taxname";
	$query2 .= "\'" . $tax . "\'";
	$query3 .= "ref_taxname = \'" . $tax . "\'";
    }
#    $query = $query1 . " where otu_id = $sample_id;" ;
    $query = $query1 . $query2 . ")" . $query3 . ";";
    print STDERR "executing $query\n";
#    exit(0);
    my $sth = $dbh->prepare($query) ||
	die ("Could not prepare $query: $dbh->errstr");
    $sth->execute() || die ("Could not execute $query: $dbh->errstr");
}
exit(0);
