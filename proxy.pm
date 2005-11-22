#!/usr/bin/perl
use strict;
use warnings;

=head1 NAME

cities.pm - set of routines from my cities proxy that provide a HTTP proxy

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

##########################################################################
#
# Libs we need.
use CGI ':all';
use CGI::Carp qw(fatalsToBrowser);
use LWP::UserAgent;
use HTML::TreeBuilder;
use HTTP::Cookies;

sub gettreefromurl($$) {
	my ($q,$realpage) = @_;

	######################################################################
	#
	# Determine exactly what options were used to call this script

	my $request_method=$q->request_method();
	if (!$request_method) {
		#print "You must be testing me\n";
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
	for my $i ($q->url_param) {
		if (! defined $i) {
			# HUH?
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

	#get gamesession cookie
	my $user_gamesession_cookie = $q->cookie('gamesession');

	######################################################################
	#
	# Duplicate the options and call the real game
	my $ua = LWP::UserAgent->new;
	$ua->agent("citiesproxy/1.0 ");

	# construct the correct URL from our params
	my $url = $realpage;
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
		return ($res,undef,undef);
	}

	my $req_cookies = HTTP::Cookies->new();
	$req_cookies->extract_cookies($res);

	my $send_cookie;
	my $callbackref = sub {
		my ($version,$key,$val,$path,$domain,$port,$path_spec,
		    $secure,$expires,$discard,$hash) = @_;

		# WARN - cookie name hardcoded
		if ($key eq 'gamesession') {
			$send_cookie = $q->cookie(
				-name=>$key,
				-value=>$val,
				-expires=>$expires,
			);
		}
	};
	$req_cookies->scan( $callbackref );

	if ($res->content_type ne 'text/html') {
		return ($res,$send_cookie,undef);
	}

	######################################################################
	#
	# Create a document tree from the returned data
	my $tree = HTML::TreeBuilder->new;
	$tree->ignore_ignorable_whitespace(0);
	$tree->no_space_compacting(1);
	$tree->store_comments(1);
	$tree->parse($res->content);
	$tree->eof;
	$tree->elementify;

	return ($res,$send_cookie,$tree);
}

1;
