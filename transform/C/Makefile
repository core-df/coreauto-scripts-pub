# Copyright Core DF — Apache License 2.0
CC ?= gcc
CFLAGS ?= -Wall -Wextra -Iinclude -I../http/C/include
LDFLAGS ?= -lcjson
SRC = src/transformclient.c
OBJS = obj/transformclient.o

.PHONY: all clean
all: libcoreauto_transform.a

obj/%.o: src/%.c | obj
	$(CC) $(CFLAGS) -c $< -o $@

libcoreauto_transform.a: $(OBJS)
	ar rcs $@ $(OBJS)

obj:
	mkdir -p obj

clean:
	rm -rf obj libcoreauto_transform.a
