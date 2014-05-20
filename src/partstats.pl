#!/usr/bin/perl

use strict;

my $VERSION = ' $Id: partstats.pl,v 1.1 2012/02/12 16:30:31 mpop Exp $ ';

# Program to compute statistics about a clustering provided in XML format
#
# If no file index information is provided simply lists each OTU and number
# of sequences contained in it, in a tab-delimited spreadsheet format.
#
# If file index information is provided, for each OTU the program also reports
# the number of samples containing that OTU.


use Getopt::Long;
use XML::Parser;

my $version = undef;
my $help = undef;

my $partition = undef;
my $fileidx = undef;
my $prefix = undef;


my $name = "";
my $level = 0;
my $num = 0;
my $out;

open(PART, $partition) || die ("Cannot open part $partition: $!\n");
while (<PART>){
    chomp;
    my $line = $_;
    $line =~ s/;//; # get rid of end of line
    if ($line =~ /^\s*{/){
	$level++;
	$line =~ s/^\s*{//; # strip front
    }

    if ($line =~ /=/){
	my ($tag, $value) = split('=', $line);
	if ($tag eq "name") {
	    if ($level == 1) {
		$batchname = $value;
	    }
	    if ($level == 2) {
		$name = $value;
		print "\"$name\"	";
		$num = 0;
	    }
	}
	next;
    }
   
    if ($line =~ /^\s*}/) {
	if ($level == 2){ 
		print "$num\n";	
	}
	$level--;
	next;
    }

    if ($level == 2) { # I only care about level two partitions
	++$num;
    }
}

exit(0);

