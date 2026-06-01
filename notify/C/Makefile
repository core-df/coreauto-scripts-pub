# Copyright Core DF — Apache License 2.0
CC ?= gcc
CFLAGS ?= -Wall -Wextra -Iinclude -I../../http/C/include
CFLAGS += $(EXTRA_CFLAGS)
LDFLAGS ?= -L../../http/C -lcoreauto_http -lcurl -lcjson
LDFLAGS += $(EXTRA_LDFLAGS)
TEST_COMMON = ../../tests/c/mock_http.c ../../tests/c/testutil.c
TEST_CFLAGS = -Wall -Wextra -Iinclude -I../../http/C/include -I../../tests/c $(EXTRA_CFLAGS)
HTTP_LIB = ../../http/C/libcoreauto_http.a

.PHONY: all clean test
all: libcoreauto_notify.a
obj/notifyclient.o: src/notifyclient.c | obj
	$(CC) $(CFLAGS) -c $< -o $@
libcoreauto_notify.a: obj/notifyclient.o
	ar rcs $@ $^
obj:
	mkdir -p obj
test: $(HTTP_LIB) all tests/test_notifyclient
	./tests/test_notifyclient

$(HTTP_LIB):
	$(MAKE) -C ../../http/C

tests/test_notifyclient: tests/test_notifyclient.c $(TEST_COMMON) | libcoreauto_notify.a $(HTTP_LIB)
	$(CC) $(TEST_CFLAGS) -o $@ tests/test_notifyclient.c $(TEST_COMMON) -L. -L../../http/C -lcoreauto_notify -lcoreauto_http $(LDFLAGS)

clean:
	rm -rf obj libcoreauto_notify.a tests/test_notifyclient
