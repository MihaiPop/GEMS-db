#!/usr/bin/perl

####
#
# Change the following line to point to location of Perl libraries
#
####

use ParseTab;

# Takes a .csv file that contains a Filename field and adds (or updates if
# already exists) a field called File # with an integer representing this
# file.  This integer will be used to construct new sequence identifiers.

print STDERR "Usage: add_filenum.pl file.csv > file.new.csv\n";
print STDERR " Assumes file.csv contains a field called \"Filename\"\n";
print STDERR " and adds or updates a new field called \"File \#\"\n";
my $incsv = $ARGV[0];
open(IN, $incsv) || die("Cannot open $incsv:  $!\n");

my $pi = new ParseTab(\*IN);
my @names = @{$pi->getNameArray()};

my $numnum = 0;
my $foundfilenum = 0;
for (my $i= 0; $i <= $#names; $i++){
    if ($names[$i] eq "File \#"){
	$numnum = $i + 1;
    }
    if ($names[$i] eq "Filename"){
	$foundfilenum = 1;
    }
}

if ($foundfilenum == 0){
    die ("Filename is not a field in $incsv\n");
}

my $maxnum = 0;
my $startnum = 0;
if ($numnum == 0){ # no File # field
    push @names, "File \#";
} else { # find max id
    my $maxnum = `cut -f $numnum $incsv | sort -n | tail -1`;
    chomp $maxnum;

    if ($maxnum > 0){
	$startnum = $maxnum; # where we start numbering files
    }
}

print join("\t", @names), "\n";

while (my $data = $pi->getRecord()){
    if ($$data{"Filename"} !~ /^\s*$/ && int($$data{"File \#"}) == 0){
	$$data{"File \#"} = ++$startnum;
    }
    print_row(\@names, $data, \*STDOUT);
}

exit(0);

sub print_row
{
    my $names = shift;
    my $hash = shift;
    my $file = shift;

    print $file $$hash{$$names[$0]};
    for (my $i = 1; $i <= $#$names; $i++){
        print $file "\t", $$hash{$$names[$i]};
    }
    print $file "\n";
}
