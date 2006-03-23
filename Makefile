
all:

test:
	install -m a+rx game.cgi ~hamish/WWW/cities/
	install -m a+rx other.cgi ~hamish/WWW/cities/
	install -m a+r cities.pm ~hamish/WWW/cities/
	install -m a+r proxy.pm ~hamish/WWW/cities/
	install -m a+rx showmap.cgi ~hamish/WWW/cities/
	install -m a+rx map.cgi ~hamish/WWW/cities/
	install -m a+r game.css ~hamish/WWW/cities/
	install -m a+r black.jpg ~hamish/WWW/cities/
	touch ~hamish/WWW/cities/gamelog.txt
	chmod a+rw ~hamish/WWW/cities/gamelog.txt
	install -d -m a+rwx ~hamish/WWW/cities/db

# FIXME - install a database if this is not already one there

prof1:
	perl -d:DProf ./showmap.cgi >/dev/null
	dprofpp

prof2:
	perl -d:DProf ./showmap.cgi 1 10 1 10 >/dev/null
	dprofpp

profmap:
	perl -d:DProf ./map.cgi x=4 y=4 >/dev/null
	dprofpp

