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

  property int scaleFocusIndex: -1
  property int modeFocusIndex: -1
  property int nightlightTempFocusIndex: -1

  onCurrentScaleChanged: {
    if (!customScaleOpen) scaleFocusIndex = currentScaleIndex()
  }

  onActiveMonitorChanged: {
    if (!customModeOpen) modeFocusIndex = currentModeIndex()
  }

  onNightlightTempChanged: {
    nightlightTempFocusIndex = currentNightlightIndex()
  }

  readonly property bool isCustomScaleActive: {
    for (var i = 0; i < scaleOptions.length; i++) {
      if (Math.abs(root.currentScale - Number(scaleOptions[i].value)) < 0.1) {
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
    root.modeFocusIndex = root.displayModes.length
    if (root.panelRoot && typeof root.panelRoot.returnFocusToKeyCatcher === "function") {
      root.panelRoot.returnFocusToKeyCatcher()
    } else {
      root.forceActiveFocus()
    }
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
    root.scaleFocusIndex = root.scaleOptions.length
    if (root.panelRoot && typeof root.panelRoot.returnFocusToKeyCatcher === "function") {
      root.panelRoot.returnFocusToKeyCatcher()
    } else {
      root.forceActiveFocus()
    }
  }

  readonly property var scaleOptions: [
    { label: "100%", value: "1" },
    { label: "125%", value: "1.25" },
    { label: "150%", value: "1.5" },
    { label: "200%", value: "2" }
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

  readonly property var commonFallbacks: [
    { label: "2560 × 1440 (2K QHD)", w: 2560, h: 1440, tag: "2K" },
    { label: "1920 × 1080 (FHD 1080p)", w: 1920, h: 1080, tag: "1080p" },
    { label: "1280 × 720 (HD 720p)", w: 1280, h: 720, tag: "720p" },
    { label: "1024 × 768 (XGA 4:3)", w: 1024, h: 768, tag: "4:3" }
  ]

  readonly property var displayModes: {
    var list = []
    var seen = {}
    var targetHz = (activeMonitor && activeMonitor.refreshRate) ? Math.round(activeMonitor.refreshRate) : 60
    var nativeW = 0
    var nativeH = 0

    // 1. Native display mode
    if (activeMonitor && Array.isArray(activeMonitor.modes) && activeMonitor.modes.length > 0) {
      var raw = String(activeMonitor.modes[0] || "").trim()
      var clean = raw.replace(/Hz$/i, "")
      var match = clean.match(/^(\d+)x(\d+)(?:@([\d.]+))?/)
      if (match) {
        nativeW = parseInt(match[1])
        nativeH = parseInt(match[2])
        var hz = match[3] ? Math.round(parseFloat(match[3])) : targetHz
        var key = nativeW + "x" + nativeH
        seen[key] = true
        list.push({
          label: "★ Native (" + nativeW + " × " + nativeH + " @ " + hz + "Hz)",
          mode: "preferred",
          w: nativeW,
          h: nativeH,
          hz: hz,
          isNative: true
        })
      }
    }

    if (list.length === 0 && activeMonitor && activeMonitor.width && activeMonitor.height) {
      nativeW = activeMonitor.width
      nativeH = activeMonitor.height
      var mhz = activeMonitor.refreshRate ? Math.round(activeMonitor.refreshRate) : targetHz
      var mkey = nativeW + "x" + nativeH
      seen[mkey] = true
      list.push({
        label: "★ Native (" + nativeW + " × " + nativeH + " @ " + mhz + "Hz)",
        mode: "preferred",
        w: nativeW,
        h: nativeH,
        hz: mhz,
        isNative: true
      })
    }

    // 2. Add at most 1 or 2 standard lower fallback resolutions
    var fallbacksAdded = 0
    for (var j = 0; j < commonFallbacks.length && fallbacksAdded < 2; j++) {
      var fb = commonFallbacks[j]
      var k = fb.w + "x" + fb.h
      if (!seen[k] && (!nativeW || (fb.w < nativeW && fb.h <= nativeH))) {
        seen[k] = true
        list.push({
          label: fb.label,
          mode: fb.w + "x" + fb.h + "@" + targetHz,
          w: fb.w,
          h: fb.h,
          hz: targetHz,
          isNative: false
        })
        fallbacksAdded++
      }
    }

    return list
  }

  property bool activeFocusSection: false
  readonly property bool isContentFocused: {
    if (root.panelRoot && root.panelRoot.focusSection !== undefined) {
      return root.panelRoot.focusSection === "content"
    }
    return activeFocusSection
  }
  property int focusedRow: 0   // 0: Brightness, 1: Night Light Toggle, 2: Warmth, 3: Scale, 4: Resolution
  onFocusedRowChanged: {
    ensureRowVisible(focusedRow)
    if (focusedRow !== 2) nightlightTempFocusIndex = currentNightlightIndex()
    if (focusedRow !== 3 && !customScaleOpen) scaleFocusIndex = currentScaleIndex()
    if (focusedRow !== 4 && !customModeOpen) modeFocusIndex = currentModeIndex()
  }

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
    if (customScaleOpen) return scaleOptions.length
    var best = -1
    var minDiff = 999
    for (var i = 0; i < scaleOptions.length; i++) {
      var diff = Math.abs(root.currentScale - Number(scaleOptions[i].value))
      if (diff < minDiff) { minDiff = diff; best = i }
    }
    if (minDiff > 0.1) return scaleOptions.length
    return best >= 0 ? best : scaleOptions.length
  }

  function currentModeIndex() {
    if (customModeOpen) return displayModes.length
    if (!activeMonitor) return 0
    for (var i = 0; i < displayModes.length; i++) {
      if (displayModes[i].w === activeMonitor.width && displayModes[i].h === activeMonitor.height) {
        return i
      }
    }
    return displayModes.length
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

  function currentNightlightOption() {
    var idx = currentNightlightIndex()
    if (idx >= 0 && idx < nightlightOptions.length) {
      return nightlightOptions[idx]
    }
    return null
  }

  function cycleScale(delta) {
    var cur = (scaleFocusIndex >= 0) ? scaleFocusIndex : currentScaleIndex()
    if (delta < 0 && cur === 0) return false
    var next = Math.max(0, Math.min(scaleOptions.length, cur + delta))
    if (next === cur) return false
    scaleFocusIndex = next
    if (customScaleOpen && next < scaleOptions.length) {
      customScaleOpen = false
    }
    return true
  }

  function openCustomScale() {
    scaleFocusIndex = scaleOptions.length
    customScaleOpen = true
    customScaleError = ""
    if (!customScaleText && currentScale > 0) {
      customScaleText = Math.round(currentScale * 100) + "%"
    }
    Qt.callLater(function() {
      if (customScaleInputItem) {
        customScaleInputItem.forceActiveFocus()
        customScaleInputItem.selectAll()
      }
    })
  }

  function cycleMode(delta) {
    var cur = (modeFocusIndex >= 0) ? modeFocusIndex : currentModeIndex()
    if (delta < 0 && cur === 0) return false
    var next = Math.max(0, Math.min(displayModes.length, cur + delta))
    if (next === cur) return false
    modeFocusIndex = next
    if (customModeOpen && next < displayModes.length) {
      customModeOpen = false
    }
    return true
  }

  function openCustomMode() {
    modeFocusIndex = displayModes.length
    customModeOpen = true
    customModeError = ""
    if (!customModeText && activeMonitor) {
      customModeText = activeMonitor.width + "x" + activeMonitor.height + "@" + Math.round(activeMonitor.refreshRate || 60)
    }
    Qt.callLater(function() {
      if (customModeInputItem) {
        customModeInputItem.forceActiveFocus()
        customModeInputItem.selectAll()
      }
    })
  }

  function cycleNightlightTemp(delta) {
    var cur = (nightlightTempFocusIndex >= 0) ? nightlightTempFocusIndex : currentNightlightIndex()
    if (delta < 0 && cur === 0) return false
    var next = Math.max(0, Math.min(nightlightOptions.length - 1, cur + delta))
    if (next === cur) return false
    nightlightTempFocusIndex = next
    return true
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
      if (focusedRow === 0) {
        if (dx < 0 && root.brightness <= 5) return false
        adjustBrightness(dx * 5)
        return true
      }
      else if (focusedRow === 1) {
        if (dx < 0) return false
        toggleNightlight()
        return true
      }
      else if (focusedRow === 2) return cycleNightlightTemp(dx)
      else if (focusedRow === 3) return cycleScale(dx)
      else if (focusedRow === 4) return cycleMode(dx)
    }
    return false
  }

  function handleActivate() {
    if (hasActiveInput) return
    if (focusedRow === 0) adjustBrightness(5)
    else if (focusedRow === 1) toggleNightlight()
    else if (focusedRow === 2) {
      var curTemp = (nightlightTempFocusIndex >= 0) ? nightlightTempFocusIndex : currentNightlightIndex()
      if (curTemp >= 0 && curTemp < nightlightOptions.length) {
        setNightlightTemp(nightlightOptions[curTemp].temp)
      }
    }
    else if (focusedRow === 3) {
      var curScale = (scaleFocusIndex >= 0) ? scaleFocusIndex : currentScaleIndex()
      if (curScale === scaleOptions.length) {
        if (customScaleOpen) {
          applyCustomScale()
        } else {
          openCustomScale()
        }
      } else if (curScale >= 0 && curScale < scaleOptions.length) {
        setScale(scaleOptions[curScale].value)
      }
    } else if (focusedRow === 4) {
      var curMode = (modeFocusIndex >= 0) ? modeFocusIndex : currentModeIndex()
      if (curMode === displayModes.length) {
        if (customModeOpen) {
          applyCustomMode()
        } else {
          openCustomMode()
        }
      } else if (curMode >= 0 && curMode < displayModes.length) {
        setMode(displayModes[curMode].mode)
      }
    }
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
    } else if (key === "c" || key === "C") {
      if (focusedRow === 3) {
        scaleFocusIndex = scaleOptions.length
        openCustomScale()
        return true
      } else if (focusedRow === 4) {
        modeFocusIndex = displayModes.length
        openCustomMode()
        return true
      }
    } else if (key === "h" || key === "H") {
      return handleMove(-1, 0)
    } else if (key === "l" || key === "L") {
      return handleMove(1, 0)
    } else if (key >= "1" && key <= "4") {
      var n = parseInt(key) - 1
      if (focusedRow === 3 && n < scaleOptions.length) {
        scaleFocusIndex = n
        customScaleOpen = false
        setScale(scaleOptions[n].value)
        return true
      } else if (focusedRow === 4 && n < displayModes.length) {
        modeFocusIndex = n
        customModeOpen = false
        setMode(displayModes[n].mode)
        return true
      }
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
    root.customScaleOpen = false
    var targetNum = Number(scaleVal)
    var foundIdx = -1
    for (var i = 0; i < scaleOptions.length; i++) {
      if (Math.abs(targetNum - Number(scaleOptions[i].value)) < 0.1) {
        foundIdx = i
        break
      }
    }
    root.scaleFocusIndex = (foundIdx >= 0) ? foundIdx : root.currentScaleIndex()
    var mon = activeMonitor ? activeMonitor.name : ""
    setScaleProcess.command = [pluginPath + "/scripts/display-control.sh", "set-scale", String(scaleVal), mon]
    setScaleProcess.running = true
    notifyStatus("Scale set to " + scaleVal + "x")
  }

  function setMode(modeVal) {
    if (!activeMonitor) return
    root.customModeOpen = false
    var foundIdx = -1
    for (var i = 0; i < displayModes.length; i++) {
      if (displayModes[i].mode === modeVal || (displayModes[i].isNative && (modeVal === "preferred" || modeVal === displayModes[i].mode))) {
        foundIdx = i
        break
      }
    }
    root.modeFocusIndex = (foundIdx >= 0) ? foundIdx : root.currentModeIndex()
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

  Timer {
    id: scaleRefreshTimer
    interval: 250
    repeat: false
    onTriggered: {
      root.refresh()
      if (panelRoot && typeof panelRoot.notifySettingChanged === "function") {
        panelRoot.notifySettingChanged()
      }
    }
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
        scaleRefreshTimer.restart()
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
        scaleRefreshTimer.restart()
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
        color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
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
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04)
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
            color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)

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
                color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)

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
        readonly property bool isFocused: root.isContentFocused && root.focusedRow === 0
        readonly property bool isHovered: brightnessMouseArea.containsMouse
        color: brightnessCard.isFocused ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.07) : (brightnessCard.isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.05) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02))
        border.color: brightnessCard.isFocused ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35) : (brightnessCard.isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.20) : "transparent")
        border.width: 1

        MouseArea {
          id: brightnessMouseArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.focusedRow = 0
            if (root.panelRoot) root.panelRoot.focusSection = "content"
          }
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
                  if (root.panelRoot) root.panelRoot.focusSection = "content"
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
                  if (root.panelRoot) root.panelRoot.focusSection = "content"
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
        readonly property bool isFocused: root.isContentFocused && root.focusedRow === 1
        readonly property bool isHovered: nightlightToggleMouseArea.containsMouse
        color: nightlightToggleCard.isFocused ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.07) : (nightlightToggleCard.isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.05) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02))
        border.color: nightlightToggleCard.isFocused ? Color.accent : (nightlightToggleCard.isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.20) : "transparent")
        border.width: nightlightToggleCard.isFocused ? 2 : 1

        MouseArea {
          id: nightlightToggleMouseArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.focusedRow = 1
            if (root.panelRoot) root.panelRoot.focusSection = "content"
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
            color: root.nightlightEnabled ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)

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
            color: root.nightlightEnabled ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.10)
            border.color: (nightlightToggleCard.isFocused || nightlightToggleCard.isHovered) ? Color.accent : "transparent"
            border.width: nightlightToggleCard.isFocused ? 2 : (nightlightToggleCard.isHovered ? 1 : 0)

            Text {
              anchors.centerIn: parent
              text: root.nightlightEnabled ? "ACTIVE" : "OFF"
              font.family: Style.font.family
              font.pixelSize: 11
              font.bold: true
              color: root.nightlightEnabled ? "#000000" : (nightlightToggleCard.isFocused || nightlightToggleCard.isHovered ? Color.foreground : Color.muted)
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
        readonly property bool isFocused: root.isContentFocused && root.focusedRow === 2
        readonly property bool isHovered: nightlightTempMouseArea.containsMouse
        color: nightlightTempCard.isFocused ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.07) : (nightlightTempCard.isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.05) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02))
        border.color: nightlightTempCard.isFocused ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35) : (nightlightTempCard.isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.20) : "transparent")
        border.width: 1

        MouseArea {
          id: nightlightTempMouseArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.focusedRow = 2
            if (root.panelRoot) root.panelRoot.focusSection = "content"
          }
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

                Rectangle {
                  height: 20
                  width: activeNlTempText.implicitWidth + 12
                  radius: 4
                  color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
                  border.color: Color.accent
                  border.width: 1

                  Text {
                    id: activeNlTempText
                    anchors.centerIn: parent
                    text: {
                      var opt = root.currentNightlightOption()
                      return opt ? opt.label : (root.nightlightTemp + "K")
                    }
                    font.family: Style.font.family
                    font.pixelSize: 10
                    font.bold: true
                    color: Color.accent
                  }
                }

                Text {
                  visible: nightlightTempCard.isFocused
                  text: "• Use [←/→ or h/l] to navigate • [Enter/Space] to set"
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
                  if (root.panelRoot) root.panelRoot.focusSection = "content"
                  var cur = (root.nightlightTempFocusIndex >= 0) ? root.nightlightTempFocusIndex : root.currentNightlightIndex()
                  var next = Math.max(0, cur - 1)
                  root.nightlightTempFocusIndex = next
                  root.setNightlightTemp(root.nightlightOptions[next].temp)
                }
              }

              Button {
                text: "▶"
                implicitWidth: 32
                implicitHeight: 32
                bordered: true
                onClicked: {
                  root.focusedRow = 2
                  if (root.panelRoot) root.panelRoot.focusSection = "content"
                  var cur = (root.nightlightTempFocusIndex >= 0) ? root.nightlightTempFocusIndex : root.currentNightlightIndex()
                  var next = Math.min(root.nightlightOptions.length - 1, cur + 1)
                  root.nightlightTempFocusIndex = next
                  root.setNightlightTemp(root.nightlightOptions[next].temp)
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
                id: nlOptionCard
                width: nightlightFlow.itemWidth
                height: 34
                radius: 6
                readonly property bool isActive: Math.abs(root.nightlightTemp - modelData.temp) < 200
                readonly property bool isFocused: root.isContentFocused && (root.focusedRow === 2) && ((root.nightlightTempFocusIndex >= 0 ? root.nightlightTempFocusIndex : root.currentNightlightIndex()) === index)
                readonly property bool isHovered: nlMouseArea.containsMouse

                color: {
                  if (isActive) {
                    return isHovered ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.28)
                                     : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
                  }
                  if (isFocused) {
                    return isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.18)
                                     : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.14)
                  }
                  if (isHovered) {
                    return Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
                  }
                  return Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.03)
                }

                border.color: {
                  if (isFocused) {
                    return Color.accent
                  }
                  if (isActive) {
                    return Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.6)
                  }
                  if (isHovered) {
                    return Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28)
                  }
                  return Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
                }
                border.width: isFocused ? 2 : 1

                MouseArea {
                  id: nlMouseArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.focusedRow = 2
                    root.nightlightTempFocusIndex = index
                    if (root.panelRoot) root.panelRoot.focusSection = "content"
                    root.setNightlightTemp(modelData.temp)
                  }
                }

                RowLayout {
                  anchors.centerIn: parent
                  spacing: 4

                  Rectangle {
                    visible: nlOptionCard.isActive
                    width: 5
                    height: 5
                    radius: 2.5
                    color: Color.accent
                  }

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.label
                    font.family: Style.font.family
                    font.pixelSize: 11
                    font.bold: nlOptionCard.isActive || nlOptionCard.isFocused
                    color: nlOptionCard.isActive ? Color.accent : (nlOptionCard.isFocused || nlOptionCard.isHovered ? Color.foreground : Color.muted)
                  }
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
        readonly property bool isFocused: root.isContentFocused && root.focusedRow === 3
        readonly property bool isHovered: scaleCardMouseArea.containsMouse
        color: scaleCard.isFocused ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.07) : (scaleCard.isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.05) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02))
        border.color: scaleCard.isFocused ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35) : (scaleCard.isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.20) : "transparent")
        border.width: 1

        MouseArea {
          id: scaleCardMouseArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.focusedRow = 3
            if (root.panelRoot) root.panelRoot.focusSection = "content"
          }
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

                Rectangle {
                  height: 20
                  width: activeScaleText.implicitWidth + 12
                  radius: 4
                  color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
                  border.color: Color.accent
                  border.width: 1

                  Text {
                    id: activeScaleText
                    anchors.centerIn: parent
                    text: Math.round(root.currentScale * 100) + "%"
                    font.family: Style.font.family
                    font.pixelSize: 10
                    font.bold: true
                    color: Color.accent
                  }
                }

                Text {
                  visible: scaleCard.isFocused
                  text: "• Use [←/→ or h/l] to navigate • [Enter/Space] to set"
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
                  if (root.panelRoot) root.panelRoot.focusSection = "content"
                  var cur = (root.scaleFocusIndex >= 0) ? root.scaleFocusIndex : root.currentScaleIndex()
                  var next = Math.max(0, cur - 1)
                  root.scaleFocusIndex = next
                  if (next < root.scaleOptions.length) {
                    root.customScaleOpen = false
                    root.setScale(root.scaleOptions[next].value)
                  }
                }
              }

              Button {
                text: "▶"
                implicitWidth: 32
                implicitHeight: 32
                bordered: true
                onClicked: {
                  root.focusedRow = 3
                  if (root.panelRoot) root.panelRoot.focusSection = "content"
                  var cur = (root.scaleFocusIndex >= 0) ? root.scaleFocusIndex : root.currentScaleIndex()
                  var next = Math.min(root.scaleOptions.length - 1, cur + 1)
                  root.scaleFocusIndex = next
                  root.customScaleOpen = false
                  root.setScale(root.scaleOptions[next].value)
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
                id: scaleOptionCard
                width: scaleFlow.itemWidth
                height: 34
                radius: 6
                readonly property bool isActive: Math.abs(root.currentScale - Number(modelData.value)) < 0.05
                readonly property bool isFocused: root.isContentFocused && (root.focusedRow === 3) && (!root.customScaleOpen) && ((root.scaleFocusIndex >= 0 ? root.scaleFocusIndex : root.currentScaleIndex()) === index)
                readonly property bool isHovered: scaleMouseArea.containsMouse

                color: {
                  if (isActive) {
                    return isHovered ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.28)
                                     : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
                  }
                  if (isFocused) {
                    return isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.18)
                                     : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.14)
                  }
                  if (isHovered) {
                    return Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
                  }
                  return Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.03)
                }

                border.color: {
                  if (isFocused) {
                    return Color.accent
                  }
                  if (isActive) {
                    return Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.6)
                  }
                  if (isHovered) {
                    return Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28)
                  }
                  return Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
                }
                border.width: isFocused ? 2 : 1

                MouseArea {
                  id: scaleMouseArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.focusedRow = 3
                    root.scaleFocusIndex = index
                    root.customScaleOpen = false
                    if (root.panelRoot) root.panelRoot.focusSection = "content"
                    root.setScale(modelData.value)
                  }
                }

                RowLayout {
                  anchors.centerIn: parent
                  spacing: 4

                  Rectangle {
                    visible: scaleOptionCard.isActive
                    width: 5
                    height: 5
                    radius: 2.5
                    color: Color.accent
                  }

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.label
                    font.family: Style.font.family
                    font.pixelSize: 11
                    font.bold: scaleOptionCard.isActive || scaleOptionCard.isFocused
                    color: scaleOptionCard.isActive ? Color.accent : (scaleOptionCard.isFocused || scaleOptionCard.isHovered ? Color.foreground : Color.muted)
                  }
                }
              }
            }

            // Custom Scale Option Card
            Rectangle {
              id: customScaleChip
              width: Math.max(scaleFlow.itemWidth, 90)
              height: 34
              radius: 6
              readonly property bool isActive: root.isCustomScaleActive
              readonly property bool isFocused: root.isContentFocused && (root.focusedRow === 3) && (root.customScaleOpen || ((root.scaleFocusIndex >= 0 ? root.scaleFocusIndex : root.currentScaleIndex()) === root.scaleOptions.length))
              readonly property bool isHovered: customScaleMouse.containsMouse

              color: {
                if (isActive) {
                  return isHovered ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.28)
                                   : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
                }
                if (isFocused) {
                  return isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.18)
                                   : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.14)
                }
                if (isHovered) {
                  return Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
                }
                return Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.03)
              }

              border.color: {
                if (isFocused) {
                  return Color.accent
                }
                if (isActive) {
                  return Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.6)
                }
                if (isHovered) {
                  return Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28)
                }
                return Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
              }
              border.width: isFocused ? 2 : 1

              MouseArea {
                id: customScaleMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.focusedRow = 3
                  if (root.panelRoot) root.panelRoot.focusSection = "content"
                  if (root.customScaleOpen) {
                    root.customScaleOpen = false
                    root.scaleFocusIndex = root.currentScaleIndex()
                  } else {
                    root.openCustomScale()
                  }
                }
              }

              RowLayout {
                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.width - 8)
                spacing: 4

                Rectangle {
                  visible: customScaleChip.isActive
                  width: 5
                  height: 5
                  radius: 2.5
                  color: Color.accent
                }

                Text {
                  text: "󰍹"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  color: customScaleChip.isActive ? Color.accent : (customScaleChip.isFocused || customScaleChip.isHovered ? Color.foreground : Color.muted)
                }

                Text {
                  Layout.fillWidth: true
                  elide: Text.ElideRight
                  horizontalAlignment: Text.AlignHCenter
                  text: root.isCustomScaleActive ? ("Custom: " + Math.round(root.currentScale * 100) + "%") : "Custom..."
                  font.family: Style.font.family
                  font.pixelSize: 11
                  font.bold: customScaleChip.isActive || customScaleChip.isFocused
                  color: customScaleChip.isActive ? Color.accent : (customScaleChip.isFocused || customScaleChip.isHovered ? Color.foreground : Color.muted)
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
              color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12)
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: 8

              Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                radius: 6
                color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.05)
                border.color: (customScaleInput.activeFocus) ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
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
                      root.customScaleError = ""
                      root.scaleFocusIndex = root.currentScaleIndex()
                      if (root.panelRoot && typeof root.panelRoot.returnFocusToKeyCatcher === "function") {
                        root.panelRoot.returnFocusToKeyCatcher()
                      } else {
                        root.forceActiveFocus()
                      }
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
                  root.scaleFocusIndex = root.currentScaleIndex()
                  if (root.panelRoot && typeof root.panelRoot.returnFocusToKeyCatcher === "function") {
                    root.panelRoot.returnFocusToKeyCatcher()
                  }
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
        readonly property bool isFocused: root.isContentFocused && root.focusedRow === 4
        readonly property bool isHovered: modeCardMouseArea.containsMouse
        color: modeCard.isFocused ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.07) : (modeCard.isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.05) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02))
        border.color: modeCard.isFocused ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35) : (modeCard.isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.20) : "transparent")
        border.width: 1

        MouseArea {
          id: modeCardMouseArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.focusedRow = 4
            if (root.panelRoot) root.panelRoot.focusSection = "content"
          }
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
                  color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
                  border.color: Color.accent
                  border.width: 1

                  Text {
                    id: activeResLabel
                    anchors.centerIn: parent
                    text: {
                      if (!activeMonitor) return ""
                      var res = activeMonitor.width + " × " + activeMonitor.height + (activeMonitor.refreshRate ? (" @ " + activeMonitor.refreshRate + "Hz") : "")
                      if (root.displayModes.length > 0 && root.displayModes[0].isNative && activeMonitor.width === root.displayModes[0].w && activeMonitor.height === root.displayModes[0].h) {
                        return "★ Native (" + res + ")"
                      }
                      return res
                    }
                    font.family: Style.font.family
                    font.pixelSize: 10
                    font.bold: true
                    color: Color.accent
                  }
                }

                Text {
                  visible: modeCard.isFocused
                  text: "• Use [←/→ or h/l] to navigate • [Enter/Space] to set"
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
                  if (root.panelRoot) root.panelRoot.focusSection = "content"
                  var cur = (root.modeFocusIndex >= 0) ? root.modeFocusIndex : root.currentModeIndex()
                  var next = Math.max(0, cur - 1)
                  root.modeFocusIndex = next
                  if (next < root.displayModes.length) {
                    root.customModeOpen = false
                    root.setMode(root.displayModes[next].mode)
                  }
                }
              }

              Button {
                text: "▶"
                implicitWidth: 32
                implicitHeight: 32
                bordered: true
                onClicked: {
                  root.focusedRow = 4
                  if (root.panelRoot) root.panelRoot.focusSection = "content"
                  var cur = (root.modeFocusIndex >= 0) ? root.modeFocusIndex : root.currentModeIndex()
                  var next = Math.min(root.displayModes.length - 1, cur + 1)
                  root.modeFocusIndex = next
                  root.customModeOpen = false
                  root.setMode(root.displayModes[next].mode)
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
                id: modeOptionCard
                width: modeFlow.itemWidth
                height: 34
                radius: 6
                readonly property bool isActive: (root.currentModeIndex() === index)
                readonly property bool isFocused: root.isContentFocused && (root.focusedRow === 4) && (!root.customModeOpen) && ((root.modeFocusIndex >= 0 ? root.modeFocusIndex : root.currentModeIndex()) === index)
                readonly property bool isHovered: modeMouseArea.containsMouse

                color: {
                  if (isActive) {
                    return isHovered ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.28)
                                     : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
                  }
                  if (isFocused) {
                    return isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.18)
                                     : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.14)
                  }
                  if (isHovered) {
                    return Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
                  }
                  return Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.03)
                }

                border.color: {
                  if (isFocused) {
                    return Color.accent
                  }
                  if (isActive) {
                    return Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.6)
                  }
                  if (isHovered) {
                    return Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28)
                  }
                  return Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
                }
                border.width: isFocused ? 2 : 1

                MouseArea {
                  id: modeMouseArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.focusedRow = 4
                    root.modeFocusIndex = index
                    root.customModeOpen = false
                    if (root.panelRoot) root.panelRoot.focusSection = "content"
                    root.setMode(modelData.mode)
                  }
                }

                RowLayout {
                  anchors.centerIn: parent
                  width: Math.min(implicitWidth, parent.width - 8)
                  spacing: 4

                  Rectangle {
                    visible: modeOptionCard.isActive
                    width: 5
                    height: 5
                    radius: 2.5
                    color: Color.accent
                  }

                  Text {
                    visible: modelData.isNative
                    text: "★"
                    font.family: Style.font.family
                    font.pixelSize: 11
                    color: modeOptionCard.isActive ? Color.accent : "#e5c890"
                  }

                  Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    horizontalAlignment: modelData.isNative ? Text.AlignLeft : Text.AlignHCenter
                    text: modelData.label
                    font.family: Style.font.family
                    font.pixelSize: 11
                    font.bold: modeOptionCard.isActive || modeOptionCard.isFocused || modelData.isNative
                    color: modeOptionCard.isActive ? Color.accent : (modeOptionCard.isFocused || modeOptionCard.isHovered ? Color.foreground : (modelData.isNative ? Color.foreground : Color.muted))
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
              readonly property bool isActive: root.isCustomModeActive
              readonly property bool isFocused: root.isContentFocused && (root.focusedRow === 4) && (root.customModeOpen || ((root.modeFocusIndex >= 0 ? root.modeFocusIndex : root.currentModeIndex()) === root.displayModes.length))
              readonly property bool isHovered: customModeMouse.containsMouse

              color: {
                if (isActive) {
                  return isHovered ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.28)
                                   : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
                }
                if (isFocused) {
                  return isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.18)
                                   : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.14)
                }
                if (isHovered) {
                  return Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
                }
                return Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.03)
              }

              border.color: {
                if (isFocused) {
                  return Color.accent
                }
                if (isActive) {
                  return Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.6)
                }
                if (isHovered) {
                  return Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28)
                }
                return Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
              }
              border.width: isFocused ? 2 : 1

              MouseArea {
                id: customModeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.focusedRow = 4
                  if (root.panelRoot) root.panelRoot.focusSection = "content"
                  if (root.customModeOpen) {
                    root.customModeOpen = false
                    root.modeFocusIndex = root.currentModeIndex()
                  } else {
                    root.openCustomMode()
                  }
                }
              }

              RowLayout {
                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.width - 8)
                spacing: 5

                Rectangle {
                  visible: customModeChip.isActive
                  width: 5
                  height: 5
                  radius: 2.5
                  color: Color.accent
                }

                Text {
                  text: "󰒓"
                  font.family: Style.font.family
                  font.pixelSize: 12
                  color: customModeChip.isActive ? Color.accent : (customModeChip.isFocused || customModeChip.isHovered ? Color.foreground : Color.muted)
                }

                Text {
                  Layout.fillWidth: true
                  elide: Text.ElideRight
                  horizontalAlignment: Text.AlignHCenter
                  text: root.isCustomModeActive ? ("Custom: " + (activeMonitor ? (activeMonitor.width + "×" + activeMonitor.height) : "Active")) : "Custom Mode..."
                  font.family: Style.font.family
                  font.pixelSize: 11
                  font.bold: customModeChip.isActive || customModeChip.isFocused
                  color: customModeChip.isActive ? Color.accent : (customModeChip.isFocused || customModeChip.isHovered ? Color.foreground : Color.muted)
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
              color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12)
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: 8

              Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                radius: 6
                color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.05)
                border.color: (customModeInput.activeFocus) ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
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
                      root.customModeError = ""
                      root.modeFocusIndex = root.currentModeIndex()
                      if (root.panelRoot && typeof root.panelRoot.returnFocusToKeyCatcher === "function") {
                        root.panelRoot.returnFocusToKeyCatcher()
                      } else {
                        root.forceActiveFocus()
                      }
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
                  root.modeFocusIndex = root.currentModeIndex()
                  if (root.panelRoot && typeof root.panelRoot.returnFocusToKeyCatcher === "function") {
                    root.panelRoot.returnFocusToKeyCatcher()
                  }
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
