sub init()
    m.backgroundA = m.top.findNode("backgroundA")
    m.backgroundB = m.top.findNode("backgroundB")
    m.statusLabel = m.top.findNode("statusLabel")
    m.clockLabel = m.top.findNode("clockLabel")
    m.timezoneLabel = m.top.findNode("timezoneLabel")

    m.weatherMain = m.top.findNode("weatherMain")
    m.weatherSub = m.top.findNode("weatherSub")
    m.weatherDetail = m.top.findNode("weatherDetail")
    m.weatherPoster = m.top.findNode("weatherPoster")

    m.f1Countdown = m.top.findNode("f1Countdown")
    m.f1Race = m.top.findNode("f1Race")
    m.f1Circuit = m.top.findNode("f1Circuit")
    m.f1After = m.top.findNode("f1After")
    m.trackNameLabel = m.top.findNode("trackNameLabel")
    m.trackLabel = m.top.findNode("trackLabel")
    m.circuitPoster = m.top.findNode("circuitPoster")
    m.quali1 = m.top.findNode("quali1")
    m.quali2 = m.top.findNode("quali2")
    m.quali3 = m.top.findNode("quali3")

    m.wowMain = m.top.findNode("wowMain")
    m.wowSub = m.top.findNode("wowSub")
    m.wowOrb = m.top.findNode("wowOrb")
    m.wowPulse = m.top.findNode("wowPulse")

    m.clockTimer = m.top.findNode("clockTimer")
    m.pollTimer = m.top.findNode("pollTimer")
    m.motionTimer = m.top.findNode("motionTimer")
    m.wowTimer = m.top.findNode("wowTimer")
    m.backgroundTimer = m.top.findNode("backgroundTimer")
    m.dashboardTask = m.top.findNode("dashboardTask")

    m.clockTimer.observeField("fire", "onClockTick")
    m.pollTimer.observeField("fire", "onPollTick")
    m.motionTimer.observeField("fire", "onMotionTick")
    m.wowTimer.observeField("fire", "onWowTick")
    m.backgroundTimer.observeField("fire", "onBackgroundTick")
    m.dashboardTask.observeField("dashboard", "onDashboardLoaded")
    m.dashboardTask.observeField("error", "onDashboardError")

    m.weatherIcon = "moon-new"
    m.motionFrame = 0
    m.currentWowIndex = 0
    m.wowRealms = []
    m.backgroundIndex = 0

    onClockTick()
    m.clockTimer.control = "start"
    m.pollTimer.control = "start"
    m.motionTimer.control = "start"
    m.wowTimer.control = "start"
    m.backgroundTimer.control = "start"
end sub

sub onBackendUrlChanged()
    if m.top.backendUrl <> invalid and m.top.backendUrl <> "" then
        fetchDashboard()
    end if
end sub

sub onClockTick()
    m.clockLabel.text = formatLocalTime()
end sub

sub onPollTick()
    fetchDashboard()
end sub

sub onMotionTick()
    m.motionFrame = m.motionFrame + 1
    animateWeatherIcon()
    animateWowIcon()
end sub

sub onWowTick()
    if m.wowRealms <> invalid and m.wowRealms.count() > 0 then
        m.currentWowIndex = (m.currentWowIndex + 1) mod m.wowRealms.count()
        renderWowRealm()
    end if
end sub

sub onBackgroundTick()
    m.backgroundIndex = (m.backgroundIndex + 1) mod 2
    if m.backgroundIndex = 0 then
        m.backgroundA.opacity = 1
        m.backgroundB.opacity = 0
    else
        m.backgroundA.opacity = 0
        m.backgroundB.opacity = 1
    end if
end sub

sub fetchDashboard()
    if m.top.backendUrl = invalid or m.top.backendUrl = "" then return

    m.statusLabel.text = "Updating..."
    m.dashboardTask.url = m.top.backendUrl
    m.dashboardTask.control = "RUN"
end sub

sub onDashboardLoaded()
    data = m.dashboardTask.dashboard
    if data = invalid then
        showUnavailable()
        return
    end if

    if data.time <> invalid then
        if data.time.timezone <> invalid then m.timezoneLabel.text = data.time.timezone
    end if

    if data.weather <> invalid then renderWeather(data.weather)
    if data.wow <> invalid then renderWow(data.wow)
    if data.f1 <> invalid then renderF1(data.f1)

    m.statusLabel.text = "Updated " + formatLocalTime()
end sub

sub renderWeather(weather as Dynamic)
    temp = valueOrDash(weather.tempF)
    condition = valueOrDash(weather.condition)

    if temp <> "--" then
        m.weatherMain.text = temp + Chr(176) + "F  " + condition
    else
        m.weatherMain.text = condition
    end if

    m.weatherSub.text = valueOrDash(weather.location)
    detail = "H " + valueOrDash(weather.highF) + Chr(176) + "  L " + valueOrDash(weather.lowF) + Chr(176)
    if weather.isDay <> invalid and weather.isDay = false and weather.moonPhase <> invalid then
        detail = detail + Chr(10) + valueOrDash(weather.moonPhase.name) + " " + valueOrDash(weather.moonPhase.illumination) + "%"
    end if
    m.weatherDetail.text = detail

    if weather.icon <> invalid then
        m.weatherIcon = weather.icon
    else
        m.weatherIcon = "unknown"
    end if
    m.weatherPoster.uri = "pkg:/images/weather/" + m.weatherIcon + ".png"
end sub

sub renderWow(wow as Dynamic)
    if wow.realms <> invalid and wow.realms.count() > 0 then
        m.wowRealms = wow.realms
        if m.currentWowIndex >= m.wowRealms.count() then m.currentWowIndex = 0
        renderWowRealm()
    else
        m.wowRealms = []
        m.wowMain.text = "World of Warcraft realm status unavailable"
        m.wowSub.text = valueOrDash(wow.error)
    end if
end sub

sub renderWowRealm()
    realm = m.wowRealms[m.currentWowIndex]
    status = LCase(valueOrDash(realm.status))
    population = valueOrDash(realm.population)
    region = UCase(valueOrDash(realm.region))

    if status = "online" then
        m.wowOrb.color = "0x34D399FF"
        m.wowPulse.color = "0x34D39988"
    else if status = "unavailable" then
        m.wowOrb.color = "0xF59E0BFF"
        m.wowPulse.color = "0xF59E0B88"
    else
        m.wowOrb.color = "0xF87171FF"
        m.wowPulse.color = "0xF8717188"
    end if

    m.wowMain.text = valueOrDash(realm.realm) + Chr(10) + UCase(status)
    m.wowSub.text = region + "  Population: " + population + Chr(10) + (m.currentWowIndex + 1).ToStr() + "/" + m.wowRealms.count().ToStr()
end sub

sub renderF1(f1 as Dynamic)
    m.f1Countdown.text = valueOrDash(f1.countdown)
    m.f1Race.text = valueOrDash(f1.nextRace) + Chr(10) + valueOrDash(f1.session)
    m.f1Circuit.text = valueOrDash(f1.circuit) + Chr(10) + valueOrDash(f1.country)

    if f1.weekendAfter <> invalid then
        m.f1After.text = "After that: " + valueOrDash(f1.weekendAfter.nextRace) + Chr(10) + "in " + valueOrDash(f1.weekendAfter.countdown)
    else
        m.f1After.text = ""
    end if

    m.trackNameLabel.text = valueOrDash(f1.circuit)
    m.trackLabel.text = formatCircuitFacts(f1)

    if f1.circuitImage <> invalid and f1.circuitImage <> "" then
        m.circuitPoster.uri = f1.circuitImage
    else
        m.circuitPoster.uri = ""
    end if
    renderQualifying(f1.qualifyingTop3)
end sub

sub renderQualifying(top3 as Dynamic)
    if top3 = invalid or top3.count() = 0 then
        m.quali1.text = "Qualifying not posted yet"
        m.quali2.text = ""
        m.quali3.text = ""
        return
    end if

    labels = [m.quali1, m.quali2, m.quali3]
    for i = 0 to 2
        if i < top3.count() then
            driver = top3[i]
            labels[i].text = driver.position.ToStr() + ". " + valueOrDash(driver.driver) + "  " + valueOrDash(driver.team) + "  " + valueOrDash(driver.time)
        else
            labels[i].text = ""
        end if
    end for
end sub

sub animateWeatherIcon()
    bob = m.motionFrame mod 3
    m.weatherPoster.translation = [78, 62 + bob]
    if (m.motionFrame mod 2) = 0 then
        m.weatherPoster.opacity = 0.9
    else
        m.weatherPoster.opacity = 1.0
    end if
end sub

sub animateWowIcon()
    if (m.motionFrame mod 2) = 0 then
        m.wowPulse.opacity = 0.2
    else
        m.wowPulse.opacity = 0.45
    end if
end sub

sub onDashboardError()
    showUnavailable()
end sub

sub showUnavailable()
    m.statusLabel.text = "Data unavailable"
    m.weatherMain.text = "Data unavailable"
    m.weatherSub.text = ""
    m.weatherDetail.text = ""
    m.wowMain.text = "World of Warcraft realm status unavailable"
    m.wowSub.text = ""
    m.f1Countdown.text = "Data unavailable"
    m.f1Race.text = ""
    m.f1Circuit.text = ""
    m.f1After.text = ""
    m.trackNameLabel.text = ""
    m.trackLabel.text = ""
    m.circuitPoster.uri = ""
end sub

function formatLocalTime() as String
    now = CreateObject("roDateTime")
    now.ToLocalTime()
    hour = now.GetHours()
    minute = now.GetMinutes()
    suffix = "AM"

    if hour >= 12 then suffix = "PM"

    hour12 = hour mod 12
    if hour12 = 0 then hour12 = 12

    minuteText = minute.ToStr()
    if minute < 10 then minuteText = "0" + minuteText

    return hour12.ToStr() + ":" + minuteText + " " + suffix
end function

function valueOrDash(value as Dynamic) as String
    if value = invalid then return "--"
    valueType = type(value)
    if (valueType = "String" or valueType = "roString") and value = "" then return "--"
    return value.ToStr()
end function

function formatCircuitFacts(f1 as Dynamic) as String
    facts = ""

    if f1.circuitLocation <> invalid and f1.circuitLocation <> "" then
        facts = f1.circuitLocation
    else if f1.country <> invalid and f1.country <> "" then
        facts = f1.country
    end if

    lengthValue = valueOrDash(f1.circuitLengthKm)
    if lengthValue <> "--" and lengthValue <> "null" then
        lengthText = lengthValue + " km"
        if facts <> "" then
            facts = facts + Chr(10) + lengthText
        else
            facts = lengthText
        end if
    end if

    lapsValue = valueOrDash(f1.laps)
    if lapsValue <> "--" and lapsValue <> "null" then
        lapsText = lapsValue + " laps"
        if facts <> "" then
            facts = facts + "  " + Chr(183) + "  " + lapsText
        else
            facts = lapsText
        end if
    end if

    if facts = "" then return "Circuit map"
    return facts
end function
