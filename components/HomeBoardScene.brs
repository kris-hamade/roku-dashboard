sub init()
    m.backgroundA = m.top.findNode("backgroundA")
    m.backgroundB = m.top.findNode("backgroundB")
    m.titleLabel = m.top.findNode("titleLabel")
    m.statusLabel = m.top.findNode("statusLabel")
    m.clockLabel = m.top.findNode("clockLabel")
    m.timezoneLabel = m.top.findNode("timezoneLabel")

    m.weatherMain = m.top.findNode("weatherMain")
    m.weatherCard = m.top.findNode("weatherCard")
    m.weatherSub = m.top.findNode("weatherSub")
    m.weatherDetail = m.top.findNode("weatherDetail")
    m.weatherMoon = m.top.findNode("weatherMoon")
    m.weatherPoster = m.top.findNode("weatherPoster")

    m.featureTitle = m.top.findNode("featureTitle")
    m.f1Card = m.top.findNode("f1Card")
    m.f1Countdown = m.top.findNode("f1Countdown")
    m.f1RaceName = m.top.findNode("f1RaceName")
    m.f1Session = m.top.findNode("f1Session")
    m.f1CircuitName = m.top.findNode("f1CircuitName")
    m.f1Country = m.top.findNode("f1Country")
    m.f1AfterRace = m.top.findNode("f1AfterRace")
    m.f1AfterCountdown = m.top.findNode("f1AfterCountdown")
    m.trackNameLabel = m.top.findNode("trackNameLabel")
    m.trackLocationLabel = m.top.findNode("trackLocationLabel")
    m.trackStatsLabel = m.top.findNode("trackStatsLabel")
    m.trackMap = m.top.findNode("trackMap")
    m.circuitPoster = m.top.findNode("circuitPoster")
    m.qualiTitle = m.top.findNode("qualiTitle")
    m.quali1 = m.top.findNode("quali1")
    m.quali2 = m.top.findNode("quali2")
    m.quali3 = m.top.findNode("quali3")

    m.wowRealm = m.top.findNode("wowRealm")
    m.wowCard = m.top.findNode("wowCard")
    m.wowStatus = m.top.findNode("wowStatus")
    m.wowMeta = m.top.findNode("wowMeta")
    m.wowIndex = m.top.findNode("wowIndex")
    m.wowOrb = m.top.findNode("wowOrb")
    m.wowPulse = m.top.findNode("wowPulse")

    m.clockTimer = m.top.findNode("clockTimer")
    m.pollTimer = m.top.findNode("pollTimer")
    m.motionTimer = m.top.findNode("motionTimer")
    m.wowTimer = m.top.findNode("wowTimer")
    m.backgroundTimer = m.top.findNode("backgroundTimer")
    m.featureTimer = m.top.findNode("featureTimer")
    m.dashboardTask = m.top.findNode("dashboardTask")

    m.clockTimer.observeField("fire", "onClockTick")
    m.pollTimer.observeField("fire", "onPollTick")
    m.motionTimer.observeField("fire", "onMotionTick")
    m.wowTimer.observeField("fire", "onWowTick")
    m.backgroundTimer.observeField("fire", "onBackgroundTick")
    m.featureTimer.observeField("fire", "onFeatureTick")
    m.dashboardTask.observeField("dashboard", "onDashboardLoaded")
    m.dashboardTask.observeField("error", "onDashboardError")

    m.weatherIcon = "moon-new"
    m.motionFrame = 0
    m.currentWowIndex = 0
    m.wowRealms = []
    m.backgroundIndex = 0
    m.activeBackground = 0
    m.featureMode = "f1"
    m.currentF1 = invalid
    m.newsItems = []
    m.backgroundUris = [
        "pkg:/images/backgrounds/cityscape-01.png",
        "pkg:/images/backgrounds/cityscape-02.png",
        "pkg:/images/backgrounds/cityscape-03.png",
        "pkg:/images/backgrounds/cityscape-04.png",
        "pkg:/images/backgrounds/cityscape-05.png",
        "pkg:/images/backgrounds/cityscape-06.png",
        "pkg:/images/backgrounds/cityscape-07.png",
        "pkg:/images/backgrounds/cityscape-08.png",
        "pkg:/images/backgrounds/cityscape-09.png",
        "pkg:/images/backgrounds/cityscape-10.png"
    ]
    m.foregroundNodes = [m.titleLabel, m.timezoneLabel, m.statusLabel, m.clockLabel, m.weatherCard, m.f1Card, m.wowCard]
    m.foregroundBase = [[56, 34], [56, 77], [792, 44], [54, 112], [56, 226], [446, 226], [56, 638]]

    onClockTick()
    m.clockTimer.control = "start"
    m.pollTimer.control = "start"
    m.motionTimer.control = "start"
    m.wowTimer.control = "start"
    m.backgroundTimer.control = "start"
    m.featureTimer.control = "start"
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
    animateBurnInDrift()
    animateBackgroundDrift()
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
    m.backgroundIndex = (m.backgroundIndex + 1) mod m.backgroundUris.count()

    if m.activeBackground = 0 then
        m.backgroundB.uri = m.backgroundUris[m.backgroundIndex]
        m.backgroundA.opacity = 0
        m.backgroundB.opacity = 1
        m.activeBackground = 1
    else
        m.backgroundA.uri = m.backgroundUris[m.backgroundIndex]
        m.backgroundA.opacity = 1
        m.backgroundB.opacity = 0
        m.activeBackground = 0
    end if
end sub

sub onFeatureTick()
    if m.newsItems <> invalid and m.newsItems.count() > 0 then
        if m.featureMode = "f1" then
            m.featureMode = "news"
        else
            m.featureMode = "f1"
        end if
        renderFeatureCard()
    end if
end sub

sub fetchDashboard()
    if m.top.backendUrl = invalid or m.top.backendUrl = "" then return

    m.statusLabel.text = "Updating"
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
    if data.f1 <> invalid then m.currentF1 = data.f1
    if data.news <> invalid then m.newsItems = data.news
    renderFeatureCard()

    m.statusLabel.text = "Updated " + formatLocalTime()
end sub

sub renderFeatureCard()
    if m.featureMode = "news" and m.newsItems <> invalid and m.newsItems.count() > 0 then
        renderNews()
    else if m.currentF1 <> invalid then
        renderF1(m.currentF1)
    end if
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
    m.weatherMoon.text = ""
    if weather.isDay <> invalid and weather.isDay = false and weather.moonPhase <> invalid then
        m.weatherMoon.text = valueOrDash(weather.moonPhase.name) + " " + valueOrDash(weather.moonPhase.illumination) + "%"
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
        m.wowRealm.text = "World of Warcraft"
        m.wowStatus.text = "realm status unavailable"
        m.wowMeta.text = valueOrDash(wow.error)
        m.wowIndex.text = ""
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

    m.wowRealm.text = valueOrDash(realm.realm)
    m.wowStatus.text = UCase(status)
    m.wowMeta.text = region + "  Population: " + population
    m.wowIndex.text = (m.currentWowIndex + 1).ToStr() + "/" + m.wowRealms.count().ToStr()
end sub

sub renderF1(f1 as Dynamic)
    m.featureTitle.text = "Formula 1"
    m.trackMap.visible = true
    m.qualiTitle.text = "Qualifying Top 3"
    m.f1Countdown.text = valueOrDash(f1.countdown)
    m.f1RaceName.text = valueOrDash(f1.nextRace)
    m.f1Session.text = valueOrDash(f1.session)
    m.f1CircuitName.text = valueOrDash(f1.circuit)
    m.f1Country.text = valueOrDash(f1.country)

    if f1.weekendAfter <> invalid then
        m.f1AfterRace.text = "After that: " + valueOrDash(f1.weekendAfter.nextRace)
        m.f1AfterCountdown.text = "in " + valueOrDash(f1.weekendAfter.countdown)
    else
        m.f1AfterRace.text = ""
        m.f1AfterCountdown.text = ""
    end if

    m.trackNameLabel.text = valueOrDash(f1.circuit)
    renderCircuitFacts(f1)

    if f1.circuitImage <> invalid and f1.circuitImage <> "" then
        m.circuitPoster.uri = f1.circuitImage
    else
        m.circuitPoster.uri = ""
    end if
    renderQualifying(f1.qualifyingTop3)
end sub

sub renderNews()
    m.featureTitle.text = "Top Headlines"
    m.trackMap.visible = false
    m.circuitPoster.uri = ""
    m.qualiTitle.text = "More Headlines"

    clearFeatureText()
    m.f1Countdown.text = "World / U.S. / Tech"

    if m.newsItems.count() > 0 then
        first = m.newsItems[0]
        firstLines = splitTextIntoLines(valueOrDash(first.title), 43, 4)
        if firstLines.count() > 0 then m.f1RaceName.text = firstLines[0]
        if firstLines.count() > 1 then m.f1Session.text = firstLines[1]
        if firstLines.count() > 2 then m.f1CircuitName.text = firstLines[2]
        if firstLines.count() > 3 then m.f1Country.text = firstLines[3]
    end if

    if m.newsItems.count() > 1 then
        item = m.newsItems[1]
        m.f1AfterRace.text = newsPrefix(item) + firstLine(valueOrDash(item.title), 46)
    end if

    if m.newsItems.count() > 2 then
        item = m.newsItems[2]
        m.f1AfterCountdown.text = newsPrefix(item) + firstLine(valueOrDash(item.title), 46)
    end if

    labels = [m.quali1, m.quali2, m.quali3]
    for i = 0 to 2
        itemIndex = i + 3
        if itemIndex < m.newsItems.count() then
            item = m.newsItems[itemIndex]
            labels[i].text = newsPrefix(item) + firstLine(valueOrDash(item.title), 68)
        else
            labels[i].text = ""
        end if
    end for
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

sub animateBurnInDrift()
    driftX = (Int(m.motionFrame / 47) mod 7) - 3
    driftY = (Int(m.motionFrame / 61) mod 7) - 3

    for i = 0 to m.foregroundNodes.count() - 1
        base = m.foregroundBase[i]
        m.foregroundNodes[i].translation = [base[0] + driftX, base[1] + driftY]
    end for
end sub

sub animateBackgroundDrift()
    panX = -24 + (Int(m.motionFrame / 5) mod 9)
    panY = -16 + (Int(m.motionFrame / 7) mod 7)
    if m.activeBackground = 0 then
        m.backgroundA.translation = [panX, panY]
    else
        m.backgroundB.translation = [panX, panY]
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
    m.weatherMoon.text = ""
    m.wowRealm.text = "World of Warcraft"
    m.wowStatus.text = "realm status unavailable"
    m.wowMeta.text = ""
    m.wowIndex.text = ""
    m.f1Countdown.text = "Data unavailable"
    m.featureTitle.text = "Formula 1"
    m.f1RaceName.text = ""
    m.f1Session.text = ""
    m.f1CircuitName.text = ""
    m.f1Country.text = ""
    m.f1AfterRace.text = ""
    m.f1AfterCountdown.text = ""
    m.trackNameLabel.text = ""
    m.trackLocationLabel.text = ""
    m.trackStatsLabel.text = ""
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

sub clearFeatureText()
    m.f1RaceName.text = ""
    m.f1Session.text = ""
    m.f1CircuitName.text = ""
    m.f1Country.text = ""
    m.f1AfterRace.text = ""
    m.f1AfterCountdown.text = ""
    m.trackNameLabel.text = ""
    m.trackLocationLabel.text = ""
    m.trackStatsLabel.text = ""
    m.quali1.text = ""
    m.quali2.text = ""
    m.quali3.text = ""
end sub

function newsPrefix(item as Dynamic) as String
    category = valueOrDash(item.category)
    source = valueOrDash(item.source)

    if source <> "--" then return source + ": "
    if category <> "--" then return category + ": "
    return ""
end function

function firstLine(text as String, maxChars as Integer) as String
    lines = splitTextIntoLines(text, maxChars, 1)
    if lines.count() = 0 then return ""
    return lines[0]
end function

function splitTextIntoLines(text as String, maxChars as Integer, maxLines as Integer) as Object
    words = text.Tokenize(" ")
    lines = []
    current = ""

    for each word in words
        if current = "" then
            candidate = word
        else
            candidate = current + " " + word
        end if

        if Len(candidate) <= maxChars then
            current = candidate
        else
            if current <> "" then
                lines.Push(current)
            end if
            current = word
            if lines.count() >= maxLines then return lines
        end if
    end for

    if current <> "" and lines.count() < maxLines then
        lines.Push(current)
    end if

    return lines
end function

sub renderCircuitFacts(f1 as Dynamic)
    if f1.circuitLocation <> invalid and f1.circuitLocation <> "" then
        m.trackLocationLabel.text = f1.circuitLocation
    else if f1.country <> invalid and f1.country <> "" then
        m.trackLocationLabel.text = f1.country
    else
        m.trackLocationLabel.text = ""
    end if

    stats = ""
    lengthValue = valueOrDash(f1.circuitLengthKm)
    if lengthValue <> "--" and lengthValue <> "null" then
        stats = lengthValue + " km"
    end if

    lapsValue = valueOrDash(f1.laps)
    if lapsValue <> "--" and lapsValue <> "null" then
        lapsText = lapsValue + " laps"
        if stats <> "" then
            stats = stats + "  " + Chr(183) + "  " + lapsText
        else
            stats = lapsText
        end if
    end if

    m.trackStatsLabel.text = stats
end sub
