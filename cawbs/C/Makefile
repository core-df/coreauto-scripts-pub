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
LDFLAGS ?= -lcurl -lcjson

LIB_SRC = src/wbs.c
CAWBS_SRC = src/cawbs.c src/cawbsbatch.c
OBJS = obj/wbs.o obj/cawbs.o obj/cawbsbatch.o

.PHONY: all clean

all: libcawbs.a

obj/wbs.o: obj $(LIB_SRC)
	$(CC) $(CFLAGS) -c $(LIB_SRC) -o $@

obj/cawbs.o: obj src/cawbs.c
	$(CC) $(CFLAGS) -c src/cawbs.c -o $@

obj/cawbsbatch.o: obj src/cawbsbatch.c
	$(CC) $(CFLAGS) -c src/cawbsbatch.c -o $@

libcawbs.a: $(OBJS)
	ar rcs $@ $(OBJS)

obj:
	mkdir -p obj

clean:
	rm -rf obj libcawbs.a
