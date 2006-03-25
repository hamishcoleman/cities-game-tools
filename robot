#!/usr/bin/perl
use strict;
use warnings;
#
# This script 
# 
#
#

##########################################################################
#
# Libs we need.
use Data::Dumper;
$Data::Dumper::Indent = 1;
$Data::Dumper::Sortkeys = 1;

use cities;

use LWP::UserAgent;
use HTTP::Cookies;
sub citieslogin($$) {
	my ($username,$password) = @_;

	my $req = HTTP::Request->new(POST => "$cities::baseurl/cgi-bin/game");
	$req->content_type('application/x-www-form-urlencoded');
	$req->content("username=$username&password=$password");

	my ($res,$tree) = maketreefromreq($req);

	if (!$res->is_success) {
		die "login: ", $res->status_line;
	}
	if ($res->content_type ne 'text/html') {
                # awooga, awooga, this is not a parseable document...
                die "login: received ", $res->content_type;
        }

	return ($res,$tree);
}

my $d;
$d->{_state} = 'initializing';
$d->{_logname} = '_LOGNAME_';
$d->{_password} = '_PASSWORD_';

my ($res,$tree) = citieslogin($d->{_logname},$d->{_password});

# save the session cookie for later...
my $cookie = HTTP::Cookies->new();
$cookie->extract_cookies($res);

screenscrape($tree,$d);
computelocation($d);

print Dumper($d);

__END__


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

