# Copyright Core DF — Apache License 2.0
CC ?= gcc
CFLAGS ?= -Wall -Wextra -Iinclude
CFLAGS += $(EXTRA_CFLAGS)
LDFLAGS ?= -lcurl -lcjson
LDFLAGS += $(EXTRA_LDFLAGS)
SRC = src/coreauto_result.c src/httpclient.c
OBJS = obj/coreauto_result.o obj/httpclient.o

TEST_COMMON = ../../tests/c/mock_http.c ../../tests/c/testutil.c
TEST_CFLAGS = -Wall -Wextra -Iinclude -I../../tests/c $(EXTRA_CFLAGS)

.PHONY: all clean test
all: libcoreauto_http.a

obj/%.o: src/%.c | obj
	$(CC) $(CFLAGS) -c $< -o $@

libcoreauto_http.a: $(OBJS)
	ar rcs $@ $(OBJS)

obj:
	mkdir -p obj

test: all tests/test_httpclient
	./tests/test_httpclient

tests/test_httpclient: tests/test_httpclient.c $(TEST_COMMON) | libcoreauto_http.a
	$(CC) $(TEST_CFLAGS) -o $@ tests/test_httpclient.c $(TEST_COMMON) -L. -lcoreauto_http $(LDFLAGS) $(EXTRA_LDFLAGS)

clean:
	rm -rf obj libcoreauto_http.a tests/test_httpclient
