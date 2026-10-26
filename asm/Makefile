# Optional 8086 assembly build of hello (hello.com) with NASM.
# Not part of the default build: run from the top with "make -C asm".
#   make -C asm            builds hello.com
#   make -C asm test       runs ../tests/run.sh and the differential
#                          tests against the Watcom hello.exe
#   make -C asm measure    prints the size / FAT / memory comparison

NASM   ?= nasm
NFLAGS  = -f bin -Werror

VERSION := $(shell cat ../VERSION)

all: hello.com

hello.com: hello.asm ../VERSION
	$(NASM) $(NFLAGS) '-DVERSION="$(VERSION)"' -o $@ hello.asm

tests/err2out.com: tests/err2out.asm
	$(NASM) $(NFLAGS) -o $@ tests/err2out.asm

# The Watcom reference, built by the unchanged top-level Makefile
# (WATCOM= on this command line is passed down).
../hello.exe: FORCE
	$(MAKE) -C .. hello.exe

test: hello.com tests/err2out.com ../hello.exe
	sh ../tests/run.sh $(CURDIR)/hello.com
	sh tests/diff.sh $(CURDIR)/../hello.exe $(CURDIR)/hello.com

measure: hello.com ../hello.exe
	sh measure.sh $(CURDIR)/../hello.exe $(CURDIR)/hello.com

clean:
	rm -f hello.com tests/err2out.com

.PHONY: all test measure clean FORCE
