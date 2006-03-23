#!/usr/bin/perl -w
use strict;
#
# output one map tile
#

use CGI ':all';
use CGI::Carp qw(fatalsToBrowser);
use DBI;

use cities;

my %images = (
	'' => 'http://cities.totl.net/images/grass.jpg',
	loc_null => 'black.jpg',
	loc_city => 'http://cities.totl.net/images/road.jpg',
	loc_road => 'http://cities.totl.net/images/road.jpg',
	loc_boat => 'http://cities.totl.net/images/boat.png',
	loc_space => 'http://cities.totl.net/images/space.jpg',
	loc_cloud => 'http://cities.totl.net/images/clouds.jpg',
	loc_beach => 'http://cities.totl.net/images/beach.png',
	loc_swamp => 'http://cities.totl.net/images/swamp.png',
	loc_sewage => 'http://cities.totl.net/images/slime.jpg',
	loc_lava => 'http://cities.totl.net/images/lava.jpg',
	loc_water => 'http://cities.totl.net/images/water.png',
	loc_ocean => 'http://cities.totl.net/images/water.png',
	loc_cave => 'http://cities.totl.net/images/cave.png',
	loc_mountain => 'http://cities.totl.net/images/crags.jpg',
	loc_crags => 'http://cities.totl.net/images/crags.jpg',
	loc_jungle => 'http://cities.totl.net/images/jungle.png',
	loc_forest => 'http://cities.totl.net/images/forest.jpg',
	loc_desert => 'http://cities.totl.net/images/badlands.png',
	loc_badlands => 'http://cities.totl.net/images/badlands.png',
	loc_stone => 'http://cities.totl.net/images/road.jpg',
	loc_dragon => 'http://cities.totl.net/images/dragon.png',
	loc_mudwet => 'http://cities.totl.net/images/mudwet.jpg',
	loc_muddry => 'http://cities.totl.net/images/muddry.jpg',
	loc_snow => 'http://cities.totl.net/images/snow.png',
	loc_ice => 'http://cities.totl.net/images/ice.jpg',
	loc_glacier => 'http://cities.totl.net/images/glacier.jpg',
	loc_tunnel => 'http://cities.totl.net/images/tunnel.jpg',
	loc_doore => 'http://cities.totl.net/images/doore.jpg',

#.loc_goth {
#	background-image: none;
#	font-weight: bold;
#	background-color: black;
#	color: red;
#	border: solid 1px red;
#}

);

sub lookup($$) {
	my ($x,$y) = @_;

	my $dbh = DBI->connect( "dbi:SQLite:$cities::db" ) || die "Cannot connect: $DBI::errstr";

	my $sth = $dbh->prepare_cached(qq{
		SELECT class,name,visits
		FROM map
		WHERE realm='0' AND x=? AND y=?
	}) || die $dbh->errstr;

	$sth->execute($x,$y);
	my $res = $sth->fetch();

	if (!$res) {
		return undef;
	}

	my ($class,$name,$visits) = @{$res};
	if (!$name) {$name = '';}
	return ($class,$name,$visits);
}

sub out_html_table($$) {
	my ($class,$name) = @_;
	return "<table><tr><td class=\"location $class\" height=\"100\" width=\"100\"><div>$name</div></td></tr></table>";
}

my $query = new CGI;

if (!$query->request_method) {
	print "commandline test mode\n";
}

my $x = int(param('x'));
my $y = int(param('y'));
my $t = param('t');	# data type requested

if (!defined $x || !defined $y) {
	print $query->header;
	print "no square\n";
	exit;
}

if (!defined $t) {
	$t='html';
}

if ($t eq 'html') {
	# Basic printout
	my ($class,$name,$visits) = lookup($x,$y);

	print $query->header(-expires=>'+3d');
	print "<html><head><title>Square $x,$y</title>\n";
	print '<link type="text/css" media="all" rel="stylesheet" href="http://cities.totl.net/game.css" />';
	print '</head><body>';
	if ($class) {
		print out_html_table($class,$name);
	} else {
		print "no data\n";
	}
	print '</body></html>';
} elsif ($t eq 'js') {
	# a javascript fragment
	my ($class,$name,$visits) = lookup($x,$y);

	print $query->header('text/javascript');
	if ($class) {
		print "document.write('",out_html_table($class,$name),"');\n";
	} else {
		print "document.write('no data');\n";
	}
} elsif ($t eq 'jsi') {
	# something to include the javascript fragment
	print $query->header(-expires=>'+3d');
	print "<html><head><title>Square $x,$y</title>\n";
	print '<link type="text/css" media="all" rel="stylesheet" href="http://cities.totl.net/game.css" />';
	print "</head><body>\n";
	print '<script type="text/javascript" src="?',"x=$x&y=$y&t=js",'"></script>';
	print "</body>\n";
} elsif ($t eq 'mm') {
	# moving map image
	my ($class,$name,$visits) = lookup($x,$y);

	if ($class) {
		my $image = $images{$class};
		if (defined $image) {
			print redirect($image);
		} else {
			print redirect('http://cities.totl.net/images/grass.jpg');
		}
	} else {
		print redirect('black.jpg');
	}
} elsif ($t eq 'mmi') {
	# include the moving map image
	print $query->header(-expires=>'+3d');
	print "<html><head><title>Square $x,$y</title>\n";
	print '<link type="text/css" media="all" rel="stylesheet" href="http://cities.totl.net/game.css" />';
	print "</head><body>\n";
	print '<img href="text/javascript" src="?',"x=$x&y=$y&t=mm",'">';
	print "</body>\n";
} else {
	print $query->header;
	print "unknown format";
}
