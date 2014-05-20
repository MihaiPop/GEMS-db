#!/usr/bin/perl

use strict;

my $VERSION = ' $Id: uploadClinical.pl,v 1.2 2012/03/09 21:35:41 mpop Exp $ ';

my $DEBUG = undef;


use lib "/home/mpop/Work/Gates/Jan2012Freeze/GEMS_db/lib";

use ParseTab;
use Getopt::Long;
use DBI;
use Term::ReadKey;

my $version = undef;
my $help = undef;
my $meta = undef;
my $clinical = undef;
my $host = undef;
my $mysql = 1;
my $postgres = undef;
my $db = undef;

my $result = GetOptions(
    "version" => \$version,
    "help" => \$help,
    "meta=s" => \$meta,
    "clinical=s" => \$clinical,
    "db=s" => \$db,
    "mysql" => \$mysql,
    "postgres" => \$postgres
    );

if (defined $version){
    die ($VERSION . "\n");
}

if (defined $help
    || ! defined $result
    || ! defined $meta){
    die ("Usage: uploadClinical.pl --meta <file>.meta.csv --clinical <file>.clinical.csv\n" .
	 "       <file>.meta.csv - key for decoding mapping from clinical data to database fields \n" .
	 "       <file>.clinical.csv - clinical information\n");
}

open(META, $meta) || die ("Cannot open $meta: $!\n");
my $pt = new ParseTab(\*META);

my %tableFields = (); # mapping from table.field pair to clinical field(s)
my %values = ();      # mapping from clinical field to values stored.
my %applies = ();     # fields applies to case or control only
my %tables = ();      # list relevant database tables

while (my $data = $pt->getRecord()){
    if ($$data{"Auto"} ne "YES"){next;}  ## only care about some fields for now
    my $tbl = $$data{"Database table"};
    my $fld = $$data{"Database field"};
    my $clin = $$data{"GEMS field"};
    
    $tableFields{"$tbl.$fld"} .= "$clin;";
    $tables{$tbl} = 1;
    $values{$clin} = $$data{"Values"};
    $applies{$clin} = $$data{"Applies to"};
}
close(META);

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

my $dbType = "mysql";
if (defined $mysql){
    $postgres = undef;
    $dbType = "mysql";
} 
if (defined $postgres){
    $mysql = undef;
    $dbType = "postgres";
}

my $dbh = DBI->connect("dbi:$type:host=$host;database=$db;", $uname, $pass);
die("User $uname cannot connect to database\n") unless defined $dbh;
$dbh->do("use $db;");


# here we want to build a query of the form
# insert into TBL (field1, field2, ..., fieldn) values (val1, val2, ..., valn) 
# on duplicate key set field1 = val1, field2 = val2, ...
#
# We'll create three parts of the query:
# query1 has (field1, field2, ...)
# query2 has (val1, val2, ...)
# query3 has field1= val1, ...
#
# if a database field has more than one clinical field assigned to it
# and these disagree we'll output an error and take the first one for now

open(CLIN, $clinical) || die ("Cannot open $clinical: $!\n");
my $pc = new ParseTab(\*CLIN);
while (my $data = $pc->getRecord()){
    $tableFields{"Sample.id"} =~ s/;//g;
    $tableFields{"Sample.type"} =~ s/;//g;
    debug("id is " . $tableFields{"Sample.id"} . "\n");
    debug("type is " . $tableFields{"Sample.type"} . "\n");
    my $id = $$data{$tableFields{"Sample.id"}}; # get ID
    my $type = $$data{$tableFields{"Sample.type"}}; # get type of record

    debug("Got id $id and type $type\n");
    # create a separate query for each table
    foreach my $table (keys %tables){
	my @query1;
	my @query2;
	my @query3;
	if ($table ne "Sample"){
	    push @query1, "sample_id";
	    push @query2, $id;
	}

	my @myFields = grep(/^$table/, keys %tableFields);
	# Add each field separately to the table
	for (my $f = 0; $f <= $#myFields; $f++){
	    debug("doing $myFields[$f]\n");
	    debug("has value $tableFields{$myFields[$f]}\n");
	    my @fields = split(';', $tableFields{$myFields[$f]}); # get all clinical fields
	    # mapped to this DB field
	    my ($t, $field) = split('\.', $myFields[$f]);
	    debug("Table is $table field is $field\n");
	    # Check all fields have the same value

	    #TODO need to set values according to value approach
	    my $val = getValue($$data{$fields[0]}, $values{$fields[0]});
	    debug("Getting $fields[0]: $$data{$fields[0]}\n");
	    for (my $i = 1; $i <= $#fields; $i++){
		my $newval = getValue($$data{$fields[$i]}, $values{$fields[$i]});
		debug("Checking $fields[$i] for $i\n");
		if ($newval !~ /^\s*$/ 
		    && $val =~ /^\s*$/) {
		    $val = $newval;
		}
		if ($newval !~ /^\s*$/ && 
		    $newval ne $val){
		    print STDERR "Fields mapped to $myFields[$f] disagree for id $id\n";
		}
	    }
	    if ($val =~ /^\s*$/){next;} # no need to enter empty fields
	    push @query1, $field;
	    push @query2, $val;
	    push @query3, "$field = $val";
	}
	# here we create the full query
	my $query = "insert into $table (" 
	    . join(', ', @query1) . ") values ("
	    . join(', ', @query2) . ") on duplicate key set "
	    . join(', ', @query3) . ";";

	print $query, "\n";
	
	my $sth = $dbh->prepare($query) || 
	    die ("Could not prepare $query: $dbh->errstr");
	$sth->execute() || 
	    die ("Could not execute $query: $dbh->errstr");
    }
}
close(CLIN);


exit(0);

#############

sub getValue()
{
    my $entry = shift;
    my $valueIfo = shift;

    # here I assume valueIfo looks something like:
    # (1-Yes,2-No)
    # if $entry is '1' it would return 'Yes'.
    # otherwise the entry is returned as received.
    #
    # if valueIfo is 'STR' returns entry in quotes

    debug("Got entry $entry and value $valueIfo\n");

    if ($entry =~ /^\s*$/){return $entry;}

    if ($valueIfo eq "STR"){
	debug("Returning \'$entry\'\n");
	return "\'$entry\'";
    }
    if ($valueIfo !~ /^\(/) {
	debug("Returning $entry\n");
	return $entry;
    }
    $valueIfo =~ s/[\(\)]//g;

    my %valmap;
    my @flds = split(/\s*,\s*/, $valueIfo);
    for (my $i = 0; $i <= $#flds; $i++){
	my ($key, $val) = split(/\s*-\s*/, $flds[$i]);
	$valmap{$key} = $val;
    }
    debug("Returning \'" . $valmap{$entry} . "\'\n");
    return "\'" . $valmap{$entry} . "\'";
}


# subroutine to make debugging easier.
sub debug ()
{
    my $text = shift;
    if (defined $DEBUG){
	print STDERR $text;
    }
}
