# hello16

Hello world for 16-bit MS-DOS, built with Open Watcom.

The resulting `hello.exe` is a small-model, real-mode 8086 executable
(about 10 KB) that runs on any DOS from an original PC up.

This repository is also the template for other 16-bit DOS utilities
(see [dos-md5sum16](https://github.com/plicease/dos-md5sum16) and
[dos-tar16](https://github.com/plicease/dos-tar16)). The conventions
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
| 1. C only | `NAME.c` | Open Watcom | `NAME.exe` |
| 2. Assembly only | `NAME.asm` | NASM | `NAME.com` |
| 3. C reference and assembly | `NAME.c`, `asm/NAME.asm` | Open Watcom and NASM | `NAME.exe`, plus `asm/NAME.com` if CI tests it |

This repository is layout 3: `hello.c` is the reference and
`asm/hello.asm` is the assembly version. Remove what a utility does not
need (see [Starting a new utility from this
template](#starting-a-new-utility-from-this-template)).

Which to use is up to the implementor. The trade-off is size against
effort. C is quicker to write and review, but the Watcom C runtime costs
about 9 KB on disk and 11 KB of conventional memory per program
(`hello.exe` is 9,532 bytes against 511 for `hello.com`; see
`asm/README.md`). Assembly avoids that cost, but file I/O, error
handling and number formatting all have to be written and tested by
hand. Size is a good reason to choose assembly, for example for a tool
that has to fit on a crowded boot floppy.

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
behavior gets a `diff.sh` case. In this repository the assembly is an
experiment and is left out of CI and the release; a utility that ships
its `.COM` adds NASM and `make -C asm test` to both workflows and
attaches `asm/NAME.com` to the release (rules 5 and 7).

## Conventions

### 1. Build and test on Linux with GNU make and Open Watcom or NASM

Everything is built and tested on a Linux host, driven by GNU make. C
is cross-compiled with the Linux-hosted Open Watcom toolchain:

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

### 2. Watcom location

(Layouts 1 and 3. Layout 2 needs no Watcom, only NASM on `PATH`.)

The `Makefile` uses the Open Watcom installation in `~/opt/watcom` by
default. Point it somewhere else on the command line:

    make WATCOM=/path/to/watcom
    make test WATCOM=/path/to/watcom

The `Makefile` sets `INCLUDE` and puts `$(WATCOM)/binl64` and
`$(WATCOM)/binl` on `PATH` itself, so there is no environment to source
first. In CI, `open-watcom/setup-watcom` sets `WATCOM`, which overrides
the default.

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

`.github/workflows/ci.yml` builds and runs `make test` on every pull
request and every push to `main`. Its `test` job is a required status
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
attached. If the version is unchanged, it does nothing. To release, bump
`VERSION` in the PR. In layout 2 the attached program is `NAME.com`; in
layout 3 it is `NAME.exe`, plus `asm/NAME.com` if the utility ships it.

## Starting a new utility from this template

1. Copy the repository and rename `hello` and `dos-hello16` throughout
   (`hello.c`, `asm/hello.asm`, both `Makefile`s, `tests/run.sh`,
   `asm/tests/diff.sh`, `asm/measure.sh`, the workflows, the
   `--version` string, this README).
2. Pick a layout (see [Implementation](#implementation-c-assembly-or-both)):
   - **C only:** delete `asm/`.
   - **Assembly only:** move `asm/NAME.asm` to the top level, replace
     the top-level `Makefile` with a NASM one (the `NAME.com` rule from
     `asm/Makefile`, with `test` running `tests/run.sh` on `NAME.com`),
     delete `NAME.c` and the rest of `asm/`, and in both workflows
     install `nasm` instead of using `open-watcom/setup-watcom` and
     release `NAME.com`.
   - **C reference and assembly:** keep both. To ship the `.COM`,
     install `nasm` and run `make -C asm test` in both workflows, and
     attach `asm/NAME.com` to the release.
3. Reset `VERSION` to `0.01`.
4. Create the GitHub repository, push `main`, and apply the branch
   protection above.
5. Do the work on a feature branch and merge it with a PR.

## Files

- `hello.c`: the program
- `Makefile`: Open Watcom build (`make`, `make test`, `make clean`)
- `VERSION`: the version, compiled in and printed by `--version`
- `tests/run.sh`: the test suite, run under DOSBox-X by `make test`
- `.github/workflows/ci.yml`: build and test on PRs and pushes to `main`
- `.github/workflows/release.yml`: tag and release when `VERSION` changes
- `asm/`: the 8086 assembly `hello.com` for layout 3, checked against
  `hello.exe` by `make -C asm test` (here an experiment and minimal-size
  baseline, not part of CI or the release; see `asm/README.md`)

## License

MIT. See `LICENSE`.
