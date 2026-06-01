# Copyright Core DF — Apache License 2.0
CC ?= gcc
CFLAGS ?= -Wall -Wextra -Iinclude -I../../../http/C/include -I../../_shared/C/common
CFLAGS += $(EXTRA_CFLAGS)
LDFLAGS ?= -lcjson
LDFLAGS += $(EXTRA_LDFLAGS)

# librdkafka (Homebrew: brew install librdkafka)
RDKAFKA_PREFIX ?= /opt/homebrew
RDKAFKA_CFLAGS ?= $(shell pkg-config --cflags rdkafka 2>/dev/null)
RDKAFKA_LIBS ?= $(shell pkg-config --libs rdkafka 2>/dev/null)
ifeq ($(RDKAFKA_LIBS),)
  RDKAFKA_CFLAGS = -I$(RDKAFKA_PREFIX)/include
  RDKAFKA_LIBS = -L$(RDKAFKA_PREFIX)/lib -lrdkafka -lz -lpthread
endif
CFLAGS += $(RDKAFKA_CFLAGS)
LDFLAGS += $(RDKAFKA_LIBS)

.PHONY: all clean test
all: libcoreauto_kafka.a

obj/kafkaclient.o: src/kafkaclient.c | obj
	$(CC) $(CFLAGS) -c $< -o $@

libcoreauto_kafka.a: obj/kafkaclient.o
	ar rcs $@ $^

obj:
	mkdir -p obj

HTTP_LIB = ../../../http/C/libcoreauto_http.a

test: all tests/test_kafkaclient
	./tests/test_kafkaclient

tests/test_kafkaclient: tests/test_kafkaclient.c | libcoreauto_kafka.a $(HTTP_LIB)
	$(CC) $(CFLAGS) -I../../../tests/c -o $@ tests/test_kafkaclient.c \
		../../../tests/c/testutil.c -L. -L../../../http/C -lcoreauto_kafka -lcoreauto_http $(LDFLAGS)

$(HTTP_LIB):
	$(MAKE) -C ../../../http/C

clean:
	rm -rf obj libcoreauto_kafka.a tests/test_kafkaclient
