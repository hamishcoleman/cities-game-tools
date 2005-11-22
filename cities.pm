#!/usr/bin/perl
use strict;
use warnings;

=head1 NAME

cities.pm - set of common routines from my cities proxy

=cut

use proxy;

##########################################################################
#
# Adjust URLs to point to the right places
sub adjusturls(\$$) {
	my ($tree,$realpage) = @_;

	my $selfurl = url(-relative=>1);

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
		# FIXME - cities link hardcoded
		if ($ref =~ m%^http://cities.totl.net/%) {
			$i->attr('href',$selfurl . '?realpage='.$ref);
		}
	}
}

##forms
#for my $i ($tree->look_down(
#		"_tag", "form",
#		"action","/cgi-bin/game")) {
#	$i->attr('action',$selfurl);
#}


1;

