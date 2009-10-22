#!/usr/bin/perl
#
# This script performs the regular daily actions I want
#
#
use strict;
use warnings;

use robot;

use Data::Dumper;
$Data::Dumper::Indent = 1;
$Data::Dumper::Sortkeys = 1;

use robot;

my $r = Robot->new('_LOGNAME_','_PASSWORD_');

$r->login;

my $old_item = $r->current_item();

if ($r->action('act_retreat')->id) {
	# If possible, use a monastry
	$r->action('act_retreat')->click;
}


if ($r->item('Cornucopia')->id) {
	# If possible, use the cornucopia
	$r->item('Cornucopia')->wield;

	# TODO - state storage so we only drink/eat once a day
	$r->action('act_item_eat')->click;
	$r->action('act_item_drink')->click;
}

$old_item->wield;

# TODO - check if we are at the base of the elevator or in it and get in or
# out as appropriate

