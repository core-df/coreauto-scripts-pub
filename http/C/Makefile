# Copyright Core DF — Apache License 2.0
CC ?= gcc
CFLAGS ?= -Wall -Wextra -Iinclude
LDFLAGS ?= -lcurl -lcjson
SRC = src/coreauto_result.c src/httpclient.c
OBJS = obj/coreauto_result.o obj/httpclient.o

.PHONY: all clean
all: libcoreauto_http.a

obj/%.o: src/%.c | obj
	$(CC) $(CFLAGS) -c $< -o $@

libcoreauto_http.a: $(OBJS)
	ar rcs $@ $(OBJS)

obj:
	mkdir -p obj

clean:
	rm -rf obj libcoreauto_http.a
