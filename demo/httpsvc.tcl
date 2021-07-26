###########################################################################
#
# Windows service demo - a simple HTTP/1.1 server
#
###########################################################################

namespace eval httpd {

    package require uri

    array set statusCodes {
        OK                  {200 OK}
        NOT_MODIFIED        {304 {Not Modified}}
        BAD_REQUEST         {400 {Bad Request}}
        NOT_FOUND           {404 {Not Found}}
        METHOD_NOT_ALLOWED  {405 {Method Not Allowed}}
        NOT_ACCEPTABLE      {406 {Not Acceptable}}
        LENGTH_REQUIRED     {411 {Length Required}}
        SERVER_ERROR        {500 {Internal Server Error}}
    }

    array set knownContentTypes {
        .323         text/h323
        .accdb       application/msaccess
        .accde       application/msaccess
        .accdt       application/msaccess
        .acx         application/internet-property-stream
        .ai          application/postscript
        .aif         audio/x-aiff
        .aifc        audio/aiff
        .aiff        audio/aiff
        .application application/x-ms-application
        .art         image/x-jg
        .asf         video/x-ms-asf
        .asm         text/plain
        .asr         video/x-ms-asf
        .asx         video/x-ms-asf
        .atom        application/atom+xml
        .au          audio/basic
        .avi         video/x-msvideo
        .axs         application/olescript
        .bas         text/plain
        .bcpio       application/x-bcpio
        .bmp         image/bmp
        .c           text/plain
        .calx        application/vnd.ms-office.calx
        .cat         application/vnd.ms-pki.seccat
        .cdf         application/x-cdf
        .class       application/x-java-applet
        .clp         application/x-msclip
        .cmx         image/x-cmx
        .cnf         text/plain
        .cod         image/cis-cod
        .cpio        application/x-cpio
        .cpp         text/plain
        .crd         application/x-mscardfile
        .crl         application/pkix-crl
        .crt         application/x-x509-ca-cert
        .csh         application/x-csh
        .css         text/css
        .dcr         application/x-director
        .der         application/x-x509-ca-cert
        .dib         image/bmp
        .dir         application/x-director
        .disco       text/xml
        .dll         application/x-msdownload
        .dll.config  text/xml
        .dlm         text/dlm
        .doc         application/msword
        .docm        application/vnd.ms-word.document.macroEnabled.12
        .docx        application/vnd.openxmlformats-officedocument.wordprocessingml.document
        .dot         application/msword
        .dotm        application/vnd.ms-word.template.macroEnabled.12
        .dotx        application/vnd.openxmlformats-officedocument.wordprocessingml.template
        .dtd         text/xml
        .dvi         application/x-dvi
        .dwf         drawing/x-dwf
        .dxr         application/x-director
        .eml         message/rfc822
        .eps         application/postscript
        .etx         text/x-setext
        .evy         application/envoy
        .exe.config  text/xml
        .fdf         application/vnd.fdf
        .fif         application/fractals
        .flr         x-world/x-vrml
        .flv         video/x-flv
        .gif         image/gif
        .gtar        application/x-gtar
        .gz          application/x-gzip
        .h           text/plain
        .hdf         application/x-hdf
        .hdml        text/x-hdml
        .hhc         application/x-oleobject
        .hlp         application/winhlp
        .hqx         application/mac-binhex40
        .hta         application/hta
        .htc         text/x-component
        .htm         text/html
        .html        text/html
        .htt         text/webviewhtml
        .hxt         text/html
        .ico         image/x-icon
        .ief         image/ief
        .iii         application/x-iphone
        .ins         application/x-internet-signup
        .isp         application/x-internet-signup
        .ivf         video/x-ivf
        .jar         application/java-archive
        .jck         application/liquidmotion
        .jcz         application/liquidmotion
        .jfif        image/pjpeg
        .jpe         image/jpeg
        .jpeg        image/jpeg
        .jpg         image/jpeg
        .js          application/x-javascript
        .jsx         text/jscript
        .latex       application/x-latex
        .lit         application/x-ms-reader
        .lsf         video/x-la-asf
        .lsx         video/x-la-asf
        .m13         application/x-msmediaview
        .m14         application/x-msmediaview
        .m1v         video/mpeg
        .m3u         audio/x-mpegurl
        .man         application/x-troff-man
        .manifest    application/x-ms-manifest
        .map         text/plain
        .mdb         application/x-msaccess
        .me          application/x-troff-me
        .mht         message/rfc822
        .mhtml       message/rfc822
        .mid         audio/mid
        .midi        audio/mid
        .mmf         application/x-smaf
        .mno         text/xml
        .mny         application/x-msmoney
        .mov         video/quicktime
        .movie       video/x-sgi-movie
        .mp2         video/mpeg
        .mp3         audio/mpeg
        .mpa         video/mpeg
        .mpe         video/mpeg
        .mpeg        video/mpeg
        .mpg         video/mpeg
        .mpp         application/vnd.ms-project
        .mpv2        video/mpeg
        .ms          application/x-troff-ms
        .mvb         application/x-msmediaview
        .mvc         application/x-miva-compiled
        .nc          application/x-netcdf
        .nsc         video/x-ms-asf
        .nws         message/rfc822
        .oda         application/oda
        .odc         text/x-ms-odc
        .ods         application/oleobject
        .one         application/onenote
        .onea        application/onenote
        .onetoc      application/onenote
        .onetoc2     application/onenote
        .onetmp      application/onenote
        .onepkg      application/onenote
        .osdx        application/opensearchdescription+xml
        .p10         application/pkcs10
        .p12         application/x-pkcs12
        .p7b         application/x-pkcs7-certificates
        .p7c         application/pkcs7-mime
        .p7m         application/pkcs7-mime
        .p7r         application/x-pkcs7-certreqresp
        .p7s         application/pkcs7-signature
        .pbm         image/x-portable-bitmap
        .pdf         application/pdf
        .pfx         application/x-pkcs12
        .pgm         image/x-portable-graymap
        .pko         application/vnd.ms-pki.pko
        .pma         application/x-perfmon
        .pmc         application/x-perfmon
        .pml         application/x-perfmon
        .pmr         application/x-perfmon
        .pmw         application/x-perfmon
        .png         image/png
        .pnm         image/x-portable-anymap
        .pnz         image/png
        .pot         application/vnd.ms-powerpoint
        .potm        application/vnd.ms-powerpoint.template.macroEnabled.12
        .potx        application/vnd.openxmlformats-officedocument.presentationml.template
        .ppam        application/vnd.ms-powerpoint.addin.macroEnabled.12
        .ppm         image/x-portable-pixmap
        .pps         application/vnd.ms-powerpoint
        .ppsm        application/vnd.ms-powerpoint.slideshow.macroEnabled.12
        .ppsx        application/vnd.openxmlformats-officedocument.presentationml.slideshow
        .ppt         application/vnd.ms-powerpoint
        .pptm        application/vnd.ms-powerpoint.presentation.macroEnabled.12
        .pptx        application/vnd.openxmlformats-officedocument.presentationml.presentation
        .prf         application/pics-rules
        .ps          application/postscript
        .pub         application/x-mspublisher
        .qt          video/quicktime
        .qtl         application/x-quicktimeplayer
        .ra          audio/x-pn-realaudio
        .ram         audio/x-pn-realaudio
        .ras         image/x-cmu-raster
        .rf          image/vnd.rn-realflash
        .rgb         image/x-rgb
        .rm          application/vnd.rn-realmedia
        .rmi         audio/mid
        .roff        application/x-troff
        .rpm         audio/x-pn-realaudio-plugin
        .rtf         application/rtf
        .rtx         text/richtext
        .scd         application/x-msschedule
        .sct         text/scriptlet
        .setpay      application/set-payment-initiation
        .setreg      application/set-registration-initiation
        .sgml        text/sgml
        .sh          application/x-sh
        .shar        application/x-shar
        .sit         application/x-stuffit
        .sldm        application/vnd.ms-powerpoint.slide.macroEnabled.12
        .sldx        application/vnd.openxmlformats-officedocument.presentationml.slide
        .smd         audio/x-smd
        .smx         audio/x-smd
        .smz         audio/x-smd
        .snd         audio/basic
        .spc         application/x-pkcs7-certificates
        .spl         application/futuresplash
        .src         application/x-wais-source
        .ssm         application/streamingmedia
        .sst         application/vnd.ms-pki.certstore
        .stl         application/vnd.ms-pki.stl
        .sv4cpio     application/x-sv4cpio
        .sv4crc      application/x-sv4crc
        .swf         application/x-shockwave-flash
        .t           application/x-troff
        .tar         application/x-tar
        .tcl         application/x-tcl
        .tex         application/x-tex
        .texi        application/x-texinfo
        .texinfo     application/x-texinfo
        .tgz         application/x-compressed
        .thmx        application/vnd.ms-officetheme
        .tif         image/tiff
        .tiff        image/tiff
        .tr          application/x-troff
        .trm         application/x-msterminal
        .tsv         text/tab-separated-values
        .txt         text/plain
        .uls         text/iuls
        .ustar       application/x-ustar
        .vbs         text/vbscript
        .vcf         text/x-vcard
        .vcs         text/plain
        .vdx         application/vnd.ms-visio.viewer
        .vml         text/xml
        .vsd         application/vnd.visio
        .vss         application/vnd.visio
        .vst         application/vnd.visio
        .vsto        application/x-ms-vsto
        .vsw         application/vnd.visio
        .vsx         application/vnd.visio
        .vtx         application/vnd.visio
        .wav         audio/wav
        .wax         audio/x-ms-wax
        .wbmp        image/vnd.wap.wbmp
        .wcm         application/vnd.ms-works
        .wdb         application/vnd.ms-works
        .wks         application/vnd.ms-works
        .wm          video/x-ms-wm
        .wma         audio/x-ms-wma
        .wmd         application/x-ms-wmd
        .wmf         application/x-msmetafile
        .wml         text/vnd.wap.wml
        .wmlc        application/vnd.wap.wmlc
        .wmls        text/vnd.wap.wmlscript
        .wmlsc       application/vnd.wap.wmlscriptc
        .wmp         video/x-ms-wmp
        .wmv         video/x-ms-wmv
        .wmx         video/x-ms-wmx
        .wmz         application/x-ms-wmz
        .wps         application/vnd.ms-works
        .wri         application/x-mswrite
        .wrl         x-world/x-vrml
        .wrz         x-world/x-vrml
        .wsdl        text/xml
        .wvx         video/x-ms-wvx
        .x           application/directx
        .xaf         x-world/x-vrml
        .xaml        application/xaml+xml
        .xap         application/x-silverlight-app
        .xbap        application/x-ms-xbap
        .xbm         image/x-xbitmap
        .xdr         text/plain
        .xla         application/vnd.ms-excel
        .xlam        application/vnd.ms-excel.addin.macroEnabled.12
        .xlc         application/vnd.ms-excel
        .xlm         application/vnd.ms-excel
        .xls         application/vnd.ms-excel
        .xlsb        application/vnd.ms-excel.sheet.binary.macroEnabled.12
        .xlsm        application/vnd.ms-excel.sheet.macroEnabled.12
        .xlsx        application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
        .xlt         application/vnd.ms-excel
        .xltm        application/vnd.ms-excel.template.macroEnabled.12
        .xltx        application/vnd.openxmlformats-officedocument.spreadsheetml.template
        .xlw         application/vnd.ms-excel
        .xml         text/xml
        .xof         x-world/x-vrml
        .xpm         image/x-xpixmap
        .xps         application/vnd.ms-xpsdocument
        .xsd         text/xml
        .xsf         text/xml
        .xsl         text/xml
        .xslt        text/xml
        .xwd         image/x-xwindowdump
        .z           application/x-compress
        .zip         application/x-zip-compressed
    }

    set doNotCompress {.avi .docx .gz .jar .jpg .mkv .mp2 .mp3 .mp4 .mpg .png .pnz .pptx .qt .tgz .xlsx .xz .z .zip}

    ###########################################################################
    #
    # start
    #
    #   Starts the HTTP server
    #
    # Arguments:
    #   _port - server port
    #
    ###########################################################################
    proc start { { _port 8080 } } {
        if { ![catch { package require iocp_inet }] } {
            set socket ::iocp::inet::socket
        } else {
            set socket socket
        }
        set ::httpd::sock [$socket -server ::httpd::accept $_port]
        return
    }

    ###########################################################################
    #
    # stop
    #
    #   Stops the HTTP server
    #
    ###########################################################################
    proc stop {} {
        catch { chan close $::httpd::sock }
        foreach ch [array names ::httpd::incomingRequests] {
            catch { chan close $ch }
        }
        array unset ::httpd::incomingRequests
        array unset ::httpd::requestProcQueue
    }

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
        variable incomingRequests
        variable requestProcQueue
        if { [catch {
            chan configure $_sock -blocking no -encoding binary
            set incomingRequests($_sock) [dict create method {} uri {} headers {}]
            set requestProcQueue($_sock) [list]
            chan event $_sock readable [list ::httpd::io readRequest $_sock]
        }] } {
            catch { chan close $_sock }
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
    proc io { _cmd _sock } {
        if { [catch { $_cmd $_sock } res opts] } {
            set errorCode [dict get $opts -errorcode]
            catch { respond $_sock $errorCode -content $res -headers {Connection close} }
            terminate $_sock

        } elseif { [chan names $_sock] == {} || [chan eof $_sock] } {
            terminate $_sock
        }
    }

    ###########################################################################
    #
    # terminate
    #
    #   Closes the client socket and cleanups the internal data structures
    #
    # Arguments:
    #   _sock - client socket
    #
    ###########################################################################
    proc terminate { _sock } {
        variable incomingRequests
        variable requestProcQueue

        catch { chan close $_sock }
        array unset incomingRequests $_sock
        array unset requestProcQueue $_sock
    }

    ###########################################################################
    #
    # readRequest
    #
    #   Reads the first line from the HTTP request, parses it and adds parsed
    #   result to the internal request representation
    #
    # Arguments:
    #   _sock - channel to communicate with the client
    #
    ###########################################################################
    proc readRequest { _sock } {
        variable incomingRequests

        set len [chan gets $_sock line]
        if { $len < 0 } {
            # channel does not have the complete first line in the buffer yet
            # let it call us again when it has more data
            return
        }
        if { $len == 0 } {
            return -code error -errorcode BAD_REQUEST "Empty start line"
        }

        # parse request line
        lassign [split $line] method url protocol
        if { $method == {} || $url == {} } {
            return -code error -errorcode BAD_REQUEST "Malformed start line (missing method and/or url)"
        }
        if { [string range $protocol 0 5] ne "HTTP/1" } {
            return -code error -errorcode BAD_REQUEST "Unexpected/unsupported protocol"
        }

        dict set incomingRequests($_sock) method $method
        dict set incomingRequests($_sock) uri [uri::split $url] ;# scheme, user, pwd, host, port, path, query, fragment

        chan event $_sock readable [list ::httpd::io readHeaders $_sock]
        readHeaders $_sock
    }

    ###########################################################################
    #
    # readHeaders
    #
    #   Reads the header line from the HTTP request, parses it and adds parsed
    #   result to the internal request representation
    #
    # Arguments:
    #   _sock - channel to communicate with the client
    #
    ###########################################################################
    proc readHeaders { _sock } {
        variable incomingRequests

        while { [set len [chan gets $_sock line]] > 0 } {
            if { [regexp {^([^:]+?):\s+(.+?)\s*$} $line >> name data] } {
                dict set incomingRequests($_sock) headers [string tolower $name] $data
            }
        }

        if { $len < 0 } {
            # the line is not yet complete in the socket buffer
            return
        }

        if { [dict get $incomingRequests($_sock) method] in {POST PUT PATCH} } {
            chan event $_sock readable [list ::httpd::io readContent $_sock]
            readContent $_sock
        } else {
            queueRequestProcessing $_sock
        }
    }

    ###########################################################################
    #
    # setTranslation
    #
    #   Sets in or out EOL channel translation
    #
    # Arguments:
    #   _sock - channel to communicate with the client
    #   _dir  - -read or -write
    #   _mode - mode
    #
    ###########################################################################
    proc setTranslation { _sock _dir _mode } {
        set translation [chan configure $_sock -translation]
        if { $_dir == "-read" } {
            lset translation 0 $_mode
        } else {
            lset translation 1 $_mode
        }
        chan configure $_sock -translation $translation
    }

    ###########################################################################
    #
    # readContent
    #
    #   Reads request content
    #
    # Arguments:
    #   _sock - channel to communicate with the client
    #
    ###########################################################################
    proc readContent { _sock } {
        variable incomingRequests

        if { [dict exists $incomingRequests($_sock) headers "transfer-encoding"] } {
            set transferEncoding [dict get $incomingRequests($_sock) headers "transfer-encoding"]
        } else {
            set transferEncoding "identity"
        }

        if { $transferEncoding == "identity" } {

            if { ![dict exists $incomingRequests($_sock) headers "content-length"] } {
                return -code error -errorcode LENGTH_REQUIRED {}
            }
            set length [dict get $incomingRequests($_sock) headers "content-length"]
            dict set incomingRequests($_sock) size $length
            dict set incomingRequests($_sock) content ""

            setTranslation $_sock -read binary
            chan event $_sock readable [list ::httpd::io readContentData $_sock]
            readContentData $_sock

        } elseif { $transferEncoding == "chunked" } {

            dict set incomingRequests($_sock) state   size
            dict set incomingRequests($_sock) size    0
            dict set incomingRequests($_sock) content ""

            setTranslation $_sock -read binary
            chan event $_sock readable [list ::httpd::io readChunkedContent $_sock]
            readChunkedContent $_sock

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
    #   _sock - channel to communicate with the client
    #
    ###########################################################################
    proc readContentData { _sock } {
        variable incomingRequests

        set size [dict get $incomingRequests($_sock) size]
        set data [chan read $_sock $size]
        dict append incomingRequests($_sock) content $data
        set size [expr $size - [string length $data] ]

        if { $size > 0 } {
            dict set incomingRequests($_sock) size $size
        } else {
            dict unset incomingRequests($_sock) size
            queueRequestProcessing $_sock
        }
    }

    ###########################################################################
    #
    # readChunkedContent
    #
    #   Reads chunked request content
    #
    # Arguments:
    #   _sock - channel to communicate with the client
    #
    ###########################################################################
    proc readChunkedContent { _sock } {
        variable incomingRequests

        while { 1 } {
            switch [dict get $incomingRequests($_sock) state] {
                size { # read chunk size
                    set len [chan gets $_sock line]
                    if { $len < 0 } {
                        return
                    }
                    if { $len <= 1 } { # there will be a <CR> at the end of the line
                        return -code error -errorcode BAD_REQUEST "Chunk size line is too short"
                    }
                    if { [scan $line %x size] != 1 } {
                        return -code error -errorcode BAD_REQUEST "Cannot parse chunk size"
                    }
                    if { $size > 0 } {
                        dict set incomingRequests($_sock) size $size
                        dict set incomingRequests($_sock) state data
                    } else {
                        dict unset incomingRequests($_sock) size
                        dict set incomingRequests($_sock) state done
                    }
                }
                data {
                    set size [dict get $incomingRequests($_sock) size]
                    set data [chan read $_sock $size]
                    set size [expr $size - [string length $data] ]
                    dict append incomingRequests($_sock) content $data
                    dict set incomingRequests($_sock) size $size
                    if { $size == 0 } {
                        dict set incomingRequests($_sock) state term
                    }
                }
                term {
                    set len [chan gets $_sock line]
                    if { $len < 0 } {
                        return
                    }
                    if { $len > 1 } { # we should expect a lone <CR> here
                        return -code error -errorcode BAD_REQUEST "Unexpected data before the chunk terminator"
                    }
                    dict set incomingRequests($_sock) state size
                }
                done {
                    set len [chan gets $_sock line]
                    if { $len < 0 } {
                        return
                    }
                    if { $len > 1 } { # we should expect a lone <CR> here
                        return -code error -errorcode BAD_REQUEST "Unexpected data in the trailer chunk"
                    }
                    dict unset incomingRequests($_sock) state
                    dict unset incomingRequests($_sock) size
                    queueRequestProcessing $_sock
                    return
                }
            }
        }
    }

    ###########################################################################
    #
    # queueRequestProcessing
    #
    #   Adds request to request processing queue
    #
    # Arguments:
    #   _sock - channel to communicate with the client
    #
    ###########################################################################
    proc queueRequestProcessing { _sock } {
        variable incomingRequests
        variable requestProcQueue

        lappend requestProcQueue($_sock) $incomingRequests($_sock)
        set incomingRequests($_sock) [dict create method {} uri {} headers {}]

        setTranslation $_sock -read auto

        chan event $_sock readable [list ::httpd::io readRequest $_sock]
        chan event $_sock writable [list ::httpd::io procRequest $_sock]
    }

    ###########################################################################
    #
    # procRequest
    #
    #   Processes a request from the requests queue
    #
    # Arguments:
    #   _sock - channel to communicate with the client
    #
    ###########################################################################
    proc procRequest { _sock } {
        variable requestProcQueue
        variable config

        # Ensure we won't pick up the next request until this one is done.
        chan event $_sock writable {}

        set queue $requestProcQueue($_sock)
        set request [lindex $queue 0]
        set requestProcQueue($_sock) [lrange $queue 1 end]

        # Look up the request handler first. If we cannot handle the request,
        # then we won't waste time on handling the request content
        set proc 0
        set path [dict get $request uri path]
        foreach { route handler } [dict get $config path] {
            if { [string match $route $path] } {
                set proc 1
                break
            }
        }
        if { $proc } {
            if { [string index $route end] == "*" } {
                dict set request uri path [string range $path [string length $route]-1 end]
            } else {
                dict set request uri path [string range $path [string length $route] end]
            }
            if { [dict exists $request content] } {
                if { [dict exists $request headers "content-encoding"] } {
                    set contentEncoding [dict get $request headers "content-encoding"]
                    if { $contentEncoding != "identity" } {
                        if { $contentEncoding ni {compress deflate gzip} } {
                            return -code error -errorcode NOT_ACCEPTABLE "Unsupported content encoding $contentEncoding"
                        }
                        set content [dict get $request content]
                        switch $contentEncoding {
                            compress { set content [zlib decompress $content] }
                            deflate  { set content [zlib inflate    $content] }
                            gzip     { set content [zlib gunzip     $content] }
                        }
                        dict set request content $content
                    }
                }
                if { [dict exists $request headers "content-type"] } {
                    set contentType [dict get $request headers "content-type"]
                    if { [regexp -nocase {charset=([^;[:space:]]+)} $contentType >> charset] } {
                        set charset [string tolower $charset]
                        set content [dict get $request content]
                        set content [encoding convertfrom $charset $content]
                        dict set request content $content
                    }
                }
            }
        } else {
            set handler [getFileHandler $request]
        }

        {*}$handler $_sock $request

        if { [llength $requestProcQueue($_sock)] > 0 } {
            chan event $_sock writable [list ::httpd::io procRequest $_sock]
        } elseif { [dict exists $request headers connection] && [dict get $request headers connection] == "close" } {
            chan close $_sock
        }
    }

    ###########################################################################
    #
    # getFileHandler
    #
    #   Determines how to handle incoming file request
    #
    # Arguments:
    #   _request - parsed HTTP request
    #
    # Returns:
    #   { handler_command ?opt_arg ...? }
    #
    ###########################################################################
    proc getFileHandler { _request } {
        variable config

        if { [dict get $_request method] ni {GET HEAD} } {
            return ::httpd::respondMethodNotAllowedForFileRequests
        }

        set path [dict get $_request uri path]
        set root [dict get $config root]
        set path [file join $root $path]
        if { [file isdirectory $path] } {
            set path [file join $path index.html]
        }

        if { ![file isfile $path] || ![file readable $path] } {
            return ::httpd::respondNotFound
        }

        if {
            [dict exists $_request headers "if-modified-since"] &&
            ![catch {clock scan [dict get $_request headers "if-modified-since"] -gmt 1 -format {%a, %d %b %Y %H:%M:%S GMT}} modTime] &&
            [file mtime $path] <= $modTime
        } {
            return [list ::httpd::respondNotModified $path]
        }

        if { [dict get $_request method] == "HEAD" } {
            return [list ::httpd::sendFileInfo $path]
        }

        set contentEncoding ""
        if { [dict exists $_request headers "accept-encoding"] } {
            foreach encoding [regexp -inline -all {\w+} [dict get $_request headers "accept-encoding"] ] {
                if { $encoding in {compress deflate gzip} } {
                    set contentEncoding $encoding
                    break
                }
            }
        }
        if { $contentEncoding != "" && [string tolower [file ext $path]] ni $::httpd::doNotCompress } {
            return [list ::httpd::sendCompressedFile $contentEncoding $path]
        } else {
            return [list ::httpd::sendFile $path]
        }
    }

    ###########################################################################
    #
    # respondNotModified
    #
    #   Sends 304 response
    #
    # Arguments:
    #   _path    - name of the file which content was requested
    #   _sock    - channel to communicate with the client
    #   _request - parsed request
    #
    ###########################################################################
    proc respondNotModified { _path _sock _request } {
        set modTime [clock format [file mtime $_path] -gmt 1 -format {%a, %d %b %Y %H:%M:%S GMT}]
        respond $_sock NOT_MODIFIED -headers [list Last-Modified $modTime]
    }

    ###########################################################################
    #
    # respondNotFound
    #
    #   Sends 404 response
    #
    # Arguments:
    #   _sock    - channel to communicate with the client
    #   _request - parsed request
    #
    ###########################################################################
    proc respondNotFound { _sock _request } {
        respond $_sock NOT_FOUND -content "[dict get $_request uri path] does not exist"
    }

    ###########################################################################
    #
    # respondMethodNotAllowedForFileRequests
    #
    #   Sends 405 response
    #
    # Arguments:
    #   _sock    - channel to communicate with the client
    #   _request - parsed request
    #
    ###########################################################################
    proc respondMethodNotAllowedForFileRequests { _sock _request } {
        respond $_sock METHOD_NOT_ALLOWED -headers {Allow {GET, HEAD}}
    }

    ###########################################################################
    #
    # sendFileInfo
    #
    #   Returns headers that would be returned with the content of the specified
    #   file.
    #
    # Arguments:
    #   _path    - name of the file which content should be returned
    #   _sock    - channel to communicate with the client
    #   _request - parsed request
    #
    ###########################################################################
    proc sendFileInfo { _path _sock _request } {
        variable knownContentTypes
        set contentType [lindex [array get knownContentTypes [string tolower [file extension $_path]]] end]
        if { $contentType == {} } {
            set contentType "application/octet-stream"
        }
        puts $_sock "HTTP/1.1 200 OK"
        puts $_sock [format {Last-Modified: %s} [clock format [file mtime $_path] -gmt 1 -format {%a, %d %b %Y %H:%M:%S GMT}]]
        puts $_sock [format {Content-Type: %s} $contentType]
        puts $_sock [format {Content-Length: %d} [file size $_path]]
        puts $_sock ""
        flush $_sock
    }

    ###########################################################################
    #
    # sendFile
    #
    #   Returns content of the specified file.
    #
    # Arguments:
    #   _path    - name of the file which content should be returned
    #   _sock    - channel to communicate with the client
    #   _request - parsed request
    #
    ###########################################################################
    proc sendFile { _path _sock _request } {
        variable knownContentTypes
        set contentType [lindex [array get knownContentTypes [file extension $_path]] end]
        if { $contentType == {} } {
            set contentType "application/octet-stream"
        }
        puts $_sock "HTTP/1.1 200 OK"
        puts $_sock [format {Last-Modified: %s} [clock format [file mtime $_path] -gmt 1 -format {%a, %d %b %Y %H:%M:%S GMT}]]
        puts $_sock [format {Content-Type: %s} $contentType]
        puts $_sock [format {Content-Length: %d} [file size $_path]]
        puts $_sock ""

        setTranslation $_sock -write binary
        set ifc [open $_path r]
        set err [catch {
            chan configure $ifc -blocking no -translation binary -encoding binary -buffering full -buffersize 65536
            chan copy $ifc $_sock
        } res opts]
        catch { chan close $ifc }
        if { $err } {
            return -options $opts $res
        }
        setTranslation $_sock -write auto
    }

    ###########################################################################
    #
    # sendCompressedFile
    #
    #   Returns content of the specified file. Compresses it for transfer.
    #
    # Arguments:
    #   _encoding - compression method to use
    #   _path     - name of the file which content should be returned
    #   _sock     - channel to communicate with the client
    #   _request  - parsed request
    #
    ###########################################################################
    proc sendCompressedFile { _encoding _path _sock _request } {
        variable knownContentTypes

        set content ""
        set size [file size $_path]

        set ifc [open $_path r]
        set err [catch {
            chan configure $ifc -blocking no -translation binary -encoding binary -buffering full -buffersize 65536
            while { $size > 0 } {
                set data [chan read $ifc $size]
                set dataLen [string length $data]
                if { $dataLen == 0 } {
                    update
                } else {
                    append content $data
                    set size [expr $size - $dataLen]
                }
            }
        } res opts]
        catch { chan close $ifc }
        if { $err } {
            return -options $opts $res
        }

        set content [zlib $_encoding $content]

        set contentType [lindex [array get knownContentTypes [file extension $_path]] end]
        if { $contentType == {} } {
            set contentType "application/octet-stream"
        }

        puts $_sock "HTTP/1.1 200 OK"
        puts $_sock [format {Last-Modified: %s} [clock format [file mtime $_path] -gmt 1 -format {%a, %d %b %Y %H:%M:%S GMT}]]
        puts $_sock [format {Content-Type: %s} $contentType]
        puts $_sock [format {Content-Encoding: %s} $_encoding]
        puts $_sock [format {Content-Length: %d} [string length $content]]
        puts $_sock ""

        setTranslation $_sock -write binary
        puts -nonewline $_sock $content
        flush $_sock
        setTranslation $_sock -write auto
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

    ###########################################################################
    #
    # respond
    #
    #   Sends a response to the client
    #
    # Arguments:
    #   _sock - channel to communicate with the client
    #   _code - HTTP response code
    #   args:
    #    -content - content
    #    -headers - list of additional headers
    #    -encoding - content of request's Accept-Encoding
    #
    ###########################################################################
    proc respond { _sock _code args } {
        variable statusCodes

        array set opts { -content {} -headers {} -encoding {} }
        array set opts $args
        foreach key { content headers encoding } {
            set $key $opts(-$key)
        }

        lassign [lindex [array get statusCodes $_code] end] code reason
        if { $code == {} } {
            lassign $statusCodes(SERVER_ERROR) code reason
        }

        puts $_sock "HTTP/1.1 $code $reason"

        set contentTypePresent 0
        set allowPresent 0
        foreach {name value} $headers {
            puts -nonewline $_sock $name
            puts -nonewline $_sock {: }
            puts $_sock $value
            set contentTypePresent [expr { $contentTypePresent || $name == "Content-Type" }]
            set allowPresent [expr { $allowPresent || $name == "Allow" }]
        }

        if { $code == 406 } {
            puts $_sock "Accept-Encoding: gzip, compress, deflate"
        } elseif { $code == 405 && !$allowPresent } {
            puts $_sock "Allow: GET, HEAD, POST, PUT, PATCH, DELETE"
        }

        set contentLength [string length $content]
        if { $contentLength > 0 } {
            if { !$contentTypePresent } {
                puts $_sock {Content-Type: text/plain; charset=utf-8}
                set content [encoding convertto utf-8 $content]
            }
            if { $encoding != {} } {
                set contentEncoding ""
                foreach enc [regexp -inline -all {\w+} $encoding] {
                    if { $enc in {compress deflate gzip} } {
                        set contentEncoding $encoding
                        break
                    }
                }
                if { $contentEncoding != "" } {
                    set content [zlib $contentEncoding $content]
                    set contentLength [string length $content]
                }
            }
        }
        puts -nonewline $_sock {Content-Length: }
        puts $_sock $contentLength
        puts $_sock ""
        if { $contentLength > 0 } {
            setTranslation $_sock -write binary
            puts -nonewline $_sock $content
            setTranslation $_sock -write auto
        }
        flush $_sock
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
    catch { ::httpd::stop }
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
    set ::httpd::config [dict create {*}[read $confFile]]
    close $confFile
    unset confFile
} else {
    set ::httpd::config [dict create]
}
#
# Set defaults for the required configuration keys if they are not provided
#
foreach { key val } [list \
    port  8080 \
    root  [file join [file dir [info script]] docs] \
    path  {} \
] {
    if { ![dict exists $::httpd::config $key] } {
        dict set ::httpd::config $key $val
    }
}

source [file join [file dir [info script]] dyn_content.tcl]

#
# Start HTTP server
#
::httpd::start [dict get $::httpd::config port]

###########################################################################
#
# Done. Service is running now.
#
###########################################################################
