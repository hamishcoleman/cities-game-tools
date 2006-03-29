#!/usr/bin/perl
use strict;
use warnings;
#
# Print out a HTML map from the database
#
# TODO - move those translations into the database
#
use CGI qw/:all -nosticky/;
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
	Lounge => 'T',
	Marker => '.',
	Medic => 'H',
	Monastry => 'M',
	'Night Shrine' => '*',
	'Nightfall Shrine' => '*',
	'N. Market Outlet' => 'm',
	'N. Market Local Office' => 'o',
	Nobby => 'H',
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

# spit the header out before we do anything that could cause an error message..
print <<EOF
<html>
 <head>
  <title>Cities Map</title>
  <link href="game.css" media="screen" rel="stylesheet" type="text/css">
 </head>
 <script type="text/javascript">

function togglekey() {
	keydiv = document.getElementById('keydiv');
	keybox = document.getElementById('keybox');
	if (keybox.checked) {
		keydiv.style.display='block';
	} else {
		keydiv.style.display='none';
	}
}

 </script>
<body>
EOF
;

my $dbh = DBI->connect( "dbi:SQLite:$cities::db" ) || die "Cannot connect: $DBI::errstr";

my $lastx=20000;
my $lasty=20000;
my $lastrealm='0';

my $want_realm = param('realm');
my $realm;

my $d;
$d->{_state}='showmap';

$d->{_logname} = param('wn');
if (!defined $d->{_logname}) {
	addcookie($d,undef,$query->cookie('gamesession'));
}

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

# map extants rectangle
my $map_min_x= $maximums->[0];
my $map_max_x= $maximums->[1];
my $map_min_y= $maximums->[2];
my $map_max_y= $maximums->[3];

# Display area rectangle
my $min_x=param('x1') || $ARGV[0] || $map_min_x;
my $max_x=param('x2') || $ARGV[1] || $map_max_x;
my $min_y=param('y1') || $ARGV[2] || $map_min_y;
my $max_y=param('y2') || $ARGV[3] || $map_max_y;

my $want_visits = param('visits') || $ARGV[4];

my $public=1;
if (url(-relative=>1) eq 'showmap.cgi') {
	$public=0;
}

if ($public) {
	# this is a public map...
	$want_visits = 0;		# never allowed publicly
	if ($max_y>200) {$max_y=200;}	# hide the mess
	if ($map_max_y>200) {$map_max_y=200;}	# hide the mess
}


print start_form(-method=>'GET',name=>"tools");
if (param('wn')) {
	print hidden('wn',param('wn'));
}

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
	$sth->finish();

	if (defined $d->{_logname}) {
		unshift @realms,"CURRENT";
	}

	print	popup_menu(-name=>'realm',
			-default=>$want_realm,
			-values=>\@realms,
			-onchange=>'document.tools.submit();'),
}
print "</td>";
#print "<td>Showing: $realm</td>\n";

print "<td>map size [$map_min_x,$map_max_y] - [$map_max_x,$map_min_y]</td>\n";
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
	-id=>'keybox',
	-onchange=>'togglekey();');
print "</td>";

my $want_center = param('center');
if (defined $d->{_logname}) {
	print "<td>";
	print checkbox(-name=>'center',
		-checked=>$want_center,
		-onchange=>'document.tools.submit();');
	print "</td>";
}

my $center_size=10;
if ($want_center && defined $d->{_logname}) {
	if ($max_x > $lastx+$center_size) {$max_x = $lastx+$center_size;}
	if ($min_x < $lastx-$center_size) {$min_x = $lastx-$center_size;}
	if ($max_y > $lasty+$center_size) {$max_y = $lasty+$center_size;}
	if ($min_y < $lasty-$center_size) {$min_y = $lasty-$center_size;}
}

my $want_zoom = param('zoom');
if (($want_zoom || $want_center) && defined $d->{_logname}) {
	print "<td>";
	print checkbox(-name=>'zoom',
		-checked=>$want_zoom,
		-onchange=>'document.tools.submit();');
	print "</td>";
}

if (!$public) {
	print "<td>";
	print checkbox(-name=>'visits',
		-checked=>$want_visits,
		-onchange=>'document.tools.submit();');
	print "</td>";
}

# debug..
#print "<td>public==$public</td>";

print "</tr></table>\n";
print end_form;

###
### Dump the map key
###

# Print out the map key
# TODO - sort by key _and_ then by name - easy when this is in the dB

if ($want_key) {
	print "<div id='keydiv'>\n";
} else {
	print "<div id='keydiv' style='display:none'>\n";
}
print "<table border=1><tr><th>icon</th><th>Full Name</th></tr>\n";
for my $i (sort {$shortname{$a} cmp $shortname{$b}} keys %shortname) {
	print "<tr><th>$shortname{$i}</th><td>$i</td></tr>\n";
}
print "</table>\n";
print "</div>\n";


###
### Container and arrows
print "<table>\n";
print "<tr>";

#top,left
print "<td>";
if ($min_x > $map_min_x && $max_y < $map_max_y) {
	print "NW";
}
print "</td>";

#top
print "<td align=center>";
if ($max_y < $map_max_y) {
	print "North";
}
print "</td>";

#top,right
print "<td>";
if ($max_x < $map_max_x && $max_y < $map_max_y) {
	print "NE";
}
print "</td>";

print "</tr><tr>";

#left
print "<td>";
if ($min_x > $map_min_x) {
	print "West";
}
print "</td>";

print "<td>";
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

my $row=$max_y;
while ($row>$min_y-1) {
	print "<tr>";
	
	# Index the left
	if ($row%10==0) {
		print "<td>$row</td>";
	} else {
		print "<td>&nbsp;</td>";
	}

	my $lookup = $dbh->prepare_cached(qq{
		SELECT x,y,class,name,visits
		FROM map
		WHERE realm=? AND x>=? AND x<=? AND y=?
		ORDER BY x
	});
	$lookup->execute($realm,$min_x,$max_x,$row);

	my $skip = 0;
	my $lastcol;
	while (my $res = $lookup->fetch) {
		my $col = $res->[0];
		my $thisy = $res->[1];
		my $class = $res->[2];
		my $name = $res->[3];
		my $visits = $res->[4];

		if (!defined $lastcol) {
			$lastcol = $min_x;
		}
		if ($col > ($lastcol+1)) {
			$skip = $col - ($lastcol+1);
		}

		if ($class) {
			$class =~ s/location //;
			$class =~ s/ map_loc//;
		}

		if ($skip) {
			print "<td colspan=$skip></td>";
			$skip=0;
		}
		if ($want_zoom) {
			print '<td class="location ', $class, '">';
			print '<div>',($name||'&nbsp;'),'</div>';
		} else {
			print '<td class="', $class, ' map_loc">';
		}
		my $empty=1;

		# Show my last position
		# in this realm only, unless we are centering.  The assumption
		# being that we may be in an unknown realm and want to track
		# our progress on a known realm..
		if (($col==$lastx && $row==$lasty) && 
		    ($want_center || $realm eq $lastrealm)) {
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

		# no grid square should be empty (zoomed squares have content)
		if ($empty && !$want_zoom) {
			print "&nbsp;"
		}
		print '</td>';
		$lastcol=$col;
	}
	$lookup->finish();

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

###
### Container and arrows
print "</td>";

#right
print "<td>";
if ($max_x < $map_max_x) {
	print "East";
}
print "</td>";

print "</tr><tr>";

#bottom,left
print "<td>";
if ($min_x > $map_min_x && $min_y > $map_min_y) {
	print "SW";
}
print "</td>";

#bottom
print "<td align=center>";
if ($min_x > $map_min_x) {
	print "South";
}
print "</td>";

#bottom,right
print "<td>";
if ($max_x < $map_max_x && $min_y > $map_min_y) {
	print "SE";
}
print "</td>";

print "</tr></table>";


print "</body></html>\n";


