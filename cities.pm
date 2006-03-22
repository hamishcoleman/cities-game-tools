#!/usr/bin/perl
use strict;
use warnings;
#
# _LOGNAME_/_PASSWORD_
#

##########################################################################
#
# Configure it.
#
# (nothing much right now)
#
glob $cities::baseurl = "http://cities.totl.net";
glob $cities::logfile = "/home/hamish/WWW/cities/gamelog.txt";


=head1 NAME

cities.pm - set of common routines from my cities proxy

=cut

use proxy;

##########################################################################
#
# Adjust URLs to point to the right places
sub adjusturls($$) {
	my ($tree,$realpage) = @_;

	#my $selfurl = url(-relative=>1);
	my $otherurl = "other.cgi";
	my $gameurl = "game.cgi";

	#stylesheets
	for my $i ($tree->look_down(
			"_tag", "link",
			"rel", "stylesheet")) {
		$i->attr('href',resolve_url($realpage,$i->attr('href')));
	}

	#images
	for my $i ($tree->look_down(
			"_tag", "img" )) {
		$i->attr('src',resolve_url($realpage,$i->attr('src')));
	}

	# um, not an img but displays an img ??
	for my $i ($tree->look_down(
			"_tag", "input" )) {
		if ($i->attr('src')) {
			$i->attr('src',resolve_url($realpage,$i->attr('src')));
		}
	}

	# main game page form
	for my $i ($tree->look_down(
			"_tag", "form",
			"action","game")) {
		$i->attr('action',$gameurl );
	}

	# logout page form
	for my $i ($tree->look_down(
			"_tag", "form",
			"action","/cgi-bin/game")) {
		$i->attr('action',$gameurl );
	}

	#links
	for my $i ($tree->look_down(
			"_tag", "a", )) {
		my $href = $i->attr('href');

		# Handle the game page specially
		if ($href eq '/cgi-bin/game') {
			$i->attr('href',$gameurl );
			next;
		} elsif ($href eq 'game') {
			$i->attr('href',$gameurl );
			next;
		} elsif ($href =~ m%^game(\?.*)%) {
			$i->attr('href',$gameurl . $1);
			next;
		} elsif ($href =~ m%^\?(.*)%) {
			$i->attr('href', '?realpage='. $realpage . '&' . $1);
			next;
		}

		# Handle other urls with the "other.cgi" handler
		my $ref = resolve_url($realpage,$href);
		# FIXME - cities link hardcoded
		if ($ref =~ m%^http://cities.totl.net/%) {
			$i->attr('href',$otherurl . '?realpage='.$ref);
		}
	}
}

sub handle_simple_cases($) {
	my ($res) = @_;
	
	# there was an error of some kind
	if (!$res->is_success) {
		# FIXME - this is not right...
		my $query = new CGI;
		print $query->header;
		print $res->status_line, "\n\n";
		print $res->content;
		exit;
	}
	
	# The data was not HTML, so we have no tree to process
	if ($res->content_type ne 'text/html') {
		# awooga, awooga, this is not a parseable document...
		my $query = new CGI;
		print $query->header($res->content_type);
		print $res->content;
		exit;
	}
}

sub addvalue($$$$$) {
	my ($tree,$d,$key,$value,$name) = @_;
	my $node;

	$node = $tree->look_down($key,$value);
	if ($node) {
		$d->{$name} = $node->as_trimmed_text();
		return $d->{$name};
	}
	return undef;
}

sub addviewport($$) {
	my ($tree,$d) = @_;

	my $viewport = $tree->look_down('id','viewport');
	if (!$viewport) {
		# Something is wrong
		return;
	}

	my %mapping = (
		c  => [0, 0],

		n  => [0, 1],
		s  => [0, -1],
		e  => [1, 0],
		w  => [-1, 0],

		nw => [-1, 1],
		sw => [-1, -1],
		ne => [1, 1],
		se => [1, -1],
	);

	for my $id (keys %mapping) {
		my $square = $viewport->look_down('id',$id);
		if (!defined $square) {
			# maybe we cannot see that square?
			next;
		}
		my $div = $square->address('.0');
		if (!defined $div) {
			# Something is wrong
			next;
		}
		my $class = $square->attr('class');
		if ($class =~ /(loc_dark|loc_bright)/) {
			# We are not able to see anything here, so dont log it
			next;
		}

		my $x = $mapping{$id}[0];
		my $y = $mapping{$id}[1];
		
		$d->{viewport}->{$x}->{$y}->{class} = $class;
		$d->{viewport}->{$x}->{$y}->{name} = $div->as_trimmed_text();

	}
}

sub screenscrape($) {
	my ($tree) = @_;
	my $d;		# place to store our scrapings
	my $node;	# temp node value
	my $s;		# temp string value

	$d->{_state} = 'unknown';

	$node = $tree->look_down('_tag','title');
	if (!$node) {
		# No title?  something is wrong
		return $d;
	}
	$s = $node->as_trimmed_text();

	# FIXME - checking titles is somewhat fragile
	if ($s =~ m/^Cities - login$/) {
		$d->{_state} = 'loggedout';
	} elsif ($s =~ m/^Cities - bye$/) {
		$d->{_state} = 'loggedout';
	} else {
		# If not one of the above assume logged in
		$d->{_state} = 'loggedin';
	}

	# FIXME - very fragile
	$node = $tree->look_down(
		'_tag', 'div',
		'style', qr/^text/);
	if ($node) {
		$d->{_fullname} = $node->as_trimmed_text();
	}

	addvalue($tree,$d,'id','ap','ap');
	addvalue($tree,$d,'id','maxap','maxap');
	addvalue($tree,$d,'id','hp','hp');
	addvalue($tree,$d,'id','maxhp','maxhp');
	addvalue($tree,$d,'id','gold','gold');

	$node = $tree->look_down(
		'_tag','textarea',
		'class','textin');
	if ($node) {
		$d->{textin} = $node->as_text();
	}

	# id="inventory"

	addvalue($tree,$d,'id','long','long');
	addvalue($tree,$d,'id','lat','lat');
	# div id="abilities", span TIME

	# equippable clock
	# equippable GPS
	# marker stone

	# div id="item", span class="control_title", Big Map
	# div id="equipment", div id="item" ...

	addviewport($tree,$d);

	return $d;
}


1;

__END__

###### Include the logic from the game.cgi here as an example

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
	if (defined $map) {
		next;
	}
	my $maybe = $element->attr('class');
	if (defined $maybe && $maybe =~ m/map_loc/) {
		$map = $i;
	}
}

# TODO - look for the text "Small Map:"
# TODO - look for the text "Big Map:"
# TODO - clean this up into one function

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
				my $name = $loc->look_down(
					'_tag', 'span',
					'class', 'hideuntil');
				if (!defined $name) {
					print LOG 'MAP: ',
						$col-2 , ', ' ,
						-($row-2) , ', "' ,
						$loc->attr('class') , "\"\n";
				} else {
					print LOG 'SUR: ',
						$col-2 , ', ' ,
						-($row-2) , ', "' ,
						$loc->attr('class') , "\", \"",
						$name->as_trimmed_text(),
						"\"\n";
				}
			}
		}
	}
}

#update database with map details

