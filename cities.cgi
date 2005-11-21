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
use HTTP::Cookies;


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

my $request_method=$q->request_method();
my $paramstr;
for my $i ($q->param) {
	if ($paramstr) {
		$paramstr .= "&";
	}
	$paramstr .= $i.'='.$q->param($i);
}

my $urlparamstr;
for my $i ($q->url_param) {
	if ($urlparamstr) {
		$urlparamstr .= "&";
	}
	$urlparamstr .= $i.'='.$q->url_param($i);
}

#get gamesession cookie
my $get_gamesession_cookie = $q->cookie('gamesession');
#$cookie_jar->set_cookie( $version, $key, $val, $path, $domain, $port,
#       $path_spec, $secure, $maxage, $discard, \%rest )


##########################################################################
#
# Duplicate the options and call the real game
my $ua = LWP::UserAgent->new;
$ua->agent("citiesproxy/1.0 ");

# construct the correct URL from our params
my $url = $baseurl.'/cgi-bin/game';
if ($urlparamstr ne 'keywords=') {
	$url .= '?'.$urlparamstr;
}

my $req = HTTP::Request->new($request_method => $url);
if ($request_method eq 'POST') {
	$req->content_type('application/x-www-form-urlencoded');
	$req->content($paramstr);
}
# set cookie -- $cookie_jar->add_cookie_header( $req )
# set post params

my $res = $ua->request($req);

if (!$res->is_success) {
        print $res->status_line, "\n";
        exit;
}

my $cookie_jar = HTTP::Cookies->new();
$cookie_jar->extract_cookies($res);

my $callback_debug;
my $send_gamesession_cookie;
sub cookie_callback() {
	my ($version,$key,$val,$path,$domain,$port,$path_spec,
	    $secure,$expires,$discard,$hash) = @_;
	$callback_debug = join(",",@_)."\n";

	if ($key eq 'gamesession') {
		$send_gamesession_cookie = $q->cookie(
			-name=>$key,
			-value=>$val,
			-path=>$path,
			-domain=>$domain,
			-expires=>$expires,
		);
	}
}
$cookie_jar->scan( \&cookie_callback );



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

##links
#for my $i ($tree->look_down(
#		"_tag", "a",
#		"href", qr/^game/)) {
#	my $link = $i->attr('href');
#	$link =~ s/^game/$selfurl/;
#	$i->attr('href',$link);
#}
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
	-cookie=>$send_gamesession_cookie,
	);

#print "<pre>\n";
#print $paramstr."\n";
#print $urlparamstr."\n";
#print "</pre>\n";

print $tree->as_HTML;

$tree=$tree->delete;

##########################################################################
#
# Original text for comparison...
#print "\n=====================================\n";
#print $res->content;

print Dumper($cookie_jar);
print "\n".$callback_debug;
print "\n";
print "get ". Dumper($get_gamesession_cookie) ."\n";
print "send ". Dumper($send_gamesession_cookie) ."\n";

