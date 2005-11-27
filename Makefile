
all:

test:
	install -m a+rx game.cgi ~hamish/WWW/cities/
	install -m a+rx other.cgi ~hamish/WWW/cities/
	install -m a+rx cities.pm ~hamish/WWW/cities/
	install -m a+rx proxy.pm ~hamish/WWW/cities/
	install -m a+rx showmap.cgi ~hamish/WWW/cities/
	touch ~hamish/WWW/cities/gamelog.txt
	chmod a+rw ~hamish/WWW/cities/gamelog.txt

prof1:
	perl -d:DProf ./showmap.cgi >/dev/null
	dprofpp

