# hello.com: 8086 assembly baseline (experiment)

An optional, hand-written 8086 assembly version of `hello`, built as a
`.COM` with NASM. It is the minimal-size baseline for the `dos-*16`
suite: the smallest program that behaves exactly like the Watcom C
`hello.exe`, used to measure how much of `hello.exe` is C runtime.

It is **not** part of the default build, tests, CI or release. The
top-level `Makefile`, `hello.c`, `tests/run.sh` and the workflows are
unchanged, and releases still ship only the Watcom `hello.exe`.

## Build and test

Needs NASM (any 2.x or 3.x; checked with 3.01), and for the tests
DOSBox-X plus the Watcom toolchain for the reference `hello.exe`.

    make -C asm                  # hello.com
    make -C asm test             # existing suite + differential tests
    make -C asm measure          # size / FAT12 / memory comparison
    make -C asm clean

    make -C asm test DOSBOX=$PWD/asm/tests/dosbox-8086   # on an 8086

`WATCOM=` works as at the top level and is passed down when the
reference `hello.exe` needs building. The build is a single command,

    nasm -f bin -Werror '-DVERSION="0.01"' -o hello.com hello.asm

and NASM's flat binary output is deterministic. `cpu 8086` in the
source makes NASM reject any instruction newer than the original 8086.

`make -C asm test` runs:

- `tests/run.sh` (the existing suite, unchanged) on `hello.com`. The
  suite copies the program to `hello.exe`; DOS decides between EXE and
  COM by the `MZ` signature, not the name, so the image runs as a COM.
- `tests/diff.sh`, which runs `hello.exe` and `hello.com` on the same
  41 argument lists in one DOSBox-X session and requires identical
  bytes on standard output, identical bytes on standard output plus
  standard error, and identical exit status. A few cases are also
  checked against exact expected bytes, CR LF endings included.
  Standard error is captured with `tests/err2out.asm`, a small helper
  that runs a program with handle 2 duplicated from handle 1, because
  DOS shells cannot redirect it.

`tests/dosbox-8086` runs DOSBox-X with `cputype=8086`, where an 80186
instruction does not execute. Both suites pass there for both
programs. DOSBox-X calls this CPU mode experimental.

## Behavior

Same as `hello.c`: the greeting, `--help` / `-h` / `-?`, `--version`
(from `../VERSION`), and the two diagnostics on standard error with exit
status 1. Only the first argument is looked at, as in `hello.c`.

The subtle part is matching how the Watcom C startup splits the command
tail into `argv`, because a diagnostic echoes the argument. The rules
below were found by testing the Watcom build without reading its
source, and are now pinned by `tests/diff.sh`:

- spaces and tabs separate arguments; leading ones are skipped;
- `"` toggles quoting and is removed, so `a"b c"d` is `ab cd`, `""` is
  an empty argument (an "extra operand"), and `-"h"` is `-h`;
- `\"` is a literal `"`, but `\\"` is `\` followed by a toggle;
- any other `\` is literal.

## Results

From `make -C asm measure` (Open Watcom 2.0, NASM 3.01, `VERSION`
0.01):

| | `hello.exe` (Watcom C) | `hello.com` (asm) |
|---|---:|---:|
| File size | 9,532 bytes | 511 bytes (205 code, 306 text) |
| 360K / 720K floppy (1 KB clusters) | 10 clusters, 10,240 bytes | 1 cluster, 1,024 bytes |
| 1.2M / 1.44M floppy (512 B clusters) | 19 clusters, 9,728 bytes | 1 cluster, 512 bytes |
| Conventional memory to load | 12,096 bytes | about 1,024 bytes |
| DOS version | 2.0 or later | 2.0 or later |
| CPU | 8086 | 8086 |

FAT figures are measured: each file is copied onto a freshly formatted
image with mtools, and the drop in free space is recorded.

Memory: for `hello.exe` the figure is from the MZ header (PSP 256 +
load image 9,484 rounded to a paragraph + minimum allocation 147
paragraphs, which holds BSS and the 2 KB stack). A `.COM` has no header,
so for `hello.com` it is PSP + image + 256 bytes of stack. hello uses
only a few words of stack itself, but DOS and interrupt handlers also
push onto it. Either way DOS gives a program the largest free block when
it loads it. The Watcom startup then shrinks its block. `hello.com`
does not, which costs nothing because it exits at once and starts no
child process.

DOS versions: both use handle I/O (function 40h) and exit with a status
(function 4Ch), which arrived in DOS 2.0. On DOS 1.x, `hello.com` would
print nothing and then end through `int 20h`, placed after the 4Ch
call. This is untested; there is no DOS 1.x in the test setup. Tests
run on DOSBox-X's built-in DOS.

## What the baseline says about runtime overhead

Of `hello.exe`'s 9,532 bytes, `main` is 153 bytes of code. The rest is
the general-purpose C runtime. The link map
(`wcl ... -fm=hello.map`, same flags as the `Makefile`) shows 8,554
bytes of code in `_TEXT` from 65 object modules. These cover:

- startup and `argv` splitting (`cstart`, `cmain086`, `initargv`,
  `histsplt`, init/fini tables, multibyte and code-page set-up);
- stdio streams: `FILE` tables, buffer allocation, flushing on exit,
  text-mode `\n` to CR LF translation, tty detection, `fclose`;
- a near heap (`malloc`, `free`, `sbrk`, heap growth) needed for the
  stream buffers;
- `printf` / `fprintf` formatting, with integer conversions down to
  64-bit `lltoa`, none of which `hello` uses.

The data side is similar: about 1.2 KB of DGROUP data and BSS plus a
2 KB stack, against none for the `.COM`. So for a utility this small,
the fixed cost of the Watcom C runtime is about 9 KB on disk (9 or 18
extra floppy clusters) and about 11 KB of conventional memory. The
program's own logic is a few hundred bytes in either language.

That gap is roughly what a future `dos-libc16` can win back. If its
startup splits the tail without a heap, writes go straight to DOS
handles with no `FILE` buffering, and functions link one per object so
`printf` comes in only when used, `hello` in C should land within a few
hundred bytes of this baseline rather than 18 times its size. This
baseline gives that work a concrete target: 511 bytes and one cluster.

## Provenance and license

`hello.asm`, `tests/err2out.asm` and the scripts here were written from
scratch for this repository. They contain no Open Watcom runtime code,
and the argument-splitting rules were found by black-box testing of the
Watcom build. They are MIT licensed like the rest of the repository
(see `../LICENSE`).

## Recommendation

Whether a utility is written in C, assembly, or both is up to its
implementor (see "Implementation: C, assembly, or both" in
`../README.md`). Things to weigh:

- The size win is real but fixed: about 9 KB on disk and 11 KB of
  memory per program. It matters most on a 360K boot floppy full of
  tools, and size is a good reason to choose assembly.
- The cost grows with every feature. Matching even `hello`'s argument
  splitting took differential tests. Real utilities (md5sum, tar) need
  file I/O, error handling and number formatting written and checked by
  hand.
- Much of the saving may also come from C through a slimmer runtime
  (`dos-libc16` with per-function linking), which keeps the C sources
  and the Watcom template.

For `hello` itself, `hello.com` stays an optional baseline and the
yardstick for `dos-libc16`: build `hello.c` against it and compare with
`make -C asm measure`. This directory is also the example for the
"C reference and assembly" layout: how to build the `.COM` and test it
against the C version. Here `make -C asm test` is not run in CI; a
utility that ships its `.COM` adds it to the workflows.
