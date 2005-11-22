
all:

test:
	install -m a+rx cities.cgi ~hamish/WWW/test/
	install -m a+rx other.cgi ~hamish/WWW/test/
	install -m a+rx cities.pm ~hamish/WWW/test/
	install -m a+rx proxy.pm ~hamish/WWW/test/

