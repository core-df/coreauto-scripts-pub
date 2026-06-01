# Copyright Core DF — Apache License 2.0
CC ?= gcc
CFLAGS ?= -Wall -Wextra -Iinclude -I../../http/C/include
CFLAGS += $(EXTRA_CFLAGS)
LDFLAGS ?= -lcjson
LDFLAGS += $(EXTRA_LDFLAGS)
SRC = src/transformclient.c
OBJS = obj/transformclient.o

TEST_COMMON = ../../tests/c/testutil.c
TEST_CFLAGS = -Wall -Wextra -Iinclude -I../../http/C/include -I../../tests/c $(EXTRA_CFLAGS)

.PHONY: all clean test
all: libcoreauto_transform.a

obj/%.o: src/%.c | obj
	$(CC) $(CFLAGS) -c $< -o $@

libcoreauto_transform.a: $(OBJS)
	ar rcs $@ $(OBJS)

obj:
	mkdir -p obj

test: all tests/test_transformclient
	./tests/test_transformclient

tests/test_transformclient: tests/test_transformclient.c $(TEST_COMMON) | libcoreauto_transform.a
	$(CC) $(TEST_CFLAGS) -o $@ tests/test_transformclient.c $(TEST_COMMON) -L. -lcoreauto_transform $(LDFLAGS)

clean:
	rm -rf obj libcoreauto_transform.a tests/test_transformclient
