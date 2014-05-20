# $Id: ParseTaxonomy.pm,v 1.11 2012/02/14 17:29:02 mpop Exp $

# ParseTaxonomy.pm
#

package ParseTaxonomy;
{

=head1 NAME

    ParseTaxonomy - class for reading an NCBI-formatted taxonomy
    
Assumes the files names.dmp, nodes.dmp, and possibly merged.dmp exist
in the directory provided as parameter
=head1 SYNOPSIS

use ParseTaxonomy;
my $parser = new ParseTaxonomy($directory);


=head1 DESCRIPTION

This module parses an NCBI-taxonomy like database and offers a number
of useful utilities.

=cut

use strict;

sub new();
sub getFullTaxonomy();
sub getLevelName();
sub getLevelId();

=over

=item $parser = new ParseTaxonomy($dir) ;

Creates a new parser object reading taxonomy information from directory $dir

=cut

sub new()
{
    my $pkg = shift;
    my $TAXDIR = shift;

    my %parents;    # parent of a node
    my %nodename;   # name of a tax id
    my %namenode;   # tax id for a name
    my %ranks;      # rank for node
    my %merged;     # merged sequences

    my $self = {};
    bless $self;

# read taxonomy information
    print STDERR "Parsing taxonomy database\n";

    if (-f "$TAXDIR/merged.dmp") {
	open(MERGED, "$TAXDIR/merged.dmp") || 
	    die ("Cannot open $TAXDIR/merged.dmp:$!\n");
	while (<MERGED>){
	    chomp;
	    my @fields = split('\|', $_);
	    my $me = $fields[0]; $me =~ s/\s//g;
	    if ($me eq ""){
		die ("Incorrect database entry in merged.dmp line $.: empty first field [node id]");
	    }
	    my $parent = $fields[1]; $parent =~ s/\s//g;
	    if ($parent eq ""){
		die ("Incorrect database entry in merged.dmp line $.: empty second field [parent id]");
	    }
	    $merged{$me} = $parent;
	}
	close(MERGED);
    }
    
    open(NODES, "$TAXDIR/nodes.dmp") || 
	die ("Cannot open $TAXDIR/nodes.dmp:$!\n");
    
    while (<NODES>){
	chomp;
	my @fields = split('\|', $_);
	my $me = $fields[0]; $me =~ s/\s//g;
	if ($me eq ""){
	    die ("Incorrect database entry in nodes.dmp line $.: empty first field [node id]");
	}

	my $parent = $fields[1]; $parent =~ s/\s//g;
	if ($parent eq ""){
	    die ("Incorrect database entry in nodes.dmp line $.: empty second field [parent id]");
	}

	my $rank = $fields[2]; $rank =~ s/\s//g;
	if ($rank eq ""){
	    die ("Incorrect database entry in nodes.dmp line $.: empty third field [taxonomic rank]");
	}

	$parents{$me} = $parent;
	$ranks{$me} = $rank;
    }
    close(NODES);
        
    open(NAMES, "$TAXDIR/names.dmp") || 
	die ("Cannot open $TAXDIR/names.dmp:$!\n");
    while (<NAMES>){
	chomp;
	my @fields = split('\|', $_);
	
	my $sname = $fields[3];  $sname =~ s/^\s*//; $sname =~ s/\s*$//;
	if ($sname eq ""){
	    die ("Incorrect database entry in names.dmp line $.: empty first field [name type]");
	}

	my $id = $fields[0];  $id =~ s/\s//g;
	if ($id eq ""){
	    die ("Incorrect database entry in names.dmp line $.: empty second field [taxonomy id]");
	}

	my $name = $fields[1];   $name =~ s/^\s*//; $name =~ s/\s*$//;
	if ($sname eq ""){
	    die ("Incorrect database entry in names.dmp line $.: empty third field [taxonomic name]");
	}

	if ($sname eq "scientific name"){
	    $nodename{$id} = $name;
	}
	$namenode{$name} = $id;
    }
    close(NAMES);
    
    print STDERR "Done reading taxonomy DB\n";

    $self->{parents} = \%parents;
    $self->{nodename} = \%nodename;
    $self->{namenode} = \%namenode;
    $self->{ranks} = \%ranks;
    $self->{merged} = \%merged;
    
    return $self;
}

=item $data = $parser->getFullTaxonomy($taxid);

Returns a semi-colon delimited version of the full lineage of a taxon id.

my $taxonomy = $parser->getFullTaxonomy(1392);

=cut

sub getFullTaxonomy()
{
    my $self = shift;
    my $id = shift;

    if (exists ${$self->{merged}}{$id}){$id = ${$self->{merged}}{$id};}
    
    my $taxonomy = "";
    while ($id > 1){
#	print STDERR "id is $id";
        return undef unless exists ${$self->{nodename}}{$id};
#	print STDERR " name is $nodename{$id} ";
        $taxonomy = ";" . ${$self->{nodename}}{$id} . $taxonomy;
        return undef unless exists ${$self->{parents}}{$id};
        $id = ${$self->{parents}}{$id};
#	print STDERR "parent is $id\n";
    }
    return $taxonomy;
}

=item $name = $parser->getLevelName($taxid, $level);

Returns the scientific name for taxon id $taxid at taxonomic level $level.
Returns 'undef' if the taxon does not have a label at the required taxonomic
level.

my $name = $parser->getLevelName(1392, 'genus');

=cut
sub getLevelName()
{
    my $self = shift;
    my $id = shift;
    my $level = shift;

    if (exists ${$self->{merged}}{$id}){$id = ${$self->{merged}}{$id};}

    do {
        return undef unless exists ${$self->{ranks}}{$id};
        if (${$self->{ranks}}{$id} eq $level) {
            return undef unless exists ${$self->{nodename}}{$id};
            return ${$self->{nodename}}{$id};
        }
        return undef unless exists ${$self->{parents}}{$id};
        $id = ${$self->{parents}}{$id};
    } until ($id <= 1);
    return undef;
}

=item $name = $parser->getLevelId($taxid, $level);

Returns the taxonomy id for taxon id $taxid at taxonomic level $level.
Returns 'undef' if the taxon does not have a label at the required taxonomic
level.

my $nodeid = $parser->getLevelId(1392, 'genus');

=cut
sub getLevelId()
{
    my $self = shift;
    my $id = shift;
    my $level = shift;

    if (exists ${$self->{merged}}{$id}){$id = ${$self->{merged}}{$id};}

    do {
        return undef unless exists ${$self->{ranks}}{$id};
        if (${$self->{ranks}}{$id} eq $level) {
            return $id;
        }
        return undef unless exists ${$self->{parents}}{$id};
        $id = ${$self->{parents}}{$id};
    } until ($id <= 1);
    return undef;
}
}
1;
