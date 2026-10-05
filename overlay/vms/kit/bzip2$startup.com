$! BZIP2$STARTUP.COM - system startup for bzip2 on OpenVMS
$!
$! Installed by PCSI into SYS$STARTUP.  Defines the system logical name
$! BZIP2$ROOT, pointing at the installed [BZIP2] directory.  To run it at every
$! boot, add this line to SYS$MANAGER:SYSTARTUP_VMS.COM:
$!
$!     $ @SYS$STARTUP:BZIP2$STARTUP.COM
$!
$! P1 = "INSTALL": also print the post-installation tasks (PCSI runs it so).
$! P1 = "REMOVE":  deassign BZIP2$ROOT instead (PCSI runs it so at removal).
$!
$! Users then define the commands with
$!     $ @BZIP2$ROOT:[000000]BZIP2$SETUP.COM
$!
$ set noon
$ mode = f$edit(p1, "UPCASE")
$ if mode .eqs. "REMOVE"
$ then
$   if f$trnlnm("BZIP2$ROOT", "LNM$SYSTEM_TABLE") .nes. "" then -
        deassign/system/executive_mode BZIP2$ROOT
$   exit 1
$ endif
$!
$! This procedure sits in <destination>[SYS$STARTUP]; the product is in
$! <destination>[BZIP2].  Rooted logicals need the physical form:
$! DKA0:[SYS0.SYSCOMMON.SYS$STARTUP] -> DKA0:[SYS0.SYSCOMMON.BZIP2.]
$ proc = f$environment("PROCEDURE")
$ dev = f$parse(proc,,,"DEVICE","NO_CONCEAL")
$ dir = f$edit(f$parse(proc,,,"DIRECTORY","NO_CONCEAL"), "UPCASE") - "]["
$ root = dir - "SYS$STARTUP]" + "BZIP2.]"
$ if root .eqs. dir + "BZIP2.]"
$ then
$   write sys$error "BZIP2$STARTUP: expected to be in a [SYS$STARTUP] directory, not ''dir'"
$   exit 44
$ endif
$ root = root - ".000000"
$ define/system/executive_mode/translation_attributes=concealed BZIP2$ROOT 'dev''root'
$ if f$search("BZIP2$ROOT:[BIN]BZIP2.EXE") .eqs. ""
$ then
$   write sys$error "BZIP2$STARTUP: BZIP2.EXE not found under ''dev'''root'"
$   exit 44
$ endif
$ if mode .nes. "INSTALL" then exit 1
$ say = "write sys$output"
$ say ""
$ say "    Post-installation tasks for bzip2"
$ say ""
$ say "    At system startup: to define BZIP2$ROOT at every boot, add this line to"
$ say "    SYS$MANAGER:SYSTARTUP_VMS.COM:"
$ say "    $ @SYS$STARTUP:BZIP2$STARTUP.COM"
$ say "    For each user: to define the commands, add this line to LOGIN.COM:"
$ say "    $ @BZIP2$ROOT:[000000]BZIP2$SETUP.COM"
$ say ""
$ say "    PRODUCT REMOVE BZIP2 removes the product and deassigns BZIP2$ROOT."
$ say ""
$ exit 1
