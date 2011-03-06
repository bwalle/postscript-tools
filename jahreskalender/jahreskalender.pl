#!/usr/bin/perl 
#
# jahreskalender.pl -- gibt einen Jahreskalender in üblicher Form aus.
#
# (c) Bernhard.Walle <bernhard@bwalle.de>

# You may use this script under the conditions of the Perl Artistic License.
#
# Auruf: jahreskalender.pl [-o Datei] [-y Jahr] [-t Termine] [-h]
#
# Ausgabe in Datei: Normalerweise wird eine Postscript-Datei erstellt,
#                   wenn die angegebene Datei allerdings auf .pdf endet, wird
#                   automatisch ins PDF-Format gewandelt


# Module
use Date::Calc ("Days_in_Month", "Delta_Days", "Easter_Sunday", "Add_Delta_Days",
	"Week_Number", "Day_of_Week", "Month_to_Text", "Day_of_Week_Abbreviation",
	"Decode_Language", "Language");
use PostScript::Simple;
use sigtrap qw(die INT QUIT);
use Getopt::Std;

$VERSION = "0.3.2";

# Parameter
getopts('o:y:t:hvn');

if ($opt_h)
{
	print <<'EOF';
    
Aufruf: jahreskalender.pl [-o Datei] [-y Jahr] [-h]
--------------------------------------------------------------------------------

BITTE        Die Wahl der Sprache für den Kalender erfolgt abhängig von der
BEACHTEN!    Sprachumgebung Ihres Betriebssystemes. Dies gilt aber nur für die
             Tage und Monatsnamen - Feiertage bleiben auf Deutsch. Dies gilt
             nur für Unix -- auf anderen Plattformen wird stets Deutsch
             verwendet.

-h           Gibt diesen Hilfetext aus.

-v           Gibt die Version des Programmes aus.

-o Datei     Der Kalender wird in Datei kopiert, anstatt ausgedruckt zu werden.
             Normalerweise erfolgt die Ausgabe ins Postscript-Format, außer
             Datei endet auf .pdf, dann wird nach PDF konvertiert (erfordert
             das Programm `ps2pdf').

-y Jahr      Erstellt einen Kalender für Jahr. Das Jahr muss vierstellig
             angegeben werden. Fehlt dieser Parameter, wird das aktuelle Jahr
             genommen.

-t Termine   Gibt einen Dateinamen an, in dem sich Termine befinden. Diese wer-
             den in das freie Feld gedruckt; Feiertage werden durch Termine
             überschrieben. Der Aufbau der Datei ist einfach: Jede Zeile enthält
             einen Termin (Format TT.MM. oder TT.MM.JJJJ), gefolgt von einem
             (oder mehreren) Leerzeichen/Tabulatoren mit anschließender Be-
             zeichnung. Kommentare können mit `#' am Zeilenanfang gesetzt 
             werden. Termine in einem anderen Jahr werden einfach ignoriert.

-n           Feiertage werden nur fett gedruckt, nicht beschriftet. Diese
             Einstellung ist nützlich für das Erstellen fremdsprachiger
             Kalender.

--------------------------------------------------------------------------------
           
EOF
    exit 0;
}

END {
	unlink("/tmp/kalenderdruck-$$.ps");
}

# Version ausgeben
if ($opt_v) 
{
	print "Jahreskalender.pl, Version $VERSION\n";
	exit 0;
}

# Welches Jahr?
$YEAR = $opt_y || (localtime())[5]+1900;

# Ausdruck in Datei? -- - heißt STDOUT
$DATEI = $opt_o || "";

# Termindatei
$TERMINFILE = $opt_t || "";

# Feiertage
$HOLIDAYS = $opt_n ? 0 : 1;

# Sprache setzen
$LANG = defined $ENV{LANG} ? substr($ENV{LANG}, 0, 2) : "de";
Language(Decode_Language($LANG));

$p = PostScript::Simple->new(landscape => 1,
							units => 'mm',
							papersize => 'A4',
							colour => 1,
							page => 1,
							reencode => 'ISOLatin1Encoding',
							eps => 0,
						);

$monat = 1;
						
foreach $page (1, 2) 
{
	$p->newpage($page);
	
	$p->setfont('Helvetica-Bold-iso', 200);
	$p->setcolour((0xE9, 0xE9, 0xE9));
	$p->text(70, 80, $YEAR);
	$p->setcolour("black");
	$p->setlinewidth(0.7);

	# Rahmen und Titel
	$p->box(20, 20, 277, 190);

	# vertikale Linien
	for ($i = 1; $i <= 5; $i++) 
    {
		$p->line((257/6*$i + 20), 20, (257/6*$i + 20), 190);
	}

	$p->line(20, 183, 277, 183);
	
	$p->setfont('Times-Bold-iso', 12);
	for ($monat = 1+($page-1)*6; $monat <= 6*$page; $monat++) 
    {	
		$p->text(257/6*($monat-6*($page-1)-1)+23, 185,
			Month_to_Text($monat));
	}

	$p->setlinewidth(0.1);
	# vertikale Linien
	for ($i = 0; $i <= 5; $i++) 
    {
		$p->line((257/6*$i + 31), 20, (257/6*$i + 31), 183);
	}
	
	# horizontale Linien
	for ($i = 1; $i < 31; $i ++) 
    {
		$p->line(20, (183-163/31*$i), 277, (183-163/31*$i));
	}

	# Text einfügen
	for ($monat = 1+($page-1)*6; $monat <= 6*$page; $monat++) 
    {	
		for ($tag = 1; $tag <= 31; $tag++) 
        {
			if ($tag < 10) 
            {
				$zusatz = 1.75;
			}
            else 
            {
				$zusatz = 0;
			}

			if ($tag <= Days_in_Month($YEAR, $monat)) 
            {
				$p->setfont('Helvetica-iso', 9);

				
				# Wochennummer am Monatsanfang
				if ($tag == 1 and Day_of_Week($YEAR, $monat, $tag) == 1) {
					$p->setfont('Helvetica-iso', 7);
					$p->text((257/6*($monat-6*($page-1)-1)+59),
						(183-163/31*($tag-1)-2.5), 
						get_week_string($YEAR, $monat, $tag+1));
					$p->setfont('Helvetica-iso', 9);
				}
					
				# Tage mit Beschriftung (Sonntag, Termine, Feiertage)
				if (Day_of_Week($YEAR, $monat, $tag) == 7 or
					get_feiertag($tag, $monat) or get_termin($tag, $monat)) 
                {
					# Termine
					if (get_termin($tag, $monat)) 
                    {
						$p->text(257/6*($monat-6*($page-1)-1)+32,
							(183-163/31*$tag+1.5), 
							get_termin($tag, $monat));

					}

					# Sonntage
					if (Day_of_Week($YEAR, $monat, $tag) == 7) 
                    {
						# Abschlusslinie
						$p->setlinewidth(0.5);
						$p->line((257/6*($monat-6*($page-1)-1)+20),
							(183-163/31*$tag),
							257/6*($monat-6*($page-1))+20,
							(183-163/31*$tag),);

						# Wochennummer normal
						if ($tag != Days_in_Month($YEAR, $monat)) 
                        {
							$p->setfont('Helvetica-iso', 7);
							$p->text((257/6*($monat-6*($page-1)-1)+59),
								(183-163/31*$tag-2.5), 
								get_week_string($YEAR, $monat, $tag+1));
						}
							
						$p->setlinewidth(0.1);
						$p->setfont('Helvetica-Bold-iso', 9);
					}

					# Feiertag
					if (get_feiertag($tag, $monat)) 
                    {
						$p->setfont('Helvetica-iso', 9);
						unless (get_termin($tag, $monat)) 
                        {
							$p->text(257/6*($monat-6*($page-1)-1)+32,
								(183-163/31*$tag+1.5), 
								get_feiertag($tag, $monat));
						}
						$p->setfont('Helvetica-Bold-iso', 9);
					}

				}

				# Tagzahl
				$p->text(257/6*($monat-6*($page-1)-1)+21.5+$zusatz, 
					(183-163/31*$tag+1.5),
					$tag);

				# Wochentag
				$p->text(257/6*($monat-6*($page-1)-1)+25.5, 
					(183-163/31*$tag+1.5), substr(Day_of_Week_Abbreviation(
						Day_of_Week($YEAR, $monat, $tag)), 0, 2));
			}
		}
	}
}


if ($DATEI eq "") 
{
    # Drucken
	if ($^O =~ /Win/i) 
    {
		print STDERR "Drucken unter Windows wird nicht unterstützt.\n";
		print STDERR "Erzeugen Sie eine Postscript-Datei und drucken sie mit Ghostscript aus.\n";
	}
	my $printer = defined $ENV{PRINTER} ? "-P$ENV{PRINTER}" : "";
    $p->output("/tmp/kalenderdruck-$$.ps");
    system("cat /tmp/kalenderdruck-$$.ps | psselect -o -q | lpr $printer");
    print STDERR "ENTER drücken, um fortzufahren ...";
    $test = <STDIN>;
    system("cat /tmp/kalenderdruck-$$.ps | psselect -e -q | lpr $printer");
}
else
{
    if ($DATEI =~ /\.pdf$/) 
    {
        $DATEI =~ s/\.pdf$/.ps/;
        $p->output($DATEI);
        system("ps2pdf $DATEI");
        unlink($DATEI);
    }
    else 
    {
        $p->output($DATEI);
    }
}

sub get_week_string 
{
	my ($YEAR, $monat, $tag) = @_;
	my $week;

	$week = Week_Number($YEAR, $monat, $tag);

	$week = $week == 53 ? 1 : $week;

	return $week < 10 ? "  ".$week : "".$week;
}

sub get_feiertag 
{
	my ($tag, $monat) = @_;

	@normal_holidays = (
		[  1,  1, "Neujahr" ],
		[  1,  6, "Hl. 3 K\xF6nige" ],
		[  5,  1, "Tag d. Arbeit"],
		[  8, 15, "Mari\xE4 Himmelfahrt" ],
		[ 11,  1, "Allerheiligen" ],
		[ 12, 25, "1. Weihnachtsfeiert." ],
		[ 12, 26, "2. Weihnachtsfeiert." ],
	);
	
	# Nationalfeiertag
	# 3. Oktober
	if ($YEAR >= 1990) 
    {
		push @normal_holidays, [ 10, 3, "Tag der dt. Einheit" ];
	}
	# 17. Juni 1953 (bin nicht sicher, wann der eingeführt wurde)
	if ($YEAR <= 1990 && $YEAR >= 1954) 
    {
		push @normal_holidays, [ 6, 17, "Nationalfeiertag" ];
	}

	for ($i = 0; $i < @normal_holidays; $i++) 
    {
		if ($normal_holidays[$i][0] == $monat &&
			$normal_holidays[$i][1] == $tag) 
        {
			return $HOLIDAYS ? $normal_holidays[$i][2] : " ";
		}
	}


	# christl. Feiertage mit Bezug auf Ostern
	# Berechnung aufgrund der Gauß'schen Osterformel (siehe Doku von Date::Calc)

	my (undef, $em, $ed) = Easter_Sunday($YEAR);
	
		#
		# Feiertage (aus der Dokumentation zu Date::Calc):
		# Ostersonntag 	- 2 : Karfreitag
		#				± 0 : Ostersonntag
		#				+ 1 : Ostermontag
		#				+39 : Christi Himmelfahrt ("Vatertag") (nicht bundeseinh.)
		#				+49 : Pfingstsonntag
		#				+50 : Pfingstmontag
		#				+60 : Fronleichnam (nicht bundeseinheitl.)

	my @namen = ("Karfreitag", "Ostersonntag", "Ostermontag", 
		"Christi Himmelfahrt", "Pfingstsonntag", "Pfingstmontag", "Fronleichnam");
	
	$i = 0;
	foreach (-2, 0, +1, +39, +49, +50, +60) 
    {
		if ((Add_Delta_Days($YEAR, $em, $ed, $_))[1] == $monat &&
			(Add_Delta_Days($YEAR, $em, $ed, $_))[2] == $tag) 
        {
			return $HOLIDAYS ? $namen[$i] : " ";
		}
		$i++;
	}
	
	return 0;
}

{
	my @termine;	# statische Variable in C/C++

	sub parse_termine 
    {

		if ($TERMINFILE eq "") 
        {
			return;
		}

		open (TERMINE, "<$TERMINFILE") or die "Die Termindatei $TERMINFILE konnte ".
			"nicht geöffnet werden: $!";

		while (<TERMINE>) 
        {
			if (/^#/ or /^\s+$/) 
            {
				next;
			}
            else 
            {
				my ($tag, $monat, $jahr, $bezeichnung);
				if (/^\d{2}\.\d{2}\.\d{4}\s+/) 
                {
                    ($tag, $monat, $jahr, $bezeichnung) = 
                            /^(\d{2})\.(\d{2})\.(\d{4})\s+(.*)$/;
					if ($jahr != $YEAR) 
                    {
                        next;
					}
				}
                elsif (/^\d{2}\.\d{2}\.\s+/) 
                {
					($tag, $monat, $bezeichnung) = /^(\d{2})\.(\d{2})\.\s+(.*)$/;
				}
                else 
                {
					next;
				}
				$bezeichnung =~ s/-/­/g;	# kurze Bindestriche
				push @termine, [ $monat, $tag, $bezeichnung ];
			}
		}
        
		close TERMINE or die "Die Termindatei $TERMINFILE konnte nicht ".
			"geschlossen werden: $!";
	}
    
	sub get_termin
    {
        
		my ($tag, $monat) = @_;
        
		if ($TERMINFILE eq "") 
        { 
			return 0;
		}
        
		if (!defined(@termine)) 
        {
			parse_termine();
		}
        
		for ($i = 0; $i < @termine; $i++) 
        {
			if ($termine[$i][0] == $monat &&
					$termine[$i][1] == $tag) 
            {
				return $termine[$i][2];
			}
		}
        
		return 0;
	}
}

# vim: set sw=4 ts=4 noet:
