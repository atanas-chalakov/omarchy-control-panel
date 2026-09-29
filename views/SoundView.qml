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
  property int volume: 50
  property bool muted: false
  property var sinks: []
  property string statusMessage: ""
  property bool activeFocusSection: false
  property int focusedRow: 0   // 0: Volume Controls, 1: Output Devices
  property int focusedCol: 0   // 0: -5%, 1: +5%, 2: Mute
  property int focusedSinkIndex: 0

  function handleMove(dx, dy) {
    if (dy !== 0) {
      if (dy > 0) {
        if (focusedRow === 0 && sinks.length > 0) {
          focusedRow = 1
          return true
        } else if (focusedRow === 1) {
          focusedSinkIndex = Math.min(sinks.length - 1, focusedSinkIndex + 1)
          return true
        }
      } else {
        if (focusedRow === 1) {
          if (focusedSinkIndex === 0) {
            focusedRow = 0
          } else {
            focusedSinkIndex = Math.max(0, focusedSinkIndex - 1)
          }
          return true
        }
      }
      return false
    }
    if (dx !== 0) {
      if (focusedRow === 0) {
        if (dx < 0 && focusedCol === 0) {
          return false // back to sidebar
        }
        if (dx > 0) {
          focusedCol = Math.min(2, focusedCol + 1)
        } else {
          focusedCol = Math.max(0, focusedCol - 1)
        }
        return true
      } else if (focusedRow === 1) {
        if (dx < 0) {
          return false // back to sidebar
        }
      }
    }
    return false
  }

  function handleActivate() {
    if (focusedRow === 0) {
      if (focusedCol === 0) {
        handleKeyH(-1)
      } else if (focusedCol === 1) {
        handleKeyH(1)
      } else if (focusedCol === 2) {
        toggleMute()
      }
    } else if (focusedRow === 1) {
      if (focusedSinkIndex >= 0 && focusedSinkIndex < sinks.length) {
        setDefaultSink(sinks[focusedSinkIndex].id, sinks[focusedSinkIndex].name)
      }
    }
  }

  function handleTextKey(key) {
    if (key === "m" || key === "M") {
      toggleMute()
    } else if (key === "h" || key === "H") {
      handleKeyH(-1)
    } else if (key === "l" || key === "L") {
      handleKeyH(1)
    } else if (key === "r" || key === "R") {
      refresh()
    }
  }

  // Keyboard navigation handler from parent
  function handleKeyH(dx) {
    if (dx < 0) {
      setVolume(Math.max(0, root.volume - 5))
    } else {
      setVolume(Math.min(100, root.volume + 5))
    }
  }

  function refresh() {
    if (!stateProcess.running && pluginPath.length > 0) {
      stateProcess.command = [pluginPath + "/scripts/system-control.sh", "audio-get"]
      stateProcess.running = true
    }
  }

  function setVolume(val) {
    var v = Math.round(val)
    root.volume = v
    setVolProcess.command = [pluginPath + "/scripts/system-control.sh", "audio-set-volume", String(v)]
    setVolProcess.running = true
    notifyStatus("Volume: " + v + "%")
  }

  function toggleMute() {
    root.muted = !root.muted
    setMuteProcess.command = [pluginPath + "/scripts/system-control.sh", "audio-set-mute", "toggle"]
    setMuteProcess.running = true
    notifyStatus(root.muted ? "Audio Muted" : "Audio Unmuted")
  }

  function setDefaultSink(id, name) {
    setSinkProcess.command = [pluginPath + "/scripts/system-control.sh", "audio-set-sink", String(id)]
    setSinkProcess.running = true
    notifyStatus("Output: " + name)
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
          if (data.volume !== undefined) root.volume = data.volume
          if (data.muted !== undefined) root.muted = data.muted
          if (Array.isArray(data.sinks)) root.sinks = data.sinks
        } catch (e) {
          console.warn("SoundView: JSON parse error", e)
        }
      }
    }
  }

  // Set Volume Process
  Process {
    id: setVolProcess
  }

  // Set Mute Process
  Process {
    id: setMuteProcess
    onRunningChanged: if (!running) root.refresh()
  }

  // Set Sink Process
  Process {
    id: setSinkProcess
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

      // Section: Master Volume
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 120
        color: Color.pickAlpha("surface.subtle", "#181b1d")
        radius: Style.cornerRadius || 8

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 14
          spacing: 10

          RowLayout {
            Layout.fillWidth: true
            Text {
              text: root.muted ? "󰝟  Master Volume" : (root.volume > 50 ? "󰕾  Master Volume" : "󰖀  Master Volume")
              font.family: Style.font.family
              font.pixelSize: Style.font.subtitle || 14
              font.bold: true
              color: root.muted ? Color.urgent : Color.foreground
            }

            Text {
              text: " (Use [h/l] to adjust, [m] to mute)"
              font.family: Style.font.family
              font.pixelSize: Style.font.subtext || 11
              color: Color.muted
            }

            Item { Layout.fillWidth: true }

            Text {
              text: root.muted ? "MUTED" : (root.volume + "%")
              font.family: Style.font.family
              font.pixelSize: Style.font.subtitle || 14
              font.bold: true
              color: root.muted ? Color.urgent : Color.accent
            }

            Button {
              text: "-5%"
              bordered: true
              hasCursor: root.activeFocusSection && root.focusedRow === 0 && root.focusedCol === 0
              onClicked: {
                root.focusedRow = 0
                root.focusedCol = 0
                root.handleKeyH(-1)
              }
            }

            Button {
              text: "+5%"
              bordered: true
              hasCursor: root.activeFocusSection && root.focusedRow === 0 && root.focusedCol === 1
              onClicked: {
                root.focusedRow = 0
                root.focusedCol = 1
                root.handleKeyH(1)
              }
            }

            Button {
              text: root.muted ? "Unmute" : "Mute"
              iconText: root.muted ? "󰕾" : "󰝟"
              selected: root.muted
              bordered: true
              hasCursor: root.activeFocusSection && root.focusedRow === 0 && root.focusedCol === 2
              onClicked: {
                root.focusedRow = 0
                root.focusedCol = 2
                root.toggleMute()
              }
            }
          }

          PanelSlider {
            Layout.fillWidth: true
            minimum: 0
            maximum: 100
            step: 1
            integer: true
            value: root.volume
            onMoved: function(v) { root.volume = Math.round(v) }
            onReleased: function(v) { root.setVolume(v) }
          }
        }
      }

      // Section: Output Devices
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 190
        color: Color.pickAlpha("surface.subtle", "#181b1d")
        radius: Style.cornerRadius || 8

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 14
          spacing: 10

          RowLayout {
            Layout.fillWidth: true
            Text {
              text: "󰓃  Audio Output Devices"
              font.family: Style.font.family
              font.pixelSize: Style.font.subtitle || 14
              font.bold: true
              color: Color.foreground
            }

            Item { Layout.fillWidth: true }

            Button {
              text: "Refresh"
              iconText: ""
              onClicked: root.refresh()
            }
          }

          Text {
            text: "Click any device below to make it your active default audio output."
            font.family: Style.font.family
            font.pixelSize: Style.font.subtext || 11
            color: Color.muted
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
              model: root.sinks

              delegate: Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                radius: 6
                readonly property bool isCursorTarget: root.activeFocusSection && root.focusedRow === 1 && root.focusedSinkIndex === index
                color: isCursorTarget
                  ? Color.pickAlpha("surface.selected", "#2a3036")
                  : (modelData.isDefault
                    ? Color.pickAlpha("surface.selected", "#2a3036")
                    : Color.pickAlpha("surface.hover", "#1f2327"))
                border.color: isCursorTarget
                  ? Color.accent
                  : (modelData.isDefault ? Color.accent : "transparent")
                border.width: isCursorTarget ? 2 : 1

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.focusedRow = 1
                    root.focusedSinkIndex = index
                    root.setDefaultSink(modelData.id, modelData.name)
                  }
                }

                RowLayout {
                  anchors.fill: parent
                  anchors.margins: 12
                  spacing: 10

                  Text {
                    text: modelData.name.indexOf("Charge") !== -1 ? "󰥰" : "󰕾"
                    font.family: Style.font.family
                    font.pixelSize: 18
                    color: modelData.isDefault ? Color.accent : Color.muted
                  }

                  Text {
                    Layout.fillWidth: true
                    text: modelData.name
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body || 13
                    font.bold: modelData.isDefault
                    color: Color.foreground
                    elide: Text.ElideRight
                  }

                  Rectangle {
                    visible: modelData.isDefault
                    width: 64
                    height: 22
                    radius: 4
                    color: Color.pickAlpha("accent.subtle", "#1f3b30")

                    Text {
                      anchors.centerIn: parent
                      text: "Active Output"
                      font.family: Style.font.family
                      font.pixelSize: 10
                      font.bold: true
                      color: Color.accent
                    }
                  }
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
