#!/usr/bin/perl
#
# This script performs the regular daily actions I want
#
#
use strict;
use warnings;

# allow the libs to be in the bin dir
use FindBin;
use lib $FindBin::RealBin;

use robot;

use Data::Dumper;
$Data::Dumper::Indent = 1;
$Data::Dumper::Sortkeys = 1;

use robot;

my $robot_username = shift @ARGV || die "need username";
my $robot_password = shift @ARGV || die "need password";
my $r = Robot->new($robot_username, $robot_password);

$r->login;

my $old_item = $r->current_item();

# Only do these actions once a day
if ($r->current_time() =~ m/^12:/) {
	if ($r->item('Cornucopia')->id) {
		# If possible, use the cornucopia
		$r->item('Cornucopia')->wield;

		$r->action('act_item_eat')->click;
		$r->action('act_item_drink')->click;
	}
	## Air favored
	#if ($r->item('InstrumentHarmonica')->wield) {
	#	$r->action('act_item_practise')->click;
	#}
	#if ($r->item('InstrumentAccordion')->wield) {
	#	$r->action('act_item_practise')->click;
	#}
}

# Try various things to use up today's AP
if ($r->action('act_retreat')->id) {
	# If possible, use a monastry
	$r->action('act_retreat')->click;
} else {
	if ($r->item('Fleece')->wield) {
		# remembering that ->click checks the remaining AP, this
		# will do as much carding as possible
		$r->action('act_build_carded_30')->click;
		$r->action('act_build_carded_10')->click;
		$r->action('act_build_carded_3')->click;
		$r->action('act_build_carded_1')->click;
	}
	if ($r->item('Distaff')->wield) {
		$r->action('act_build_wool_30')->click;
		$r->action('act_build_wool_10')->click;
		$r->action('act_build_wool_3')->click;
		$r->action('act_build_wool_1')->click;
	}
	if ($r->item('Wood')->wield) {
		$r->action('act_build_charcoal_100')->click;
	}
}

$old_item->wield;

# TODO - check if we are at the base of the elevator or in it and get in or
# out as appropriate

