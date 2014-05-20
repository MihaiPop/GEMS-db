#!/usr/bin/perl

use Text::CSV;

my %map_table = (
    "1A" => "1A",
    "1B" => "2A",
    "1C" => "3A",
    "1D" => "4A",
    "1E" => "5A",
    "1F" => "6A",
    "1G" => "7A",
    "1H" => "8A",
    "2A" => "9A",
    "2B" => "10A",
    "2C" => "11A",
    "2D" => "12A",
    "2E" => "1B",
    "2F" => "2B",
    "2G" => "3B",
    "2H" => "4B",
    "3A" => "5B",
    "3B" => "6B",
    "3C" => "7B",
    "3D" => "8B",
    "3E" => "9B",
    "3F" => "10B",
    "3G" => "11B",
    "3H" => "12B",
    "4A" => "1C",
    "4B" => "2C",
    "4C" => "3C",
    "4D" => "4C",
    "4E" => "5C",
    "4F" => "6C",
    "4G" => "7C",
    "4H" => "8C",
    "5A" => "9C",
    "5B" => "10C",
    "5C" => "11C",
    "5D" => "12C",
    "5E" => "1D",
    "5F" => "2D",
    "5G" => "3D",
    "5H" => "4D",
    "6A" => "5D",
    "6B" => "6D",
    "6C" => "7D",
    "6D" => "8D",
    "6E" => "9D",
    "6F" => "10D",
    "6G" => "11D",
    "6H" => "12D",
    "7A" => "1E",
    "7B" => "2E",
    "7C" => "3E",
    "7D" => "4E",
    "7E" => "5E",
    "7F" => "6E",
    "7G" => "7E",
    "7H" => "8E",
    "8A" => "9E",
    "8B" => "10E",
    "8C" => "11E",
    "8D" => "12E",
    "8E" => "1F",
    "8F" => "2F",
    "8G" => "3F",
    "8H" => "4F",
    "9A" => "5F",
    "9B" => "6F",
    "9C" => "7F",
    "9D" => "8F",
    "9E" => "9F",
    "9F" => "10F",
    "9G" => "11F",
    "9H" => "12F",
    "10A" => "1G",
    "10B" => "2G",
    "10C" => "3G",
    "10D" => "4G",
    "10E" => "5G",
    "10F" => "6G",
    "10G" => "7G",
    "10H" => "8G",
    "11A" => "9G",
    "11B" => "10G",
    "11C" => "11G",
    "11D" => "12G",
    "11E" => "1H",
    "11F" => "2H",
    "11G" => "3H",
    "11H" => "4H",
    "12A" => "5H",
    "12B" => "6H",
    "12C" => "7H",
    "12D" => "8H",
    "12E" => "9H",
    "12F" => "10H",
    "12G" => "11H",
    "12H" => "12H"
);

#print $map_table{"13A"}, "\n";

open(IN, $ARGV[0]) || die ("Cannot open $ARGV[0]: $!\n");
#print "got $ARGV[0]\n";

my $in = Text::CSV->new({sep_char => "\t"});
if (! defined $in) {die("Couldnt build parser\n")};
$in->column_names($in->getline(\*IN));
#print $in->column_names(),"\n";

my %ids = (); #sample id
my %rest = (); #rest of the info
my $n = 0;

my %seenplate = ();
my $last = undef;
my $plate = undef;
while (my $data = $in->getline_hr(\*IN)) {
#	print "..\n";
	++$n;

    if ($$data{"Plate"} ne $last){ # new plate
       if (exists $seenplate{$$data{"Plate"}}){
	    if (exists $seenplate{$$data{"Plate"} . "R"}){
 		$plate = $$data{"Plate"} . "RR";
	    } else {
		$plate = $$data{"Plate"} . "R";
	    }
	} else {
		$plate = $$data{"Plate"};
	}
        $seenplate{$plate} = 1;
        $last = $$data{"Plate"};
    }
    my $key = $plate . "_" . $$data{"Well"};
#	print "$key\n";
    $ids{$key} = $$data{"Sample ID"};
    $rest{$key} = $$data{"File #"};
}

print STDERR "got $n records\n";
$n = 0;
print "Plate\tWell\tSample ID\tFile #\n";
while (my ($key, $id) = each %ids){
   ++$n;
    my ($plate, $well) = split('_', $key);
    print "$plate\t$well\t";
    print $ids{$plate . "_" . $map_table{$well}};
    print "\t$rest{$key}\n";
}

print STDERR "printed $n records\n";
