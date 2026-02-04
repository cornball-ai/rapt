CC ?= gcc
CFLAGS = -Wall -Wextra -Werror -O2 -g -D_FORTIFY_SOURCE=2
LDFLAGS = -Wl,-z,relro,-z,now

PREFIX ?= /usr
BINDIR = $(PREFIX)/bin

.PHONY: all clean install

all: raptd

raptd: raptd.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $<

clean:
	rm -f raptd

install: raptd
	install -d $(DESTDIR)$(BINDIR)
	install -m 755 raptd $(DESTDIR)$(BINDIR)/raptd
