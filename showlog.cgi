#!/usr/bin/perl
use strict;
use warnings;
#
# Print out the user's log
#
#
use CGI qw/:all -nosticky/;
use CGI::Carp qw(fatalsToBrowser);
use Data::Dumper;
use DBI;
use HTTP::Date qw(time2iso time2isoz);

use cities;

my $query = new CGI;
print $query->header();

# spit the header out before we do anything that could cause an error message..
print <<EOF;
<html>
 <head>
  <title>Cities Log</title>
  <link href="game.css" media="screen" rel="stylesheet" type="text/css">
 </head>
<body>
EOF

my $dbh = dbopen();

my $d;
$d->{_state}='showlog';

if (!$query->request_method) {
	print "commandline test mode\n";
	$d->{_logname} = $ARGV[0];
} else {
	addcookie($d,undef,$query->cookie('gamesession'));
}

if (!$d->{_logname}) {
	die "you are not logged in\n";
}

my $want_name = param('wn') || $d->{_logname};
my $count= param('count') || 100;

print $want_name,"\n";

my $sth = $dbh->prepare(qq{
	SELECT realm,x,y,date,gametime,text
	FROM userlog
	WHERE name=?
	ORDER BY entry DESC
	LIMIT 400
}) || die $dbh->errstr;
$sth->execute($want_name);

print "<table border=1>";

while (my $res = $sth->fetch()) {
	my ($realm,$x,$y,$gametime);

	if (!$count--) {
		last;
	}

	if (defined $res->[0]) {
		$realm = $res->[0];
	} else {
		$realm = 'unknown';
	}
	if (defined $res->[1]) {
		$x = $res->[1];
	} else {
		$x = '?';
	}
	if (defined $res->[2]) {
		$y = $res->[2];
	} else {
		$y = '?';
	}

	print "<tr>";
	print "<td valign=top>\n";
	#print "gametime: $res->[4]\n";
	if (defined $res->[4]) {
		print "$res->[4]<br>\n";
	} else {
		print time2isoz($res->[3]),"<br>\n";
	}
	print time2iso($res->[3]),"<br>\n";
	print "LOC: $realm/$x/$y<br>\n";
	print "</td><td valign=top>\n<pre>";
	print "$res->[5]";
	print "</pre>\n</td>";
	print "</tr>\n\n";
	#print Dumper($res);
}

print "</table>";
print "</body></html>\n";


