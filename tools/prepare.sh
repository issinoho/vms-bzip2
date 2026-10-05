#!/usr/bin/env bash
# prepare.sh - build a VMS-ready bzip2 source tree in staging/<name>-<version>/
#
#   1. fetch + verify the upstream tarball
#   2. extract it, apply patches/series, lay overlay/ over the top
#   3. write the PCSI kit inputs
#
# bzip2 has no configure: its Makefile compiles a fixed list of sources, which
# vms/descrip.mms lists too (checked below against the Makefile).
# Nothing in staging/ is ever edited by hand: fix things in patches/ or overlay/.
set -euo pipefail

top=$(cd "$(dirname "$0")/.." && pwd)
. "$top/upstream.conf"
name=$UPSTREAM_NAME-$UPSTREAM_VERSION
tarball=$top/cache/$(basename "$UPSTREAM_URL")
stage=$top/staging/$name

step() { echo "prepare: $*"; }
die() { echo "prepare: error: $*" >&2; exit 1; }

"$top/tools/fetch.sh" >/dev/null

step "extracting $name"
rm -rf "$stage"; mkdir -p "$top/staging"
tar -xzf "$tarball" -C "$top/staging"
[ -d "$stage" ] || die "tarball did not unpack to $stage"

while read -r p; do
    case $p in ''|'#'*) continue ;; esac
    step "patch $p"
    patch -d "$stage" -p1 -s --no-backup-if-mismatch -F0 < "$top/patches/$p" ||
        die "patch $p does not apply cleanly"
done < "$top/patches/series"

(cd "$top/overlay" && find . -type f) | while read -r f; do
    [ -e "$stage/$f" ] && die "overlay/$f would replace an upstream file; use a patch"
    true
done
cp -a "$top/overlay/." "$stage/"

# The library's objects in the Makefile (OBJS=) must be the ones descrip.mms
# builds: a new release that adds a source would otherwise not link.
unix=$(sed -n '/^OBJS=/,/^$/p' "$stage/Makefile" | tr ' \t\\=' '\n\n\n\n' | sed -n 's/\.o$//p')
for o in $unix; do
    grep -q "\$(OBJ)$o\.OBJ" "$stage/vms/descrip.mms" ||
        die "vms/descrip.mms does not build $o, which the Makefile's OBJS lists"
done
step "descrip.mms builds all $(echo "$unix" | wc -l) library objects"

if [ -d "$stage/vms/kit" ]; then
step "PCSI kit inputs"
: "${KIT_PRODUCER:=ISSINOHO}"
# Three-part versions (1.0.8): the third part is the PCSI update and our VMS
# patch level the ECO, so 1.0.8-vms1 is V1.0-8E1.
IFS=. read -r major minor update _ <<< "$UPSTREAM_VERSION"
pcsiversion="V$major.$minor-${update:-0}E$VMS_PATCH_LEVEL"
kitversion="$UPSTREAM_VERSION-vms$VMS_PATCH_LEVEL"
kit=$stage/vms/kit
subst() {
    sed -e "s/@PRODUCER@/$KIT_PRODUCER/g" -e "s/@BASE@/$1/g" \
        -e "s/@PCSIVERSION@/$pcsiversion/g" -e "s/@VERSION@/$UPSTREAM_VERSION/g" \
        -e "s/@KITVERSION@/$kitversion/g" -e "s/@ARCH@/$2/g"
}
for base in I64VMS X86VMS; do
    subst $base "" < "$kit/bzip2.pcsi\$desc_template" > "$kit/BZIP2-$base.PCSI\$DESC"
    subst $base "" < "$kit/bzip2.pcsi\$text_template" > "$kit/BZIP2-$base.PCSI\$TEXT"
done
rm -f "$kit/bzip2.pcsi\$desc_template" "$kit/bzip2.pcsi\$text_template"
mv "$kit/bzip2\$startup.com" "$kit/BZIP2\$STARTUP.COM"
mv "$kit/bzip2\$setup.com" "$kit/BZIP2\$SETUP.COM"
subst "" "IA64 and x86-64" < "$kit/readme.vms" > "$kit/README.VMS"; rm -f "$kit/readme.vms"
mkdir -p "$kit/doc"
cp "$stage/LICENSE" "$kit/doc/LICENSE."
cp "$stage/CHANGES" "$kit/doc/CHANGES."
cp "$stage/bzip2.1" "$kit/doc/BZIP2.1"
cp "$stage/bzip2.txt" "$kit/doc/BZIP2.TXT"
cp "$stage/manual.html" "$kit/doc/MANUAL.HTML"
printf 'KIT_PRODUCER=%s\nPCSI_VERSION=%s\nKIT_VERSION=%s\n' "$KIT_PRODUCER" "$pcsiversion" \
    "$kitversion" > "$kit/kit.env"
fi

step "staged $stage"
