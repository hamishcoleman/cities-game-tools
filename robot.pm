#
# This is a library for automated cities character actions
#
#
use strict;
use warnings;


#
# Handler for activities touching a null result
# - click is for null actions
# - wield is for null items
#
# Basically, if you search for a item/action that is not present, you will
# get an instance of this class instead of an undef
#
package Cities::Null;

sub new {
	my ($class,$id) = @_;
	my $self = { _id => $id };
	bless $self, $class;
	return $self;
}

sub click {
	my ($self) = @_;
	warn "Attempting to click a null action ($self->{_id})";
	return undef;
}

sub wield {
	my ($self) = @_;
	warn "Attempting to wield a null item ($self->{_id})";
	return undef;
}

#
# An Action is any of the buttons on the screen
#
package Cities::Action;

sub new {
	my ($class,$id,$text) = @_;
	my $self = {};
	bless $self, $class;

	if (!$id) {
		die "Actions must have ids";
	}
	$self->id($id);
	$self->text($text);

	return $self;
}

sub container {
	my ($self,$v) = @_;

	$v && ($self->{_container} = $v);
	return $self->{_container};
}

sub id {
	my ($self,$v) = @_;

	$v && ($self->{_id} = $v);
	return $self->{_id};
}

sub ap {
	my ($self,$v) = @_;

	$v && ($self->{_ap} = $v);
	return $self->{_ap};
}

sub text {
	my ($self,$v) = @_;

	$v && ($self->{_text} = $v);

	if ($v && $v =~ m/ \((\d+) AP\)$/) {
		$self->ap($1);
	}

	return $self->{_text};
}

sub click {
	my ($self,$force) = @_;

	if (!$self->container) {
		die "Must have a container to click";
	}

	if (!$force
	    && $self->{_ap}
	    && ($self->{_ap} +10) > $self->container->ap) {
		# not enough AP to click
		# NOTE: hardcoded guard of 10 spare AP
		return undef;
	}

	return $self->container->_click($self);
}

#
# An Item that can be in your inventory
#
package Cities::Item;

sub new {
	my ($class,$id,$text) = @_;
	my $self = {};
	bless $self, $class;

	if (!$id) {
		die "Must have item codename"
	}
	$self->id($id);
	$self->text($text);

	return $self;
}

sub text {
	my ($self,$text) = @_;

	if (!$text) {
		# get
		return $self->{_text};
	}

	# set
	$self->{_text} = $text;

	if ($text =~ m/ x (\d+)$/) {
		$self->{_count} = $1;
	}
	if ($text =~ m/ \((\d+) (\d+)%\)( x |$)/) {
		$self->{_damage} = $1;
		$self->{_tohit} = $2/100;
		$self->{_weapon} = 1;
	}
}

sub id {
	my ($self,$id) = @_;

	if (!$id) {
		# get
		return $self->{_id};
	}

	#set
	$self->{_id}=$id;
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

	if (!$self->container) {
		die "Cannot wield an item with no container"
	}

	return $self->container->_wield($self);
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

sub populate_items_list_ajax {
	# use the new fangled interface for getting the items list
	my ($self) = @_;

	my $req = HTTP::Request->new(GET => "$cities::baseurl/cgi-bin/ajaxitems?cat=all");
	my $res = $self->{_ua}->request($req);

	if (!$res->is_success) {
		die "ajax: ", $res->status_line;
	}

	if ($res->content_type ne 'text/html') {
		# awooga, awooga, this is not a parseable document...
		die "ajax: received ", $res->content_type;
	}

	# TODO - fixup maketreefromreq
	my $tree = HTML::TreeBuilder->new;
	$tree->store_comments(1);
	$tree->parse($res->content);
	$tree->eof;
	$tree->elementify;

	for my $i ($tree->look_down('_tag','a')) {
		my $text = $i->as_trimmed_text();
		my $href = $i->attr('href');
		my $id;
		if ($href =~ m/item=(.*)/) {
			$id = $1;
		} else {
			# filter out the quickdraw <a>'s
			next;
		}

		my $item = Cities::Item->new($id,$text);
		$item->container($self);

		$self->{_items}{$id} = $item;
	}
	1;
}

sub populate_actions_list {
	my ($self) = @_;

	if (!$self->{_form}) {
		die "No form data";
	}

	for ($self->{_form}->find_input) {
		next if (!$_->name);
		my $action = Cities::Action->new($_->name,$_->value);
		$action->container($self);

		$self->{_actions}{$_->{name}} = $action;
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

	# Keep a copy for debugging
	$self->{_resold} = $self->{_res};

	# Done with the two users of the results
	delete $self->{_res};

	$self->{_d}={};
	screenscrape($tree,$self->{_d});

	# TODO - move this into the login method
	if ($self->{_d}->{_state} ne 'loggedin') {
		die "not logged in";
	}

	# FIXME - dbloaduser depends on _logname
	# computlocation calls dbloaduser if it needs some inertial tracking
	$self->{_d}->{_logname} = $self->{_username};

	# Determine our x,y location and guess a realm
	computelocation($self->{_d});

	# Dump out the user and map data to the db
	#dumptodb($self->{_d});
	dumptextintodb($self->{_d});

	$self->populate_items_list;
	$self->populate_actions_list;

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
	# convince the DBI to _STOP_ITS_WHINGING_
	$sth->finish();

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

	if ($self->{_form}->find_input('item')) {
		# old interface
		my $olditem = $self->item($self->{_form}->value('item'));

		if (!$item) {
			die "Cannot wield a null value"
		}

		$self->{_form}->value('item',$item->id);

		# make it active
		$self->request($self->{_form}->click('act_null'));

		return $olditem;
	}

	# new fangled ajax interface
	my $id = $item->id;
	my $req = HTTP::Request->new(GET => "$cities::baseurl/cgi-bin/game?item=$id");
	$self->request($req);
}

sub item {
	my ($self,$item) = @_;

	if (!$self->{_items}) {
		$self->populate_items_list_ajax;
		$self->{_items} || die "No items";
	}

	if ($item) {
		my $item = $self->{_items}{$item};
		if ($item) {
			return $item;
		}
		return Cities::Null->new($item);
	}
	return values %{$self->{_items}};
}

sub _click {
	my ($self,$action) = @_;

	if (!$self->{_form}) {
		$self->request;
		$self->{_form} || die "No form data";
	}

	if (!$action) {
		die "Cannot action a null value"
	}

	$self->request($self->{_form}->click($action->id));
}

sub action {
	my ($self,$action) = @_;

	if (!$self->{_actions}) {
		$self->request;
		$self->{_actions} || die "No items";
	}

	if ($action) {
		my $action = $self->{_actions}{$action};
		if ($action) {
			return $action;
		}
		return Cities::Null->new($action);
	}
	return values %{$self->{_actions}};
}

sub rxy {
	my ($self) = @_;

	if (!$self->{_d}) {
		$self->request;
		$self->{_d} || die "No scrape data";
	}

	return ($self->{_d}{_realm},$self->{_d}{_x},$self->{_d}{_y});
}

sub ap {
	my ($self) = @_;

	if (!$self->{_d}) {
		$self->request;
		$self->{_d} || die "No scrape data";
	}

	return ($self->{_d}{ap});
}

1;
__END__


use Data::Dumper;
$Data::Dumper::Indent = 1;
$Data::Dumper::Sortkeys = 1;

use robot;

my $r = Robot->new('_LOGNAME_','_PASSWORD_');
my $r = Robot->new('_LOGNAME_','_PASSWORD_');

$r->login;
print "Robot is at ",join('/',$r->rxy),"\n";
$r->item('CruelBlade')->wield;

# If possible, use a monastry
$r->action('act_retreat')->click;

# If possible, use the cornucopia
$r->action('act_item_eat')->click;
$r->action('act_item_drink')->click;

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
