#!/usr/bin/perl
use strict;
use warnings;
#
# This is a CGI script that acts as a proxy for the cities game.
# The intent is to extract details out of pages, such as persistant mapping
# and event log file
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

##########################################################################
#
# Determine exactly what options were used to call this script
my $q = new CGI;

#TODO

#print "method=", request_method(), "\n";
#print "url_param()= ";
#print join ",", $q->url_param;
#print "\n";
#print "x= ";
#print join ",", $q->url_param('x');
#print "\n";

#get gamesession cookie

##########################################################################
#
# Duplicate the options and call the real game
my $ua = LWP::UserAgent->new;
$ua->agent("citiesproxy/1.0 ");

# construct URL from params
my $req = HTTP::Request->new(GET => $baseurl."/cgi-bin/game");
# set cookie
# set post params

my $res = $ua->request($req);

if (!$res->is_success) {
        print $res->status_line, "\n";
        exit;
}

##########################################################################
#
# Create a document tree from the returned data
my $tree = HTML::TreeBuilder->new;
$tree->ignore_ignorable_whitespace(0);
$tree->no_space_compacting(1);
$tree->store_comments(1);
$tree->parse($res->content);
$tree->eof;
$tree->elementify;

##########################################################################
#
# Adjust any relative URLs to point to the real game

# Modify things and generally act wierd
my $link = $tree->look_down(
	"_tag", "link",
	"rel", "stylesheet"
);
if ($link) {
	$link->attr('href',$baseurl.$link->attr('href'));
}

##########################################################################
#
# Extract saliant data from the information and store it.

##########################################################################
#
# Modify the tree to include data from our database

##########################################################################
#
# Output our changed HTML document
print $q->header;
print $tree->as_HTML;

$tree=$tree->delete;

##########################################################################
#
# Original text for comparison...
#print "\n=====================================\n";
#print $res->content;

