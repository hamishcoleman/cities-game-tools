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

sub id {
	return undef;
}

#
# A Map entry is an object that can appear on the map
# this is either a map square or a road between squares
#
package Cities::Map::Entry;

sub new {
	my ($invocant,$x,$y) = @_;
	my $class = ref($invocant) || $invocant;
	my $self = {};
	bless $self, $class;

	# FIXME - realms! and zero locations
	#if (!$x || !$y) {
	#	die "Locations must have both x and y";
	#}
	if (!$self->validxy($x,$y)) {
		die "Location $x, $y is not valid";
	}

	$self->{_x} = $x;
	$self->{_y} = $y;

	return $self;
}

sub xy {
	my ($self) = @_;
	return ($self->{_x},$self->{_y});
}

sub distance {
	my ($self,$l2) = @_;
	my ($x1,$y1) = $self->xy;
	my ($x2,$y2) = $l2->xy;

	my $dx = abs($x1-$x2);
	my $dy = abs($y1-$y2);

	return sqrt($dx ** 2 + $dy ** 2);
}

sub char {
	return "?";
}

sub is_location { return undef;}
sub is_road {return undef;}

#
# A Location is one of the map squares
#
package Cities::Location;
our @ISA = "Cities::Map::Entry";

sub validxy {
	my ($self,$x,$y) = @_;

	if (int($x) != $x) {
		return undef;
	}
	if (int($y) != $y) {
		return undef;
	}
	return 1;
}

sub is_location {
	return 1;
}

sub name {
	my ($self,$v) = @_;

	$v && ($self->{_name} = $v);
	return $self->{_name};
}

# Map key translations
my %shortname = (
	'Cottage Hospital' => 'H',
	'Doctor' => 'H',
	'First Aid Point' => 'H',
	'Herbert the Healer' => 'H',
	'Hospital' => 'H',
	'Hospital Satellite' => 'H',
	'Jude' => 'H',
	'Kill or Cure' => 'H',
	'Medic' => 'H',
	'Nobby' => 'H',
	'Road' => '#',
	'Teleport' => 't',
	'Ice Trail' => '~',
	'Track' => '~',
	'Trail' => '~',

	'Plains' => '_',
	'Field' => '_',
	'Valley' => '_',
);

sub char {
	my ($self) = @_;

	my $name = $self->name();
	if ($name) {
		if ($shortname{$name}) {
			return $shortname{$name};
		}
		return substr($name,0,1);
	}
	return '?';
}

#
# A Road is one of the links between Locations
#
package Cities::Road;
our @ISA = "Cities::Map::Entry";

sub validxy {
	my ($self,$x,$y) = @_;

	if ($x-int($x) == 0.5) {
		return 1;
	}
	if ($y-int($y) == 0.5) {
		return 1;
	}
	return undef;
}

sub is_road {
	return 1;
}

sub monster {
	my ($self,$v) = @_;

	$v && ($self->{_monster} = $v);
	return $self->{_monster};
}

sub state {
	my ($self,$v) = @_;

	$v && ($self->{_state} = $v);
	return $self->{_state};
}

sub char {
	my ($self) = @_;

	my $monster = $self->monster();
	if ($monster) {
		return '*';
	}
	return '+';
}

#
# A Map is a collection of Locations and Roads
#
package Cities::Map;

sub new {
	my ($invocant) = @_;
	my $class = ref($invocant) || $invocant;

	my $self = {};
	bless $self, $class;

	return $self;
}

# set current location
sub current {
	my ($self,$v) = @_;
	if ($v) {
		$v = $self->add($v);
		$self->{_current} = $v;
	}
	return $self->{_current};
}

sub add {
	my ($self,$v) = @_;

	my ($x,$y) = $v->xy();

	my $l = $self->{_map}{$x}{$y};
	if ($l) {
		# copy the location data, dont replace existing object
		# this means that existing refs stay valid
		# but also means that "add" essentially consumes the object
		# FIXME - doesnt cope if the class has changed

		for my $i (keys %{$v}) {
			$l->{$i} = $v->{$i};
		}
		$v = $l;
	} else {
		$self->{_map}{$x}{$y}=$v;
	}

	if ($v->can('name') && $v->name()) {
		# TODO - keep the closest one
		$self->{_recent}{$v->name()}=$v;
	}

	return $v;
}

sub _extents {
	my ($self) = @_;

	my ($x_min,$x_max,$y_min,$y_max);

	for my $x (keys %{$self->{_map}}) {
		if (!$x_min || $x < $x_min) {
			$x_min = $x;
		}
		if (!$x_max || $x > $x_max) {
			$x_max = $x;
		}
		for my $y (keys %{$self->{_map}{$x}}) {
			if (!$y_min || $y < $y_min) {
				$y_min = $y;
			}
			if (!$y_max || $y > $y_max) {
				$y_max = $y;
			}
		}
	}
	my $d = {};
	$d->{x}{min}=$x_min;
	$d->{x}{max}=$x_max;
	$d->{y}{min}=$y_min;
	$d->{y}{max}=$y_max;
	return $d;
}

sub get {
	my ($self,$x,$y) = @_;
	return $self->{_map}{$x}{$y};
}

sub print {
	my ($self) = @_;

	my $extent=$self->_extents();

	my $y = $extent->{y}{max};
	while ($y>=$extent->{y}{min}) {
		my $x = $extent->{x}{min};
		while ($x<=$extent->{x}{max}) {
			my $l = $self->get($x,$y);
			$x+=0.5;

			if (!$l) {
				print " ";
				next;
			}

			if ($l == $self->current) {
				# reverse vid
				print "\e[7m";
				print $l->char();
				# standard
				print "\e[0m";
				next;
			}

			print $l->char();
		}
		print "\n";
		$y-=0.5;
	}
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

sub location {
	my ($self,$v) = @_;

	$v && ($self->{_location} = $v);
	return $self->{_location};
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

	$self->{_map} = Cities::Map->new();

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
	$self->{_current_item} = $menu->value();

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

sub populate_locations {
	my ($self) = @_;

	my ($x,$y) = $self->{_map}->current()->xy();

	for my $dx (keys %{$self->{_d}{_map}}) {
		for my $dy (keys %{$self->{_d}{_map}{$dx}}) {
			my $l = Cities::Location->new($x+$dx,$y+$dy);
			$l->name($self->{_d}{_map}{$dx}{$dy}{name});

			$self->{_map}->add($l);
		}
	}
}

sub populate_roads {
	my ($self) = @_;

	my ($x,$y) = $self->{_map}->current()->xy();

	for my $dx (keys %{$self->{_d}{_dir}}) {
		for my $dy (keys %{$self->{_d}{_dir}{$dx}}) {
			my $dirent = $self->{_d}{_dir}{$dx}{$dy};
			my $l = Cities::Road->new($x+$dx,$y+$dy);

			$l->monster($dirent->{monster});
			$l->state($dirent->{state});

			$l = $self->{_map}->add($l);

			if ($dirent->{action}) {
				my $action = $self->action($dirent->{action});
				if ($action->id) {
					$action->ap($dirent->{ap});
					$action->location($l);
				}
			}

		}
	}
}

sub populate_scrape_data {
	my ($self) = @_;

	if (!$self->{_res}) {
		# no result data to process
		die "no res data";
	}

	$self->{_form} = HTML::Form->parse($self->{_res});
	$self->{_form}->strict(1);

	my $content = $self->{_res}->content;
        $content =~ s/(?<!<div>)\(dark\)<\/div>/<div>(dark)<\/div>/g;

	# TODO - fixup maketreefromreq
	my $tree = HTML::TreeBuilder->new;
	$tree->store_comments(1);
	#$tree->parse($self->{_res}->content);
	$tree->parse($content);
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

	$self->{_map}->current(
		Cities::Location->new(
			$self->{_d}{_x},
			$self->{_d}{_y}
		)
	);

	$self->populate_items_list;
	$self->populate_actions_list;

	$self->populate_locations;
	$self->populate_roads;

	# FIXME - populate current_item from new fangled interface
	# look_down id=current_item, look_down _tag=a
	# href="http://wiki.cities.totl.net/index.php?title=RustySword"
	# title=RustySword
	# current_item=title

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

sub current_item {
	my ($self) = @_;

	return $self->item($self->{_current_item});
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

	# clicking on something could change the inventory, so delete it
	delete $self->{_items};

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

	return ($self->{_d}{_realm},$self->{_map}->current()->xy());
}

sub ap {
	my ($self) = @_;

	if (!$self->{_d}) {
		$self->request;
		$self->{_d} || die "No scrape data";
	}

	return ($self->{_d}{ap});
}

sub map {
	my ($self) = @_;
	return ($self->{_map});
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
$r->dump('out.txt');

$r->map->print();

$r->item('CruelBlade')->wield;

# If possible, use a monastry
$r->action('act_retreat')->click;

# If possible, use the cornucopia
$r->action('act_item_eat')->click;
$r->action('act_item_drink')->click;

my $r = Robot->new('_LOGNAME_','_PASSWORD_');
$r->monster - returns a direction object list


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
