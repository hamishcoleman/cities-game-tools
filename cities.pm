#!/usr/bin/perl
use strict;
use warnings;
#
# _LOGNAME_/_PASSWORD_
#

##########################################################################
#
# Configure it.
#
# (nothing much right now)
#
glob $cities::baseurl = "http://cities.totl.net";
glob $cities::logfile = "/home/hamish/WWW/cities/gamelog.txt";
glob $cities::db = "/home/hamish/WWW/cities/db/gamelog.sqlite";

use HTTP::Date;
use DBI;

=head1 NAME

cities.pm - set of common routines from my cities proxy

=cut

use proxy;

##########################################################################
#
# Adjust URLs to point to the right places
sub adjusturls($$) {
	my ($tree,$realpage) = @_;

	#my $selfurl = url(-relative=>1);
	my $otherurl = "other.cgi";
	my $gameurl = "game.cgi";

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

	# um, not an img but displays an img ??
	for my $i ($tree->look_down(
			"_tag", "input" )) {
		if ($i->attr('src')) {
			$i->attr('src',resolve_url($realpage,$i->attr('src')));
		}
	}

	# main game page form
	for my $i ($tree->look_down(
			"_tag", "form",
			"action","game")) {
		$i->attr('action',$gameurl );
	}

	# logout page form
	for my $i ($tree->look_down(
			"_tag", "form",
			"action","/cgi-bin/game")) {
		$i->attr('action',$gameurl );
	}

	#links
	for my $i ($tree->look_down(
			"_tag", "a", )) {
		my $href = $i->attr('href');

		# Handle the game page specially
		if ($href eq '/cgi-bin/game') {
			$i->attr('href',$gameurl );
			next;
		} elsif ($href eq 'game') {
			$i->attr('href',$gameurl );
			next;
		} elsif ($href =~ m%^game(\?.*)%) {
			$i->attr('href',$gameurl . $1);
			next;
		} elsif ($href =~ m%^\?(.*)%) {
			$i->attr('href', '?realpage='. $realpage . '&' . $1);
			next;
		}

		# Handle other urls with the "other.cgi" handler
		my $ref = resolve_url($realpage,$href);
		# FIXME - cities link hardcoded
		if ($ref =~ m%^http://cities.totl.net/%) {
			$i->attr('href',$otherurl . '?realpage='.$ref);
		}
	}
}

sub handle_simple_cases($) {
	my ($res) = @_;
	
	# there was an error of some kind
	if (!$res->is_success) {
		# FIXME - this is not right...
		my $query = new CGI;
		print $query->header;
		print $res->status_line, "\n\n";
		print $res->content;
		exit;
	}
	
	# The data was not HTML, so we have no tree to process
	if ($res->content_type ne 'text/html') {
		# awooga, awooga, this is not a parseable document...
		my $query = new CGI;
		print $query->header($res->content_type);
		print $res->content;
		exit;
	}
}

sub addvalue($$$$$) {
	my ($tree,$d,$key,$value,$name) = @_;
	my $node;

	$node = $tree->look_down($key,$value);
	if ($node) {
		$d->{$name} = $node->as_trimmed_text();
		return $d->{$name};
	}
	return undef;
}

sub addviewport($$) {
	my ($tree,$d) = @_;

	my $viewport = $tree->look_down('id','viewport');
	if (!$viewport) {
		# Something is wrong
		return;
	}

	my %mapping = (
		c  => [0, 0],

		n  => [0, 1],
		s  => [0, -1],
		e  => [1, 0],
		w  => [-1, 0],

		nw => [-1, 1],
		sw => [-1, -1],
		ne => [1, 1],
		se => [1, -1],
	);

	for my $id (keys %mapping) {
		my $square = $viewport->look_down('id',$id);
		if (!defined $square) {
			# maybe we cannot see that square?
			next;
		}
		my $div = $square->address('.0');
		if (!defined $div) {
			# Something is wrong
			next;
		}
		my $class = $square->attr('class');
		if ($class =~ /(loc_dark|loc_bright)/) {
			# We are not able to see anything here, so dont log it
			next;
		}

		my $x = $mapping{$id}[0];
		my $y = $mapping{$id}[1];
		
		$d->{_map}->{$x}->{$y}->{class} = $class;
		$d->{_map}->{$x}->{$y}->{name} = $div->as_trimmed_text();
	}
}

sub addmap($$) {
	my ($tree,$d) = @_;

	my $map;
	for my $item ($tree->look_down( 'id','item' )) {
		if (defined $map) {
			# only one map added at a time...
			next;
		}
		my $title = $item->look_down(
			'_tag','span',
			'class','control_title');
		if (!defined $title) {
			# Something is wrong
			next;
		}
		# FIXME - this is fragile
		if ($title->as_trimmed_text =~ m/(Big Map|Map|Small Map|Small Magic Map):/) {
			$map = $item->look_down('_tag','table');
		}
	}
	if (!$map) {
		# no map found
		return;
	}

	my ($size,$offset);

	if (defined $map->address(".14.14")) {
		$size = 14;
		$offset = 7;
	} elsif (defined $map->address(".10.10")) {
		$size = 10;
		$offset = 5;
	} else {
		$size = 4;
		$offset = 2;
	}

	for my $row (0..$size) {
		for my $col (0..$size) {
			my $loc = $map->address(".$row.$col");
			if (!defined $loc) {
				next;
			}

			$d->{_map}->{$row-$offset}->{$col-$offset}->{class} = $loc->attr('class');

			my $name = $loc->look_down(
				'_tag', 'span',
				'class', 'hideuntil');
			if (defined $name) {
				$d->{_map}->{$row-$offset}->{$col-$offset}->{name} = $name->as_trimmed_text();
			}
		}
	}
}

sub computelocation($) {
	my ($d) = @_;

	if (defined $d->{lat} && defined $d->{long}) {
		#long = x, lat = y
		if ($d->{long} =~ m/([\d]+)([EW])/) {
			if ($2 eq 'E') { $d->{_x} = $1 }
			if ($2 eq 'W') { $d->{_x} = -$1 }
		}
		if ($d->{lat} =~ m/([\d]+)([NS])/) {
			if ($2 eq 'N') { $d->{_y} = $1 }
			if ($2 eq 'S') { $d->{_y} = -$1 }
		}
		# FIXME - I am not checking for errors ..
		$d->{_realm} = '0';
	}

	# we do not have enough information...
	# TODO - consult database, construct an inertial reckoning
	#
	# if no location and no has_intrinsic_location then attempt
	# inertial reckoning in default realm.  look out for warping
	# stopwords implying new realm.
	#
	# if no location and has_intrinsic_location and db realm is
	# default or null, start a new realm.
	#
	# basically I am trying to support robots without intrinsic
	# location abilities, whilst also trying to allow some mapping
	# of areas without location information.
	
	#$d->{_realm} = something
}

sub screenscrape($) {
	my ($tree) = @_;
	my $d;		# place to store our scrapings
	my $node;	# temp node value
	my $s;		# temp string value

	$d->{_state} = 'unknown';

	$node = $tree->look_down('_tag','title');
	if (!$node) {
		# No title?  something is wrong
		return $d;
	}
	$s = $node->as_trimmed_text();

	# save the system time that this scrape was generated
	$d->{_time} = time();

	# FIXME - checking titles is somewhat fragile
	if ($s =~ m/^Cities - login$/) {
		$d->{_state} = 'loggedout';
	} elsif ($s =~ m/^Cities - bye$/) {
		$d->{_state} = 'loggedout';
	} else {
		# If not one of the above assume logged in
		$d->{_state} = 'loggedin';
	}

	# FIXME - very fragile
	$node = $tree->look_down(
		'_tag', 'div',
		'style', qr/^text/);
	if ($node) {
		$d->{_fullname} = $node->as_trimmed_text();
	}

	addvalue($tree,$d,'id','ap','ap');
	addvalue($tree,$d,'id','maxap','maxap');
	addvalue($tree,$d,'id','hp','hp');
	addvalue($tree,$d,'id','maxhp','maxhp');
	addvalue($tree,$d,'id','gold','gold');

	$node = $tree->look_down(
		'_tag','textarea',
		'class','textin');
	if ($node) {
		$d->{_textin} = $node->as_text();
	}

	# id="inventory"

	addvalue($tree,$d,'id','long','long');
	addvalue($tree,$d,'id','lat','lat');

	# FIXME - could accidentally find times in palintir messages ...
	for $node ($tree->look_down(
			'_tag', 'div',
			'class','controls')) {
		my $text = $node->as_trimmed_text();
		if ($text =~ m/(\d\d?:\d\d[ap]m)/) {
			# We have a clock
			if (!defined $d->{_clock}) {
				$d->{_clock} = $1;
			}
		}
	}

	# marker stone
	if (!defined $d->{lat} || !defined $d->{long}) {
		for $node ($tree->look_down(
				'_tag', 'div',
				'class','controls')) {
			my $text = $node->as_trimmed_text();
			if ($text =~ m/gives the exact location.* ([\d]+[EW]) and ([\d]+[NS])/) {
				# Found a Marker stone
				$d->{long} = $1;
				$d->{lat} = $2;
			}
		}
	}

	# div id="equipment", div id="item" ...

	addmap($tree,$d);
	# add the viewport second as it's data will overwrite the map data
	addviewport($tree,$d);

	# construct X and Y values
	computelocation($d);

	return $d;
}

sub addcookie($$$) {
	my ($d,$send_cookie,$recv_cookie) = @_;

	if (!defined $recv_cookie || !$recv_cookie || $recv_cookie eq 'null') {
		$d->{_cookie} = $send_cookie;
	} else {
		$d->{_cookie} = $recv_cookie;
	}

	if (defined $d->{_cookie}) {
		$d->{_cookie} =~ m/(.*)%3A(.*)/;
		$d->{_logname} = $1;
	}
}

sub dumptogamelog($) {
	my ($d) = @_;
	my $haveloc;

	# FIXME - error checking
	open(LOG,">>$cities::logfile");

	#
	#$Data::Dumper::Indent = 1;
	#$Data::Dumper::Sortkeys = 1;
	#print LOG Dumper($d);

	if (defined $d->{_logname}) {
		print LOG "USER: $d->{_logname}\n";
	}

	if (defined $d->{_clock}) {
		print LOG "TIME: $d->{_clock}\n";
	}

	if (defined $d->{_x} && defined $d->{_y}) {
		print LOG "LOC: $d->{_x}, $d->{_y}\n";
		print LOG "VISIT: $d->{_x}, $d->{_y}\n";
		$haveloc=1;
	}
	print LOG $d->{_textin};

	for my $x (keys %{$d->{_map}}) {
		for my $y (keys %{$d->{_map}->{$x}}) {
			my ($head,$tail);

			if ($haveloc) {
				$head = 'OLD: '. ($d->{_x} + $x)
					. ', '. ($d->{_y} + $y)
					. ', ';
			} else {
				$head = 'SUR: '. $x
					. ', '. $y
					. ', ';
			}

			$tail = '"'. $d->{_map}->{$x}->{$y}->{class} . '"';
			if (defined $d->{_map}->{$x}->{$y}->{name}) {
				$tail .= ', "' 
					. $d->{_map}->{$x}->{$y}->{name}
					. '"';
			}

			print LOG $head, $tail, "\n";
		}
	}
}

sub dumptodb($) {
	my ($d) = @_;

	# use the defined timevalue
	my $time = $d->{_time};

	if (!defined $d->{_x} || !defined $d->{_y}) {
		# TODO - use the realms feature to add unknown locations
		return;
	}

	my $dbh = DBI->connect( "dbi:SQLite:$cities::db" ) || die "Cannot connect: $DBI::errstr";
	$dbh->{AutoCommit} = 0;


	# dump the current user data
	my $userlookup = $dbh->prepare(qq{
		SELECT lastseen
		FROM user
		WHERE name = ?
	});
	$userlookup->execute($d->{_logname});
	my $user = $userlookup->fetch;
	$userlookup->finish();
	if (!$user) {
		# bad!
		die "You do not exist in the database";
	}
	$dbh->do(qq{
		UPDATE user
		SET lastseen=?, lastx=?, lasty=?, realm=?
	}, undef, $d->{_time},$d->{_x},$d->{_y},$d->{_realm});


	# dump the map data
	for my $x (keys %{$d->{_map}}) {
		for my $y (keys %{$d->{_map}->{$x}}) {
			my $class = $d->{_map}->{$x}->{$y}->{class};
			my $name = $d->{_map}->{$x}->{$y}->{name};

			my $lookup = $dbh->prepare_cached(qq{
				SELECT class,name
				FROM map
				WHERE realm=? AND x=? AND y=?
			});
			$lookup->execute($d->{_realm},($d->{_x} + $x),($d->{_y} + $y));
			my $res = $lookup->fetch;

			# convince the DBI to _STOP_ITS_WHINGING_
			$lookup->finish();

			if (!$res) {
				my $visits = $d->{_map}->{$x}->{$y}->{visits};
				if (!$visits) { $visits = 0; }
				# record does not exist, add it
				my $insert = $dbh->prepare_cached(qq{
					INSERT
					INTO map(realm,x,y,class,name,visits,lastseen,lastchanged,lastchangedby)
					VALUES(?,?,?,?,?,?,?,?,?)
				}) or die $dbh->errstr;
				$insert->execute($d->{_realm},($d->{_x} + $x),($d->{_y} + $y),
					$class,
					$name,
					$visits,
					$time,$time,$d->{_logname});
				next;
			}

			my $diff = 0;

			if ($res->[0] ne $class) {
				$diff=1;
			}
			if (!$diff && $res->[1] ne $name) {
				$diff=1;
			}

			if ($diff) {
				# something is different, update the entry
				my $update = $dbh->prepare_cached(qq{
					UPDATE map
					SET class=?, name=?, lastseen=?, lastchanged=?, lastchangedby=?
					WHERE realm=? AND x=? AND y=?
				}) or die $dbh->errstr;
				$update->execute(
					$class,
					$name,
					$time,$time,$d->{_logname},
					$d->{_realm},($d->{_x} + $x),($d->{_y} + $y));
				next;
			}

			# no differences, just update the freshness
			my $seen = $dbh->prepare_cached(qq{
				UPDATE map
				SET lastseen=?
				WHERE realm=? AND x=? AND y=?
			}) or die $dbh->errstr;
			$seen->execute(
				$time,
				$d->{_realm},($d->{_x} + $x),($d->{_y} + $y));
		}
	}

	# update visits
	my $visits = $dbh->prepare_cached(qq{
		UPDATE map
		SET visits=visits+1, lastvisited=?
		WHERE realm=? AND x=? AND y=?
	}) or die $dbh->errstr;
	$visits->execute(
		$time,
		$d->{_realm},($d->{_x}),($d->{_y}));

	$dbh->commit();

	# YEY, I have triggered an sqlite dbi bug http://rt.cpan.org/Public/Bug/Display.html?id=9643
	# basically, if you do not use a prepared sth, you cannot finish it
	# and the dbh destroy _WILL_ whinge at you.  Stupid stupid stupid

	$dbh->disconnect;
}

1;

__END__

