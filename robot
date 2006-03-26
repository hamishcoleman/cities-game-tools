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
	$dbh->commit();
}

sub addgoal($$$$) {
	my ($name,$command,$x,$y) = @_;
	my $dbh = dbopen();
	$dbh->do(qq{
		INSERT INTO robotgoal(name,command,x,y)
		VALUES(?,?,?,?);
	},undef,$name,$command,$x,$y);
	$dbh->commit();

	# FIXME - using a global
	addtexttolog($d,"New Goal is $command to $x/$y\n");
}

# Give me a standard response to reaching a goal
sub goalreached($$) {
	my ($d,$id) = @_;

	addtexttolog($d,"Goal Reached\n");
	print "Goal($id) reached\n";
	delgoal($id);
	addgoal($d->{_logname},'Map',0,0);
}

# Generate a list of E/W directions to complete the goal
sub makedirs_wantx($$) {
	my ($d,$goalx) = @_;
	my @dirs_want;

	if ($goalx > $d->{_x}) {
		push @dirs_want, "act_e";
	} elsif ($goalx < $d->{_x}) {
		push @dirs_want, "act_w";
	}

	return @dirs_want;
}

# Generate a list of N/S directions to complete the goal
sub makedirs_wanty($$) {
	my ($d,$goaly) = @_;
	my @dirs_want;

	if ($goaly > $d->{_y}) {
		push @dirs_want, "act_n";
	} elsif ($goaly < $d->{_y}) {
		push @dirs_want, "act_s";
	}

	return @dirs_want;
}

# From a list of wanted directions, generate a list of possible directions
sub makedirs_can($@) {
	my ($d,@dirs_want) = @_;
	my @dirs_can;

	# TODO - if 'fight' compare 'best weapon' to monster hp and our hp
	#	and allow direction if we can beat it.

	# make list of directions that need to go and can go
	for my $i (@dirs_want) {
		#print "Checking direction $i\n";
		my $state = $d->{_dir}->{$i}->{state};
		if (defined $state && $state eq 'move') {
			push @dirs_can, $i;
		}
	}

	addtexttolog($d,
		"Want to go:".join(',',@dirs_want)."\n"
		."Can     go:".join(',',@dirs_can)."\n"
		.Dumper($d->{_dir})
	);

	return @dirs_can;
}

# If we are blocked, add a goal with a detour plan
sub addgoaldetour($$) {
	my ($d,$dir) = @_;

	# use a right-hand-rule to produce a detour
	if ($dir eq 'act_e') {
		addgoal($d->{_logname},'movey-',$d->{_x}+1,$d->{_x});
	} elsif ($dir eq 'act_w') {
		addgoal($d->{_logname},'movey+',$d->{_x}-1,$d->{_x});
	} elsif ($dir eq 'act_n') {
		addgoal($d->{_logname},'movex+',$d->{_y},$d->{_y}+1);
	} elsif ($dir eq 'act_s') {
		addgoal($d->{_logname},'movex-',$d->{_y},$d->{_y}-1);
	}
}

sub makemovereq($$@) {
	my ($d,$form,@dirs_want) = @_;

	my @dirs_can;
	push @dirs_can,makedirs_can($d,@dirs_want);

	if (!@dirs_can) {
		# Movement blocked, generate a detour using a
		# right-hand-rule
		
		my $dir = $dirs_want[int rand scalar @dirs_want];

		addgoaldetour($d,$dir);
		return undef;
	}

	my $dir = $dirs_can[int rand scalar @dirs_can];

	print "Moving $dir\n";
	$form->value(item=>'Fists');
	return $form->click($dir);
}

sub generatenewgoal($) {
	my ($d) = @_;
	my $dbh = dbopen();

	my $area=10;

	my $sth = $dbh->prepare_cached(qq{
		SELECT x,y
		FROM map
		WHERE x>0 AND x<100 AND y>0 AND y<100 AND realm='0'
		AND x>? AND x<? AND y>? AND y<?
		ORDER BY lastseen
		LIMIT 1;
	}) || die $dbh->errstr;
	$sth->execute(
		$d->{_x}-10, $d->{_x}+10,
		$d->{_y}-10, $d->{_y}+10,
	);
	my $res = $sth->fetch();
	$sth->finish();

	if (!$res) {
		die "could not generate goal as there is nothing nearby!!";
	}

	#print "New Goal is movexy $res->[0]/$res->[1]\n";
	addgoal($d->{_logname},'movexy',$res->[0],$res->[1]);
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
$d->{_realm} = 'robot';
computelocation($d);
$d->{_realm} = '0';	# force this even if we are on inertial navigation
dumptodb($d);
dumptextintodb($d);
print "Robot is at $d->{_realm}/$d->{_x}/$d->{_y}\n";

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
		# TODO - examine inventory and select 'best weapon'
		$d = undef;
		$d->{_state} = 'newpage';
		$d->{_logname} = $robot_logname;
		screenscrape($tree,$d);
		if ($d->{_state} ne 'loggedin') {
			die "not logged in";
		}
		$d->{_realm} = 'robot';
		computelocation($d);
		$d->{_realm} = '0';	# force this as above
		dumptodb($d);
		dumptextintodb($d);
		$req=undef;
		print "Robot is at $d->{_realm}/$d->{_x}/$d->{_y}\n";

		print "\n";
		sleep 10;
	}

	
	if ($d->{ap} / $d->{maxap} < 0.10) {
		addtexttolog($d,"Finishing: Less than 10% AP remains\n");
		print "Less than 10% AP remains\n";
		last;
	}
	if ($d->{hp} / $d->{maxhp} < 0.50) {
		addtexttolog($d,"Finishing: Less than 10% HP remains\n");
		print "Less than 50% HP remains\n";
		last;
	}

	# lookup current goal
	my ($goalid,$command,$goalx,$goaly) = loadgoal($d->{_logname});
	if (!$goalid) {
		# TODO - if none, generate new goal
		print "No goal found\n";
		generatenewgoal($d);
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
			goalreached($d,$goalid);
			next;
		}

		# make list of directions we need to go in
		my @dirs_want;
		push @dirs_want, makedirs_wantx($d,$goalx);
		push @dirs_want, makedirs_wanty($d,$goaly);

		#print "Want to move in ",join(',',@dirs_want),"\n";

		$req = makemovereq($d,$form,@dirs_want);
		next;
	} elsif ($command eq 'movey-' || $command eq 'movey+') {
		# check if we have reached our goal
		if ($goalx == $d->{_x}) {
			goalreached($d,$goalid);
			next;
		}
		# check param2 to see if the goal is still valid
		my $max = $goalx>$goaly ? $goalx:$goaly;
		my $min = $goalx<$goaly ? $goalx:$goaly;
		if ($d->{_x} > $max || $d->{_x} < $min) {
			addtexttolog($d,"Goal invalid\n");
			print "Goal($goalid) is now invalid\n";
			delgoal($goalid);
			next;
		}

		my @dirs_want;

		# make list of directions we need to go in
		push @dirs_want, makedirs_wantx($d,$goalx);
		if ($command eq 'movey-') {
			push @dirs_want, 'act_s';
		} else {
			push @dirs_want, 'act_n';
		}

		$req = makemovereq($d,$form,@dirs_want);
		next;
	} elsif ($command eq 'movex-' || $command eq 'movex+') {
		# check if we have reached our goal
		if ($goaly == $d->{_y}) {
			goalreached($d,$goalid);
			next;
		}
		# check param2 to see if the goal is still valid
		my $max = $goalx>$goaly ? $goalx:$goaly;
		my $min = $goalx<$goaly ? $goalx:$goaly;
		if ($d->{_y} > $max || $d->{_y} < $min) {
			addtexttolog($d,"Goal invalid\n");
			print "Goal($goalid) is now invalid\n";
			delgoal($goalid);
			next;
		}

		my @dirs_want;

		# make list of directions we need to go in
		push @dirs_want, makedirs_wanty($d,$goaly);
		if ($command eq 'movex-') {
			push @dirs_want, 'act_w';
		} else {
			push @dirs_want, 'act_e';
		}

		$req = makemovereq($d,$form,@dirs_want);
		next;
	}


	$req=undef;

	# debugging
	last;
}

# debugging
#print Dumper($d);
#print "\n";
#print $form->dump;


__END__
