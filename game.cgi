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
# Configure it.
#
# (nothing much right now)
#
my $baseurl = "http://cities.totl.net";
my $logfile = "/home/hamish/WWW/test/gamelog.txt";

##########################################################################
#
# Libs we need.
use Data::Dumper;
use CGI ':all';
use CGI::Carp qw(fatalsToBrowser);
use LWP::UserAgent;
use HTML::TreeBuilder;
use HTTP::Cookies;

use cities;

##########################################################################
#
# Determine exactly what options were used to call this script
my $query = new CGI;

if (!$query->request_method) {
	print "You must be testing me\n";
}

my $realpage=$baseurl . '/cgi-bin/game';

### DIG HERE
my ($res,$send_cookie,$tree) = gettreefromurl($query,$realpage);

# there was an error of some kind
if (!$res->is_success) {
        print $res->status_line, "\n";
        exit;
}

# The data was not HTML, so we have no tree to process
if ($res->content_type ne 'text/html') {
	# awooga, awooga, this is not a parseable document...
	print $query->header($res->content_type);
	print $res->content;
	exit;
}

##########################################################################
#
# Adjust URLs to point to the right places

adjusturls($tree,$realpage);


##########################################################################
#
# Extract saliant data from the information and store it.

# FIXME - error checking
open(LOG,">>$logfile");

my $gametime=''; 
my $gameX='';
my $gameY='';
my $gamelog='';

my $textin = $tree->look_down(
		'_tag', 'textarea',
		'class','textin'
	);
if (defined $textin) {
	#$gamelog = $textin->as_trimmed_text();
	$gamelog = $textin->as_text();
	if ($gamelog) {
		print LOG "LOG: $gamelog\n";
	}
}

# Look for a Marker stone
for my $i ($tree->look_down(
		'_tag', 'div',
		'class', 'controls')) {
	my $text = $i->as_trimmed_text();
	if ($text =~ m/gives the exact location.* ([\d]+)([EW]) and ([\d]+)([NS])/) {
		if ($2 eq 'W') { $gameX = -$1; } else { $gameX=$1; }
		if ($4 eq 'S') { $gameY = -$3; } else { $gameY=$3; }
		print LOG "LOC: $gameX, $gameY\n";
	}
}
#get co-ordinates (in future, guess co-ordinates?)

#get game time or GMT

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
				int($row/2)-1 , ', "' ,
				$loc->attr('class') , '", "' ,
				$div->as_trimmed_text() , "\"\n";
		}
	}
}

#get map
#update database with map details

close(LOG);
##########################################################################
#
# Modify the tree to include data from our database

##########################################################################
#
# Output our changed HTML document
print $query->header(
	-cookie=>$send_cookie,
	);

print $tree->as_HTML;

$tree=$tree->delete;

