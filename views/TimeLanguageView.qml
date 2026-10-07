import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Item {
  id: root
  anchors.fill: parent

  property string pluginPath: (Quickshell.env("HOME") || "/home/ac") + "/.config/omarchy/plugins/ac.control-panel"
  onPluginPathChanged: refresh()

  property var panelRoot: null
  property bool activeFocusSection: false
  readonly property bool isContentFocused: root.panelRoot ? (root.panelRoot.focusSection === "content") : root.activeFocusSection
  property int focusedCard: 0 // 0..9
  property int clockFormatFocusIndex: -1
  property int timezoneFocusIndex: -1
  property int layoutPresetFocusIndex: -1
  property int shortcutFocusIndex: -1
  onFocusedCardChanged: {
    ensureCardVisible(focusedCard)
    if (focusedCard !== 0) clockFormatFocusIndex = currentClockFormatIndex()
    if (focusedCard !== 2) timezoneFocusIndex = currentTimezoneIndex()
    if (focusedCard !== 6) layoutPresetFocusIndex = currentPresetIndex()
    if (focusedCard !== 7) shortcutFocusIndex = currentShortcutIndex()
  }

  readonly property bool hasActiveInput: (cityField && cityField.activeFocus) || (customLayoutField && customLayoutField.activeFocus)

  onActiveFocusSectionChanged: {
    if (!activeFocusSection) {
      blurInput()
    }
  }

  function blurInput() {
    if (cityField) cityField.focus = false
    if (customLayoutField) customLayoutField.focus = false
  }

  property string statusMessage: ""

  // State properties
  property string currentTime: "--:--"
  property string currentDate: "Loading date..."
  property string currentTimezone: "UTC"
  onCurrentTimezoneChanged: timezoneFocusIndex = currentTimezoneIndex()
  property string currentTimezoneOffset: ""
  property bool ntpActive: true
  property string clockFormat: "dddd HH:mm"
  property bool is24Hour: true
  onIs24HourChanged: clockFormatFocusIndex = currentClockFormatIndex()
  property bool hasSeconds: false

  property string locationName: "Auto-detecting..."
  property bool isAutoLocation: true
  property string customCity: ""
  property string weatherStatus: ""

  property string kbLayout: "us"
  onKbLayoutChanged: layoutPresetFocusIndex = currentPresetIndex()
  property string kbVariant: ""
  property string kbOptions: ""
  property var configuredLayouts: ["us"]
  property string activeLayout: "English (US)"
  property int activeLayoutIndex: 0
  property string kbDeviceName: ""
  property string switchShortcut: "none"
  onSwitchShortcutChanged: shortcutFocusIndex = currentShortcutIndex()

  property string systemLocale: "en_US.UTF-8"
  property var installedLocales: ["en_US.utf8"]
  property bool fcitxActive: false

  // Layout Presets list
  readonly property var layoutPresets: [
    { id: "us", label: "US English", layouts: "us", variants: "" },
    { id: "us_bg", label: "US + Bulgarian (Phonetic)", layouts: "us,bg", variants: ",phonetic" },
    { id: "us_de", label: "US + German", layouts: "us,de", variants: "" },
    { id: "us_fr", label: "US + French", layouts: "us,fr", variants: "" },
    { id: "us_es", label: "US + Spanish", layouts: "us,es", variants: "" },
    { id: "us_dk", label: "US + Danish", layouts: "us,dk", variants: "" },
    { id: "us_it", label: "US + Italian", layouts: "us,it", variants: "" }
  ]

  // Switching Shortcuts list
  readonly property var shortcutOptions: [
    { id: "alt_shift", label: "Alt + Shift", code: "alt_shift" },
    { id: "win_space", label: "Super + Space", code: "win_space" },
    { id: "alts", label: "Left Alt + Right Alt", code: "alts" },
    { id: "caps", label: "Caps Lock", code: "caps" },
    { id: "ctrl_shift", label: "Ctrl + Shift", code: "ctrl_shift" }
  ]

  // Common Timezone Presets
  readonly property var timezonePresets: [
    { label: "Sofia", tz: "Europe/Sofia" },
    { label: "London", tz: "Europe/London" },
    { label: "Paris", tz: "Europe/Paris" },
    { label: "New York", tz: "America/New_York" },
    { label: "Tokyo", tz: "Asia/Tokyo" },
    { label: "UTC", tz: "UTC" }
  ]

  // Curated database for instant city suggestions & autocomplete
  readonly property var cityDatabase: [
    // Bulgaria & Balkans
    { name: "Sofia", country: "Bulgaria", tag: "BG" },
    { name: "Plovdiv", country: "Bulgaria", tag: "BG" },
    { name: "Varna", country: "Bulgaria", tag: "BG" },
    { name: "Burgas", country: "Bulgaria", tag: "BG" },
    { name: "Ruse", country: "Bulgaria", tag: "BG" },
    { name: "Stara Zagora", country: "Bulgaria", tag: "BG" },
    { name: "Pleven", country: "Bulgaria", tag: "BG" },
    { name: "Veliko Tarnovo", country: "Bulgaria", tag: "BG" },
    { name: "Blagoevgrad", country: "Bulgaria", tag: "BG" },
    { name: "Bucharest", country: "Romania", tag: "RO" },
    { name: "Belgrade", country: "Serbia", tag: "RS" },
    { name: "Athens", country: "Greece", tag: "GR" },
    { name: "Thessaloniki", country: "Greece", tag: "GR" },
    { name: "Skopje", country: "North Macedonia", tag: "MK" },
    { name: "Zagreb", country: "Croatia", tag: "HR" },
    { name: "Sarajevo", country: "Bosnia", tag: "BA" },
    { name: "Istanbul", country: "Turkey", tag: "TR" },

    // Western & Central Europe
    { name: "London", country: "United Kingdom", tag: "UK" },
    { name: "Manchester", country: "United Kingdom", tag: "UK" },
    { name: "Edinburgh", country: "United Kingdom", tag: "UK" },
    { name: "Paris", country: "France", tag: "FR" },
    { name: "Lyon", country: "France", tag: "FR" },
    { name: "Marseille", country: "France", tag: "FR" },
    { name: "Berlin", country: "Germany", tag: "DE" },
    { name: "Munich", country: "Germany", tag: "DE" },
    { name: "Frankfurt", country: "Germany", tag: "DE" },
    { name: "Hamburg", country: "Germany", tag: "DE" },
    { name: "Cologne", country: "Germany", tag: "DE" },
    { name: "Amsterdam", country: "Netherlands", tag: "NL" },
    { name: "Rotterdam", country: "Netherlands", tag: "NL" },
    { name: "Brussels", country: "Belgium", tag: "BE" },
    { name: "Vienna", country: "Austria", tag: "AT" },
    { name: "Zurich", country: "Switzerland", tag: "CH" },
    { name: "Geneva", country: "Switzerland", tag: "CH" },
    { name: "Madrid", country: "Spain", tag: "ES" },
    { name: "Barcelona", country: "Spain", tag: "ES" },
    { name: "Valencia", country: "Spain", tag: "ES" },
    { name: "Rome", country: "Italy", tag: "IT" },
    { name: "Milan", country: "Italy", tag: "IT" },
    { name: "Naples", country: "Italy", tag: "IT" },
    { name: "Prague", country: "Czechia", tag: "CZ" },
    { name: "Warsaw", country: "Poland", tag: "PL" },
    { name: "Krakow", country: "Poland", tag: "PL" },
    { name: "Budapest", country: "Hungary", tag: "HU" },
    { name: "Dublin", country: "Ireland", tag: "IE" },
    { name: "Lisbon", country: "Portugal", tag: "PT" },
    { name: "Porto", country: "Portugal", tag: "PT" },

    // Northern Europe
    { name: "Stockholm", country: "Sweden", tag: "SE" },
    { name: "Oslo", country: "Norway", tag: "NO" },
    { name: "Copenhagen", country: "Denmark", tag: "DK" },
    { name: "Helsinki", country: "Finland", tag: "FI" },
    { name: "Reykjavik", country: "Iceland", tag: "IS" },

    // North America
    { name: "New York", country: "United States", tag: "US" },
    { name: "Los Angeles", country: "United States", tag: "US" },
    { name: "Chicago", country: "United States", tag: "US" },
    { name: "San Francisco", country: "United States", tag: "US" },
    { name: "Seattle", country: "United States", tag: "US" },
    { name: "Austin", country: "United States", tag: "US" },
    { name: "Boston", country: "United States", tag: "US" },
    { name: "Miami", country: "United States", tag: "US" },
    { name: "Washington", country: "United States", tag: "US" },
    { name: "Toronto", country: "Canada", tag: "CA" },
    { name: "Vancouver", country: "Canada", tag: "CA" },
    { name: "Montreal", country: "Canada", tag: "CA" },

    // Asia, Pacific & Middle East
    { name: "Tokyo", country: "Japan", tag: "JP" },
    { name: "Kyoto", country: "Japan", tag: "JP" },
    { name: "Osaka", country: "Japan", tag: "JP" },
    { name: "Seoul", country: "South Korea", tag: "KR" },
    { name: "Singapore", country: "Singapore", tag: "SG" },
    { name: "Hong Kong", country: "China", tag: "HK" },
    { name: "Taipei", country: "Taiwan", tag: "TW" },
    { name: "Sydney", country: "Australia", tag: "AU" },
    { name: "Melbourne", country: "Australia", tag: "AU" },
    { name: "Auckland", country: "New Zealand", tag: "NZ" },
    { name: "Bangkok", country: "Thailand", tag: "TH" },
    { name: "Dubai", country: "United Arab Emirates", tag: "AE" },
    { name: "Tel Aviv", country: "Israel", tag: "IL" },
    { name: "Doha", country: "Qatar", tag: "QA" }
  ]

  // Filtered matching cities based on cityField input
  property int selectedCitySuggestionIndex: 0

  readonly property var matchingCities: {
    var q = (cityField ? cityField.text.trim().toLowerCase() : "")
    if (!q || q.length < 1) return []
    return cityDatabase.filter(function(c) {
      return c.name.toLowerCase().indexOf(q) !== -1 || c.country.toLowerCase().indexOf(q) !== -1
    }).slice(0, 5)
  }

  onMatchingCitiesChanged: {
    if (selectedCitySuggestionIndex >= matchingCities.length) {
      selectedCitySuggestionIndex = Math.max(0, matchingCities.length - 1)
    }
  }

  function selectCitySuggestion(cityName) {
    if (cityField) cityField.text = cityName
    root.setCustomLocation(cityName)
    if (cityField) cityField.focus = false
    if (root.panelRoot && typeof root.panelRoot.returnFocusToKeyCatcher === "function") {
      root.panelRoot.returnFocusToKeyCatcher()
    }
  }

  function currentClockFormatIndex() {
    return root.is24Hour ? 1 : 0
  }

  function currentTimezoneIndex() {
    for (var i = 0; i < timezonePresets.length; i++) {
      if (timezonePresets[i].tz === root.currentTimezone) return i
    }
    return 0
  }

  function currentPresetIndex() {
    for (var i = 0; i < layoutPresets.length; i++) {
      if (layoutPresets[i].layouts === root.kbLayout) return i
    }
    return -1
  }

  function currentShortcutIndex() {
    for (var i = 0; i < shortcutOptions.length; i++) {
      if (shortcutOptions[i].code === root.switchShortcut) return i
    }
    return 0
  }

  function ensureCardVisible(index) {
    if (!scrollArea || !scrollArea.contentItem) return
    var targets = [clockCard, secondsCard, tzCard, locCard, cityInputCard, kbActiveCard, kbPresetsCard, kbShortcutCard, customLayoutCard, langCard]
    if (index >= 0 && index < targets.length) {
      var item = targets[index]
      if (item && item.visible) {
        var flick = scrollArea.contentItem
        var pos = item.mapToItem(scrollArea, 0, 0)
        var maxScroll = Math.max(0, flick.contentHeight - flick.height)
        if (pos.y < 12) {
          flick.contentY = Math.max(0, Math.min(maxScroll, flick.contentY + pos.y - 12))
        } else if (pos.y + item.height > scrollArea.height - 12) {
          if (item.height >= scrollArea.height) {
            flick.contentY = Math.max(0, Math.min(maxScroll, flick.contentY + pos.y - 12))
          } else {
            flick.contentY = Math.max(0, Math.min(maxScroll, flick.contentY + (pos.y + item.height - scrollArea.height + 12)))
          }
        }
      }
    }
  }

  function notifyStatus(msg) {
    statusMessage = msg
    statusClearTimer.restart()
  }

  Timer {
    id: statusClearTimer
    interval: 3500
    repeat: false
    onTriggered: root.statusMessage = ""
  }


  // Live Clock Counter
  Timer {
    id: liveTimer
    interval: 1000
    repeat: true
    running: true
    onTriggered: updateLiveClock()
  }

  function updateLiveClock() {
    var now = new Date()
    var hours = now.getHours()
    var minutes = now.getMinutes()
    var seconds = now.getSeconds()
    var ampm = hours >= 12 ? "PM" : "AM"

    var pad = function(n) { return (n < 10 ? "0" : "") + n }

    if (root.is24Hour) {
      root.currentTime = pad(hours) + ":" + pad(minutes) + (root.hasSeconds ? ":" + pad(seconds) : "")
    } else {
      var h12 = hours % 12
      if (h12 === 0) h12 = 12
      root.currentTime = h12 + ":" + pad(minutes) + (root.hasSeconds ? ":" + pad(seconds) : "") + " " + ampm
    }
  }

  function refresh() {
    if (!stateProcess.running && pluginPath.length > 0) {
      stateProcess.command = [pluginPath + "/scripts/region-control.sh", "get-state"]
      stateProcess.running = true
    }
  }

  function setTimeFormat(mode) {
    actionProcess.command = [pluginPath + "/scripts/region-control.sh", "set-time-format", String(mode)]
    actionProcess.running = true
    notifyStatus("Clock format set to " + (mode === "12" ? "12-Hour (AM/PM)" : "24-Hour"))
  }

  function toggleSeconds() {
    actionProcess.command = [pluginPath + "/scripts/region-control.sh", "toggle-seconds"]
    actionProcess.running = true
    notifyStatus(root.hasSeconds ? "Seconds hidden from clock" : "Seconds enabled on clock")
  }

  function openTimezoneMenu() {
    actionProcess.command = [pluginPath + "/scripts/region-control.sh", "open-timezone-menu"]
    actionProcess.running = true
    notifyStatus("Opening Timezone selector...")
  }

  function setTimezone(tz) {
    actionProcess.command = [pluginPath + "/scripts/region-control.sh", "set-timezone", tz]
    actionProcess.running = true
    notifyStatus("Timezone set to " + tz)
  }

  function toggleAutoLocation() {
    if (root.isAutoLocation) {
      // Focus city input to enter custom city
      focusedCard = 4
      if (cityField) {
        cityField.forceActiveFocus()
        cityField.selectAll()
      }
      notifyStatus("Enter custom city name below")
    } else {
      clearCustomLocation()
    }
  }

  function setCustomLocation(city) {
    if (!city || city.trim().length === 0) {
      clearCustomLocation()
      return
    }
    actionProcess.command = [pluginPath + "/scripts/region-control.sh", "set-location", city.trim()]
    actionProcess.running = true
    notifyStatus("Weather location set to: " + city.trim())
  }

  function clearCustomLocation() {
    actionProcess.command = [pluginPath + "/scripts/region-control.sh", "clear-location"]
    actionProcess.running = true
    notifyStatus("Reverted to automatic IP geolocation")
  }

  function switchActiveLayout() {
    actionProcess.command = [pluginPath + "/scripts/region-control.sh", "switch-layout"]
    actionProcess.running = true
    notifyStatus("Switched to next keyboard layout")
  }

  function applyLayoutPreset(preset) {
    var sc = root.switchShortcut !== "none" ? root.switchShortcut : "alt_shift"
    actionProcess.command = [pluginPath + "/scripts/region-control.sh", "set-keyboard-config", preset.layouts, preset.variants || "", sc]
    actionProcess.running = true
    notifyStatus("Keyboard layout set: " + preset.label)
  }

  function cycleClockFormat(delta) {
    var cur = (clockFormatFocusIndex >= 0) ? clockFormatFocusIndex : currentClockFormatIndex()
    if (delta < 0 && cur === 0) return false
    var next = Math.max(0, Math.min(1, cur + delta))
    if (next === cur) return false
    clockFormatFocusIndex = next
    return true
  }

  function cycleTimezonePreset(delta) {
    if (timezonePresets.length === 0) return false
    var cur = (timezoneFocusIndex >= 0) ? timezoneFocusIndex : currentTimezoneIndex()
    if (delta < 0 && cur <= 0) return false
    var next = Math.max(0, Math.min(timezonePresets.length - 1, (cur < 0 ? 0 : cur) + delta))
    if (next === cur) return false
    timezoneFocusIndex = next
    return true
  }

  function cycleLayoutPreset(delta) {
    if (layoutPresets.length === 0) return false
    var cur = (layoutPresetFocusIndex >= 0) ? layoutPresetFocusIndex : currentPresetIndex()
    if (delta < 0 && cur <= 0) return false
    var next = Math.max(0, Math.min(layoutPresets.length - 1, (cur < 0 ? 0 : cur) + delta))
    if (next === cur) return false
    layoutPresetFocusIndex = next
    return true
  }

  function cycleSwitchShortcut(delta) {
    if (shortcutOptions.length === 0) return false
    var cur = (shortcutFocusIndex >= 0) ? shortcutFocusIndex : currentShortcutIndex()
    if (delta < 0 && cur === 0) return false
    var next = Math.max(0, Math.min(shortcutOptions.length - 1, cur + delta))
    if (next === cur) return false
    shortcutFocusIndex = next
    return true
  }

  function setCustomKeyboardConfig(layouts, variants) {
    var sc = root.switchShortcut !== "none" ? root.switchShortcut : "alt_shift"
    actionProcess.command = [pluginPath + "/scripts/region-control.sh", "set-keyboard-config", layouts, variants || "", sc]
    actionProcess.running = true
    notifyStatus("Custom layouts applied: " + layouts)
  }

  function launchFcitx5Config() {
    actionProcess.command = [pluginPath + "/scripts/region-control.sh", "launch-fcitx5-config"]
    actionProcess.running = true
    notifyStatus("Opening Fcitx5 Input Method configuration...")
  }

  // Keyboard navigation interface for PanelKeyCatcher
  function handleMove(dx, dy) {
    if (dy !== 0) {
      focusedCard = Math.max(0, Math.min(9, focusedCard + dy))
      ensureCardVisible(focusedCard)
      return true
    } else if (dx !== 0) {
      if (focusedCard === 0) return cycleClockFormat(dx)
      else if (focusedCard === 1) {
        if (dx < 0) return false
        toggleSeconds()
        return true
      }
      else if (focusedCard === 2) return cycleTimezonePreset(dx)
      else if (focusedCard === 3) {
        if (dx < 0) return false
        toggleAutoLocation()
        return true
      }
      else if (focusedCard === 5) {
        if (dx < 0) return false
        switchActiveLayout()
        return true
      }
      else if (focusedCard === 6) return cycleLayoutPreset(dx)
      else if (focusedCard === 7) return cycleSwitchShortcut(dx)
      else if (focusedCard === 9) {
        if (dx < 0) return false
        launchFcitx5Config()
        return true
      }
    }
    return false
  }

  function handleActivate() {
    if (focusedCard === 0) {
      var curFmt = (clockFormatFocusIndex >= 0) ? clockFormatFocusIndex : currentClockFormatIndex()
      setTimeFormat(curFmt === 1 ? "24" : "12")
    }
    else if (focusedCard === 1) toggleSeconds()
    else if (focusedCard === 2) {
      var tzIdx = (timezoneFocusIndex >= 0) ? timezoneFocusIndex : currentTimezoneIndex()
      if (tzIdx >= 0 && tzIdx < timezonePresets.length) {
        setTimezone(timezonePresets[tzIdx].tz)
      } else {
        openTimezoneMenu()
      }
    }
    else if (focusedCard === 3) toggleAutoLocation()
    else if (focusedCard === 4) {
      if (cityField) {
        cityField.forceActiveFocus()
        cityField.selectAll()
      }
    }
    else if (focusedCard === 5) switchActiveLayout()
    else if (focusedCard === 6) {
      var pIdx = (layoutPresetFocusIndex >= 0) ? layoutPresetFocusIndex : currentPresetIndex()
      if (pIdx >= 0 && layoutPresets[pIdx]) applyLayoutPreset(layoutPresets[pIdx])
    }
    else if (focusedCard === 7) {
      var sIdx = (shortcutFocusIndex >= 0) ? shortcutFocusIndex : currentShortcutIndex()
      if (shortcutOptions[sIdx]) {
        var chosen = shortcutOptions[sIdx]
        actionProcess.command = [pluginPath + "/scripts/region-control.sh", "set-keyboard-config", root.kbLayout, root.kbVariant, chosen.code]
        actionProcess.running = true
        notifyStatus("Switch shortcut: " + chosen.label)
      }
    }
    else if (focusedCard === 8) {
      if (customLayoutField) {
        customLayoutField.forceActiveFocus()
        customLayoutField.selectAll()
      }
    }
    else if (focusedCard === 9) launchFcitx5Config()
  }

  function handleTextKey(key) {
    if (hasActiveInput) return false

    var k = key.toLowerCase()
    if (k === "h") {
      focusedCard = 0
      return true
    } else if (k === "s") {
      focusedCard = 1
      toggleSeconds()
      return true
    } else if (k === "t") {
      focusedCard = 2
      return true
    } else if (k === "a") {
      focusedCard = 3
      toggleAutoLocation()
      return true
    } else if (k === "l") {
      focusedCard = 4
      if (cityField) {
        cityField.forceActiveFocus()
        cityField.selectAll()
      }
      return true
    } else if (k === "k") {
      focusedCard = 5
      switchActiveLayout()
      return true
    } else if (k === "p") {
      focusedCard = 6
      return true
    } else if (k === "w") {
      focusedCard = 7
      return true
    } else if (k === "c") {
      focusedCard = 8
      if (customLayoutField) {
        customLayoutField.forceActiveFocus()
        customLayoutField.selectAll()
      }
      return true
    } else if (k === "f") {
      focusedCard = 9
      launchFcitx5Config()
      return true
    }
    return false
  }

  Component.onCompleted: {
    refresh()
    updateLiveClock()
  }

  // Reactive state processes
  Process {
    id: stateProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var data = JSON.parse(text)
          if (data.time) root.currentTime = data.time
          if (data.date) root.currentDate = data.date
          if (data.timezone) root.currentTimezone = data.timezone
          if (data.timezoneOffset) root.currentTimezoneOffset = data.timezoneOffset
          if (data.ntpActive !== undefined) root.ntpActive = data.ntpActive === true
          if (data.clockFormat) root.clockFormat = data.clockFormat
          if (data.is24Hour !== undefined) root.is24Hour = data.is24Hour === true
          if (data.hasSeconds !== undefined) root.hasSeconds = data.hasSeconds === true
          if (data.locationName) root.locationName = data.locationName
          if (data.isAutoLocation !== undefined) root.isAutoLocation = data.isAutoLocation === true
          if (data.customCity !== undefined) {
            root.customCity = data.customCity
            if (cityField && !cityField.activeFocus) cityField.text = data.customCity
          }
          if (data.weatherStatus) root.weatherStatus = data.weatherStatus
          if (data.kbLayout) {
            root.kbLayout = data.kbLayout
            if (customLayoutField && !customLayoutField.activeFocus) customLayoutField.text = data.kbLayout
          }
          if (data.kbVariant !== undefined) root.kbVariant = data.kbVariant
          if (data.kbOptions !== undefined) root.kbOptions = data.kbOptions
          if (Array.isArray(data.configuredLayouts)) root.configuredLayouts = data.configuredLayouts
          if (data.activeLayout) root.activeLayout = data.activeLayout
          if (typeof data.activeLayoutIndex === "number") root.activeLayoutIndex = data.activeLayoutIndex
          if (data.kbDeviceName) root.kbDeviceName = data.kbDeviceName
          if (data.switchShortcut) root.switchShortcut = data.switchShortcut
          if (data.systemLocale) root.systemLocale = data.systemLocale
          if (Array.isArray(data.installedLocales)) root.installedLocales = data.installedLocales
          if (data.fcitxActive !== undefined) root.fcitxActive = data.fcitxActive === true
        } catch (e) {}
      }
    }
  }

  Process {
    id: actionProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var data = JSON.parse(text)
          if (data.time) root.currentTime = data.time
          if (data.date) root.currentDate = data.date
          if (data.timezone) root.currentTimezone = data.timezone
          if (data.timezoneOffset) root.currentTimezoneOffset = data.timezoneOffset
          if (data.ntpActive !== undefined) root.ntpActive = data.ntpActive === true
          if (data.clockFormat) root.clockFormat = data.clockFormat
          if (data.is24Hour !== undefined) root.is24Hour = data.is24Hour === true
          if (data.hasSeconds !== undefined) root.hasSeconds = data.hasSeconds === true
          if (data.locationName) root.locationName = data.locationName
          if (data.isAutoLocation !== undefined) root.isAutoLocation = data.isAutoLocation === true
          if (data.customCity !== undefined) {
            root.customCity = data.customCity
            if (cityField && !cityField.activeFocus) cityField.text = data.customCity
          }
          if (data.weatherStatus) root.weatherStatus = data.weatherStatus
          if (data.kbLayout) {
            root.kbLayout = data.kbLayout
            if (customLayoutField && !customLayoutField.activeFocus) customLayoutField.text = data.kbLayout
          }
          if (data.kbVariant !== undefined) root.kbVariant = data.kbVariant
          if (data.kbOptions !== undefined) root.kbOptions = data.kbOptions
          if (Array.isArray(data.configuredLayouts)) root.configuredLayouts = data.configuredLayouts
          if (data.activeLayout) root.activeLayout = data.activeLayout
          if (typeof data.activeLayoutIndex === "number") root.activeLayoutIndex = data.activeLayoutIndex
          if (data.kbDeviceName) root.kbDeviceName = data.kbDeviceName
          if (data.switchShortcut) root.switchShortcut = data.switchShortcut
          if (data.systemLocale) root.systemLocale = data.systemLocale
          if (Array.isArray(data.installedLocales)) root.installedLocales = data.installedLocales
          if (data.fcitxActive !== undefined) root.fcitxActive = data.fcitxActive === true
        } catch (e) {}
        if (panelRoot && typeof panelRoot.notifySettingChanged === "function") {
          panelRoot.notifySettingChanged()
        }
      }
    }
    onRunningChanged: if (!running) root.refresh()
  }

  // Watchers for reactive updates
  FileView {
    id: weatherWatcher
    path: Quickshell.env("HOME") + "/.local/state/omarchy/settings/weather.json"
    watchChanges: true
    printErrors: false
    onFileChanged: root.refresh()
  }

  FileView {
    id: shellConfigWatcher
    path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
    watchChanges: true
    printErrors: false
    onFileChanged: root.refresh()
  }

  FileView {
    id: kbToggleWatcher
    path: Quickshell.env("HOME") + "/.local/state/omarchy/toggles/hypr/keyboard-layout.lua"
    watchChanges: true
    printErrors: false
    onFileChanged: root.refresh()
  }

  ScrollView {
    id: scrollArea
    anchors.fill: parent
    clip: true
    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
    ScrollBar.vertical.policy: ScrollBar.AsNeeded

    ColumnLayout {
      width: Math.max(200, scrollArea.availableWidth - 16)
      spacing: 14

      // Status Notification Toast
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 32
        visible: root.statusMessage.length > 0
        radius: 6
        color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15)
        border.color: Color.accent
        border.width: 1

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 12
          anchors.rightMargin: 12

          Text {
            text: "✓  " + root.statusMessage
            font.family: Style.font.family
            font.pixelSize: 12
            font.bold: true
            color: Color.accent
          }
        }
      }

      // ==========================================
      // SECTION 1: TIME & DATE
      // ==========================================
      Text {
        text: "DATE & TIME"
        font.family: Style.font.family
        font.pixelSize: 11
        font.bold: true
        color: Color.accent
        Layout.topMargin: 4
      }

      // Hero Live Clock Card (Index 0)
      Rectangle {
        id: clockCard
        Layout.fillWidth: true
        implicitHeight: Math.max(90, clockInnerRow.implicitHeight + 28)
        Layout.preferredHeight: implicitHeight
        radius: Style.cornerRadius || 8
        readonly property bool isFocused: root.isContentFocused && root.focusedCard === 0
        readonly property bool isHovered: clockMouse.containsMouse
        color: isFocused ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, isHovered ? 0.08 : 0.06) : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02))
        border.color: isFocused ? Color.accent : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08))
        border.width: isFocused ? 2 : 1

        MouseArea {
          id: clockMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (root.panelRoot) root.panelRoot.focusSection = "content"
            root.focusedCard = 0
          }
        }

        RowLayout {
          id: clockInnerRow
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 14
          spacing: 16

          // Big Clock Icon / Clock Display
          Rectangle {
            width: 52
            height: 52
            radius: 10
            color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)

            Text {
              anchors.centerIn: parent
              text: "󰅐"
              font.family: Style.font.family
              font.pixelSize: 28
              color: Color.accent
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 0
            Layout.minimumWidth: 0
            spacing: 3

            Flow {
              Layout.fillWidth: true
              width: parent.width
              spacing: 8

              Text {
                text: root.currentTime
                font.family: Style.font.family
                font.pixelSize: 26
                font.bold: true
                color: Color.foreground
              }

              // Clock Format Options: 12-Hour vs 24-Hour
              RowLayout {
                spacing: 6
                Repeater {
                  model: [
                    { label: "12-Hour", is24: false },
                    { label: "24-Hour", is24: true }
                  ]
                  delegate: Rectangle {
                    height: 24
                    width: fmtText.implicitWidth + 22
                    radius: 12
                    readonly property bool isActive: (root.is24Hour === modelData.is24)
                    readonly property bool isCursorFocused: root.isContentFocused && (root.focusedCard === 0) && (((root.clockFormatFocusIndex >= 0 ? root.clockFormatFocusIndex : root.currentClockFormatIndex()) === index))
                    readonly property bool isHovered: fmtMouse.containsMouse

                    color: isActive
                      ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, isHovered ? 0.28 : 0.20)
                      : (isCursorFocused ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, isHovered ? 0.18 : 0.14) : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04)))

                    border.color: isCursorFocused
                      ? Color.accent
                      : (isActive ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60) : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.10)))
                    border.width: isCursorFocused ? 2 : 1

                    MouseArea {
                      id: fmtMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        if (root.panelRoot) root.panelRoot.focusSection = "content"
                        root.focusedCard = 0
                        root.clockFormatFocusIndex = index
                        root.setTimeFormat(modelData.is24 ? "24" : "12")
                      }
                    }

                    RowLayout {
                      anchors.centerIn: parent
                      spacing: 4
                      Rectangle {
                        visible: isActive
                        width: 5
                        height: 5
                        radius: 2.5
                        color: Color.accent
                      }
                      Text {
                        id: fmtText
                        text: modelData.label
                        font.family: Style.font.family
                        font.pixelSize: 10
                        font.bold: isActive || isCursorFocused
                        color: isActive ? Color.accent : (isCursorFocused ? Color.foreground : (isHovered ? Color.foreground : Color.muted))
                      }
                    }
                  }
                }
              }

              // NTP Badge
              Rectangle {
                width: 108
                height: 22
                radius: 5
                color: root.ntpActive ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)

                RowLayout {
                  anchors.centerIn: parent
                  spacing: 4
                  Text {
                    text: root.ntpActive ? "✓ NTP Synced" : "NTP Inactive"
                    font.family: Style.font.family
                    font.pixelSize: 10
                    font.bold: true
                    color: root.ntpActive ? Color.accent : Color.muted
                  }
                }
              }
            }

            Text {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              wrapMode: Text.WordWrap
              text: root.currentDate + "  •  " + root.currentTimezone + " (" + root.currentTimezoneOffset + ")"
              font.family: Style.font.family
              font.pixelSize: Style.font.subtext || 12
              color: Color.muted
            }
          }
        }
      }

      // Show Seconds Card (Index 1)
      Rectangle {
        id: secondsCard
        Layout.fillWidth: true
        implicitHeight: Math.max(64, secondsInnerRow.implicitHeight + 20)
        Layout.preferredHeight: implicitHeight
        radius: Style.cornerRadius || 8
        readonly property bool isFocused: root.isContentFocused && root.focusedCard === 1
        readonly property bool isHovered: secondsMouse.containsMouse
        color: isFocused ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, isHovered ? 0.08 : 0.06) : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02))
        border.color: isFocused ? Color.accent : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08))
        border.width: isFocused ? 2 : 1

        MouseArea {
          id: secondsMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (root.panelRoot) root.panelRoot.focusSection = "content"
            root.focusedCard = 1
            root.toggleSeconds()
          }
        }

        RowLayout {
          id: secondsInnerRow
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 14
          spacing: 14

          Rectangle {
            width: 38
            height: 38
            radius: 8
            color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)

            Text {
              anchors.centerIn: parent
              text: "󱑊"
              font.family: Style.font.family
              font.pixelSize: 20
              color: root.hasSeconds ? Color.accent : Color.muted
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 0
            Layout.minimumWidth: 0
            spacing: 2

            Text {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              wrapMode: Text.WordWrap
              text: "Show Seconds Counter [S]"
              font.family: Style.font.family
              font.pixelSize: Style.font.body || 13
              font.bold: true
              color: Color.foreground
            }

            Text {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              wrapMode: Text.WordWrap
              text: "Includes real-time second updates (:ss) in the top status bar"
              font.family: Style.font.family
              font.pixelSize: Style.font.subtext || 11
              color: Color.muted
            }
          }

          Rectangle {
            width: 44
            height: 24
            radius: 12
            color: root.hasSeconds ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)

            Rectangle {
              width: 18
              height: 18
              radius: 9
              anchors.verticalCenter: parent.verticalCenter
              x: root.hasSeconds ? 22 : 4
              color: root.hasSeconds ? Color.background : Color.muted
              Behavior on x { NumberAnimation { duration: 150 } }
            }
          }
        }
      }

      // Timezone Settings Card (Index 2)
      Rectangle {
        id: tzCard
        Layout.fillWidth: true
        implicitHeight: Math.max(104, tzColLayout.implicitHeight + 28)
        Layout.preferredHeight: implicitHeight
        radius: Style.cornerRadius || 8
        readonly property bool isFocused: root.isContentFocused && root.focusedCard === 2
        readonly property bool isHovered: tzMouse.containsMouse
        color: isFocused ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, isHovered ? 0.08 : 0.06) : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02))
        border.color: isFocused ? Color.accent : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08))
        border.width: isFocused ? 2 : 1

        MouseArea {
          id: tzMouse
          anchors.fill: parent
          hoverEnabled: true
          onClicked: {
            if (root.panelRoot) root.panelRoot.focusSection = "content"
            root.focusedCard = 2
          }
        }

        ColumnLayout {
          id: tzColLayout
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 14
          spacing: 10

          RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
              width: 38
              height: 38
              radius: 8
              color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)

              Text {
                anchors.centerIn: parent
                text: "󰢮"
                font.family: Style.font.family
                font.pixelSize: 20
                color: Color.accent
              }
            }

            ColumnLayout {
              Layout.fillWidth: true
              Layout.preferredWidth: 0
              spacing: 2

              Text {
                text: "System Timezone [T]"
                font.family: Style.font.family
                font.pixelSize: Style.font.body || 13
                font.bold: true
                color: Color.foreground
              }

              Text {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: "Current: " + root.currentTimezone + " (" + root.currentTimezoneOffset + ")"
                font.family: Style.font.family
                font.pixelSize: Style.font.subtext || 11
                color: Color.accent
              }
            }

            // Change Timezone Button
            Rectangle {
              Layout.preferredHeight: 30
              Layout.preferredWidth: 160
              radius: 6
              color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
              border.color: Color.accent
              border.width: 1

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.focusedCard = 2
                  root.openTimezoneMenu()
                }
              }

              RowLayout {
                anchors.centerIn: parent
                spacing: 6
                Text {
                  text: "󰍉 Change Timezone..."
                  font.family: Style.font.family
                  font.pixelSize: 11
                  font.bold: true
                  color: Color.accent
                }
              }
            }
          }

          // Quick Timezone Presets
          Flow {
            Layout.fillWidth: true
            width: parent.width
            spacing: 6

            Text {
              text: "Quick Presets:"
              font.family: Style.font.family
              font.pixelSize: 11
              color: Color.muted
              topPadding: 3
            }

            Repeater {
              model: root.timezonePresets
              delegate: Rectangle {
                height: 24
                width: presetText.implicitWidth + 22
                radius: 12
                readonly property bool isActive: (root.currentTimezone === modelData.tz)
                readonly property bool isCursorFocused: root.isContentFocused && (root.focusedCard === 2) && (((root.timezoneFocusIndex >= 0 ? root.timezoneFocusIndex : root.currentTimezoneIndex()) === index))
                readonly property bool isHovered: tzPresetMouse.containsMouse

                color: isActive
                  ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, isHovered ? 0.28 : 0.20)
                  : (isCursorFocused ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, isHovered ? 0.18 : 0.14) : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04)))

                border.color: isCursorFocused
                  ? Color.accent
                  : (isActive ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60) : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.10)))
                border.width: isCursorFocused ? 2 : 1

                MouseArea {
                  id: tzPresetMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (root.panelRoot) root.panelRoot.focusSection = "content"
                    root.focusedCard = 2
                    root.timezoneFocusIndex = index
                    root.setTimezone(modelData.tz)
                  }
                }

                RowLayout {
                  anchors.centerIn: parent
                  spacing: 4
                  Rectangle {
                    visible: isActive
                    width: 5
                    height: 5
                    radius: 2.5
                    color: Color.accent
                  }
                  Text {
                    id: presetText
                    text: modelData.label
                    font.family: Style.font.family
                    font.pixelSize: 10
                    font.bold: isActive || isCursorFocused
                    color: isActive ? Color.accent : (isCursorFocused ? Color.foreground : (isHovered ? Color.foreground : Color.muted))
                  }
                }
              }
            }
          }
        }
      }

      // ==========================================
      // SECTION 2: LOCATION & WEATHER
      // ==========================================
      Text {
        text: "LOCATION & WEATHER"
        font.family: Style.font.family
        font.pixelSize: 11
        font.bold: true
        color: Color.accent
        Layout.topMargin: 8
      }

      // Weather Location Status Card (Index 3)
      Rectangle {
        id: locCard
        Layout.fillWidth: true
        implicitHeight: Math.max(76, locInnerRow.implicitHeight + 20)
        Layout.preferredHeight: implicitHeight
        radius: Style.cornerRadius || 8
        readonly property bool isFocused: root.isContentFocused && root.focusedCard === 3
        readonly property bool isHovered: locMouse.containsMouse
        color: isFocused ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, isHovered ? 0.08 : 0.06) : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02))
        border.color: isFocused ? Color.accent : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08))
        border.width: isFocused ? 2 : 1

        MouseArea {
          id: locMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (root.panelRoot) root.panelRoot.focusSection = "content"
            root.focusedCard = 3
            root.toggleAutoLocation()
          }
        }

        RowLayout {
          id: locInnerRow
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 14
          spacing: 14

          Rectangle {
            width: 44
            height: 44
            radius: 8
            color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)

            Text {
              anchors.centerIn: parent
              text: "󰖐"
              font.family: Style.font.family
              font.pixelSize: 24
              color: Color.accent
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 0
            Layout.minimumWidth: 0
            spacing: 3

            Flow {
              Layout.fillWidth: true
              width: parent.width
              spacing: 8

              Text {
                text: "Location: " + root.locationName
                font.family: Style.font.family
                font.pixelSize: Style.font.body || 13
                font.bold: true
                color: Color.foreground
              }

              Rectangle {
                width: autoBadgeText.implicitWidth + 10
                height: 18
                radius: 4
                color: root.isAutoLocation ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)

                Text {
                  id: autoBadgeText
                  anchors.centerIn: parent
                  text: root.isAutoLocation ? "Auto IP" : "Custom City"
                  font.family: Style.font.family
                  font.pixelSize: 9
                  font.bold: true
                  color: root.isAutoLocation ? Color.accent : Color.muted
                }
              }
            }

            Text {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              wrapMode: Text.WordWrap
              text: root.weatherStatus.length > 0 ? root.weatherStatus : "Auto-detected from network IP address"
              font.family: Style.font.family
              font.pixelSize: Style.font.subtext || 11
              color: Color.muted
            }
          }

          // Toggle Button
          Rectangle {
            Layout.preferredHeight: 28
            Layout.preferredWidth: 120
            Layout.minimumWidth: 120
            radius: 5
            color: root.isAutoLocation ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
            border.color: Color.accent
            border.width: 1

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.focusedCard = 3
                root.toggleAutoLocation()
              }
            }

            Text {
              anchors.centerIn: parent
              text: root.isAutoLocation ? "Use Custom [A]" : "Use Auto IP [A]"
              font.family: Style.font.family
              font.pixelSize: 10
              font.bold: true
              color: Color.accent
            }
          }
        }
      }

      // Custom City Input Field (Index 4)
      // Custom City Input Field with Autocomplete & Quick Suggestions (Index 4)
      Rectangle {
        id: cityInputCard
        Layout.fillWidth: true
        implicitHeight: Math.max(86, cityColLayout.implicitHeight + 20)
        Layout.preferredHeight: implicitHeight
        radius: Style.cornerRadius || 8
        readonly property bool isFocused: root.isContentFocused && (root.focusedCard === 4 || (cityField && cityField.activeFocus))
        readonly property bool isHovered: cityCardMouse.containsMouse
        color: isFocused ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06) : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02))
        border.color: isFocused ? Color.accent : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08))
        border.width: isFocused ? 2 : 1

        MouseArea {
          id: cityCardMouse
          anchors.fill: parent
          hoverEnabled: true
          onClicked: {
            if (root.panelRoot) root.panelRoot.focusSection = "content"
            root.focusedCard = 4
          }
        }

        ColumnLayout {
          id: cityColLayout
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 10
          spacing: 6

          // Row 1: Input & Action Buttons
          RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            spacing: 8

            Text {
              text: "󰍎 City [L]:"
              font.family: Style.font.family
              font.pixelSize: 12
              font.bold: true
              color: (cityField && cityField.activeFocus) ? Color.accent : Color.muted
            }

            TextField {
              id: cityField
              Layout.fillWidth: true
              Layout.fillHeight: true
              Layout.minimumWidth: 80
              placeholderText: "Type city (e.g. Sofia, London, Tokyo)... [Enter]"
              text: root.customCity
              background: null
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.body || 13

              onPressed: {
                root.focusedCard = 4
              }

              onAccepted: {
                if (root.matchingCities.length > 0 && root.selectedCitySuggestionIndex >= 0 && root.selectedCitySuggestionIndex < root.matchingCities.length) {
                  root.selectCitySuggestion(root.matchingCities[root.selectedCitySuggestionIndex].name)
                } else {
                  root.selectCitySuggestion(cityField.text.trim())
                }
              }

              Keys.onEscapePressed: function(event) {
                cityField.focus = false
                if (root.panelRoot && typeof root.panelRoot.returnFocusToKeyCatcher === "function") {
                  root.panelRoot.returnFocusToKeyCatcher()
                }
                event.accepted = true
              }

              Keys.onDownPressed: function(event) {
                if (root.matchingCities.length > 0) {
                  root.selectedCitySuggestionIndex = (root.selectedCitySuggestionIndex + 1) % root.matchingCities.length
                  event.accepted = true
                } else {
                  cityField.focus = false
                  root.focusedCard = 5
                  if (root.panelRoot && typeof root.panelRoot.returnFocusToKeyCatcher === "function") {
                    root.panelRoot.returnFocusToKeyCatcher()
                  }
                  root.ensureCardVisible(5)
                  event.accepted = true
                }
              }

              Keys.onUpPressed: function(event) {
                if (root.matchingCities.length > 0) {
                  root.selectedCitySuggestionIndex = (root.selectedCitySuggestionIndex - 1 + root.matchingCities.length) % root.matchingCities.length
                  event.accepted = true
                } else {
                  cityField.focus = false
                  root.focusedCard = 3
                  if (root.panelRoot && typeof root.panelRoot.returnFocusToKeyCatcher === "function") {
                    root.panelRoot.returnFocusToKeyCatcher()
                  }
                  root.ensureCardVisible(3)
                  event.accepted = true
                }
              }

              Keys.onTabPressed: function(event) {
                event.accepted = true
                cityField.focus = false
                if (root.panelRoot && typeof root.panelRoot.toggleFocusSection === "function") {
                  root.panelRoot.toggleFocusSection()
                } else if (root.panelRoot) {
                  root.panelRoot.focusSection = "sidebar"
                  if (typeof root.panelRoot.returnFocusToKeyCatcher === "function") {
                    root.panelRoot.returnFocusToKeyCatcher()
                  }
                }
              }

              Keys.onBacktabPressed: function(event) {
                event.accepted = true
                cityField.focus = false
                if (root.panelRoot && typeof root.panelRoot.toggleFocusSection === "function") {
                  root.panelRoot.toggleFocusSection()
                } else if (root.panelRoot) {
                  root.panelRoot.focusSection = "sidebar"
                  if (typeof root.panelRoot.returnFocusToKeyCatcher === "function") {
                    root.panelRoot.returnFocusToKeyCatcher()
                  }
                }
              }
            }

            // Apply Button
            Rectangle {
              Layout.preferredHeight: 28
              Layout.preferredWidth: 54
              Layout.minimumWidth: 54
              radius: 5
              color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
              border.color: Color.accent
              border.width: 1

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (root.matchingCities.length > 0 && root.selectedCitySuggestionIndex >= 0 && root.selectedCitySuggestionIndex < root.matchingCities.length) {
                    root.selectCitySuggestion(root.matchingCities[root.selectedCitySuggestionIndex].name)
                  } else {
                    root.selectCitySuggestion(cityField.text.trim())
                  }
                }
              }

              Text {
                anchors.centerIn: parent
                text: "Apply"
                font.family: Style.font.family
                font.pixelSize: 11
                font.bold: true
                color: Color.accent
              }
            }

            // Clear Button
            Rectangle {
              Layout.preferredHeight: 28
              Layout.preferredWidth: 54
              Layout.minimumWidth: 54
              radius: 5
              visible: !root.isAutoLocation || root.customCity.length > 0
              color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  cityField.text = ""
                  root.clearCustomLocation()
                  cityField.focus = false
                  if (root.panelRoot && typeof root.panelRoot.returnFocusToKeyCatcher === "function") {
                    root.panelRoot.returnFocusToKeyCatcher()
                  }
                }
              }

              Text {
                anchors.centerIn: parent
                text: "Reset"
                font.family: Style.font.family
                font.pixelSize: 11
                color: Color.muted
              }
            }
          }

          // Row 2A: Live Autocomplete Suggestions (Visible when typing and matches found)
          ColumnLayout {
            Layout.fillWidth: true
            visible: cityField && cityField.activeFocus && root.matchingCities.length > 0
            spacing: 3

            Rectangle {
              Layout.fillWidth: true
              height: 1
              color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
            }

            Repeater {
              model: root.matchingCities

              delegate: Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                radius: 5
                color: (index === root.selectedCitySuggestionIndex) ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06)
                border.color: (index === root.selectedCitySuggestionIndex) ? Color.accent : "transparent"
                border.width: (index === root.selectedCitySuggestionIndex) ? 1 : 0

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onEntered: root.selectedCitySuggestionIndex = index
                  onClicked: root.selectCitySuggestion(modelData.name)
                }

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: 10
                  anchors.rightMargin: 10
                  spacing: 8

                  Text {
                    text: "󰍎"
                    font.family: Style.font.family
                    font.pixelSize: 13
                    color: Color.accent
                  }

                  Text {
                    text: modelData.name
                    font.family: Style.font.family
                    font.pixelSize: 12
                    font.bold: true
                    color: (index === root.selectedCitySuggestionIndex) ? Color.accent : Color.foreground
                  }

                  Rectangle {
                    Layout.preferredHeight: 16
                    Layout.preferredWidth: countryBadge.implicitWidth + 8
                    radius: 3
                    color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04)

                    Text {
                      id: countryBadge
                      anchors.centerIn: parent
                      text: modelData.country
                      font.family: Style.font.family
                      font.pixelSize: 9
                      color: Color.muted
                    }
                  }

                  Item { Layout.fillWidth: true }

                  Text {
                    text: (index === root.selectedCitySuggestionIndex) ? "Press [Enter] to Select 󰅂" : "Click to select"
                    font.family: Style.font.family
                    font.pixelSize: 10
                    color: (index === root.selectedCitySuggestionIndex) ? Color.accent : Color.muted
                  }
                }
              }
            }
          }

          // Row 2B: Quick Suggestion Chips (Visible when not actively browsing autocomplete)
          Flow {
            Layout.fillWidth: true
            width: parent.width
            visible: !(cityField && cityField.activeFocus && root.matchingCities.length > 0)
            spacing: 6

            Text {
              text: "Quick Cities:"
              font.family: Style.font.family
              font.pixelSize: 10
              font.bold: true
              color: Color.muted
              topPadding: 4
            }

              Repeater {
                model: [
                  { name: "Sofia", tag: "BG" },
                  { name: "Plovdiv", tag: "BG" },
                  { name: "Varna", tag: "BG" },
                  { name: "Burgas", tag: "BG" },
                  { name: "London", tag: "UK" },
                  { name: "Berlin", tag: "DE" },
                  { name: "Paris", tag: "FR" },
                  { name: "New York", tag: "US" },
                  { name: "Tokyo", tag: "JP" }
                ]

                delegate: Rectangle {
                  height: 24
                  width: chipLabel.implicitWidth + 14
                  radius: 4
                  color: (root.customCity === modelData.name) ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06)
                  border.color: (root.customCity === modelData.name) ? Color.accent : "transparent"
                  border.width: 1

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selectCitySuggestion(modelData.name)
                  }

                  Text {
                    id: chipLabel
                    anchors.centerIn: parent
                    text: (root.customCity === modelData.name ? "✓ " : "") + modelData.name
                    font.family: Style.font.family
                    font.pixelSize: 10
                    font.bold: root.customCity === modelData.name
                    color: (root.customCity === modelData.name) ? Color.accent : Color.foreground
                  }
                }
              }
          }
        }
      }

      // ==========================================
      // SECTION 3: KEYBOARD LAYOUTS
      // ==========================================
      Text {
        text: "KEYBOARD LAYOUTS & SWITCHING"
        font.family: Style.font.family
        font.pixelSize: 11
        font.bold: true
        color: Color.accent
        Layout.topMargin: 8
      }

      // Active Keyboard Card (Index 5)
      Rectangle {
        id: kbActiveCard
        Layout.fillWidth: true
        implicitHeight: Math.max(76, kbActiveInnerRow.implicitHeight + 20)
        Layout.preferredHeight: implicitHeight
        radius: Style.cornerRadius || 8
        readonly property bool isFocused: root.isContentFocused && root.focusedCard === 5
        readonly property bool isHovered: kbActiveMouse.containsMouse
        color: isFocused ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, isHovered ? 0.08 : 0.06) : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02))
        border.color: isFocused ? Color.accent : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08))
        border.width: isFocused ? 2 : 1

        MouseArea {
          id: kbActiveMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (root.panelRoot) root.panelRoot.focusSection = "content"
            root.focusedCard = 5
            root.switchActiveLayout()
          }
        }

        RowLayout {
          id: kbActiveInnerRow
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 14
          spacing: 14

          Rectangle {
            width: 44
            height: 44
            radius: 8
            color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)

            Text {
              anchors.centerIn: parent
              text: "󰌌"
              font.family: Style.font.family
              font.pixelSize: 24
              color: Color.accent
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 0
            Layout.minimumWidth: 0
            spacing: 2

            Flow {
              Layout.fillWidth: true
              width: parent.width
              spacing: 8
              Text {
                text: "Active: " + root.activeLayout
                font.family: Style.font.family
                font.pixelSize: Style.font.body || 13
                font.bold: true
                color: Color.foreground
              }

              Rectangle {
                width: 64
                height: 18
                radius: 4
                color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)

                Text {
                  anchors.centerIn: parent
                  text: "Layout #" + (root.activeLayoutIndex + 1)
                  font.family: Style.font.family
                  font.pixelSize: 9
                  font.bold: true
                  color: Color.accent
                }
              }
            }

            Text {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              wrapMode: Text.WordWrap
              text: "Hardware: " + (root.kbDeviceName || "Default System Keyboard") + "  •  Configured: [" + root.kbLayout + "]"
              font.family: Style.font.family
              font.pixelSize: Style.font.subtext || 11
              color: Color.muted
            }
          }

          // Switch Layout Button
          Rectangle {
            Layout.preferredHeight: 32
            Layout.preferredWidth: 120
            Layout.minimumWidth: 110
            radius: 6
            color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
            border.color: Color.accent
            border.width: 1

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.focusedCard = 5
                root.switchActiveLayout()
              }
            }

            Text {
              anchors.centerIn: parent
              text: "󰘳 Switch [K]"
              font.family: Style.font.family
              font.pixelSize: 11
              font.bold: true
              color: Color.accent
            }
          }
        }
      }

      // Layout Presets Card (Index 6)
      Rectangle {
        id: kbPresetsCard
        Layout.fillWidth: true
        implicitHeight: Math.max(90, kbPresetsCol.implicitHeight + 28)
        Layout.preferredHeight: implicitHeight
        radius: Style.cornerRadius || 8
        readonly property bool isFocused: root.isContentFocused && root.focusedCard === 6
        readonly property bool isHovered: presetsCardMouse.containsMouse
        color: isFocused ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, isHovered ? 0.08 : 0.06) : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02))
        border.color: isFocused ? Color.accent : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08))
        border.width: isFocused ? 2 : 1

        MouseArea {
          id: presetsCardMouse
          anchors.fill: parent
          hoverEnabled: true
          onClicked: {
            if (root.panelRoot) root.panelRoot.focusSection = "content"
            root.focusedCard = 6
          }
        }

        ColumnLayout {
          id: kbPresetsCol
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 14
          spacing: 8

          RowLayout {
            Layout.fillWidth: true
            Text {
              text: "Layout Presets [P] (Cycle with ←/→)"
              font.family: Style.font.family
              font.pixelSize: Style.font.body || 13
              font.bold: true
              color: Color.foreground
            }

            Item { Layout.fillWidth: true }

            Text {
              text: "Configured: " + root.kbLayout
              font.family: Style.font.family
              font.pixelSize: 11
              color: Color.accent
            }
          }

          Flow {
            Layout.fillWidth: true
            width: parent.width
            spacing: 6

            Repeater {
              model: root.layoutPresets
              delegate: Rectangle {
                height: 28
                width: pillText.implicitWidth + 24
                radius: 14
                readonly property bool isActive: (root.kbLayout === modelData.layouts)
                readonly property bool isCursorFocused: root.isContentFocused && (root.focusedCard === 6) && (((root.layoutPresetFocusIndex >= 0 ? root.layoutPresetFocusIndex : root.currentPresetIndex()) === index))
                readonly property bool isHovered: lpMouse.containsMouse

                color: isActive
                  ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, isHovered ? 0.28 : 0.20)
                  : (isCursorFocused ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, isHovered ? 0.18 : 0.14) : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04)))

                border.color: isCursorFocused
                  ? Color.accent
                  : (isActive ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60) : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.10)))
                border.width: isCursorFocused ? 2 : 1

                MouseArea {
                  id: lpMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (root.panelRoot) root.panelRoot.focusSection = "content"
                    root.focusedCard = 6
                    root.layoutPresetFocusIndex = index
                    root.applyLayoutPreset(modelData)
                  }
                }

                RowLayout {
                  anchors.centerIn: parent
                  spacing: 4
                  Rectangle {
                    visible: isActive
                    width: 5
                    height: 5
                    radius: 2.5
                    color: Color.accent
                  }
                  Text {
                    id: pillText
                    text: modelData.label
                    font.family: Style.font.family
                    font.pixelSize: 10
                    font.bold: isActive || isCursorFocused
                    color: isActive ? Color.accent : (isCursorFocused ? Color.foreground : (isHovered ? Color.foreground : Color.muted))
                  }
                }
              }
            }
          }
        }
      }

      // Layout Switch Shortcut Card (Index 7)
      Rectangle {
        id: kbShortcutCard
        Layout.fillWidth: true
        implicitHeight: Math.max(84, kbShortcutCol.implicitHeight + 28)
        Layout.preferredHeight: implicitHeight
        radius: Style.cornerRadius || 8
        readonly property bool isFocused: root.isContentFocused && root.focusedCard === 7
        readonly property bool isHovered: scCardMouse.containsMouse
        color: isFocused ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, isHovered ? 0.08 : 0.06) : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02))
        border.color: isFocused ? Color.accent : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08))
        border.width: isFocused ? 2 : 1

        MouseArea {
          id: scCardMouse
          anchors.fill: parent
          hoverEnabled: true
          onClicked: {
            if (root.panelRoot) root.panelRoot.focusSection = "content"
            root.focusedCard = 7
          }
        }

        ColumnLayout {
          id: kbShortcutCol
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 14
          spacing: 8

          RowLayout {
            Layout.fillWidth: true
            Text {
              text: "Layout Switch Shortcut [W] (Cycle with ←/→)"
              font.family: Style.font.family
              font.pixelSize: Style.font.body || 13
              font.bold: true
              color: Color.foreground
            }

            Item { Layout.fillWidth: true }

            Text {
              text: "Option: " + (root.switchShortcut !== "none" ? root.switchShortcut : "Default")
              font.family: Style.font.family
              font.pixelSize: 11
              color: Color.accent
            }
          }

          Flow {
            Layout.fillWidth: true
            width: parent.width
            spacing: 6

            Repeater {
              model: root.shortcutOptions
              delegate: Rectangle {
                height: 26
                width: scText.implicitWidth + 22
                radius: 13
                readonly property bool isActive: (root.switchShortcut === modelData.code)
                readonly property bool isCursorFocused: (root.isContentFocused && root.focusedCard === 7 && index === ((root.shortcutFocusIndex >= 0) ? root.shortcutFocusIndex : root.currentShortcutIndex()))
                readonly property bool isHovered: scMouse.containsMouse
                color: isActive
                  ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, isHovered ? 0.28 : 0.20)
                  : (isCursorFocused ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, isHovered ? 0.18 : 0.14) : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04)))
                border.color: isCursorFocused
                  ? Color.accent
                  : (isActive ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60) : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.10)))
                border.width: isCursorFocused ? 2 : 1

                MouseArea {
                  id: scMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (root.panelRoot) root.panelRoot.focusSection = "content"
                    root.focusedCard = 7
                    root.shortcutFocusIndex = index
                    actionProcess.command = [pluginPath + "/scripts/region-control.sh", "set-keyboard-config", root.kbLayout, root.kbVariant, modelData.code]
                    actionProcess.running = true
                    notifyStatus("Switch shortcut: " + modelData.label)
                  }
                }

                RowLayout {
                  anchors.centerIn: parent
                  spacing: 4
                  Rectangle {
                    visible: isActive
                    width: 5
                    height: 5
                    radius: 2.5
                    color: Color.accent
                  }
                  Text {
                    id: scText
                    text: modelData.label
                    font.family: Style.font.family
                    font.pixelSize: 10
                    font.bold: isActive || isCursorFocused
                    color: isActive ? Color.accent : (isCursorFocused ? Color.foreground : (isHovered ? Color.foreground : Color.muted))
                  }
                }
              }
            }
          }
        }
      }

      // Custom Layout Input Card (Index 8)
      Rectangle {
        id: customLayoutCard
        Layout.fillWidth: true
        implicitHeight: Math.max(86, customLayoutCol.implicitHeight + 20)
        Layout.preferredHeight: implicitHeight
        radius: Style.cornerRadius || 8
        readonly property bool isFocused: root.isContentFocused && (root.focusedCard === 8 || (customLayoutField && customLayoutField.activeFocus))
        readonly property bool isHovered: customCardMouse.containsMouse
        color: isFocused ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06) : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02))
        border.color: isFocused ? Color.accent : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08))
        border.width: isFocused ? 2 : 1

        MouseArea {
          id: customCardMouse
          anchors.fill: parent
          hoverEnabled: true
          onClicked: {
            if (root.panelRoot) root.panelRoot.focusSection = "content"
            root.focusedCard = 8
          }
        }

        ColumnLayout {
          id: customLayoutCol
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 10
          spacing: 6

          // Row 1: Custom Layout Input & Apply Button
          RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            spacing: 8

            Text {
              text: "󰌌 Custom [C]:"
              font.family: Style.font.family
              font.pixelSize: 12
              font.bold: true
              color: (customLayoutField && customLayoutField.activeFocus) ? Color.accent : Color.muted
            }

            TextField {
              id: customLayoutField
              Layout.fillWidth: true
              Layout.fillHeight: true
              Layout.minimumWidth: 80
              placeholderText: "Comma-separated layouts (e.g. us,bg,de)... [Enter]"
              text: root.kbLayout
              background: null
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.body || 13

              onPressed: {
                root.focusedCard = 8
              }

              onAccepted: {
                root.setCustomKeyboardConfig(customLayoutField.text.trim(), "")
                customLayoutField.focus = false
                if (root.panelRoot && typeof root.panelRoot.returnFocusToKeyCatcher === "function") {
                  root.panelRoot.returnFocusToKeyCatcher()
                }
              }

              Keys.onEscapePressed: function(event) {
                customLayoutField.focus = false
                if (root.panelRoot && typeof root.panelRoot.returnFocusToKeyCatcher === "function") {
                  root.panelRoot.returnFocusToKeyCatcher()
                }
                event.accepted = true
              }

              Keys.onDownPressed: function(event) {
                customLayoutField.focus = false
                root.focusedCard = 9
                if (root.panelRoot && typeof root.panelRoot.returnFocusToKeyCatcher === "function") {
                  root.panelRoot.returnFocusToKeyCatcher()
                }
                root.ensureCardVisible(9)
                event.accepted = true
              }

              Keys.onUpPressed: function(event) {
                customLayoutField.focus = false
                root.focusedCard = 7
                if (root.panelRoot && typeof root.panelRoot.returnFocusToKeyCatcher === "function") {
                  root.panelRoot.returnFocusToKeyCatcher()
                }
                root.ensureCardVisible(7)
                event.accepted = true
              }

              Keys.onTabPressed: function(event) {
                event.accepted = true
                customLayoutField.focus = false
                if (root.panelRoot && typeof root.panelRoot.toggleFocusSection === "function") {
                  root.panelRoot.toggleFocusSection()
                } else if (root.panelRoot) {
                  root.panelRoot.focusSection = "sidebar"
                  if (typeof root.panelRoot.returnFocusToKeyCatcher === "function") {
                    root.panelRoot.returnFocusToKeyCatcher()
                  }
                }
              }

              Keys.onBacktabPressed: function(event) {
                event.accepted = true
                customLayoutField.focus = false
                if (root.panelRoot && typeof root.panelRoot.toggleFocusSection === "function") {
                  root.panelRoot.toggleFocusSection()
                } else if (root.panelRoot) {
                  root.panelRoot.focusSection = "sidebar"
                  if (typeof root.panelRoot.returnFocusToKeyCatcher === "function") {
                    root.panelRoot.returnFocusToKeyCatcher()
                  }
                }
              }
            }

            Rectangle {
              Layout.preferredHeight: 28
              Layout.preferredWidth: 54
              Layout.minimumWidth: 54
              radius: 5
              color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
              border.color: Color.accent
              border.width: 1

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.setCustomKeyboardConfig(customLayoutField.text.trim(), "")
                  customLayoutField.focus = false
                  if (root.panelRoot && typeof root.panelRoot.returnFocusToKeyCatcher === "function") {
                    root.panelRoot.returnFocusToKeyCatcher()
                  }
                }
              }

              Text {
                anchors.centerIn: parent
                text: "Apply"
                font.family: Style.font.family
                font.pixelSize: 11
                font.bold: true
                color: Color.accent
              }
            }
          }

          // Row 2: Quick Suggestions Chips
          Flow {
            Layout.fillWidth: true
            width: parent.width
            spacing: 6

            Text {
              text: "Quick Presets:"
              font.family: Style.font.family
              font.pixelSize: 10
              font.bold: true
              color: Color.muted
              topPadding: 4
            }

            Repeater {
              model: [
                { label: "us", val: "us", variant: "" },
                { label: "us,bg(phonetic)", val: "us,bg", variant: ",phonetic" },
                { label: "us,de", val: "us,de", variant: "" },
                { label: "us,fr", val: "us,fr", variant: "" },
                { label: "us,es", val: "us,es", variant: "" },
                { label: "us,it", val: "us,it", variant: "" }
              ]

              delegate: Rectangle {
                height: 24
                width: kbChipText.implicitWidth + 14
                radius: 4
                color: (root.kbLayout === modelData.val) ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06)
                border.color: (root.kbLayout === modelData.val) ? Color.accent : "transparent"
                border.width: 1

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    customLayoutField.text = modelData.val
                    root.setCustomKeyboardConfig(modelData.val, modelData.variant)
                  }
                }

                Text {
                  id: kbChipText
                  anchors.centerIn: parent
                  text: (root.kbLayout === modelData.val ? "✓ " : "") + modelData.label
                  font.family: Style.font.family
                  font.pixelSize: 10
                  font.bold: root.kbLayout === modelData.val
                  color: (root.kbLayout === modelData.val) ? Color.accent : Color.foreground
                }
              }
            }
          }
        }
      }

      // ==========================================
      // SECTION 4: LANGUAGES & INPUT METHODS
      // ==========================================
      Text {
        text: "LANGUAGES & INPUT METHODS"
        font.family: Style.font.family
        font.pixelSize: 11
        font.bold: true
        color: Color.accent
        Layout.topMargin: 8
      }

      // Languages & Fcitx5 Card (Index 9)
      Rectangle {
        id: langCard
        Layout.fillWidth: true
        implicitHeight: Math.max(104, langColLayout.implicitHeight + 28)
        Layout.preferredHeight: implicitHeight
        radius: Style.cornerRadius || 8
        readonly property bool isFocused: root.isContentFocused && root.focusedCard === 9
        readonly property bool isHovered: langCardMouse.containsMouse
        color: isFocused ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, isHovered ? 0.08 : 0.06) : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02))
        border.color: isFocused ? Color.accent : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08))
        border.width: isFocused ? 2 : 1

        MouseArea {
          id: langCardMouse
          anchors.fill: parent
          hoverEnabled: true
          onClicked: {
            if (root.panelRoot) root.panelRoot.focusSection = "content"
            root.focusedCard = 9
          }
        }

        ColumnLayout {
          id: langColLayout
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 14
          spacing: 10

          RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
              width: 38
              height: 38
              radius: 8
              color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)

              Text {
                anchors.centerIn: parent
                text: "󰗊"
                font.family: Style.font.family
                font.pixelSize: 20
                color: Color.accent
              }
            }

            ColumnLayout {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              spacing: 2

              Flow {
                Layout.fillWidth: true
                width: parent.width
                spacing: 8
                Text {
                  text: "System Locale: " + root.systemLocale
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body || 13
                  font.bold: true
                  color: Color.foreground
                }

                Rectangle {
                  width: fcitxText.implicitWidth + 10
                  height: 18
                  radius: 4
                  color: root.fcitxActive ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)

                  Text {
                    id: fcitxText
                    anchors.centerIn: parent
                    text: root.fcitxActive ? "Fcitx5 Active" : "Fcitx5 Inactive"
                    font.family: Style.font.family
                    font.pixelSize: 9
                    font.bold: true
                    color: root.fcitxActive ? Color.accent : Color.muted
                  }
                }
              }

              Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                wrapMode: Text.WordWrap
                text: "Installed locales: " + root.installedLocales.join(", ")
                font.family: Style.font.family
                font.pixelSize: Style.font.subtext || 11
                color: Color.muted
              }
            }

            // Launch Fcitx5 Button
            Rectangle {
              Layout.preferredHeight: 32
              Layout.preferredWidth: 175
              Layout.minimumWidth: 150
              radius: 6
              color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
              border.color: Color.accent
              border.width: 1

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.focusedCard = 9
                  root.launchFcitx5Config()
                }
              }

              RowLayout {
                anchors.centerIn: parent
                spacing: 6

                Text {
                  text: "󰌌 Configure IMEs... [F]"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  font.bold: true
                  color: Color.accent
                }
              }
            }
          }

          // Locale info row
          Flow {
            Layout.fillWidth: true
            width: parent.width
            spacing: 6

            Text {
              text: "Locales:"
              font.family: Style.font.family
              font.pixelSize: 11
              color: Color.muted
              topPadding: 3
            }

            Repeater {
              model: root.installedLocales
              delegate: Rectangle {
                height: 22
                width: locTag.implicitWidth + 12
                radius: 4
                color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)

                Text {
                  id: locTag
                  anchors.centerIn: parent
                  text: modelData
                  font.family: Style.font.family
                  font.pixelSize: 10
                  color: Color.foreground
                }
              }
            }
          }
        }
      }

      // Bottom Spacer
      Item {
        Layout.preferredHeight: 16
      }
    }
  }
}
