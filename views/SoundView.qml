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
  property int focusedRow: 0   // 0: Volume, 1: Mute, 2: Output Device

  function currentSinkIndex() {
    for (var i = 0; i < sinks.length; i++) {
      if (sinks[i].isDefault) return i
    }
    return 0
  }

  function cycleSink(delta) {
    if (sinks.length === 0) return
    var idx = currentSinkIndex()
    var next = (idx + delta + sinks.length) % sinks.length
    setDefaultSink(sinks[next].id, sinks[next].name)
  }

  function adjustVolume(delta) {
    var v = Math.max(0, Math.min(100, root.volume + delta))
    setVolume(v)
  }

  function handleMove(dx, dy) {
    if (dy !== 0) {
      focusedRow = Math.max(0, Math.min(2, focusedRow + dy))
      return true
    }
    if (dx !== 0) {
      if (focusedRow === 0) adjustVolume(dx * 5)
      else if (focusedRow === 1) toggleMute()
      else if (focusedRow === 2) cycleSink(dx)
      return true
    }
    return false
  }

  function handleActivate() {
    if (focusedRow === 0) toggleMute()
    else if (focusedRow === 1) toggleMute()
    else if (focusedRow === 2) cycleSink(1)
  }

  function handleTextKey(key) {
    if (key === "m" || key === "M") {
      toggleMute()
    } else if (key === "r" || key === "R") {
      refresh()
    } else if (key === "v" || key === "V") {
      focusedRow = 0
    } else if (key === "o" || key === "O") {
      focusedRow = 2
    } else if (key === "h" || key === "H") {
      adjustVolume(-5)
    } else if (key === "l" || key === "L") {
      adjustVolume(5)
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

      // Setting Row 0: Master Volume Stepper & Slider Card
      Rectangle {
        id: volumeCard
        Layout.fillWidth: true
        Layout.preferredHeight: 112
        radius: Style.cornerRadius || 8
        readonly property bool isFocused: root.activeFocusSection && root.focusedRow === 0
        color: volumeCard.isFocused ? Color.pickAlpha("surface.selected", "#22272e") : Color.pickAlpha("surface.subtle", "#181b1d")
        border.color: volumeCard.isFocused ? Color.accent : "transparent"
        border.width: volumeCard.isFocused ? 2 : 1

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
              text: root.muted ? "󰝟" : (root.volume > 50 ? "󰕾" : "󰖀")
              font.family: Style.font.family
              font.pixelSize: 18
              color: root.muted ? Color.urgent : (volumeCard.isFocused ? Color.accent : Color.foreground)
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 2

              RowLayout {
                spacing: 8
                Text {
                  text: "Master Volume"
                  font.family: Style.font.family
                  font.pixelSize: Style.font.subtitle || 14
                  font.bold: true
                  color: Color.foreground
                }
                Text {
                  visible: volumeCard.isFocused
                  text: "• Use [←/→ or h/l] to adjust ±5%"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  color: Color.accent
                }
              }

              Text {
                text: "System main sound output volume level."
                font.family: Style.font.family
                font.pixelSize: Style.font.subtext || 11
                color: Color.muted
              }
            }

            Text {
              text: root.muted ? "MUTED" : (root.volume + "%")
              font.family: Style.font.family
              font.pixelSize: Style.font.subtitle || 14
              font.bold: true
              color: root.muted ? Color.urgent : Color.accent
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
                  root.adjustVolume(-5)
                }
              }

              Button {
                text: "▶"
                implicitWidth: 32
                implicitHeight: 32
                bordered: true
                onClicked: {
                  root.focusedRow = 0
                  root.adjustVolume(5)
                }
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

      // Setting Row 1: Mute Audio Toggle Card
      Rectangle {
        id: muteCard
        Layout.fillWidth: true
        Layout.preferredHeight: 74
        radius: Style.cornerRadius || 8
        readonly property bool isFocused: root.activeFocusSection && root.focusedRow === 1
        color: muteCard.isFocused ? Color.pickAlpha("surface.selected", "#22272e") : Color.pickAlpha("surface.subtle", "#181b1d")
        border.color: muteCard.isFocused ? Color.accent : "transparent"
        border.width: muteCard.isFocused ? 2 : 1

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.focusedRow = 1
            root.toggleMute()
          }
        }

        RowLayout {
          anchors.fill: parent
          anchors.margins: 14
          spacing: 14

          Rectangle {
            width: 44
            height: 44
            radius: 8
            color: root.muted ? Color.pickAlpha("urgent.subtle", "#3a1f1f") : Color.pickAlpha("surface.hover", "#20252b")

            Text {
              anchors.centerIn: parent
              text: root.muted ? "󰝟" : "󰕾"
              font.family: Style.font.family
              font.pixelSize: 20
              color: root.muted ? Color.urgent : Color.foreground
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
              spacing: 8
              Text {
                text: "Mute All Audio"
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle || 14
                font.bold: true
                color: Color.foreground
              }
              Text {
                visible: muteCard.isFocused
                text: "• Press [Enter/Space or m] to toggle"
                font.family: Style.font.family
                font.pixelSize: 11
                color: Color.accent
              }
            }

            Text {
              text: root.muted ? "Audio is currently muted" : "Audio output is active and unmuted"
              font.family: Style.font.family
              font.pixelSize: Style.font.subtext || 11
              color: Color.muted
            }
          }

          Rectangle {
            width: 90
            height: 32
            radius: 16
            color: root.muted ? Color.urgent : Color.pickAlpha("surface.selected", "#2a3036")
            border.color: muteCard.isFocused ? Color.accent : "transparent"
            border.width: muteCard.isFocused ? 2 : 0

            Text {
              anchors.centerIn: parent
              text: root.muted ? "MUTED" : "UNMUTED"
              font.family: Style.font.family
              font.pixelSize: 11
              font.bold: true
              color: root.muted ? "#ffffff" : Color.muted
            }
          }
        }
      }

      // Setting Row 2: Audio Output Device Card
      Rectangle {
        id: sinkCard
        Layout.fillWidth: true
        Layout.preferredHeight: 120
        radius: Style.cornerRadius || 8
        readonly property bool isFocused: root.activeFocusSection && root.focusedRow === 2
        color: sinkCard.isFocused ? Color.pickAlpha("surface.selected", "#22272e") : Color.pickAlpha("surface.subtle", "#181b1d")
        border.color: sinkCard.isFocused ? Color.accent : "transparent"
        border.width: sinkCard.isFocused ? 2 : 1

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
              text: "󰓃"
              font.family: Style.font.family
              font.pixelSize: 18
              color: sinkCard.isFocused ? Color.accent : Color.foreground
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 2

              RowLayout {
                spacing: 8
                Text {
                  text: "Audio Output Device"
                  font.family: Style.font.family
                  font.pixelSize: Style.font.subtitle || 14
                  font.bold: true
                  color: Color.foreground
                }
                Text {
                  visible: sinkCard.isFocused
                  text: "• Use [←/→ or h/l] to cycle"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  color: Color.accent
                }
              }

              Text {
                text: "Select default speaker or headphone sink."
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
                  root.cycleSink(-1)
                }
              }

              Button {
                text: "▶"
                implicitWidth: 32
                implicitHeight: 32
                bordered: true
                onClicked: {
                  root.focusedRow = 2
                  root.cycleSink(1)
                }
              }
            }
          }

          // Devices list pills
          RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
              model: root.sinks

              delegate: Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: 6
                color: modelData.isDefault ? Color.pickAlpha("accent.subtle", "#1f3b30") : Color.pickAlpha("surface.hover", "#1b1f23")
                border.color: modelData.isDefault ? Color.accent : "transparent"
                border.width: modelData.isDefault ? 1 : 0

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.focusedRow = 2
                    root.setDefaultSink(modelData.id, modelData.name)
                  }
                }

                RowLayout {
                  anchors.fill: parent
                  anchors.margins: 8
                  spacing: 6

                  Text {
                    text: modelData.name.indexOf("Charge") !== -1 ? "󰥰" : "󰕾"
                    font.family: Style.font.family
                    font.pixelSize: 14
                    color: modelData.isDefault ? Color.accent : Color.muted
                  }

                  Text {
                    Layout.fillWidth: true
                    text: modelData.name
                    font.family: Style.font.family
                    font.pixelSize: 11
                    font.bold: modelData.isDefault
                    color: modelData.isDefault ? Color.accent : Color.foreground
                    elide: Text.ElideRight
                  }

                  Text {
                    visible: modelData.isDefault
                    text: "✓"
                    font.family: Style.font.family
                    font.pixelSize: 11
                    color: Color.accent
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
