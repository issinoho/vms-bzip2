<p align="center">
  <img src="docs/images/banner.svg" alt="bzip2 for OpenVMS: a DECterm window compressing a file" width="100%">
</p>

# bzip2 for OpenVMS

[bzip2](https://sourceware.org/bzip2/) (**1.0.8**), the block-sorting compressor, built natively for
OpenVMS on **IA64** and **x86-64**, following its own releases. It belongs to the same family as
[GNU grep](https://github.com/issinoho/vms-grep), [GNU sed](https://github.com/issinoho/vms-sed),
[GNU awk](https://github.com/issinoho/vms-awk), [GNU make](https://github.com/issinoho/vms-make),
[GNU diffutils](https://github.com/issinoho/vms-diffutils),
[GNU patch](https://github.com/issinoho/vms-patch), [GNU m4](https://github.com/issinoho/vms-m4),
[GNU Bison](https://github.com/issinoho/vms-bison), [flex](https://github.com/issinoho/vms-flex),
[GNU Wget](https://github.com/issinoho/vms-wget), [curl](https://github.com/issinoho/vms-curl),
[PCRE2](https://github.com/issinoho/vms-pcre2), [zlib](https://github.com/issinoho/vms-zlib),
[XZ Utils](https://github.com/issinoho/vms-xz) and [Zstandard](https://github.com/issinoho/vms-zstd)
for OpenVMS.

This repository holds **only our changes**: every build starts from the signed release tarball (Mark
Wielaard's key, pinned in `keys/`), applies our patches and adds our VMS files. bzip2 has no
configure; `vms/descrip.mms` compiles the sources its Makefile lists (`prepare.sh` checks they
agree).

## Status

**Released: [v1.0.8-vms1](https://github.com/issinoho/vms-bzip2/releases/tag/v1.0.8-vms1).**

| | IA64 (OpenVMS V8.4-2L3, VSI C 7.4) | x86-64 (OpenVMS E9.2-4, VSI C 7.7) |
|---|---|---|
| Builds | yes | yes |
| Smoke test: upstream's own test (sample1-3 decompress to the reference files and compress at -1, -2, -3 to the reference `.bz2` files byte for byte), a text-file round trip, `-t`, `bzip2recover`, a `/NAMES=UPPERCASE` program linking with `LIBBZ2.OLB`, error statuses | 12/12 | 12/12 |
| Kit install, smoke test on the installed kit, remove | clean | clean |
| PCSI kit (`BZIP2`, `V1.0-8E1`) | `ISSINOHO-I64VMS-BZIP2-V0100-8E1-1.PCSI` | `ISSINOHO-X86VMS-BZIP2-V0100-8E1-1.PCSI` |

## Installing the kit

Download the kit for your architecture from the
[latest release](https://github.com/issinoho/vms-bzip2/releases/latest) and check it against the
release's `SHA256SUMS`. A kit downloaded through a non-VMS system loses its record format, so
restore that first, then install it:

```
$ SET FILE/ATTRIBUTE=(RFM:FIX,LRL:8192,MRS:8192,RAT:NONE) ISSINOHO-*-BZIP2-V0100-8E1-1.PCSI
$ PRODUCT INSTALL BZIP2 /PRODUCER=ISSINOHO /SOURCE=dev:[dir]
$ @BZIP2$ROOT:[000000]BZIP2$SETUP.COM
$ bzip2 "-k" file.txt
```

It installs `bzip2` and `bzip2recover` in `[BZIP2.BIN]`, `LIBBZ2.OLB` (libbz2) in `[BZIP2.LIB]`,
`BZLIB.H` in `[BZIP2.INCLUDE]`, `BZIP2$SETUP.COM`, the documentation and `README.VMS` in
`[BZIP2.DOC]`, and `SYS$STARTUP:BZIP2$STARTUP.COM`, which defines `BZIP2$ROOT` (add it to
`SYS$MANAGER:SYSTARTUP_VMS.COM`). `PRODUCT REMOVE BZIP2` removes it.

## On VMS

- **Commands:** `BZIP2$SETUP.COM` defines `bzip2`, `bunzip2` (`bzip2 -d`), `bzcat`
  (`bzip2 -dc`) and `bzip2recover`.
- **Text files:** a VMS text file (variable-length or VFC records) is compressed as text:
  its records become LF-terminated lines, as on Unix, and decompressing gives a Stream_LF
  file with the same lines. Any other file (stream, fixed-length records: executables, kits)
  is compressed byte for byte.
- **The library:** compile with `/INCLUDE=BZIP2$ROOT:[INCLUDE]` and link with
  `BZIP2$ROOT:[LIB]LIBBZ2.OLB/LIBRARY`. It is compiled `/NAMES=(AS_IS,SHORTENED)` and its
  headers declare the API so, so programs compiled with any `/NAMES` link with it.
- **File names** such as `file.txt.bz2` need an ODS-5 disk.
- **Exit status:** a failed run has error severity under DCL, so `ON ERROR` works; under a
  GNV shell, `$?` is the exit code as on Unix.
- **Upper-case options in batch jobs:** under the TRADITIONAL DCL parse style unquoted
  options reach the program in lower case; quote them, use the long forms, or
  `$ SET PROCESS/PARSE_STYLE=EXTENDED` first.

## Patches

| Patch | Purpose |
|---|---|
| 0001 | `bzlib.h`: declare the API under `#pragma names as_is, shortened`, so programs compiled with any `/NAMES` link with the library. |
| 0002 | `bzip2.c`, `bzip2recover.c`: `exit()` through `vms_exit()` (an error severity under DCL); `main` ends with `exit()`. |
| 0003 | `bzip2.c`: a `BZIP2`/`BZIP` value starting with `$` is the foreign command that runs bzip2, not options (`getenv()` returns DCL symbols). |
| 0004 | `bzip2.c`: read a text file (variable-length or VFC records) as text, so its lines survive. |

## How to build

Set up `tools/nodes.conf` as described in
[vms-grep's README](https://github.com/issinoho/vms-grep#2b-build-on-vms-from-the-host-over-ssh).
The smoke tests compare files with VSI Perl.

```sh
git clone https://github.com/issinoho/vms-bzip2.git
cd vms-bzip2
tools/prepare.sh            # fetch + verify, patch, MMS lists, kit inputs
tools/build.sh ia64         # upload, then @[.VMS]BUILD on the node (MMS)
tools/test.sh ia64          # smoke test
tools/kit.sh ia64           # PCSI kit -> out/kits/
```

## Roadmap

1. Link this library into the other ports where they can use it (Wget, curl).
2. Offer the patches upstream.
3. A port to OpenVMS **Alpha**.

The family of ports, all for IA64 and x86-64, each following its upstream releases:

| Port | Latest release | |
|---|---|---|
| GNU grep — [vms-grep](https://github.com/issinoho/vms-grep) | [v3.12-vms3](https://github.com/issinoho/vms-grep/releases/tag/v3.12-vms3) | with `grep -P` through PCRE2 |
| PCRE2 — [vms-pcre2](https://github.com/issinoho/vms-pcre2) | [v10.49-vms1](https://github.com/issinoho/vms-pcre2/releases/tag/v10.49-vms1) | the regular-expression library |
| GNU sed — [vms-sed](https://github.com/issinoho/vms-sed) | [v4.10-vms1](https://github.com/issinoho/vms-sed/releases/tag/v4.10-vms1) | the stream editor |
| GNU awk (gawk) — [vms-awk](https://github.com/issinoho/vms-awk) | [v5.4.1-vms1](https://github.com/issinoho/vms-awk/releases/tag/v5.4.1-vms1) | built with gawk's own VMS port |
| zlib — [vms-zlib](https://github.com/issinoho/vms-zlib) | [v1.3.2-vms1](https://github.com/issinoho/vms-zlib/releases/tag/v1.3.2-vms1) | the compression library |
| **bzip2** (this port) — [vms-bzip2](https://github.com/issinoho/vms-bzip2) | [v1.0.8-vms1](https://github.com/issinoho/vms-bzip2/releases/tag/v1.0.8-vms1) | the bzip2 compressor and libbz2 |
| XZ Utils — [vms-xz](https://github.com/issinoho/vms-xz) | [v5.8.4-vms1](https://github.com/issinoho/vms-xz/releases/tag/v5.8.4-vms1) | xz and liblzma |
| Zstandard — [vms-zstd](https://github.com/issinoho/vms-zstd) | [v1.5.7-vms1](https://github.com/issinoho/vms-zstd/releases/tag/v1.5.7-vms1) | zstd and libzstd |
| curl — [vms-curl](https://github.com/issinoho/vms-curl) | [v8.22.0-vms2](https://github.com/issinoho/vms-curl/releases/tag/v8.22.0-vms2) | alongside VSI's curl kit, following curl's own releases |
| GNU Wget — [vms-wget](https://github.com/issinoho/vms-wget) | [v1.25.0-vms2](https://github.com/issinoho/vms-wget/releases/tag/v1.25.0-vms2) | the web retriever |
| GNU m4 — [vms-m4](https://github.com/issinoho/vms-m4) | [v1.4.21-vms1](https://github.com/issinoho/vms-m4/releases/tag/v1.4.21-vms1) | the macro processor |
| GNU Bison — [vms-bison](https://github.com/issinoho/vms-bison) | [v3.8.2-vms2](https://github.com/issinoho/vms-bison/releases/tag/v3.8.2-vms2) | the parser generator; runs GNU m4 |
| flex — [vms-flex](https://github.com/issinoho/vms-flex) | [v2.6.4-vms1](https://github.com/issinoho/vms-flex/releases/tag/v2.6.4-vms1) | the scanner generator; runs GNU m4 |
| GNU make — [vms-make](https://github.com/issinoho/vms-make) | [v4.4.1-vms1](https://github.com/issinoho/vms-make/releases/tag/v4.4.1-vms1) | built with make's own VMS port |
| GNU diffutils — [vms-diffutils](https://github.com/issinoho/vms-diffutils) | [v3.12-vms1](https://github.com/issinoho/vms-diffutils/releases/tag/v3.12-vms1) | cmp, diff, diff3, sdiff |
| GNU patch — [vms-patch](https://github.com/issinoho/vms-patch) | [v2.8-vms1](https://github.com/issinoho/vms-patch/releases/tag/v2.8-vms1) | applies diffs |

## Artwork

`docs/images/banner.svg` and `docs/images/icon.svg` were made for this project in the style
of classic DECwindows and VT terminals, like those of its sibling ports.

## Licence

bzip2 is free software under a BSD-style licence; see `LICENSE`. Our patches and VMS files are
distributed under the same terms.

OpenVMS is a trademark of VMS Software, Inc. This project is not affiliated with VMS
Software, Inc. or with the bzip2 project.
