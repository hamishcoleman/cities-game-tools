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

sub out_html_table {
	return "<table><tr><td class=\"location $class\" height=\"100\" width=\"100\"><div>$name</div></td></tr></table>";
}

if ($t eq 'html') {
	print $query->header(-expires=>'+3d');
	print '<html><head><title>Square $x,$y</title>';
	print '<link type="text/css" media="all" rel="stylesheet" href="http://cities.totl.net/game.css" />';
	print '</head><body>';
	print out_html_table();
	print '</body></html>';
} elsif ($t eq 'js') {
	print $query->header('text/javascript');
	print "document.write('",out_html_table(),"');\n";
} elsif ($t eq 'jsi') {
	print $query->header(-expires=>'+3d');
	print '<html><head><title>Square $x,$y</title>';
	print '<link type="text/css" media="all" rel="stylesheet" href="http://cities.totl.net/game.css" />';
	print "</head><body>\n";
	print '<script type="text/javascript" src="?',"x=$x&y=$y&t=js",'"></script>';
	print "</body>\n";
} else {
	print $query->header;
	print "unknown format";
}
