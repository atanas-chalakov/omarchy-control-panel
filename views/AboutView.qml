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
  property string osName: "Omarchy"
  property string osVersion: "4.0.3"
  property string kernel: ""
  property string cpu: ""
  property string ram: ""
  property string uptime: ""
  property string hostname: ""
  property string timezone: ""
  property string ntp: ""
  property bool activeFocusSection: false

  function handleMove(dx, dy) {
    return true
  }

  function handleActivate() {
    refresh()
  }

  function handleTextKey(key) {
    if (key === "r" || key === "R") {
      refresh()
    } else if (key === "t" || key === "T") {
      openTimezonePicker()
    }
  }

  function openTimezonePicker() {
    actionProcess.command = [pluginPath + "/scripts/system-control.sh", "about-set-timezone"]
    actionProcess.running = true
  }

  function refresh() {
    if (!stateProcess.running && pluginPath.length > 0) {
      stateProcess.command = [pluginPath + "/scripts/system-control.sh", "about-get"]
      stateProcess.running = true
    }
  }

  Component.onCompleted: refresh()

  // Action Process
  Process {
    id: actionProcess
  }

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
          if (data.timezone) root.timezone = data.timezone
          if (data.ntp) root.ntp = data.ntp
        } catch (e) {
          console.warn("AboutView: JSON parse error", e)
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
      spacing: 16

      // Hero Card
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: Math.max(90, heroLayout.implicitHeight + 32)
        Layout.preferredHeight: implicitHeight
        color: Color.pickAlpha("surface.subtle", "#181b1d")
        radius: Style.cornerRadius || 8

        RowLayout {
          id: heroLayout
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
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
            Layout.minimumWidth: 0
            spacing: 4

            Flow {
              Layout.fillWidth: true
              width: parent.width
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
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              wrapMode: Text.WordWrap
              text: "Arch Linux based • Hyprland compositor • Quickshell desktop"
              font.family: Style.font.family
              font.pixelSize: Style.font.subtext || 12
              color: Color.muted
            }
          }

          Button {
            text: "Refresh"
            iconText: ""
            bordered: true
            hasCursor: root.activeFocusSection
            onClicked: root.refresh()
          }
        }
      }

      // Hardware Specs Card
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: Math.max(200, specsLayout.implicitHeight + 32)
        Layout.preferredHeight: implicitHeight
        color: Color.pickAlpha("surface.subtle", "#181b1d")
        radius: Style.cornerRadius || 8

        ColumnLayout {
          id: specsLayout
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
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
            columns: parent.width >= 480 ? 2 : 1
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
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              wrapMode: Text.WordWrap
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
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              wrapMode: Text.WordWrap
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
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              wrapMode: Text.WordWrap
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
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              wrapMode: Text.WordWrap
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
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              wrapMode: Text.WordWrap
              text: root.uptime
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.body || 13
              font.bold: true
            }
          }
        }
      }

      // Time & Region Card
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: Math.max(76, tzColLayout.implicitHeight + 28)
        Layout.preferredHeight: implicitHeight
        color: Color.pickAlpha("surface.subtle", "#181b1d")
        radius: Style.cornerRadius || 8

        ColumnLayout {
          id: tzColLayout
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 16
          spacing: 12

          RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
              width: 38
              height: 38
              radius: 8
              color: Color.pickAlpha("accent.subtle", "#203a30")

              Text {
                anchors.centerIn: parent
                text: "󰃭"
                font.family: Style.font.family
                font.pixelSize: 18
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
                  text: "Timezone & Network Time"
                  font.family: Style.font.family
                  font.pixelSize: 13
                  font.bold: true
                  color: Color.foreground
                }

                Rectangle {
                  visible: root.ntp.length > 0
                  width: ntpText.implicitWidth + 10
                  height: 18
                  radius: 4
                  color: (root.ntp === "active") ? Color.pickAlpha("accent.subtle", "#203a30") : Color.pickAlpha("surface.hover", "#22272c")

                  Text {
                    id: ntpText
                    anchors.centerIn: parent
                    text: "NTP: " + root.ntp.toUpperCase()
                    font.family: Style.font.family
                    font.pixelSize: 10
                    font.bold: true
                    color: (root.ntp === "active") ? Color.accent : Color.muted
                  }
                }
              }

              Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                wrapMode: Text.WordWrap
                text: root.timezone.length > 0 ? root.timezone : "Loading timezone..."
                font.family: Style.font.family
                font.pixelSize: 12
                color: Color.muted
              }
            }

            Button {
              text: "󰃭 Change Timezone [T]"
              onClicked: root.openTimezonePicker()
            }
          }
        }
      }

      Item { Layout.preferredHeight: 12 }
    }
  }
}
