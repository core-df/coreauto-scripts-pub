# Copyright Core DF — Apache License 2.0
CC ?= gcc
CFLAGS ?= -Wall -Wextra -Iinclude -I../../http/C/include
LDFLAGS ?= -lcjson
.PHONY: all clean
all: libcoreauto_files.a
obj/fileclient.o: src/fileclient.c | obj
	$(CC) $(CFLAGS) -c $< -o $@
libcoreauto_files.a: obj/fileclient.o
	ar rcs $@ $^
obj:
	mkdir -p obj
clean:
	rm -rf obj libcoreauto_files.a
