import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Item {
  id: root

  property string pluginPath: ""
  property int brightness: 100
  property var monitors: []
  property var activeMonitor: monitors.length > 0 ? monitors[0] : null
  property real currentScale: activeMonitor ? Number(activeMonitor.scale) : 1.0

  readonly property var scaleOptions: [
    { label: "100%", value: "1" },
    { label: "125%", value: "1.25" },
    { label: "150%", value: "1.5" },
    { label: "160%", value: "1.6" },
    { label: "200%", value: "2" }
  ]

  readonly property var commonModes: [
    { label: "1920 × 1080 (FHD)", mode: "1920x1080@60" },
    { label: "1600 × 900", mode: "1600x900@60" },
    { label: "1366 × 768", mode: "1366x768@60" },
    { label: "1280 × 720 (HD)", mode: "1280x720@60" }
  ]

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
  }

  function setScale(scaleVal) {
    setScaleProcess.command = [pluginPath + "/scripts/display-control.sh", "set-scale", String(scaleVal)]
    setScaleProcess.running = true
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

      // Section: Monitor Info Card
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
            width: 44
            height: 44
            radius: 8
            color: Color.pickAlpha("surface.selected", "#2a3036")

            Text {
              anchors.centerIn: parent
              text: "󰍹"
              font.family: Style.font.family
              font.pixelSize: 22
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
                width: 60
                height: 18
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

      // Section: Brightness
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 90
        color: Color.pickAlpha("surface.subtle", "#181b1d")
        radius: Style.cornerRadius || 8

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 14
          spacing: 8

          RowLayout {
            Layout.fillWidth: true
            Text {
              text: "󰃠  Brightness"
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

      // Section: Scaling
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 100
        color: Color.pickAlpha("surface.subtle", "#181b1d")
        radius: Style.cornerRadius || 8

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 14
          spacing: 10

          ColumnLayout {
            spacing: 2
            Text {
              text: "󰘵  Display Scaling"
              font.family: Style.font.family
              font.pixelSize: Style.font.subtitle || 14
              font.bold: true
              color: Color.foreground
            }
            Text {
              text: "Scale text, icons, and interface elements for high-DPI displays."
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

      // Section: Resolution & Modes
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 130
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
                text: "󰹑  Resolution"
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle || 14
                font.bold: true
                color: Color.foreground
              }

              Item { Layout.fillWidth: true }

              Text {
                text: activeMonitor ? (activeMonitor.width + " × " + activeMonitor.height + " @ " + activeMonitor.refreshRate + " Hz") : ""
                font.family: Style.font.family
                font.pixelSize: Style.font.subtext || 12
                color: Color.accent
              }
            }

            Text {
              text: "Choose a screen resolution suited to your workflow."
              font.family: Style.font.family
              font.pixelSize: Style.font.subtext || 11
              color: Color.muted
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

      Item { Layout.preferredHeight: 12 }
    }
  }
}
