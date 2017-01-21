PREFIX = /usr/local

.PHONY: all install uninstall clean test

all: fssync.1

fssync.1: README.rst
	rst2man $< $@

install: all
	install -Dp fssync $(DESTDIR)$(PREFIX)/bin/fssync
	install -Dpm 0644 fssync.1 $(DESTDIR)$(PREFIX)/share/man/man1/fssync.1

uninstall:
	-cd $(DESTDIR)$(PREFIX) && rm -f bin/fssync share/man/man1/fssync.1

clean:
	-rm -f fssync.1

test:
	./test
