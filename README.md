# hello16

Hello world for 16-bit MS-DOS, built with Open Watcom.

The resulting `hello.exe` is a small-model, real-mode 8086 executable
(about 10 KB) that runs on any DOS from an original PC up.

This repository is also the template for other 16-bit DOS utilities
(see [dos-md5sum16](https://github.com/plicease/dos-md5sum16) and
[dos-tar16](https://github.com/plicease/dos-tar16)). The conventions
below are what every such utility should follow.

## Usage

    hello              prints "Hello, world!"
    hello --help       show help (also -h, -?)
    hello --version    show version

The exit code is 0 on success and 1 for a bad option or operand.

## Conventions

### 1. Build and test on Linux with GNU make and Open Watcom

Everything is built and tested on a Linux host, cross-compiling with the
Linux-hosted Open Watcom toolchain driven by GNU make:

    make         # builds hello.exe
    make test    # runs the test suite under DOSBox-X
    make clean

### 2. Watcom location

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
as `-DVERSION="..."`. Versions are MS-DOS style, not semantic versioning:
they start at `0.01` and go `0.02`, `0.03`, ... `1.00`, `1.01`, and so on.
`make test` checks that `--version` matches `VERSION`.

### 7. Releases

`.github/workflows/release.yml` runs on every push to `main`, which (by
rule 3) is always a PR merge. If `VERSION` names a version that has no
`v<VERSION>` tag yet, it builds and tests `hello.exe`, tags the merge
commit `v<VERSION>`, and publishes a GitHub release with `hello.exe`
attached. If the version is unchanged, it does nothing. To release, bump
`VERSION` in the PR.

## Starting a new utility from this template

1. Copy the repository and rename `hello.c`, `hello.exe` and
   `dos-hello16` throughout (`Makefile`, `tests/run.sh`,
   `.github/workflows/release.yml`, the `--version` string, this README).
2. Reset `VERSION` to `0.01`.
3. Create the GitHub repository, push `main`, and apply the branch
   protection above.
4. Do the work on a feature branch and merge it with a PR.

## Files

- `hello.c`: the program
- `Makefile`: Open Watcom build (`make`, `make test`, `make clean`)
- `VERSION`: the version, compiled in and printed by `--version`
- `tests/run.sh`: the test suite, run under DOSBox-X by `make test`
- `.github/workflows/ci.yml`: build and test on PRs and pushes to `main`
- `.github/workflows/release.yml`: tag and release when `VERSION` changes
- `asm/`: optional 8086 assembly `hello.com`, a minimal-size baseline
  (experiment; not part of the build, tests or release; see
  `asm/README.md`)

## License

MIT. See `LICENSE`.
