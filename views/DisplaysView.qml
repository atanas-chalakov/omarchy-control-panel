import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Item {
  id: root

  property string pluginPath: "/home/ac/.config/omarchy/plugins/ac.control-panel"
  onPluginPathChanged: refresh()
  property int brightness: 100
  property var monitors: []
  property var activeMonitor: monitors.length > 0 ? monitors[0] : null
  property real currentScale: activeMonitor ? Number(activeMonitor.scale) : 1.0
  property string statusMessage: ""

  readonly property var scaleOptions: [
    { label: "100%", value: "1" },
    { label: "125%", value: "1.25" },
    { label: "150%", value: "1.5" },
    { label: "160%", value: "1.6" },
    { label: "200%", value: "2" }
  ]

  readonly property var commonModes: [
    { label: "1920 × 1080 (FHD)", mode: "1920x1080@60.008" },
    { label: "1600 × 900", mode: "1600x900@60" },
    { label: "1366 × 768", mode: "1366x768@60" },
    { label: "1280 × 720 (HD)", mode: "1280x720@60" }
  ]

  property bool activeFocusSection: false
  property int focusedRow: 0   // 0: Brightness, 1: Scale, 2: Resolution

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
    var resPrefix = activeMonitor.width + "x" + activeMonitor.height
    for (var i = 0; i < commonModes.length; i++) {
      if (commonModes[i].mode.indexOf(resPrefix) === 0) return i
    }
    return 0
  }

  function cycleScale(delta) {
    var idx = currentScaleIndex()
    var next = Math.max(0, Math.min(scaleOptions.length - 1, idx + delta))
    setScale(scaleOptions[next].value)
  }

  function cycleMode(delta) {
    var idx = currentModeIndex()
    var next = Math.max(0, Math.min(commonModes.length - 1, idx + delta))
    setMode(commonModes[next].mode)
  }

  function adjustBrightness(delta) {
    var val = Math.max(5, Math.min(100, root.brightness + delta))
    setBrightness(val)
  }

  function handleMove(dx, dy) {
    if (dy !== 0) {
      focusedRow = Math.max(0, Math.min(2, focusedRow + dy))
      return true
    }
    if (dx !== 0) {
      if (focusedRow === 0) adjustBrightness(dx * 5)
      else if (focusedRow === 1) cycleScale(dx)
      else if (focusedRow === 2) cycleMode(dx)
      return true
    }
    return false
  }

  function handleActivate() {
    if (focusedRow === 0) adjustBrightness(5)
    else if (focusedRow === 1) cycleScale(1)
    else if (focusedRow === 2) cycleMode(1)
  }

  function handleTextKey(key) {
    if (key === "r" || key === "R") {
      refresh()
    } else if (key === "b" || key === "B") {
      focusedRow = 0
    } else if (key === "s" || key === "S") {
      focusedRow = 1
    } else if (key === "m" || key === "M") {
      focusedRow = 2
    } else if (key === "h" || key === "H") {
      adjustBrightness(-5)
    } else if (key === "l" || key === "L") {
      adjustBrightness(5)
    }
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
        } catch (e) {
          console.warn("DisplaysView: JSON parse error", e)
        }
      }
    }
  }

  // Set Brightness Process
  Process {
    id: setBrightnessProcess
  }

  // Set Scale Process
  Process {
    id: setScaleProcess
    onRunningChanged: if (!running) root.refresh()
  }

  // Set Mode Process
  Process {
    id: setModeProcess
    onRunningChanged: if (!running) root.refresh()
  }

  ScrollView {
    anchors.fill: parent
    clip: true

    ColumnLayout {
      width: parent.width - 24
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
        Layout.fillWidth: true
        Layout.preferredHeight: 76
        color: Color.pickAlpha("surface.subtle", "#181b1d")
        radius: Style.cornerRadius || 8

        RowLayout {
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
              text: "󰍹"
              font.family: Style.font.family
              font.pixelSize: 24
              color: Color.accent
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
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
        Layout.preferredHeight: 112
        radius: Style.cornerRadius || 8
        readonly property bool isFocused: root.activeFocusSection && root.focusedRow === 0
        color: brightnessCard.isFocused ? Color.pickAlpha("surface.selected", "#22272e") : Color.pickAlpha("surface.subtle", "#181b1d")
        border.color: brightnessCard.isFocused ? Color.accent : "transparent"
        border.width: brightnessCard.isFocused ? 2 : 1

        MouseArea {
          anchors.fill: parent
          z: -1
          onClicked: root.focusedRow = 0
        }

        ColumnLayout {
          anchors.fill: parent
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
              spacing: 2

              RowLayout {
                spacing: 8
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
                }
              }

              Text {
                text: "Backlight screen brightness percentage."
                font.family: Style.font.family
                font.pixelSize: Style.font.subtext || 11
                color: Color.muted
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

      // Setting Row 1: Display Scaling Stepper Card
      Rectangle {
        id: scaleCard
        Layout.fillWidth: true
        Layout.preferredHeight: 112
        radius: Style.cornerRadius || 8
        readonly property bool isFocused: root.activeFocusSection && root.focusedRow === 1
        color: scaleCard.isFocused ? Color.pickAlpha("surface.selected", "#22272e") : Color.pickAlpha("surface.subtle", "#181b1d")
        border.color: scaleCard.isFocused ? Color.accent : "transparent"
        border.width: scaleCard.isFocused ? 2 : 1

        MouseArea {
          anchors.fill: parent
          z: -1
          onClicked: root.focusedRow = 1
        }

        ColumnLayout {
          anchors.fill: parent
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
              spacing: 2

              RowLayout {
                spacing: 8
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
                }
              }

              Text {
                text: "Interface, window border, and font scale factor."
                font.family: Style.font.family
                font.pixelSize: Style.font.subtext || 11
                color: Color.muted
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
                  root.focusedRow = 1
                  root.cycleScale(-1)
                }
              }

              Button {
                text: "▶"
                implicitWidth: 32
                implicitHeight: 32
                bordered: true
                onClicked: {
                  root.focusedRow = 1
                  root.cycleScale(1)
                }
              }
            }
          }

          // Visual segmented option cards
          RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
              model: root.scaleOptions

              delegate: Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                radius: 6
                readonly property bool isSelected: Math.abs(root.currentScale - Number(modelData.value)) < 0.05
                color: isSelected ? Color.pickAlpha("accent.subtle", "#1f3b30") : Color.pickAlpha("surface.hover", "#1b1f23")
                border.color: isSelected ? Color.accent : "transparent"
                border.width: isSelected ? 1 : 0

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.focusedRow = 1
                    root.setScale(modelData.value)
                  }
                }

                Text {
                  anchors.centerIn: parent
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

      // Setting Row 2: Resolution Stepper Card
      Rectangle {
        id: modeCard
        Layout.fillWidth: true
        Layout.preferredHeight: 112
        radius: Style.cornerRadius || 8
        readonly property bool isFocused: root.activeFocusSection && root.focusedRow === 2
        color: modeCard.isFocused ? Color.pickAlpha("surface.selected", "#22272e") : Color.pickAlpha("surface.subtle", "#181b1d")
        border.color: modeCard.isFocused ? Color.accent : "transparent"
        border.width: modeCard.isFocused ? 2 : 1

        MouseArea {
          anchors.fill: parent
          z: -1
          onClicked: root.focusedRow = 2
        }

        ColumnLayout {
          anchors.fill: parent
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
              spacing: 2

              RowLayout {
                spacing: 8
                Text {
                  text: "Screen Resolution"
                  font.family: Style.font.family
                  font.pixelSize: Style.font.subtitle || 14
                  font.bold: true
                  color: Color.foreground
                }
                Text {
                  visible: modeCard.isFocused
                  text: "• Use [←/→ or h/l] to cycle"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  color: Color.accent
                }
              }

              Text {
                text: "Resolution modes configured for this display."
                font.family: Style.font.family
                font.pixelSize: Style.font.subtext || 11
                color: Color.muted
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
                  root.cycleMode(-1)
                }
              }

              Button {
                text: "▶"
                implicitWidth: 32
                implicitHeight: 32
                bordered: true
                onClicked: {
                  root.focusedRow = 2
                  root.cycleMode(1)
                }
              }
            }
          }

          // Visual segmented option cards
          RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
              model: root.commonModes

              delegate: Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                radius: 6
                readonly property bool isSelected: {
                  if (!activeMonitor) return false
                  var resPrefix = activeMonitor.width + "x" + activeMonitor.height
                  return modelData.mode.indexOf(resPrefix) === 0
                }
                color: isSelected ? Color.pickAlpha("accent.subtle", "#1f3b30") : Color.pickAlpha("surface.hover", "#1b1f23")
                border.color: isSelected ? Color.accent : "transparent"
                border.width: isSelected ? 1 : 0

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.focusedRow = 2
                    root.setMode(modelData.mode)
                  }
                }

                Text {
                  anchors.centerIn: parent
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
