# Copyright Core DF — Apache License 2.0
CC ?= gcc
CFLAGS ?= -Wall -Wextra -Iinclude -I../../http/C/include
CFLAGS += $(EXTRA_CFLAGS)
LDFLAGS ?= -lcjson
LDFLAGS += $(EXTRA_LDFLAGS)
TEST_COMMON = ../../tests/c/testutil.c
TEST_CFLAGS = -Wall -Wextra -Iinclude -I../../http/C/include -I../../tests/c $(EXTRA_CFLAGS)

.PHONY: all clean test
all: libcoreauto_files.a
obj/fileclient.o: src/fileclient.c | obj
	$(CC) $(CFLAGS) -c $< -o $@
libcoreauto_files.a: obj/fileclient.o
	ar rcs $@ $^
obj:
	mkdir -p obj
test: all tests/test_fileclient
	./tests/test_fileclient

tests/test_fileclient: tests/test_fileclient.c $(TEST_COMMON) | libcoreauto_files.a
	$(CC) $(TEST_CFLAGS) -o $@ tests/test_fileclient.c $(TEST_COMMON) -L. -lcoreauto_files $(LDFLAGS)

clean:
	rm -rf obj libcoreauto_files.a tests/test_fileclient
