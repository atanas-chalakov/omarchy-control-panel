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

  property string pluginPath: "/home/ac/.config/omarchy/plugins/ac.control-panel"
  onPluginPathChanged: refresh()
  property var panelRoot: null
  property int brightness: 100
  property var monitors: []
  property var activeMonitor: monitors.length > 0 ? monitors[0] : null
  property real currentScale: activeMonitor ? Number(activeMonitor.scale) : 1.0
  property bool nightlightEnabled: false
  property int nightlightTemp: 4000
  property string statusMessage: ""

  property bool customModeOpen: false
  property string customModeText: ""
  property string customModeError: ""
  property Item customModeInputItem: null

  property bool customScaleOpen: false
  property string customScaleText: ""
  property string customScaleError: ""
  property Item customScaleInputItem: null

  readonly property bool isCustomScaleActive: {
    for (var i = 0; i < scaleOptions.length; i++) {
      if (Math.abs(root.currentScale - Number(scaleOptions[i].value)) < 0.05) {
        return false
      }
    }
    return true
  }

  readonly property bool isCustomModeActive: {
    if (!activeMonitor) return false
    for (var i = 0; i < displayModes.length; i++) {
      if (activeMonitor.width === displayModes[i].w && activeMonitor.height === displayModes[i].h) {
        return false
      }
    }
    return true
  }

  readonly property bool hasActiveInput: (customModeOpen && customModeInputItem && customModeInputItem.activeFocus) || (customScaleOpen && customScaleInputItem && customScaleInputItem.activeFocus)

  onActiveFocusSectionChanged: {
    if (!activeFocusSection) {
      blurInput()
    }
  }

  function focusToInput() {
    if (customModeOpen && customModeInputItem) {
      customModeInputItem.forceActiveFocus()
    } else if (customScaleOpen && customScaleInputItem) {
      customScaleInputItem.forceActiveFocus()
    }
  }

  function blurInput() {
    if (customModeInputItem) customModeInputItem.focus = false
    if (customScaleInputItem) customScaleInputItem.focus = false
  }

  function applyCustomMode() {
    var raw = root.customModeText.trim()
    if (raw === "") {
      root.customModeError = "Please enter a resolution mode (e.g. 1920x1080@144 or preferred)"
      return
    }
    var valid = (raw === "preferred" || raw === "highrr" || raw === "highres" || /^(\d+)x(\d+)(?:@([\d.]+))?$/.test(raw))
    if (!valid) {
      root.customModeError = "Invalid mode format. Use WIDTHxHEIGHT[@HZ] (e.g. 1920x1080@144) or 'preferred'"
      return
    }
    root.customModeError = ""
    root.setMode(raw)
    root.customModeOpen = false
  }

  function applyCustomScale() {
    var raw = root.customScaleText.trim()
    if (raw === "") {
      root.customScaleError = "Please enter a scale factor (e.g. 1.25 or 125%)"
      return
    }
    var num = NaN
    if (raw.endsWith("%")) {
      num = parseFloat(raw.replace("%", "")) / 100.0
    } else {
      num = parseFloat(raw)
    }
    if (isNaN(num) || num < 0.25 || num > 4.0) {
      root.customScaleError = "Scale must be between 0.25 (25%) and 4.0 (400%)"
      return
    }
    num = Math.round(num * 100) / 100
    root.customScaleError = ""
    root.setScale(String(num))
    root.customScaleOpen = false
  }

  readonly property var scaleOptions: [
    { label: "100%", value: "1" },
    { label: "110%", value: "1.1" },
    { label: "115%", value: "1.15" },
    { label: "125%", value: "1.25" },
    { label: "133%", value: "1.33" },
    { label: "150%", value: "1.5" },
    { label: "160%", value: "1.6" },
    { label: "175%", value: "1.75" },
    { label: "200%", value: "2" },
    { label: "225%", value: "2.25" }
  ]

  readonly property var nightlightOptions: [
    { label: "2500K (Candle)", temp: 2500 },
    { label: "3000K (Amber)", temp: 3000 },
    { label: "3500K (Warmest)", temp: 3500 },
    { label: "4000K (Warm)", temp: 4000 },
    { label: "4500K (Mild)", temp: 4500 },
    { label: "5000K (Normal)", temp: 5000 },
    { label: "5500K (Neutral)", temp: 5500 },
    { label: "6000K (Cool)", temp: 6000 },
    { label: "6500K (Daylight)", temp: 6500 }
  ]

  readonly property var standardResolutions: [
    { label: "3840 × 2160 (4K UHD)", w: 3840, h: 2160, tag: "4K" },
    { label: "3440 × 1440 (UWQHD 21:9)", w: 3440, h: 1440, tag: "UW" },
    { label: "2560 × 1600 (WQXGA 16:10)", w: 2560, h: 1600, tag: "16:10" },
    { label: "2560 × 1440 (QHD 2K)", w: 2560, h: 1440, tag: "2K" },
    { label: "2560 × 1080 (UW-FHD 21:9)", w: 2560, h: 1080, tag: "UW" },
    { label: "1920 × 1200 (WUXGA 16:10)", w: 1920, h: 1200, tag: "16:10" },
    { label: "1920 × 1080 (FHD 1080p)", w: 1920, h: 1080, tag: "FHD" },
    { label: "1680 × 1050 (WSXGA+ 16:10)", w: 1680, h: 1050, tag: "16:10" },
    { label: "1600 × 900 (HD+)", w: 1600, h: 900, tag: "HD+" },
    { label: "1440 × 900 (WXGA+ 16:10)", w: 1440, h: 900, tag: "16:10" },
    { label: "1366 × 768 (FWXGA)", w: 1366, h: 768, tag: "WXGA" },
    { label: "1280 × 800 (WXGA 16:10)", w: 1280, h: 800, tag: "16:10" },
    { label: "1280 × 720 (HD 720p)", w: 1280, h: 720, tag: "HD" },
    { label: "1024 × 768 (XGA 4:3)", w: 1024, h: 768, tag: "4:3" }
  ]

  readonly property var displayModes: {
    var list = []
    var seen = {}
    var targetHz = (activeMonitor && activeMonitor.refreshRate) ? activeMonitor.refreshRate : 60

    if (activeMonitor && Array.isArray(activeMonitor.modes)) {
      for (var i = 0; i < activeMonitor.modes.length; i++) {
        var raw = String(activeMonitor.modes[i] || "").trim()
        var clean = raw.replace(/Hz$/i, "")
        var match = clean.match(/^(\d+)x(\d+)(?:@([\d.]+))?/)
        if (match) {
          var w = parseInt(match[1])
          var h = parseInt(match[2])
          var hz = match[3] ? Math.round(parseFloat(match[3])) : targetHz
          var key = w + "x" + h
          if (!seen[key]) {
            seen[key] = true
            list.push({
              label: "★ Native (" + w + " × " + h + " @ " + hz + "Hz)",
              mode: clean,
              w: w,
              h: h,
              hz: hz,
              isNative: true
            })
          }
        }
      }
    }

    if (activeMonitor && (!Array.isArray(activeMonitor.modes) || activeMonitor.modes.length === 0) && activeMonitor.width && activeMonitor.height) {
      var mw = activeMonitor.width
      var mh = activeMonitor.height
      var mhz = activeMonitor.refreshRate ? Math.round(activeMonitor.refreshRate) : targetHz
      var mkey = mw + "x" + mh
      seen[mkey] = true
      list.push({
        label: "★ Native (" + mw + " × " + mh + " @ " + mhz + "Hz)",
        mode: mw + "x" + mh + "@" + mhz,
        w: mw,
        h: mh,
        hz: mhz,
        isNative: true
      })
    }

    for (var j = 0; j < standardResolutions.length; j++) {
      var item = standardResolutions[j]
      var k = item.w + "x" + item.h
      if (!seen[k]) {
        seen[k] = true
        var modeStr = item.w + "x" + item.h + "@" + targetHz
        list.push({
          label: item.label,
          mode: modeStr,
          w: item.w,
          h: item.h,
          hz: targetHz,
          isNative: false
        })
      }
    }

    return list
  }

  property bool activeFocusSection: false
  property int focusedRow: 0   // 0: Brightness, 1: Night Light Toggle, 2: Warmth, 3: Scale, 4: Resolution
  onFocusedRowChanged: ensureRowVisible(focusedRow)

  function ensureRowVisible(index) {
    if (!scrollArea || !scrollArea.contentItem) return
    var targets = [brightnessCard, nightlightToggleCard, nightlightTempCard, scaleCard, modeCard]
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

  function currentScaleIndex() {
    var best = 0
    var minDiff = 999
    for (var i = 0; i < scaleOptions.length; i++) {
      var diff = Math.abs(root.currentScale - Number(scaleOptions[i].value))
      if (diff < minDiff) { minDiff = diff; best = i }
    }
    return best
  }

  function currentModeIndex() {
    if (!activeMonitor) return 0
    for (var i = 0; i < displayModes.length; i++) {
      if (displayModes[i].w === activeMonitor.width && displayModes[i].h === activeMonitor.height) {
        return i
      }
    }
    return 0
  }

  function currentNightlightIndex() {
    var best = 1
    var minDiff = 99999
    for (var i = 0; i < nightlightOptions.length; i++) {
      var diff = Math.abs(root.nightlightTemp - nightlightOptions[i].temp)
      if (diff < minDiff) { minDiff = diff; best = i }
    }
    return best
  }

  function cycleScale(delta) {
    var idx = currentScaleIndex()
    var next = Math.max(0, Math.min(scaleOptions.length - 1, idx + delta))
    setScale(scaleOptions[next].value)
  }

  function cycleMode(delta) {
    var idx = currentModeIndex()
    var next = Math.max(0, Math.min(displayModes.length - 1, idx + delta))
    setMode(displayModes[next].mode)
  }

  function cycleNightlightTemp(delta) {
    var idx = currentNightlightIndex()
    var next = Math.max(0, Math.min(nightlightOptions.length - 1, idx + delta))
    setNightlightTemp(nightlightOptions[next].temp)
  }

  function adjustBrightness(delta) {
    var val = Math.max(5, Math.min(100, root.brightness + delta))
    setBrightness(val)
  }

  function handleMove(dx, dy) {
    if (hasActiveInput) return true
    if (dy !== 0) {
      focusedRow = Math.max(0, Math.min(4, focusedRow + dy))
      ensureRowVisible(focusedRow)
      return true
    }
    if (dx !== 0) {
      if (focusedRow === 0) adjustBrightness(dx * 5)
      else if (focusedRow === 1) toggleNightlight()
      else if (focusedRow === 2) cycleNightlightTemp(dx)
      else if (focusedRow === 3) cycleScale(dx)
      else if (focusedRow === 4) cycleMode(dx)
      return true
    }
    return false
  }

  function handleActivate() {
    if (hasActiveInput) return
    if (focusedRow === 0) adjustBrightness(5)
    else if (focusedRow === 1) toggleNightlight()
    else if (focusedRow === 2) cycleNightlightTemp(1)
    else if (focusedRow === 3) cycleScale(1)
    else if (focusedRow === 4) cycleMode(1)
  }

  function handleTextKey(key) {
    if (hasActiveInput) return false
    if (key === "r" || key === "R") {
      refresh()
      return true
    } else if (key === "b" || key === "B") {
      focusedRow = 0
      return true
    } else if (key === "n" || key === "N") {
      focusedRow = 1
      toggleNightlight()
      return true
    } else if (key === "w" || key === "W") {
      focusedRow = 2
      return true
    } else if (key === "s" || key === "S") {
      focusedRow = 3
      return true
    } else if (key === "m" || key === "M") {
      focusedRow = 4
      return true
    } else if (key === "h" || key === "H") {
      if (focusedRow === 0) adjustBrightness(-5)
      else if (focusedRow === 1) toggleNightlight()
      else if (focusedRow === 2) cycleNightlightTemp(-1)
      else if (focusedRow === 3) cycleScale(-1)
      else if (focusedRow === 4) cycleMode(-1)
      return true
    } else if (key === "l" || key === "L") {
      if (focusedRow === 0) adjustBrightness(5)
      else if (focusedRow === 1) toggleNightlight()
      else if (focusedRow === 2) cycleNightlightTemp(1)
      else if (focusedRow === 3) cycleScale(1)
      else if (focusedRow === 4) cycleMode(1)
      return true
    }
    return false
  }

  function refresh() {
    if (!stateProcess.running && pluginPath.length > 0) {
      stateProcess.command = [pluginPath + "/scripts/display-control.sh", "get-state"]
      stateProcess.running = true
    }
  }

  function setBrightness(val) {
    var p = Math.round(val)
    root.brightness = p
    setBrightnessProcess.command = [pluginPath + "/scripts/display-control.sh", "set-brightness", String(p)]
    setBrightnessProcess.running = true
    notifyStatus("Brightness: " + p + "%")
  }

  function toggleNightlight() {
    root.nightlightEnabled = !root.nightlightEnabled
    setNightlightToggleProcess.command = [pluginPath + "/scripts/display-control.sh", "set-nightlight-toggle"]
    setNightlightToggleProcess.running = true
    notifyStatus(root.nightlightEnabled ? "Night Light Enabled" : "Night Light Disabled")
  }

  function setNightlightTemp(temp) {
    root.nightlightTemp = temp
    setNightlightTempProcess.command = [pluginPath + "/scripts/display-control.sh", "set-nightlight-temp", String(temp)]
    setNightlightTempProcess.running = true
    notifyStatus("Warmth: " + temp + "K")
  }

  function setScale(scaleVal) {
    setScaleProcess.command = [pluginPath + "/scripts/display-control.sh", "set-scale", String(scaleVal)]
    setScaleProcess.running = true
    notifyStatus("Scale set to " + scaleVal + "x")
  }

  function setMode(modeVal) {
    if (!activeMonitor) return
    setModeProcess.command = [
      pluginPath + "/scripts/display-control.sh",
      "set-mode",
      activeMonitor.name,
      modeVal,
      String(activeMonitor.scale || 1)
    ]
    setModeProcess.running = true
    notifyStatus("Resolution: " + modeVal)
  }

  function notifyStatus(msg) {
    statusMessage = msg
    statusClearTimer.restart()
  }

  Timer {
    id: statusClearTimer
    interval: 3000
    repeat: false
    onTriggered: root.statusMessage = ""
  }

  Component.onCompleted: refresh()

  // State Process
  Process {
    id: stateProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var data = JSON.parse(text)
          if (data.brightness !== undefined) root.brightness = data.brightness
          if (Array.isArray(data.monitors)) root.monitors = data.monitors
          if (data.nightlight) {
            root.nightlightEnabled = data.nightlight.enabled === true
            if (data.nightlight.temperature !== undefined && data.nightlight.temperature !== null) {
              root.nightlightTemp = Number(data.nightlight.temperature)
            }
          }
        } catch (e) {
          console.warn("DisplaysView: JSON parse error", e)
        }
      }
    }
  }

  // Set Brightness Process
  Process {
    id: setBrightnessProcess
    onRunningChanged: {
      if (!running && panelRoot && typeof panelRoot.notifySettingChanged === "function") {
        panelRoot.notifySettingChanged()
      }
    }
  }

  // Set Nightlight Toggle Process
  Process {
    id: setNightlightToggleProcess
    onRunningChanged: {
      if (!running) {
        root.refresh()
        if (panelRoot && typeof panelRoot.notifySettingChanged === "function") {
          panelRoot.notifySettingChanged()
        }
      }
    }
  }

  // Set Nightlight Temp Process
  Process {
    id: setNightlightTempProcess
    onRunningChanged: {
      if (!running) {
        root.refresh()
        if (panelRoot && typeof panelRoot.notifySettingChanged === "function") {
          panelRoot.notifySettingChanged()
        }
      }
    }
  }

  // Set Scale Process
  Process {
    id: setScaleProcess
    onRunningChanged: {
      if (!running) {
        root.refresh()
        if (panelRoot && typeof panelRoot.notifySettingChanged === "function") {
          panelRoot.notifySettingChanged()
        }
      }
    }
  }

  // Set Mode Process
  Process {
    id: setModeProcess
    onRunningChanged: {
      if (!running) {
        root.refresh()
        if (panelRoot && typeof panelRoot.notifySettingChanged === "function") {
          panelRoot.notifySettingChanged()
        }
      }
    }
  }

  ScrollView {
    id: scrollArea
    anchors.fill: parent
    clip: true
    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
    ScrollBar.vertical.policy: ScrollBar.AsNeeded

    ColumnLayout {
      width: Math.max(200, scrollArea.availableWidth - 12)
      spacing: 14

      // Status Notification Toast
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 32
        visible: root.statusMessage.length > 0
        radius: 6
        color: Color.pickAlpha("accent.subtle", "#1f3b30")
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

      // Display Hero Card
      Rectangle {
        id: displayHeroCard
        Layout.fillWidth: true
        implicitHeight: Math.max(76, displayHeroRow.implicitHeight + 28)
        Layout.preferredHeight: implicitHeight
        color: Color.pickAlpha("surface.subtle", "#181b1d")
        radius: Style.cornerRadius || 8

        RowLayout {
          id: displayHeroRow
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 14
          spacing: 14

          Rectangle {
            width: 46
            height: 46
            radius: 8
            color: Color.pickAlpha("surface.selected", "#2a3036")

            Text {
              anchors.centerIn: parent
              text: "󰍹"
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
              spacing: 8

              Text {
                text: activeMonitor ? activeMonitor.name : "Display"
                font.family: Style.font.family
                font.pixelSize: Style.font.title || 16
                font.bold: true
                color: Color.foreground
              }

              Rectangle {
                width: 72
                height: 20
                radius: 4
                color: Color.pickAlpha("accent.subtle", "#1f3b30")

                Text {
                  anchors.centerIn: parent
                  text: "Connected"
                  font.family: Style.font.family
                  font.pixelSize: 10
                  font.bold: true
                  color: Color.accent
                }
              }
            }

            Text {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              wrapMode: Text.WordWrap
              text: activeMonitor ? (activeMonitor.description || activeMonitor.model || (activeMonitor.width + "x" + activeMonitor.height + " @ " + activeMonitor.refreshRate + "Hz")) : ""
              font.family: Style.font.family
              font.pixelSize: Style.font.subtext || 12
              color: Color.muted
            }
          }

          Button {
            text: "Refresh"
            iconText: ""
            onClicked: root.refresh()
          }
        }
      }

      // Setting Row 0: Brightness Stepper & Slider Card
      Rectangle {
        id: brightnessCard
        Layout.fillWidth: true
        implicitHeight: Math.max(116, brightnessColLayout.implicitHeight + 28)
        Layout.preferredHeight: implicitHeight
        radius: Style.cornerRadius || 8
        readonly property bool isFocused: root.activeFocusSection && root.focusedRow === 0
        color: brightnessCard.isFocused ? Color.pickAlpha("surface.selected", "#22272e") : Color.pickAlpha("surface.subtle", "#181b1d")
        border.color: brightnessCard.isFocused ? Color.accent : "transparent"
        border.width: brightnessCard.isFocused ? 2 : 1

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.focusedRow = 0
        }

        ColumnLayout {
          id: brightnessColLayout
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 14
          spacing: 10

          RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
              text: "󰃠"
              font.family: Style.font.family
              font.pixelSize: 18
              color: brightnessCard.isFocused ? Color.accent : Color.foreground
            }

            ColumnLayout {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              spacing: 2

              Flow {
                Layout.fillWidth: true
                width: parent.width
                spacing: 6

                Text {
                  text: "Display Brightness"
                  font.family: Style.font.family
                  font.pixelSize: Style.font.subtitle || 14
                  font.bold: true
                  color: Color.foreground
                }

                Text {
                  visible: brightnessCard.isFocused
                  text: "• Use [←/→ or h/l] to adjust ±5%"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  color: Color.accent
                  topPadding: 2
                  width: Math.min(implicitWidth, parent.width)
                  wrapMode: Text.WordWrap
                }
              }

              Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: "Backlight screen brightness percentage."
                font.family: Style.font.family
                font.pixelSize: Style.font.subtext || 11
                color: Color.muted
                wrapMode: Text.WordWrap
              }
            }

            Text {
              text: root.brightness + "%"
              font.family: Style.font.family
              font.pixelSize: Style.font.subtitle || 14
              font.bold: true
              color: Color.accent
            }

            RowLayout {
              spacing: 6

              Button {
                text: "◀"
                implicitWidth: 32
                implicitHeight: 32
                bordered: true
                onClicked: {
                  root.focusedRow = 0
                  root.adjustBrightness(-5)
                }
              }

              Button {
                text: "▶"
                implicitWidth: 32
                implicitHeight: 32
                bordered: true
                onClicked: {
                  root.focusedRow = 0
                  root.adjustBrightness(5)
                }
              }
            }
          }

          PanelSlider {
            Layout.fillWidth: true
            minimum: 5
            maximum: 100
            step: 1
            integer: true
            value: root.brightness
            onMoved: function(v) { root.brightness = Math.round(v) }
            onReleased: function(v) { root.setBrightness(v) }
          }
        }
      }

      // Setting Row 1: Night Light Toggle Card
      Rectangle {
        id: nightlightToggleCard
        Layout.fillWidth: true
        implicitHeight: Math.max(74, nightlightToggleRowLayout.implicitHeight + 28)
        Layout.preferredHeight: implicitHeight
        radius: Style.cornerRadius || 8
        readonly property bool isFocused: root.activeFocusSection && root.focusedRow === 1
        color: nightlightToggleCard.isFocused ? Color.pickAlpha("surface.selected", "#22272e") : Color.pickAlpha("surface.subtle", "#181b1d")
        border.color: nightlightToggleCard.isFocused ? Color.accent : "transparent"
        border.width: nightlightToggleCard.isFocused ? 2 : 1

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.focusedRow = 1
            root.toggleNightlight()
          }
        }

        RowLayout {
          id: nightlightToggleRowLayout
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 14
          spacing: 14

          Rectangle {
            width: 44
            height: 44
            radius: 8
            color: root.nightlightEnabled ? Color.pickAlpha("accent.subtle", "#1f3b30") : Color.pickAlpha("surface.hover", "#20252b")

            Text {
              anchors.centerIn: parent
              text: "󰖔"
              font.family: Style.font.family
              font.pixelSize: 20
              color: root.nightlightEnabled ? Color.accent : Color.foreground
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: 2

            Flow {
              Layout.fillWidth: true
              width: parent.width
              spacing: 6

              Text {
                text: "Night Light (Blue Light Filter)"
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle || 14
                font.bold: true
                color: Color.foreground
              }

              Text {
                visible: nightlightToggleCard.isFocused
                text: "• Press [Enter/Space or n] to toggle"
                font.family: Style.font.family
                font.pixelSize: 11
                color: Color.accent
                topPadding: 2
                width: Math.min(implicitWidth, parent.width)
                wrapMode: Text.WordWrap
              }
            }

            Text {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              text: root.nightlightEnabled ? "Warmer colors active to reduce eye strain and assist sleep." : "Standard daytime color spectrum is currently active."
              font.family: Style.font.family
              font.pixelSize: Style.font.subtext || 11
              color: Color.muted
              wrapMode: Text.WordWrap
            }
          }

          Rectangle {
            Layout.preferredWidth: 90
            Layout.minimumWidth: 90
            Layout.preferredHeight: 32
            Layout.alignment: Qt.AlignVCenter
            radius: 16
            color: root.nightlightEnabled ? Color.accent : Color.pickAlpha("surface.selected", "#2a3036")
            border.color: nightlightToggleCard.isFocused ? Color.accent : "transparent"
            border.width: nightlightToggleCard.isFocused ? 2 : 0

            Text {
              anchors.centerIn: parent
              text: root.nightlightEnabled ? "ACTIVE" : "OFF"
              font.family: Style.font.family
              font.pixelSize: 11
              font.bold: true
              color: root.nightlightEnabled ? "#000000" : Color.muted
            }
          }
        }
      }

      // Setting Row 2: Night Light Warmth Stepper Card
      Rectangle {
        id: nightlightTempCard
        Layout.fillWidth: true
        implicitHeight: Math.max(116, nightlightTempColLayout.implicitHeight + 28)
        Layout.preferredHeight: implicitHeight
        radius: Style.cornerRadius || 8
        readonly property bool isFocused: root.activeFocusSection && root.focusedRow === 2
        color: nightlightTempCard.isFocused ? Color.pickAlpha("surface.selected", "#22272e") : Color.pickAlpha("surface.subtle", "#181b1d")
        border.color: nightlightTempCard.isFocused ? Color.accent : "transparent"
        border.width: nightlightTempCard.isFocused ? 2 : 1

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.focusedRow = 2
        }

        ColumnLayout {
          id: nightlightTempColLayout
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 14
          spacing: 10

          RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
              text: "󰃟"
              font.family: Style.font.family
              font.pixelSize: 18
              color: nightlightTempCard.isFocused ? Color.accent : Color.foreground
            }

            ColumnLayout {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              spacing: 2

              Flow {
                Layout.fillWidth: true
                width: parent.width
                spacing: 6

                Text {
                  text: "Color Warmth (Temperature)"
                  font.family: Style.font.family
                  font.pixelSize: Style.font.subtitle || 14
                  font.bold: true
                  color: Color.foreground
                }

                Text {
                  visible: nightlightTempCard.isFocused
                  text: "• Use [←/→ or h/l] to cycle"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  color: Color.accent
                  topPadding: 2
                  width: Math.min(implicitWidth, parent.width)
                  wrapMode: Text.WordWrap
                }
              }

              Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: "Target color warmth in Kelvin when Night Light is enabled."
                font.family: Style.font.family
                font.pixelSize: Style.font.subtext || 11
                color: Color.muted
                wrapMode: Text.WordWrap
              }
            }

            // Stepper buttons
            RowLayout {
              spacing: 6

              Button {
                text: "◀"
                implicitWidth: 32
                implicitHeight: 32
                bordered: true
                onClicked: {
                  root.focusedRow = 2
                  root.cycleNightlightTemp(-1)
                }
              }

              Button {
                text: "▶"
                implicitWidth: 32
                implicitHeight: 32
                bordered: true
                onClicked: {
                  root.focusedRow = 2
                  root.cycleNightlightTemp(1)
                }
              }
            }
          }

          // Visual segmented option cards (Responsive Flow)
          Flow {
            id: nightlightFlow
            Layout.fillWidth: true
            width: parent.width
            spacing: 8

            readonly property int count: root.nightlightOptions.length
            readonly property int minItemWidth: 105
            readonly property int cols: Math.max(1, Math.min(count, Math.floor((width + spacing) / (minItemWidth + spacing))))
            readonly property real itemWidth: Math.max(60, Math.floor((width - (cols - 1) * spacing) / cols))

            Repeater {
              model: root.nightlightOptions

              delegate: Rectangle {
                width: nightlightFlow.itemWidth
                height: 34
                radius: 6
                readonly property bool isSelected: Math.abs(root.nightlightTemp - modelData.temp) < 200
                color: isSelected ? Color.pickAlpha("accent.subtle", "#1f3b30") : Color.pickAlpha("surface.hover", "#1b1f23")
                border.color: isSelected ? Color.accent : "transparent"
                border.width: isSelected ? 1 : 0

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.focusedRow = 2
                    root.setNightlightTemp(modelData.temp)
                  }
                }

                Text {
                  anchors.centerIn: parent
                  width: Math.min(implicitWidth, parent.width - 8)
                  elide: Text.ElideRight
                  horizontalAlignment: Text.AlignHCenter
                  text: modelData.label
                  font.family: Style.font.family
                  font.pixelSize: 11
                  font.bold: isSelected
                  color: isSelected ? Color.accent : Color.foreground
                }
              }
            }
          }
        }
      }

      // Setting Row 3: Display Scaling Stepper Card
      Rectangle {
        id: scaleCard
        Layout.fillWidth: true
        implicitHeight: Math.max(116, scaleColLayout.implicitHeight + 28)
        Layout.preferredHeight: implicitHeight
        radius: Style.cornerRadius || 8
        readonly property bool isFocused: root.activeFocusSection && root.focusedRow === 3
        color: scaleCard.isFocused ? Color.pickAlpha("surface.selected", "#22272e") : Color.pickAlpha("surface.subtle", "#181b1d")
        border.color: scaleCard.isFocused ? Color.accent : "transparent"
        border.width: scaleCard.isFocused ? 2 : 1

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.focusedRow = 3
        }

        ColumnLayout {
          id: scaleColLayout
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 14
          spacing: 10

          RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
              text: "󰘵"
              font.family: Style.font.family
              font.pixelSize: 18
              color: scaleCard.isFocused ? Color.accent : Color.foreground
            }

            ColumnLayout {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              spacing: 2

              Flow {
                Layout.fillWidth: true
                width: parent.width
                spacing: 6

                Text {
                  text: "Display Scaling"
                  font.family: Style.font.family
                  font.pixelSize: Style.font.subtitle || 14
                  font.bold: true
                  color: Color.foreground
                }

                Text {
                  visible: scaleCard.isFocused
                  text: "• Use [←/→ or h/l] to cycle"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  color: Color.accent
                  topPadding: 2
                  width: Math.min(implicitWidth, parent.width)
                  wrapMode: Text.WordWrap
                }
              }

              Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: "Interface, window border, and font scale factor."
                font.family: Style.font.family
                font.pixelSize: Style.font.subtext || 11
                color: Color.muted
                wrapMode: Text.WordWrap
              }
            }

            // Stepper buttons
            RowLayout {
              spacing: 6

              Button {
                text: "◀"
                implicitWidth: 32
                implicitHeight: 32
                bordered: true
                onClicked: {
                  root.focusedRow = 3
                  root.cycleScale(-1)
                }
              }

              Button {
                text: "▶"
                implicitWidth: 32
                implicitHeight: 32
                bordered: true
                onClicked: {
                  root.focusedRow = 3
                  root.cycleScale(1)
                }
              }
            }
          }

          // Visual segmented option cards (Responsive Flow)
          Flow {
            id: scaleFlow
            Layout.fillWidth: true
            width: parent.width
            spacing: 8

            readonly property int count: root.scaleOptions.length + 1
            readonly property int minItemWidth: 64
            readonly property int cols: Math.max(1, Math.min(count, Math.floor((width + spacing) / (minItemWidth + spacing))))
            readonly property real itemWidth: Math.max(48, Math.floor((width - (cols - 1) * spacing) / cols))

            Repeater {
              model: root.scaleOptions

              delegate: Rectangle {
                width: scaleFlow.itemWidth
                height: 34
                radius: 6
                readonly property bool isSelected: Math.abs(root.currentScale - Number(modelData.value)) < 0.05
                color: isSelected ? Color.pickAlpha("accent.subtle", "#1f3b30") : Color.pickAlpha("surface.hover", "#1b1f23")
                border.color: isSelected ? Color.accent : "transparent"
                border.width: isSelected ? 1 : 0

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.focusedRow = 3
                    root.setScale(modelData.value)
                  }
                }

                Text {
                  anchors.centerIn: parent
                  width: Math.min(implicitWidth, parent.width - 8)
                  elide: Text.ElideRight
                  horizontalAlignment: Text.AlignHCenter
                  text: modelData.label
                  font.family: Style.font.family
                  font.pixelSize: 11
                  font.bold: isSelected
                  color: isSelected ? Color.accent : Color.foreground
                }
              }
            }

            // Custom Scale Option Card
            Rectangle {
              id: customScaleChip
              width: Math.max(scaleFlow.itemWidth, 90)
              height: 34
              radius: 6
              readonly property bool isSelected: root.isCustomScaleActive || root.customScaleOpen
              color: customScaleChip.isSelected ? Color.pickAlpha("accent.subtle", "#1f3b30") : Color.pickAlpha("surface.hover", "#1b1f23")
              border.color: customScaleChip.isSelected ? Color.accent : "transparent"
              border.width: customScaleChip.isSelected ? 1 : 0

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.focusedRow = 3
                  root.customScaleOpen = !root.customScaleOpen
                  if (root.customScaleOpen) {
                    root.customScaleError = ""
                    if (!root.customScaleText) {
                      root.customScaleText = Math.round(root.currentScale * 100) + "%"
                    }
                    Qt.callLater(function() {
                      if (root.customScaleInputItem) {
                        root.customScaleInputItem.forceActiveFocus()
                      }
                    })
                  }
                }
              }

              RowLayout {
                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.width - 8)
                spacing: 4

                Text {
                  text: "󰍹"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  color: customScaleChip.isSelected ? Color.accent : Color.muted
                }

                Text {
                  Layout.fillWidth: true
                  elide: Text.ElideRight
                  horizontalAlignment: Text.AlignHCenter
                  text: root.isCustomScaleActive ? ("Custom: " + Math.round(root.currentScale * 100) + "%") : "Custom..."
                  font.family: Style.font.family
                  font.pixelSize: 11
                  font.bold: customScaleChip.isSelected
                  color: customScaleChip.isSelected ? Color.accent : Color.foreground
                }
              }
            }
          }

          // Expandable Custom Scale Input
          ColumnLayout {
            visible: root.customScaleOpen
            Layout.fillWidth: true
            spacing: 6

            Rectangle {
              Layout.fillWidth: true
              height: 1
              color: Color.pickAlpha("border.subtle", "#262b30")
              opacity: 0.5
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: 8

              Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                radius: 6
                color: Color.pickAlpha("surface.selected", "#1a1f24")
                border.color: (customScaleInput.activeFocus) ? Color.accent : Color.pickAlpha("border.subtle", "#2a3036")
                border.width: (customScaleInput.activeFocus) ? 2 : 1

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: 10
                  anchors.rightMargin: 8
                  spacing: 8

                  Text {
                    text: "󰘵"
                    font.family: Style.font.family
                    font.pixelSize: 13
                    color: customScaleInput.activeFocus ? Color.accent : Color.muted
                  }

                  TextField {
                    id: customScaleInput
                    Layout.fillWidth: true
                    placeholderText: "e.g. 1.25, 118%, 1.35... [Enter to Apply]"
                    placeholderTextColor: Color.muted
                    color: Color.foreground
                    font.family: Style.font.family
                    font.pixelSize: 12
                    background: Item {}
                    text: root.customScaleText

                    Component.onCompleted: root.customScaleInputItem = customScaleInput
                    onTextChanged: {
                      if (root.customScaleText !== text) {
                        root.customScaleText = text
                        root.customScaleError = ""
                      }
                    }

                    onAccepted: root.applyCustomScale()

                    Keys.onEscapePressed: function(event) {
                      event.accepted = true
                      root.customScaleOpen = false
                    }

                    Keys.onTabPressed: function(event) {
                      event.accepted = true
                      if (root.panelRoot && typeof root.panelRoot.toggleFocusSection === "function") {
                        root.panelRoot.toggleFocusSection()
                      }
                    }

                    Keys.onBacktabPressed: function(event) {
                      event.accepted = true
                      if (root.panelRoot && typeof root.panelRoot.toggleFocusSection === "function") {
                        root.panelRoot.toggleFocusSection()
                      }
                    }
                  }
                }
              }

              Button {
                text: "Apply"
                implicitHeight: 34
                implicitWidth: 70
                bordered: true
                onClicked: root.applyCustomScale()
              }

              Button {
                text: "Cancel"
                implicitHeight: 34
                implicitWidth: 70
                bordered: true
                onClicked: {
                  root.customScaleOpen = false
                  root.customScaleError = ""
                }
              }
            }

            Text {
              visible: root.customScaleError.length > 0
              text: root.customScaleError
              font.family: Style.font.family
              font.pixelSize: 11
              color: "#ff5555"
            }

            Text {
              visible: root.customScaleError.length === 0
              text: "Enter custom scaling factor: decimal (e.g. 1.18, 1.35) or percentage (e.g. 118%, 135%)"
              font.family: Style.font.family
              font.pixelSize: 11
              color: Color.muted
            }
          }
        }
      }

      // Setting Row 4: Resolution Stepper Card
      Rectangle {
        id: modeCard
        Layout.fillWidth: true
        implicitHeight: Math.max(116, modeColLayout.implicitHeight + 28)
        Layout.preferredHeight: implicitHeight
        radius: Style.cornerRadius || 8
        readonly property bool isFocused: root.activeFocusSection && root.focusedRow === 4
        color: modeCard.isFocused ? Color.pickAlpha("surface.selected", "#22272e") : Color.pickAlpha("surface.subtle", "#181b1d")
        border.color: modeCard.isFocused ? Color.accent : "transparent"
        border.width: modeCard.isFocused ? 2 : 1

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.focusedRow = 4
        }

        ColumnLayout {
          id: modeColLayout
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 14
          spacing: 10

          RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
              text: "󰹑"
              font.family: Style.font.family
              font.pixelSize: 18
              color: modeCard.isFocused ? Color.accent : Color.foreground
            }

            ColumnLayout {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              spacing: 2

              Flow {
                Layout.fillWidth: true
                width: parent.width
                spacing: 6

                Text {
                  text: "Screen Resolution"
                  font.family: Style.font.family
                  font.pixelSize: Style.font.subtitle || 14
                  font.bold: true
                  color: Color.foreground
                }

                Rectangle {
                  visible: activeMonitor !== null
                  height: 20
                  width: activeResLabel.implicitWidth + 12
                  radius: 4
                  color: Color.pickAlpha("accent.subtle", "#1f3b30")
                  border.color: Color.accent
                  border.width: 1

                  Text {
                    id: activeResLabel
                    anchors.centerIn: parent
                    text: activeMonitor ? (activeMonitor.width + " × " + activeMonitor.height + (activeMonitor.refreshRate ? (" @ " + activeMonitor.refreshRate + "Hz") : "")) : ""
                    font.family: Style.font.family
                    font.pixelSize: 10
                    font.bold: true
                    color: Color.accent
                  }
                }

                Text {
                  visible: modeCard.isFocused
                  text: "• Use [←/→ or h/l] to cycle"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  color: Color.accent
                  topPadding: 2
                  width: Math.min(implicitWidth, parent.width)
                  wrapMode: Text.WordWrap
                }
              }

              Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: "Resolution modes configured for this display."
                font.family: Style.font.family
                font.pixelSize: Style.font.subtext || 11
                color: Color.muted
                wrapMode: Text.WordWrap
              }
            }

            // Stepper buttons
            RowLayout {
              spacing: 6

              Button {
                text: "◀"
                implicitWidth: 32
                implicitHeight: 32
                bordered: true
                onClicked: {
                  root.focusedRow = 4
                  root.cycleMode(-1)
                }
              }

              Button {
                text: "▶"
                implicitWidth: 32
                implicitHeight: 32
                bordered: true
                onClicked: {
                  root.focusedRow = 4
                  root.cycleMode(1)
                }
              }
            }
          }

          // Visual segmented option cards (Responsive Flow)
          Flow {
            id: modeFlow
            Layout.fillWidth: true
            width: parent.width
            spacing: 8

            readonly property int count: root.displayModes.length + 1
            readonly property int minItemWidth: 155
            readonly property int cols: Math.max(1, Math.min(count, Math.floor((width + spacing) / (minItemWidth + spacing))))
            readonly property real itemWidth: Math.max(90, Math.floor((width - (cols - 1) * spacing) / cols))

            Repeater {
              model: root.displayModes

              delegate: Rectangle {
                width: modeFlow.itemWidth
                height: 34
                radius: 6
                readonly property bool isSelected: {
                  if (!activeMonitor) return false
                  return activeMonitor.width === modelData.w && activeMonitor.height === modelData.h
                }
                color: isSelected ? Color.pickAlpha("accent.subtle", "#1f3b30") : Color.pickAlpha("surface.hover", "#1b1f23")
                border.color: isSelected ? Color.accent : (modelData.isNative ? Color.pickAlpha("accent.subtle", "#304036") : "transparent")
                border.width: isSelected ? 1 : (modelData.isNative ? 1 : 0)

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.focusedRow = 4
                    root.setMode(modelData.mode)
                  }
                }

                RowLayout {
                  anchors.centerIn: parent
                  width: Math.min(implicitWidth, parent.width - 8)
                  spacing: 4

                  Text {
                    visible: modelData.isNative
                    text: "★"
                    font.family: Style.font.family
                    font.pixelSize: 11
                    color: isSelected ? Color.accent : "#e5c890"
                  }

                  Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    horizontalAlignment: modelData.isNative ? Text.AlignLeft : Text.AlignHCenter
                    text: modelData.label
                    font.family: Style.font.family
                    font.pixelSize: 11
                    font.bold: isSelected || modelData.isNative
                    color: isSelected ? Color.accent : (modelData.isNative ? Color.foreground : Color.muted)
                  }
                }
              }
            }

            // Custom Mode Option Card
            Rectangle {
              id: customModeChip
              width: Math.max(modeFlow.itemWidth, 140)
              height: 34
              radius: 6
              readonly property bool isSelected: root.isCustomModeActive || root.customModeOpen
              color: customModeChip.isSelected ? Color.pickAlpha("accent.subtle", "#1f3b30") : Color.pickAlpha("surface.hover", "#1b1f23")
              border.color: customModeChip.isSelected ? Color.accent : "transparent"
              border.width: customModeChip.isSelected ? 1 : 0

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.focusedRow = 4
                  root.customModeOpen = !root.customModeOpen
                  if (root.customModeOpen) {
                    root.customModeError = ""
                    if (!root.customModeText && activeMonitor) {
                      root.customModeText = activeMonitor.width + "x" + activeMonitor.height + (activeMonitor.refreshRate ? ("@" + activeMonitor.refreshRate) : "")
                    }
                    Qt.callLater(function() {
                      if (root.customModeInputItem) {
                        root.customModeInputItem.forceActiveFocus()
                      }
                    })
                  }
                }
              }

              RowLayout {
                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.width - 8)
                spacing: 5

                Text {
                  text: "󰒓"
                  font.family: Style.font.family
                  font.pixelSize: 12
                  color: customModeChip.isSelected ? Color.accent : Color.muted
                }

                Text {
                  Layout.fillWidth: true
                  elide: Text.ElideRight
                  horizontalAlignment: Text.AlignHCenter
                  text: root.isCustomModeActive ? ("Custom: " + (activeMonitor ? (activeMonitor.width + "×" + activeMonitor.height) : "Active")) : "Custom Mode..."
                  font.family: Style.font.family
                  font.pixelSize: 11
                  font.bold: customModeChip.isSelected
                  color: customModeChip.isSelected ? Color.accent : Color.foreground
                }
              }
            }
          }

          // Expandable Custom Mode Input
          ColumnLayout {
            visible: root.customModeOpen
            Layout.fillWidth: true
            spacing: 6

            Rectangle {
              Layout.fillWidth: true
              height: 1
              color: Color.pickAlpha("border.subtle", "#262b30")
              opacity: 0.5
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: 8

              Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                radius: 6
                color: Color.pickAlpha("surface.selected", "#1a1f24")
                border.color: (customModeInput.activeFocus) ? Color.accent : Color.pickAlpha("border.subtle", "#2a3036")
                border.width: (customModeInput.activeFocus) ? 2 : 1

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: 10
                  anchors.rightMargin: 8
                  spacing: 8

                  Text {
                    text: "󰹑"
                    font.family: Style.font.family
                    font.pixelSize: 13
                    color: customModeInput.activeFocus ? Color.accent : Color.muted
                  }

                  TextField {
                    id: customModeInput
                    Layout.fillWidth: true
                    placeholderText: "e.g. 1920x1080@144, 2560x1440, preferred, highrr... [Enter to Apply]"
                    placeholderTextColor: Color.muted
                    color: Color.foreground
                    font.family: Style.font.family
                    font.pixelSize: 12
                    background: Item {}
                    text: root.customModeText

                    Component.onCompleted: root.customModeInputItem = customModeInput
                    onTextChanged: {
                      if (root.customModeText !== text) {
                        root.customModeText = text
                        root.customModeError = ""
                      }
                    }

                    onAccepted: root.applyCustomMode()

                    Keys.onEscapePressed: function(event) {
                      event.accepted = true
                      root.customModeOpen = false
                    }

                    Keys.onTabPressed: function(event) {
                      event.accepted = true
                      if (root.panelRoot && typeof root.panelRoot.toggleFocusSection === "function") {
                        root.panelRoot.toggleFocusSection()
                      }
                    }

                    Keys.onBacktabPressed: function(event) {
                      event.accepted = true
                      if (root.panelRoot && typeof root.panelRoot.toggleFocusSection === "function") {
                        root.panelRoot.toggleFocusSection()
                      }
                    }
                  }
                }
              }

              Button {
                text: "Apply"
                implicitHeight: 34
                implicitWidth: 70
                bordered: true
                onClicked: root.applyCustomMode()
              }

              Button {
                text: "Cancel"
                implicitHeight: 34
                implicitWidth: 70
                bordered: true
                onClicked: {
                  root.customModeOpen = false
                  root.customModeError = ""
                }
              }
            }

            Text {
              visible: root.customModeError.length > 0
              text: root.customModeError
              font.family: Style.font.family
              font.pixelSize: 11
              color: "#ff5555"
            }

            Text {
              visible: root.customModeError.length === 0
              text: "Enter custom resolution mode: WIDTHxHEIGHT[@REFRESH] (e.g. 1920x1080@144) or 'preferred' / 'highrr'"
              font.family: Style.font.family
              font.pixelSize: 11
              color: Color.muted
            }
          }
        }
      }

      Item { Layout.preferredHeight: 12 }
    }
  }
}
