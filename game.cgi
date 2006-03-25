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
use CGI ':all';
use CGI::Carp qw(fatalsToBrowser);
use Data::Dumper;

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
my ($req,$recv_cookie) = makereqfromquery($query,$realpage);
my ($res,$send_cookie,$send_cookie_val,$tree) = maketreefromreq($req);

handle_simple_cases($res);

##########################################################################
#
# Adjust URLs to point to the right places

adjusturls($tree,$realpage);

##########################################################################
#
# Extract saliant data from the information and store it.

my $d;
$d->{_state} = 'unknown';

addcookie($d,$send_cookie_val,$recv_cookie);
screenscrape($tree,$d);

# TODO - determine what to do about various states..
if ($d->{_state} eq 'loggedin') {
	computelocation($d);
	dumptogamelog($d);
	dumptodb($d);
}

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

