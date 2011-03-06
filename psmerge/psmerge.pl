#!/usr/bin/perl
#
# Fügt mehrere Postscript-Dateien zu einer großen zusammen. Benötigt
# Ghostscript.
#
# © 2003, Bernhard Walle <Bernhard.Walle@gmx.de>

use File::Temp qw(tempfile);
our $VERSION = "0.1.2";

# Print help message
if (@ARGV < 2) {
	if ($ARGV[0] eq "-v" or $ARGV[0] eq "--version") {
		print STDERR "psmerge.pl $VERSION -- ",
			"© 2003, Bernhard Walle <bernhard.walle@gmx.de>\n";
	} elsif($ARGV[0] eq "-h" or $ARGV[0] eq "--help") {
		exec("perldoc", "-T", $0);
	} else {
		print STDERR "Usage: psmerge.pl inputfile1 [inputfile2, ...] outputfile\n";
	}
	exit(0);
}

use constant FALSE => 0;
use constant TRUE => 1;

my $outFile = pop(@ARGV);
my @inputFiles = @ARGV;


# Some checks
if (-e $outFile) {
	print STDERR "File '$outFile' exists. It will be overwritten. Continue? [y/n] ";
	my $key = <STDIN>;
	chomp($key);
	unless ($key eq "y" or $key eq "j") { 
		exit 1;
	}
}
foreach (@inputFiles) {
	unless (-e $_) {
		print STDERR "Input file '$_' does not exist.\n";
		exit 1;
	}
	open PSFILE, "<$_" or die "Could not open $_ for reading: $!";
}

($tempFH, $tempFilename) = tempfile( SUFFIX => ".ps", UNLINK => 1);


print "We're running Ghostscript now ...\n";
system (("gs", "-dNOPAUSE", "-sDEVICE=pswrite", "-sOutputFile=$tempFilename",
		@inputFiles, "-c", "quit"));

print "Removing the bounding box ...\n";

open (PSFILE, ">$outFile") or die "Cound not open $outFile for writing: $!";
while (<$tempFH>) {
	if (!( /^%%BoundingBox:/ or /^%%HiResBoundingBox:/ )) {
		print PSFILE $_;
	}
}

close PSFILE or die "Could not open $outFile: $!";

=head1 NAME

psmerge.pl - merges Postscript files by using Ghostscript

=head1 SYNOPSIS 

psmerge.pl I<input1> [I<input2>, ...] I<output>|-


=head1 OPTIONS
      
=over 7

=item B<-h> | B<--help>

Print this help message and exit.

=item B<-v> | B<--version>

Prints the version of the program and exits.


=head1 SEE ALSO

gs(1), psjoin(1), psmerge(1)

=head1 COPYRIGHT

© 2002-03 Bernhard Walle

This is free software; see the source for  copying  conditions.
There is NO warranty; not even for MERCHANTABILITY or FITNESS FOR
A PARTICULAR PURPOSE. 


=head1 AUTHOR

Bernhard Walle <bernhard.walle@gmx.de>

=cut

