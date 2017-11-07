@echo off

set TCL_HOME=C:\Apps\Tcl

if %1x == x goto PrintUsage
if %2x == x goto PrintUsage
if /i %1 == create goto Create
if /i %1 == delete goto Delete
echo Unknown command - %1
goto PrintUsage

:Create
if %3x == x goto PrintUsage
if %4x == x goto PrintUsage
rem
rem The command that launches the service will supply a configration file that is
rem named after and is expected to be in the same directory as the service script
rem
rem Note that as-is the last (#4) argument does not tolerate spaces in the path
rem
sc create %2 binPath= "%TCL_HOME%\bin\tclsvc.exe %4 %~dpn4.conf" DisplayName= %3
if %errorlevel% neq 0 goto End
reg query HKLM\SYSTEM\CurrentControlSet\Services\EventLog\Application\TCLSvc /v EventMessageFile 1>nul 2>nul
if %errorlevel% equ 0 goto End
reg add HKLM\SYSTEM\CurrentControlSet\Services\EventLog\Application\TCLSvc /v EventMessageFile /d %TCL_HOME%\bin\tclsvc.dll
reg add HKLM\SYSTEM\CurrentControlSet\Services\EventLog\Application\TCLSvc /v TypesSupported /t REG_DWORD /d 7
goto End

:Delete
sc delete %2
reg query HKLM\SYSTEM\CurrentControlSet\Services /s /f *\tclsvc.exe* /d 1>nul 2>nul
if %errorlevel% equ 0 goto End
reg delete HKLM\SYSTEM\CurrentControlSet\Services\EventLog\Application\TCLSvc /va /f
goto End

:PrintUsage
echo Usage:
echo %~n0 create ServiceName "Service Display Name" C:\Full\Path\To\Service.tcl
echo %~n0 delete ServiceName

:End
