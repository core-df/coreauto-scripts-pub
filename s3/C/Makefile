# Copyright Core DF — Apache License 2.0
CC ?= gcc
CFLAGS ?= -Wall -Wextra -Iinclude -I../../http/C/include
CFLAGS += $(EXTRA_CFLAGS)
LDFLAGS ?= -lcjson
LDFLAGS += $(EXTRA_LDFLAGS)
TEST_COMMON = ../../tests/c/testutil.c
TEST_CFLAGS = -Wall -Wextra -Iinclude -I../../http/C/include -I../../tests/c $(EXTRA_CFLAGS)
HTTP_LIB = ../../http/C/libcoreauto_http.a

.PHONY: all clean test
all: libcoreauto_s3.a
obj/s3client.o: src/s3client.c | obj
	$(CC) $(CFLAGS) -c $< -o $@
libcoreauto_s3.a: obj/s3client.o
	ar rcs $@ $^
obj:
	mkdir -p obj
test: $(HTTP_LIB) all tests/test_s3client
	./tests/test_s3client

$(HTTP_LIB):
	$(MAKE) -C ../../http/C

tests/test_s3client: tests/test_s3client.c $(TEST_COMMON) | libcoreauto_s3.a $(HTTP_LIB)
	$(CC) $(TEST_CFLAGS) -o $@ tests/test_s3client.c $(TEST_COMMON) -L. -L../../http/C -lcoreauto_s3 -lcoreauto_http $(LDFLAGS)

clean:
	rm -rf obj libcoreauto_s3.a tests/test_s3client
