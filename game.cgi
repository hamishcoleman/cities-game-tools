#!/usr/bin/perl
use strict;
use warnings;
#
# This is a CGI script that acts as a proxy for the cities game.
# 
# This script handles the /cgi-bin/game page
#

# TODO - dont read locations that are part of the text of palintirs
#	(or other things non GPS/Intrinsic related ...)

##########################################################################
#
# Libs we need.
use CGI ':all';
use CGI::Carp qw(fatalsToBrowser);
use Data::Dumper;

$Data::Dumper::Indent = 1;
$Data::Dumper::Sortkeys = 1;

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
my ($res,$send_cookie,$recv_cookie,$send_cookie_val,$tree) = gettreefromurl($query,$realpage);

handle_simple_cases($res);

##########################################################################
#
# Adjust URLs to point to the right places

adjusturls($tree,$realpage);


##########################################################################
#
# Extract saliant data from the information and store it.

my $d = screenscrape($tree);
if (!defined $recv_cookie || !$recv_cookie || $recv_cookie eq 'null') {
	$d->{_cookie} = $send_cookie_val;
} else {
	$d->{_cookie} = $recv_cookie;
}

# FIXME - error checking
open(LOG,">>$cities::logfile");
print LOG Dumper($d);
close(LOG);

dumptogamelog($d);

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

#print "<!-- \n";
#print Dumper($res), "\n\n", Dumper($tree);

$tree=$tree->delete;

