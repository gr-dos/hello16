# Build hello.exe for 16-bit MS-DOS with Open Watcom.
#   make WATCOM=~/opt/watcom

WATCOM ?= $(HOME)/opt/watcom
export WATCOM
export INCLUDE := $(WATCOM)/h
export PATH := $(WATCOM)/binl64:$(WATCOM)/binl:$(PATH)

VERSION := $(shell cat VERSION)

CC     = wcl
CFLAGS = -q -bt=dos -ms -0 -os -s -wx -we -zq '-DVERSION="$(VERSION)"'

SRCS = hello.c

hello.exe: $(SRCS) VERSION
	$(CC) $(CFLAGS) -fe=$@ $(SRCS)

test: hello.exe
	sh tests/run.sh $(CURDIR)/hello.exe

clean:
	rm -f *.o *.obj *.err hello.exe

.PHONY: test clean
