# TCLSVC

A minimalistic NT service runner for TCL scripts. Your TCL script will be executed in a somewhat constrained environment that provides basic garantees about NT service responsiveness.

## Motivation

The service should respond to NT service events - stop, shutdown - in a timely manner. It is all too easy (almost natural) for a TCL script to enter a nested event loop and prevent the service executable to see and react to NT service events.

The additional driving factor was to have a minimal codebase. Windows already provides tools to start, stop, create and delete service. Embedding the code that provides tha same functionality into the service runner seemed counterproductive - increased maintenance efforts with no tangible benefits.

## Implementation

This service runner requires TCL service script to be event driven. While standard blocking operations are not prohibited, it is expected that they will be avoided.

## Demo Service

Project includes a demo service script - `httpsvc.tcl`. This is a simple HTTP/1.1 web server that serves static and dynamic content. `dyn_content.tcl` explains how to implement and register dynamic content handlers.

> Note that depending on the complexity of the dynamic content generation it might be a good idea to avoid doing it from within the `httpsvc` itself. A pool of worker processes that requests can be dispatched to for processing is one of the possible solutions that helps preventing TCL service script from stalling the service runner.

## Getting Started

These instructions will get you a copy of the project up and running. Note that while these instructions reference 32-bit environment, because that was a development target, the implementation has no specific restricitons and can be built for a 64-bit platform.

### Prerequisites

The provided Makefile uses [MinGW-W64](https://sourceforge.net/projects/mingw-w64/files/Toolchains%20targetting%20Win32/Personal%20Builds/mingw-builds/) GCC compiler for 32 bit target. i686-win32-dwarf was used for development.

> Note that as distributed MinGW's `make` is called `mingw32-make`. You might want to rename it or replace the `make` command in the instructions below with the `mingw64-make`.

You will also need a 32-bit TCL for Windows installed. For instance, [ActiveTcl](https://www.activestate.com/activetcl/downloads).

Depending on the installation method you select you might need to add `bin` directory for one or both items to your PATH.

### Compiling

Create `local.mk` script. It will be included by the TCLSVC Makefile and it has to define MINGW32 and TCL32 variables and make them point to locations where MinGW and TCL are installed on your machine. For example:

```makefile
MINGW32 = C:/Apps/mingw32
TCL32   = C:/Apps/TCL
```

Build the TCLSVC

```
make
```

This will generate `tclsvc.exe` and `tclsvc.dll`.

### Installing the Demo

A demo script of the HTTP server can be installed by executing:

```
make install
```

This will copy tclsvc - EXE and DLL - into TCL `bin` directory and the demo script and the demo web site "content" into TCL `svc` directory. If the latter does not exist, you will be prompted.

The final step before running the demo as the NT service is to actully register it as a service. While this can be done manually, a helper batch script - `tclsvcctl.cmd` - is provided that makes the job a bit easier.

> Note that `tclsvcctl.cmd` needs to know where TCL is installed. You need to modify `TCL_HOME` variable defined in the batch script and make it point to the directory where TCL is installed.

```batchfile
set TCL_HOME=C:\Apps\Tcl
```

The `tclsvcctl.cmd` needs the service name - a short identifier-like name that is used to add service to the registry, a display name - a name that will be visible in the `services.msc`, and a path to the service script. Assuming `TCL_HOME` point to `C:\Apps\Tcl` the following command would register the demo service:

```batchfile
tclsvcctl create DemoHttpService "Demo TCL HTTP Service" C:\Apps\Tcl\svc\httpsvc.tcl
```

### Running the Demo

Open `services.msc`, find the newly added service, which will be stopped, and click start.

Alternatively, if you prefer a command line approach, either execute:

```batchfile
sc start DemoHttpService
```

### Stopping and Removing the Demo

To stop the demo service execute:

```batchfile
sc stop DemoHttpService
```

and to remove it:

```batchfile
tclsvcctl delete DemoHttpService
```
