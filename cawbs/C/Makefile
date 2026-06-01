# Copyright Core DF

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

CC ?= gcc
CFLAGS ?= -Wall -Wextra -Iinclude
CFLAGS += $(EXTRA_CFLAGS)
LDFLAGS ?= -lcurl -lcjson
LDFLAGS += $(EXTRA_LDFLAGS)

LIB_SRC = src/wbs.c
CAWBS_SRC = src/cawbs.c src/cawbsbatch.c src/cawbsingress.c
OBJS = obj/wbs.o obj/cawbs.o obj/cawbsbatch.o obj/cawbsingress.o

TEST_COMMON = ../../tests/c/mock_http.c ../../tests/c/testutil.c
TEST_CFLAGS = -Wall -Wextra -Iinclude -I../../tests/c $(EXTRA_CFLAGS)
TEST_LIBS = -L. -lcawbs -lcurl -lcjson $(EXTRA_LDFLAGS)

.PHONY: all clean test

all: libcawbs.a

obj/wbs.o: obj $(LIB_SRC)
	$(CC) $(CFLAGS) -c $(LIB_SRC) -o $@

obj/cawbs.o: obj src/cawbs.c
	$(CC) $(CFLAGS) -c src/cawbs.c -o $@

obj/cawbsbatch.o: obj src/cawbsbatch.c
	$(CC) $(CFLAGS) -c src/cawbsbatch.c -o $@

obj/cawbsingress.o: obj src/cawbsingress.c
	$(CC) $(CFLAGS) -c src/cawbsingress.c -o $@

libcawbs.a: $(OBJS)
	ar rcs $@ $(OBJS)

obj:
	mkdir -p obj

test: all tests/test_wbs tests/test_cawbs
	./tests/test_wbs
	./tests/test_cawbs

tests/test_wbs: tests/test_wbs.c $(TEST_COMMON) | libcawbs.a
	$(CC) $(TEST_CFLAGS) -o $@ tests/test_wbs.c $(TEST_COMMON) $(TEST_LIBS)

tests/test_cawbs: tests/test_cawbs.c $(TEST_COMMON) | libcawbs.a
	$(CC) $(TEST_CFLAGS) -o $@ tests/test_cawbs.c $(TEST_COMMON) $(TEST_LIBS)

clean:
	rm -rf obj libcawbs.a tests/test_wbs tests/test_cawbs
