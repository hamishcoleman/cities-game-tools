#!/usr/bin/perl -w
use strict;
#
# output one map tile
#

use CGI ':all';
use CGI::Carp qw(fatalsToBrowser);
use DBI;

use cities;

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

my $dbh = DBI->connect( "dbi:SQLite:$cities::db" ) || die "Cannot connect: $DBI::errstr";

my $sth = $dbh->prepare_cached(qq{
        SELECT class,name,visits
        FROM map
        WHERE realm='0' AND x=? AND y=?
}) || die $dbh->errstr;

$sth->execute($x,$y);
my $res = $sth->fetch();

if (!$res) {
	# no data on this square
	print $query->header;
	print "no data\n";
	exit;
}

my ($class,$name,$visits) = @{$res};
if (!$name) {$name = '';}

if ($t eq 'html') {
	print $query->header(-expires=>'+3d');
	print start_html(-title=>"Square $x,$y");
	print Link({-rel=>'stylesheet',-type=>'text/css',
		-href=>'http://cities.totl.net/game.css',
		-media=>'all'});
#		-style=>"http://www.zot.org/~hamish/cities/game.css",
#		-style=>'http://cities.totl.net/game.css',

#	print "<pre>\n";
#	print "$x,$y\n";
#	print $class,"\n";
#	print $name,"\n";
#	print $visits,"\n";
#	print "</pre>\n";

	print table({-border=>0,-cellspacing=>0,-cellpadding=>0},
		Tr(
			td({-class=>'location '.$class,-id=>'square',-width=>100,-height=>100},
				div($name)
			)
		)
	);
} else {
	print $query->header;
	print "unknown format";
}
