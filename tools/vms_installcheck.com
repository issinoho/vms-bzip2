$! VMS_INSTALLCHECK.COM <tree-dir-name> - install the BZIP2 kit, verify, smoke-test
$! the installed image, then remove it.  Changes the system while it runs (PCSI
$! database, SYS$COMMON:[BZIP2], system logical BZIP2$ROOT); leaves it as it was.
$ set noon
$ arch = f$edit(f$getsyi("ARCH_NAME"), "UPCASE")
$ base = "I64VMS"
$ if arch .eqs. "X86_64" then base = "X86VMS"
$ if arch .eqs. "ALPHA" then base = "AXPVMS"
$ if arch .eqs. "VAX" then base = "VMS"
$ tree = f$environment("DEFAULT") - "]" + "." + p1 + "]"
$ kitdir = tree - "]" + ".KIT_''arch']"
$ write sys$output "=== INSTALL from ", kitdir
$ if arch .eqs. "VAX" then goto install_vax
$ product install BZIP2 /producer=ISSINOHO /base_system='base' /source='kitdir' /options=noconfirm /log
$ goto installed
$! PCSI on OpenVMS VAX V7.3 has no /OPTIONS=NOCONFIRM: its questions are
$! answered from the lines below (continue, default options, no review);
$! DCL skips any it does not ask.
$install_vax:
$ define/user_mode sys$command sys$input
$ product install BZIP2 /producer=ISSINOHO /base_system='base' /source='kitdir' /log
YES
YES
NO
$installed:
$ write sys$output "=== install status ", $status
$ product show product BZIP2 /producer=ISSINOHO
$ write sys$output "=== VERIFY"
$ write sys$output "startup procedure: [", f$search("SYS$STARTUP:BZIP2$STARTUP.COM"), "]"
$ show logical BZIP2$ROOT
$ directory/nohead/notrail BZIP2$ROOT:[000000...]*.*
$ @BZIP2$ROOT:[000000]BZIP2$SETUP.COM
$ show symbol bzip2
$ bzip2 --version
$ write sys$output "=== SMOKE TEST on installed image"
$ smoke = tree - "]" + ".VMS]TEST_SMOKE.COM"
$ @'smoke' BZIP2$ROOT:[BIN]
$ write sys$output "=== REMOVE"
$ if arch .eqs. "VAX" then goto remove_vax
$ product remove BZIP2 /producer=ISSINOHO /options=noconfirm /log
$ goto removed
$remove_vax:
$ define/user_mode sys$command sys$input
$ product remove BZIP2 /producer=ISSINOHO /log
YES
$removed:
$ write sys$output "=== remove status ", $status
$ write sys$output "BZIP2$ROOT after removal: [", f$trnlnm("BZIP2$ROOT"), "]"
$ write sys$output "files after removal: [", f$search("SYS$COMMON:[BZIP2...]*.*"), "]"
$ write sys$output "startup after removal: [", f$search("SYS$STARTUP:BZIP2$STARTUP.COM"), "]"
$ product show product BZIP2 /producer=ISSINOHO
$ delete/symbol/global bzip2
$ delete/symbol/global bunzip2
$ delete/symbol/global bzcat
$ delete/symbol/global bzip2recover
