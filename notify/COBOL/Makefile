CC ?= gcc
CFLAGS ?= -Wall -Wextra -I../C/include -I../../http/C/include
LDFLAGS ?= -L../C -lcoreauto_notify -L../../http/C -lcoreauto_http -lcurl -lcjson
.PHONY: all clean
all: libnotify_cobol.so
libnotify_cobol.so: src/notify_cobol.c
	cd ../C && $(MAKE)
	cd ../../http/C && $(MAKE)
	$(CC) $(CFLAGS) -fPIC -shared -o $@ src/notify_cobol.c $(LDFLAGS)
clean:
	rm -f libnotify_cobol.so
