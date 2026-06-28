sub Main(args as Dynamic)
    RunScreenSaver(args)
end sub

sub RunScreenSaver(args as Dynamic)
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.SetMessagePort(port)

    scene = screen.CreateScene("HomeBoardScene")
    scene.backendUrl = GetBackendUrl()

    screen.Show()

    while true
        msg = wait(0, port)
        msgType = type(msg)

        if msgType = "roSGScreenEvent"
            if msg.isScreenClosed() then return
        end if
    end while
end sub

function GetBackendUrl() as String
    defaultUrl = "http://127.0.0.1:3000/api/dashboard"
    configText = ReadAsciiFile("pkg:/config.json")

    if configText = invalid or configText = "" then return defaultUrl

    config = ParseJson(configText)
    if config = invalid then return defaultUrl
    if config.BACKEND_URL = invalid or config.BACKEND_URL = "" then return defaultUrl

    return config.BACKEND_URL
end function
