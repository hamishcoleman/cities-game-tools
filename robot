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

sub loadgoal($) {
	my ($name) = @_;
	my $dbh = dbopen();

	my $sth = $dbh->prepare_cached(qq{
		SELECT id,command,x,y
		FROM robotgoal
		WHERE name=?
		ORDER BY id DESC
		LIMIT 1
	}) || die $dbh->errstr;
	$sth->execute($name);
	my $res = $sth->fetch();
	$sth->finish();

	return ($res->[0],$res->[1],$res->[2],$res->[3]);
}

sub delgoal($) {
	my ($id) = @_;
	my $dbh = dbopen();
	$dbh->do(qq{
		DELETE FROM robotgoal
		WHERE id=?
	},undef,$id);
}

$d->{_logname} = $robot_logname;
$d->{_password} = $robot_password;
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
$d->{_realm} = 'test';	# force this whilst I am testing ...
dumptodb($d);
dumptextintodb($d);

my $req;

while (1) {
	if ($req) {
		$cookie->add_cookie_header($req);
		my ($res,$tree) = maketreefromreq($req);
		if (!$res->is_success) {
			die "robot: ", $res->status_line;
		}
		if ($res->content_type ne 'text/html') {
			die "robot: received ", $res->content_type;
		}
		$form = HTML::Form->parse($res);
		$d = undef;
		$d->{_state} = 'newpage';
		$d->{_logname} = $robot_logname;
		screenscrape($tree,$d);
		if ($d->{_state} ne 'loggedin') {
			die "not logged in";
		}
		computelocation($d);
		$d->{_realm} = 'test';	# force this whilst I am testing ...
		dumptodb($d);
		dumptextintodb($d);
	}

	print "Robot is at $d->{_realm}/$d->{_x}/$d->{_y}\n";
	
	if ($d->{ap} / $d->{maxap} < 0.10) {
		print "Less than 10% AP remains\n";
		last;
	}
	if ($d->{hp} / $d->{maxhp} < 0.50) {
		print "Less than 50% HP remains\n";
		last;
	}

	# lookup current goal
	my ($goalid,$command,$goalx,$goaly) = loadgoal($d->{_logname});
	if (!$goalid) {
		# TODO - if none, generate new goal
		print "No goal found\n";
		last;
	}
	print "Goal($goalid) is $command to $goalx/$goaly\n";

	if ($command eq 'Map') {
		delgoal($goalid);
		$form->value(item=>'Map');
		$req = $form->click('act_null');
		next;
	} elsif ($command eq 'movexy') {
		if ($goalx == $d->{_x} && $goaly == $d->{_y}) {
			print "Goal($goalid) reached\n";
			delgoal($goalid);
			next;
		}
	}

	# calculate movement towards goal
	# if blocked push temporary goal
	# perform movement, submit, scrape, etc
	## select GPS, submit, scrape, etc
	# select map, submit, scrape, etc


	$req=undef;

	# debugging
	last;
}

# debugging
#print Dumper($d);
#print "\n";
#print $form->dump;


__END__
