$! BZIP2$SETUP.COM - define the bzip2 commands for a user
$!
$! Add to LOGIN.COM (or SYS$MANAGER:SYLOGIN.COM for everyone):
$!     $ @BZIP2$ROOT:[000000]BZIP2$SETUP.COM
$!
$! Quote upper-case options, or SET PROCESS/PARSE_STYLE=EXTENDED: traditional DCL
$! parsing changes the case of unquoted arguments; batch jobs use the traditional style.
$!
$ if f$trnlnm("BZIP2$ROOT") .eqs. ""
$ then
$   write sys$error "BZIP2$SETUP: BZIP2$ROOT is not defined; run BZIP2$STARTUP.COM first"
$   exit 44
$ endif
$ bzip2        :== $BZIP2$ROOT:[BIN]BZIP2.EXE
$ bunzip2      :== "$BZIP2$ROOT:[BIN]BZIP2.EXE -d"
$ bzcat        :== "$BZIP2$ROOT:[BIN]BZIP2.EXE -dc"
$ bzip2recover :== $BZIP2$ROOT:[BIN]BZIP2RECOVER.EXE
$ exit 1
