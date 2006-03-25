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
use HTTP::Date qw(time2iso);

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

print $want_name,"\n";

my $sth = $dbh->prepare(qq{
	SELECT realm,x,y,date,gametime,text
	FROM userlog
	WHERE name=?
	ORDER BY date DESC
}) || die $dbh->errstr;
$sth->execute($want_name);

print "<table border=1>";

while (my $res = $sth->fetch()) {
	print "<tr>";
	print "<td valign=top>\n";
	#print "gametime: $res->[4]\n";
	print time2iso($res->[3]),"<br>\n";
	print "LOC: $res->[0]/$res->[1]/$res->[2]<br>\n";
	print "</td><td valign=top>\n<pre>";
	print "$res->[5]";
	print "</pre>\n</td>";
	print "</tr>\n\n";
	#print Dumper($res);
}

print "</table>";
print "</body></html>\n";


