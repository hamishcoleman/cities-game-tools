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
		print redirect('http://cities.totl.net/images/road.jpg');
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
