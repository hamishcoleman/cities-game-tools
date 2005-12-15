#!/usr/bin/perl
use strict;
use warnings;
#
# This is a CGI script that acts as a proxy for the cities game.
# 
# This script handles the /cgi-bin/game page
#

##########################################################################
#
# Libs we need.
use Data::Dumper;
use CGI ':all';
use CGI::Carp qw(fatalsToBrowser);

use cities;

##########################################################################
#
# Determine exactly what options were used to call this script
my $query = new CGI;

if (!$query->request_method) {
	print "You must be testing me\n";
}

my $realpage=$cities::baseurl . '/cgi-bin/game';

### DIG HERE
my ($res,$send_cookie,$tree) = gettreefromurl($query,$realpage);

handle_simple_cases($res);

##########################################################################
#
# Adjust URLs to point to the right places

adjusturls($tree,$realpage);


##########################################################################
#
# Extract saliant data from the information and store it.

# FIXME - error checking
open(LOG,">>$cities::logfile");

my $gametime=''; 
my $gameX='';
my $gameY='';
my $gamelog='';

#
# Extract the log contents
my $textin = $tree->look_down(
		'_tag', 'textarea',
		'class','textin'
	);
if (defined $textin) {
	#$gamelog = $textin->as_trimmed_text();
	$gamelog = $textin->as_text();
	if ($gamelog) {
		print LOG "$gamelog";
	}
}

# Extract various abilities and controls
for my $i ($tree->look_down(
		'_tag', 'div',
		'class', 'controls')) {
	my $text = $i->as_trimmed_text();

	# id="location"
	if ($text =~ m/gives the exact location.* ([\d]+)([EW]) and ([\d]+)([NS])/) {
		# Found a Marker stone
		if ($2 eq 'W') { $gameX = -$1; } else { $gameX=$1; }
		if ($4 eq 'S') { $gameY = -$3; } else { $gameY=$3; }
		print LOG "LOC: $gameX, $gameY\n";
	} elsif ($text =~ m/(\d+)([EW]) (\d+)([NS])/) {
		# Natural location ability
		# TODO - check that this reads the GPS
		# FIXME - this reads the guide to time and space :-(
		if ($2 eq 'W') { $gameX = -$1; } else { $gameX=$1; }
		if ($4 eq 'S') { $gameY = -$3; } else { $gameY=$3; }
		print LOG "LOC: $gameX, $gameY\n";
	}

	if ($text =~ m/(\d\d?:\d\d[ap]m)/) {
		# Found a clock
		$gametime = $1;
		print LOG "TIME: $gametime\n";
	}
	#TODO - substitute a time guess?
}

#(in future, guess co-ordinates based on movement?)

#print LOG "$gametime: $gameY,$gameX: $gamelog\n";

#get surroundings
my $surroundings = $tree->look_down(
		'_tag', 'table',
		'width','500'
	);
if (defined $surroundings) {
	#print LOG $surroundings->address('.3.3.0')->as_trimmed_text() . "\n";
	for my $row (1, 3, 5) {
		for my $col (1, 3, 5) {
			my $loc = $surroundings->address(".$row.$col");
			my $div = $loc->address(".0");
			if (!defined $div) {
				next;
			}
			print LOG 'SUR: ',
				int($col/2)-1 , ', ' ,
				-(int($row/2)-1) , ', "' ,
				$loc->attr('class') , '", "' ,
				$div->as_trimmed_text() , "\"\n";
		}
	}
}

#Look for the map and read it
my $map;
for my $i ($tree->look_down(
		'_tag', 'table',
		'border', '0',
		'cellpadding', '0',
		'cellspacing', '0')) {
	my $element = $i->address('.0.0');
	if (!defined $element) {
		next;
	}
	my $maybe = $element->attr('class');
	if (defined $maybe && $maybe =~ m/map_loc/) {
		$map = $i;
	}
}

# TODO - look for the text "Small Map:"
# TODO - look for the text "Big Map:"

if (defined $map) {

	if (defined $map->address(".14.14")) {
		# its a Big Map, but not a really big map (oh woe is my 20x20)
		for my $row (0..14) {
			for my $col (0..14) {
				my $loc = $map->address(".$row.$col");
				if (!defined $loc) {
					next;
				}
				print LOG 'MAP: ',
					$col-7 , ', ' ,
					-($row-7) , ', "' ,
					$loc->attr('class') , "\"\n";
			}
		}
	} elsif (defined $map->address(".10.10")) {
		# its a Map
		for my $row (0..10) {
			for my $col (0..10) {
				my $loc = $map->address(".$row.$col");
				if (!defined $loc) {
					next;
				}
				print LOG 'MAP: ',
					$col-5 , ', ' ,
					-($row-5) , ', "' ,
					$loc->attr('class') , "\"\n";
			}
		}
	} else {
		# its a Small Map
		for my $row (0..4) {
			for my $col (0..4) {
				my $loc = $map->address(".$row.$col");
				if (!defined $loc) {
					next;
				}
				print LOG 'MAP: ',
					$col-2 , ', ' ,
					-($row-2) , ', "' ,
					$loc->attr('class') , "\"\n";
			}
		}
	}
}

#update database with map details

close(LOG);
##########################################################################
#
# Modify the tree to include data from our database

# simple insert of standing stones onto the map
for my $i ($tree->look_down(
		'_tag', 'td',
		'class', 'loc_stone map_loc')) {
	$i->push_content("S");
}


##########################################################################
#
# Output our changed HTML document
print $query->header( -cookie=>$send_cookie, );

print $tree->as_HTML;

$tree=$tree->delete;

