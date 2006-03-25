#!/usr/bin/perl
use strict;
use warnings;

#
# FIXME - these should be configured by the user and not specific to cities
my $magic_urlparam = 'realpage';

# FIXME - this value is currently used in the clients but not via this var
my $magic_cookie = 'gamesession';

=head1 NAME

proxy.pm - set of routines from my cities proxy that provide a HTTP proxy

=cut

##########################################################################
#
# Libs we need.
use CGI ':all';
#use CGI::Carp qw(fatalsToBrowser);
use LWP::UserAgent;
use HTML::TreeBuilder;
use HTTP::Cookies;

# Take a context and a URL reference found in that context and return the
# fully qualified URL that the reference is referring to
# 
sub resolve_url($$) {
	my ($context,$ref) = @_;

	# FIXME - surely there is someone who has written a URL expansion lib

	if ($ref =~ m%^http://%) {
		return $ref;
	} 

	my ($base) = ($context =~ m%^([^:]+://[^/]+)/%);
	if ($ref =~ m%^/%) {
		return $base . $ref;
	} 

	#if ($ref =~ m%^?%) {
	#	return $context . $ref;
	#}

	my ($dir) = ($context =~ m%^(.*/)%);
	return $dir . $ref;
}

sub makereqfromquery($$) {
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
		# FIXME - magic param name
		# Unfortunatly, the ->delete method I was using on the query
		# does not adjust the url_param() values ...
		if ($i eq $magic_urlparam) {
			next;
		}
		if ($urlparamstr) {
			$urlparamstr .= "&";
		}
		$urlparamstr .= $i.'='. ($q->url_param($i)||'');
	}

	# defeat CGI.pm's automatic ISINDEX treatment
	if ($urlparamstr eq 'keywords=') {
		undef $urlparamstr;
	}

	#get gamesession cookie
	my $user_gamesession_cookie = $q->cookie($magic_cookie);

	######################################################################
	#
	# Duplicate the options and get ready to call the real game

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
		$req->header(Cookie => $magic_cookie.'='.$user_gamesession_cookie);
	}

	return ($req,$user_gamesession_cookie);
}

sub maketreefromreq($) {
	my ($req) = @_;

	######################################################################
	#
	# call the real game
	my $ua = LWP::UserAgent->new;
	$ua->agent("citieslib/1.0 ");

	my $res = $ua->request($req);

	if (!$res->is_success) {
		return ($res,undef,undef);
	}


	if ($res->content_type ne 'text/html') {
		return ($res,undef);
	}

	######################################################################
	#
	# Create a document tree from the returned data
	my $tree = HTML::TreeBuilder->new;
	#$tree->ignore_ignorable_whitespace(0);
	#$tree->no_space_compacting(1);
	$tree->store_comments(1);
	$tree->parse($res->content);
	$tree->eof;
	$tree->elementify;

	return ($res,$tree);
}

sub extractcookiefromres($$) {
	my ($res,$cookiename) = @_;

	my $cookies = HTTP::Cookies->new();
	$cookies->extract_cookies($res);

	my $cookie_text;
	my $send_cookie;

	my $callbackref = sub {
		my ($version,$key,$val,$path,$domain,$port,$path_spec,
		    $secure,$expires,$discard,$hash) = @_;

		if ($key eq $cookiename) {
			$cookie_text = $val;
			$send_cookie = cookie(
				-name=>$key,
				-value=>$val,
				-expires=>$expires,
			);
		}
	};

	$cookies->scan( $callbackref );

	return ($cookie_text,$send_cookie);
}

1;
