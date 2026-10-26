#!/bin/sh
#
# Differential tests: run the Watcom hello.exe and the assembly
# hello.com on the same arguments under DOSBox-X and require identical
# bytes on standard output, identical bytes on standard output plus
# standard error, and identical exit status.  A few cases are also
# checked against exact expected bytes, CR LF line endings included.
#
# Standard error is captured with err2out.com (built from err2out.asm
# next to this script), which runs a program with handle 2 duplicated
# from handle 1.  Redirections are written before the command
# (">file cmd args") so that arguments with an odd number of quotes do
# not swallow them.
#
# To add a test: add a line to the case list below (the line is the
# argument text, verbatim; an empty line means no arguments).
#
# Usage: tests/diff.sh path/to/hello.exe path/to/hello.com
# Environment: DOSBOX (default dosbox-x), KEEP=1 to keep the work
#              directory.

set -u

here=$(cd "$(dirname "$0")" && pwd)
ref=${1:?usage: diff.sh hello.exe hello.com}
asm=${2:?usage: diff.sh hello.exe hello.com}
DOSBOX=${DOSBOX:-dosbox-x}

command -v "$DOSBOX" >/dev/null || { echo "$DOSBOX not found" >&2; exit 2; }
for f in "$ref" "$asm" "$here/err2out.com"; do
    [ -f "$f" ] || { echo "$f not found" >&2; exit 2; }
done
ref=$(cd "$(dirname "$ref")" && pwd)/$(basename "$ref")
asm=$(cd "$(dirname "$asm")" && pwd)/$(basename "$asm")

work=$(mktemp -d "${TMPDIR:-/tmp}/doshello.XXXXXX")
pass=0
fail=0
LC_ALL=C
export LC_ALL

long=$(printf '%0100d' 0 | tr 0 x)

# ------------------------------------------------------------------
# fixtures

cd "$work" || exit 2
cp "$ref" ref.exe &&
cp "$asm" asm.com &&
cp "$here/err2out.com" err2out.com || exit 2

cat > cases.txt <<EOS

--help
-h
-?
--version
--help extra
--version --bogus
extra --help
--bogus
-
--HELP
--hel
--helpx
--versio
--versionx
-h--
/?
,--help
   --version
	--help
"a b"
a"b c"d
""
"" --help
"--help"
-"h"
"--ver"sion
a\\"b
a\\\\"b c"
a\\\\\\"b c"
a\\b
x\\
"a
\\"
"\\""
\\"a
\\\\"a b"
a""
""""
$long
"$long"
EOS

cat > rc.bat <<'EOS'
@echo off
if errorlevel 2 goto rc2
if errorlevel 1 goto rc1
echo rc0 >c:\r%1.txt
goto end
:rc1
echo rc1 >c:\r%1.txt
goto end
:rc2
echo rc2 >c:\r%1.txt
:end
EOS

# for case N and program P (c = ref.exe, a = asm.com):
#   PON.TXT  standard output       RPON.TXT  its exit status
#   PBN.TXT  both streams          RPBN.TXT  its exit status
n=0
printf '@echo off\r\n' > steps.bat
while IFS= read -r args; do
    n=$((n + 1))
    for p in c a; do
        case $p in c) prog=ref.exe ;; a) prog=asm.com ;; esac
        printf '>%so%d.txt %s %s\r\ncall rc %so%d\r\n' \
            $p $n $prog "$args" $p $n >> steps.bat
        printf '>%sb%d.txt err2out %s %s\r\ncall rc %sb%d\r\n' \
            $p $n $prog "$args" $p $n >> steps.bat
    done
done < cases.txt

SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy timeout 300 \
    "$DOSBOX" -defaultconf -silent -nogui -nomenu \
    -set "cpu cycles=max" \
    -c "mount c \"$work\"" -c "c:" \
    -c "steps.bat" -c "exit" >dosbox.log 2>&1

# ------------------------------------------------------------------
# checks

ok()     { pass=$((pass + 1)); }
not_ok() { printf "FAIL: %s\n" "$*"; fail=$((fail + 1)); }

# same FILE: the C and assembly versions of FILE must exist and match
same() {
    if [ -f "C$1.TXT" ] && cmp -s "C$1.TXT" "A$1.TXT"; then
        ok
    else
        not_ok "$1 differs: [$args]"
        diff "C$1.TXT" "A$1.TXT" 2>&1 | sed 's/^/    /'
    fi
}

# exact FILE: FILE from both versions must be the printf(1) format on
# stdin
exact() {
    # shellcheck disable=SC2059
    printf "$(cat)" > want.txt
    for p in C A; do
        if cmp -s want.txt "$p$1.TXT"; then
            ok
        else
            not_ok "$p$1.TXT is not as expected"
        fi
    done
}

n=0
while IFS= read -r args; do
    n=$((n + 1))
    for s in O B; do
        same "$s$n"
        if [ -f "RC$s$n.TXT" ] && cmp -s "RC$s$n.TXT" "RA$s$n.TXT"; then
            ok
        else
            not_ok "exit status differs for $s$n: [$args]"
        fi
    done
done < cases.txt

exact O1 <<'EOS'
Hello, world!\r\n
EOS
exact B9 <<'EOS'
hello: unrecognized option '--bogus'\r\nTry 'hello --help' for more information.\r\n
EOS
exact B21 <<'EOS'
hello: extra operand 'a b'\r\nTry 'hello --help' for more information.\r\n
EOS
exact O9 < /dev/null

# ------------------------------------------------------------------

echo "$pass passed, $fail failed"
if [ "$fail" -ne 0 ] || [ "${KEEP:-0}" = 1 ]; then
    echo "work directory: $work"
else
    rm -rf "$work"
fi
[ "$fail" -eq 0 ]
