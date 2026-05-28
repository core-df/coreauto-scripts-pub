COBC ?= cobc
CC ?= gcc
CFLAGS ?= -Wall -Wextra -I../C/include
LDFLAGS ?= -L../C -lcoreauto_http -lcurl -lcjson
.PHONY: all clean
all: libhttp_cobol.so
libhttp_cobol.so: src/http_cobol.c
	cd ../C && $(MAKE)
	$(CC) $(CFLAGS) -fPIC -shared -o $@ src/http_cobol.c -L../C -lcoreauto_http $(LDFLAGS)
clean: rm -f libhttp_cobol.so
