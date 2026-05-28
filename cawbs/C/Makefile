# Copyright (c) Core DF. All rights reserved.

CC ?= gcc
CFLAGS ?= -Wall -Wextra -Iinclude
LDFLAGS ?= -lcurl -lcjson

LIB_SRC = src/wbs.c
CAWBS_SRC = src/cawbs.c src/cawbsbatch.c
OBJS = obj/wbs.o obj/cawbs.o obj/cawbsbatch.o

.PHONY: all clean

all: libcawbs.a

obj/wbs.o: obj $(LIB_SRC)
	$(CC) $(CFLAGS) -c $(LIB_SRC) -o $@

obj/cawbs.o: obj src/cawbs.c
	$(CC) $(CFLAGS) -c src/cawbs.c -o $@

obj/cawbsbatch.o: obj src/cawbsbatch.c
	$(CC) $(CFLAGS) -c src/cawbsbatch.c -o $@

libcawbs.a: $(OBJS)
	ar rcs $@ $(OBJS)

obj:
	mkdir -p obj

clean:
	rm -rf obj libcawbs.a
