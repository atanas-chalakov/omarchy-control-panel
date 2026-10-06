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
  property string currentProfile: "balanced"
  property int batteryCapacity: 100
  property string batteryStatus: "Unknown"
  property bool batteryPresent: false
  property bool acOnline: true
  property int screensaverTimeout: 150
  property int lockTimeout: 300
  property bool stayAwake: false
  property string statusMessage: ""

  property bool customScreensaverOpen: false
  property string customScreensaverText: ""
  property string customScreensaverError: ""
  property Item customScreensaverInputItem: null

  property bool customLockOpen: false
  property string customLockText: ""
  property string customLockError: ""
  property Item customLockInputItem: null

  property int screensaverFocusIndex: -1
  property int lockFocusIndex: -1

  onScreensaverTimeoutChanged: {
    if (!customScreensaverOpen) screensaverFocusIndex = currentScreensaverIndex()
  }

  onLockTimeoutChanged: {
    if (!customLockOpen) lockFocusIndex = currentLockIndex()
  }

  readonly property bool isCustomScreensaverActive: {
    if (root.screensaverTimeout === 0) return false
    for (var i = 0; i < screensaverOptions.length; i++) {
      if (screensaverOptions[i].seconds === root.screensaverTimeout) return false
    }
    return true
  }

  readonly property bool isCustomLockActive: {
    if (root.lockTimeout === 0) return false
    for (var j = 0; j < lockOptions.length; j++) {
      if (lockOptions[j].seconds === root.lockTimeout) return false
    }
    return true
  }

  readonly property bool hasActiveInput: (customScreensaverOpen && customScreensaverInputItem && customScreensaverInputItem.activeFocus) || (customLockOpen && customLockInputItem && customLockInputItem.activeFocus)

  onActiveFocusSectionChanged: {
    if (!activeFocusSection) {
      blurInput()
    }
  }

  function focusToInput() {
    if (customScreensaverOpen && customScreensaverInputItem) {
      customScreensaverInputItem.forceActiveFocus()
    } else if (customLockOpen && customLockInputItem) {
      customLockInputItem.forceActiveFocus()
    }
  }

  function blurInput() {
    if (customScreensaverInputItem) customScreensaverInputItem.focus = false
    if (customLockInputItem) customLockInputItem.focus = false
  }

  function applyCustomScreensaver() {
    var raw = root.customScreensaverText.trim().toLowerCase()
    if (raw === "") {
      root.customScreensaverError = "Please enter timeout minutes (e.g. 12 or 45)"
      return
    }
    var clean = raw.replace(/mins?|minutes?/g, "").trim()
    var mins = parseFloat(clean)
    if (isNaN(mins) || mins <= 0 || mins > 1440) {
      root.customScreensaverError = "Enter valid minutes between 0.5 and 1440 (24h)"
      return
    }
    var sec = Math.round(mins * 60)
    root.customScreensaverError = ""
    root.setIdle(sec, root.lockTimeout)
    root.customScreensaverOpen = false
    root.screensaverFocusIndex = root.screensaverOptions.length
    if (root.panelRoot && typeof root.panelRoot.returnFocusToKeyCatcher === "function") {
      root.panelRoot.returnFocusToKeyCatcher()
    } else {
      root.forceActiveFocus()
    }
  }

  function applyCustomLock() {
    var raw = root.customLockText.trim().toLowerCase()
    if (raw === "") {
      root.customLockError = "Please enter timeout minutes (e.g. 25 or 90)"
      return
    }
    var clean = raw.replace(/mins?|minutes?|hrs?|hours?/g, function(match) {
      return match.startsWith("h") ? " * 60" : ""
    }).trim()
    var mins = 0
    if (clean.includes("* 60")) {
      var parts = clean.split("*")
      mins = parseFloat(parts[0].trim()) * 60
    } else {
      mins = parseFloat(clean)
    }
    if (isNaN(mins) || mins <= 0 || mins > 1440) {
      root.customLockError = "Enter valid minutes between 1 and 1440 (24h)"
      return
    }
    var sec = Math.round(mins * 60)
    root.customLockError = ""
    root.setIdle(root.screensaverTimeout, sec)
    root.customLockOpen = false
    root.lockFocusIndex = root.lockOptions.length
    if (root.panelRoot && typeof root.panelRoot.returnFocusToKeyCatcher === "function") {
      root.panelRoot.returnFocusToKeyCatcher()
    } else {
      root.forceActiveFocus()
    }
  }

  readonly property var powerProfiles: [
    {
      id: "power-saver",
      title: "Power Saver",
      icon: "",
      description: "Low power draw, reduces CPU frequency to extend battery life."
    },
    {
      id: "balanced",
      title: "Balanced",
      icon: "󰾅",
      description: "Standard dynamic scaling balancing performance and power."
    },
    {
      id: "performance",
      title: "Performance",
      icon: "󰓅",
      description: "Maximum responsiveness and CPU clock speeds for heavy workloads."
    }
  ]

  readonly property var screensaverOptions: [
    { label: "1 min", seconds: 60 },
    { label: "2.5 min", seconds: 150 },
    { label: "5 min", seconds: 300 },
    { label: "15 min", seconds: 900 },
    { label: "30 min", seconds: 1800 },
    { label: "Never", seconds: 0 }
  ]

  readonly property var lockOptions: [
    { label: "2 min", seconds: 120 },
    { label: "5 min", seconds: 300 },
    { label: "15 min", seconds: 900 },
    { label: "30 min", seconds: 1800 },
    { label: "Never", seconds: 0 }
  ]

  function formatDuration(sec) {
    if (sec === 0 || sec >= 86400) return "Never"
    if (sec < 60) return sec + "s"
    var mins = Math.floor(sec / 60)
    var rem = sec % 60
    if (mins >= 60) {
      var hrs = (mins / 60).toFixed(1)
      if (hrs.endsWith(".0")) hrs = String(Math.floor(mins / 60))
      return hrs + " hr" + (hrs === "1" ? "" : "s")
    }
    if (rem > 0) return mins + "m " + rem + "s"
    return mins + " min"
  }

  property bool activeFocusSection: false
  property int focusedRow: 0   // 0: Profiles, 1: Stay Awake, 2: Screen Off, 3: Lock Screen
  onFocusedRowChanged: ensureRowVisible(focusedRow)

  function ensureRowVisible(index) {
    if (!scrollArea || !scrollArea.contentItem) return
    var targets = [profileCard, stayAwakeCard, screensaverCard, lockCard]
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

  function currentProfileIndex() {
    for (var i = 0; i < powerProfiles.length; i++) {
      if (powerProfiles[i].id === root.currentProfile) return i
    }
    return 1
  }

  function currentScreensaverIndex() {
    if (customScreensaverOpen) return screensaverOptions.length
    for (var i = 0; i < screensaverOptions.length; i++) {
      if (screensaverOptions[i].seconds === root.screensaverTimeout) return i
    }
    return screensaverOptions.length
  }

  function currentLockIndex() {
    if (customLockOpen) return lockOptions.length
    for (var i = 0; i < lockOptions.length; i++) {
      if (lockOptions[i].seconds === root.lockTimeout) return i
    }
    return lockOptions.length
  }

  function cycleProfile(delta) {
    var idx = currentProfileIndex()
    if (delta < 0 && idx === 0) return false
    var next = Math.max(0, Math.min(powerProfiles.length - 1, idx + delta))
    if (next === idx) return false
    setProfile(powerProfiles[next].id)
    return true
  }

  function cycleScreensaver(delta) {
    var cur = (screensaverFocusIndex >= 0) ? screensaverFocusIndex : currentScreensaverIndex()
    if (delta < 0 && cur === 0) return false
    var next = Math.max(0, Math.min(screensaverOptions.length, cur + delta))
    if (next === cur) return false
    screensaverFocusIndex = next
    if (next < screensaverOptions.length) {
      if (customScreensaverOpen) customScreensaverOpen = false
      setIdle(screensaverOptions[next].seconds, root.lockTimeout)
    } else {
      if (customScreensaverOpen) customScreensaverOpen = false
    }
    return true
  }

  function openCustomScreensaver() {
    screensaverFocusIndex = screensaverOptions.length
    customScreensaverOpen = true
    customScreensaverError = ""
    if (!customScreensaverText && root.screensaverTimeout > 0) {
      customScreensaverText = String(Math.round(root.screensaverTimeout / 60 * 10) / 10)
    }
    Qt.callLater(function() {
      if (customScreensaverInputItem) {
        customScreensaverInputItem.forceActiveFocus()
        customScreensaverInputItem.selectAll()
      }
    })
  }

  function cycleLock(delta) {
    var cur = (lockFocusIndex >= 0) ? lockFocusIndex : currentLockIndex()
    if (delta < 0 && cur === 0) return false
    var next = Math.max(0, Math.min(lockOptions.length, cur + delta))
    if (next === cur) return false
    lockFocusIndex = next
    if (next < lockOptions.length) {
      if (customLockOpen) customLockOpen = false
      setIdle(root.screensaverTimeout, lockOptions[next].seconds)
    } else {
      if (customLockOpen) customLockOpen = false
    }
    return true
  }

  function openCustomLock() {
    lockFocusIndex = lockOptions.length
    customLockOpen = true
    customLockError = ""
    if (!customLockText && root.lockTimeout > 0) {
      customLockText = String(Math.round(root.lockTimeout / 60 * 10) / 10)
    }
    Qt.callLater(function() {
      if (customLockInputItem) {
        customLockInputItem.forceActiveFocus()
        customLockInputItem.selectAll()
      }
    })
  }

  function handleMove(dx, dy) {
    if (hasActiveInput) return true
    if (dy !== 0) {
      focusedRow = Math.max(0, Math.min(3, focusedRow + dy))
      ensureRowVisible(focusedRow)
      return true
    }
    if (dx !== 0) {
      if (focusedRow === 0) return cycleProfile(dx)
      else if (focusedRow === 1) {
        if (dx < 0) return false
        toggleStayAwake()
        return true
      }
      else if (focusedRow === 2) return cycleScreensaver(dx)
      else if (focusedRow === 3) return cycleLock(dx)
    }
    return false
  }

  function handleActivate() {
    if (hasActiveInput) return
    if (focusedRow === 0) cycleProfile(1)
    else if (focusedRow === 1) toggleStayAwake()
    else if (focusedRow === 2) {
      var curSs = (screensaverFocusIndex >= 0) ? screensaverFocusIndex : currentScreensaverIndex()
      if (curSs === screensaverOptions.length) {
        if (customScreensaverOpen) {
          applyCustomScreensaver()
        } else {
          openCustomScreensaver()
        }
      } else {
        cycleScreensaver(1)
      }
    } else if (focusedRow === 3) {
      var curLk = (lockFocusIndex >= 0) ? lockFocusIndex : currentLockIndex()
      if (curLk === lockOptions.length) {
        if (customLockOpen) {
          applyCustomLock()
        } else {
          openCustomLock()
        }
      } else {
        cycleLock(1)
      }
    }
  }

  function handleTextKey(key) {
    if (hasActiveInput) return false
    if (key === "r" || key === "R") {
      refresh()
      return true
    } else if (key === "p" || key === "P") {
      focusedRow = 0
      return true
    } else if (key === "a" || key === "A") {
      focusedRow = 1
      toggleStayAwake()
      return true
    } else if (key === "s" || key === "S") {
      focusedRow = 2
      return true
    } else if (key === "l" || key === "L") {
      focusedRow = 3
      return true
    } else if (key === "c" || key === "C") {
      if (focusedRow === 2) {
        screensaverFocusIndex = screensaverOptions.length
        openCustomScreensaver()
        return true
      } else if (focusedRow === 3) {
        lockFocusIndex = lockOptions.length
        openCustomLock()
        return true
      }
    } else if (key === "h" || key === "H") {
      return handleMove(-1, 0)
    } else if (key === "l" || key === "L") {
      return handleMove(1, 0)
    } else if (key >= "1" && key <= "6") {
      var n = parseInt(key) - 1
      if (focusedRow === 0 && n < powerProfiles.length) {
        setProfile(powerProfiles[n].id)
        return true
      } else if (focusedRow === 2 && n < screensaverOptions.length) {
        screensaverFocusIndex = n
        customScreensaverOpen = false
        setIdle(screensaverOptions[n].seconds, root.lockTimeout)
        return true
      } else if (focusedRow === 3 && n < lockOptions.length) {
        lockFocusIndex = n
        customLockOpen = false
        setIdle(root.screensaverTimeout, lockOptions[n].seconds)
        return true
      }
    }
    return false
  }

  function refresh() {
    if (!stateProcess.running && pluginPath.length > 0) {
      stateProcess.command = [pluginPath + "/scripts/power-control.sh", "get-state"]
      stateProcess.running = true
    }
  }

  function toggleStayAwake() {
    root.stayAwake = !root.stayAwake
    setStayAwakeProcess.command = [pluginPath + "/scripts/power-control.sh", "set-stay-awake", "toggle"]
    setStayAwakeProcess.running = true
    notifyStatus(root.stayAwake ? "Stay Awake Enabled (Idle Inhibited)" : "Stay Awake Disabled")
  }

  function setProfile(profileId) {
    root.currentProfile = profileId
    setProfileProcess.command = [pluginPath + "/scripts/power-control.sh", "set-profile", profileId]
    setProfileProcess.running = true
    notifyStatus("Power Profile: " + profileId)
  }

  function setIdle(newScreensaver, newLock) {
    root.customScreensaverOpen = false
    root.customLockOpen = false
    root.screensaverTimeout = newScreensaver
    root.lockTimeout = newLock
    var sIdx = screensaverOptions.length
    for (var i = 0; i < screensaverOptions.length; i++) {
      if (screensaverOptions[i].seconds === newScreensaver) { sIdx = i; break }
    }
    var lIdx = lockOptions.length
    for (var j = 0; j < lockOptions.length; j++) {
      if (lockOptions[j].seconds === newLock) { lIdx = j; break }
    }
    root.screensaverFocusIndex = sIdx
    root.lockFocusIndex = lIdx
    setIdleProcess.command = [
      pluginPath + "/scripts/power-control.sh",
      "set-idle",
      String(newScreensaver),
      String(newLock)
    ]
    setIdleProcess.running = true
    notifyStatus("Idle timers updated")
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

  // Reactive inotify watcher for stay-awake indicator changes
  FileView {
    id: stayAwakeWatcher
    path: Quickshell.env("HOME") + "/.local/state/omarchy/indicators/stay-awake"
    watchChanges: true
    printErrors: false
    onFileChanged: root.refresh()
  }

  // State Process
  Process {
    id: stateProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var data = JSON.parse(text)
          if (data.profile) root.currentProfile = data.profile
          if (data.stayAwake !== undefined) root.stayAwake = (data.stayAwake === true)
          if (data.battery) {
            root.batteryPresent = data.battery.present === true
            root.batteryCapacity = (data.battery.capacity !== undefined && data.battery.capacity !== null) ? Number(data.battery.capacity) : 100
            root.batteryStatus = String(data.battery.status || "Unknown")
            root.acOnline = data.battery.acOnline === true
          }
          if (data.idle) {
            if (data.idle.screensaver !== undefined && data.idle.screensaver !== null) {
              root.screensaverTimeout = Number(data.idle.screensaver)
            } else {
              root.screensaverTimeout = 150
            }
            if (data.idle.lock !== undefined && data.idle.lock !== null) {
              root.lockTimeout = Number(data.idle.lock)
            } else {
              root.lockTimeout = 300
            }
          }
        } catch (e) {
          console.warn("PowerView: JSON parse error", e)
        }
      }
    }
  }

  // Set Profile Process
  Process {
    id: setProfileProcess
    onRunningChanged: {
      if (!running) {
        root.refresh()
        if (panelRoot && typeof panelRoot.notifySettingChanged === "function") {
          panelRoot.notifySettingChanged()
        }
      }
    }
  }

  // Set Stay Awake Process
  Process {
    id: setStayAwakeProcess
    onRunningChanged: {
      if (!running) {
        root.refresh()
        if (panelRoot && typeof panelRoot.notifySettingChanged === "function") {
          panelRoot.notifySettingChanged()
        }
      }
    }
  }

  // Set Idle Process
  Process {
    id: setIdleProcess
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

      // Power/Battery Hero Card
      Rectangle {
        id: powerHeroCard
        Layout.fillWidth: true
        implicitHeight: Math.max(76, powerHeroRow.implicitHeight + 28)
        Layout.preferredHeight: implicitHeight
        color: Color.pickAlpha("surface.subtle", "#181b1d")
        radius: Style.cornerRadius || 8

        RowLayout {
          id: powerHeroRow
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
              text: root.acOnline ? "󰂄" : (root.batteryCapacity > 20 ? "󰁹" : "󰂃")
              font.family: Style.font.family
              font.pixelSize: 24
              color: root.acOnline ? Color.accent : (root.batteryCapacity > 20 ? Color.foreground : Color.urgent)
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
                text: root.batteryPresent ? ("Battery: " + root.batteryCapacity + "%") : "External Power"
                font.family: Style.font.family
                font.pixelSize: Style.font.title || 16
                font.bold: true
                color: Color.foreground
              }

              Rectangle {
                width: 80
                height: 20
                radius: 4
                color: root.acOnline ? Color.pickAlpha("accent.subtle", "#1f3b30") : Color.pickAlpha("surface.selected", "#2a3036")

                Text {
                  anchors.centerIn: parent
                  text: root.acOnline ? "AC Connected" : "On Battery"
                  font.family: Style.font.family
                  font.pixelSize: 10
                  font.bold: true
                  color: root.acOnline ? Color.accent : Color.muted
                }
              }
            }

            Text {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              wrapMode: Text.WordWrap
              text: root.batteryPresent ? ("Status: " + root.batteryStatus) : "Direct AC supply active"
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

      // Setting Row 0: Power Mode Profile
      Rectangle {
        id: profileCard
        Layout.fillWidth: true
        implicitHeight: Math.max(116, profileColLayout.implicitHeight + 28)
        Layout.preferredHeight: implicitHeight
        radius: Style.cornerRadius || 8
        readonly property bool isFocused: root.activeFocusSection && root.focusedRow === 0
        color: profileCard.isFocused ? Color.pickAlpha("surface.selected", "#22272e") : Color.pickAlpha("surface.subtle", "#181b1d")
        border.color: profileCard.isFocused ? Color.accent : "transparent"
        border.width: profileCard.isFocused ? 2 : 1

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.focusedRow = 0
        }

        ColumnLayout {
          id: profileColLayout
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 14
          spacing: 10

          RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
              text: {
                for (var i = 0; i < root.powerProfiles.length; i++) {
                  if (root.powerProfiles[i].id === root.currentProfile) return root.powerProfiles[i].icon
                }
                return "󰾅"
              }
              font.family: Style.font.family
              font.pixelSize: 18
              color: profileCard.isFocused ? Color.accent : Color.foreground
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
                  text: "Power Profile"
                  font.family: Style.font.family
                  font.pixelSize: Style.font.subtitle || 14
                  font.bold: true
                  color: Color.foreground
                }

                Text {
                  visible: profileCard.isFocused
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
                text: {
                  for (var i = 0; i < root.powerProfiles.length; i++) {
                    if (root.powerProfiles[i].id === root.currentProfile) return root.powerProfiles[i].description
                  }
                  return ""
                }
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
                  root.focusedRow = 0
                  root.cycleProfile(-1)
                }
              }

              Button {
                text: "▶"
                implicitWidth: 32
                implicitHeight: 32
                bordered: true
                onClicked: {
                  root.focusedRow = 0
                  root.cycleProfile(1)
                }
              }
            }
          }

          // Visual segmented option cards (Responsive Flow)
          Flow {
            id: profileFlow
            Layout.fillWidth: true
            width: parent.width
            spacing: 8

            readonly property int count: root.powerProfiles.length
            readonly property int minItemWidth: 110
            readonly property int cols: Math.max(1, Math.min(count, Math.floor((width + spacing) / (minItemWidth + spacing))))
            readonly property real itemWidth: Math.max(70, Math.floor((width - (cols - 1) * spacing) / cols))

            Repeater {
              model: root.powerProfiles

              delegate: Rectangle {
                width: profileFlow.itemWidth
                height: 34
                radius: 6
                readonly property bool isSelected: root.currentProfile === modelData.id
                color: isSelected ? Color.pickAlpha("accent.subtle", "#1f3b30") : Color.pickAlpha("surface.hover", "#1b1f23")
                border.color: isSelected ? Color.accent : "transparent"
                border.width: isSelected ? 1 : 0

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.focusedRow = 0
                    root.setProfile(modelData.id)
                  }
                }

                RowLayout {
                  anchors.centerIn: parent
                  width: Math.min(implicitWidth, parent.width - 8)
                  spacing: 4
                  Text {
                    text: modelData.icon
                    font.family: Style.font.family
                    font.pixelSize: 13
                    color: isSelected ? Color.accent : Color.muted
                  }
                  Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    elide: Text.ElideRight
                    text: modelData.title
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
      }

      // Setting Row 1: Stay Awake (Inhibit Idle / Sleep) Toggle Card
      Rectangle {
        id: stayAwakeCard
        Layout.fillWidth: true
        implicitHeight: Math.max(74, stayAwakeRowLayout.implicitHeight + 28)
        Layout.preferredHeight: implicitHeight
        radius: Style.cornerRadius || 8
        readonly property bool isFocused: root.activeFocusSection && root.focusedRow === 1
        color: stayAwakeCard.isFocused ? Color.pickAlpha("surface.selected", "#22272e") : Color.pickAlpha("surface.subtle", "#181b1d")
        border.color: stayAwakeCard.isFocused ? Color.accent : "transparent"
        border.width: stayAwakeCard.isFocused ? 2 : 1

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.focusedRow = 1
            root.toggleStayAwake()
          }
        }

        RowLayout {
          id: stayAwakeRowLayout
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 14
          spacing: 14

          Rectangle {
            width: 44
            height: 44
            radius: 8
            color: root.stayAwake ? Color.pickAlpha("accent.subtle", "#1f3b30") : Color.pickAlpha("surface.hover", "#20252b")

            Text {
              anchors.centerIn: parent
              text: root.stayAwake ? "󰌵" : "󰒲"
              font.family: Style.font.family
              font.pixelSize: 20
              color: root.stayAwake ? Color.accent : Color.foreground
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
                text: "Stay Awake (Inhibit Sleep)"
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle || 14
                font.bold: true
                color: Color.foreground
              }

              Text {
                visible: stayAwakeCard.isFocused
                text: "• Press [Enter/Space or a] to toggle"
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
              text: root.stayAwake ? "Idle inhibition active: screen will remain on and will not lock." : "Standard power-saving idle timers and automatic locking are enabled."
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
            color: root.stayAwake ? Color.accent : Color.pickAlpha("surface.selected", "#2a3036")
            border.color: stayAwakeCard.isFocused ? Color.accent : "transparent"
            border.width: stayAwakeCard.isFocused ? 2 : 0

            Text {
              anchors.centerIn: parent
              text: root.stayAwake ? "AWAKE" : "NORMAL"
              font.family: Style.font.family
              font.pixelSize: 11
              font.bold: true
              color: root.stayAwake ? "#000000" : Color.muted
            }
          }
        }
      }

      // Setting Row 2: Screen Off Timeout
      Rectangle {
        id: screensaverCard
        Layout.fillWidth: true
        implicitHeight: Math.max(116, screensaverColLayout.implicitHeight + 28)
        Layout.preferredHeight: implicitHeight
        radius: Style.cornerRadius || 8
        readonly property bool isFocused: root.activeFocusSection && root.focusedRow === 2
        color: screensaverCard.isFocused ? Color.pickAlpha("surface.selected", "#22272e") : Color.pickAlpha("surface.subtle", "#181b1d")
        border.color: screensaverCard.isFocused ? Color.accent : "transparent"
        border.width: screensaverCard.isFocused ? 2 : 1

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.focusedRow = 2
        }

        ColumnLayout {
          id: screensaverColLayout
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 14
          spacing: 10

          RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
              text: "󰍹"
              font.family: Style.font.family
              font.pixelSize: 18
              color: screensaverCard.isFocused ? Color.accent : Color.foreground
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
                  text: "Screen Off Timeout"
                  font.family: Style.font.family
                  font.pixelSize: Style.font.subtitle || 14
                  font.bold: true
                  color: Color.foreground
                }

                Rectangle {
                  height: 20
                  width: activeScreensaverText.implicitWidth + 12
                  radius: 4
                  color: Color.pickAlpha("accent.subtle", "#1f3b30")
                  border.color: Color.accent
                  border.width: 1

                  Text {
                    id: activeScreensaverText
                    anchors.centerIn: parent
                    text: root.formatDuration(root.screensaverTimeout)
                    font.family: Style.font.family
                    font.pixelSize: 10
                    font.bold: true
                    color: Color.accent
                  }
                }

                Text {
                  visible: screensaverCard.isFocused
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
                text: "Turn off screen or activate screensaver when workstation is idle."
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
                  root.cycleScreensaver(-1)
                }
              }

              Button {
                text: "▶"
                implicitWidth: 32
                implicitHeight: 32
                bordered: true
                onClicked: {
                  root.focusedRow = 2
                  root.cycleScreensaver(1)
                }
              }
            }
          }

          // Visual segmented option cards (Responsive Flow)
          Flow {
            id: screensaverFlow
            Layout.fillWidth: true
            width: parent.width
            spacing: 8

            readonly property int count: root.screensaverOptions.length + 1
            readonly property int minItemWidth: 65
            readonly property int cols: Math.max(1, Math.min(count, Math.floor((width + spacing) / (minItemWidth + spacing))))
            readonly property real itemWidth: Math.max(48, Math.floor((width - (cols - 1) * spacing) / cols))

            Repeater {
              model: root.screensaverOptions

              delegate: Rectangle {
                width: screensaverFlow.itemWidth
                height: 34
                radius: 6
                readonly property bool isSelected: {
                  var activeIdx = (root.screensaverFocusIndex >= 0) ? root.screensaverFocusIndex : root.currentScreensaverIndex()
                  return activeIdx === index
                }
                color: isSelected ? Color.pickAlpha("accent.subtle", "#1f3b30") : Color.pickAlpha("surface.hover", "#1b1f23")
                border.color: isSelected ? Color.accent : "transparent"
                border.width: isSelected ? 1 : 0

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.focusedRow = 2
                    root.screensaverFocusIndex = index
                    root.customScreensaverOpen = false
                    root.setIdle(modelData.seconds, root.lockTimeout)
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

            // Custom Screensaver Option Card
            Rectangle {
              id: customScreensaverChip
              width: Math.max(screensaverFlow.itemWidth, 80)
              height: 34
              radius: 6
              readonly property bool isSelected: root.customScreensaverOpen || (root.screensaverFocusIndex >= 0 ? root.screensaverFocusIndex === root.screensaverOptions.length : root.isCustomScreensaverActive)
              color: customScreensaverChip.isSelected ? Color.pickAlpha("accent.subtle", "#1f3b30") : Color.pickAlpha("surface.hover", "#1b1f23")
              border.color: customScreensaverChip.isSelected ? Color.accent : "transparent"
              border.width: customScreensaverChip.isSelected ? 1 : 0

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.focusedRow = 2
                  if (root.customScreensaverOpen) {
                    root.customScreensaverOpen = false
                    root.screensaverFocusIndex = root.currentScreensaverIndex()
                  } else {
                    root.openCustomScreensaver()
                  }
                }
              }

              Text {
                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.width - 8)
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                text: root.isCustomScreensaverActive ? ("Custom: " + root.formatDuration(root.screensaverTimeout)) : "+ Custom..."
                font.family: Style.font.family
                font.pixelSize: 11
                font.bold: customScreensaverChip.isSelected
                color: customScreensaverChip.isSelected ? Color.accent : Color.foreground
              }
            }
          }

          // Expandable Custom Screensaver Input
          ColumnLayout {
            visible: root.customScreensaverOpen
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
                border.color: (customScreensaverInput.activeFocus) ? Color.accent : Color.pickAlpha("border.subtle", "#2a3036")
                border.width: (customScreensaverInput.activeFocus) ? 2 : 1

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: 10
                  anchors.rightMargin: 8
                  spacing: 8

                  Text {
                    text: "󰍹"
                    font.family: Style.font.family
                    font.pixelSize: 13
                    color: customScreensaverInput.activeFocus ? Color.accent : Color.muted
                  }

                  TextField {
                    id: customScreensaverInput
                    Layout.fillWidth: true
                    placeholderText: "Enter custom minutes (e.g. 12, 25, 40)... [Enter to Set]"
                    placeholderTextColor: Color.muted
                    color: Color.foreground
                    font.family: Style.font.family
                    font.pixelSize: 12
                    background: Item {}
                    text: root.customScreensaverText

                    Component.onCompleted: root.customScreensaverInputItem = customScreensaverInput
                    onTextChanged: {
                      if (root.customScreensaverText !== text) {
                        root.customScreensaverText = text
                        root.customScreensaverError = ""
                      }
                    }

                    onAccepted: root.applyCustomScreensaver()

                    Keys.onEscapePressed: function(event) {
                      event.accepted = true
                      root.customScreensaverOpen = false
                      root.customScreensaverError = ""
                      root.screensaverFocusIndex = root.currentScreensaverIndex()
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
                text: "Set"
                implicitHeight: 34
                implicitWidth: 60
                bordered: true
                onClicked: root.applyCustomScreensaver()
              }

              Button {
                text: "Cancel"
                implicitHeight: 34
                implicitWidth: 65
                bordered: true
                onClicked: {
                  root.customScreensaverOpen = false
                  root.customScreensaverError = ""
                  root.screensaverFocusIndex = root.currentScreensaverIndex()
                  if (root.panelRoot && typeof root.panelRoot.returnFocusToKeyCatcher === "function") {
                    root.panelRoot.returnFocusToKeyCatcher()
                  }
                }
              }
            }

            Text {
              visible: root.customScreensaverError.length > 0
              text: root.customScreensaverError
              font.family: Style.font.family
              font.pixelSize: 11
              color: "#ff5555"
            }

            Text {
              visible: root.customScreensaverError.length === 0
              text: "Set exact minutes before display powers down or activates screensaver (e.g. 12, 45, 90)."
              font.family: Style.font.family
              font.pixelSize: 11
              color: Color.muted
            }
          }
        }
      }

      // Setting Row 3: Lock Screen Timeout
      Rectangle {
        id: lockCard
        Layout.fillWidth: true
        implicitHeight: Math.max(116, lockColLayout.implicitHeight + 28)
        Layout.preferredHeight: implicitHeight
        radius: Style.cornerRadius || 8
        readonly property bool isFocused: root.activeFocusSection && root.focusedRow === 3
        color: lockCard.isFocused ? Color.pickAlpha("surface.selected", "#22272e") : Color.pickAlpha("surface.subtle", "#181b1d")
        border.color: lockCard.isFocused ? Color.accent : "transparent"
        border.width: lockCard.isFocused ? 2 : 1

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.focusedRow = 3
        }

        ColumnLayout {
          id: lockColLayout
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 14
          spacing: 10

          RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
              text: ""
              font.family: Style.font.family
              font.pixelSize: 18
              color: lockCard.isFocused ? Color.accent : Color.foreground
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
                  text: "Lock Screen Timeout"
                  font.family: Style.font.family
                  font.pixelSize: Style.font.subtitle || 14
                  font.bold: true
                  color: Color.foreground
                }

                Rectangle {
                  height: 20
                  width: activeLockText.implicitWidth + 12
                  radius: 4
                  color: Color.pickAlpha("accent.subtle", "#1f3b30")
                  border.color: Color.accent
                  border.width: 1

                  Text {
                    id: activeLockText
                    anchors.centerIn: parent
                    text: root.formatDuration(root.lockTimeout)
                    font.family: Style.font.family
                    font.pixelSize: 10
                    font.bold: true
                    color: Color.accent
                  }
                }

                Text {
                  visible: lockCard.isFocused
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
                text: "Automatically lock the desktop after a designated idle period."
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
                  root.cycleLock(-1)
                }
              }

              Button {
                text: "▶"
                implicitWidth: 32
                implicitHeight: 32
                bordered: true
                onClicked: {
                  root.focusedRow = 3
                  root.cycleLock(1)
                }
              }
            }
          }

          // Visual segmented option cards (Responsive Flow)
          Flow {
            id: lockFlow
            Layout.fillWidth: true
            width: parent.width
            spacing: 8

            readonly property int count: root.lockOptions.length + 1
            readonly property int minItemWidth: 65
            readonly property int cols: Math.max(1, Math.min(count, Math.floor((width + spacing) / (minItemWidth + spacing))))
            readonly property real itemWidth: Math.max(48, Math.floor((width - (cols - 1) * spacing) / cols))

            Repeater {
              model: root.lockOptions

              delegate: Rectangle {
                width: lockFlow.itemWidth
                height: 34
                radius: 6
                readonly property bool isSelected: {
                  var activeIdx = (root.lockFocusIndex >= 0) ? root.lockFocusIndex : root.currentLockIndex()
                  return activeIdx === index
                }
                color: isSelected ? Color.pickAlpha("accent.subtle", "#1f3b30") : Color.pickAlpha("surface.hover", "#1b1f23")
                border.color: isSelected ? Color.accent : "transparent"
                border.width: isSelected ? 1 : 0

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.focusedRow = 3
                    root.lockFocusIndex = index
                    root.customLockOpen = false
                    root.setIdle(root.screensaverTimeout, modelData.seconds)
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

            // Custom Lock Option Card
            Rectangle {
              id: customLockChip
              width: Math.max(lockFlow.itemWidth, 80)
              height: 34
              radius: 6
              readonly property bool isSelected: root.customLockOpen || (root.lockFocusIndex >= 0 ? root.lockFocusIndex === root.lockOptions.length : root.isCustomLockActive)
              color: customLockChip.isSelected ? Color.pickAlpha("accent.subtle", "#1f3b30") : Color.pickAlpha("surface.hover", "#1b1f23")
              border.color: customLockChip.isSelected ? Color.accent : "transparent"
              border.width: customLockChip.isSelected ? 1 : 0

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.focusedRow = 3
                  if (root.customLockOpen) {
                    root.customLockOpen = false
                    root.lockFocusIndex = root.currentLockIndex()
                  } else {
                    root.openCustomLock()
                  }
                }
              }

              Text {
                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.width - 8)
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                text: root.isCustomLockActive ? ("Custom: " + root.formatDuration(root.lockTimeout)) : "+ Custom..."
                font.family: Style.font.family
                font.pixelSize: 11
                font.bold: customLockChip.isSelected
                color: customLockChip.isSelected ? Color.accent : Color.foreground
              }
            }
          }

          // Expandable Custom Lock Input
          ColumnLayout {
            visible: root.customLockOpen
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
                border.color: (customLockInput.activeFocus) ? Color.accent : Color.pickAlpha("border.subtle", "#2a3036")
                border.width: (customLockInput.activeFocus) ? 2 : 1

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: 10
                  anchors.rightMargin: 8
                  spacing: 8

                  Text {
                    text: ""
                    font.family: Style.font.family
                    font.pixelSize: 13
                    color: customLockInput.activeFocus ? Color.accent : Color.muted
                  }

                  TextField {
                    id: customLockInput
                    Layout.fillWidth: true
                    placeholderText: "Enter custom minutes (e.g. 15, 45, 90)... [Enter to Set]"
                    placeholderTextColor: Color.muted
                    color: Color.foreground
                    font.family: Style.font.family
                    font.pixelSize: 12
                    background: Item {}
                    text: root.customLockText

                    Component.onCompleted: root.customLockInputItem = customLockInput
                    onTextChanged: {
                      if (root.customLockText !== text) {
                        root.customLockText = text
                        root.customLockError = ""
                      }
                    }

                    onAccepted: root.applyCustomLock()

                    Keys.onEscapePressed: function(event) {
                      event.accepted = true
                      root.customLockOpen = false
                      root.customLockError = ""
                      root.lockFocusIndex = root.currentLockIndex()
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
                text: "Set"
                implicitHeight: 34
                implicitWidth: 60
                bordered: true
                onClicked: root.applyCustomLock()
              }

              Button {
                text: "Cancel"
                implicitHeight: 34
                implicitWidth: 65
                bordered: true
                onClicked: {
                  root.customLockOpen = false
                  root.customLockError = ""
                  root.lockFocusIndex = root.currentLockIndex()
                  if (root.panelRoot && typeof root.panelRoot.returnFocusToKeyCatcher === "function") {
                    root.panelRoot.returnFocusToKeyCatcher()
                  }
                }
              }
            }

            Text {
              visible: root.customLockError.length > 0
              text: root.customLockError
              font.family: Style.font.family
              font.pixelSize: 11
              color: "#ff5555"
            }

            Text {
              visible: root.customLockError.length === 0
              text: "Set exact minutes before desktop automatically locks (e.g. 25, 60, 90)."
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
