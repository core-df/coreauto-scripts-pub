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
#
# Build GnuCOBOL step programs with the cawbs C bridge.

COBC ?= cobc
CC ?= gcc
CINC = -I../C/include
CFLAGS ?= -Wall -Wextra $(CINC)
LDFLAGS ?= -lcurl -lcjson

CAWBS_C = ../C/src/wbs.c ../C/src/cawbs.c ../C/src/cawbsbatch.c ../C/src/cawbsingress.c
BRIDGE = src/cawbs_cobol.c
LIB = libcawbs_cobol.so

.PHONY: all clean

all: $(LIB) bin/cawbs_rt bin/cawbs_batch bin/cawbs_ingress

$(LIB): $(CAWBS_C) $(BRIDGE)
	$(CC) $(CFLAGS) -fPIC -shared -o $@ $(CAWBS_C) $(BRIDGE) $(LDFLAGS)

bin:
	mkdir -p bin

bin/cawbs_rt: src/cawbs_rt.cbl $(LIB) | bin
	COB_LIBRARY_PATH=. $(COBC) -x -Icopy -L. -lcawbs_cobol -o $@ $<

bin/cawbs_batch: src/cawbs_batch.cbl $(LIB) | bin
	COB_LIBRARY_PATH=. $(COBC) -x -Icopy -L. -lcawbs_cobol -o $@ $<

bin/cawbs_ingress: src/cawbs_ingress.cbl $(LIB) | bin
	COB_LIBRARY_PATH=. $(COBC) -x -Icopy -L. -lcawbs_cobol -o $@ $<

clean:
	rm -rf bin $(LIB)
