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
    { label: "10 min", seconds: 600 },
    { label: "Never", seconds: 0 }
  ]

  readonly property var lockOptions: [
    { label: "2 min", seconds: 120 },
    { label: "5 min", seconds: 300 },
    { label: "10 min", seconds: 600 },
    { label: "15 min", seconds: 900 },
    { label: "Never", seconds: 0 }
  ]

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
    for (var i = 0; i < screensaverOptions.length; i++) {
      if (screensaverOptions[i].seconds === root.screensaverTimeout) return i
    }
    return 1
  }

  function currentLockIndex() {
    for (var i = 0; i < lockOptions.length; i++) {
      if (lockOptions[i].seconds === root.lockTimeout) return i
    }
    return 1
  }

  function cycleProfile(delta) {
    var idx = currentProfileIndex()
    var next = (idx + delta + powerProfiles.length) % powerProfiles.length
    setProfile(powerProfiles[next].id)
  }

  function cycleScreensaver(delta) {
    var idx = currentScreensaverIndex()
    var next = Math.max(0, Math.min(screensaverOptions.length - 1, idx + delta))
    setIdle(screensaverOptions[next].seconds, root.lockTimeout)
  }

  function cycleLock(delta) {
    var idx = currentLockIndex()
    var next = Math.max(0, Math.min(lockOptions.length - 1, idx + delta))
    setIdle(root.screensaverTimeout, lockOptions[next].seconds)
  }

  function handleMove(dx, dy) {
    if (dy !== 0) {
      focusedRow = Math.max(0, Math.min(3, focusedRow + dy))
      ensureRowVisible(focusedRow)
      return true
    }
    if (dx !== 0) {
      if (focusedRow === 0) cycleProfile(dx)
      else if (focusedRow === 1) toggleStayAwake()
      else if (focusedRow === 2) cycleScreensaver(dx)
      else if (focusedRow === 3) cycleLock(dx)
      return true
    }
    return false
  }

  function handleActivate() {
    if (focusedRow === 0) cycleProfile(1)
    else if (focusedRow === 1) toggleStayAwake()
    else if (focusedRow === 2) cycleScreensaver(1)
    else if (focusedRow === 3) cycleLock(1)
  }

  function handleTextKey(key) {
    if (key === "r" || key === "R") {
      refresh()
    } else if (key === "p" || key === "P") {
      focusedRow = 0
    } else if (key === "a" || key === "A") {
      focusedRow = 1
      toggleStayAwake()
    } else if (key === "s" || key === "S") {
      focusedRow = 2
    } else if (key === "l" || key === "L") {
      focusedRow = 3
    } else if (key >= "1" && key <= "5") {
      var n = parseInt(key) - 1
      if (focusedRow === 0 && n < powerProfiles.length) {
        setProfile(powerProfiles[n].id)
      } else if (focusedRow === 2 && n < screensaverOptions.length) {
        setIdle(screensaverOptions[n].seconds, root.lockTimeout)
      } else if (focusedRow === 3 && n < lockOptions.length) {
        setIdle(root.screensaverTimeout, lockOptions[n].seconds)
      }
    }
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
    root.screensaverTimeout = newScreensaver
    root.lockTimeout = newLock
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
          anchors.fill: parent
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

            RowLayout {
              Layout.fillWidth: true
              spacing: 8
              Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                elide: Text.ElideRight
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
          anchors.fill: parent
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

              RowLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 8
                Text {
                  text: "Power Profile"
                  font.family: Style.font.family
                  font.pixelSize: Style.font.subtitle || 14
                  font.bold: true
                  color: Color.foreground
                }
                Text {
                  visible: profileCard.isFocused
                  Layout.fillWidth: true
                  Layout.minimumWidth: 0
                  text: "• Use [←/→ or h/l] to cycle"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  color: Color.accent
                  elide: Text.ElideRight
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
                elide: Text.ElideRight
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

          // Visual segmented option cards
          RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
              model: root.powerProfiles

              delegate: Rectangle {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredHeight: 34
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
          anchors.fill: parent
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

            RowLayout {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              spacing: 8
              Text {
                text: "Stay Awake (Inhibit Sleep)"
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle || 14
                font.bold: true
                color: Color.foreground
              }
              Text {
                visible: stayAwakeCard.isFocused
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: "• Press [Enter/Space or a] to toggle"
                font.family: Style.font.family
                font.pixelSize: 11
                color: Color.accent
                elide: Text.ElideRight
              }
            }

            Text {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              text: root.stayAwake ? "Idle inhibition active: screen will remain on and will not lock." : "Standard power-saving idle timers and automatic locking are enabled."
              font.family: Style.font.family
              font.pixelSize: Style.font.subtext || 11
              color: Color.muted
              elide: Text.ElideRight
            }
          }

          Rectangle {
            width: 90
            height: 32
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
          anchors.fill: parent
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

              RowLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 8
                Text {
                  text: "Screen Off Timeout"
                  font.family: Style.font.family
                  font.pixelSize: Style.font.subtitle || 14
                  font.bold: true
                  color: Color.foreground
                }
                Text {
                  visible: screensaverCard.isFocused
                  Layout.fillWidth: true
                  Layout.minimumWidth: 0
                  text: "• Use [←/→ or h/l] to cycle"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  color: Color.accent
                  elide: Text.ElideRight
                }
              }

              Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: "Turn off screen or activate screensaver when workstation is idle."
                font.family: Style.font.family
                font.pixelSize: Style.font.subtext || 11
                color: Color.muted
                elide: Text.ElideRight
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

          // Visual segmented option cards
          RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
              model: root.screensaverOptions

              delegate: Rectangle {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredHeight: 34
                radius: 6
                readonly property bool isSelected: root.screensaverTimeout === modelData.seconds
                color: isSelected ? Color.pickAlpha("accent.subtle", "#1f3b30") : Color.pickAlpha("surface.hover", "#1b1f23")
                border.color: isSelected ? Color.accent : "transparent"
                border.width: isSelected ? 1 : 0

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.focusedRow = 2
                    root.setIdle(modelData.seconds, root.lockTimeout)
                  }
                }

                Text {
                  anchors.centerIn: parent
                  width: Math.min(implicitWidth, parent.width - 8)
                  elide: Text.ElideRight
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
          anchors.fill: parent
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

              RowLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 8
                Text {
                  text: "Lock Screen Timeout"
                  font.family: Style.font.family
                  font.pixelSize: Style.font.subtitle || 14
                  font.bold: true
                  color: Color.foreground
                }
                Text {
                  visible: lockCard.isFocused
                  Layout.fillWidth: true
                  Layout.minimumWidth: 0
                  text: "• Use [←/→ or h/l] to cycle"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  color: Color.accent
                  elide: Text.ElideRight
                }
              }

              Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: "Automatically lock the desktop after a designated idle period."
                font.family: Style.font.family
                font.pixelSize: Style.font.subtext || 11
                color: Color.muted
                elide: Text.ElideRight
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

          // Visual segmented option cards
          RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
              model: root.lockOptions

              delegate: Rectangle {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredHeight: 34
                radius: 6
                readonly property bool isSelected: root.lockTimeout === modelData.seconds
                color: isSelected ? Color.pickAlpha("accent.subtle", "#1f3b30") : Color.pickAlpha("surface.hover", "#1b1f23")
                border.color: isSelected ? Color.accent : "transparent"
                border.width: isSelected ? 1 : 0

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.focusedRow = 3
                    root.setIdle(root.screensaverTimeout, modelData.seconds)
                  }
                }

                Text {
                  anchors.centerIn: parent
                  width: Math.min(implicitWidth, parent.width - 8)
                  elide: Text.ElideRight
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

      Item { Layout.preferredHeight: 12 }
    }
  }
}
