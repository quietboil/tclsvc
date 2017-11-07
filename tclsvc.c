#include <windows.h>
#include <tcl.h>

VOID SvcReport ( DWORD, LPTSTR, ... );
VOID SvcSetStatus ( DWORD, DWORD );

static BOOL stopRequested = FALSE;
static BOOL stopEventSent = FALSE;
static BOOL dispatchingEvents = TRUE;
static Tcl_ThreadId tclMainThreadId = NULL;

typedef struct {
    Tcl_Event     header;
    Tcl_Interp *  interp;
} SvcCtrlEvent;

//----------------------------------------------------------------------
//
// TclService_NotifyStopRequested
//
//   This function is invoked by SvcCtrlHandler when it receives STOP or
//   SHUTDOWN control code.
//
//----------------------------------------------------------------------

void TclService_NotifyStopRequested ()
{
    stopRequested = TRUE;
    if ( tclMainThreadId != NULL ) {
        Tcl_ThreadAlert( tclMainThreadId );
    } else {
        dispatchingEvents = FALSE;
    }
}

//----------------------------------------------------------------------
//
// SignalShutdown
//
//   This function is invoked by Tcl_DoOneEvent when the application
//   becomes idle.
//
//----------------------------------------------------------------------

static void SignalShutdown ( ClientData clientData )
{
    dispatchingEvents = FALSE;
}

//----------------------------------------------------------------------
//
// CtrlEventSetup
//
//   This function is invoked before Tcl_DoOneEvent blocks waiting for an
//   event.
//
//----------------------------------------------------------------------

static void CtrlEventSetup ( ClientData clientData, int flags )
{
    if ( stopRequested && !stopEventSent ) {
        Tcl_Time blockTime = { 0, 0 };
        Tcl_SetMaxBlockTime( &blockTime );
    }
}

//----------------------------------------------------------------------
//
// CtrlEventProc
//
//   This function is invoked by Tcl_ServiceEvent when a service event
//   reaches the front of the event queue.
//
// Results:
//   Returns 1 if the event was handled, meaning it should be removed
//   from the queue.
//
//----------------------------------------------------------------------

static int CtrlEventProc ( Tcl_Event * tclEvent, int flags )
{
    SvcCtrlEvent * ctrlEvent = (SvcCtrlEvent *) tclEvent;
    if ( Tcl_Eval( ctrlEvent->interp, "shutdown" ) != TCL_OK ) {
        dispatchingEvents = FALSE;
    } else {
        // schedule shutdown after all events have been processed
        Tcl_DoWhenIdle( SignalShutdown, NULL );
    }
    return 1;
}

//----------------------------------------------------------------------
//
// CtrlEventCheck
//
//   This function is invoked by Tcl_DoOneEvent to check the event source
//   for events.
//
//----------------------------------------------------------------------

static void CtrlEventCheck ( ClientData clientData, int flags )
{
    if ( stopRequested && !stopEventSent ) {
        SvcCtrlEvent * ctrlEvent = (SvcCtrlEvent *) ckalloc( sizeof(SvcCtrlEvent) );
        ctrlEvent->header.proc = CtrlEventProc;
        ctrlEvent->interp = (Tcl_Interp *) clientData;
        Tcl_QueueEvent( (Tcl_Event *) ctrlEvent, TCL_QUEUE_TAIL );
        stopEventSent = TRUE;
    }
}

//----------------------------------------------------------------------
//
// SvcVwaitCmd:
//   Implements custom "vwait" command, which returns an error as
//   cannot allow nested event loops.
//
//----------------------------------------------------------------------

static int SvcVwaitCmd ( ClientData clientData, Tcl_Interp * interp, int objc, Tcl_Obj * const objv[] )
{
    Tcl_ResetResult(interp);
    Tcl_AppendResult(interp, "vwait cannot be used by the service script", NULL);
    return TCL_ERROR;
}

//----------------------------------------------------------------------
//
// SvcVwaitCmd:
//   Implements custom "update" command, which returns an error as
//   cannot allow nested event loops.
//
//----------------------------------------------------------------------

static int SvcUpdateCmd ( ClientData clientData, Tcl_Interp * interp, int objc, Tcl_Obj * const objv[] )
{
    Tcl_ResetResult(interp);
    Tcl_AppendResult(interp, "update cannot be used by the service script", NULL);
    return TCL_ERROR;
}

//----------------------------------------------------------------------
//
// SvcExitCmd:
//   Implements custom "exit" command
//
//----------------------------------------------------------------------

static int SvcExitCmd ( ClientData clientData, Tcl_Interp * interp, int objc, Tcl_Obj * const objv[] )
{
    if ( Tcl_Eval( interp, "shutdown" ) != TCL_OK ) {
        dispatchingEvents = FALSE;
    } else {
        // schedule shutdown after all events have been processed
        Tcl_DoWhenIdle( SignalShutdown, NULL );
    }
    return TCL_OK;
}

//----------------------------------------------------------------------
//
// SvcLogCmd:
//   Implements "svclog" command
//
//----------------------------------------------------------------------

static int SvcLogCmd ( ClientData clientData, Tcl_Interp * interp, int objc, Tcl_Obj * const objv[] )
{
    if ( objc < 3 ) {
        Tcl_WrongNumArgs( interp, 1, objv, "level message ?args...?" );
        return TCL_ERROR;
    }

    static char const *  levels[] = { "info", "warning", "error", NULL };
    static DWORD const logTypes[] = { EVENTLOG_INFORMATION_TYPE, EVENTLOG_WARNING_TYPE, EVENTLOG_ERROR_TYPE };
    int index;

    if ( Tcl_GetIndexFromObj( interp, objv[1], levels, "level", 0, &index ) != TCL_OK ) {
        return TCL_ERROR;
    }

    char * format  = Tcl_GetString( objv[2] );
    char * message = Tcl_GetString(
        Tcl_Format( interp, format, objc - 3, objv + 3 )
    );
    SvcReport( logTypes[index], message );

    return TCL_OK;
}


//----------------------------------------------------------------------
//
// InitTclInterp
//
//   Initializes TCL interpreter
//
// Parameters:
//      interp - newly created TCL interpreter
//
// Returns:
//   Tcl_Init result
//
//----------------------------------------------------------------------

static int InitTclInterp ( Tcl_Interp * interp )
{
    Tcl_SetVar( interp, "argv0", __argv[1], TCL_GLOBAL_ONLY );

    char *args = Tcl_Merge( __argc - 2, (char const * const *) __argv + 2);
    Tcl_SetVar( interp, "argv", args, TCL_GLOBAL_ONLY );
    Tcl_Free(args);

    char txtbuf[12];
    _itoa( __argc - 2, txtbuf, 10 );
    Tcl_SetVar( interp, "argc", txtbuf, TCL_GLOBAL_ONLY );

    // Tcl_Eval( interp, "set tcl_library [file join [file dir [file dir [info nameofexecutable]]] lib tcl[info tclversion]]" );

    return Tcl_Init( interp );
}

//----------------------------------------------------------------------
//
// ReportTclError
//
//   Helper function to report TCL errors including error info
//   Accepts sprintf style parameters
//
//----------------------------------------------------------------------

static void ReportTclError ( Tcl_Interp * interp, char const * message, ... )
{
    va_list msgArgs;
    va_start( msgArgs, message );
    char txtbuf[BUFSIZ];
    vsprintf( txtbuf, message, msgArgs );

    char const * errorInfo = Tcl_GetVar( interp, "errorInfo", TCL_GLOBAL_ONLY | TCL_LEAVE_ERR_MSG );
    if ( errorInfo == NULL ) {
        errorInfo = Tcl_GetStringResult( interp );
    }
    SvcReport( EVENTLOG_ERROR_TYPE, "%s: %s", txtbuf, errorInfo );
}

//----------------------------------------------------------------------
//
// StartAndRunTclService
//
//   Starts TCL service and runs TCL event loop
//
// Parameters:
//   svcName - the name of the service
//
//----------------------------------------------------------------------

void StartAndRunTclService ( char const * svcName )
{
    if ( __argc < 2 ) {
        SvcReport( EVENTLOG_ERROR_TYPE, "TCL script for this service is not configured. %s will stop now.", svcName );
        return;
    }
    // SetEnvironmentVariable( "TCL_LIBRARY", NULL );

    Tcl_FindExecutable( __argv[0] );
    Tcl_Interp * interp = Tcl_CreateInterp();
    if ( InitTclInterp( interp ) != TCL_OK ) {
        SvcReport( EVENTLOG_ERROR_TYPE, "Unable to initialize TCL interpreter" );
        return;
    }

    Tcl_SetVar( interp, "tcl_service", svcName, TCL_GLOBAL_ONLY );
    Tcl_CreateObjCommand( interp, "exit", SvcExitCmd, NULL, NULL);
    Tcl_CreateObjCommand( interp, "vwait", SvcVwaitCmd, NULL, NULL);
    Tcl_CreateObjCommand( interp, "update", SvcUpdateCmd, NULL, NULL);
    Tcl_CreateObjCommand( interp, "svclog", SvcLogCmd, NULL, NULL);
    Tcl_CreateEventSource( CtrlEventSetup, CtrlEventCheck, interp );

    tclMainThreadId = Tcl_GetCurrentThread();

    if ( Tcl_EvalFile( interp, __argv[1] ) != TCL_OK ) {
        ReportTclError( interp, "Unable to execute service script %s", __argv[1] );
        Tcl_Finalize();
        return;
    }

    SvcReport( EVENTLOG_INFORMATION_TYPE, "%s is running", svcName );

    SvcSetStatus( SERVICE_RUNNING, 0 );
    int eventMask = TCL_ALL_EVENTS;
    while ( dispatchingEvents ) {
        if ( Tcl_DoOneEvent( eventMask ) == 0 ) {
            break;
        }
    }
    SvcSetStatus( SERVICE_STOP_PENDING, 3000 );
    Tcl_Finalize();
    SvcReport( EVENTLOG_INFORMATION_TYPE, "%s stopped", svcName );
}
