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
  property var panelRoot: null
  property int volume: 50
  property bool muted: false
  property var sinks: []
  property int inputVolume: 100
  property bool inputMuted: false
  property var sources: []
  property var apps: []
  property string statusMessage: ""

  property bool activeFocusSection: false
  readonly property bool isContentFocused: {
    if (root.panelRoot && root.panelRoot.focusSection !== undefined) {
      return root.panelRoot.focusSection === "content"
    }
    return activeFocusSection
  }
  property int sinkFocusIndex: -1
  property int sourceFocusIndex: -1

  onSinksChanged: sinkFocusIndex = currentSinkIndex()
  onSourcesChanged: sourceFocusIndex = currentSourceIndex()

  property int focusedRow: 0   // 0: Vol, 1: Mute, 2: Sink, 3: Mic Vol, 4: Mic Mute, 5: Mic Source, 6+: Apps
  onFocusedRowChanged: {
    ensureRowVisible(focusedRow)
    if (focusedRow !== 2) sinkFocusIndex = currentSinkIndex()
    if (focusedRow !== 5) sourceFocusIndex = currentSourceIndex()
  }

  function ensureRowVisible(index) {
    if (!scrollArea || !scrollArea.contentItem) return
    var targets = [volumeCard, muteCard, sinkCard, inputVolCard, inputMuteCard, sourceCard]
    var item = null
    if (index >= 0 && index < targets.length) {
      item = targets[index]
    } else if (index >= 6 && appRepeater && index - 6 < appRepeater.count) {
      item = appRepeater.itemAt(index - 6)
    }
    if (item && item.visible) {
      var flick = scrollArea.contentItem
      var pos = item.mapToItem(scrollArea, 0, 0)
      var maxScroll = Math.max(0, flick.contentHeight - flick.height)
      if (pos.y < 12) {
        flick.contentY = Math.max(0, Math.min(maxScroll, flick.contentY + pos.y - 12))
      } else if (pos.y + item.height > scrollArea.height - 12) {
        if (item.height >= scrollArea.height) {
          flick.contentY = Math.max(0, Math.min(maxScroll, flick.contentY + pos.y - 12))
        } else {
          flick.contentY = Math.max(0, Math.min(maxScroll, flick.contentY + (pos.y + item.height - scrollArea.height + 12)))
        }
      }
    }
  }

  function currentSinkIndex() {
    for (var i = 0; i < sinks.length; i++) {
      if (sinks[i].isDefault) return i
    }
    return 0
  }

  function cycleSink(delta) {
    if (sinks.length === 0) return false
    var cur = (sinkFocusIndex >= 0) ? sinkFocusIndex : currentSinkIndex()
    if (delta < 0 && cur === 0) return false
    var next = Math.max(0, Math.min(sinks.length - 1, cur + delta))
    if (next === cur) return false
    sinkFocusIndex = next
    return true
  }

  function adjustVolume(delta) {
    if (delta < 0 && root.volume <= 0) return false
    var v = Math.max(0, Math.min(100, root.volume + delta))
    if (v === root.volume) return false
    setVolume(v)
    return true
  }

  function currentSourceIndex() {
    for (var i = 0; i < sources.length; i++) {
      if (sources[i].isDefault) return i
    }
    return 0
  }

  function cycleSource(delta) {
    if (sources.length === 0) return false
    var idx = (sourceFocusIndex >= 0) ? sourceFocusIndex : currentSourceIndex()
    if (delta < 0 && idx === 0) return false
    var next = Math.max(0, Math.min(sources.length - 1, idx + delta))
    if (next === idx) return false
    sourceFocusIndex = next
    return true
  }

  function adjustInputVolume(delta) {
    if (delta < 0 && root.inputVolume <= 0) return false
    var v = Math.max(0, Math.min(100, root.inputVolume + delta))
    if (v === root.inputVolume) return false
    setInputVolume(v)
    return true
  }

  function adjustAppVolume(id, delta, name) {
    for (var i = 0; i < root.apps.length; i++) {
      if (root.apps[i].id === id) {
        var curV = root.apps[i].volume || 100
        if (delta < 0 && curV <= 0) return false
        var newV = Math.max(0, Math.min(100, curV + delta))
        if (newV === curV) return false
        setAppVolume(id, newV, name)
        return true
      }
    }
    return false
  }

  function handleMove(dx, dy) {
    var maxRow = 5 + (root.apps.length > 0 ? root.apps.length : 0)
    if (dy !== 0) {
      focusedRow = Math.max(0, Math.min(maxRow, focusedRow + dy))
      ensureRowVisible(focusedRow)
      return true
    }
    if (dx !== 0) {
      if (focusedRow === 0) return adjustVolume(dx * 5)
      else if (focusedRow === 1) {
        if (dx < 0) return false
        toggleMute()
        return true
      }
      else if (focusedRow === 2) return cycleSink(dx)
      else if (focusedRow === 3) return adjustInputVolume(dx * 5)
      else if (focusedRow === 4) {
        if (dx < 0) return false
        toggleInputMute()
        return true
      }
      else if (focusedRow === 5) return cycleSource(dx)
      else if (focusedRow >= 6) {
        var appIdx = focusedRow - 6
        if (appIdx >= 0 && appIdx < root.apps.length) {
          return adjustAppVolume(root.apps[appIdx].id, dx * 5, root.apps[appIdx].name)
        }
      }
    }
    return false
  }

  function handleActivate() {
    if (focusedRow === 0) toggleMute()
    else if (focusedRow === 1) toggleMute()
    else if (focusedRow === 2) {
      var curSink = (sinkFocusIndex >= 0) ? sinkFocusIndex : currentSinkIndex()
      if (curSink >= 0 && curSink < sinks.length) {
        setDefaultSink(sinks[curSink].id, sinks[curSink].name)
      }
    }
    else if (focusedRow === 3) toggleInputMute()
    else if (focusedRow === 4) toggleInputMute()
    else if (focusedRow === 5) {
      var curSource = (sourceFocusIndex >= 0) ? sourceFocusIndex : currentSourceIndex()
      if (curSource >= 0 && curSource < sources.length) {
        setDefaultSource(sources[curSource].id, sources[curSource].name)
      }
    }
    else if (focusedRow >= 6) {
      var appIdx = focusedRow - 6
      if (appIdx >= 0 && appIdx < root.apps.length) {
        toggleAppMute(root.apps[appIdx].id, root.apps[appIdx].name)
      }
    }
  }

  function handleTextKey(key) {
    if (key === "m" || key === "M") {
      if (focusedRow >= 6) {
        var appIdx = focusedRow - 6
        if (appIdx >= 0 && appIdx < root.apps.length) {
          toggleAppMute(root.apps[appIdx].id, root.apps[appIdx].name)
        }
      } else if (focusedRow >= 3) {
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
    } else if (key === "a" || key === "A") {
      if (root.apps.length > 0) focusedRow = 6
    } else if (key === "h" || key === "H") {
      return handleMove(-1, 0)
    } else if (key === "l" || key === "L") {
      return handleMove(1, 0)
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

  function setAppVolume(id, val, name) {
    var v = Math.round(val)
    setAppVolProcess.command = [pluginPath + "/scripts/system-control.sh", "audio-set-app-volume", String(id), String(v)]
    setAppVolProcess.running = true
    notifyStatus((name || "App") + " Volume: " + v + "%")
  }

  function toggleAppMute(id, name) {
    setAppMuteProcess.command = [pluginPath + "/scripts/system-control.sh", "audio-set-app-mute", String(id), "toggle"]
    setAppMuteProcess.running = true
    notifyStatus("Toggled mute for " + (name || "App"))
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
          if (Array.isArray(data.apps)) root.apps = data.apps
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
    onRunningChanged: {
      if (!running) {
        root.refresh()
        if (panelRoot && typeof panelRoot.notifySettingChanged === "function") {
          panelRoot.notifySettingChanged()
        }
      }
    }
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
    onRunningChanged: {
      if (!running) {
        root.refresh()
        if (panelRoot && typeof panelRoot.notifySettingChanged === "function") {
          panelRoot.notifySettingChanged()
        }
      }
    }
  }

  // Set App Volume Process
  Process {
    id: setAppVolProcess
  }

  // Set App Mute Process
  Process {
    id: setAppMuteProcess
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
        color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
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
        readonly property bool isFocused: root.isContentFocused && root.focusedRow === 0
        readonly property bool isHovered: volumeCardMouseArea.containsMouse
        color: volumeCard.isFocused ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.07) : (volumeCard.isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.05) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02))
        border.color: volumeCard.isFocused ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35) : (volumeCard.isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.20) : "transparent")
        border.width: 1

        MouseArea {
          id: volumeCardMouseArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.focusedRow = 0
            if (root.panelRoot) root.panelRoot.focusSection = "content"
          }
        }

        ColumnLayout {
          id: volumeColLayout
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
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

              Flow {
                Layout.fillWidth: true
                width: parent.width
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
                  text: "• Use [←/→ or h/l] to adjust ±5%"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  color: Color.accent
                }
              }

              Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: "System main sound output volume level."
                font.family: Style.font.family
                font.pixelSize: Style.font.subtext || 11
                color: Color.muted
                wrapMode: Text.WordWrap
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
                  if (root.panelRoot) root.panelRoot.focusSection = "content"
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
                  if (root.panelRoot) root.panelRoot.focusSection = "content"
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
        readonly property bool isFocused: root.isContentFocused && root.focusedRow === 1
        readonly property bool isHovered: muteCardMouseArea.containsMouse
        color: muteCard.isFocused ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.07) : (muteCard.isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.05) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02))
        border.color: muteCard.isFocused ? Color.accent : (muteCard.isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.20) : "transparent")
        border.width: muteCard.isFocused ? 2 : 1

        MouseArea {
          id: muteCardMouseArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.focusedRow = 1
            if (root.panelRoot) root.panelRoot.focusSection = "content"
            root.toggleMute()
          }
        }

        RowLayout {
          id: muteRowLayout
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 14
          spacing: 14

          Rectangle {
            width: 44
            height: 44
            radius: 8
            color: root.muted ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.25) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)

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

            Flow {
              Layout.fillWidth: true
              width: parent.width
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
                text: "• Press [Enter/Space or m] to toggle"
                font.family: Style.font.family
                font.pixelSize: 11
                color: Color.accent
              }
            }

            Text {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              text: root.muted ? "Audio output is currently muted" : "Audio output is active and unmuted"
              font.family: Style.font.family
              font.pixelSize: Style.font.subtext || 11
              color: Color.muted
              wrapMode: Text.WordWrap
            }
          }

          Rectangle {
            width: 90
            height: 32
            radius: 16
            color: root.muted ? Color.urgent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.10)
            border.color: (muteCard.isFocused || muteCard.isHovered) ? (root.muted ? Color.urgent : Color.accent) : "transparent"
            border.width: muteCard.isFocused ? 2 : (muteCard.isHovered ? 1 : 0)

            Text {
              anchors.centerIn: parent
              text: root.muted ? "MUTED" : "UNMUTED"
              font.family: Style.font.family
              font.pixelSize: 11
              font.bold: true
              color: root.muted ? "#ffffff" : (muteCard.isFocused || muteCard.isHovered ? Color.foreground : Color.muted)
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
        readonly property bool isFocused: root.isContentFocused && root.focusedRow === 2
        readonly property bool isHovered: sinkCardMouseArea.containsMouse
        color: sinkCard.isFocused ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.07) : (sinkCard.isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.05) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02))
        border.color: sinkCard.isFocused ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35) : (sinkCard.isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.20) : "transparent")
        border.width: 1

        MouseArea {
          id: sinkCardMouseArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.focusedRow = 2
            if (root.panelRoot) root.panelRoot.focusSection = "content"
          }
        }

        ColumnLayout {
          id: sinkColLayout
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
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

              Flow {
                Layout.fillWidth: true
                width: parent.width
                spacing: 8

                Text {
                  text: "Audio Output Device"
                  font.family: Style.font.family
                  font.pixelSize: Style.font.subtitle || 14
                  font.bold: true
                  color: Color.foreground
                }

                Rectangle {
                  height: 20
                  width: activeSinkLabel.implicitWidth + 12
                  radius: 4
                  color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
                  border.color: Color.accent
                  border.width: 1

                  Text {
                    id: activeSinkLabel
                    anchors.centerIn: parent
                    text: {
                      var idx = root.currentSinkIndex()
                      return (root.sinks.length > idx && root.sinks[idx]) ? root.sinks[idx].name : "Default"
                    }
                    font.family: Style.font.family
                    font.pixelSize: 10
                    font.bold: true
                    color: Color.accent
                    elide: Text.ElideRight
                  }
                }

                Text {
                  visible: sinkCard.isFocused
                  text: "• Use [←/→ or h/l] to navigate • [Enter/Space] to set"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  color: Color.accent
                }
              }

              Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: "Select default speaker or headphone sink."
                font.family: Style.font.family
                font.pixelSize: Style.font.subtext || 11
                color: Color.muted
                wrapMode: Text.WordWrap
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
                  if (root.panelRoot) root.panelRoot.focusSection = "content"
                  var cur = (root.sinkFocusIndex >= 0) ? root.sinkFocusIndex : root.currentSinkIndex()
                  var next = Math.max(0, cur - 1)
                  root.sinkFocusIndex = next
                  if (next < root.sinks.length) {
                    root.setDefaultSink(root.sinks[next].id, root.sinks[next].name)
                  }
                }
              }

              Button {
                text: "▶"
                implicitWidth: 32
                implicitHeight: 32
                bordered: true
                onClicked: {
                  root.focusedRow = 2
                  if (root.panelRoot) root.panelRoot.focusSection = "content"
                  var cur = (root.sinkFocusIndex >= 0) ? root.sinkFocusIndex : root.currentSinkIndex()
                  var next = Math.min(root.sinks.length - 1, cur + 1)
                  root.sinkFocusIndex = next
                  if (next < root.sinks.length) {
                    root.setDefaultSink(root.sinks[next].id, root.sinks[next].name)
                  }
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
                id: sinkPillRect
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                implicitHeight: Math.max(36, sinkPillRow.implicitHeight + 12)
                Layout.preferredHeight: implicitHeight
                radius: 6

                readonly property bool isActive: modelData.isDefault
                readonly property bool isFocused: root.isContentFocused && (root.focusedRow === 2) && ((root.sinkFocusIndex >= 0 ? root.sinkFocusIndex : root.currentSinkIndex()) === index)
                readonly property bool isHovered: sinkPillMouse.containsMouse

                color: {
                  if (isActive) {
                    return isHovered ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.28)
                                     : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
                  }
                  if (isFocused) {
                    return isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.18)
                                     : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.14)
                  }
                  if (isHovered) {
                    return Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
                  }
                  return Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.03)
                }

                border.color: {
                  if (isFocused) {
                    return Color.accent
                  }
                  if (isActive) {
                    return Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.6)
                  }
                  if (isHovered) {
                    return Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28)
                  }
                  return Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
                }
                border.width: isFocused ? 2 : 1

                MouseArea {
                  id: sinkPillMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.focusedRow = 2
                    root.sinkFocusIndex = index
                    if (root.panelRoot) root.panelRoot.focusSection = "content"
                    root.setDefaultSink(modelData.id, modelData.name)
                  }
                }

                RowLayout {
                  id: sinkPillRow
                  anchors.top: parent.top
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.margins: 8
                  spacing: 6

                  Rectangle {
                    visible: sinkPillRect.isActive
                    width: 5
                    height: 5
                    radius: 2.5
                    color: Color.accent
                  }

                  Text {
                    text: modelData.name.indexOf("Charge") !== -1 ? "󰥰" : "󰕾"
                    font.family: Style.font.family
                    font.pixelSize: 14
                    color: sinkPillRect.isActive ? Color.accent : (sinkPillRect.isFocused || sinkPillRect.isHovered ? Color.foreground : Color.muted)
                  }

                  Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: modelData.name
                    font.family: Style.font.family
                    font.pixelSize: 11
                    font.bold: sinkPillRect.isActive || sinkPillRect.isFocused
                    color: sinkPillRect.isActive ? Color.accent : (sinkPillRect.isFocused || sinkPillRect.isHovered ? Color.foreground : Color.muted)
                    elide: Text.ElideRight
                  }

                  Text {
                    visible: sinkPillRect.isActive
                    text: "✓"
                    font.family: Style.font.family
                    font.pixelSize: 11
                    font.bold: true
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
        readonly property bool isFocused: root.isContentFocused && root.focusedRow === 3
        readonly property bool isHovered: inputVolMouseArea.containsMouse
        color: inputVolCard.isFocused ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.07) : (inputVolCard.isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.05) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02))
        border.color: inputVolCard.isFocused ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35) : (inputVolCard.isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.20) : "transparent")
        border.width: 1

        MouseArea {
          id: inputVolMouseArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.focusedRow = 3
            if (root.panelRoot) root.panelRoot.focusSection = "content"
          }
        }

        ColumnLayout {
          id: inputVolColLayout
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
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

              Flow {
                Layout.fillWidth: true
                width: parent.width
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
                  text: "• Use [←/→ or h/l] to adjust ±5%"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  color: Color.accent
                }
              }

              Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: "Microphone input gain and recording volume level."
                font.family: Style.font.family
                font.pixelSize: Style.font.subtext || 11
                color: Color.muted
                wrapMode: Text.WordWrap
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
                  if (root.panelRoot) root.panelRoot.focusSection = "content"
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
                  if (root.panelRoot) root.panelRoot.focusSection = "content"
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
        readonly property bool isFocused: root.isContentFocused && root.focusedRow === 4
        readonly property bool isHovered: inputMuteMouseArea.containsMouse
        color: inputMuteCard.isFocused ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.07) : (inputMuteCard.isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.05) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02))
        border.color: inputMuteCard.isFocused ? Color.accent : (inputMuteCard.isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.20) : "transparent")
        border.width: inputMuteCard.isFocused ? 2 : 1

        MouseArea {
          id: inputMuteMouseArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.focusedRow = 4
            if (root.panelRoot) root.panelRoot.focusSection = "content"
            root.toggleInputMute()
          }
        }

        RowLayout {
          id: inputMuteRowLayout
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 14
          spacing: 14

          Rectangle {
            width: 44
            height: 44
            radius: 8
            color: root.inputMuted ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.25) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)

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

            Flow {
              Layout.fillWidth: true
              width: parent.width
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
                text: "• Press [Enter/Space or m] to toggle"
                font.family: Style.font.family
                font.pixelSize: 11
                color: Color.accent
              }
            }

            Text {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              text: root.inputMuted ? "Microphone is muted (no audio input)" : "Microphone is active and unmuted"
              font.family: Style.font.family
              font.pixelSize: Style.font.subtext || 11
              color: Color.muted
              wrapMode: Text.WordWrap
            }
          }

          Rectangle {
            width: 90
            height: 32
            radius: 16
            color: root.inputMuted ? Color.urgent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.10)
            border.color: (inputMuteCard.isFocused || inputMuteCard.isHovered) ? (root.inputMuted ? Color.urgent : Color.accent) : "transparent"
            border.width: inputMuteCard.isFocused ? 2 : (inputMuteCard.isHovered ? 1 : 0)

            Text {
              anchors.centerIn: parent
              text: root.inputMuted ? "MUTED" : "UNMUTED"
              font.family: Style.font.family
              font.pixelSize: 11
              font.bold: true
              color: root.inputMuted ? "#ffffff" : (inputMuteCard.isFocused || inputMuteCard.isHovered ? Color.foreground : Color.muted)
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
        readonly property bool isFocused: root.isContentFocused && root.focusedRow === 5
        readonly property bool isHovered: sourceCardMouseArea.containsMouse
        color: sourceCard.isFocused ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.07) : (sourceCard.isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.05) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02))
        border.color: sourceCard.isFocused ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35) : (sourceCard.isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.20) : "transparent")
        border.width: 1

        MouseArea {
          id: sourceCardMouseArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.focusedRow = 5
            if (root.panelRoot) root.panelRoot.focusSection = "content"
          }
        }

        ColumnLayout {
          id: sourceColLayout
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
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

              Flow {
                Layout.fillWidth: true
                width: parent.width
                spacing: 8

                Text {
                  text: "Microphone Input Device"
                  font.family: Style.font.family
                  font.pixelSize: Style.font.subtitle || 14
                  font.bold: true
                  color: Color.foreground
                }

                Rectangle {
                  height: 20
                  width: activeSourceLabel.implicitWidth + 12
                  radius: 4
                  color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
                  border.color: Color.accent
                  border.width: 1

                  Text {
                    id: activeSourceLabel
                    anchors.centerIn: parent
                    text: {
                      var idx = root.currentSourceIndex()
                      return (root.sources.length > idx && root.sources[idx]) ? root.sources[idx].name : "Default"
                    }
                    font.family: Style.font.family
                    font.pixelSize: 10
                    font.bold: true
                    color: Color.accent
                    elide: Text.ElideRight
                  }
                }

                Text {
                  visible: sourceCard.isFocused
                  text: "• Use [←/→ or h/l] to navigate • [Enter/Space] to set"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  color: Color.accent
                }
              }

              Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: "Select default audio input device and recording source."
                font.family: Style.font.family
                font.pixelSize: Style.font.subtext || 11
                color: Color.muted
                wrapMode: Text.WordWrap
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
                  if (root.panelRoot) root.panelRoot.focusSection = "content"
                  var cur = (root.sourceFocusIndex >= 0) ? root.sourceFocusIndex : root.currentSourceIndex()
                  var next = Math.max(0, cur - 1)
                  root.sourceFocusIndex = next
                  if (next < root.sources.length) {
                    root.setDefaultSource(root.sources[next].id, root.sources[next].name)
                  }
                }
              }

              Button {
                text: "▶"
                implicitWidth: 32
                implicitHeight: 32
                bordered: true
                onClicked: {
                  root.focusedRow = 5
                  if (root.panelRoot) root.panelRoot.focusSection = "content"
                  var cur = (root.sourceFocusIndex >= 0) ? root.sourceFocusIndex : root.currentSourceIndex()
                  var next = Math.min(root.sources.length - 1, cur + 1)
                  root.sourceFocusIndex = next
                  if (next < root.sources.length) {
                    root.setDefaultSource(root.sources[next].id, root.sources[next].name)
                  }
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
                id: sourcePillRect
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                implicitHeight: Math.max(36, sourcePillRow.implicitHeight + 12)
                Layout.preferredHeight: implicitHeight
                radius: 6

                readonly property bool isActive: modelData.isDefault
                readonly property bool isFocused: root.isContentFocused && (root.focusedRow === 5) && ((root.sourceFocusIndex >= 0 ? root.sourceFocusIndex : root.currentSourceIndex()) === index)
                readonly property bool isHovered: sourcePillMouse.containsMouse

                color: {
                  if (isActive) {
                    return isHovered ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.28)
                                     : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
                  }
                  if (isFocused) {
                    return isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.18)
                                     : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.14)
                  }
                  if (isHovered) {
                    return Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
                  }
                  return Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.03)
                }

                border.color: {
                  if (isFocused) {
                    return Color.accent
                  }
                  if (isActive) {
                    return Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.6)
                  }
                  if (isHovered) {
                    return Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28)
                  }
                  return Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
                }
                border.width: isFocused ? 2 : 1

                MouseArea {
                  id: sourcePillMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.focusedRow = 5
                    root.sourceFocusIndex = index
                    if (root.panelRoot) root.panelRoot.focusSection = "content"
                    root.setDefaultSource(modelData.id, modelData.name)
                  }
                }

                RowLayout {
                  id: sourcePillRow
                  anchors.top: parent.top
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.margins: 8
                  spacing: 6

                  Rectangle {
                    visible: sourcePillRect.isActive
                    width: 5
                    height: 5
                    radius: 2.5
                    color: Color.accent
                  }

                  Text {
                    text: "󰍬"
                    font.family: Style.font.family
                    font.pixelSize: 14
                    color: sourcePillRect.isActive ? Color.accent : (sourcePillRect.isFocused || sourcePillRect.isHovered ? Color.foreground : Color.muted)
                  }

                  Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: modelData.name
                    font.family: Style.font.family
                    font.pixelSize: 11
                    font.bold: sourcePillRect.isActive || sourcePillRect.isFocused
                    color: sourcePillRect.isActive ? Color.accent : (sourcePillRect.isFocused || sourcePillRect.isHovered ? Color.foreground : Color.muted)
                    elide: Text.ElideRight
                  }

                  Text {
                    visible: sourcePillRect.isActive
                    text: "✓"
                    font.family: Style.font.family
                    font.pixelSize: 11
                    font.bold: true
                    color: Color.accent
                  }
                }
              }
            }
          }
        }
      }

      // Section Header: Applications Mixer
      Text {
        text: "APPLICATION AUDIO MIXER"
        font.family: Style.font.family
        font.pixelSize: 11
        font.bold: true
        color: Color.muted
        Layout.topMargin: 8
      }

      // Empty state card
      Rectangle {
        visible: root.apps.length === 0
        Layout.fillWidth: true
        implicitHeight: Math.max(64, soundEmptyRow.implicitHeight + 28)
        Layout.preferredHeight: implicitHeight
        radius: Style.cornerRadius || 8
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.03)
        border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
        border.width: 1

        RowLayout {
          id: soundEmptyRow
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 14
          spacing: 12

          Text {
            text: "󰝚"
            font.family: Style.font.family
            font.pixelSize: 20
            color: Color.muted
          }

          ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 0
            Layout.minimumWidth: 0
            spacing: 2

            Text {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              elide: Text.ElideRight
              text: "No Active Application Audio Streams"
              font.family: Style.font.family
              font.pixelSize: 13
              font.bold: true
              color: Color.foreground
            }

            Text {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              wrapMode: Text.WordWrap
              text: "Apps currently playing audio (browsers, media players, games) will appear here."
              font.family: Style.font.family
              font.pixelSize: 11
              color: Color.muted
            }
          }
        }
      }

      // Active Apps Repeater
      Repeater {
        id: appRepeater
        model: root.apps

        delegate: Rectangle {
          id: appCard
          Layout.fillWidth: true
          implicitHeight: Math.max(104, appColLayout.implicitHeight + 24)
          Layout.preferredHeight: implicitHeight
          radius: Style.cornerRadius || 8
          readonly property bool isFocused: root.isContentFocused && root.focusedRow === (6 + index)
          readonly property bool isHovered: appCardMouseArea.containsMouse
          color: appCard.isFocused ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.07) : (appCard.isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.05) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02))
          border.color: appCard.isFocused ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35) : (appCard.isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.20) : "transparent")
          border.width: 1

          MouseArea {
            id: appCardMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.focusedRow = 6 + index
              if (root.panelRoot) root.panelRoot.focusSection = "content"
            }
          }

          ColumnLayout {
            id: appColLayout
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 12
            spacing: 8

            RowLayout {
              Layout.fillWidth: true
              spacing: 10

              Rectangle {
                width: 32
                height: 32
                radius: 6
                color: modelData.muted ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.25) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)

                Text {
                  anchors.centerIn: parent
                  text: modelData.muted ? "󰝟" : "󰕾"
                  font.family: Style.font.family
                  font.pixelSize: 16
                  color: modelData.muted ? Color.urgent : Color.accent
                }
              }

              ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 2

                Flow {
                  Layout.fillWidth: true
                  width: parent.width
                  spacing: 6
                  Text {
                    text: modelData.name
                    font.family: Style.font.family
                    font.pixelSize: 13
                    font.bold: true
                    color: Color.foreground
                  }

                  Text {
                    visible: appCard.isFocused
                    text: "• Use [←/→ or h/l] to adjust"
                    font.family: Style.font.family
                    font.pixelSize: 11
                    color: Color.accent
                  }
                }

                Text {
                  text: "Stream #" + modelData.id
                  font.family: Style.font.family
                  font.pixelSize: 10
                  color: Color.muted
                }
              }

              Text {
                text: modelData.muted ? "MUTED" : (modelData.volume + "%")
                font.family: Style.font.family
                font.pixelSize: 13
                font.bold: true
                color: modelData.muted ? Color.urgent : Color.accent
              }

              Button {
                text: modelData.muted ? "Unmute" : "Mute"
                implicitHeight: 28
                onClicked: {
                  root.focusedRow = 6 + index
                  if (root.panelRoot) root.panelRoot.focusSection = "content"
                  root.toggleAppMute(modelData.id, modelData.name)
                }
              }

              RowLayout {
                spacing: 4

                Button {
                  text: "◀"
                  implicitWidth: 28
                  implicitHeight: 28
                  onClicked: {
                    root.focusedRow = 6 + index
                    if (root.panelRoot) root.panelRoot.focusSection = "content"
                    root.adjustAppVolume(modelData.id, -5, modelData.name)
                  }
                }

                Button {
                  text: "▶"
                  implicitWidth: 28
                  implicitHeight: 28
                  onClicked: {
                    root.focusedRow = 6 + index
                    if (root.panelRoot) root.panelRoot.focusSection = "content"
                    root.adjustAppVolume(modelData.id, 5, modelData.name)
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
              value: modelData.volume
              onMoved: function(v) { modelData.volume = Math.round(v) }
              onReleased: function(v) { root.setAppVolume(modelData.id, v, modelData.name) }
            }
          }
        }
      }

      Item { Layout.preferredHeight: 12 }
    }
  }
}
