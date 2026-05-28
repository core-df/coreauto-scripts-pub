CC ?= gcc
CFLAGS ?= -Wall -Wextra -I../C/include -I../../http/C/include
LDFLAGS ?= -L../C -lcoreauto_s3 -lcjson
.PHONY: all clean
all: libs3_cobol.so
libs3_cobol.so: src/s3_cobol.c
	cd ../C && $(MAKE)
	$(CC) $(CFLAGS) -fPIC -shared -o $@ src/s3_cobol.c $(LDFLAGS)
clean:
	rm -f libs3_cobol.so
