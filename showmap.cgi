#!/usr/bin/perl
use strict;
use warnings;
#
# Print out a HTML map from the log file
#
use CGI ':all';
use CGI::Carp qw(fatalsToBrowser);
use Data::Dumper;

my $logfile = '/home/hamish/WWW/test/gamelog.txt';

# Map key translations
my %shortname = (
	Alchemist => 'A',
	'Eastern Market Office' => 'o',
	'Eastern Market' => 'm',
	'Guard Tower' => 'G',
	Hospital => 'H',
	Marker => '.',
	Monastry => 'M',
	'Southern Marker' => '.',

);

my $query = new CGI;

my $x=20000;
my $y=20000;

my $max_x=-20000;
my $max_y=-20000;
my $min_x=20000;
my $min_y=20000;

sub setminmax($$) {
	my ($x,$y) = @_;

	if ($x>$max_x) {
		$max_x=$x;
	}
	if ($y>$max_y) {
		$max_y=$y;
	}
	if ($x<$min_x) {
		$min_x=$x;
	}
	if ($y<$min_y) {
		$min_y=$y;
	}
}

my %map;

open LOG,$logfile or die "could not open $logfile $!\n";

while(<LOG>) {
	#print $_;
	chomp;
	if ( $_ =~ m/^LOC: (-?\d+), (-?\d+)/ ) {
		$x=$1;
		$y=$2;
		#print "LOC: $x, $y\n";
	} elsif ( $_ =~ m/^SUR: (-?\d+), (-?\d+), "([^"]+)", "([^"]+)"/) {
		my $thisx = $x+$1;
		my $thisy = $y+$2;
		my $class = $3;
		my $name = $4;
		$class =~ s/location //;
		$map{$thisy}{$thisx}{class} = $class;
		$map{$thisy}{$thisx}{name} = $name;
		$map{$thisy}{$thisx}{lines} .= " $.";
		setminmax($thisx,$thisy);
		#print "SUR: $thisx, $thisy, '$class', '$name'\n";
	} elsif ( $_ =~ m/^MAP: (-?\d+), (-?\d+), "([^"]+)"/) {
		my $thisx = $x+$1;
		my $thisy = $y+$2;
		my $class = $3;
		$class =~ s/ map_loc//;
		$map{$thisy}{$thisx}{class} = $class;
		setminmax($thisx,$thisy);
		#print "MAP: $thisx, $thisy, '$class'\n";
	} elsif ( $_ =~ m/^You go North./) {
		$y++;
		#print "LOC: $x, $y\n";
	} elsif ( $_ =~ m/^You go South./) {
		$y--;
		#print "LOC: $x, $y\n";
	} elsif ( $_ =~ m/^You go East./) {
		$x++;
		#print "LOC: $x, $y\n";
	} elsif ( $_ =~ m/^You go West./) {
		$x--;
		#print "LOC: $x, $y\n";
	}
	setminmax($x,$y);
}

close(LOG);

print $query->header();

print "<html><head><title>Cities Map</title>\n",
	 '<link href="http://cities.totl.net/game.css" media="screen" rel="stylesheet" type="text/css">', "\n",
	"</head><body>\n",
	"<table border=0 cellpadding=0 cellspacing=0>\n";

# Stick an index along the top
print " <tr>\n";
for my $col ($min_x..$max_x) {
	if ($col%10==0) {
		print "  <td>$col</td>\n";
	} else {
		print "  <td></td>\n";
	}
}
print " </td>\n";

my $row=$max_y;
while ($row>$min_y-1) {
	print " <tr>\n";
	
	# Index the left
	if ($row%10==0) {
		print "  <td>$row</td>\n";
	} else {
		print "  <td></td>\n";
	}

	for my $col ($min_x..$max_x) {
		if (defined $map{$row}{$col}{class}) {
			print '<td class="',
				$map{$row}{$col}{class},
				' map_loc">';
			my $name = $map{$row}{$col}{name};
			my $empty=1;
			if (defined $name && defined $shortname{$name}) {
				print $shortname{$name};
				$empty=0;
			}
			if ($col==$x && $row==$y) {
				print "<b>X</b>";
				$empty=0;
			}
			if ($empty) {
				print "&nbsp;"
			}
			print '</td>';
		} else {
			print '<td class="map_loc">?</td>';
		}
	}

	# Index the right
	if ($row%10==0) {
		print "<td>$row</td>\n";
	}

	print " </tr>\n";
	$row--;
}

# Stick an index along the bottom
print " <tr>\n";
for my $col ($min_x..$max_x) {
	if ($col%10==0) {
		print "  <td>$col</td>\n";
	} else {
		print "  <td></td>\n";
	}
}
print " </td>\n";

print " </table> </body> </html>\n";

#print "map size [$min_x,$min_y] - [$max_x,$max_y]\n";
#print "last location: $x, $y\n";
#print Dumper(\%map);


