# hello.com: 8086 assembly version

A hand-written 8086 assembly version of `hello`, built as a
`.COM` with NASM. It is the minimal-size baseline for the
[gr-dos](https://github.com/gr-dos) `*16` suite: the smallest program that behaves exactly like the C
`hello.exe`, used to measure how much of `hello.exe` is C runtime.

The top-level `make` and `make test` build and test only the C
`hello.exe`. CI and the release workflow also run `make -C asm test`,
and each release ships `hello.com` alongside `hello.exe`.

## Build and test

Needs NASM (any 2.x or 3.x; checked with 3.01), and for the tests
DOSBox-X plus what the top-level build needs for the reference
`hello.exe` (libc16 and its Open Watcom).

    make -C asm                  # hello.com
    make -C asm test             # existing suite + differential tests
    make -C asm measure          # size / FAT12 / memory comparison
    make -C asm clean

    make -C asm test DOSBOX=$PWD/asm/tests/dosbox-8086   # on an 8086

`LIBC16_ROOT=` works as at the top level and is passed down when the
reference `hello.exe` needs building. The build is a single command,

    nasm -f bin -Werror '-DVERSION="0.01"' -o hello.com hello.asm

and NASM's flat binary output is deterministic. `cpu 8086` in the
source makes NASM reject any instruction newer than the original 8086.

`make -C asm test` runs:

- `tests/run.sh` (the existing suite, unchanged) on `hello.com`. The
  suite copies the program to `hello.exe`; DOS decides between EXE and
  COM by the `MZ` signature, not the name, so the image runs as a COM.
- `tests/diff.sh`, which runs `hello.exe` and `hello.com` on the same
  95 argument lists in one DOSBox-X session and requires identical
  bytes on standard output, identical bytes on standard output plus
  standard error, and identical exit status. 41 lists are written out;
  the other 54 are runs of 0 to 8 backslashes before a quote in six
  positions (mid-word before a quoted blank, inside quotes before a
  blank, trailing, leading, closing a quoted argument, and in an
  option). A few cases are also checked against exact expected bytes,
  CR LF endings included. Standard error is captured with
  `tests/err2out.asm`, a small helper that runs a program with handle 2
  duplicated from handle 1, because DOS shells cannot redirect it.
  Every list is also passed to `tests/tail.asm`, which writes back the
  command tail it received, to check that the shell hands the argument
  text to the programs unchanged.

`tests/dosbox-8086` runs DOSBox-X with `cputype=8086`, where an 80186
instruction does not execute. Both suites pass there for both
programs. DOSBox-X calls this CPU mode experimental.

## Behavior

Same as `hello.c`: the greeting, `--help` / `-h` / `-?`, `--version`
(from `../VERSION`), and the two diagnostics on standard error with exit
status 1. Only the first argument is looked at, as in `hello.c`.

The subtle part is matching how `hello.exe` splits the command tail
into `argv`, because a diagnostic echoes the argument. `hello.exe` is
linked with libc16, which splits it as Microsoft C does (libc16's
`docs/spec/startup.md`), and `tests/diff.sh` pins the rules:

- spaces and tabs separate arguments; leading ones are skipped;
- `"` toggles quoting and is removed, so `a"b c"d` is `ab cd`, `""` is
  an empty argument (an "extra operand"), and `-"h"` is `-h`;
- a run of 2n backslashes before `"` gives n backslashes and a toggle,
  and 2n + 1 give n backslashes and a literal `"`, so `a\\\"b c"` is
  `a\"b` followed by `c`;
- any other `\` is literal.

The backslash cases in `tests/diff.sh` cover runs of 0 to 8. Before
libc16, `hello.exe` used Open Watcom's runtime, whose startup turns a
run of n ≥ 2 backslashes before `"` into n − 1 backslashes and a toggle;
the two rules agree only for runs of 0 to 2, and `hello.asm` followed
Watcom's until it moved with `hello.exe`.

## Results

From `make -C asm measure` (Open Watcom `2026-10-01-Build` with libc16,
NASM 3.01, `VERSION` 0.01), with the Open Watcom runtime build it
replaces for comparison:

| | `hello.exe` (libc16) | `hello.com` (asm) | `hello.exe` (Watcom runtime) |
|---|---:|---:|---:|
| File size | 1,384 bytes | 547 bytes | 9,532 bytes |
| 360K / 720K floppy (1 KB clusters) | 2 clusters, 2,048 bytes | 1 cluster, 1,024 bytes | 10 clusters, 10,240 bytes |
| 1.2M / 1.44M floppy (512 B clusters) | 3 clusters, 1,536 bytes | 2 clusters, 1,024 bytes | 19 clusters, 9,728 bytes |
| Conventional memory to load | 3,968 bytes | about 1,072 bytes | 12,096 bytes |
| DOS version | 2.0 or later | 2.0 or later | 2.0 or later |
| CPU | 8086 | 8086 | 8086 |

FAT figures are measured: each file is copied onto a freshly formatted
image with mtools, and the drop in free space is recorded.

Memory: for `hello.exe` the figure is from the MZ header (PSP 256 +
load image 1,336 rounded to a paragraph + minimum allocation 148
paragraphs, which holds BSS and the 2 KB stack). A `.COM` has no header,
so for `hello.com` it is PSP + image + 256 bytes of stack. hello uses
only a few words of stack itself, but DOS and interrupt handlers also
push onto it. Either way DOS gives a program the largest free block when
it loads it. The libc16 startup then shrinks its block. `hello.com`
does not, which costs nothing because it exits at once and starts no
child process.

DOS versions: both use handle I/O (function 40h) and exit with a status
(function 4Ch), which arrived in DOS 2.0. On DOS 1.x, `hello.com` would
print nothing and then end through `int 20h`, placed after the 4Ch
call. This is untested; there is no DOS 1.x in the test setup. Tests
run on DOSBox-X's built-in DOS.

## What the baseline says about runtime overhead

`hello.exe`'s link map (`hello.map`, written by the `Makefile`) shows
989 bytes of code, of which `hello.c` is about 260 (`main`, `usage` and
`bad_arg`) and libc16 the rest: the startup, `argv` splitting (245
bytes), `write` with text-mode `\n` to CR LF translation, `fputs`,
`strlen`, `strcmp`, and the `stdout` and `stderr` streams. DGROUP holds
about 330 bytes of messages and data, 310 bytes of BSS (mostly the
`argv` buffers) and the 2 KB stack.

With Open Watcom's runtime the same program was 9,532 bytes: 8,554 bytes
of code from 65 object modules, for code page set-up, buffered streams
flushed at exit, a heap for the stream buffers, and `printf`
formatting down to 64-bit integers, none of which `hello` needs.
libc16 links only what a program calls, writes straight to DOS handles,
and has no `printf`, which takes `hello` in C from 18 times the size of
`hello.com` to about 2.5 times, or one more floppy cluster.

## Provenance and license

`hello.asm`, `tests/err2out.asm` and the scripts here were written from
scratch for this repository. They contain no Open Watcom runtime code;
the argument-splitting rules were first found by black-box testing of
the Watcom build, and now follow libc16's specification. They are MIT
licensed like the rest of the repository
(see `../LICENSE`).

## Recommendation

Whether a utility is written in C, assembly, or both is up to its
implementor (see "Implementation: C, assembly, or both" in
`../README.md`). Things to weigh:

- The size win is real but fixed, and with libc16 it is small: under
  1 KB on disk and about 3 KB of memory per program. It matters most on
  a 360K boot floppy full of tools, and size is still a reason to
  choose assembly.
- The cost grows with every feature. Matching even `hello`'s argument
  splitting took differential tests. Real utilities (md5sum, tar) need
  file I/O, error handling and number formatting written and checked by
  hand.
- Most of the saving now comes from C through libc16's per-function
  linking, which keeps the C sources and the template.

For `hello` itself, `hello.com` is also the size baseline and the
yardstick for `libc16`: build `hello.c` against it and compare with
`make -C asm measure`. This directory is also the example for the
"C reference and assembly" layout: how to build the `.COM` and test it
against the C version, run it in CI, and release it.
