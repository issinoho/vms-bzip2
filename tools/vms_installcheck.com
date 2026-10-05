$! VMS_INSTALLCHECK.COM <tree-dir-name> - install the BZIP2 kit, verify, smoke-test
$! the installed image, then remove it.  Changes the system while it runs (PCSI
$! database, SYS$COMMON:[BZIP2], system logical BZIP2$ROOT); leaves it as it was.
$ set noon
$ arch = f$edit(f$getsyi("ARCH_NAME"), "UPCASE")
$ base = "I64VMS"
$ if arch .eqs. "X86_64" then base = "X86VMS"
$ tree = f$environment("DEFAULT") - "]" + "." + p1 + "]"
$ kitdir = tree - "]" + ".KIT_''arch']"
$ write sys$output "=== INSTALL from ", kitdir
$ product install BZIP2 /producer=ISSINOHO /base_system='base' /source='kitdir' /options=noconfirm /log
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
$ product remove BZIP2 /producer=ISSINOHO /options=noconfirm /log
$ write sys$output "=== remove status ", $status
$ write sys$output "BZIP2$ROOT after removal: [", f$trnlnm("BZIP2$ROOT"), "]"
$ write sys$output "files after removal: [", f$search("SYS$COMMON:[BZIP2...]*.*"), "]"
$ write sys$output "startup after removal: [", f$search("SYS$STARTUP:BZIP2$STARTUP.COM"), "]"
$ product show product BZIP2 /producer=ISSINOHO
$ delete/symbol/global bzip2
$ delete/symbol/global bunzip2
$ delete/symbol/global bzcat
$ delete/symbol/global bzip2recover
