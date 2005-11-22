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

#foo! textarea
for my $i ($tree->look_down(
		"_tag", "textarea",
		"class","textin")) {
	$i->push_content("\nfoo!");
}

##########################################################################
#
# Extract saliant data from the information and store it.

#get game time or GMT
#get co-ordinates (in future, guess co-ordinates?)
#get textarea
#log all the above

#get map
#get surroundings
#update database with map details

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


