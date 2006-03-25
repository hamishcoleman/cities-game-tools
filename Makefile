
localdir := ~hamish/WWW/cities
testdir  := $(localdir)/test

files    := game.cgi other.cgi \
	    showmap.cgi map.cgi \
	    showlog.cgi \
	    cities.pm proxy.pm \
	    game.css black.jpg

all:
	@echo I think you want make test or make local

#
# Generic rules
#
# TODO - see if I cannot consolodate the extra words for test vs local

$(localdir)/%.cgi $(testdir)/%.cgi: %.cgi
	install -m a+rx $^ $@

$(localdir)/% $(testdir)/%: %
	install -m a+r $^ $@

# the two install targets
test:	$(testdir) \
	$(addprefix $(testdir)/,$(files)) \
	$(localdir)/gamelog.txt \
	$(localdir)/db/gamelog.sqlite

local:	$(localdir) \
	$(addprefix $(localdir)/,$(files)) \
	$(localdir)/gamelog.txt \
	$(localdir)/db/gamelog.sqlite

$(localdir) $(testdir):
	install -d -m a+rx,u+rwx $@

$(testdir): $(localdir)

# Argh, I always have issues with makeing directories.  This one always thinks
# it needs updating ...  oh well..
#
#$(localdir)/db: $(localdir)
#	install -d -m a+rwx $@

$(localdir)/gamelog.txt:
	touch ~hamish/WWW/cities/gamelog.txt
	chmod a+rw ~hamish/WWW/cities/gamelog.txt

$(localdir)/db/gamelog.sqlite: gamelog.sqlite
	@echo WARNING: database schema has changed
	@echo          manual intervention required

# FIXME - install a database if this is not already one there

gamelog.sqlite: schema.sql
	rm -f $@
	sqlite3 $@ <$^

prof1:
	perl -d:DProf ./showmap.cgi >/dev/null
	dprofpp

prof2:
	perl -d:DProf ./showmap.cgi 1 10 1 10 >/dev/null
	dprofpp

profmap:
	perl -d:DProf ./map.cgi x=4 y=4 >/dev/null
	dprofpp

