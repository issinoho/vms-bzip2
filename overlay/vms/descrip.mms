! DESCRIP.MMS - build bzip2 for OpenVMS (IA64, x86-64)
!
! Run via [.VMS]BUILD.COM, which passes ARCH and creates the output
! directories.  bzip2 has no configure; the sources are the Makefile's.
!
! Outputs:
!   [.OBJ_<arch>]LIBBZ2.OLB           the library (libbz2)
!   [.BIN_<arch>]BZIP2.EXE, BZIP2RECOVER.EXE
!   [.INSTALL_<arch>.INCLUDE]BZLIB.H  install tree used by other ports
!   [.INSTALL_<arch>.LIB]LIBBZ2.OLB

.IFDEF ARCH
.ELSE
ARCH = IA64
.ENDIF

OBJ = [.OBJ_$(ARCH)]
BIN = [.BIN_$(ARCH)]
INST = [.INSTALL_$(ARCH)

! VSI C qualifiers shared by the family of ports (/NAMES=(AS_IS,SHORTENED);
! bzlib.h declares its API so on VMS, patch 0001, so programs compiled with
! any /NAMES link with the library).  _FILE_OFFSET_BITS: bzip2 handles files
! over 2 GB; vms_exit and vms_crtl_init are the family's VMS run-time setup.
CC = CC
CFLAGS = /NAMES=(AS_IS,SHORTENED)/FLOAT=IEEE_FLOAT/IEEE_MODE=DENORM_RESULTS-
	/PREFIX_LIBRARY_ENTRIES=ALL_ENTRIES/WARNINGS=(ERRORS=IMPLICITFUNC)/MAIN=POSIX_EXIT-
	/NOLIST/INCLUDE_DIRECTORY=([],[.VMS])-
	/DEFINE=(_LARGEFILE,_USE_STD_STAT,_POSIX_EXIT)

LIB = $(OBJ)LIBBZ2.OLB
LIB_OBJS = $(OBJ)blocksort.OBJ, $(OBJ)huffman.OBJ, $(OBJ)crctable.OBJ, -
	$(OBJ)randtable.OBJ, $(OBJ)compress.OBJ, $(OBJ)decompress.OBJ, -
	$(OBJ)bzlib.OBJ
VMS_OBJS = $(OBJ)vms_exit.OBJ, $(OBJ)vms_crtl_init.OBJ

ALL : $(LIB), $(BIN)BZIP2.EXE, $(BIN)BZIP2RECOVER.EXE, INSTALL_TREE
	@ CONTINUE

INSTALL_TREE : $(INST).LIB]LIBBZ2.OLB, $(INST).INCLUDE]BZLIB.H
	@ CONTINUE

! "-": LIBRARY and LINK end with a warning status for modules compiled
! with warnings; tools/build.sh fails the build on real errors.
$(LIB) : $(LIB_OBJS)
	IF F$SEARCH("$(MMS$TARGET)") .EQS. "" THEN LIBRARY/CREATE/OBJECT $(MMS$TARGET)
	- LIBRARY/REPLACE/OBJECT $(MMS$TARGET) $(LIB_OBJS)

$(BIN)BZIP2.EXE : $(OBJ)bzip2.OBJ, $(VMS_OBJS), $(LIB)
	- LINK/EXECUTABLE=$(MMS$TARGET)/MAP=$(OBJ)BZIP2.MAP $(OBJ)bzip2.OBJ, $(VMS_OBJS), $(LIB)/LIBRARY

$(BIN)BZIP2RECOVER.EXE : $(OBJ)bzip2recover.OBJ, $(VMS_OBJS)
	- LINK/EXECUTABLE=$(MMS$TARGET)/MAP=$(OBJ)BZIP2RECOVER.MAP $(OBJ)bzip2recover.OBJ, $(VMS_OBJS)

$(INST).LIB]LIBBZ2.OLB : $(LIB)
	COPY $(MMS$SOURCE) $(MMS$TARGET)

$(INST).INCLUDE]BZLIB.H : []bzlib.h
	COPY $(MMS$SOURCE) $(MMS$TARGET)


$(OBJ)blocksort.OBJ : []blocksort.c, []bzlib.h, []bzlib_private.h
	- $(CC) $(CFLAGS) /OBJECT=$(MMS$TARGET) $(MMS$SOURCE)
$(OBJ)huffman.OBJ : []huffman.c, []bzlib.h, []bzlib_private.h
	- $(CC) $(CFLAGS) /OBJECT=$(MMS$TARGET) $(MMS$SOURCE)
$(OBJ)crctable.OBJ : []crctable.c, []bzlib.h, []bzlib_private.h
	- $(CC) $(CFLAGS) /OBJECT=$(MMS$TARGET) $(MMS$SOURCE)
$(OBJ)randtable.OBJ : []randtable.c, []bzlib.h, []bzlib_private.h
	- $(CC) $(CFLAGS) /OBJECT=$(MMS$TARGET) $(MMS$SOURCE)
$(OBJ)compress.OBJ : []compress.c, []bzlib.h, []bzlib_private.h
	- $(CC) $(CFLAGS) /OBJECT=$(MMS$TARGET) $(MMS$SOURCE)
$(OBJ)decompress.OBJ : []decompress.c, []bzlib.h, []bzlib_private.h
	- $(CC) $(CFLAGS) /OBJECT=$(MMS$TARGET) $(MMS$SOURCE)
$(OBJ)bzlib.OBJ : []bzlib.c, []bzlib.h, []bzlib_private.h
	- $(CC) $(CFLAGS) /OBJECT=$(MMS$TARGET) $(MMS$SOURCE)
$(OBJ)bzip2.OBJ : []bzip2.c, []bzlib.h
	- $(CC) $(CFLAGS) /OBJECT=$(MMS$TARGET) $(MMS$SOURCE)
$(OBJ)bzip2recover.OBJ : []bzip2recover.c
	- $(CC) $(CFLAGS) /OBJECT=$(MMS$TARGET) $(MMS$SOURCE)
$(OBJ)vms_exit.OBJ : [.VMS]vms_exit.c
	- $(CC) $(CFLAGS) /OBJECT=$(MMS$TARGET) $(MMS$SOURCE)
$(OBJ)vms_crtl_init.OBJ : [.VMS]vms_crtl_init.c
	- $(CC) $(CFLAGS) /OBJECT=$(MMS$TARGET) $(MMS$SOURCE)

CLEAN :
	IF F$SEARCH("$(OBJ)*.*") .NES. "" THEN DELETE/NOLOG $(OBJ)*.*;*
	IF F$SEARCH("$(BIN)*.*") .NES. "" THEN DELETE/NOLOG $(BIN)*.*;*
