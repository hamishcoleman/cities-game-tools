#!/usr/bin/perl
use strict;
use warnings;
#
# Print out a HTML map from the database
#
# TODO - move those translations into the database
#
use CGI ':all';
use CGI::Carp qw(fatalsToBrowser);
use Data::Dumper;
use DBI;

use cities;

# Map key translations
my %shortname = (
#	Alchemist => 'A',
	'Cottage Hospital' => 'H',
	'Doctor' => 'H',
	'E. Market Outlet' => 'm',
	'E. Market Local Office' => 'o',
	'Eastern Market Office' => 'o',
	'Eastern Market' => 'm',
	'Eastern Marker' => '.',
	'First Aid Point' => 'H',
	'Flood' => 'F',
	'Graveyard' => 'g',
#	'Guard Tower' => 'G',
	Healer => 'H',
	'Healing Field' => 'H',
	'Herbert the Healer' => 'H',
	Hospital => 'H',
	'Hospital Satellite' => 'H',
	'Ice Station' => 'I',
	'Ice Trail' => '~',
	'Jude' => 'H',
	'Kill or Cure' => 'H',
	Marker => '.',
	Medic => 'H',
	Monastry => 'M',
	'Night Shrine' => '*',
	'Nightfall Shrine' => '*',
	'N. Market Outlet' => 'm',
	'N. Market Local Office' => 'o',
	'Northern Marker' => '.',
	'Northern Market' => 'm',
	'Northern Market Office' => 'o',
	'Oil Platform' => 'O',
	'Road Marker' => '.',
#	Ruin
	'Shrine of the Light' => '*',
	'S. Market Outlet' => 'm',
	'S. Market Local Office' => 'o',
	'Southern Market Office' => 'o',
	'Southern Market' => 'm',
	'Southern Marker' => '.',
	'Standing Stone' => 'S',
	'Stone Circle' => '*',
	'Track' => '~',
	'Trading Post' => 'T',
	'Trading Satellite' => 'T',
	Trail => '~',
	'W. Market Outlet' => 'm',
	'W. Market Local Office' => 'o',
	'Western Marker' => '.',
#	Well
#	'Wizards Tower' => 'W',

	# An unknown city square
	'Unknown Building' => '?',
);

my $query = new CGI;
print $query->header();

my $dbh = DBI->connect( "dbi:SQLite:$cities::db" ) || die "Cannot connect: $DBI::errstr";

my $lastx=20000;
my $lasty=20000;
my $lastrealm='0';

my $want_realm = param('realm');
my $realm;

my $d;
$d->{_state}='showmap';

addcookie($d,undef,$query->cookie('gamesession'));
if ($d->{_logname}) {

	# FIXME - should use dbloaduser...

	my $sth = $dbh->prepare(qq{
		SELECT realm,lastx,lasty
		FROM user
		WHERE name = ?
	}) || die $dbh->errstr;
	$sth->execute($d->{_logname});
	my $xy = $sth->fetch;
	$sth->finish();
	if ($xy) {
		$lastrealm = $xy->[0];
		$lastx = $xy->[1];
		$lasty = $xy->[2];
	}

	# if there no selected realm, choose the users current one
	if (!defined $want_realm) {
		$realm = $lastrealm;
	}

	# if the selected realm is the CURRENT one, set that
	if ($want_realm && $want_realm eq 'CURRENT') {
		$realm = $lastrealm;
	}
}

# if we dont yet have a realm set use the selected one
if (!defined $realm) {
	$realm = $want_realm;
}

# if there was not one selected, use the system default
if (!defined $realm) {
	$realm = '0';
}

# FIXME - my used/selected realm logic is working, but I dont know why
# 	When you first visit the showmap and are logged in, the CURRENT
#	realm is selected, but I have not programmed that to happen...

my $sth = $dbh->prepare(qq{
	SELECT min(x),max(x),min(y),max(y)
	FROM map
	WHERE realm=?
});
$sth->execute($realm);
my $maximums = $sth->fetch;
$sth->finish();

my $min_x=$ARGV[0] || $maximums->[0];
my $max_x=$ARGV[1] || $maximums->[1];
my $min_y=$ARGV[2] || $maximums->[2];
my $max_y=$ARGV[3] || $maximums->[3];

my $want_visits = ! $ARGV[4];

my $public=1;
if (url(-relative=>1) eq 'showmap.cgi') {
	$public=0;
}

if ($public) {
	# this is a public map...
	$want_visits = 0;		# never allowed
	if ($max_y>200) {$max_y=200;}	# hide the mess
}

print "<html><head><title>Cities Map</title>",
	'<link href="game.css" media="screen" rel="stylesheet" type="text/css">',
	"</head><body>\n";

print start_form(-method=>'GET',name=>"map");
print "<table border=1><tr>";

print "<td>";
{
	my $sth = $dbh->prepare(qq{
		SELECT DISTINCT realm
		FROM map
		ORDER BY realm
	}) || die $dbh->errstr;
	$sth->execute();
	my @realms;
	my $res;
	while ($res = $sth->fetch()) {
		push @realms,$res->[0];
	}

	if (defined $d->{_logname}) {
		unshift @realms,"CURRENT";
	}

	print	popup_menu(-name=>'realm',
			-default=>$want_realm,
			-values=>\@realms,
			-onchange=>'document.map.submit();'),
}
print "</td>";
#print "<td>Showing: $realm</td>\n";

print "<td>map size [$min_x,$max_y] - [$max_x,$min_y]</td>\n";
if (defined $d->{_logname}) {
	print "<td>";
	print "USER: $d->{_logname}";
	print " (Location: $lastx, $lasty, realm: $lastrealm)\n";
	print "</td>";
}

my $want_key = param('key');
print "<td>";
print checkbox(-name=>'key',
	-checked=>$want_key,
	-onchange=>'document.map.submit();');
print "</td>";

my $want_center = param('center');
print "<td>";
print checkbox(-name=>'center',
	-checked=>$want_center,
	-onchange=>'document.map.submit();');
print "</td>";

my $center_size=10;
if ($want_center && defined $d->{_logname}) {
	if ($max_x > $lastx+$center_size) {$max_x = $lastx+$center_size;}
	if ($min_x < $lastx-$center_size) {$min_x = $lastx-$center_size;}
	if ($max_y > $lasty+$center_size) {$max_y = $lasty+$center_size;}
	if ($min_y < $lasty-$center_size) {$min_y = $lasty-$center_size;}
}

# debug..
#print "<td>public==$public</td>";

print "</tr></table>\n";
print end_form;

###
### Dump the map key
###

if ($want_key) {
	# Print out the map key
	# TODO - sort by key _and_ then by name - easy when this is in the dB
	print "<table border=1><tr><th>icon</th><th>Full Name</th></tr>\n";
	for my $i (sort {$shortname{$a} cmp $shortname{$b}} keys %shortname) {
		print "<tr><th>$shortname{$i}</th><td>$i</td></tr>\n";
	}
	print "</table>\n";
}


###
### Dump the map
### 
print "<table border=0 cellpadding=0 cellspacing=0>\n";

# Stick an index along the top
print "<tr>";
my $skip = 2;
for my $col ($min_x..$max_x) {
	if ($col%10==0) {
		print "<td align='right' colspan=$skip>$col</td>";
		$skip=1;
	} else {
		$skip++;
	}
}
print "</tr>\n";

my $lookup = $dbh->prepare_cached(qq{
	SELECT class,name,visits
	FROM map
	WHERE realm=? AND x=? AND y=?
});

my $row=$max_y;
while ($row>$min_y-1) {
	print "<tr>";
	
	# Index the left
	if ($row%10==0) {
		print "<td>$row</td>";
	} else {
		print "<td>&nbsp;</td>";
	}

	my $skip = 0;
	for my $col ($min_x..$max_x) {
		$lookup->execute($realm,$col,$row);
		my $res = $lookup->fetch;

		if (!$res) {
			# no data for this location...
			$skip++;
			next;
		}

		my $class = $res->[0];
		my $name = $res->[1];
		my $visits = $res->[2];

		if ($class) {
			$class =~ s/location //;
			$class =~ s/ map_loc//;
		}

		if ($skip) {
			print "<td colspan=$skip></td>";
			$skip=0;
		}
		print '<td class="', $class, ' map_loc">';
		my $empty=1;

		# Show my last position
		if ($realm eq $lastrealm && $col==$lastx && $row==$lasty) {
			print "<b>X</b>";
			$empty=0;
		}

		# Mark crazy standing stones...
		if ($empty && $class eq 'loc_stone' && !defined $name) {
			$name = 'Standing Stone';
		}

		# Mark unknown city squares
		if ($empty && $class eq 'loc_city' && !defined $name) {
			$name = 'Unknown Building';
		}

		# If we have a map key for this location, use it
		if ($empty && defined $name && defined $shortname{$name}) {
			print $shortname{$name};
			$empty=0;
		} 

		if ($want_visits && $empty && $visits) {
			# mark the paths
			print '+';
			$empty=0;
		}

		# no grid square should be empty
		if ($empty) {
			print "&nbsp;"
		}
		print '</td>';
	}

	# 
	if ($skip) {
		print "<td colspan=$skip></td>";
		$skip=0;
	}

	# Index the right
	if ($row%10==0) {
		print "<td>$row</td>";
	}

	print "</tr>\n";
	$row--;
}

# Stick an index along the bottom
print "<tr>";
$skip=2;
for my $col ($min_x..$max_x) {
	if ($col%10==0) {
		print "<td align='right' colspan=$skip>$col</td>";
		$skip=1;
	} else {
		$skip++;
	}
}
print "</tr>\n";

print "</table>\n";

# TODO - print out the key

print "</body></html>\n";


