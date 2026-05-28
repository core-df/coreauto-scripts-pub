COBC ?= cobc
CC ?= gcc
CFLAGS ?= -Wall -Wextra -I../C/include -I../../http/C/include
LDFLAGS ?= -L../C -lcoreauto_files -lcjson
.PHONY: all clean
all: libfile_cobol.so
libfile_cobol.so: src/file_cobol.c
	cd ../C && $(MAKE)
	$(CC) $(CFLAGS) -fPIC -shared -o $@ src/file_cobol.c -L../C -lcoreauto_files $(LDFLAGS)
clean:
	rm -f libfile_cobol.so
