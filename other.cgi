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


##########################################################################
#
# Determine exactly what options were used to call this script
my $q = new CGI;

my $request_method=$q->request_method();
if (!$request_method) {
	print "You must be testing me\n";
	$request_method="TEST";
}

my $postparamstr;
for my $i ($q->param) {
	if ($postparamstr) {
		$postparamstr .= "&";
	}
	$postparamstr .= $i.'='.$q->param($i);
}

my $urlparamstr="";
my $realpage;
for my $i ($q->url_param) {
	if (! defined $i) {
		# HUH?
		next;
	}
	if ($i eq 'realpage') {
		$realpage=$q->url_param($i);
		next;
	}
	if ($urlparamstr) {
		$urlparamstr .= "&";
	}
	$urlparamstr .= $i.'='. ($q->url_param($i)||'');
}
if ($urlparamstr eq 'keywords=') {
	undef $urlparamstr;
}

if (! defined $realpage) {
	print "No real page requested\n";
	exit;
}

#get gamesession cookie
my $user_gamesession_cookie = $q->cookie('gamesession');

##########################################################################
#
# Duplicate the options and call the real game
my $ua = LWP::UserAgent->new;
$ua->agent("citiesproxy/1.0 ");

# construct the correct URL from our params
my $url = $baseurl.$realpage;
if ($urlparamstr) {
	$url .= '?'.$urlparamstr;
}

my $req = HTTP::Request->new($request_method => $url);
if ($request_method eq 'POST') {
	$req->content_type('application/x-www-form-urlencoded');
	$req->content($postparamstr);
}
if ($user_gamesession_cookie) {
	$req->header(Cookie => 'gamesession='.$user_gamesession_cookie);
}

my $res = $ua->request($req);

if (!$res->is_success) {
        print $res->status_line, "\n";
        exit;
}

my $req_cookies = HTTP::Cookies->new();
$req_cookies->extract_cookies($res);

my $send_cookie;
sub cookie_callback() {
	my ($version,$key,$val,$path,$domain,$port,$path_spec,
	    $secure,$expires,$discard,$hash) = @_;

	if ($key eq 'gamesession') {
		$send_cookie = $q->cookie(
			-name=>$key,
			-value=>$val,
			-expires=>$expires,
		);
	}
}
$req_cookies->scan( \&cookie_callback );



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
# Adjust URLs to point to the right places
my $selfurl = url(-relative=>1);

# Modify things and generally act wierd

#stylesheets
for my $i ($tree->look_down(
		"_tag", "link",
		"rel", "stylesheet")) {
	$i->attr('href',$baseurl.$i->attr('href'));
}

#images
for my $i ($tree->look_down(
		"_tag", "img",
		"src", qr%^/%)) {
	$i->attr('src',$baseurl.$i->attr('src'));
}

#links
for my $i ($tree->look_down(
		"_tag", "a",
		"href", qr%^/cgi-bin/%)) {
	my $href = $i->attr('href');
	if ($href eq '/cgi-bin/game') {
		# FIXME - handle game calls differently
		next;
	}
	$href = $selfurl . '?realpage=' . $href;
	$i->attr('href',$href);
}

#for my $i ($tree->look_down(
#		"_tag", "a",
#		"href", qr%^/%)) {
#	$i->attr('href',$selfurl."?XURL=".$i->attr('href'));
#}

#forms
for my $i ($tree->look_down(
		"_tag", "form",
		"action","/cgi-bin/game")) {
	$i->attr('action',$selfurl);
}

#foo! textarea
for my $i ($tree->look_down(
		"_tag", "textarea",
		"class","textin")) {
	$i->push_content("\nfoo!");
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
print $q->header(
	-cookie=>$send_cookie,
	);

print $tree->as_HTML;

$tree=$tree->delete;


