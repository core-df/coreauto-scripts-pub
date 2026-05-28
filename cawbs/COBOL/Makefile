# Copyright (c) Core DF. All rights reserved.
#
# Build GnuCOBOL step programs with the cawbs C bridge.

COBC ?= cobc
CC ?= gcc
CINC = -I../C/include
CFLAGS ?= -Wall -Wextra $(CINC)
LDFLAGS ?= -lcurl -lcjson

CAWBS_C = ../C/src/wbs.c ../C/src/cawbs.c ../C/src/cawbsbatch.c
BRIDGE = src/cawbs_cobol.c
LIB = libcawbs_cobol.so

.PHONY: all clean

all: $(LIB) bin/cawbs_rt bin/cawbs_batch

$(LIB): $(CAWBS_C) $(BRIDGE)
	$(CC) $(CFLAGS) -fPIC -shared -o $@ $(CAWBS_C) $(BRIDGE) $(LDFLAGS)

bin:
	mkdir -p bin

bin/cawbs_rt: src/cawbs_rt.cbl $(LIB) | bin
	COB_LIBRARY_PATH=. $(COBC) -x -Icopy -L. -lcawbs_cobol -o $@ $<

bin/cawbs_batch: src/cawbs_batch.cbl $(LIB) | bin
	COB_LIBRARY_PATH=. $(COBC) -x -Icopy -L. -lcawbs_cobol -o $@ $<

clean:
	rm -rf bin $(LIB)
