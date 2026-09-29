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

  // Keyboard navigation handler from parent
  function handleKeyH(dx) {
    if (dx < 0) {
      setBrightness(Math.max(5, root.brightness - 5))
    } else {
      setBrightness(Math.min(100, root.brightness + 5))
    }
  }

  function handleActivate() {
    refresh()
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
      spacing: 16

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

      // Section: Monitor Info Card
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 80
        color: Color.pickAlpha("surface.subtle", "#181b1d")
        radius: Style.cornerRadius || 8

        RowLayout {
          anchors.fill: parent
          anchors.margins: 14
          spacing: 14

          Rectangle {
            width: 48
            height: 48
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
                width: 68
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
              text: activeMonitor ? (activeMonitor.description || activeMonitor.model || "") : ""
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

      // Section: Resolution Selection
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 140
        color: Color.pickAlpha("surface.subtle", "#181b1d")
        radius: Style.cornerRadius || 8

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 14
          spacing: 10

          RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
              spacing: 2
              Text {
                text: "󰹑  Screen Resolution"
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle || 14
                font.bold: true
                color: Color.foreground
              }
              Text {
                text: "Click any resolution below to apply and persist to monitors.lua"
                font.family: Style.font.family
                font.pixelSize: Style.font.subtext || 11
                color: Color.muted
              }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
              width: 130
              height: 24
              radius: 4
              color: Color.pickAlpha("surface.selected", "#2a3036")

              Text {
                anchors.centerIn: parent
                text: activeMonitor ? (activeMonitor.width + "x" + activeMonitor.height + " @ " + activeMonitor.refreshRate + "Hz") : ""
                font.family: Style.font.family
                font.pixelSize: 11
                font.bold: true
                color: Color.accent
              }
            }
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
              model: root.commonModes

              delegate: Button {
                Layout.fillWidth: true
                text: modelData.label
                selected: {
                  if (!activeMonitor) return false
                  var resPrefix = activeMonitor.width + "x" + activeMonitor.height
                  return modelData.mode.indexOf(resPrefix) === 0
                }
                onClicked: root.setMode(modelData.mode)
              }
            }
          }
        }
      }

      // Section: Scaling
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 110
        color: Color.pickAlpha("surface.subtle", "#181b1d")
        radius: Style.cornerRadius || 8

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 14
          spacing: 10

          ColumnLayout {
            spacing: 2
            RowLayout {
              Text {
                text: "󰘵  Display Scaling"
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle || 14
                font.bold: true
                color: Color.foreground
              }

              Item { Layout.fillWidth: true }

              Text {
                text: "Current: " + root.currentScale + "x"
                font.family: Style.font.family
                font.pixelSize: Style.font.subtext || 12
                color: Color.accent
              }
            }

            Text {
              text: "Scale text, window borders, and UI elements for high-DPI display."
              font.family: Style.font.family
              font.pixelSize: Style.font.subtext || 11
              color: Color.muted
            }
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
              model: root.scaleOptions

              delegate: Button {
                Layout.fillWidth: true
                text: modelData.label
                selected: {
                  var target = Number(modelData.value)
                  return Math.abs(root.currentScale - target) < 0.05
                }
                onClicked: root.setScale(modelData.value)
              }
            }
          }
        }
      }

      // Section: Brightness
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 104
        color: Color.pickAlpha("surface.subtle", "#181b1d")
        radius: Style.cornerRadius || 8

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 14
          spacing: 8

          RowLayout {
            Layout.fillWidth: true
            Text {
              text: "󰃠  Brightness  (Use [h/l] to adjust ±5%)"
              font.family: Style.font.family
              font.pixelSize: Style.font.subtitle || 14
              font.bold: true
              color: Color.foreground
            }

            Item { Layout.fillWidth: true }

            Text {
              text: root.brightness + "%"
              font.family: Style.font.family
              font.pixelSize: Style.font.subtitle || 14
              font.bold: true
              color: Color.accent
            }

            Button {
              text: "-5%"
              onClicked: root.handleKeyH(-1)
            }

            Button {
              text: "+5%"
              onClicked: root.handleKeyH(1)
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

      Item { Layout.preferredHeight: 12 }
    }
  }
}
