#
# This is a library for automated cities character actions
#
#

#
# An Item that can be in your inventory
#
package Cities::Item;
use strict;
use warnings;

sub new {
	my ($class,$value,$name) = @_;
	my $self = {};
	bless $self, $class;

	if (!$value) {
		die "Must have item codename"
	}
	$self->value($value);
	$self->name($name);

	return $self;
}

sub name {
	my ($self,$name) = @_;

	if (!$name) {
		# get
		return $self->{_name};
	}

	# set
	$self->{_name} = $name;

	if ($name =~ m/ x (\d+)$/) {
		$self->{_count} = $1;
	}
	if ($name =~ m/ \((\d+) (\d+)%\)( x |$)/) {
		$self->{_damage} = $1;
		$self->{_tohit} = $2/100;
		$self->{_weapon} = 1;
	}
}

sub value {
	my ($self,$value) = @_;

	if (!$value) {
		# get
		return $self->{_value};
	}

	#set
	$self->{_value}=$value;
}

sub container {
	my ($self,$v) = @_;

	if (!$v) {
		# get
		return $self->{_container};
	}

	#set
	$self->{_container}=$v;
}

sub wield {
	my ($self) = @_;

	if (!$self->{_container}) {
		die "Cannot wield an item with no container"
	}

	return $self->{_container}->_wield($self);
}

sub avgdamage {
	my ($self) = @_;

	if (!$self->{_weapon}) {
		return 0;
	}

	return $self->{_damage} * $self->{_tohit};
}

#
# The main robot system
#
package Robot;
use strict;
use warnings;


#
# Libs we need.
use Data::Dumper;
$Data::Dumper::Indent = 1;
$Data::Dumper::Sortkeys = 1;

use HTML::Form;

use cities;

sub dump {
	my ($self,$filename) = @_;

	if ($filename) {
		use FileHandle;
		my $fh = new FileHandle $filename,"w";
		if (!defined $fh) {
			die "could not open $filename $!\n";
		}

		$fh->print(Dumper($self));
	} else {
		print(Dumper($self));
	}
}

sub new {
	my $class = shift;
	my $self = {
		_username => shift,
		_password => shift,
	};

	if(!$self->{_username}) {
		die "Must specify character username";
	}

	use LWP::UserAgent;
	use HTTP::Cookies;

	$self->{_ua} = LWP::UserAgent->new;
	$self->{_ua}->agent("citieslib/1.0 ");
	$self->{_ua}->cookie_jar(HTTP::Cookies->new());

	$self->{_dbh} = dbopen();

	bless $self, $class;
	return $self;
}

sub populate_items_list {
	my ($self) = @_;

	if (!$self->{_form}) {
		die "No form data";
	}

	my $menu = $self->{_form}->find_input('item');
	#$menu->possible_values;

	# FIXME - depends on the internals of HTML::Form
	for (@{$menu->{menu}}) {
		my $item = Cities::Item->new($_->{value},$_->{name});
		$item->container($self);

		$self->{_items}{$_->{value}} = $item;
	}
	1;
}

sub populate_scrape_data {
	my ($self) = @_;

	if (!$self->{_res}) {
		# no result data to process
		die "no res data";
	}

	$self->{_form} = HTML::Form->parse($self->{_res});
	$self->{_form}->strict(1);

	# TODO - fixup maketreefromreq
	my $tree = HTML::TreeBuilder->new;
	$tree->store_comments(1);
	$tree->parse($self->{_res}->content);
	$tree->eof;
	$tree->elementify;

	# Done with the two users of the results
	delete $self->{_res};

	$self->{_d}={};
	screenscrape($tree,$self->{_d});

	# TODO - move this into the login method
	if ($self->{_d}->{_state} ne 'loggedin') {
		die "not logged in";
	}

	# Determine our x,y location and guess a realm
	computelocation($self->{_d});

	# Dump out the user and map data to the db
	#dumptodb($self->{_d});
	dumptextintodb($self->{_d});

	$self->populate_items_list;

	return 1;
}

sub request {
	my ($self,$req) = @_;

	if (!$req) {
		if ($self->{_res}) {
			warn "Not overwriting existing result data";
			return $self->{_res};
		}
		$req = HTTP::Request->new(GET => "$cities::baseurl/cgi-bin/game");
	}

	# TODO - fixup maketreefromreq
	my $res = $self->{_ua}->request($req);

	if (!$res->is_success) {
		die "login: ", $res->status_line;
	}

	if ($res->content_type ne 'text/html') {
		# awooga, awooga, this is not a parseable document...
		die "login: received ", $res->content_type;
	}

	# TODO - check if we are successfully logged in
	# see cities::screenscrape

	# cache this data for further processing
	$self->{_res} = $res;

	# and immediately process it
	$self->populate_scrape_data;

	return $res;
}

sub session {
	my ($self,$value) = @_;

	if (!$value) {
		# Get

## Disabled for simplicity
#		if (!$self->{_session}) {
#			my $sth = $self->{_dbh}->prepare_cached(qq{
#				SELECT session
#				FROM user
#				WHERE name = ?
#			});
#			$sth->execute($self->{_username});
#			my $res = $sth->fetch();
#			$sth->finish();
#
#			if (!$res) {
#				die "user $self->{_username} is not in the db";
#			}
#
#			$self->{_session} = $res->[0];
#		}
#
#		# now set the cookie, if we actually have a value
#		if ($self->{_session}) {
#			$self->{_ua}->cookie_jar->set_cookie(
#				0,'gamesession',$self->{_session},
#				'/',$cities::baseurl,undef,
#				1, undef, 500000, undef, undef
#			);
#		}

		return $self->{_session};
	}

	# Set
	$self->{_session} = $value;

	my $sth = $self->{_dbh}->prepare_cached(qq{
		UPDATE user
		SET session=?
		WHERE name = ?
	});
	$sth->execute($value,$self->{_username});
	$self->{_dbh}->commit();

	return $value;
}

sub login {
	my ($self) = @_;

	if($self->session) {
		# already logged in
		return 1;
	}

	if(!$self->{_password}) {
		# TODO - lookup session in user table
		die "Unknown password for character";
	}

	my $req = HTTP::Request->new(POST => "$cities::baseurl/cgi-bin/game");
	$req->content_type('application/x-www-form-urlencoded');
	$req->content("username=$self->{_username}&password=$self->{_password}");
	my $res = $self->request($req);

	# save the session cookie for later...
	my ($send_cookie_val,$send_cookie)
		= extractcookiefromres($res,'gamesession');
	$self->session($send_cookie_val);

	return 1;
}

sub _wield {
	my ($self,$item) = @_;

	if (!$self->{_form}) {
		$self->request;
		$self->{_form} || die "No form data";
	}

	my $olditem = $self->item($self->{_form}->value('item'));

	if (!$item) {
		die "Cannot wield a null value"
	}

	$self->{_form}->value('item',$item->value);

	# make it active
	$self->request($self->{_form}->click('act_null'));

	return $olditem;
}

sub item {
	my ($self,$item) = @_;

	if (!$self->{_items}) {
		$self->request;
		$self->{_items} || die "No items";
	}

	if ($item) {
		return $self->{_items}{$item};
	}
	return values %{$self->{_items}};
}

sub rxy {
	my ($self) = @_;

	if (!$self->{_d}) {
		$self->request;
		$self->{_d} || die "No scrape data";
	}

	return ($self->{_d}{_realm},$self->{_d}{_x},$self->{_d}{_y});
}

1;
__END__

use Data::Dumper;
$Data::Dumper::Indent = 1;
$Data::Dumper::Sortkeys = 1;

use robot;

my $r = Robot->new('_LOGNAME_','_PASSWORD_');
$r->login;
print "Robot is at ",join('/',$r->rxy),"\n";
$r->item('CruelBlade')->wield;

$r->monster - returns a direction object list
$r


#########################################


# TODO
# - select 'best' weapon (dont use cruel blade if not needed)
# - watch out for breaking weapons and stop before all are used
# - stop fighting if our hp gets too low
# - keep fighting if the monster is still alive

for my $dir (keys %{$d->{_dir}}) {
	if ($d->{_dir}{$dir}{state} ne 'fight') {
		# nothing to fight
		next;
	}
	if ($d->{_dir}{$dir}{hp} > 10) {
		# too big to auto-fight
		next;
	}

	my $inputname = 'act_fight_'.$dir;
	my $input = $form->find_input($inputname);
	if (!$input) {
		print "No button called $inputname\n";
		next;
	}

	my $req = $form->click($inputname);

	$cookie->add_cookie_header($req);
	my ($res,$tree) = maketreefromreq($req);
	if (!$res->is_success) {
		die "robot: ", $res->status_line;
	}
	if ($res->content_type ne 'text/html') {
		die "robot: received ", $res->content_type;
	}

	screenscrape($tree,$d);
	if ($d->{_state} ne 'loggedin') {
		die "not logged in";
	}
	computelocation($d);
	dumptextintodb($d);

}

# debugging
#print Dumper($d);
#print "\n";
#print $form->dump;


__END__
