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
  property string osName: "Omarchy"
  property string osVersion: "4.0.3"
  property string kernel: ""
  property string cpu: ""
  property string ram: ""
  property string uptime: ""
  property string hostname: ""

  function refresh() {
    if (!stateProcess.running && pluginPath.length > 0) {
      stateProcess.command = [pluginPath + "/scripts/system-control.sh", "about-get"]
      stateProcess.running = true
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
          if (data.os) root.osName = data.os
          if (data.version) root.osVersion = data.version
          if (data.kernel) root.kernel = data.kernel
          if (data.cpu) root.cpu = data.cpu
          if (data.ram) root.ram = data.ram
          if (data.uptime) root.uptime = data.uptime
          if (data.hostname) root.hostname = data.hostname
        } catch (e) {
          console.warn("AboutView: JSON parse error", e)
        }
      }
    }
  }

  ScrollView {
    anchors.fill: parent
    clip: true

    ColumnLayout {
      width: parent.width - 24
      spacing: 16

      // Hero Card
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 100
        color: Color.pickAlpha("surface.subtle", "#181b1d")
        radius: Style.cornerRadius || 8

        RowLayout {
          anchors.fill: parent
          anchors.margins: 16
          spacing: 16

          Rectangle {
            width: 56
            height: 56
            radius: 12
            color: Color.pickAlpha("surface.selected", "#2a3036")

            Text {
              anchors.centerIn: parent
              text: "󰣇"
              font.family: Style.font.family
              font.pixelSize: 32
              color: Color.accent
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            RowLayout {
              spacing: 8
              Text {
                text: root.osName
                font.family: Style.font.family
                font.pixelSize: 20
                font.bold: true
                color: Color.foreground
              }

              Rectangle {
                width: 60
                height: 20
                radius: 4
                color: Color.pickAlpha("accent.subtle", "#1f3b30")

                Text {
                  anchors.centerIn: parent
                  text: "v" + root.osVersion
                  font.family: Style.font.family
                  font.pixelSize: 11
                  font.bold: true
                  color: Color.accent
                }
              }
            }

            Text {
              text: "Arch Linux based • Hyprland compositor • Quickshell desktop"
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

      // Hardware Specs Card
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 220
        color: Color.pickAlpha("surface.subtle", "#181b1d")
        radius: Style.cornerRadius || 8

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 16
          spacing: 12

          Text {
            text: "󰍹  Hardware & System Details"
            font.family: Style.font.family
            font.pixelSize: Style.font.subtitle || 14
            font.bold: true
            color: Color.foreground
          }

          GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: 10
            columnSpacing: 20

            // Row 1
            Text {
              text: "Hostname:"
              color: Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.body || 13
            }
            Text {
              text: root.hostname
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.body || 13
              font.bold: true
            }

            // Row 2
            Text {
              text: "Processor (CPU):"
              color: Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.body || 13
            }
            Text {
              text: root.cpu
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.body || 13
              font.bold: true
            }

            // Row 3
            Text {
              text: "Memory (RAM):"
              color: Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.body || 13
            }
            Text {
              text: root.ram
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.body || 13
              font.bold: true
            }

            // Row 4
            Text {
              text: "Linux Kernel:"
              color: Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.body || 13
            }
            Text {
              text: root.kernel
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.body || 13
              font.bold: true
            }

            // Row 5
            Text {
              text: "System Uptime:"
              color: Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.body || 13
            }
            Text {
              text: root.uptime
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.body || 13
              font.bold: true
            }
          }
        }
      }

      Item { Layout.preferredHeight: 12 }
    }
  }
}
