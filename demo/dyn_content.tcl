###########################################################################
#
# Demo of dynamic content for the simple HTTP/1.1 server
#
###########################################################################

namespace eval ::docs {

    ###########################################################################
    #
    # time
    #
    #   Returns current time in plan text
    #
    # Arguments:
    #   _sock    - channel to communicate with the client
    #   _request - dict of the parsed HTTP request
    #
    ###########################################################################
    proc time { _sock _request } {
        ::httpd::respond $_sock OK -content [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
    }

    ###########################################################################
    #
    # hello
    #
    #   Returns HTML formatted greeting
    #
    # Arguments:
    #   _sock    - channel to communicate with the client
    #   _request - dict of the parsed HTTP request
    #
    ###########################################################################
    proc hello { _sock _request } {
        set path [dict get $_request uri path]
        # The path above is, using servlets parlance, a "path info"
        if { $path == "" } {
            set path "World"
        }
        set time [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]

        ::httpd::respond $_sock OK -content [format $::docs::hello_response_template $path $time] -headers {Content-Type text/html}
    }

    set hello_response_template {<!doctype html>
<html lang="en">
<head>
  <title>Hello</title>
</head>
<body>
  <h1>Greetings %1$s</h1>
  <p>Time now is %2$s.</p>
</body>
</html>}

}

# Register dynamic content handlers
#                               _ context path
#                              /    _ handling proc
#                             /    /
dict set ::httpd::config path time ::docs::time

dict set ::httpd::config path hello ::docs::hello
#                             ~~~~~ - this will handle only http://host:port/hello requests (URI path is "")
dict set ::httpd::config path hello/* ::docs::hello
#                             ~~~~~~~ - this will handle "hello" requests that have path info like http://host:port/hello/...
