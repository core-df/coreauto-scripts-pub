CC ?= gcc
CFLAGS ?= -Wall -Wextra -Iinclude -I../../../http/C/include -I../../_shared/C/common \
	-I../../../cawbs/C/include
CFLAGS += $(EXTRA_CFLAGS)
LDFLAGS ?= -lcurl -lcjson
LDFLAGS += $(EXTRA_LDFLAGS)
HTTP_LIB = ../../../http/C/libcoreauto_http.a
CAWBS_LIB = ../../../cawbs/C/libcawbs.a
LIB = libcoreauto_ingress.a

.PHONY: all clean test
all: $(LIB)

obj/ingressclient.o: src/ingressclient.c | obj
	$(CC) $(CFLAGS) -c $< -o $@

$(LIB): obj/ingressclient.o
	ar rcs $@ $^

obj:
	mkdir -p obj

test: all tests/test_ingressclient
	./tests/test_ingressclient

tests/test_ingressclient: tests/test_ingressclient.c | $(LIB) $(HTTP_LIB) $(CAWBS_LIB)
	$(CC) $(CFLAGS) -I../../../tests/c -o $@ tests/test_ingressclient.c \
		../../../tests/c/testutil.c -L. -L../../../http/C -L../../../cawbs/C \
		-lcoreauto_ingress -lcawbs -lcoreauto_http $(LDFLAGS)

$(HTTP_LIB):
	$(MAKE) -C ../../../http/C

$(CAWBS_LIB):
	$(MAKE) -C ../../../cawbs/C EXTRA_CFLAGS="$(EXTRA_CFLAGS)" EXTRA_LDFLAGS="$(EXTRA_LDFLAGS)"

clean:
	rm -rf obj $(LIB) tests/test_ingressclient
