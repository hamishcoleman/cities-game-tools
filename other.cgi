#!/usr/bin/perl
use strict;
use warnings;
#
# This is a CGI script that acts as a proxy for the cities game.
# 
# This script handles all 'other' pages (essentially anything that is not
# /cgi-bin/game
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

# Check that the user has actually asked for something
#
my $realpage=url_param('realpage');
if (! defined $realpage) {
	# FIXME - error message
	print $query->header;
	print "404 No real page requested\n";
	exit;
}

# This only works if it is not a POST, and even then, it never alters the url_param()
#$query->delete('realpage');

if ($realpage !~ m%$cities::baseurl/%) {
	# FIXME - error message
	print $query->header;
	print "404 Whatchatalknboutwillis\n";
	exit;
}

### DIG HERE
my ($res,$send_cookie,$tree) = gettreefromurl($query,$realpage);

handle_simple_cases($res);

##########################################################################
#
# Adjust URLs to point to the right places

adjusturls($tree,$realpage);

##########################################################################
#
# Output our changed HTML document
print $query->header( -cookie=>$send_cookie );

print $tree->as_HTML;

$tree=$tree->delete;

