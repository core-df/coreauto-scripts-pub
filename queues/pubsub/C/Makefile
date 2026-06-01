CC ?= gcc
CFLAGS ?= -Wall -Wextra -Iinclude -I../../../http/C/include -I../../_shared/C/common
CFLAGS += $(EXTRA_CFLAGS)
LDFLAGS ?= -lcjson
LDFLAGS += $(EXTRA_LDFLAGS)
HTTP_LIB = ../../../http/C/libcoreauto_http.a
LIB = libcoreauto_pubsub.a
CLIENT = pubsubclient
.PHONY: all clean test
all: $(LIB)
obj/$(CLIENT).o: src/$(CLIENT).c | obj
	$(CC) $(CFLAGS) -c $< -o $@
$(LIB): obj/$(CLIENT).o
	ar rcs $@ $^
obj:
	mkdir -p obj
test: all tests/test_$(CLIENT)
	./tests/test_$(CLIENT)
tests/test_$(CLIENT): tests/test_$(CLIENT).c | $(LIB) $(HTTP_LIB)
	$(CC) $(CFLAGS) -I../../../tests/c -o $@ tests/test_$(CLIENT).c ../../../tests/c/testutil.c -L. -L../../../http/C -lcoreauto_pubsub -lcoreauto_http $(LDFLAGS)
$(HTTP_LIB):
	$(MAKE) -C ../../../http/C
clean:
	rm -rf obj $(LIB) tests/test_$(CLIENT)
