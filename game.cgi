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
my ($res,$tree) = maketreefromreq($req);
my ($send_cookie_val,,$send_cookie) = extractcookiefromres($res,'gamesession');
handle_simple_cases($res);
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
	dumptextintodb($d);

	my @list;
	for my $i ($query->param) {
		if ($i eq 'item' || $i eq 'say' || $i eq 'width'
			|| $i eq 'shop_buy' || $i eq 'heal_user'
			|| $i eq 'act_n.x' || $i eq 'act_n.y'
			|| $i eq 'act_s.x' || $i eq 'act_s.y'
			|| $i eq 'act_e.x' || $i eq 'act_e.y'
			|| $i eq 'act_w.x' || $i eq 'act_w.y'
			|| $i eq 'act_fast1' || $i eq 'act_setfast1'
			|| $i eq 'act_null'
			|| $i eq 'act_eqpane'
			|| $i eq 'act_say' || $i eq 'act_shout'
			|| $i eq 'act_cols'
			# act_exit exits the elevator
			# act_enter enters the elevator
		) {
			next;
		}
		push @list,($i.'=>'.param($i));
	}
	my $paramlist = join(',',@list);
	if ($paramlist) {
		addtexttolog($d,"Params: ".$paramlist);
	}
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

