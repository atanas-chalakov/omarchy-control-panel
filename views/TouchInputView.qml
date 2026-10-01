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
  property bool activeFocusSection: false
  property int focusedCard: 0   // 0: Touchscreen, 1: Touch Gestures, 2: Touch Output, 3: Touchpad, 4: Natural Scroll, 5: Tap to Click, 6: Scroll Speed, 7: Disable While Typing, 8: Pointer Sensitivity
  onFocusedCardChanged: ensureCardVisible(focusedCard)

  function ensureCardVisible(index) {
    if (!scrollArea || !scrollArea.contentItem) return
    var targets = [tsCard, tsRowSwipe, tsRowOutput, tpRowHeader, tpRowNatural, tpRowTap, tpRowSpeed, tpRowTyping, sensRow]
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

  property string statusMessage: ""

  // State properties
  property bool touchscreenPresent: false
  property string touchscreenName: ""
  property bool touchscreenEnabled: true

  property bool touchpadPresent: false
  property string touchpadName: ""
  property bool touchpadEnabled: true

  property bool naturalScroll: false
  property bool clickfingerBehavior: true
  property real scrollFactor: 0.4
  property bool disableWhileTyping: false

  property bool workspaceSwipeTouch: false
  property real sensitivity: 0.0
  property string touchOutput: "[[Auto]]"
  property var monitors: []
  property bool virtualKeyboard: false

  readonly property var scrollFactorOptions: [0.2, 0.4, 0.6, 0.8, 1.0, 1.2]
  readonly property var sensitivityOptions: [-0.5, -0.2, 0.0, 0.2, 0.4, 0.6, 0.8]

  function currentScrollFactorIndex() {
    var best = 1
    var minDiff = 999
    for (var i = 0; i < scrollFactorOptions.length; i++) {
      var diff = Math.abs(scrollFactorOptions[i] - root.scrollFactor)
      if (diff < minDiff) {
        minDiff = diff
        best = i
      }
    }
    return best
  }

  function currentSensitivityIndex() {
    var best = 2
    var minDiff = 999
    for (var i = 0; i < sensitivityOptions.length; i++) {
      var diff = Math.abs(sensitivityOptions[i] - root.sensitivity)
      if (diff < minDiff) {
        minDiff = diff
        best = i
      }
    }
    return best
  }

  function allOutputOptions() {
    var list = ["[[Auto]]"]
    if (root.monitors && root.monitors.length) {
      for (var i = 0; i < root.monitors.length; i++) {
        list.push(root.monitors[i])
      }
    }
    return list
  }

  function currentOutputIndex() {
    var opts = allOutputOptions()
    for (var i = 0; i < opts.length; i++) {
      if (opts[i] === root.touchOutput) return i
    }
    return 0
  }

  function cycleScrollFactor(delta) {
    var idx = currentScrollFactorIndex()
    var next = Math.max(0, Math.min(scrollFactorOptions.length - 1, idx + delta))
    setScrollFactor(scrollFactorOptions[next])
  }

  function cycleSensitivity(delta) {
    var idx = currentSensitivityIndex()
    var next = Math.max(0, Math.min(sensitivityOptions.length - 1, idx + delta))
    setSensitivity(sensitivityOptions[next])
  }

  function cycleTouchOutput(delta) {
    var opts = allOutputOptions()
    if (opts.length <= 1) return
    var idx = currentOutputIndex()
    var next = (idx + delta + opts.length) % opts.length
    setTouchOutput(opts[next])
  }

  function refresh() {
    if (!stateProcess.running && pluginPath.length > 0) {
      stateProcess.command = [pluginPath + "/scripts/touch-input-control.sh", "get-state"]
      stateProcess.running = true
    }
  }

  function toggleTouchscreen() {
    actionProcess.command = [pluginPath + "/scripts/touch-input-control.sh", "toggle-touchscreen"]
    actionProcess.running = true
    notifyStatus(root.touchscreenEnabled ? "Touchscreen Disabled" : "Touchscreen Enabled")
  }

  function toggleTouchpad() {
    actionProcess.command = [pluginPath + "/scripts/touch-input-control.sh", "toggle-touchpad"]
    actionProcess.running = true
    notifyStatus(root.touchpadEnabled ? "Touchpad Disabled" : "Touchpad Enabled")
  }

  function toggleNaturalScroll() {
    var target = !root.naturalScroll
    actionProcess.command = [pluginPath + "/scripts/touch-input-control.sh", "set-natural-scroll", target ? "true" : "false"]
    actionProcess.running = true
    notifyStatus(target ? "Natural Scrolling Enabled" : "Standard Scrolling Enabled")
  }

  function toggleTapToClick() {
    var target = !root.clickfingerBehavior
    actionProcess.command = [pluginPath + "/scripts/touch-input-control.sh", "set-clickfinger", target ? "true" : "false"]
    actionProcess.running = true
    notifyStatus(target ? "Tap to Click Enabled" : "Tap to Click Disabled")
  }

  function toggleDisableWhileTyping() {
    var target = !root.disableWhileTyping
    actionProcess.command = [pluginPath + "/scripts/touch-input-control.sh", "set-disable-while-typing", target ? "true" : "false"]
    actionProcess.running = true
    notifyStatus(target ? "Disable While Typing Enabled" : "Disable While Typing Disabled")
  }

  function toggleWorkspaceSwipeTouch() {
    var target = !root.workspaceSwipeTouch
    actionProcess.command = [pluginPath + "/scripts/touch-input-control.sh", "set-workspace-swipe-touch", target ? "true" : "false"]
    actionProcess.running = true
    notifyStatus(target ? "Touchscreen 3-Finger Swipe Enabled" : "Touchscreen 3-Finger Swipe Disabled")
  }

  function setScrollFactor(factor) {
    actionProcess.command = [pluginPath + "/scripts/touch-input-control.sh", "set-scroll-factor", String(factor)]
    actionProcess.running = true
    notifyStatus("Scroll Speed: " + factor + "x")
  }

  function setSensitivity(sens) {
    actionProcess.command = [pluginPath + "/scripts/touch-input-control.sh", "set-sensitivity", String(sens)]
    actionProcess.running = true
    notifyStatus("Pointer Sensitivity: " + (sens >= 0 ? "+" : "") + sens.toFixed(1))
  }

  function setTouchOutput(out) {
    actionProcess.command = [pluginPath + "/scripts/touch-input-control.sh", "set-touch-output", out]
    actionProcess.running = true
    notifyStatus("Touchscreen Output: " + (out === "[[Auto]]" ? "Auto" : out))
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

  function handleMove(dx, dy) {
    if (dy !== 0) {
      focusedCard = Math.max(0, Math.min(8, focusedCard + dy))
      ensureCardVisible(focusedCard)
    } else if (dx !== 0) {
      if (focusedCard === 0) toggleTouchscreen()
      else if (focusedCard === 1) toggleWorkspaceSwipeTouch()
      else if (focusedCard === 2) cycleTouchOutput(dx)
      else if (focusedCard === 3) toggleTouchpad()
      else if (focusedCard === 4) toggleNaturalScroll()
      else if (focusedCard === 5) toggleTapToClick()
      else if (focusedCard === 6) cycleScrollFactor(dx)
      else if (focusedCard === 7) toggleDisableWhileTyping()
      else if (focusedCard === 8) cycleSensitivity(dx)
    }
  }

  function handleActivate() {
    if (focusedCard === 0) toggleTouchscreen()
    else if (focusedCard === 1) toggleWorkspaceSwipeTouch()
    else if (focusedCard === 2) cycleTouchOutput(1)
    else if (focusedCard === 3) toggleTouchpad()
    else if (focusedCard === 4) toggleNaturalScroll()
    else if (focusedCard === 5) toggleTapToClick()
    else if (focusedCard === 6) cycleScrollFactor(1)
    else if (focusedCard === 7) toggleDisableWhileTyping()
    else if (focusedCard === 8) cycleSensitivity(1)
  }

  function handleTextKey(key) {
    var k = key.toLowerCase()
    if (k === "t") {
      focusedCard = 0
      toggleTouchscreen()
      return true
    } else if (k === "w") {
      focusedCard = 1
      toggleWorkspaceSwipeTouch()
      return true
    } else if (k === "m") {
      focusedCard = 2
      cycleTouchOutput(1)
      return true
    } else if (k === "p") {
      focusedCard = 3
      toggleTouchpad()
      return true
    } else if (k === "n") {
      focusedCard = 4
      toggleNaturalScroll()
      return true
    } else if (k === "c") {
      focusedCard = 5
      toggleTapToClick()
      return true
    } else if (k === "s") {
      focusedCard = 6
      cycleScrollFactor(1)
      return true
    } else if (k === "d") {
      focusedCard = 7
      toggleDisableWhileTyping()
      return true
    } else if (k === "a") {
      focusedCard = 8
      cycleSensitivity(1)
      return true
    } else if (k === "r") {
      refresh()
      notifyStatus("Refreshed input devices")
      return true
    }
    return false
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
          if (data.touchscreen) {
            root.touchscreenPresent = data.touchscreen.present === true
            root.touchscreenName = String(data.touchscreen.name || "")
            root.touchscreenEnabled = data.touchscreen.enabled === true
          }
          if (data.touchpad) {
            root.touchpadPresent = data.touchpad.present === true
            root.touchpadName = String(data.touchpad.name || "")
            root.touchpadEnabled = data.touchpad.enabled === true
            root.naturalScroll = data.touchpad.naturalScroll === true
            root.clickfingerBehavior = data.touchpad.clickfingerBehavior !== false
            root.scrollFactor = (typeof data.touchpad.scrollFactor === "number") ? data.touchpad.scrollFactor : 0.4
            root.disableWhileTyping = data.touchpad.disableWhileTyping === true
          }
          if (data.gestures) {
            root.workspaceSwipeTouch = data.gestures.workspaceSwipeTouch === true
          }
          if (typeof data.sensitivity === "number") {
            root.sensitivity = data.sensitivity
          }
          if (data.touchOutput) {
            root.touchOutput = String(data.touchOutput)
          }
          if (Array.isArray(data.monitors)) {
            root.monitors = data.monitors
          }
          if (data.virtualKeyboard !== undefined) {
            root.virtualKeyboard = data.virtualKeyboard === true
          }
        } catch (e) {}
      }
    }
  }

  // Action Process
  Process {
    id: actionProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var data = JSON.parse(text)
          if (data.touchscreen) {
            root.touchscreenPresent = data.touchscreen.present === true
            root.touchscreenName = String(data.touchscreen.name || "")
            root.touchscreenEnabled = data.touchscreen.enabled === true
          }
          if (data.touchpad) {
            root.touchpadPresent = data.touchpad.present === true
            root.touchpadName = String(data.touchpad.name || "")
            root.touchpadEnabled = data.touchpad.enabled === true
            root.naturalScroll = data.touchpad.naturalScroll === true
            root.clickfingerBehavior = data.touchpad.clickfingerBehavior !== false
            root.scrollFactor = (typeof data.touchpad.scrollFactor === "number") ? data.touchpad.scrollFactor : 0.4
            root.disableWhileTyping = data.touchpad.disableWhileTyping === true
          }
          if (data.gestures) {
            root.workspaceSwipeTouch = data.gestures.workspaceSwipeTouch === true
          }
          if (typeof data.sensitivity === "number") {
            root.sensitivity = data.sensitivity
          }
          if (data.touchOutput) {
            root.touchOutput = String(data.touchOutput)
          }
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
    id: tsStateWatcher
    path: Quickshell.env("HOME") + "/.local/state/omarchy/toggles/hypr/touchscreen-disabled-name"
    watchChanges: true
    printErrors: false
    onFileChanged: root.refresh()
  }

  FileView {
    id: tpStateWatcher
    path: Quickshell.env("HOME") + "/.local/state/omarchy/toggles/hypr/touchpad-disabled-name"
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

      // Touchscreen Hero / Status Card
      Rectangle {
        id: tsCard
        Layout.fillWidth: true
        Layout.preferredHeight: 90
        color: Color.pickAlpha("surface.subtle", "#181b1d")
        radius: Style.cornerRadius || 8
        border.color: (root.activeFocusSection && root.focusedCard === 0) ? Color.accent : "transparent"
        border.width: (root.activeFocusSection && root.focusedCard === 0) ? 2 : 0

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.focusedCard = 0
            root.toggleTouchscreen()
          }
        }

        RowLayout {
          anchors.fill: parent
          anchors.margins: 14
          spacing: 14

          Rectangle {
            width: 48
            height: 48
            radius: 8
            color: root.touchscreenPresent ? Color.pickAlpha("accent.subtle", "#1f3b30") : Color.pickAlpha("surface.selected", "#2a3036")

            Text {
              anchors.centerIn: parent
              text: "󰆽"
              font.family: Style.font.family
              font.pixelSize: 26
              color: (root.touchscreenPresent && root.touchscreenEnabled) ? Color.accent : Color.muted
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            RowLayout {
              spacing: 8
              Text {
                text: "Touchscreen"
                font.family: Style.font.family
                font.pixelSize: Style.font.title || 15
                font.bold: true
                color: Color.foreground
              }

              Rectangle {
                Layout.preferredHeight: 20
                Layout.preferredWidth: tsStatusText.implicitWidth + 14
                radius: 4
                color: root.touchscreenPresent
                  ? (root.touchscreenEnabled ? Color.pickAlpha("accent.subtle", "#1f3b30") : Color.pickAlpha("surface.hover", "#262b30"))
                  : Color.pickAlpha("surface.hover", "#262b30")

                Text {
                  id: tsStatusText
                  anchors.centerIn: parent
                  text: root.touchscreenPresent
                    ? (root.touchscreenEnabled ? "ENABLED" : "DISABLED")
                    : "NO DEVICE DETECTED"
                  font.family: Style.font.family
                  font.pixelSize: 10
                  font.bold: true
                  color: root.touchscreenPresent
                    ? (root.touchscreenEnabled ? Color.accent : Color.muted)
                    : Color.muted
                }
              }

              Rectangle {
                width: 18
                height: 18
                radius: 3
                color: Color.pickAlpha("surface.selected", "#2a3036")

                Text {
                  anchors.centerIn: parent
                  text: "T"
                  font.family: Style.font.family
                  font.pixelSize: 10
                  color: Color.muted
                }
              }
            }

            Text {
              Layout.fillWidth: true
              text: root.touchscreenPresent
                ? ("Device: " + root.touchscreenName)
                : "No touch digitizer reported by Hyprland. External tablets/screens will appear once connected."
              font.family: Style.font.family
              font.pixelSize: 11
              color: Color.muted
              elide: Text.ElideRight
            }
          }

          // Toggle Button
          Button {
            text: root.touchscreenEnabled ? "ENABLED" : "DISABLED"
            implicitWidth: 84
            implicitHeight: 34
            bordered: true
            onClicked: {
              root.focusedCard = 0
              root.toggleTouchscreen()
            }
          }
        }
      }

      // Touchscreen Gestures & Display Mapping
      Rectangle {
        id: tsGesturesCard
        Layout.fillWidth: true
        Layout.preferredHeight: tsGesturesCol.implicitHeight + 24
        color: Color.pickAlpha("surface.subtle", "#181b1d")
        radius: Style.cornerRadius || 8

        ColumnLayout {
          id: tsGesturesCol
          anchors.fill: parent
          anchors.margins: 12
          spacing: 10

          // Row 1: 3-Finger Workspace Swipe
          Rectangle {
            id: tsRowSwipe
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            radius: 6
            color: (root.activeFocusSection && root.focusedCard === 1) ? Color.pickAlpha("surface.selected", "#2a3036") : "transparent"
            border.color: (root.activeFocusSection && root.focusedCard === 1) ? Color.accent : "transparent"
            border.width: (root.activeFocusSection && root.focusedCard === 1) ? 2 : 0

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.focusedCard = 1
                root.toggleWorkspaceSwipeTouch()
              }
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 8
              anchors.rightMargin: 8
              spacing: 10

              Text {
                text: "󱂬"
                font.family: Style.font.family
                font.pixelSize: 16
                color: root.workspaceSwipeTouch ? Color.accent : Color.muted
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                RowLayout {
                  spacing: 6
                  Text {
                    text: "3-Finger Workspace Swipe"
                    font.family: Style.font.family
                    font.pixelSize: 13
                    font.bold: true
                    color: Color.foreground
                  }

                  Rectangle {
                    width: 18
                    height: 18
                    radius: 3
                    color: Color.pickAlpha("surface.selected", "#2a3036")
                    Text {
                      anchors.centerIn: parent
                      text: "W"
                      font.family: Style.font.family
                      font.pixelSize: 10
                      color: Color.muted
                    }
                  }
                }

                Text {
                  text: "Swipe across the touchscreen to switch between Hyprland workspaces"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  color: Color.muted
                }
              }

              Button {
                text: root.workspaceSwipeTouch ? "ON" : "OFF"
                implicitWidth: 64
                implicitHeight: 28
                bordered: true
                onClicked: {
                  root.focusedCard = 1
                  root.toggleWorkspaceSwipeTouch()
                }
              }
            }
          }

          // Row 2: Touchscreen Monitor Output Mapping
          Rectangle {
            id: tsRowOutput
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            radius: 6
            color: (root.activeFocusSection && root.focusedCard === 2) ? Color.pickAlpha("surface.selected", "#2a3036") : "transparent"
            border.color: (root.activeFocusSection && root.focusedCard === 2) ? Color.accent : "transparent"
            border.width: (root.activeFocusSection && root.focusedCard === 2) ? 2 : 0

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.focusedCard = 2
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 8
              anchors.rightMargin: 8
              spacing: 10

              Text {
                text: "󰍹"
                font.family: Style.font.family
                font.pixelSize: 16
                color: Color.muted
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                RowLayout {
                  spacing: 6
                  Text {
                    text: "Display Output Mapping"
                    font.family: Style.font.family
                    font.pixelSize: 13
                    font.bold: true
                    color: Color.foreground
                  }

                  Rectangle {
                    width: 18
                    height: 18
                    radius: 3
                    color: Color.pickAlpha("surface.selected", "#2a3036")
                    Text {
                      anchors.centerIn: parent
                      text: "M"
                      font.family: Style.font.family
                      font.pixelSize: 10
                      color: Color.muted
                    }
                  }
                }

                Text {
                  text: "Bind touch coordinates to a specific display monitor"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  color: Color.muted
                }
              }

              RowLayout {
                spacing: 6

                Button {
                  text: "◀"
                  implicitWidth: 30
                  implicitHeight: 28
                  bordered: true
                  onClicked: {
                    root.focusedCard = 2
                    root.cycleTouchOutput(-1)
                  }
                }

                Rectangle {
                  implicitWidth: 80
                  implicitHeight: 28
                  radius: 4
                  color: Color.pickAlpha("surface.selected", "#2a3036")

                  Text {
                    anchors.centerIn: parent
                    text: root.touchOutput === "[[Auto]]" ? "Auto" : root.touchOutput
                    font.family: Style.font.family
                    font.pixelSize: 12
                    font.bold: true
                    color: Color.foreground
                  }
                }

                Button {
                  text: "▶"
                  implicitWidth: 30
                  implicitHeight: 28
                  bordered: true
                  onClicked: {
                    root.focusedCard = 2
                    root.cycleTouchOutput(1)
                  }
                }
              }
            }
          }
        }
      }

      // Touchpad Controls Card
      Rectangle {
        id: tpCard
        Layout.fillWidth: true
        Layout.preferredHeight: tpCol.implicitHeight + 24
        color: Color.pickAlpha("surface.subtle", "#181b1d")
        radius: Style.cornerRadius || 8

        ColumnLayout {
          id: tpCol
          anchors.fill: parent
          anchors.margins: 12
          spacing: 8

          // Header (Touchpad Device Toggle - Key P)
          Rectangle {
            id: tpRowHeader
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            radius: 6
            color: (root.activeFocusSection && root.focusedCard === 3) ? Color.pickAlpha("surface.selected", "#2a3036") : "transparent"
            border.color: (root.activeFocusSection && root.focusedCard === 3) ? Color.accent : "transparent"
            border.width: (root.activeFocusSection && root.focusedCard === 3) ? 2 : 0

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.focusedCard = 3
                root.toggleTouchpad()
              }
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 8
              anchors.rightMargin: 8
              spacing: 8

              Text {
                text: "󰟸"
                font.family: Style.font.family
                font.pixelSize: 18
                color: Color.accent
              }

              Text {
                text: "Touchpad & Tap Controls"
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle || 14
                font.bold: true
                color: Color.foreground
              }

              Rectangle {
                Layout.preferredHeight: 18
                Layout.preferredWidth: tpStatusText.implicitWidth + 10
                radius: 3
                color: root.touchpadPresent ? Color.pickAlpha("accent.subtle", "#1f3b30") : Color.pickAlpha("surface.selected", "#2a3036")

                Text {
                  id: tpStatusText
                  anchors.centerIn: parent
                  text: root.touchpadPresent ? (root.touchpadEnabled ? "DETECTED" : "DISABLED") : "NOT FOUND"
                  font.family: Style.font.family
                  font.pixelSize: 9
                  font.bold: true
                  color: root.touchpadPresent ? (root.touchpadEnabled ? Color.accent : Color.muted) : Color.muted
                }
              }

              Item { Layout.fillWidth: true }

              Rectangle {
                width: 18
                height: 18
                radius: 3
                color: Color.pickAlpha("surface.selected", "#2a3036")
                Text {
                  anchors.centerIn: parent
                  text: "P"
                  font.family: Style.font.family
                  font.pixelSize: 10
                  color: Color.muted
                }
              }

              Button {
                text: root.touchpadEnabled ? "ENABLED" : "DISABLED"
                implicitWidth: 80
                implicitHeight: 26
                bordered: true
                onClicked: {
                  root.focusedCard = 3
                  root.toggleTouchpad()
                }
              }
            }
          }

          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Color.muted
            opacity: 0.15
          }

          // Natural Scrolling (Key N)
          Rectangle {
            id: tpRowNatural
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            radius: 6
            color: (root.activeFocusSection && root.focusedCard === 4) ? Color.pickAlpha("surface.selected", "#2a3036") : "transparent"
            border.color: (root.activeFocusSection && root.focusedCard === 4) ? Color.accent : "transparent"
            border.width: (root.activeFocusSection && root.focusedCard === 4) ? 2 : 0

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.focusedCard = 4
                root.toggleNaturalScroll()
              }
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 8
              anchors.rightMargin: 8
              spacing: 10

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                RowLayout {
                  spacing: 6
                  Text {
                    text: "Natural (Inverse) Scrolling"
                    font.family: Style.font.family
                    font.pixelSize: 12
                    font.bold: true
                    color: Color.foreground
                  }

                  Rectangle {
                    width: 16
                    height: 16
                    radius: 3
                    color: Color.pickAlpha("surface.selected", "#2a3036")
                    Text {
                      anchors.centerIn: parent
                      text: "N"
                      font.family: Style.font.family
                      font.pixelSize: 9
                      color: Color.muted
                    }
                  }
                }

                Text {
                  text: "Content moves in the same direction as fingers (like mobile screens)"
                  font.family: Style.font.family
                  font.pixelSize: 10
                  color: Color.muted
                }
              }

              Button {
                text: root.naturalScroll ? "ON" : "OFF"
                implicitWidth: 60
                implicitHeight: 26
                bordered: true
                onClicked: {
                  root.focusedCard = 4
                  root.toggleNaturalScroll()
                }
              }
            }
          }

          // Tap to Click (Key C)
          Rectangle {
            id: tpRowTap
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            radius: 6
            color: (root.activeFocusSection && root.focusedCard === 5) ? Color.pickAlpha("surface.selected", "#2a3036") : "transparent"
            border.color: (root.activeFocusSection && root.focusedCard === 5) ? Color.accent : "transparent"
            border.width: (root.activeFocusSection && root.focusedCard === 5) ? 2 : 0

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.focusedCard = 5
                root.toggleTapToClick()
              }
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 8
              anchors.rightMargin: 8
              spacing: 10

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                RowLayout {
                  spacing: 6
                  Text {
                    text: "Tap to Click (Clickfinger)"
                    font.family: Style.font.family
                    font.pixelSize: 12
                    font.bold: true
                    color: Color.foreground
                  }

                  Rectangle {
                    width: 16
                    height: 16
                    radius: 3
                    color: Color.pickAlpha("surface.selected", "#2a3036")
                    Text {
                      anchors.centerIn: parent
                      text: "C"
                      font.family: Style.font.family
                      font.pixelSize: 9
                      color: Color.muted
                    }
                  }
                }

                Text {
                  text: "1 finger = left click, 2 fingers = right click, 3 fingers = middle click"
                  font.family: Style.font.family
                  font.pixelSize: 10
                  color: Color.muted
                }
              }

              Button {
                text: root.clickfingerBehavior ? "ON" : "OFF"
                implicitWidth: 60
                implicitHeight: 26
                bordered: true
                onClicked: {
                  root.focusedCard = 5
                  root.toggleTapToClick()
                }
              }
            }
          }

          // Touchpad Scroll Speed / Factor (Key S)
          Rectangle {
            id: tpRowSpeed
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            radius: 6
            color: (root.activeFocusSection && root.focusedCard === 6) ? Color.pickAlpha("surface.selected", "#2a3036") : "transparent"
            border.color: (root.activeFocusSection && root.focusedCard === 6) ? Color.accent : "transparent"
            border.width: (root.activeFocusSection && root.focusedCard === 6) ? 2 : 0

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.focusedCard = 6
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 8
              anchors.rightMargin: 8
              spacing: 10

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                RowLayout {
                  spacing: 6
                  Text {
                    text: "Touchpad Scroll Speed"
                    font.family: Style.font.family
                    font.pixelSize: 12
                    font.bold: true
                    color: Color.foreground
                  }

                  Rectangle {
                    width: 16
                    height: 16
                    radius: 3
                    color: Color.pickAlpha("surface.selected", "#2a3036")
                    Text {
                      anchors.centerIn: parent
                      text: "S"
                      font.family: Style.font.family
                      font.pixelSize: 9
                      color: Color.muted
                    }
                  }
                }

                Text {
                  text: "Multiplier for two-finger trackpad scrolling sensitivity"
                  font.family: Style.font.family
                  font.pixelSize: 10
                  color: Color.muted
                }
              }

              RowLayout {
                spacing: 4

                Button {
                  text: "◀"
                  implicitWidth: 28
                  implicitHeight: 26
                  bordered: true
                  onClicked: {
                    root.focusedCard = 6
                    root.cycleScrollFactor(-1)
                  }
                }

                Rectangle {
                  implicitWidth: 54
                  implicitHeight: 26
                  radius: 4
                  color: Color.pickAlpha("surface.selected", "#2a3036")

                  Text {
                    anchors.centerIn: parent
                    text: root.scrollFactor.toFixed(1) + "x"
                    font.family: Style.font.family
                    font.pixelSize: 11
                    font.bold: true
                    color: Color.foreground
                  }
                }

                Button {
                  text: "▶"
                  implicitWidth: 28
                  implicitHeight: 26
                  bordered: true
                  onClicked: {
                    root.focusedCard = 6
                    root.cycleScrollFactor(1)
                  }
                }
              }
            }
          }

          // Disable While Typing (Key D)
          Rectangle {
            id: tpRowTyping
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            radius: 6
            color: (root.activeFocusSection && root.focusedCard === 7) ? Color.pickAlpha("surface.selected", "#2a3036") : "transparent"
            border.color: (root.activeFocusSection && root.focusedCard === 7) ? Color.accent : "transparent"
            border.width: (root.activeFocusSection && root.focusedCard === 7) ? 2 : 0

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.focusedCard = 7
                root.toggleDisableWhileTyping()
              }
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 8
              anchors.rightMargin: 8
              spacing: 10

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                RowLayout {
                  spacing: 6
                  Text {
                    text: "Disable While Typing"
                    font.family: Style.font.family
                    font.pixelSize: 12
                    font.bold: true
                    color: Color.foreground
                  }

                  Rectangle {
                    width: 16
                    height: 16
                    radius: 3
                    color: Color.pickAlpha("surface.selected", "#2a3036")
                    Text {
                      anchors.centerIn: parent
                      text: "D"
                      font.family: Style.font.family
                      font.pixelSize: 9
                      color: Color.muted
                    }
                  }
                }

                Text {
                  text: "Temporarily freeze touchpad during keyboard input to avoid jumps"
                  font.family: Style.font.family
                  font.pixelSize: 10
                  color: Color.muted
                }
              }

              Button {
                text: root.disableWhileTyping ? "ON" : "OFF"
                implicitWidth: 60
                implicitHeight: 26
                bordered: true
                onClicked: {
                  root.focusedCard = 7
                  root.toggleDisableWhileTyping()
                }
              }
            }
          }
        }
      }

      // Pointer Sensitivity & Virtual Keyboard
      Rectangle {
        id: sensCard
        Layout.fillWidth: true
        Layout.preferredHeight: sensCol.implicitHeight + 24
        color: Color.pickAlpha("surface.subtle", "#181b1d")
        radius: Style.cornerRadius || 8

        ColumnLayout {
          id: sensCol
          anchors.fill: parent
          anchors.margins: 12
          spacing: 10

          // Sensitivity (Key A)
          Rectangle {
            id: sensRow
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            radius: 6
            color: (root.activeFocusSection && root.focusedCard === 8) ? Color.pickAlpha("surface.selected", "#2a3036") : "transparent"
            border.color: (root.activeFocusSection && root.focusedCard === 8) ? Color.accent : "transparent"
            border.width: (root.activeFocusSection && root.focusedCard === 8) ? 2 : 0

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.focusedCard = 8
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 8
              anchors.rightMargin: 8
              spacing: 10

              Text {
                text: "󰆽"
                font.family: Style.font.family
                font.pixelSize: 16
                color: Color.muted
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                RowLayout {
                  spacing: 6
                  Text {
                    text: "Pointer Sensitivity"
                    font.family: Style.font.family
                    font.pixelSize: 13
                    font.bold: true
                    color: Color.foreground
                  }

                  Rectangle {
                    width: 18
                    height: 18
                    radius: 3
                    color: Color.pickAlpha("surface.selected", "#2a3036")
                    Text {
                      anchors.centerIn: parent
                      text: "A"
                      font.family: Style.font.family
                      font.pixelSize: 10
                      color: Color.muted
                    }
                  }
                }

                Text {
                  text: "Global cursor acceleration curve (-0.5 to +0.8)"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  color: Color.muted
                }
              }

              RowLayout {
                spacing: 4

                Button {
                  text: "◀"
                  implicitWidth: 30
                  implicitHeight: 28
                  bordered: true
                  onClicked: {
                    root.focusedCard = 8
                    root.cycleSensitivity(-1)
                  }
                }

                Rectangle {
                  implicitWidth: 64
                  implicitHeight: 28
                  radius: 4
                  color: Color.pickAlpha("surface.selected", "#2a3036")

                  Text {
                    anchors.centerIn: parent
                    text: (root.sensitivity >= 0 ? "+" : "") + root.sensitivity.toFixed(1)
                    font.family: Style.font.family
                    font.pixelSize: 12
                    font.bold: true
                    color: Color.foreground
                  }
                }

                Button {
                  text: "▶"
                  implicitWidth: 30
                  implicitHeight: 28
                  bordered: true
                  onClicked: {
                    root.focusedCard = 8
                    root.cycleSensitivity(1)
                  }
                }
              }
            }
          }

          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Color.muted
            opacity: 0.15
          }

          // Virtual Keyboard Info
          RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
              text: "󰌌"
              font.family: Style.font.family
              font.pixelSize: 16
              color: root.virtualKeyboard ? Color.accent : Color.muted
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 1

              RowLayout {
                spacing: 8
                Text {
                  text: "Virtual On-Screen Keyboard"
                  font.family: Style.font.family
                  font.pixelSize: 13
                  font.bold: true
                  color: Color.foreground
                }

                Rectangle {
                  Layout.preferredHeight: 18
                  Layout.preferredWidth: vkStatusText.implicitWidth + 10
                  radius: 3
                  color: root.virtualKeyboard ? Color.pickAlpha("accent.subtle", "#1f3b30") : Color.pickAlpha("surface.selected", "#2a3036")

                  Text {
                    id: vkStatusText
                    anchors.centerIn: parent
                    text: root.virtualKeyboard ? "ACTIVE" : "STANDBY"
                    font.family: Style.font.family
                    font.pixelSize: 9
                    font.bold: true
                    color: root.virtualKeyboard ? Color.accent : Color.muted
                  }
                }
              }

              Text {
                text: "Fcitx5 / Wayland virtual keyboard input methods ready for touchscreen typing"
                font.family: Style.font.family
                font.pixelSize: 11
                color: Color.muted
              }
            }
          }
        }
      }

      Item { Layout.preferredHeight: 12 }
    }
  }
}
