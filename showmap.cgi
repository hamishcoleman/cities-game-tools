#!/usr/bin/perl
use strict;
use warnings;
#
# Print out a HTML map from the log file
#
# TODO:
# - write out the current map as an inputfile
# - write out the current map as a perl struct, then load it on startup
# - 
#
#
use CGI ':all';
use CGI::Carp qw(fatalsToBrowser);
use Data::Dumper;

use cities;

# Map key translations
my %shortname = (
#	Alchemist => 'A',
	'Cottage Hospital' => 'H',
	'Doctor' => 'H',
	'E. Market Outlet' => 'm',
	'E. Market Local Office' => 'o',
	'Eastern Market Office' => 'o',
	'Eastern Market' => 'm',
	'Eastern Marker' => '.',
	'First Aid Point' => 'H',
	'Flood' => 'F',
	'Graveyard' => 'g',
#	'Guard Tower' => 'G',
	Healer => 'H',
	'Healing Field' => 'H',
	'Herbert the Healer' => 'H',
	Hospital => 'H',
	'Ice Station' => 'I',
	'Ice Trail' => '~',
	'Jude' => 'H',
	'Kill or Cure' => 'H',
	Marker => '.',
	Monastry => 'M',
	'Night Shrine' => '*',
	'Nightfall Shrine' => '*',
	'N. Market Outlet' => 'm',
	'N. Market Local Office' => 'o',
	'Northern Marker' => '.',
	'Northern Market' => 'm',
	'Northern Market Office' => 'o',
	'Oil Platform' => 'O',
	'Road Marker' => '.',
#	Ruin
	'Shrine of the Light' => '*',
	'S. Market Outlet' => 'm',
	'S. Market Local Office' => 'o',
	'Southern Market Office' => 'o',
	'Southern Market' => 'm',
	'Southern Marker' => '.',
	'Standing Stone' => 'S',
	'Stone Circle' => '*',
	'Track' => '~',
	'Trading Post' => 'T',
	Trail => '~',
	'W. Market Outlet' => 'm',
	'W. Market Local Office' => 'o',
	'Western Marker' => '.',
#	Well
#	'Wizards Tower' => 'W',

	# An unknown city square
	'Unknown Building' => '?',
);

my $query = new CGI;

my $x=20000;
my $y=20000;

my $max_x;
my $max_y;
my $min_x;
my $min_y;


my %map;
# storage for minimums and maximums
my %map_x;

open LOG,$cities::logfile or die "could not open $cities::logfile $!\n";

# Read the log file
while(<LOG>) {
	#print $_;
	chomp;
	if ( $_ =~ m/^LOC: (-?\d+), (-?\d+)/ ) {
		$x=$1;
		$y=$2;
		#print "LOC: $x, $y\n";
	} elsif ( $_ =~ m/^VISIT: (-?\d+), (-?\d+)/) {
		my $thisx = $1;
		my $thisy = $2;
		$map{$thisy}{$thisx}{visited}++;
	} elsif ( $_ =~ m/^SUR: (-?\d+), (-?\d+), "([^"]+)", "([^"]*)"/) {
		my $thisx = $x+$1;
		my $thisy = $y+$2;
		my $class = $3;
		my $name = $4;
		my $visited=0;
		if ($1 == 0 && $2 == 0) {
			$visited=1;
		}
		$class =~ s/location //;
		$map{$thisy}{$thisx}{class} = $class;
		if ($name) {
			$map{$thisy}{$thisx}{name} = $name;
		}
		if ($visited) {
			$map{$thisy}{$thisx}{visited}++;
		}
		$map_x{$thisx}=1;
		$map{$thisy}{$thisx}{lines} .= " $.";
		#print "SUR: $thisx, $thisy, '$class', '$name'\n";
	} elsif ( $_ =~ m/^MAP: (-?\d+), (-?\d+), "([^"]+)"/) {
		my $thisx = $x+$1;
		my $thisy = $y+$2;
		my $class = $3;
		$class =~ s/ map_loc//;
		if (defined $map{$thisy}{$thisx}{class} &&
		    $map{$thisy}{$thisx}{class} ne $class) {
			delete $map{$thisy}{$thisx}{name};
		}
		$map{$thisy}{$thisx}{class} = $class;
		$map_x{$thisx}=1;
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
	} elsif ( $_ =~ m/^OLD: (-?\d+), (-?\d+), "([^"]*)", "([^"]*)"/) {
		# An old location that I have preloaded from my notes
		my $thisx = $1;
		my $thisy = $2;
		my $class = $3;
		my $name = $4;
		$class =~ s/location //;
		$map{$thisy}{$thisx}{class} = $class;
		$map{$thisy}{$thisx}{name} = $name;
		$map_x{$thisx}=1;
		#print $_,"\n";
		#print "OLD: $thisx, $thisy, '$class', '$name'\n";
	} elsif ( $_ =~ m/^OLD: (-?\d+), (-?\d+), "([^"]*)"/) {
		# An old location that I have preloaded from my notes
		my $thisx = $1;
		my $thisy = $2;
		my $class = $3;
		$class =~ s/location //;
		$map{$thisy}{$thisx}{class} = $class;
		$map_x{$thisx}=1;
		#print $_,"\n";
		#print "OLD: $thisx, $thisy, '$class', '$name'\n";
	}
}
close(LOG);

print $query->header();

my @xvals = sort {$a<=>$b} keys %map_x;
my @yvals = sort {$a<=>$b} keys %map;

$min_x=$ARGV[0] || shift(@xvals);
$max_x=$ARGV[1] || pop(@xvals);
$min_y=$ARGV[2] || shift(@yvals);
$max_y=$ARGV[3] || pop(@yvals);

my $want_visits = ! $ARGV[4];

print "<html><head><title>Cities Map</title>",
#	 '<link href="http://cities.totl.net/game.css" media="screen" rel="stylesheet" type="text/css">',
	 '<link href="game.css" media="screen" rel="stylesheet" type="text/css">',
	"</head><body>\n";

print "<p>map size [$min_x,$max_y] - [$max_x,$min_y]</p>\n";
print "<p>LOC: $x, $y</p>\n";
#print Dumper(\%map);

print "<table border=1><tr><th>icon</th><th>Full Name</th></tr>\n";
for my $i (sort {$shortname{$a} cmp $shortname{$b}} keys %shortname) {
	print "<tr><th>$shortname{$i}</th><td>$i</td></tr>\n";
}
print "</table>\n";

print "<table border=0 cellpadding=0 cellspacing=0>\n";

# Stick an index along the top
print "<tr>";
my $skip = 1;
for my $col ($min_x..$max_x) {
	if ($col%10==0) {
		print "<td align='right' colspan=$skip>$col</td>";
		$skip=1;
	} else {
		$skip++;
	}
}
print "</tr>\n";

my $row=$max_y;
while ($row>$min_y-1) {
	print "<tr>";
	
	# Index the left
	if ($row%10==0) {
		print "<td>$row</td>";
	} else {
		print "<td>&nbsp;</td>";
	}

	my $skip = 0;
	for my $col ($min_x..$max_x) {
		my $class = $map{$row}{$col}{class};
		my $name = $map{$row}{$col}{name};
		if (defined $class) {
			if ($skip) {
				print "<td colspan=$skip></td>";
				$skip=0;
			}
			print '<td class="', $class, ' map_loc">';
			my $empty=1;

			# Show my last position
			# FIXME - something is uninitialized here...
			if ($col==$x && $row==$y) {
				print "<b>X</b>";
				$empty=0;
			}

			# Mark crazy standing stones...
			if ($empty && $class eq 'loc_stone' && !defined $name) {
				$name = 'Standing Stone';
			}

			# Mark unknown city squares
			if ($empty && $class eq 'loc_city' && !defined $name) {
				$name = 'Unknown Building';
			}

			# If we have a map key for this location, use it
			if ($empty && defined $name && defined $shortname{$name}) {
				print $shortname{$name};
				$empty=0;
			} 

			if ($want_visits && $empty && $map{$row}{$col}{visited}) {
			#if ($class eq 'loc_desert' && $name eq 'Great Desert' 
			#		&& $map{$row}{$col}{visited}) {
				# mark the paths though the desert
				# (this assumes that I only walk where it is safe ... )
				print '+';
				$empty=0;
			}

			# no grid square should be empty
			if ($empty) {
				print "&nbsp;"
			}
			print '</td>';
		} else {
			# we know no information regarding this square
			$skip++;
			#print '<td>&nbsp;</td>';
		}
	}

	# 
	if ($skip) {
		print "<td colspan=$skip></td>";
		$skip=0;
	}

	# Index the right
	if ($row%10==0) {
		print "<td>$row</td>";
	}

	print "</tr>\n";
	$row--;
}

# Stick an index along the bottom
print "<tr>";
$skip=1;
for my $col ($min_x..$max_x) {
	if ($col%10==0) {
		print "<td align='right' colspan=$skip>$col</td>";
		$skip=1;
	} else {
		$skip++;
	}
}
print "</tr>\n";

print "</table>\n";

# TODO - print out the key

print "</body></html>\n";


