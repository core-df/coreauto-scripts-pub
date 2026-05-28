CC ?= gcc
CFLAGS ?= -Wall -I../../cawbs/C/include -I../../files/C/include
LDFLAGS ?= -L../../cawbs/C -L../../files/C -lcawbs -lcoreauto_files

all:
	$(MAKE) -C ../../cawbs/C
	$(MAKE) -C ../../files/C
	$(CC) $(CFLAGS) -o full_integration_step full_integration_step.c $(LDFLAGS)
