#!/usr/bin/perl
use strict;
use warnings;
#
# Print out a HTML map from the log file
#
# TODO:
# - write out the current map as an inputfile
# - write out the current map as a perl struct, then load it on startup
#
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
	Healer => 'H',
	Hospital => 'H',
	Marker => '.',
	Monastry => 'M',
#	Ruin
	'Southern Marker' => '.',
	'Standing Stone' => 'S',
	'Trading Post' => 'T',
#	Trail
#	Well
	'Wizards Tower' => 'W',

	# An unknown city square
	'Unknown Building' => '?',
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
		setminmax($x,$y);
		#print "LOC: $x, $y\n";
	} elsif ( $_ =~ m/^SUR: (-?\d+), (-?\d+), "([^"]+)", "([^"]+)"/) {
		my $thisx = $x+$1;
		my $thisy = $y+$2;
		my $class = $3;
		my $name = $4;
		$class =~ s/location //;
		$map{$thisy}{$thisx}{class} = $class;
		$map{$thisy}{$thisx}{name} = $name;
		setminmax($thisx,$thisy);
		#$map{$thisy}{$thisx}{lines} .= " $.";
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
		setminmax($x,$y);
		#print "LOC: $x, $y\n";
	} elsif ( $_ =~ m/^You go South./) {
		$y--;
		setminmax($x,$y);
		#print "LOC: $x, $y\n";
	} elsif ( $_ =~ m/^You go East./) {
		$x++;
		setminmax($x,$y);
		#print "LOC: $x, $y\n";
	} elsif ( $_ =~ m/^You go West./) {
		$x--;
		setminmax($x,$y);
		#print "LOC: $x, $y\n";
	} elsif ( $_ =~ m/^OLD: (-?\d+), (-?\d+), "([^"]+)", "([^"]+)"/) {
		# An old location that I have preloaded from my notes
		my $thisx = $1;
		my $thisy = $2;
		my $class = $3;
		my $name = $4;
		$class =~ s/location //;
		$map{$thisy}{$thisx}{class} = $class;
		$map{$thisy}{$thisx}{name} = $name;
		setminmax($thisx,$thisy);
		#print $_,"\n";
		#print "OLD: $thisx, $thisy, '$class', '$name'\n";
	}
}

close(LOG);

print $query->header();

#print "map size [$min_x,$min_y] - [$max_x,$max_y]\n";
#print "last location: $x, $y\n";
#print Dumper(\%map);

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
		my $class = $map{$row}{$col}{class};
		my $name = $map{$row}{$col}{name};
		if (defined $class) {
			print '<td class="', $class, ' map_loc">';
			my $empty=1;

			# Mark crazy standing stones...
			if ($class eq 'loc_stone' && !defined $name) {
				$name = 'Standing Stone';
			}

			# Mark unknown city squares
			if ($class eq 'loc_city' && !defined $name) {
				$name = 'Unknown Building';
			}

			# If we have a map key for this location, use it
			if (defined $name && defined $shortname{$name}) {
				print $shortname{$name};
				$empty=0;
			} 
			# Show my last position
			if ($col==$x && $row==$y) {
				print "<b>X</b>";
				$empty=0;
			}

			# no grid square should be empty
			if ($empty) {
				print "&nbsp;"
			}
			print '</td>';
		} else {
			# we know no information regarding this square
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

print "</table>\n";

# TODO - print out the key

print "</body></html>\n";


