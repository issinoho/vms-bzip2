$! TEST_SMOKE.COM - smoke test for the built bzip2 ([.BIN_<arch>])
$!
$! Usage:  @[.VMS]TEST_SMOKE [bin-directory]
$! P1: where BZIP2.EXE and BZIP2RECOVER.EXE are (default [.BIN_<arch>]; the
$!     install check passes BZIP2$ROOT:[BIN]).
$!
$! Includes upstream's own test (make test): sample1-3.bz2 decompress to
$! sample1-3.ref, and sample1-3.ref compressed with -1, -2 and -3 give
$! sample1-3.bz2 byte for byte.  Files are compared byte by byte (DIFFERENCES
$! compares records): with VSI Perl where it is installed, otherwise with a
$! small C program compiled here (OpenVMS Alpha has no VSI Perl).
$!
$ set noon
$ saved_default = f$environment("DEFAULT")
$ proc = f$environment("PROCEDURE")
$ vmsdir = f$parse(proc,,,"DEVICE") + f$parse(proc,,,"DIRECTORY")
$ set default 'vmsdir'
$ set default [-]
$ top = f$environment("DEFAULT")
$ arch = f$edit(f$getsyi("ARCH_NAME"), "UPCASE")
$ bin = f$parse("[.BIN_''arch']",,,"DEVICE") + f$parse("[.BIN_''arch']",,,"DIRECTORY")
$ if p1 .nes. "" then bin = p1
$! The library and header: the tree's install tree, or the kit's (P1 given).
$ inc = f$parse("[.INSTALL_''arch'.INCLUDE]",,,"DEVICE") + f$parse("[.INSTALL_''arch'.INCLUDE]",,,"DIRECTORY")
$ olb = f$parse("[.INSTALL_''arch'.LIB]LIBBZ2.OLB")
$ if p1 .nes. ""
$ then
$   inc = bin - "BIN]" + "INCLUDE]"
$   olb = bin - "BIN]" + "LIB]LIBBZ2.OLB"
$ endif
$ write sys$output "SMOKE: testing ", bin
$ bzip2 = "$" + bin + "BZIP2.EXE"
$ bzip2recover = "$" + bin + "BZIP2RECOVER.EXE"
$ pass = 0
$ fail = 0
$ perl_setup = f$search("SYS$COMMON:[PERL-5_*]PERL_SETUP.COM")
$ if perl_setup .nes. "" then @'perl_setup'
$ if f$search("SMOKE.DIR") .eqs. "" then create/directory [.SMOKE]
$ set default [.SMOKE]
$ if arch .nes. "VAX" then set process/parse_style=extended
$! ODS-2 (OpenVMS VAX) allows one dot in a name and bzip2 appends ".bz2", so
$! there the files it compresses have no type: "r1", not "r1.dat".
$ dtype = ".dat"
$ if arch .eqs. "VAX" then dtype = ""
$ dspec = dtype            ! the same in a DCL file spec ("r1." on VAX)
$ if dspec .eqs. "" then dspec = "."
$! SAME a b: success if the two files hold the same bytes.
$ if perl_setup .nes. ""
$ then
$   create same.pl
open my $a, '<:raw', $ARGV[0] or exit 2; open my $b, '<:raw', $ARGV[1] or exit 2;
local $/; my $x = <$a>; my $y = <$b>; exit($x eq $y ? 0 : 1);
$!  PERL_SETUP defines perl as a foreign command symbol; DCL expands only the
$!  first symbol of a command, so put its value, not its name, in SAME.
$   same = perl + " same.pl"
$ else
$   write sys$output "SMOKE: no VSI Perl; comparing files with SAME.C"
$   create same.c
#include <stdio.h>
#include <stdlib.h>
int main(int argc, char **argv)
{
    FILE *a, *b;
    int c, d;
    if (argc != 3) exit(44);
    /* Text mode, as Perl reads them: a record file's records come back with
       their line ends, so a VAR file and a Stream_LF file holding the same
       lines compare equal; Stream_LF bytes are read unchanged. */
    a = fopen(argv[1], "r");
    b = fopen(argv[2], "r");
    if (a == NULL || b == NULL) exit(44);
    do {
        c = getc(a);
        d = getc(b);
        if (c != d) exit(44);
    } while (c != EOF);
    return 0;
}
$   cc/object=same.obj same.c
$   link/executable=same.exe same.obj
$   same = "$" + f$environment("DEFAULT") + "SAME.EXE"
$ endif
$!
$! GET from to: copy a sample here.  A sample that came by FTP in binary has
$! fixed-length 512-byte records, padded at the end; Stream_LF gives back
$! the file's own bytes.
$ goto get_done
$get:
$ copy/nolog 'from' 'to'
$ if f$file(to, "RFM") .eqs. "FIX" then set file/attribute=(rfm:stmlf) 'to'
$ return
$get_done:
$!
$! 1. version (bzip2 prints it on stderr)
$ define/user sys$error out.txt
$ define/user sys$output nla0:
$ bzip2 --version
$ search/nooutput out.txt "Version 1.0"
$ sev = $severity
$ name = "version"
$ gosub check_success
$!
$! 2-4. upstream's samples decompress to their .ref files
$ n = 1
$dec_loop:
$ from = "''top'sample''n'.bz2"
$ to = "t''n'.bz2"
$ gosub get
$ from = "''top'sample''n'.ref"
$ to = "e''n'.ref"
$ gosub get
$ bzip2 "-d" t'n'.bz2
$ sev = $severity
$ if sev .eq. 1
$ then
$   same t'n' e'n'.ref
$   if $status .ne. 1 then sev = 2
$ endif
$ name = "sample''n'.bz2 decompresses to sample''n'.ref"
$ gosub check_success
$ n = n + 1
$ if n .le. 3 then goto dec_loop
$!
$! 5-7. compressing sample<n>.ref with -<n> gives sample<n>.bz2 exactly
$ n = 1
$cmp_loop:
$ from = "''top'sample''n'.ref"
$ to = "r''n'''dspec'"
$ gosub get
$ from = "''top'sample''n'.bz2"
$ to = "e''n'.bz2"
$ gosub get
$ bzip2 "-''n'" r'n''dtype'
$ sev = $severity
$ if sev .eq. 1
$ then
$   same r'n''dtype'.bz2 e'n'.bz2
$   if $status .ne. 1 then sev = 2
$ endif
$ name = "sample''n'.ref compressed with -''n' is sample''n'.bz2"
$ gosub check_success
$ n = n + 1
$ if n .le. 3 then goto cmp_loop
$!
$! 8. a text file (variable-length records) round trip, keeping the original
$!    (-k) and testing (-t): its lines survive (patch 0004)
$ create text'dspec'
The quick brown fox jumps over the lazy dog.
OpenVMS: IA64, x86-64, Alpha and VAX.
$ copy/nolog text'dspec' orig.txt
$ bzip2 "-k" text'dtype'
$ sev = $severity
$ if sev .eq. 1 .and. f$search("text''dtype'.bz2") .eqs. "" then sev = 2
$ if sev .eq. 1
$ then
$   bzip2 "-t" text'dtype'.bz2
$   sev = $severity
$ endif
$ if sev .eq. 1
$ then
$   delete/nolog text'dspec';*
$   bzip2 "-d" text'dtype'.bz2
$   sev = $severity
$   if sev .eq. 1
$   then
$     same text'dspec' orig.txt
$     if $status .ne. 1 then sev = 2
$   endif
$ endif
$ name = "text file round trip (-k, -t, -d)"
$ gosub check_success
$!
$! 9. a corrupt file is an error
$ create bad.bz2
this is not a bzip2 file
$ define/user sys$error nla0:
$ bzip2 "-t" bad.bz2
$ sev = $severity
$ name = "a corrupt file gives an error status"
$ gosub check_failure
$!
$! 10. a missing file is an error
$ define/user sys$error nla0:
$ bzip2 "-d" nonexistent.bz2
$ sev = $severity
$ name = "a missing file gives an error status"
$ gosub check_failure
$!
$! 11. a program compiled with the default /NAMES links with LIBBZ2.OLB
$!     (bzlib.h declares the API /NAMES=(AS_IS,SHORTENED), patch 0001)
$ create ver.c
#include <stdio.h>
#include <bzlib.h>
int main (void)
{
  printf ("libbz2 %s\n", BZ2_bzlibVersion ());
  return 0;
}
$ cc/nolist/include_directory='inc' ver.c
$ link/nomap ver, 'olb'/library
$ define/user sys$output out.txt
$ run ver
$ search/nooutput out.txt "libbz2 1.0"
$ sev = $severity
$ name = "a program compiled /NAMES=UPPERCASE links with LIBBZ2.OLB"
$ gosub check_success
$!
$! 12. bzip2recover splits a file into its blocks
$ from = "''top'sample1.bz2"
$ to = "rec.bz2"
$ gosub get
$ define/user sys$error out.txt
$ bzip2recover rec.bz2
$ sev = $severity
$ if sev .eq. 1 .and. f$search("rec00001rec.bz2") .eqs. "" then sev = 2
$ name = "bzip2recover writes rec00001rec.bz2"
$ gosub check_success
$!
$ write sys$output "SMOKE: ''pass' passed, ''fail' failed"
$ delete/nolog *.*;*
$ set default [-]
$ set file/protection=o:rwed SMOKE.DIR
$ delete/nolog SMOKE.DIR;
$ set default 'saved_default'
$ if fail .eq. 0 then exit 1
$ exit 44
$!
$check_success:
$ if sev .eq. 1
$ then
$   pass = pass + 1
$   write sys$output "PASS: ", name
$ else
$   fail = fail + 1
$   write sys$output "FAIL: ", name, " (severity ", sev, ")"
$   if f$search("out.txt") .nes. ""
$   then
$     write sys$output "   output was:"
$     type out.txt;0
$   endif
$ endif
$ return
$!
$check_failure:
$ if sev .eq. 2 .or. sev .eq. 4
$ then
$   pass = pass + 1
$   write sys$output "PASS: ", name
$ else
$   fail = fail + 1
$   write sys$output "FAIL: ", name, " (severity ", sev, ", expected an error)"
$ endif
$ return
