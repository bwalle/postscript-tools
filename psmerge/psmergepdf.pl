#!/usr/bin/env perl
#
# Merges PDF files. Requires pdflatex and pdfpages.sty.
#
# © 2003, Bernhard Walle <Bernhard.Walle@gmx.de>

use constant FALSE => 0;
use constant TRUE => 1;

use strict;
use POSIX qw(getcwd);
use File::Temp qw(tempdir);
use File::Copy;
use Getopt::Long; 

our $VERSION = "0.1.3";

my $printVersion = FALSE;
my $printHelp = FALSE;
my $debug = FALSE;
my $workingdir = getcwd();
my @landscapeEnabled = ();

GetOptions (

	'h|help' 				=> 	\$printHelp,
	'v|version'				=>	\$printVersion,
	'd|debug'				=>	\$debug,

);
	
# Print help or version
if ($printHelp) {
	exec("perldoc", "-T", $0);
	exit(0);
}
if ($printVersion) {
	printVersion();
	exit(0);
}
if (@ARGV < 2) {
	print STDERR "Usage: psmergepdf.pl input1, input2, ... output\n";
	exit(1);
}
	

my $outFile = pop(@ARGV);
my @inputFiles = @ARGV;


my $tempdir = tempdir("psmergepdf.pl-XXXXXX", TMPDIR => 1, CLEANUP => 1);

# Some checks
if (-e "$outFile") {
	print STDERR "File '$outFile$_' exists. It will be overwritten. Continue? [y/n] ";
	my $key = <STDIN>;
	chomp($key);
	unless ($key eq "y" or $key eq "j") { 
		exit 1;
	}
}

my $current = 1;
my $currentFile;
foreach $currentFile (@inputFiles) {
	unless (-e $currentFile) {
		print STDERR "Input file '$currentFile' does not exist.\n";
		exit 1;
	}
	open PSFILE, $currentFile or die "Could not open $currentFile: $!";
	while  (<PSFILE>) {
		if (/^%%Orientation:.*Landscape/i) {
			push @landscapeEnabled, $current;
			last;
		}
	}
	close PSFILE;

	$current++;
}

chdir($tempdir);

foreach (@inputFiles) {
	my $postscriptFile = $_;
	s/\.ps$/.pdf/;
	s/ /_/g;
	system("ps2pdf12 '$workingdir/$postscriptFile' '$_'");
}

# running psmerge.pl
if (@landscapeEnabled != 0) {
	system("pdfconcat.pl -l '".join(",", @landscapeEnabled) . "' -o ".join(" ", @inputFiles)." file.pdf");
} else {
	system("pdfconcat.pl -o ".join(" ", @inputFiles)." file.pdf");
}
system("pdftops file.pdf file.ps");

# moving file
if ($outFile ne "-") {
	copy("$tempdir/file.ps", "$workingdir/$outFile");
} else {
	open FILE, "<$tempdir/file.ps" or die "Could not open '$tempdir/file.ps': $!";
	binmode FILE;
	print STDERR "Copying file to stdout ...\n";
	while (<FILE>) {
		print;
	}
	close FILE;
}


# -----------------------------------------------------------------------------

sub printVersion {
	print STDERR "pdfmerge.pl $VERSION\n";
}

# -----------------------------------------------------------------------------


=head1 NAME

psmergepdf.pl - merges Postscript files by converting them to PDF

=head1 SYNOPSIS 

psmergepdf.pl I<options> I<input1> [I<input2>, ...] I<output>|-


=head1 DESCRIPTION

psmergepdf.pl is a utility which merges several PDF files into one Postscript
file. There are utilities that does the same job in the web, so why another
one? There are two strategies: one is to concatenate the files and insert some
lines of Postscript code between, which only works if the files are similar and
if you have luck. Another strategy is to use Ghostscript which always works but
the result is a Postscript file that does not contain text any more, i.e. is
not convertable to ASCII, to full-text search is impossible.  So both concepts
are not suitable for me.

The solution is the PDF format. It is easy to convert between Postscript and
PDF and there's a good way to merge PDF files: pdflatex and my utility
pdfconcat.pl. So I decided to put this together and the result is here.

Change you .xpdfrc to change papersize or Postscript level. Landscape
is detected automatically by Postscript comments and the file number is
passed to pdfconcat.pl.

=head1 REQUIREMENTS

=over 4

=item *

ps2pdf to convert Postscript files to PDF (part of Ghostscript)


=item * 

pdftops to convert PDF files to Postscript (part of xpdf)

=item *

pdfconcat.pl to merge the PDF files (from me, get it where you got this utility)

=head1 OPTIONS
      
=over 7

=item B<-h> | B<--help>

Print this help message and exit.

=item B<-v> | B<--version>

Prints the version of the program and exits.


=head1 SEE ALSO

psmerge(1), xpdfrc(5), gs(1), pdftops(5), ps2pdf(1)
pdfconcat.pl (http://www.bwalle.de)
psmerge.pl (http://www.bwalle.de), does the same by using Ghostscript

=head1 COPYRIGHT

© 2003 Bernhard Walle

This is free software; see the source for  copying  conditions.
There is NO warranty; not even for MERCHANTABILITY or FITNESS FOR
A PARTICULAR PURPOSE. 


=head1 AUTHOR

Bernhard Walle <bernhard.walle@gmx.de>

=cut

