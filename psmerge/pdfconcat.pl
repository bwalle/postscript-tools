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

our $VERSION = "0.2.5";

my $printVersion = FALSE;
my $printHelp = FALSE;
my $pdfminorversion = 4;
my $oldpdflatex = FALSE;
my $debug = FALSE;
my $workingdir = getcwd();
my $landscapeRange = FALSE;
my $fitpaper = FALSE;

GetOptions (

	'h|help' 				=> 	\$printHelp,
	'v|version'				=>	\$printVersion,
	'p|pdfminorversion=i'	=>	\$pdfminorversion,
	'o|oldpdflatex'			=>  \$oldpdflatex,
	'd|debug'				=>	\$debug,
	'l|landscape=s'			=>  \$landscapeRange,
	'f|fitpaper'			=>	\$fitpaper,

);
	
# Print help or version
if ($printHelp) {
	exec("perldoc", "-T", $0);
}
if ($printVersion) {
	printVersion();
	exit(0);
}
if (@ARGV < 2) {
	print STDERR "Usage: pdfconcat.pl input1, input2, ... output\n";
	exit(1);
}
	

my $outFile = pop(@ARGV);
my @inputFiles = @ARGV;


my $tempdir = tempdir("pdfconcat.pl-XXXXXX", TMPDIR => 1, CLEANUP => 1);

# Some checks
if (-e "$outFile") {
	print STDERR "File '$outFile$_' exists. It will be overwritten. Continue? [y/n] ";
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
}

open OUT, ">$tempdir/file.tex" or die "Could not create '$tempdir/file.tex': $!";

if (!$oldpdflatex) {
	print OUT "\\pdfoptionpdfminorversion$pdfminorversion\n";
}

print OUT <<'EOF';
\documentclass[a4paper]{article}
\usepackage{pdfpages}
\begin{document}
EOF

my $fitpaperString = $fitpaper ? ",fitpaper=true" : "";

my $current = 1;
foreach (@inputFiles) {
	s/\.pdf$//;
	if (rangeContains($landscapeRange, $current)) {
		print OUT '\includepdf[landscape,pages=-'.$fitpaperString.']{' . 
			"$workingdir/$_" . "}\n";
	} else {
		print OUT '\includepdf[pages=-'.$fitpaperString.']{' . "$workingdir/$_" . "}\n";
	}
	$current++;
}

print OUT '\end{document}';

close OUT or die "Cound not close $tempdir/file.tex: $!";

# running LaTeX
print STDERR "Running pdflatex ...\n";
chdir $tempdir;
if ($debug) {
	system("pdflatex file.tex 1>&2");
} else {
	system("pdflatex file.tex >> /dev/null 2>&1");
}

# moving file
if ($outFile ne "-") {
	copy("$tempdir/file.pdf", "$workingdir/$outFile");
} else {
	open FILE, "<$tempdir/file.pdf" or die "Could not open '$tempdir/file.pdf': $!";
	binmode FILE;
	print STDERR "Copying file to stdout ...\n";
	while (<FILE>) {
		print;
	}
	close FILE;
}


# -----------------------------------------------------------------------------

sub printVersion {
	print STDERR "pdfconcat.pl $VERSION\n";
}

# -----------------------------------------------------------------------------

# checks if a range contains a value
# @param 1 the range, e.g. 1-5,10 or all
# @param 2 the value
sub rangeContains ($$) {
	my $range = shift;
	my $value = shift;

	if ($range =~ /all/i or $range eq "*") {
		return TRUE;
	}
	
	# fill the list
	foreach (split(/,/, $range)) {
		if (/-/) {
			my ($first, $last) = split(/-/, $_);
			if ($value >= $first or $value <= $last) {
				return TRUE;
			}
		} elsif ($_ == $value) {
			return TRUE;
		}
	}

	return FALSE;
}
		
			

			
	

sub printHelp {
}


=head1 NAME

pdfconcat.pl - merges PDF files

=head1 SYNOPSIS 

pdfconcat.pl I<options> I<input1> [I<input2>, ...] I<output>|-

=head1 OPTIONS
      
=over 7

=item B<-h> | B<--help>

Print this help message and exit.

=item B<-v> | B<--version>

Prints the version of the program and exits.

=item B<-p> I<version> | B<--pdfminorversion> I<version>

Specifies the minor version of the PDF file that should be created. The full
PDF version is of the format x.x, e.g.  1.4. You should specify only the part
after the point.  The PDF minor version plus one is the Acrobat (Reader)
version, so specify '3' if you want that the document could be read by Acrobat
Reader 4 and higher. The default is '4'.

B<WARNING:> The version of the PDF files that are merged must not
be higher than the specified version.

=item B<-o> | B<--oldpdflatex>

Use this option if you have a PDFlatex prior to 1.10-a installed on your
system. In this case, no pdfminorversion is specified and the system default is
used.

=item B<-l> I<range> | B<--landscape>  I<range>

Enables landscape mode for the specified range of files. So if your first file
is landscape but the second one portrait you have to call this script with
I<1>. Use I<all> if all files are landscape. You can also specify a range
like I<1-3,5>. 

=item B<-f>| B<--fitpaper>

Adjusts the paper size to the one of the partial document. If this option
is not given, the document gets centered (and scaled) to A4 portrait.


B<NOTE:> This are the file numbers (first one is 1), not page numbers!

=head1 BUGS

=item * 

The filenames of the source files may not contain dots in the file name.
pdflatex and the pdfpages package takes the first dot as beginning of the
extension. 

=head1 SEE ALSO

pdflatex(1)

=head1 COPYRIGHT

© 2002-03 Bernhard Walle

This is free software; see the source for  copying  conditions.
There is NO warranty; not even for MERCHANTABILITY or FITNESS FOR
A PARTICULAR PURPOSE. 



=head1 AUTHOR

Bernhard Walle <bernhard.walle@gmx.de>

=cut

