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
  property int volume: 50
  property bool muted: false
  property var sinks: []
  property int inputVolume: 100
  property bool inputMuted: false
  property var sources: []
  property string statusMessage: ""

  property bool activeFocusSection: false
  property int focusedRow: 0   // 0: Vol, 1: Mute, 2: Sink, 3: Mic Vol, 4: Mic Mute, 5: Mic Source

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

  function currentSourceIndex() {
    for (var i = 0; i < sources.length; i++) {
      if (sources[i].isDefault) return i
    }
    return 0
  }

  function cycleSource(delta) {
    if (sources.length === 0) return
    var idx = currentSourceIndex()
    var next = (idx + delta + sources.length) % sources.length
    setDefaultSource(sources[next].id, sources[next].name)
  }

  function adjustInputVolume(delta) {
    var v = Math.max(0, Math.min(100, root.inputVolume + delta))
    setInputVolume(v)
  }

  function handleMove(dx, dy) {
    if (dy !== 0) {
      focusedRow = Math.max(0, Math.min(5, focusedRow + dy))
      return true
    }
    if (dx !== 0) {
      if (focusedRow === 0) adjustVolume(dx * 5)
      else if (focusedRow === 1) toggleMute()
      else if (focusedRow === 2) cycleSink(dx)
      else if (focusedRow === 3) adjustInputVolume(dx * 5)
      else if (focusedRow === 4) toggleInputMute()
      else if (focusedRow === 5) cycleSource(dx)
      return true
    }
    return false
  }

  function handleActivate() {
    if (focusedRow === 0) toggleMute()
    else if (focusedRow === 1) toggleMute()
    else if (focusedRow === 2) cycleSink(1)
    else if (focusedRow === 3) toggleInputMute()
    else if (focusedRow === 4) toggleInputMute()
    else if (focusedRow === 5) cycleSource(1)
  }

  function handleTextKey(key) {
    if (key === "m" || key === "M") {
      if (focusedRow >= 3) {
        toggleInputMute()
      } else {
        toggleMute()
      }
    } else if (key === "r" || key === "R") {
      refresh()
    } else if (key === "v" || key === "V") {
      focusedRow = 0
    } else if (key === "o" || key === "O") {
      focusedRow = 2
    } else if (key === "i" || key === "I") {
      focusedRow = 3
    } else if (key === "s" || key === "S") {
      focusedRow = 5
    } else if (key === "h" || key === "H") {
      if (focusedRow === 0) adjustVolume(-5)
      else if (focusedRow === 1) toggleMute()
      else if (focusedRow === 2) cycleSink(-1)
      else if (focusedRow === 3) adjustInputVolume(-5)
      else if (focusedRow === 4) toggleInputMute()
      else if (focusedRow === 5) cycleSource(-1)
    } else if (key === "l" || key === "L") {
      if (focusedRow === 0) adjustVolume(5)
      else if (focusedRow === 1) toggleMute()
      else if (focusedRow === 2) cycleSink(1)
      else if (focusedRow === 3) adjustInputVolume(5)
      else if (focusedRow === 4) toggleInputMute()
      else if (focusedRow === 5) cycleSource(1)
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
    notifyStatus("Output Volume: " + v + "%")
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

  function setInputVolume(val) {
    var v = Math.round(val)
    root.inputVolume = v
    setInputVolProcess.command = [pluginPath + "/scripts/system-control.sh", "audio-set-input-volume", String(v)]
    setInputVolProcess.running = true
    notifyStatus("Mic Volume: " + v + "%")
  }

  function toggleInputMute() {
    root.inputMuted = !root.inputMuted
    setInputMuteProcess.command = [pluginPath + "/scripts/system-control.sh", "audio-set-input-mute", "toggle"]
    setInputMuteProcess.running = true
    notifyStatus(root.inputMuted ? "Microphone Muted" : "Microphone Active")
  }

  function setDefaultSource(id, name) {
    setSourceProcess.command = [pluginPath + "/scripts/system-control.sh", "audio-set-source", String(id)]
    setSourceProcess.running = true
    notifyStatus("Mic Source: " + name)
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
          if (data.inputVolume !== undefined) root.inputVolume = data.inputVolume
          if (data.inputMuted !== undefined) root.inputMuted = data.inputMuted
          if (Array.isArray(data.sources)) root.sources = data.sources
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

  // Set Input Volume Process
  Process {
    id: setInputVolProcess
  }

  // Set Input Mute Process
  Process {
    id: setInputMuteProcess
    onRunningChanged: if (!running) root.refresh()
  }

  // Set Source Process
  Process {
    id: setSourceProcess
    onRunningChanged: if (!running) root.refresh()
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

      // Section Header: Output
      Text {
        text: "OUTPUT (SPEAKERS / HEADPHONES)"
        font.family: Style.font.family
        font.pixelSize: 11
        font.bold: true
        color: Color.muted
        Layout.topMargin: 4
      }

      // Setting Row 0: Master Volume Stepper & Slider Card
      Rectangle {
        id: volumeCard
        Layout.fillWidth: true
        implicitHeight: Math.max(116, volumeColLayout.implicitHeight + 28)
        Layout.preferredHeight: implicitHeight
        radius: Style.cornerRadius || 8
        readonly property bool isFocused: root.activeFocusSection && root.focusedRow === 0
        color: volumeCard.isFocused ? Color.pickAlpha("surface.selected", "#22272e") : Color.pickAlpha("surface.subtle", "#181b1d")
        border.color: volumeCard.isFocused ? Color.accent : "transparent"
        border.width: volumeCard.isFocused ? 2 : 1

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.focusedRow = 0
        }

        ColumnLayout {
          id: volumeColLayout
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
              Layout.minimumWidth: 0
              spacing: 2

              RowLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 8
                Text {
                  text: "Master Output Volume"
                  font.family: Style.font.family
                  font.pixelSize: Style.font.subtitle || 14
                  font.bold: true
                  color: Color.foreground
                }
                Text {
                  visible: volumeCard.isFocused
                  Layout.fillWidth: true
                  Layout.minimumWidth: 0
                  text: "• Use [←/→ or h/l] to adjust ±5%"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  color: Color.accent
                  elide: Text.ElideRight
                }
              }

              Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: "System main sound output volume level."
                font.family: Style.font.family
                font.pixelSize: Style.font.subtext || 11
                color: Color.muted
                elide: Text.ElideRight
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
        implicitHeight: Math.max(74, muteRowLayout.implicitHeight + 28)
        Layout.preferredHeight: implicitHeight
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
          id: muteRowLayout
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
            Layout.minimumWidth: 0
            spacing: 2

            RowLayout {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              spacing: 8
              Text {
                text: "Mute All Audio Output"
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle || 14
                font.bold: true
                color: Color.foreground
              }
              Text {
                visible: muteCard.isFocused
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: "• Press [Enter/Space or m] to toggle"
                font.family: Style.font.family
                font.pixelSize: 11
                color: Color.accent
                elide: Text.ElideRight
              }
            }

            Text {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              text: root.muted ? "Audio output is currently muted" : "Audio output is active and unmuted"
              font.family: Style.font.family
              font.pixelSize: Style.font.subtext || 11
              color: Color.muted
              elide: Text.ElideRight
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
        implicitHeight: Math.max(124, sinkColLayout.implicitHeight + 28)
        Layout.preferredHeight: implicitHeight
        radius: Style.cornerRadius || 8
        readonly property bool isFocused: root.activeFocusSection && root.focusedRow === 2
        color: sinkCard.isFocused ? Color.pickAlpha("surface.selected", "#22272e") : Color.pickAlpha("surface.subtle", "#181b1d")
        border.color: sinkCard.isFocused ? Color.accent : "transparent"
        border.width: sinkCard.isFocused ? 2 : 1

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.focusedRow = 2
        }

        ColumnLayout {
          id: sinkColLayout
          anchors.fill: parent
          anchors.margins: 14
          spacing: 12

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
              Layout.minimumWidth: 0
              spacing: 2

              RowLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
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
                  Layout.fillWidth: true
                  Layout.minimumWidth: 0
                  text: "• Use [←/→ or h/l] to cycle"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  color: Color.accent
                  elide: Text.ElideRight
                }
              }

              Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: "Select default speaker or headphone sink."
                font.family: Style.font.family
                font.pixelSize: Style.font.subtext || 11
                color: Color.muted
                elide: Text.ElideRight
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
          GridLayout {
            Layout.fillWidth: true
            columns: (root.sinks.length > 1 && sinkCard.width >= 460) ? 2 : 1
            rowSpacing: 6
            columnSpacing: 8

            Repeater {
              model: root.sinks

              delegate: Rectangle {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
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
                    Layout.minimumWidth: 0
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

      // Section Header: Input
      Text {
        text: "INPUT (MICROPHONE)"
        font.family: Style.font.family
        font.pixelSize: 11
        font.bold: true
        color: Color.muted
        Layout.topMargin: 8
      }

      // Setting Row 3: Microphone Volume Stepper & Slider Card
      Rectangle {
        id: inputVolCard
        Layout.fillWidth: true
        implicitHeight: Math.max(116, inputVolColLayout.implicitHeight + 28)
        Layout.preferredHeight: implicitHeight
        radius: Style.cornerRadius || 8
        readonly property bool isFocused: root.activeFocusSection && root.focusedRow === 3
        color: inputVolCard.isFocused ? Color.pickAlpha("surface.selected", "#22272e") : Color.pickAlpha("surface.subtle", "#181b1d")
        border.color: inputVolCard.isFocused ? Color.accent : "transparent"
        border.width: inputVolCard.isFocused ? 2 : 1

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.focusedRow = 3
        }

        ColumnLayout {
          id: inputVolColLayout
          anchors.fill: parent
          anchors.margins: 14
          spacing: 10

          RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
              text: root.inputMuted ? "󰍭" : (root.inputVolume > 50 ? "󰍬" : "󰍮")
              font.family: Style.font.family
              font.pixelSize: 18
              color: root.inputMuted ? Color.urgent : (inputVolCard.isFocused ? Color.accent : Color.foreground)
            }

            ColumnLayout {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              spacing: 2

              RowLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 8
                Text {
                  text: "Microphone Input Volume"
                  font.family: Style.font.family
                  font.pixelSize: Style.font.subtitle || 14
                  font.bold: true
                  color: Color.foreground
                }
                Text {
                  visible: inputVolCard.isFocused
                  Layout.fillWidth: true
                  Layout.minimumWidth: 0
                  text: "• Use [←/→ or h/l] to adjust ±5%"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  color: Color.accent
                  elide: Text.ElideRight
                }
              }

              Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: "Microphone input gain and recording volume level."
                font.family: Style.font.family
                font.pixelSize: Style.font.subtext || 11
                color: Color.muted
                elide: Text.ElideRight
              }
            }

            Text {
              text: root.inputMuted ? "MUTED" : (root.inputVolume + "%")
              font.family: Style.font.family
              font.pixelSize: Style.font.subtitle || 14
              font.bold: true
              color: root.inputMuted ? Color.urgent : Color.accent
            }

            RowLayout {
              spacing: 6

              Button {
                text: "◀"
                implicitWidth: 32
                implicitHeight: 32
                bordered: true
                onClicked: {
                  root.focusedRow = 3
                  root.adjustInputVolume(-5)
                }
              }

              Button {
                text: "▶"
                implicitWidth: 32
                implicitHeight: 32
                bordered: true
                onClicked: {
                  root.focusedRow = 3
                  root.adjustInputVolume(5)
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
            value: root.inputVolume
            onMoved: function(v) { root.inputVolume = Math.round(v) }
            onReleased: function(v) { root.setInputVolume(v) }
          }
        }
      }

      // Setting Row 4: Mute Microphone Toggle Card
      Rectangle {
        id: inputMuteCard
        Layout.fillWidth: true
        implicitHeight: Math.max(74, inputMuteRowLayout.implicitHeight + 28)
        Layout.preferredHeight: implicitHeight
        radius: Style.cornerRadius || 8
        readonly property bool isFocused: root.activeFocusSection && root.focusedRow === 4
        color: inputMuteCard.isFocused ? Color.pickAlpha("surface.selected", "#22272e") : Color.pickAlpha("surface.subtle", "#181b1d")
        border.color: inputMuteCard.isFocused ? Color.accent : "transparent"
        border.width: inputMuteCard.isFocused ? 2 : 1

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.focusedRow = 4
            root.toggleInputMute()
          }
        }

        RowLayout {
          id: inputMuteRowLayout
          anchors.fill: parent
          anchors.margins: 14
          spacing: 14

          Rectangle {
            width: 44
            height: 44
            radius: 8
            color: root.inputMuted ? Color.pickAlpha("urgent.subtle", "#3a1f1f") : Color.pickAlpha("surface.hover", "#20252b")

            Text {
              anchors.centerIn: parent
              text: root.inputMuted ? "󰍭" : "󰍬"
              font.family: Style.font.family
              font.pixelSize: 20
              color: root.inputMuted ? Color.urgent : Color.foreground
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: 2

            RowLayout {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              spacing: 8
              Text {
                text: "Mute Microphone"
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle || 14
                font.bold: true
                color: Color.foreground
              }
              Text {
                visible: inputMuteCard.isFocused
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: "• Press [Enter/Space or m] to toggle"
                font.family: Style.font.family
                font.pixelSize: 11
                color: Color.accent
                elide: Text.ElideRight
              }
            }

            Text {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              text: root.inputMuted ? "Microphone is muted (no audio input)" : "Microphone is active and unmuted"
              font.family: Style.font.family
              font.pixelSize: Style.font.subtext || 11
              color: Color.muted
              elide: Text.ElideRight
            }
          }

          Rectangle {
            width: 90
            height: 32
            radius: 16
            color: root.inputMuted ? Color.urgent : Color.pickAlpha("surface.selected", "#2a3036")
            border.color: inputMuteCard.isFocused ? Color.accent : "transparent"
            border.width: inputMuteCard.isFocused ? 2 : 0

            Text {
              anchors.centerIn: parent
              text: root.inputMuted ? "MUTED" : "UNMUTED"
              font.family: Style.font.family
              font.pixelSize: 11
              font.bold: true
              color: root.inputMuted ? "#ffffff" : Color.muted
            }
          }
        }
      }

      // Setting Row 5: Audio Input Device Card
      Rectangle {
        id: sourceCard
        Layout.fillWidth: true
        implicitHeight: Math.max(124, sourceColLayout.implicitHeight + 28)
        Layout.preferredHeight: implicitHeight
        radius: Style.cornerRadius || 8
        readonly property bool isFocused: root.activeFocusSection && root.focusedRow === 5
        color: sourceCard.isFocused ? Color.pickAlpha("surface.selected", "#22272e") : Color.pickAlpha("surface.subtle", "#181b1d")
        border.color: sourceCard.isFocused ? Color.accent : "transparent"
        border.width: sourceCard.isFocused ? 2 : 1

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.focusedRow = 5
        }

        ColumnLayout {
          id: sourceColLayout
          anchors.fill: parent
          anchors.margins: 14
          spacing: 12

          RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
              text: "󰍬"
              font.family: Style.font.family
              font.pixelSize: 18
              color: sourceCard.isFocused ? Color.accent : Color.foreground
            }

            ColumnLayout {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              spacing: 2

              RowLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 8
                Text {
                  text: "Microphone Input Device"
                  font.family: Style.font.family
                  font.pixelSize: Style.font.subtitle || 14
                  font.bold: true
                  color: Color.foreground
                }
                Text {
                  visible: sourceCard.isFocused
                  Layout.fillWidth: true
                  Layout.minimumWidth: 0
                  text: "• Use [←/→ or h/l] to cycle"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  color: Color.accent
                  elide: Text.ElideRight
                }
              }

              Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: "Select default audio input device and recording source."
                font.family: Style.font.family
                font.pixelSize: Style.font.subtext || 11
                color: Color.muted
                elide: Text.ElideRight
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
                  root.focusedRow = 5
                  root.cycleSource(-1)
                }
              }

              Button {
                text: "▶"
                implicitWidth: 32
                implicitHeight: 32
                bordered: true
                onClicked: {
                  root.focusedRow = 5
                  root.cycleSource(1)
                }
              }
            }
          }

          // Sources list pills
          GridLayout {
            Layout.fillWidth: true
            columns: (root.sources.length > 1 && sourceCard.width >= 460) ? 2 : 1
            rowSpacing: 6
            columnSpacing: 8

            Repeater {
              model: root.sources

              delegate: Rectangle {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredHeight: 36
                radius: 6
                color: modelData.isDefault ? Color.pickAlpha("accent.subtle", "#1f3b30") : Color.pickAlpha("surface.hover", "#1b1f23")
                border.color: modelData.isDefault ? Color.accent : "transparent"
                border.width: modelData.isDefault ? 1 : 0

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.focusedRow = 5
                    root.setDefaultSource(modelData.id, modelData.name)
                  }
                }

                RowLayout {
                  anchors.fill: parent
                  anchors.margins: 8
                  spacing: 6

                  Text {
                    text: "󰍬"
                    font.family: Style.font.family
                    font.pixelSize: 14
                    color: modelData.isDefault ? Color.accent : Color.muted
                  }

                  Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
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
