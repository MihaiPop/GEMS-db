# $Id: ParseTab.pm,v 1.1.1.1 2012/02/07 17:28:13 mpop Exp $

# ParseTab.pm
#

package ParseTab;
{

=head1 NAME

ParseTab - class for reading a tab-delimited file

The assumption is that the file contains a set of lines, each tab-delimited
and that it starts with a single header line containing field names. 

=head1 SYNOPSIS

use ParseTab;
my $parser = new ParseTab(\*STDIN);

while (my $data = $parser->getRecord()){
   ...
}

=head1 DESCRIPTION

This module iterates through a tab-delimited file retrieving the records in 
as a hash-table linking the value in a field with the field name from the
header line as a key. By default the field separator is TAB but other delimiters
can also be specified in the constructor.

=cut

    use strict;

    sub new();
    sub getRecord();
    sub getNameArray();

=over

=item $parser = new ParseTab($file, $sep) ;

Creates a new parser object reading from file $file using the optional field
separator $sep

=cut

sub new()
{
    my $pkg = shift;
    my $file = shift;
    my $sep = shift;
    my @names = ();
    my $line;

    my $self = {};
    bless $self;

    $self->{sep} = "\t"; 
    $self->{sep} = $sep if defined $sep;
    $self->{file} = $file;

    $line = <$file>;
    if (! defined $line){
	print STDERR "File appears empty\n";
	return undef;
#	die("File appears empty\n");
    }

    chomp $line;
#    $line = lc($line); # just work in lowercase
    @names = split($self->{sep}, $line);
    $self->{names} = \@names;
#    print STDERR "GOT a line $buf\n";
    return $self;
}

=item $data = $parser->getRecord();

Reads a record into a hash returned as $data.  If at end of file returns undef

=cut

sub getRecord()
{
    my $self = shift;
    my %data = ();
    my $file = $self->{file};
    my $line;

    $line = <$file>;
    
    if (! defined $line){ 
	return undef;
    }

    chomp $line;

    my @fields = split($self->{sep}, $line);
    for (my $i = 0; $i <= $#fields; $i++){
	my $nm = ${$self->{names}}[$i];
	$data{$nm} = $fields[$i];
    }
    return \%data;
}


=item $arr = $parser->getNameArray()

Returns the array of names in the order in which it was found in the file

=cut

sub getNameArray()
{
    my $self = shift;

    return $self->{names};
}

}

1;
