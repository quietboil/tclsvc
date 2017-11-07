###########################################################################
#
# Windows service demo - a simple HTTP server
#
###########################################################################

namespace eval httpd {

    package require uri

    variable statusCodes [dict create {*}{
        OK                  {200 OK}
        NOT_MODIFIED        {304 {Not Modified}}
        BAD_REQUEST         {400 {Bad Request}}
        NOT_FOUND           {404 {Not Found}}
        NOT_ALLOWED         {405 {Method Not Allowed}}
        NOT_ACCEPTABLE      {406 {Not Acceptable}}
        LENGTH_REQUIRED     {411 {Length Required}}
        SERVER_ERROR        {500 {Internal Server Error}}
        NOT_IMPLEMENTED     {501 {Not Implemented}}
        SERVICE_UNAVAILABLE {503 {Service Unavailable}}
    }]

    ###########################################################################
    #
    # accept
    #
    #   Accepts incoming connection.
    #
    # Arguments:
    #   _sock - channel that may be used to communicate with the client
    #   _ip   - the address, in network address notation, of the client's host
    #   _port - the client's port number
    #
    ###########################################################################
    proc accept { _sock _ip _port } {
        if { [catch {
            chan configure $_sock -blocking no -encoding utf-8 -buffering line
            chan event $_sock readable [list [namespace which -command io] readRequest $_sock]
        }] } {
            catch { close $_sock }
        }
    }

    ###########################################################################
    #
    # io
    #
    #   Wrapper for channel event implementations that catches errors
    #
    # Arguments:
    #   _cmd  - event implementation
    #   _sock - client socket
    #   args  - event implementation arguments
    #
    ###########################################################################
    proc io { _cmd _sock args } {
        if { [catch {
            chan event $_sock readable {}
            chan event $_sock writable {}
            $_cmd $_sock {*}$args
        } res opt] } {
            sendErrorResponse $_sock [dict get $opt -errorcode] $res
        } elseif { [chan names $_sock] != {} && [eof $_sock] } {
            catch { close $_sock }
        }
    }

    ###########################################################################
    #
    # readRequest
    #
    #   Reads and parses HTTP request into an internal data structure
    #
    # Arguments:
    #   _sock    - channel to communicate with the client
    #   _request - content of the HTTP request as it is being parsed
    #
    ###########################################################################
    proc readRequest { _sock {_request {}} } {
        while { [set len [gets $_sock line]] > 0 } {
            if { ![dict exists $_request method] } {
                # parse request line
                lassign [split $line] method url protocol
                if { $method == {} || $url == {} || [string range $protocol 0 4] ne {HTTP/} } {
                    return -code error -errorcode BAD_REQUEST {}
                }
                dict set _request method $method
                dict set _request uri [uri::split $url] ;# scheme, user, pwd, host, port, path, query, fragment

            } elseif { [regexp {^([^:]+?):\s+(.+?)\s*$} $line >> name data] } {
                dict set _request headers $name $data
            }
        }

        if { $len < 0 } {
            if { [chan blocked $_sock] } {
                chan event $_sock readable [list [namespace which -command io] readRequest $_sock $_request]
            }
        } else {
            if { [dict get $_request method] eq {POST} } {
                readContent $_sock $_request
            } else {
                chan event $_sock writable [list [namespace which -command io] generateResponse $_sock $_request]
            }
        }
    }

    ###########################################################################
    #
    # readContent
    #
    #   Reads POST-ed request content
    #
    # Arguments:
    #   _sock    - channel to communicate with the client
    #   _request - parsed HTTP request
    #
    ###########################################################################
    proc readContent { _sock _request } {
        set transferEncoding [expr { [dict exists $_request headers Transfer-Encoding] ? [dict get $_request headers Transfer-Encoding] : {} }]
        if { $transferEncoding in {{} {identity}} } {
            if { ![dict exists $_request headers Content-Length] } {
                return -code error -errorcode LENGTH_REQUIRED {}
            }
            chan event $_sock readable [list [namespace which -command io] readContentData $_sock $_request [dict get $_request headers Content-Length]]

        } elseif { $transferEncoding eq {chunked} } {
            chan event $_sock readable [list [namespace which -command io] readChunkSize $_sock $_request]

        } else {
            return -code error -errorcode NOT_ACCEPTABLE "Unsupported Transfer-Encoding: $transferEncoding"
        }
    }

    ###########################################################################
    #
    # readContentData
    #
    #   Reads request content
    #
    # Arguments:
    #   _sock    - channel to communicate with the client
    #   _request - parsed HTTP request
    #   _length  - remaining number of the content octets to read
    #   _content - request content accumulated so far
    #
    ###########################################################################
    proc readContentData { _sock _request _length {_content {}} } {
        chan configure $_sock -translation binary -buffering full

        set data [chan read $_sock $_length]
        append _content $data
        incr _length -[string length $data]

        if { $_length > 0 } {
            chan event $_sock readable [list [namespace which -command io] readContentData $_sock $_request $_length $_content]
        } else {
            chan event $_sock writable [list [namespace which -command io] generateResponse $_sock $_request $_content]
        }
    }

    ###########################################################################
    #
    # readChunkSize
    #
    #   Reads "header" line of the chunk
    #
    # Arguments:
    #   _sock    - channel to communicate with the client
    #   _request - parsed HTTP request
    #   _content - request content accumulated so far
    #
    ###########################################################################
    proc readChunkSize { _sock _request {_content {}} } {
        chan configure $_sock -translation auto -encoding utf-8 -buffering line

        while { [set len [gets $_sock line]] >= 0 } {
            if { $len > 0 } {
                if { [scan $line %x size] == 1 && $size > 0 } {
                    chan event $_sock readable [list [namespace which -command io] readChunkData $_sock $_request $size $_content]
                } else {
                    chan event $_sock writable [list [namespace which -command io] generateResponse $_sock $_request $_content]
                }
                break
            }
            # else $len == 0 from CRLF that terminated the preceeding chunk
        }
    }

    ###########################################################################
    #
    # readChunkData
    #
    #   Reads chunk data and appends it to request content
    #
    # Arguments:
    #   _sock    - channel to communicate with the client
    #   _request - parsed HTTP request
    #   _length  - remaining number of the chunk octets to read
    #   _content - request content accumulated so far
    #
    ###########################################################################
    proc readChunkData { _sock _request _length _content } {
        chan configure $_sock -translation binary -buffering full

        set data [chan read $_sock $_length]
        append _content $data
        incr _length -[string length $data]

        if { $_length > 0 } {
            chan event $_sock readable [list [namespace which -command io] readChunkData $_sock $_request $_length $_content]
        } else {
            chan event $_sock readable [list [namespace which -command io] readChunkSize $_sock $_request $_content]
        }
    }

    ###########################################################################
    #
    # generateResponse
    #
    #   Inititates response generation
    #
    # Arguments:
    #   _sock    - channel to communicate with the client
    #   _request - parsed HTTP request
    #   _content - request content
    #
    ###########################################################################
    proc generateResponse { _sock _request {_content {}} } {
        chan configure $_sock -translation auto -encoding utf-8 -buffering full

        # Look up the request handler first. If we cannot handle the request,
        # then we won't waste time on handling the request content
        set handler [::docs::getHandler $_request]

        if { $_content != {} && [dict exists $_request headers Content-Type] } {
            set contentType [dict get $_request headers Content-Type]
            if { [regexp -nocase {charset=([^;[:space:]]+)} $contentType >> charset] } {
                set charset  [string tolower $charset]
                set _content [encoding convertfrom $charset $_content]
            }
        }

        chan event $_sock writable [list {*}$handler $_sock $_request $_content]
    }

    ###########################################################################
    #
    # sendErrorResponse
    #
    #   Sends an error response
    #
    # Arguments:
    #   _sock - channel to communicate with the client
    #   _code - HTTP status code
    #   _text - text of the error response
    #
    ###########################################################################
    proc sendErrorResponse { _sock _code _text } {
        variable statusCodes
        set respCode [expr { [dict exists $statusCodes $_code] ? $_code : {SERVER_ERROR} }]

        catch { respond $_sock $respCode $_text }
        if { [chan names $_sock] != {} } {
            catch { close $_sock }
        }
    }

    ###########################################################################
    #
    # respond
    #
    #   Sends responds to the client
    #
    # Arguments:
    #   _sock - channel to communicate with the client
    #   _code - HTTP status code
    #   _body - content
    #   _head - optional list of additional headers
    #
    ###########################################################################
    proc respond { _sock _code _body {_head {}} } {
        variable statusCodes
        lassign [dict get $statusCodes $_code] code reason
        puts $_sock "HTTP/1.1 $code $reason"
        puts $_sock {Connection: close}
            # We do not support persistent connections as they would demand support
            # for pipelining and the machinery for that adds a lot of complexity
        switch $code {
            405 { puts $_sock {Allow: GET, POST} }
            406 { puts $_sock {Accept-Encoding: identity} }
        }
        set contentTypePresent 0
        foreach {name value} $_head {
            puts -nonewline $_sock $name
            puts -nonewline $_sock {: }
            puts $_sock $value
            set contentTypePresent [expr { $contentTypePresent || $name eq {Content-Type} }]
        }
        if { !$contentTypePresent } {
            puts $_sock {Content-Type: text/plain; charset=utf-8}
        }
        puts -nonewline $_sock {Content-Length: }
        puts $_sock [string bytelength $_body]
        chan configure $_sock -translation binary
        puts $_sock {}
        puts -nonewline $_sock $_body
        chan configure $_sock -translation auto -encoding utf-8
        flush $_sock
        close $_sock
        return
    }

    ###########################################################################
    #
    # urldecode
    #
    #   splitQuery helper proc
    #
    # Arguments:
    #   _str - urlencoded string
    #
    # Returns:
    #   decoded string
    #
    ###########################################################################
    proc urldecode { _str } {
        set res [string map [list "+" " " "\\" "\\\\"] $_str]
        set res [regsub -all -- {%([[:xdigit:]]{2})} $res {\\u00\1}] ;# do not use \x, it does not do what one might think it does :-)
        return [subst -nocommands -novariables $res]
    }

    ###########################################################################
    #
    # splitQuery
    #
    #   Splits URI query into a parameter name-value list suitable for array set
    #   or to be used as a dictionary
    #
    # Arguments:
    #   _query - request query
    #
    # Returns:
    #   key value list
    #
    ###########################################################################
    proc splitQuery { _query } {
        # decode entire query first
        set res [list]
        foreach param [split [urldecode $_query] {&}] {
            lappend res {*}[split $param {=}]
        }
        return $res
    }
}

namespace eval docs {

    ###########################################################################
    #
    # getHandler
    #
    #   Determines how to handle incoming request
    #
    # Arguments:
    #   _request - parsed HTTP request
    #
    # Returns:
    #   list {handler_command ?opt_arg ...?}
    #
    ###########################################################################
    proc getHandler { _request } {
        global config

        set reqPath [dict get $_request uri path]

        set path [file join [dict get $config docRoot] $reqPath]
        if { [file isdirectory $path] } {
            set path [file join $path [dict get $config indexFile]]
        }
        if { [file isfile $path] && [file readable $path] } {
            if {
                [dict exists $_request headers If-Modified-Since] &&
                ![catch {clock scan [dict get $_request headers If-Modified-Since] -gmt 1 -format {%a, %d %b %Y %H:%M:%S GMT}} modTime] &&
                [file mtime $path] <= $modTime
            } {
                return [list [namespace which -command respondNotModified] $path]
            } else {
                return [list [namespace which -command serveFile] $path]
            }
        }
        return -code error -errorcode NOT_FOUND "/$reqPath does not exist"
    }

    ###########################################################################
    #
    # respondNotModified
    #
    #   Sends 304 response
    #
    # Arguments:
    #   _path - name of the file which content was requested
    #   _sock - channel to communicate with the client
    #   args  - a placeholder for parsed request and request content
    #
    ###########################################################################
    proc respondNotModified { _path _sock args } {
        if { [catch {
            chan event $_sock writable {}
            ::httpd::respond $_sock NOT_MODIFIED {} [list Last-Modified [clock format [file mtime $_path] -gmt 1 -format {%a, %d %b %Y %H:%M:%S GMT}]]
        } res opt] } {
            ::httpd::sendErrorResponse $_sock [dict get $opt -errorcode] $res
        }
    }

    ###########################################################################
    #
    # serveFile
    #
    #   Returns content of the specified file.
    #
    # Arguments:
    #   _path - name of the file which content should be returned
    #   _sock - channel to communicate with the client
    #   args  - a placeholder for parsed request and request content
    #
    ###########################################################################
    proc serveFile { _path _sock args } {
        if { [catch {
            chan event $_sock writable {}

            # default socket buffer is large enough to put headers without blocking
            puts $_sock "HTTP/1.1 200 OK"
            puts $_sock {Connection: close}
            switch [file extension $_path] {
                .txt    { puts $_sock {Content-Type: text/plain; charset=utf-8} }
                .html   { puts $_sock {Content-Type: text/html; charset=utf-8} }
                .xml    { puts $_sock {Content-Type: text/xml; charset=utf-8} }
                .jpg    { puts $_sock {Content-Type: image/jpeg} }
                .png    { puts $_sock {Content-Type: image/png} }
                .gif    { puts $_sock {Content-Type: image/gif} }
                default { puts $_sock {Content-Type: application/octet-stream} }
            }
            puts $_sock [format {Content-Length: %d} [file size $_path]]
            puts $_sock [format {Last-Modified: %s} [clock format [file mtime $_path] -gmt 1 -format {%a, %d %b %Y %H:%M:%S GMT}]]
            puts $_sock {}

            # Assuming that text - .html, .xml and .txt files (thus far) - are already UTF-8 encoded
            chan configure $_sock -translation binary -encoding binary

            set ifc [open $_path r]
            chan configure $ifc -translation binary -encoding binary -buffering full -buffersize 65536
            chan copy $ifc $_sock -command [list [namespace which -command fileIsServed] $ifc $_sock]

        } res opt] } {
            catch { close $_sock }
        }
    }

    ###########################################################################
    #
    # fileIsServed
    #
    #   Callback that chan copy calls when the file has been sent.
    #
    # Arguments:
    #   _file - input file channel
    #   _sock - channel to communicate with the client
    #   _size - number of bytes written
    #   _errs - optional error string if error has occured
    #
    ###########################################################################
    proc fileIsServed { _file _sock _size {_errs {}} } {
        catch { close $_file }
        catch { flush $_sock; close $_sock }
    }
}

###########################################################################
#
# shutdown
#
#   This procedure is called by the NT service when it receives STOP or
#   SHUTDOWN signal. It is expected that it will ensure that all event
#   sources - non-blocking channels, timers, etc - are closed eventually
#   to allow event loop to terminate.
#
###########################################################################

proc shutdown {} {
    # stop accepting new requests
    catch { close $::httpd::sock }
}

###########################################################################
#
# Service configration
#
###########################################################################

if { [info commands svclog] == {} } {
    # then this script is not running under tclsvc
    proc svclog { level msg args } {
        puts -nonewline stderr "[string toupper $level]: "
        puts [format $msg {*}$args]
    }
} else {
    proc bgerror msg {
        svclog error {bgerror: %s} $msg
    }
}

if { [llength [chan names std*]] == 0 } {
    # open pretend std channels to prevent TCL's misreporting
    # of the first 3 sockets as std channels
    open nul r
    open nul w
    open nul w
}

#
# Load/create service configuration
#
if { $argc > 0 && [file readable [lindex $argv 0]]} {
    set confFile [open [lindex $argv 0] r]
    set config [dict create {*}[read $confFile]]
    close $confFile
    unset confFile
} else {
    set config [dict create]
}
#
# Set defaults for the required configuration keys if they are not provided
#
foreach { key val } [list \
    httpPort  8080              \
    docRoot   [file join [file dir [info script]] docs] \
    indexFile index.html        \
] {
    if { ![dict exists $config $key] } {
        dict set config $key $val
    }
}

#
# Start HTTP server
#
set ::httpd::sock [socket -server ::httpd::accept [dict get $config httpPort]]

###########################################################################
#
# Done. Service is running now.
#
###########################################################################
