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
  property int volume: 50
  property bool muted: false
  property var sinks: []

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
  }

  function toggleMute() {
    root.muted = !root.muted
    setMuteProcess.command = [pluginPath + "/scripts/system-control.sh", "audio-set-mute", "toggle"]
    setMuteProcess.running = true
  }

  function setDefaultSink(id) {
    setSinkProcess.command = [pluginPath + "/scripts/system-control.sh", "audio-set-sink", String(id)]
    setSinkProcess.running = true
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

      // Section: Master Volume
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 110
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

            Item { Layout.fillWidth: true }

            Text {
              text: root.muted ? "MUTED" : (root.volume + "%")
              font.family: Style.font.family
              font.pixelSize: Style.font.subtitle || 14
              font.bold: true
              color: root.muted ? Color.urgent : Color.accent
            }

            Button {
              text: root.muted ? "Unmute" : "Mute"
              iconText: root.muted ? "󰕾" : "󰝟"
              selected: root.muted
              onClicked: root.toggleMute()
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
        Layout.preferredHeight: 180
        color: Color.pickAlpha("surface.subtle", "#181b1d")
        radius: Style.cornerRadius || 8

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 14
          spacing: 10

          RowLayout {
            Layout.fillWidth: true
            Text {
              text: "󰓃  Output Devices"
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
            text: "Select primary audio output sink."
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
                Layout.preferredHeight: 46
                radius: 6
                color: modelData.isDefault
                  ? Color.pickAlpha("surface.selected", "#2a3036")
                  : Color.pickAlpha("surface.hover", "#1f2327")
                border.color: modelData.isDefault ? Color.accent : "transparent"
                border.width: 1

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.setDefaultSink(modelData.id)
                }

                RowLayout {
                  anchors.fill: parent
                  anchors.margins: 12
                  spacing: 10

                  Text {
                    text: modelData.name.indexOf("Charge") !== -1 ? "󰥰" : "󰕾"
                    font.family: Style.font.family
                    font.pixelSize: 16
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
                    width: 58
                    height: 20
                    radius: 4
                    color: Color.pickAlpha("accent.subtle", "#1f3b30")

                    Text {
                      anchors.centerIn: parent
                      text: "Default"
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
