#!/bin/sh
#
# Compare the Watcom hello.exe with the assembly hello.com: file size,
# FAT12 allocation on the standard floppy formats (measured by copying
# each file onto a freshly formatted image with mtools), and the
# conventional memory DOS needs to load each program.
#
# Usage: sh measure.sh path/to/hello.exe path/to/hello.com

set -u
LC_ALL=C
export LC_ALL

exe=${1:?usage: measure.sh hello.exe hello.com}
com=${2:?usage: measure.sh hello.exe hello.com}
for t in mformat mcopy mdir minfo; do
    command -v $t >/dev/null || { echo "$t (mtools) not found" >&2; exit 2; }
done

work=$(mktemp -d "${TMPDIR:-/tmp}/doshello.XXXXXX")
trap 'rm -rf "$work"' EXIT

size() { wc -c < "$1" | tr -d ' '; }

# u16 FILE OFFSET: little-endian word
u16() { od -A n -t u2 -j "$2" -N 2 "$1" | tr -d ' '; }

# free FORMAT [FILE]: bytes free on a fresh FORMAT (KB) image, after
# copying FILE onto it if given
free() {
    img=$work/f.img
    rm -f "$img"
    mformat -C -f "$1" -i "$img" :: >/dev/null || exit 2
    [ $# -lt 2 ] || mcopy -i "$img" "$2" ::X >/dev/null || exit 2
    mdir -i "$img" :: | sed -n 's/^ *\([0-9 ]*\) bytes free.*/\1/p' | tr -d ' '
}

echo "File size (bytes)"
printf '  %-10s %6d\n' hello.exe "$(size "$exe")" hello.com "$(size "$com")"

echo
echo "FAT12 allocation (bytes taken from a fresh floppy, clusters)"
printf '  %-8s %8s %18s %18s\n' format cluster hello.exe hello.com
for f in 360 720 1200 1440; do
    empty=$(free $f)
    used_e=$((empty - $(free $f "$exe")))
    used_c=$((empty - $(free $f "$com")))
    cl=$(minfo -i "$work/f.img" :: |
        sed -n 's/^cluster size: *\([0-9]*\).*/\1/p')
    cl=$((cl * 512))
    printf '  %-8s %8d %10d (%3d cl) %10d (%3d cl)\n' "${f}K" $cl \
        $used_e $((used_e / cl)) $used_c $((used_c / cl))
done

# MZ header: bytes in last page, pages, header paragraphs, min alloc
last=$(u16 "$exe" 2); pages=$(u16 "$exe" 4)
hdr=$(u16 "$exe" 8); minalloc=$(u16 "$exe" 10)
[ "$last" -eq 0 ] && last=512
image=$(( (pages - 1) * 512 + last - hdr * 16 ))
exe_min=$(( 256 + (image + 15) / 16 * 16 + minalloc * 16 ))

# a .COM has no header: DOS needs the PSP, the image and a stack; 256
# bytes of stack is ample (hello uses a few words; DOS and BIOS
# interrupt handlers may push more onto it)
com_min=$(( 256 + ($(size "$com") + 15) / 16 * 16 + 256 ))

echo
echo "Conventional memory needed to load (bytes, including the 256-byte PSP)"
printf '  %-10s %6d  (image %d + min alloc %d paragraphs)\n' \
    hello.exe $exe_min $image $minalloc
printf '  %-10s %6d  (image %d + 256 stack)\n' hello.com $com_min "$(size "$com")"
