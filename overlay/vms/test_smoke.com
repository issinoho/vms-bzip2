$! TEST_SMOKE.COM - smoke test for the built bzip2 ([.BIN_<arch>])
$!
$! Usage:  @[.VMS]TEST_SMOKE [bin-directory]
$! P1: where BZIP2.EXE and BZIP2RECOVER.EXE are (default [.BIN_<arch>]; the
$!     install check passes BZIP2$ROOT:[BIN]).
$!
$! Includes upstream's own test (make test): sample1-3.bz2 decompress to
$! sample1-3.ref, and sample1-3.ref compressed with -1, -2 and -3 give
$! sample1-3.bz2 byte for byte.  Files are compared byte by byte with VSI
$! Perl (DIFFERENCES compares records).
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
$ if perl_setup .eqs. ""
$ then
$   write sys$output "SMOKE: VSI Perl not found (SYS$COMMON:[PERL-5_*]PERL_SETUP.COM)"
$   exit 44
$ endif
$ @'perl_setup'
$ if f$search("SMOKE.DIR") .eqs. "" then create/directory [.SMOKE]
$ set default [.SMOKE]
$ set process/parse_style=extended
$ create same.pl
open my $a, '<:raw', $ARGV[0] or exit 2; open my $b, '<:raw', $ARGV[1] or exit 2;
local $/; my $x = <$a>; my $y = <$b>; exit($x eq $y ? 0 : 1);
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
$ copy/nolog 'top'sample'n'.bz2 t'n'.bz2
$ bzip2 "-d" t'n'.bz2
$ sev = $severity
$ if sev .eq. 1
$ then
$   perl same.pl t'n' 'top'sample'n'.ref
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
$ copy/nolog 'top'sample'n'.ref r'n'.dat
$ bzip2 "-''n'" r'n'.dat
$ sev = $severity
$ if sev .eq. 1
$ then
$   perl same.pl r'n'.dat.bz2 'top'sample'n'.bz2
$   if $status .ne. 1 then sev = 2
$ endif
$ name = "sample''n'.ref compressed with -''n' is sample''n'.bz2"
$ gosub check_success
$ n = n + 1
$ if n .le. 3 then goto cmp_loop
$!
$! 8. a text file (variable-length records) round trip, keeping the original
$!    (-k) and testing (-t): its lines survive (patch 0004)
$ create text.txt
The quick brown fox jumps over the lazy dog.
OpenVMS, IA64 and x86-64.
$ copy/nolog text.txt orig.txt
$ bzip2 "-k" text.txt
$ sev = $severity
$ if sev .eq. 1 .and. f$search("text.txt.bz2") .eqs. "" then sev = 2
$ if sev .eq. 1
$ then
$   bzip2 "-t" text.txt.bz2
$   sev = $severity
$ endif
$ if sev .eq. 1
$ then
$   delete/nolog text.txt;*
$   bzip2 "-d" text.txt.bz2
$   sev = $severity
$   if sev .eq. 1
$   then
$     perl same.pl text.txt orig.txt
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
$ copy/nolog 'top'sample1.bz2 rec.bz2
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
