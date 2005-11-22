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

# Check that the user has actually asked for something
#
my $realpage=url_param('realpage');
if (! defined $realpage) {
	print $query->header;
	print "404 No real page requested\n";
	exit;
}
$query->delete('realpage');

### DIG HERE
my ($res,$send_cookie,$tree) = gettreefromurl($query,$realpage);

if (!$res->is_success) {
        print $res->status_line, "\n";
        exit;
}

if ($res->content_type ne 'text/html') {
	# awooga, awooga, this is not a parseable document...
	print $query->header($res->content_type);
	print $res->content;
	exit;
}

##########################################################################
#
# Adjust URLs to point to the right places
my $selfurl = url(-relative=>1);

# Modify things and generally act wierd

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

#links
for my $i ($tree->look_down(
		"_tag", "a", )) {
	my $href = $i->attr('href');

	if ($href eq '/cgi-bin/game') {
		# FIXME - handle game calls differently
		next;
	}

	my $ref = resolve_url($realpage,$href);
	if ($ref =~ m%^http://cities.totl.net/%) {
		$i->attr('href',$selfurl . '?realpage='.$ref);
	}
}

##forms
#for my $i ($tree->look_down(
#		"_tag", "form",
#		"action","/cgi-bin/game")) {
#	$i->attr('action',$selfurl);
#}
#
##foo! textarea
#for my $i ($tree->look_down(
#		"_tag", "textarea",
#		"class","textin")) {
#	$i->push_content("\nfoo!");
#}

##########################################################################
#
# Extract saliant data from the information and store it.

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


