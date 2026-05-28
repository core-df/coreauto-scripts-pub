CC ?= gcc
CFLAGS ?= -Wall -Wextra -I../C/include -I../../http/C/include
LDFLAGS ?= -L../C -lcoreauto_transform -lcjson
all: libtransform_cobol.so
libtransform_cobol.so: src/transform_cobol.c
	cd ../C && $(MAKE)
	$(CC) $(CFLAGS) -fPIC -shared -o $@ $^ $(LDFLAGS)
clean: rm -f libtransform_cobol.so
