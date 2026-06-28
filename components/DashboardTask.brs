sub init()
    m.top.functionName = "fetchDashboard"
end sub

sub fetchDashboard()
    if m.top.url = invalid or m.top.url = "" then
        m.top.error = "Missing backend URL"
        return
    end if

    print "HomeBoard: fetching dashboard from "; m.top.url

    transfer = CreateObject("roUrlTransfer")
    transfer.SetUrl(m.top.url)
    transfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.InitClientCertificates()
    transfer.AddHeader("Accept", "application/json")

    response = transfer.GetToString()

    if response = invalid or response = "" then
        print "HomeBoard: dashboard request failed with an empty response"
        m.top.error = "Request failed"
        return
    end if

    data = ParseJson(response)
    if data = invalid then
        print "HomeBoard: dashboard response was not valid JSON"
        m.top.error = "Invalid JSON"
        return
    end if

    print "HomeBoard: dashboard loaded"
    m.top.dashboard = data
end sub
