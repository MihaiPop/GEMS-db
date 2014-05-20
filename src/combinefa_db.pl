#!/usr/bin/perl


use ParseTab;
use DBI;
use AMOS::ParseFasta;
use Getopt::Long;
use Term::ReadKey;

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

print STDERR "Usage: combinefa.pl [-c code] [-sel sel.list] dir\n";
print STDERR "file[n] can contain globs but they must be escaped\n";
print STDERR "sel.list contains an optional list of filenames (SQL globs \n";
print STDERR "are allowed) that should be included.  If not provided all\n";
print STDERR "files in the database will be combined\n";
print STDERR "dir is the parent directory for the filenames found in database\n";
print STDERR "code is the name of the output file - automatically generated if not provided\n";

my $database;
my $server;
my $uname;
my $pass;

my $code = undef;
my $list = undef;

my $result = GetOptions("c=s" => \$code,
                        "sel=s" => \$list);

if (! $result) {die("Cannot parse input\n");}
my $dir = $ARGV[0]; # the only unaccounted option


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
my $dbh = DBI->connect("dbi:mysql:host=$server;database=$database;", $uname, $pass);
die("User $uname cannot connect to database\n") unless defined $dbh;
$dbh->do("use gems;");



if (! defined $code) {
	$code =  sprintf("%06d", int(rand(1000000))); 
}

print STDERR "Code is $code\n";
print STDERR "Fasta file: $code.fna\n";
print STDERR "Restrict to files in: $list\n" unless (! defined $list);

my $fastafn = "$code.fna";

my $startnum = 0;
my $filenum = 0;  # which file we're processing
my $seqnum = 0; # which sequence we're processing

# parse index file to build hash from file names to numbers, and assign
# new numbers if necessary
open(OUT, ">$fastafn") || die ("Cannot open $fastafn: $!\n");


my $query = "select filename, file_num from gems.454";
if (defined $list) {
    $query .= " where ";
    open (LIST, $list) || die ("Cannot open $list: $!\n");
    my $first = 0;
    while (<LIST>){
	my $fn = $_;
	chomp $fn;
	if ($first != 0){
	    $query .= "or ";
	}
	$first = 1;
	
	$query .= "filename like \'%$fn\' ";
    }
    close(LIST);
}
$query .= ";";

my $sth = $dbh->prepare($query) || die ("Could not prepare $query: $dbh->errstr");
$sth->execute() || die ("Could not execute $query: $dbh->errstr");


while (my @data = $sth->fetchrow_array()){
    if ($data[0] =~ /^\s*$/){
	next;
    } # no need to look at record with no filename
    if (int($data[1]) == 0){
	print STDERR "File $data[1] has no number ??\n";
	next;
    }
    my $seqnum = 0;
    my $filenum = $data[1];
    open(IN, "$dir/$data[0]") || die ("Cannot open $dir/$data[0]");
    my $pf = new AMOS::ParseFasta(\*IN, '>', "\n");
    while (my ($head, $data) = $pf->getRecord()) {
	++$seqnum;
	my $newid = "${filenum}_${seqnum}";
	print OUT ">$newid\n";
	print OUT $data;
    }
    close(IN);
}

close(OUT);

exit(0);
