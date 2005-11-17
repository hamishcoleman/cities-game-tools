#!/usr/bin/perl
use strict;
use warnings;
#

my $baseurl = "http://cities.totl.net";

use Data::Dumper;

use CGI ':all';
use CGI::Carp qw(fatalsToBrowser);

use LWP::UserAgent;

#use HTML::TokeParser;
use HTML::TreeBuilder;

####
#### First, extract some details about how we were called

my $q = new CGI;

print $q->header;
#print "<pre>\n";
#
#print "method=", request_method(), "\n";
#print "url_param()= ";
#print join ",", $q->url_param;
#print "\n";
#print "x= ";
#print join ",", $q->url_param('x');
#print "\n";

####
#### Next duplicate that call to the real cities game

# Create a user agent object
my $ua = LWP::UserAgent->new;
$ua->agent("citiesproxy/1.0 ");

# Create a request
my $req = HTTP::Request->new(GET => $baseurl."/cgi-bin/game");

# Pass request to the user agent and get a response back
my $res = $ua->request($req);

# Check the outcome of the response
if (!$res->is_success) {
        print $res->status_line, "\n";
        exit;
}

## Simple Parse the content..
#my $p = HTML::TokeParser->new(\$res->content);
#
#while (my $token = $p->get_token) {
#	if( $token->[0] eq 'S' ) {
#		print $token->[4];
#	} elsif( $token->[0] eq 'E' ) {
#		print $token->[2];
#	} elsif( $token->[0] eq 'T' ) {
#		print $token->[1];
#	} elsif( $token->[0] eq 'C' ) {
#		print $token->[1];
#	} elsif( $token->[0] eq 'D' ) {
#		print $token->[1];
#	} elsif( $token->[0] eq 'PI' ) {
#		print $token->[2];
#	}
#}

# Parse the HTML document into a tree
my $tree = HTML::TreeBuilder->new;
$tree->ignore_ignorable_whitespace(0);
$tree->no_space_compacting(1);
$tree->store_comments(1);
$tree->parse($res->content);
$tree->eof;
$tree->elementify;

# Modify things and generally act wierd
my $link = $tree->look_down(
	"_tag", "link",
	"rel", "stylesheet"
);
if ($link) {
	$link->attr('href',$baseurl.$link->attr('href'));
}

# Output our changed HTML document
print $tree->as_HTML;

$tree=$tree->delete;

#print "\n=====================================\n";
#print $res->content;

