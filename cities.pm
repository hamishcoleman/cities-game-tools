#!/usr/bin/perl
use strict;
use warnings;
#
#
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
		#$i->attr('href',$otherurl . '?realpage='.resolve_url($realpage,$i->attr('href')));
	}

	#images
	for my $i ($tree->look_down(
			"_tag", "img" )) {
		$i->attr('src',resolve_url($realpage,$i->attr('src')));
		#$i->attr('src',$otherurl . '?realpage='.resolve_url($realpage,$i->attr('src')));
	}

	# um, not an img but displays an img ??
	for my $i ($tree->look_down(
			"_tag", "input" )) {
		if ($i->attr('src')) {
			$i->attr('src',resolve_url($realpage,$i->attr('src')));
			#$i->attr('src',$otherurl . '?realpage='.resolve_url($realpage,$i->attr('src')));
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

	# Need to fix the newspaper
	#
	# <input type="button" value="Read" onclick="window.open(&quot;/newspaper/issue2.html&quot;, &quot;name&quot;)" name="act_item_read" class="button" ,=",">
	# <input type="button" value="Archives" onclick="window.open(&quot;/newspaper/index.html&quot;, &quot;name&quot;)" name="act_item_archives" class="button" ,=",">
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

# adds to the dataset values defined with id= attribs
sub addidvalue($$$$$) {
	my ($tree,$d,$key,$value,$name) = @_;
	my $node;

	$node = $tree->look_down($key,$value);
	if ($node) {
		$d->{$name} = $node->as_trimmed_text();
		return $d->{$name};
	}
	return undef;
}

# trys to extract the status of each direction from the viewport
sub adddirection($$$) {
	my ($tree,$d,$name) = @_;

	my $node = $tree->look_down('name','act_move_'.$name);
	if ($node) {
		$d->{_dir}->{$name}->{state} = 'move';
		my $s = $node->attr('onmouseover');
		if (!$s) {
			# try new fangled interface
			$s = $node->attr('title');
		}
		if ($s =~ m/will cost (\d+) AP/) {
			$d->{_dir}->{$name}->{ap} = $1;
		}
	} elsif ($node = $tree->look_down('name','act_fight_'.$name)) {
		$d->{_dir}->{$name}->{state} = 'fight';
	} else {
		return undef;
	}

	my $div = $node->parent->look_down('_tag','div');
	if ($div) {
		my $text = $div->as_trimmed_text();
		$d->{_dir}->{$name}->{text}=$text;
		my ($mname,$mhp)=($text=~ m/(.*) \((.+)\)/);
		$d->{_dir}->{$name}->{monster}=$mname;
		$d->{_dir}->{$name}->{hp}=$mhp;
	}
}

sub addviewport($$) {
	my ($tree,$d) = @_;

	my $viewport = $tree->look_down('id','control_pane');
	if (!$viewport) {
		# Something is wrong
		warn "Could not find id=control_pane";
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

		# FIXME
		# crazy altars have a nested content
		#if ($div->attr('_tag') eq 'table') {
		#	my $div2 = $div->look_down('id',$id);
		#	if (defined $div2) {
		#		$div = $div2;
		#	}
		#}

		my $class = $square->attr('class');
		my $name;
		if ($class =~ /(loc_dark|loc_bright)/) {
			# could use Ephemermal..
			# We are not able to see anything here, so dont log it
			next;
		} else {
			# dark and bright dont have a div, so this is an error
			# for them.
			$name = $div->address('.0')->as_trimmed_text();
		}

		my $x = $mapping{$id}[0];
		my $y = $mapping{$id}[1];
		
		$d->{_map}->{$x}->{$y}->{class} = $class;
		$d->{_map}->{$x}->{$y}->{name} = $name;
	}

	# Secondly try to add the directions that are valid to move in..

	adddirection($tree,$d,'n');
	adddirection($tree,$d,'s');
	adddirection($tree,$d,'e');
	adddirection($tree,$d,'w');
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
		if (defined $title) {
			# FIXME - this is fragile
			if ($title->as_trimmed_text =~ m/(Big Map|Map|Small Map|Small Magic Map):/) {
				$map = $item->look_down('_tag','table');
				next;
			}
		}

		my $td = $item->look_down(
			'_tag','td',
			'class', qr/ map_loc/);
		if (defined $td) {
			$map = $item->look_down('_tag','table');
			next;
		}
	}
	if (!$map) {
		# no map found
		return;
	}

	my ($size,$offset);

	# FIXME - should auto-size the damn map..
	if (defined $map->address(".15.15")) {
		# it is larger than expected ...
		# skip it to avoid issues...
		# FIXME - log a warning message
		return;
	} elsif (defined $map->address(".14.14")) {
		$size = 14;	# 15x15
		$offset = 7;
	# I have never seen a 13x13 map
	} elsif (defined $map->address(".12.12")) {
		$size = 12;	# 13x13
		$offset = 6;
	} elsif (defined $map->address(".10.10")) {
		$size = 10;	# 11x11
		$offset = 5;
	} elsif (defined $map->address(".8.8")) {
		$size = 8;	# 9x9
		$offset = 4;
	} elsif (defined $map->address(".6.6")) {
		$size = 6;	# 7x7
		$offset = 3;
	} else {
		$size = 4;	# 5x5
		$offset = 2;
	}

	# FIXME - should check that the guessed center of the map has an 'X'

	for my $row (0..$size) {
		for my $col (0..$size) {
			my $loc = $map->address(".$row.$col");
			if (!defined $loc) {
				next;
			}

			$d->{_map}->{$col-$offset}->{($size-$row)-$offset}->{class} = $loc->attr('class');

			my $name = $loc->look_down(
				'_tag', 'span',
				'class', 'hideuntil');
			if (defined $name) {
				$d->{_map}->{$col-$offset}->{($size-$row)-$offset}->{name} = $name->as_trimmed_text();
			}
		}
	}
}

sub dbopen {
	my $dbh = DBI->connect_cached( "dbi:SQLite:$cities::db" ) || die "Cannot connect: $DBI::errstr";
	$dbh->{AutoCommit} = 0;

	return $dbh;
}

sub dbloaduser($) {
	my ($d) = @_;

	my $dbh = dbopen();

	if (!defined $d->{_logname}) {
		die "no logname";
	}

	my $sth = $dbh->prepare_cached(qq{
		SELECT name,realm,lastx,lasty,lastseen
		FROM user
		WHERE name = ?
	});
	$sth->execute($d->{_logname});
	my $res = $sth->fetch();
	$sth->finish();

	if (!$res) {
		die "user $d->{_logname} is not in the database";
	}

	$d->{_db}->{name} = $res->[0];
	$d->{_db}->{realm} = $res->[1];
	$d->{_db}->{lastx} = $res->[2];
	$d->{_db}->{lasty} = $res->[3];
	$d->{_db}->{lastseen} = $res->[4];
	return 1;
}

# Generate just the name part of a new realm
sub dbmakenewrealmname($) {
	my ($d) = @_;
	my $dbh = dbopen();
	my $sth;
	my $realm;
	my $realmnr;

	if (!defined $d->{_logname}) {
		die "no logname";
	}

	$sth = $dbh->prepare_cached(qq{
		SELECT max(realm)
		FROM map
		WHERE realm LIKE ?
	});
	$sth->execute('new:'.$d->{_logname}.':%');
	my $res = $sth->fetch();
	$sth->finish();

	if (!$res || !$res->[0]) {
		$realmnr = 0;
	} else {
		$realm = $res->[0];

		$realm =~ m/new:([^:]+):(\d+)/;
		$realmnr = $2;
	}

	# TODO - actually verify that there will not be any races.
	# FIXME - player names ending in numbers... (a separator?)

	my $newnr = sprintf("%02i",$realmnr+1);
	$realm = 'new:'. $d->{_logname} .':'. $newnr;

	return $realm;
}

# force the generation of the entire realm
sub dbnewrealm($) {
	my ($d) = @_;

	if (!defined $d->{_db}->{name}) {
		die "no user details";
	}

	$d->{_realm} = dbmakenewrealmname($d);
	$d->{_x} = $d->{_db}->{lastx} || 0;
	$d->{_y} = $d->{_db}->{lasty} || 0;
}

sub computelocation($) {
	my ($d) = @_;

	# TODO - be more paranoid.  once we have an x/y pos, check that the
	# new map is comparable to the stored map, otherwise, create a new realm

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
		# FIXME - I am not checking for errors in the above..
		$d->{_realm} = '0';

		# FIXME - generalise these exeptions
		if ($d->{_y} > 990) {
			$d->{_realm} = 'Underground';

			# the only y > 520 realms that I have searched
			# appear to have a 1-1 correspondance to the '0' realm
			# with a 1000 offset.
			$d->{_x}-=1000;
			$d->{_y}-=1000;
		} elsif ($d->{_y} > 510) {
			$d->{_realm} = 'Barbelith';
		} elsif ($d->{_y} > 200) {
			$d->{_realm} = 'new:North of 200';
		}
		return;
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

	dbloaduser($d);

	# set a new realm if we need it
	if (defined $d->{_db}->{realm}) {
		if ($d->{_db}->{realm} eq '0') {
			dbnewrealm($d);
		} else {
			$d->{_realm} = $d->{_db}->{realm};
			$d->{_x} = $d->{_db}->{lastx} || 0;
			$d->{_y} = $d->{_db}->{lasty} || 0;
		}
	} else {
			dbnewrealm($d);
	}

	my $s = $d->{_textin} || '';


	# inertial navigation
	if ( $s =~ m/^You go North/ms) {
		$d->{_y}++;
	} elsif ( $s =~ m/^You go South/ms) {
		$d->{_y}--;
	} elsif ( $s =~ m/^You go East/ms) {
		$d->{_x}++;
	} elsif ( $s =~ m/^You go West/ms) {
		$d->{_x}--;

	# magic phrases
	} elsif ( $s =~ m/bolted behind you by a chuckling guard/ms) {
		# TODO - could check lastx,lasty
		$d->{_realm} = "Gauntlet";
		$d->{_x} = 0;
		$d->{_y} = 0;
	} elsif ( $s =~ m/fight your way from the pit to escape/ms) {
		$d->{_realm} = "The Pit";
		$d->{_x} = 0;
		$d->{_y} = 0;
	} elsif ( $s =~ m/You are absorbed into the mall/ms) {
		#$d->{_realm} = "The Mall Lobby";
		# FIXME - different entrances...
		dbnewrealm($d);
	} elsif ( $s =~ m/\*bing\*.* Floor: /ms) {
		# FIXME - examine string
		dbnewrealm($d);
		
	} elsif ( $s =~ m/You climb out of the tunnel. It comes out in the wilderness/ms) {
		# exiting the pit
		dbnewrealm($d);
	} elsif ( $s =~ m/You step onto the teleporter/ms) {
		# gauntlet, south road teleporter (and limbo teleporters)
		# tunnel teleporters.
		dbnewrealm($d);
	} elsif ( $s =~ m/It seems that you have been summoned/ms) {
		dbnewrealm($d);
	} elsif ( $s =~ m/The taxi driver asks you/ms) {
		dbnewrealm($d);
	} elsif ( $s =~ m/you are engulfed in a vortex/ms) {
		# this should catch talismans + stones/knifes/swords etc.
		dbnewrealm($d);

		# TODO - I could extract the city name from the elemental
		#	teleports and use that for a location fix
	} elsif ( $s =~ m/You go down the hole/ms) {
		# TODO: ensure that this is the only place that holes go to
		$d->{_realm}='Underground';
		#dbnewrealm($d);
	} elsif ( $s =~ m/You return to your previous location/ms) {
		# leaving Barbelith
		dbnewrealm($d);
	} elsif ( $s =~ m/You are taken to the ARENA/ms) {
		dbnewrealm($d);
	} elsif ( $s =~ m/The Diagnora pulls you under/ms) {
		dbnewrealm($d);

	# Magic locations..
	} elsif ( $d->{_db}->{realm} eq '0' && $d->{_x}==29 && $d->{_y}==40) {
		$d->{_realm} = "Elevator";
	}

	# TODO - no message when exiting the space elevator
	# bombsquad:
	#  enter/exit:	"You enter the tunnel..."
	#	set realm from _map->0->1->name, x&y borken
	#  travel:	"You walk the path..."
	#	set realm from _map->0->0->name, x&y borken
	# gauntlet:
	#  enter:	"You are blindfolded and led down many secret passages. After a long time your eyes are finally freed. You are pushed into a long dark tunnel which is bolted behind you by a chuckling guard."
	#  exit:	"You step onto the teleporter..."
	# desert road teleporter
	#  use:		"You step onto the teleporter..."
	# the pit:
	#  enter:	"The ground opens up and swallows you. You must fight your way from the pit to escape the evil of the socks."
	#  exit:	"You climb out of the tunnel. It comes out in the wilderness."
	# summon:
	#  		"A vortex sucks you up. It seems that you have been summoned by Great Lord Ignatz MD."
	#		"You pick up the Summon Stone (as is traditional)."
	# taxi:
	#		"Off we go..."
	#		"The taxi driver asks you if you saw the match..."
	#		"Nice weather..."
	#		"You arrive at The Festival"
	# limbo:
	#  enter:	"Due to a week of inactivity the gods decide to move you to Limbo."
	#		"You are in limbo..."
	#  exit:	"You step onto the teleporter..."
	# barbeleith:
	#  enter:	"As you break the Barbelith Talisman you are engulfed in a vortex."
	#  enters at random location?  Also, has intrinsic location available
	#  leave:	"You return to your previous location."
	# tunnels:
	#  enter1:	"You go down the hole."
	# the arena:
	#  enter:	"Poof! You are taken to the ARENA!"
	#
	# talisman:
	# emergency flare:
	# tokyo4:
	# kansas:
	# cloud land:
}

sub screenscrape($$) {
	my ($tree,$d) = @_;
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

	$node = $tree->look_down('id','maxap');
	if (!$node) {
		# logged out?  definitly not normal in any case...
		$d->{_state} = 'maxapnotfound';
		return;
	}

	# FIXME - very fragile
	$node = $tree->look_down(
		'_tag', 'div',
		'style', qr/^text/);
	if ($node) {
		$d->{_fullname} = $node->as_trimmed_text();
	}

	addidvalue($tree,$d,'id','ap','ap');
	addidvalue($tree,$d,'id','maxap','maxap');
	addidvalue($tree,$d,'id','hp','hp');
	addidvalue($tree,$d,'id','maxhp','maxhp');
	addidvalue($tree,$d,'id','gold','gold');

	$node = $tree->look_down(
		'_tag','textarea',
		'class','textin');
	if ($node) {
		$d->{_textin} = $node->as_text();
	}

	# id="inventory"

	addidvalue($tree,$d,'id','long','long');
	addidvalue($tree,$d,'id','lat','lat');

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

	return $d;
}


#
# Adds information from the session cookie to our dataset
#
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
		print LOG "REALM: $d->{_realm}\n";
		$haveloc=1;
	}
	print LOG $d->{_textin};

	# map data now goes to the database
	#return;
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
	close LOG;
}

sub dbsaveuser($) {
	my ($d) = @_;

	my $dbh = dbopen();

	if (!defined $d->{_logname}) {
		#die "no logname";
		return 0;
	}

	if (!defined $d->{_realm} || !defined $d->{_x}
		|| !defined $d->{_y} || !defined $d->{_time}) {
		# cannot save without information
		addtexttolog($d,"undefined values in dbsaveuser");
		return 0;
	}

	my $sth = $dbh->prepare_cached(qq{
		UPDATE user
		SET realm=?, lastx=?, lasty=?, lastseen=?
		WHERE name = ?
	});
	$sth->execute($d->{_realm},$d->{_x},$d->{_y},
		$d->{_time},$d->{_logname});
	$dbh->commit();

	return 1;
}

sub lookup($$$) {
	my ($realm,$x,$y) = @_;
	my $dbh = dbopen();

	my $lookup = $dbh->prepare_cached(qq{
		SELECT class,name
		FROM map
		WHERE realm=? AND x=? AND y=?
	}) or die $dbh->errstr;
	$lookup->execute($realm,$x,$y);
	my $res = $lookup->fetch;

	# convince the DBI to _STOP_ITS_WHINGING_
	$lookup->finish();

	if (!$res) {
		return undef;
	}
	return ('ok',$res->[0],$res->[1]);
}

# Merge the contents of realm2/x2/y2 into realm/x/y
# if realm3 is specified, copy the results into that realm (this allows a test)
# otherwise, just update the realm/x/y values
sub dbmergesquare($$$$$$$) {
	my ($realm,$x,$y,$realm2,$x2,$y2,$realm3) = @_;
	my $dbh = dbopen();

	# load square1
	# load square2

	# visitsR = visits1+visits2
	# lastvisitedR = max(lastvisited1,lastvisited2)

	#Assume that the square2 is more special
	# if textnote2 then textnoteR = textnote2

	# newer seen is squareN
	# older seen is squareO

	# classR = classN
	# if classN != classO then nameR = nameN
	# if nameN then nameR = nameN else nameR = nameO

	# if realm3 then realmR = realm3 else realmR = realm1
	# xR = x1, yR = y1
}

sub dumptodb($) {
	my ($d) = @_;
	my $realm;

	# use the defined timevalue
	my $time = $d->{_time};

	if (!defined $d->{_x} || !defined $d->{_y} || !defined $d->{_realm}) {
		return;
	}
	$realm = $d->{_realm};
	
	my $dbh = dbopen();

	# save the user's last known position
	if(!dbsaveuser($d)) {
		# bad!
		open(LOG,">>$cities::logfile");
		print LOG "ERROR: bad user $d->{_logname}\n";
		close(LOG);
		die "User $d->{_logname} does not exist in the database";
	}

	# dump the map data
	for my $x (keys %{$d->{_map}}) {
		for my $y (keys %{$d->{_map}->{$x}}) {
			my $thisrealm = $realm;
			my $class = $d->{_map}->{$x}->{$y}->{class};
			my $name = $d->{_map}->{$x}->{$y}->{name};

			my $thisx = $d->{_x} + $x;
			my $thisy = $d->{_y} + $y;

			# we dont need this extra guff poluting the db (i hope)
			$class =~ s/location //;
			$class =~ s/ map_loc//;
			$class =~ s/ indoor//;

			# TODO - generalise these exceptions
			# Argh!
			if (
				$class eq 'loc_vashka' ||
				$class eq 'loc_boat' ||
				$class eq 'loc_smoke' ||
				$class eq 'loc_flood' ||
				$class eq 'loc_dark' ||
				$class eq 'loc_bright' ||
				$class eq 'loc_snow' ||
				$class eq 'loc_muddry'
			) {
				$thisrealm=$realm.':ephemeral';
			} else {
				# delete any ephemeral on this spot
				my $delete = $dbh->prepare_cached(qq{
					DELETE FROM map
					WHERE realm=? AND x=? AND y=?
				}) || die $dbh->errstr;
				$delete->execute($thisrealm.':ephemeral',$thisx,$thisy);
				$delete->finish();
			}

			#print "XXX: $thisrealm,$thisx,$thisy\n";
			my ($ok,$cur_class,$cur_name) = lookup($thisrealm,$thisx,$thisy);
			if (!$ok) {
				# record does not exist, add it
				my $visits = $d->{_map}->{$x}->{$y}->{visits};
				if (!$visits) { $visits = 0; }
				my $insert = $dbh->prepare_cached(qq{
					INSERT
					INTO map(realm,x,y,class,name,visits,lastseen,lastchanged,lastchangedby)
					VALUES(?,?,?,?,?,?,?,?,?)
				}) or die $dbh->errstr;
				$insert->execute($thisrealm,$thisx,$thisy,
					$class,
					$name,
					$visits,
					$time,$time,$d->{_logname});
				next;
			}

			my $diff = 0;

			# FIXME - there is still some bugs in this logic
			if ($cur_class ne $class) {
				# the square has changed class
				$diff='newclass';
			} elsif (!defined $cur_name && defined $name) {
				# we have a name now, but did not previously
				$diff='name';
			} elsif (defined $cur_name && defined $name && $cur_name ne $name) {
				# The name has changed
				$diff='newname';
			}
			# else no name now or no change

			if ($diff) {
				# dont insert rollback entries for adding a name to a square
				# with no current name
				if ($diff ne 'name') {
					# insert the square into 'rollback'
					my $rollback = $dbh->prepare_cached(qq{
						INSERT OR REPLACE
						INTO map(realm,x,y,class,name,visits,lastseen,lastvisited,lastchanged,lastchangedby,textnote)
						SELECT ?,x,y,class,name,visits,lastseen,lastvisited,lastchanged,lastchangedby,textnote
						FROM map
						WHERE realm=? AND x=? AND y=?
					}) || die $dbh->errstr;
					$rollback->execute(
						$thisrealm.':rollback',
						$thisrealm,$thisx,$thisy
					);
					$rollback->finish();
				}

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
					$thisrealm,$thisx,$thisy);
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
				$thisrealm,$thisx,$thisy);
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
		$realm,($d->{_x}),($d->{_y}));

	$dbh->commit();

	# YEY, I have triggered an sqlite dbi bug http://rt.cpan.org/Public/Bug/Display.html?id=9643
	# basically, if you do not use a prepared sth, you cannot finish it
	# and the dbh destroy _WILL_ whinge at you.  Stupid stupid stupid

	#$dbh->disconnect;
}

sub addtexttolog($$) {
	my ($d,$text) = @_;
	my $dbh = dbopen();

	my $sth = $dbh->prepare_cached(qq{
		INSERT
		INTO userlog(name,date,gametime,realm,x,y,text)
		VALUES(?,?,?,?,?,?,?);
	}) or die $dbh->errstr;
	$sth->execute(
		$d->{_logname},
		time(),
		$d->{_clock},
		$d->{_realm},
		$d->{_x},
		$d->{_y},
		$text
	);
	$sth->finish();
	$dbh->commit();
}

sub dumptextintodb($) {
	my ($d) = @_;

	if (!$d->{_textin}) {
		return;
	}

	# remove unsavory comments..
	$d->{_textin} =~ s/^You go (North|South|East|West). ?$//ms;
	$d->{_textin} =~ s/^Now using .*$//ms;
	chomp($d->{_textin});

	if (!$d->{_textin}) {
		return;
	}

	if (!$d->{_logname}) {
		#die "no logname";
		return;
	}
	if (!$d->{_time}) {
		$d->{_time} = time();
	}

	addtexttolog($d,$d->{_textin});
}


1;

__END__

