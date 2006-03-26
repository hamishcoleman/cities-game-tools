#!/usr/bin/perl
use strict;
use warnings;
#
# This script 
# 
#
#

my $robot_logname = '_LOGNAME_';
my $robot_password = '_PASSWORD_';
my $controltitle = 'Space Elevator Dock:';


my $d;
$d->{_state} = 'initializing';

##########################################################################
#
# Libs we need.
use Data::Dumper;
$Data::Dumper::Indent = 1;
$Data::Dumper::Sortkeys = 1;

use HTML::Form;

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


$d->{_logname} = $robot_logname;
$d->{_password} = $robot_password;

# TODO - dbloaduser, check lastseen, abort if less then x minutes ago

my ($res,$tree) = citieslogin($d->{_logname},$d->{_password});

# save the session cookie for later...
my $cookie = HTTP::Cookies->new();
$cookie->extract_cookies($res);

my $form = HTML::Form->parse($res);
screenscrape($tree,$d);
if ($d->{_state} ne 'loggedin') {
	die "not logged in";
}
computelocation($d);
#dumptodb($d);
dumptextintodb($d);
print "User is at $d->{_realm}/$d->{_x}/$d->{_y}\n";


# look for area
my $span;
for my $i ($tree->look_down('_tag','span','class','control_title')) {
	print "Found control titled '",$i->as_trimmed_text(),"'\n";
	if ($i->as_trimmed_text() eq $controltitle) {
		$span = $i;
	}
}

my $div = $span->parent;
my $input = $div->look_down('_tag','input');

if ($input) {
	my $inputname = $input->attr('name');

	print "Found input name=$inputname\n";

	my $req = $form->click($inputname);

	$cookie->add_cookie_header($req);
	my ($res,$tree) = maketreefromreq($req);
	if (!$res->is_success) {
		die "robot: ", $res->status_line;
	}
	if ($res->content_type ne 'text/html') {
		die "robot: received ", $res->content_type;
	}

	screenscrape($tree,$d);
	if ($d->{_state} ne 'loggedin') {
		die "not logged in";
	}
	computelocation($d);
	dumptextintodb($d);

	print "Done";
}

# debugging
#print Dumper($d);
#print "\n";
#print $form->dump;


__END__
