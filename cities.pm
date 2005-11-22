#!/usr/bin/perl
use strict;
use warnings;

=head1 NAME

cities.pm - set of common routines from my cities proxy

=cut

# Take a context and a URL reference found in that context and return the
# fully qualified URL that the reference is referring to
# 
sub resolve_url($$) {
	my ($context,$ref) = @_;

	# FIXME - surely there is someone who has written a URL expansion lib

	if ($ref =~ m%^http://%) {
		return $ref;
	} elsif ($ref =~ m%^/%) {
		my ($base) = ($context =~ m%^([^:]+://[^/]+)/%);
		return $base . $ref;
	} else {
		my ($dir) = ($context =~ m%^(.*/)%);
		return $dir . $ref;
	}
}

1;

