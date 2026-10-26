# hello16

Hello world for 16-bit MS-DOS, built with Open Watcom and
[libc16](https://github.com/gr-dos/libc16).

The resulting `hello.exe` is a small-model, real-mode 8086 executable
(about 1.4 KB) that runs on any DOS from an original PC up.

This repository is also the template for other 16-bit DOS utilities
in the [gr-dos](https://github.com/gr-dos) organization, which are
named `gr-dos/NAME16` (see [md5sum16](https://github.com/gr-dos/md5sum16)
and [tar16](https://github.com/gr-dos/tar16)). The conventions
below are what every such utility should follow, whichever language it
is written in (see [Implementation: C, assembly, or
both](#implementation-c-assembly-or-both)).

## Usage

    hello              prints "Hello, world!"
    hello --help       show help (also -h, -?)
    hello --version    show version

The exit code is 0 on success and 1 for a bad option or operand.

## Implementation: C, assembly, or both

A utility built from this template uses one of three layouts:

| Layout | Sources | Toolchain | Program built, tested and released |
|---|---|---|---|
| 1. C only | `NAME.c` | Open Watcom and libc16 | `NAME.exe` |
| 2. Assembly only | `NAME.asm` | NASM | `NAME.com` |
| 3. C reference and assembly | `NAME.c`, `asm/NAME.asm` | Open Watcom, libc16 and NASM | `NAME.exe` and `asm/NAME.com` |

This repository is layout 3: `hello.c` is the reference and
`asm/hello.asm` is the assembly version. Remove what a utility does not
need (see [Starting a new utility from this
template](#starting-a-new-utility-from-this-template)).

Which to use is up to the implementor. The trade-off is size against
effort. C is quicker to write and review. With libc16, which links only
the functions a program calls, its runtime costs under 1 KB on disk and
about 3 KB of conventional memory for a program like this one
(`hello.exe` is 1,384 bytes against 547 for `hello.com`; with Open
Watcom's own runtime it was 9,532; see `asm/README.md`). Assembly is
smaller still, but file I/O, error handling and number formatting all
have to be written and tested by hand. Size is a good reason to choose
assembly, for example for a tool that has to fit on a crowded boot
floppy.

**1. C only:** `make`, `make test`, CI and the release all use the C
`.EXE`.

**2. Assembly only:** the program is
a `.COM` (code, data and stack in one 64 KB segment) written for
`cpu 8086` so NASM rejects anything newer. With no C version to compare
against, `tests/run.sh` is the whole specification, so it has to cover
the behavior in full; to check standard error too, borrow
`asm/tests/err2out.asm`.

**3. C reference and assembly:** for a program that ships as a small
`.COM` but whose behavior is easier to define, read and change in C.
The C program is the reference: it is what the top-level `make`,
`make test`, CI and release build. `asm/` reimplements it, and
`make -C asm test` runs the same `tests/run.sh` against the `.COM` plus
`asm/tests/diff.sh`, which runs both programs on the same arguments and
requires identical standard output, standard error and exit status. Any
change to the C program goes into the assembly in the same PR, and a new
behavior gets a `diff.sh` case. Both workflows install NASM and run
`make -C asm test`, and the release attaches `asm/NAME.com` next to
`NAME.exe` (rules 5 and 7).

## Conventions

### 1. Build and test on Linux with GNU make and Open Watcom or NASM

Everything is built and tested on a Linux host, driven by GNU make. C
is cross-compiled with the Linux-hosted Open Watcom toolchain and linked
with libc16 only (no Open Watcom runtime or headers):

    make         # builds hello.exe
    make test    # runs the test suite under DOSBox-X
    make clean

Assembly is assembled with NASM (`nasm -f bin`, override with `NASM=`).
In layout 3 it lives in `asm/` with its own `Makefile`:

    make -C asm          # builds asm/hello.com
    make -C asm test     # run.sh and diff.sh against the C hello.exe
    make -C asm measure  # size / FAT12 / memory comparison
    make -C asm clean

In layout 2 the top-level `Makefile` is the assembly one, so plain
`make` and `make test` build and test `NAME.com`.

### 2. libc16 and Open Watcom

(Layouts 1 and 3. Layout 2 needs no Watcom, only NASM on `PATH`.)

C programs use [libc16](https://github.com/gr-dos/libc16), a C runtime
for small-model DOS programs, instead of Open Watcom's own, and the Open
Watcom toolchain that libc16 pins. By default `make` runs
`scripts/fetch-libc16`, which clones libc16 at the revision pinned in
that script into `build/libc16` and builds it there; libc16's build
fetches its pinned Open Watcom snapshot and JWasm into
`build/libc16/build/tools`. This needs `git`, `curl`, `xz` and a host C
compiler (for JWasm). To move to a newer libc16, change the pin.

To build against a local libc16 checkout instead (built with its own
`make`), point `LIBC16_ROOT` at it:

    make LIBC16_ROOT=../libc16
    make test LIBC16_ROOT=../libc16

The compiler and linker flags are libc16's consumer flags (its
`docs/ABI.md`): `wcc -zl -zld -x -ms -0 -s -bt=dos`, with only libc16's
headers, and `wlink option nodefaultlibs`. A function libc16 does not
provide is a link error. libc16 has no `printf`; programs write with
`fputs` and format numbers with small helpers (libc16's `libc16.h`).

### 3. `main` is protected

`main` only changes by merging a pull request. Branch protection on
`main`:

- requires a pull request before merging (no direct pushes),
- requires the `test` status check from `ci.yml` to pass,
- applies to administrators too ("Do not allow bypassing the above
  settings" / `enforce_admins`),
- disallows force pushes and deletion.

Work happens on a feature branch (for example `graham/impl`) and lands
through a PR. To set the same protection on a new repository:

    gh api -X PUT repos/OWNER/REPO/branches/main/protection --input - <<'EOF'
    {"required_status_checks":{"strict":false,"checks":[{"context":"test","app_id":15368}]},
     "enforce_admins":true,
     "required_pull_request_reviews":{"required_approving_review_count":0},
     "restrictions":null,"allow_force_pushes":false,"allow_deletions":false}
    EOF

(`app_id` 15368 is GitHub Actions, so only Actions can satisfy the check.)

### 4. Tests run under DOSBox-X via `make test`

`make test` runs `tests/run.sh`, which needs `dosbox-x` on the host
(override with `DOSBOX=`; set `KEEP=1` to keep the work directory).
It takes the program to test as its argument, so the same suite serves
the C `.EXE` and the assembly `.COM` (DOS tells them apart by the `MZ`
signature, not the file name).

The script builds fixtures in a temporary directory, writes one batch
file (`steps.bat`) holding every DOS-side step, runs it in a headless
DOSBox-X, then checks the results on the host. Step N records the
program's exit status in `RN.TXT` (via `rc.bat`) and its standard output
in `ON.TXT`. DOS cannot redirect standard error, so diagnostics are not
checked. To add a test, add a step to `steps.bat` and the matching
`rc` / `expect` / `check` lines.

### 5. CI must pass before merging

`.github/workflows/ci.yml` builds and runs `make test` (and, in layout
3, `make -C asm test`) on every pull request and every push to `main`. Its `test` job is a required status
check, so a PR cannot be merged until it passes.

### 6. `--version` and the `VERSION` file

`hello --version` prints

    hello (dos-hello16) 0.01

The version is the one line in `VERSION`; the `Makefile` compiles it in
as `-DVERSION="..."` for both Watcom and NASM. Versions are MS-DOS style, not semantic versioning:
they start at `0.01` and go `0.02`, `0.03`, ... `1.00`, `1.01`, and so on.
`make test` checks that `--version` matches `VERSION`.

### 7. Releases

`.github/workflows/release.yml` runs on every push to `main`, which (by
rule 3) is always a PR merge. If `VERSION` names a version that has no
`v<VERSION>` tag yet, it builds and tests `hello.exe`, tags the merge
commit `v<VERSION>`, and publishes a GitHub release with `hello.exe`
and `hello.com` attached. If the version is unchanged, it does nothing. To release, bump
`VERSION` in the PR. In layout 1 the release attaches only `NAME.exe`, and
in layout 2 only `NAME.com`.

## Starting a new utility from this template

1. Copy the repository as `gr-dos/NAME16` and rename `hello` and
   `hello16` throughout (`hello.c`, `asm/hello.asm`, both `Makefile`s,
   `tests/run.sh`, `asm/tests/diff.sh`, `asm/measure.sh`, the
   workflows, the `--version` string, this README).
2. Pick a layout (see [Implementation](#implementation-c-assembly-or-both)):
   - **C only:** delete `asm/`, and in both workflows drop `nasm`,
     `make -C asm test` and `asm/NAME.com`.
   - **Assembly only:** move `asm/NAME.asm` to the top level, replace
     the top-level `Makefile` with a NASM one (the `NAME.com` rule from
     `asm/Makefile`, with `test` running `tests/run.sh` on `NAME.com`),
     delete `NAME.c`, `scripts/fetch-libc16` and the rest of `asm/`, and
     in both workflows drop the libc16 cache and `make -C asm test` and
     release only `NAME.com`.
   - **C reference and assembly:** keep both, as is.
3. Reset `VERSION` to `0.01`.
4. Create the GitHub repository, push `main`, and apply the branch
   protection above.
5. Do the work on a feature branch and merge it with a PR.

## Files

- `hello.c`: the program
- `Makefile`: Open Watcom and libc16 build (`make`, `make test`,
  `make clean`)
- `scripts/fetch-libc16`: fetch and build the pinned libc16
- `VERSION`: the version, compiled in and printed by `--version`
- `tests/run.sh`: the test suite, run under DOSBox-X by `make test`
- `.github/workflows/ci.yml`: build and test on PRs and pushes to `main`
- `.github/workflows/release.yml`: tag and release when `VERSION` changes
- `asm/`: the 8086 assembly `hello.com` for layout 3, checked against
  `hello.exe` by `make -C asm test` in CI and released alongside it
  (see `asm/README.md`)

## License

MIT. See `LICENSE`.
