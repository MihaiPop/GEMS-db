#!/usr/bin/perl

use strict;

my $VERSION = ' $Id: makeNCBIDB.pl,v 1.8 2012/02/13 18:12:10 mpop Exp $ ';

use Getopt::Long;

# The goal of this script is to create a nodes.dmp and named.dmp 
# file from the SILVA database so that each entity in SILVA has
# an identifier.

# Sample bacterial name
#Bacteria;Thermotogae;Thermotogae;Thermotogales;Thermotogaceae;Fervidobacterium;Thermopallium natronophilum
# Bacteria                      - superkingdom (domain)
# Thermotogae                   - phylum
# Thermotogae                   - class
# Thermotogales                 - order
# Thermotogacea                 - family
# Fervidobacterium              - genus
# Thermopallium natronophilum   - species

# Exceptions: 
# -----------
# Myxococcales (has suborders)
#Bacteria;Proteobacteria;Deltaproteobacteria;Myxococcales;Nannocystineae;Nannocystaceae;Plesiocystis;Plesiocystis pacifica
# Bacteria                      - superkingdom (domain)
# Proteobacteria                - phylum
# Deltaproteobacteria           - class
# Myxococcales                  - order
# Nannocystineae                - suborder
# Nannocystaceae                - family
# Plesiocystis                  - genus
# Plesiocystis pacifica         - species

# Thermomicrobia (has suborders and subclasses)
#Bacteria;Chloroflexi;Thermomicrobia;Sphaerobacteridae;Sphaerobacterales;Sphaerobacteraceae;Sphaerobacter;Sphaerobacter thermophilus
# Bacteria                      - superkingdom (domain)
# Chloroflexi                   - phylum
# Thermomicrobia                - class
# Sphaerobacteridae             - subclass
# Sphaerobacterales             - order
# Sphaerobacteraceae            - family
# Sphaerobacter                 - genus
# Sphaerobacter thermophilus    - species
#
# Note: SILVA Claims Thermomicrobia also have a suborder but one is not 
# recorded in version 108 of their database.
#
###########
# Eukaryota
###########
# Not clear what the rules are here.
# The protocol will be
# Last name is a:
#   strain if it has more than 2 words
#   species if it has exactly two words
#   the appropriate taxonomic level if less than 11 levels in name
#
# Levels are:
# superkingdom
# phylum
# class
# order
# family
# genus
# species
# strain

##
# General approach
#
# Break up name into an array of names (breaking at semicolons)
#
# Set up an array of level names as described above:
# if names[0] is bacteria and names[3] is Myxococcales 
#   - we have 8 levels incl. suborder
# if names[0] is bacteria and names[2] is Thermomicrobia 
#   - we have 8 levels incl. subclass
# if names[0] is bacteria or archaea
#   - we have 7 levels
#   - if last name has more than 2 words - add an 8/9th level: strain
#     and add the first two words in name as the species name
# 
# if names[0] is eukaryota
#   - if last name has more than 2 words - it's strain
#   - if next to last name has two or more words - it's species, otherwise
#     first two words in last name become species
#   - the remaining words assigned according to the levels described above
#
# Each distinct name-level combination gets an identifier
# Parent information can be directly inferred from the relationship of names
#  in the long taxonomic name

my $infile = undef;
my $outdir = undef;
my $version = undef;
my $help = undef;

my $result = GetOptions(
    "help" => \$help,
    "version" => \$version,
    "in=s" => \$infile,
    "outdir=s" => \$outdir
    );

if (defined $version){
    die ($VERSION . "\n");
}

if (! defined $result 
    || defined $help
    || ! defined $infile
    || ! defined $outdir){
    die ("Usage: makeNCBIDB.pl --in <namesfile> --outdir <outputdir>\n" .
	 " Takes semicolon delimited taxonomic names from <namesfile>\n" . 
	 " and outputs an NCBI-like names.dmp and nodes.dmp file in the output dir\n" . 
	 " If input file has two whitespace-separated fields, assumes that\n" .
	 " the first field is a sequence identifier and the second a\n" . 
	 " taxonomic name, and also outputs a file <namesfile>.taxids\n" . 
	 " mapping the original taxonomic names to identifiers in the\n" .
	 " new database\n"
	);
}

my $namesfile = "$outdir/names.dmp";
my $nodesfile = "$outdir/nodes.dmp";
my $taxidfile = "$infile.taxids";

my $CURID   = 1; # current taxonomic ID
my @levels  = (); # name of the levels  (for prokaryotes, primarily).
my %node2id = (); # mapping from rank-name pair to a taxonomic id
my %id2parent = (); # mapping from ID to parent ID
my %id2rank = (); # mapping from ID to taxonomic rank
my %id2domain = (); # mapping from ID to domain of life
my $first = 1;  # keep track of work on first line only
my $taxfield = 0;
my $namefield = 0;

open(IN, $infile) || die ("Cannot open input $infile: $!\n");
open(OUTTAX, ">$taxidfile") || die ("Cannot open $taxidfile: $!\n");
while (<IN>){
    chomp;

    ## Here we check whether file contains both sequence ID and taxonomy name
    ## The taxonomy name is assumed to be the second record in each line.
    my @fields;
    $_ = /^(\S+)\s+(.*)$/;
    $fields[0] = $1;
    $fields[1] = $2; 
    $taxfield = 1;

    my $taxname = $fields[$taxfield];
    my @names = split(';', $taxname);

    print STDERR "$taxname has ", $#names + 1, " levels\n";

    # Some hacks to deal with SILVA nonsense

    # Truncate name after chloroplast and/or mitochondria
#    for (my $i = 0; $i <= $#names; $i++){
#	if ($names[$i] eq "Chloroplast" ||
	#    $names[$i] eq "mitochondria"){
#	    $#names = $i;
#	    last;
#	}
#    }

    # if in Bacteria and name starts with Oryza, truncate to earlier level
#    for (my $i = 0; $i <= $#names; $i++){
#	if ($names[0] eq "Bacteria" && $names[$i] =~ /^Oryza /){
#	    $#names = $i - 1;
#	    last;
#	}
#    }

    # name is uncultured bacterium, truncate to earlier level
#    if ( $names[$#names] eq "uncultured rumen bacterium" 
#         || $names[$#names] eq "uncultured bacterium" 
#         || $names[$#names] eq "uncultured marine bacterium" 
#         || $names[$#names] eq "uncultured sludge bacterium" 
#         || $names[$#names] eq "uncultured soil bacterium" 
#         || $names[$#names] eq "uncultured thermal soil bacterium" 
#         || $names[$#names] eq "uncultured archaeon"
#         || $names[$#names] eq "uncultured rumen archaeon"
#         || $names[$#names] eq "uncultured marine archaeon"
#         || $names[$#names] eq "uncultured soil archaeon"
#         || $names[$#names] eq "uncultured thermal soil archaeon"
#         || $names[$#names] eq "uncultured crenarchaeote"
#         || $names[$#names] eq "uncultured marine crenarchaeote"
#         || $names[$#names] eq "uncultured nanoarchaeote"
#         || $names[$#names] eq "uncultured marine nanoarchaeote"
#	 || $names[$#names] eq "uncultured compost bacterium"
#	 || $names[$#names] eq "uncultured compost archaeon"
#         || $names[$#names] eq "uncultured deep-sea bacterium"
#         || $names[$#names] eq "uncultured endolithic bacterium"
#         || $names[$#names] eq "uncultured endophytic bacterium"
#         || $names[$#names] eq "uncultured eukaryote"
#         || $names[$#names] eq "uncultured marine eukaryote"
#         || $names[$#names] eq "uncultured prokaryote"
#         || $names[$#names] eq "uncultured marine prokaryote"
#         || $names[$#names] eq "uncultured fungus"
#         || $names[$#names] eq "uncultured marine fungus"
#         || $names[$#names] eq "uncultured haloarchaeon"
#         || $names[$#names] eq "uncultured halophilic eubacterium"
#         || $names[$#names] eq "uncultured human oral bacterium"
#         || $names[$#names] eq "uncultured isopod gut bacterium"
#         || $names[$#names] eq "uncultured methanogenic archaeon") {
#	$#names--;
#    }
    
    # Here we decide between different options
    if ($names[0] eq "Bacteria" &&
	$names[3] eq "Myxococcales"){
	@levels = ("superkingdom", "phylum", "class", "order", "suborder", "family", "genus");
    } elsif ($names[0] eq "Bacteria" &&
	     $names[2] eq "Thermomicrobia"){
	@levels = ("superkingdom", "phylum", "class", "subclass", "order", "family", "genus");
    } elsif ($names[0] ne "Eukaryota") {
	@levels = ("superkingdom", "phylum", "class", "order", "family", "genus");
    } else { # eukaryota
	@levels = ("superkingdom", "phylum", "class", "order", "family");
    }

    # here we check for species vs. strain distinction and create a new strain
    # if necessary

    # first check if the last name has more than two words.
    my @subnames = split(/\s+/, $names[$#names]);
    my $hasstrain = 0;
    my $hasspecies = 0;
    my $hasgenus = 0;
    if ($#subnames >= 1) { # I have >= two words
	$hasspecies = 1; # I will always have a species
	print STDERR "$taxname has species\n";
	if ($#subnames > 1){ # I have > two words
	    $hasstrain = 1; # this is a strain
	    print STDERR "$taxname has strain\n";
	    if ($names[$#names - 1] !~ /\s/){
		# parent only has one word.  I have to create a species
		my $last = $#names;
		$names[++$#names] = $names[$last]; # copy the old name
		$names[$last] = join(" ", @subnames[0..1]); # create a species with just two names	
		print STDERR "created species for $taxname\n";
	    }
	}
	if ($names[0] eq "Eukaryota"){ #create genus if necessary
	    if ($subnames[0] eq $names[$#names - $hasstrain -1]){
		$hasgenus = 1;
	    }
	}
    } else {
	print STDERR "$taxname has neither strain nor species\n";
    }

    print STDERR "parsing $taxname\n";
    # here's where the hard work goes in.
    for (my $i = 0; $i <= $#names; $i++){
	my $pref = join(';', @names[0..$i]); # prefix of name
	if (! exists $node2id{$pref}) { # no id exists
	    $node2id{$pref} = $CURID++;
	    if ($i == 0) {
		$id2parent{$node2id{$pref}} = 0; # zero level nodes
	    } else {
		my  $parPref = join(';', @names[0 .. $i - 1]);
		print STDERR $node2id{$pref}, " parent is ", $node2id{$parPref}, "\n";
		$id2parent{$node2id{$pref}} = $node2id{$parPref}; # parent node must have an id at this point
	    }
	    if ($i <= $#names - $hasstrain - $hasspecies - $hasgenus) {
		# we're not yet at the strain/species/genus level
		if ($i <= $#levels){
		    $id2rank{$node2id{$pref}} = $levels[$i];
		    print STDERR "$names[$i] is $levels[$i]\n";
		} else {
		    $id2rank{$node2id{$pref}} = "no rank";
		    print STDERR "$names[$i] is no rank\n";
		}
	    } else { # now we're at either strain or species level
		if ($hasstrain == 1 && $i == $#names) { # at strain level
		    $id2rank{$node2id{$pref}} = "strain";
		    print STDERR "$names[$i] in $taxname is strain\n";
		} elsif ($hasspecies == 1 && $i == $#names - $hasstrain) {
		    $id2rank{$node2id{"$pref"}} = "species";
		    print STDERR "$names[$i] in $taxname is species\n";
		} elsif ($hasgenus == 1 && $i == $#names - $hasstrain - $hasspecies){
		    $id2rank{$node2id{$pref}} = "genus";
		    print STDERR "$names[$i] in $taxname is genus i = ", $i, " names= ",  $#names, " levels = ", $#levels, "\n";
		} else {
		    print STDERR "Shouldn\'t be here $names[$i] for $taxname\n";
		}
		
	    }
	}
	# output taxid information only if we had two records per line
        # and we've reached the end of the current taxonomy name.
	if ($i == $#names && $taxfield == 1){
	    print OUTTAX $fields[0], "\t", 
	          $node2id{$pref}, "\t",
	          $names[$i], "\t",
	          $taxname, "\t",
	          $id2rank{$node2id{$pref}}, "\n";
	}
    }
}
close(OUTTAX);

# Now we write the names and nodes files
open(NAMES, ">$namesfile") || die ("Cannot open names $namesfile:$!\n");
open(NODES, ">$nodesfile") || die ("Cannot open nodes $nodesfile:$!\n");
while (my ($id, $rank) = each %id2rank){
    print STDERR "$id has parent ", $id2parent{$id}, "\n";
    print NODES "$id\t|\t", $id2parent{$id};
    print NODES "\t|\t$rank"; # taxonomic rank
# and some information NCBI has that may or may not be relevant
    print NODES "\t|\t0"; #EMBL code
    print NODES "\t|\t0"; #Division ID
    print NODES "\t|\t0"; # node inherits division from parent
    print NODES "\t|\t0"; # genetic code ID
    print NODES "\t|\t0"; # node inherits genetic code from parent
    print NODES "\t|\t0"; # mitochondrial genetic code id
    print NODES "\t|\t0"; # node inherits mitochondrial genetic code from parent
    print NODES "\t|\t0"; # Genbank hidden flag
    print NODES "\t|\t0"; # hidden subtree root flag
    print NODES "\t|\t\t|\n"; # comments
}
close(NODES);
while (my ($namelevel, $id) = each %node2id){
    my @fields = split(';', $namelevel);
    my $name = $fields[$#fields];
    print NAMES "$id\t|\t$name\t|\t$name\t|\tscientific name\t|\n";
}
