MINGW32   = C:/Apps/mingw32
TCL32     = C:/Apps/TCL

CC32      = $(MINGW32)/bin/gcc
WINDRES32 = $(MINGW32)/bin/windres
WINDMC32  = $(MINGW32)/bin/windmc
STRIP32   = $(MINGW32)/bin/strip

CFLAGS    = -Wall -O -I $(TCL32)/include
LDFLAGS   = -l tcl86
TCLLIB32  = -L $(TCL32)/lib

all: tclsvc.dll tclsvc.exe

tclsvc.exe: winsvc.c tclsvcmsg.h tclsvc.c tclsvcinfo.o
	$(CC32) -o $@ $(CFLAGS) $^ $(TCLLIB32) $(LDFLAGS) -Wl,--subsystem,console
	$(STRIP32) $@

tclsvcinfo.o: tclsvc.rc
	$(WINDRES32) -i $^ -o $@

tclsvc.dll: tclsvcmsg.o
	$(CC32) -o $@ $(CFLAGS) $^ -shared -Wl,--subsystem,windows
	$(STRIP32) $@

tclsvcmsg.o: tclsvcmsg.rc
	$(WINDRES32) -i $^ -o $@

tclsvcmsg.rc: tclsvcmsg.mc
	$(WINDMC32) $^

tclsvcmsg.h: tclsvcmsg.mc

install: tclsvc.dll tclsvc.exe
	@xcopy tclsvc.dll  $(subst /,\,$(TCL32))\bin /D /Y
	@xcopy tclsvc.exe  $(subst /,\,$(TCL32))\bin /D /Y
	@xcopy /s demo $(subst /,\,$(TCL32))\svc /D /Y

clean:
ifneq ("$(wildcard *.o)","")
	del /q tclsvcmsg.h tclsvcmsg.rc *.o *.bin
else
	@echo Clean already
endif
