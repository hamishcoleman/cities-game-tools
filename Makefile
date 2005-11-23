
all:

test:
	install -m a+rx game.cgi ~hamish/WWW/test/
	install -m a+rx other.cgi ~hamish/WWW/test/
	install -m a+rx cities.pm ~hamish/WWW/test/
	install -m a+rx proxy.pm ~hamish/WWW/test/
	install -m a+rx showmap.cgi ~hamish/WWW/test/
	touch ~hamish/WWW/test/gamelog.txt
	chmod a+rw ~hamish/WWW/test/gamelog.txt

prof1:
	perl -d:DProf ./showmap.cgi >/dev/null
	dprofpp

