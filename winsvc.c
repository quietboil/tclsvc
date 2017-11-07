#include <windows.h>
#include <tcl.h>
#include "tclsvcmsg.h"

static VOID WINAPI SvcMain ( DWORD, LPTSTR * );
static VOID WINAPI SvcCtrlHandler ( DWORD );

VOID SvcSetStatus ( DWORD, DWORD );
VOID SvcReport ( DWORD, LPTSTR, ... );

void StartAndRunTclService ( char const *  );
void TclService_NotifyStopRequested ();

static SERVICE_STATUS          ServiceStatus;
static SERVICE_STATUS_HANDLE   hServiceStatus;

//----------------------------------------------------------------------
//
// _tmain:
//   Entry point for the process
//
//----------------------------------------------------------------------

int main ( int argc, char *argv[] )
{
    SERVICE_TABLE_ENTRY dispatchTable[] = {
        { "TCLSvc", SvcMain },
        { NULL, NULL }
    };

    if( !StartServiceCtrlDispatcher( dispatchTable ) ) {
        puts( "This program should be run as a service." );
    }

    return 0;
}

//----------------------------------------------------------------------
//
// SvcMain:
//   Entry point for the service
//
// Parameters:
//   argc - Number of arguments in the lpszArgv array
//   argv - Array of strings. The first string is the name of
//          the service and subsequent strings are passed by the process
//          that called the StartService function to start the service.
//
//----------------------------------------------------------------------

static VOID WINAPI SvcMain ( DWORD argc, LPTSTR *argv )
{
    hServiceStatus = RegisterServiceCtrlHandler( argv[0], SvcCtrlHandler );
    if( !hServiceStatus ) {
        SvcReport( EVENTLOG_ERROR_TYPE, "cannot register service handle" );
        return;
    }

    // These SERVICE_STATUS members remain as set here
    //
    ServiceStatus.dwServiceType = SERVICE_WIN32_OWN_PROCESS;
    ServiceStatus.dwServiceSpecificExitCode = 0;

    SvcSetStatus( SERVICE_START_PENDING, 3000 );

    StartAndRunTclService( argv[0] );

    SvcSetStatus( SERVICE_STOPPED, 0 );
}

//----------------------------------------------------------------------
//
// SvcCtrlHandler:
//   Called by SCM whenever a control code is sent to the service
//   using the ControlService function.
//
// Parameters:
//   ctrlCode - control code
//
//----------------------------------------------------------------------

static VOID WINAPI SvcCtrlHandler( DWORD ctrlCode )
{
    switch( ctrlCode ) {
    case SERVICE_CONTROL_SHUTDOWN:
    case SERVICE_CONTROL_STOP:
        SvcSetStatus( SERVICE_STOP_PENDING, 5000 );
        TclService_NotifyStopRequested();
        break;

    case SERVICE_CONTROL_INTERROGATE:
        SvcSetStatus( ServiceStatus.dwCurrentState, 0 );
        break;

    default:
        break;
    }
}

//----------------------------------------------------------------------
//
// SvcSetStatus:
//   Sets the current service status and reports it to the SCM.
//
// Parameters:
//   dwCurrentState  - The current state (see SERVICE_STATUS)
//   dwWaitHint      - Estimated time for pending operation, in milliseconds
//
//----------------------------------------------------------------------

VOID SvcSetStatus( DWORD dwCurrentState, DWORD dwWaitHint )
{
    ServiceStatus.dwCurrentState  = dwCurrentState;
    ServiceStatus.dwWaitHint      = dwWaitHint;
    ServiceStatus.dwWin32ExitCode = NO_ERROR;

    if ( dwCurrentState == SERVICE_START_PENDING || dwCurrentState == SERVICE_STOP_PENDING ) {
        ServiceStatus.dwControlsAccepted = 0;
    } else {
        ServiceStatus.dwControlsAccepted = SERVICE_ACCEPT_STOP | SERVICE_ACCEPT_SHUTDOWN;
    }

    if ( dwCurrentState == SERVICE_RUNNING || dwCurrentState == SERVICE_STOPPED ) {
        ServiceStatus.dwCheckPoint = 0;
    } else {
        ServiceStatus.dwCheckPoint++;
    }

    SetServiceStatus( hServiceStatus, &ServiceStatus );
}

//----------------------------------------------------------------------
//
// SvcReport:
//   Logs messages to the event log
//
// Parameters:
//   type    - one of the EVENTLOG_*_TYPE constants
//   message - text to be added to the log
//
//----------------------------------------------------------------------

VOID SvcReport( DWORD type, LPTSTR message, ... )
{
    HANDLE hEventSource = RegisterEventSource( NULL, "TCLSvc" );
    if( hEventSource != NULL ) {
        va_list msgArgs;
        char txtbuf[BUFSIZ];
        LPCTSTR args[1];
        DWORD argc = 0;
        va_start( msgArgs, message );
        vsprintf( txtbuf, message, msgArgs );

        args[argc++] = txtbuf;

        DWORD eventId =
            type == EVENTLOG_ERROR_TYPE   ? SVC_ERROR :
            type == EVENTLOG_WARNING_TYPE ? SVC_WARN  : SVC_INFO ;

        ReportEvent( hEventSource   // event log handle
                   , type           // event type
                   , 0              // event category
                   , eventId        // event identifier
                   , NULL           // no security identifier
                   , argc           // size of args array
                   , 0              // no binary data
                   , args           // array of strings
                   , NULL );        // no binary data

        DeregisterEventSource( hEventSource );
        va_end( msgArgs );
    }
}
