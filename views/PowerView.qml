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
  property string currentProfile: "balanced"
  property int batteryCapacity: 100
  property string batteryStatus: "Unknown"
  property bool batteryPresent: false
  property bool acOnline: true
  property int screensaverTimeout: 150
  property int lockTimeout: 300

  readonly property var powerProfiles: [
    {
      id: "power-saver",
      title: "Power Saver",
      icon: "",
      description: "Low power draw, reduces CPU frequency to extend battery run time."
    },
    {
      id: "balanced",
      title: "Balanced",
      icon: "󰾅",
      description: "Standard dynamic scaling balancing performance and battery longevity."
    },
    {
      id: "performance",
      title: "Performance",
      icon: "󰓅",
      description: "Maximum responsiveness and CPU clock speeds for heavy development tasks."
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

  function refresh() {
    if (!stateProcess.running && pluginPath.length > 0) {
      stateProcess.command = [pluginPath + "/scripts/power-control.sh", "get-state"]
      stateProcess.running = true
    }
  }

  function setProfile(profileId) {
    root.currentProfile = profileId
    setProfileProcess.command = [pluginPath + "/scripts/power-control.sh", "set-profile", profileId]
    setProfileProcess.running = true
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
          if (data.profile) root.currentProfile = data.profile
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
    onRunningChanged: if (!running) root.refresh()
  }

  // Set Idle Process
  Process {
    id: setIdleProcess
    onRunningChanged: if (!running) root.refresh()
  }

  ScrollView {
    anchors.fill: parent
    clip: true

    ColumnLayout {
      width: parent.width - 24
      spacing: 16

      // Section: Battery & Power Status Card
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 84
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
              text: root.acOnline ? "󰂄" : (root.batteryCapacity > 20 ? "󰁹" : "󰂃")
              font.family: Style.font.family
              font.pixelSize: 24
              color: root.acOnline ? Color.accent : (root.batteryCapacity > 20 ? Color.foreground : Color.urgent)
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
              spacing: 8
              Text {
                text: root.batteryPresent ? ("Battery: " + root.batteryCapacity + "%") : "External Power"
                font.family: Style.font.family
                font.pixelSize: Style.font.title || 16
                font.bold: true
                color: Color.foreground
              }

              Rectangle {
                width: 76
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
              text: root.batteryPresent ? ("State: " + root.batteryStatus) : "Running on direct AC power"
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

      // Section: Power Profile Selector Cards
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 180
        color: Color.pickAlpha("surface.subtle", "#181b1d")
        radius: Style.cornerRadius || 8

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 14
          spacing: 10

          ColumnLayout {
            spacing: 2
            Text {
              text: "󰓅  Power Mode Profile"
              font.family: Style.font.family
              font.pixelSize: Style.font.subtitle || 14
              font.bold: true
              color: Color.foreground
            }
            Text {
              text: "Select how system power and CPU governor behave on AC and battery."
              font.family: Style.font.family
              font.pixelSize: Style.font.subtext || 11
              color: Color.muted
            }
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Repeater {
              model: root.powerProfiles

              delegate: Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 6
                color: (root.currentProfile === modelData.id)
                  ? Color.pickAlpha("surface.selected", "#2a3036")
                  : Color.pickAlpha("surface.hover", "#1f2327")
                border.color: (root.currentProfile === modelData.id) ? Color.accent : "transparent"
                border.width: 1

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.setProfile(modelData.id)
                }

                ColumnLayout {
                  anchors.fill: parent
                  anchors.margins: 10
                  spacing: 4

                  RowLayout {
                    spacing: 6
                    Text {
                      text: modelData.icon
                      font.family: Style.font.family
                      font.pixelSize: 14
                      color: (root.currentProfile === modelData.id) ? Color.accent : Color.muted
                    }
                    Text {
                      text: modelData.title
                      font.family: Style.font.family
                      font.pixelSize: Style.font.body || 13
                      font.bold: true
                      color: Color.foreground
                    }
                  }

                  Text {
                    Layout.fillWidth: true
                    text: modelData.description
                    font.family: Style.font.family
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                    color: Color.muted
                    maximumLineCount: 2
                    elide: Text.ElideRight
                  }
                }
              }
            }
          }
        }
      }

      // Section: Screen Turn-Off Timeout
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
            Text {
              text: "󰍹  Screen Off Timeout"
              font.family: Style.font.family
              font.pixelSize: Style.font.subtitle || 14
              font.bold: true
              color: Color.foreground
            }

            Item { Layout.fillWidth: true }

            Text {
              text: {
                for (var i = 0; i < root.screensaverOptions.length; i++) {
                  if (root.screensaverOptions[i].seconds === root.screensaverTimeout)
                    return root.screensaverOptions[i].label
                }
                return Math.round(root.screensaverTimeout / 60) + " min"
              }
              font.family: Style.font.family
              font.pixelSize: Style.font.subtext || 12
              color: Color.accent
            }
          }

          Text {
            text: "Turn off screen or start screensaver when inactive."
            font.family: Style.font.family
            font.pixelSize: Style.font.subtext || 11
            color: Color.muted
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
              model: root.screensaverOptions

              delegate: Button {
                Layout.fillWidth: true
                text: modelData.label
                selected: root.screensaverTimeout === modelData.seconds
                onClicked: root.setIdle(modelData.seconds, root.lockTimeout)
              }
            }
          }
        }
      }

      // Section: Lock Screen Timeout
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
            Text {
              text: "  Lock Screen Timeout"
              font.family: Style.font.family
              font.pixelSize: Style.font.subtitle || 14
              font.bold: true
              color: Color.foreground
            }

            Item { Layout.fillWidth: true }

            Text {
              text: {
                for (var i = 0; i < root.lockOptions.length; i++) {
                  if (root.lockOptions[i].seconds === root.lockTimeout)
                    return root.lockOptions[i].label
                }
                return Math.round(root.lockTimeout / 60) + " min"
              }
              font.family: Style.font.family
              font.pixelSize: Style.font.subtext || 12
              color: Color.accent
            }
          }

          Text {
            text: "Lock the computer automatically after idle period."
            font.family: Style.font.family
            font.pixelSize: Style.font.subtext || 11
            color: Color.muted
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
              model: root.lockOptions

              delegate: Button {
                Layout.fillWidth: true
                text: modelData.label
                selected: root.lockTimeout === modelData.seconds
                onClicked: root.setIdle(root.screensaverTimeout, modelData.seconds)
              }
            }
          }
        }
      }

      Item { Layout.preferredHeight: 12 }
    }
  }
}
