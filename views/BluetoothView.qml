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
  property bool powered: true
  property bool discovering: false
  property var adapter: ({ name: "Bluetooth Adapter", mac: "" })
  property var devices: []
  property string statusMessage: ""

  property bool activeFocusSection: false
  property int focusedRow: 0   // 0: Power Toggle, 1: Scan, 2..N: Device rows
  onFocusedRowChanged: ensureRowVisible(focusedRow)

  function ensureRowVisible(index) {
    if (!scrollArea || !scrollArea.contentItem) return
    var item = null
    if (index === 0) item = btPowerCard
    else if (index === 1) item = scanCard
    else if (index >= 2 && devicesRepeater && index - 2 < devicesRepeater.count) {
      item = devicesRepeater.itemAt(index - 2)
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

  function handleMove(dx, dy) {
    var maxRow = 1 + root.devices.length
    if (dy !== 0) {
      focusedRow = Math.max(0, Math.min(maxRow, focusedRow + dy))
      ensureRowVisible(focusedRow)
      return true
    }
    if (dx !== 0) {
      if (focusedRow === 0) {
        togglePower()
      } else if (focusedRow === 1) {
        triggerScan()
      } else {
        var devIdx = focusedRow - 2
        if (devIdx >= 0 && devIdx < root.devices.length) {
          toggleDevice(root.devices[devIdx])
        }
      }
      return true
    }
    return false
  }

  function handleActivate() {
    if (focusedRow === 0) {
      togglePower()
    } else if (focusedRow === 1) {
      triggerScan()
    } else {
      var devIdx = focusedRow - 2
      if (devIdx >= 0 && devIdx < root.devices.length) {
        toggleDevice(root.devices[devIdx])
      }
    }
  }

  function handleTextKey(key) {
    if (key === "r" || key === "R") {
      refresh()
    } else if (key === "b" || key === "B") {
      focusedRow = 0
      togglePower()
    } else if (key === "s" || key === "S") {
      focusedRow = 1
      triggerScan()
    } else if (key === "h" || key === "H") {
      handleMove(-1, 0)
    } else if (key === "l" || key === "L") {
      handleMove(1, 0)
    }
  }

  function refresh() {
    if (!stateProcess.running && pluginPath.length > 0) {
      stateProcess.command = [pluginPath + "/scripts/bluetooth-control.sh", "get-state"]
      stateProcess.running = true
    }
  }

  function togglePower() {
    root.powered = !root.powered
    togglePowerProcess.command = [pluginPath + "/scripts/bluetooth-control.sh", "bluetooth-toggle"]
    togglePowerProcess.running = true
    notifyStatus(root.powered ? "Enabling Bluetooth..." : "Disabling Bluetooth...")
  }

  function triggerScan() {
    notifyStatus("Scanning for Bluetooth devices...")
    root.discovering = true
    scanProcess.command = [pluginPath + "/scripts/bluetooth-control.sh", "scan-trigger"]
    scanProcess.running = true
    scanTimer.restart()
  }

  Timer {
    id: scanTimer
    interval: 4200
    repeat: false
    onTriggered: {
      root.discovering = false
      root.refresh()
    }
  }

  function toggleDevice(dev) {
    if (!dev) return
    if (dev.connected) {
      notifyStatus("Disconnecting from " + (dev.name || dev.mac) + "...")
      deviceToggleProcess.command = [pluginPath + "/scripts/bluetooth-control.sh", "device-toggle", dev.mac]
      deviceToggleProcess.running = true
    } else if (dev.paired) {
      notifyStatus("Connecting to " + (dev.name || dev.mac) + "...")
      deviceToggleProcess.command = [pluginPath + "/scripts/bluetooth-control.sh", "device-toggle", dev.mac]
      deviceToggleProcess.running = true
    } else {
      notifyStatus("Pairing with " + (dev.name || dev.mac) + "...")
      devicePairProcess.command = [pluginPath + "/scripts/bluetooth-control.sh", "device-pair", dev.mac]
      devicePairProcess.running = true
    }
  }

  function notifyStatus(msg) {
    statusMessage = msg
    statusClearTimer.restart()
  }

  Timer {
    id: statusClearTimer
    interval: 3500
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
          if (data.powered !== undefined) root.powered = data.powered
          if (data.discovering !== undefined && !scanTimer.running) root.discovering = data.discovering
          if (data.adapter) root.adapter = data.adapter
          if (Array.isArray(data.devices)) {
            root.devices = data.devices
          }
        } catch (e) {
          console.warn("BluetoothView: JSON parse error", e)
        }
      }
    }
  }

  // Toggle Power Process
  Process {
    id: togglePowerProcess
    onRunningChanged: if (!running) root.refresh()
  }

  // Scan Process
  Process {
    id: scanProcess
    onRunningChanged: if (!running) root.refresh()
  }

  // Device Toggle Process
  Process {
    id: deviceToggleProcess
    onRunningChanged: if (!running) root.refresh()
  }

  // Device Pair Process
  Process {
    id: devicePairProcess
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

      // Bluetooth Hero Card
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
            width: 46
            height: 46
            radius: 8
            color: Color.pickAlpha("surface.selected", "#2a3036")

            Text {
              anchors.centerIn: parent
              text: root.powered ? "󰂯" : "󰂲"
              font.family: Style.font.family
              font.pixelSize: 24
              color: root.powered ? Color.accent : Color.muted
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
              spacing: 8
              Text {
                text: (root.adapter && root.adapter.name) ? root.adapter.name : "Bluetooth Adapter"
                font.family: Style.font.family
                font.pixelSize: Style.font.title || 16
                font.bold: true
                color: Color.foreground
              }

              Rectangle {
                width: root.powered ? 76 : 74
                height: 20
                radius: 4
                color: root.powered ? Color.pickAlpha("accent.subtle", "#1f3b30") : Color.pickAlpha("surface.selected", "#2a3036")

                Text {
                  anchors.centerIn: parent
                  text: root.powered ? "Ready" : "Disabled"
                  font.family: Style.font.family
                  font.pixelSize: 10
                  font.bold: true
                  color: root.powered ? Color.accent : Color.muted
                }
              }
            }

            Text {
              text: root.powered
                ? ((root.adapter && root.adapter.mac ? ("Controller MAC: " + root.adapter.mac + "  •  ") : "") + root.devices.length + " devices recorded")
                : "Bluetooth radio is disabled. Enable it to connect devices."
              font.family: Style.font.family
              font.pixelSize: Style.font.subtext || 12
              color: Color.muted
            }
          }

          Button {
            text: root.discovering ? "Scanning..." : "Scan"
            iconText: ""
            enabled: root.powered
            onClicked: root.triggerScan()
          }
        }
      }

      // Setting Row 0: Bluetooth Power Toggle Card
      Rectangle {
        id: btPowerCard
        Layout.fillWidth: true
        implicitHeight: Math.max(74, btPowerRowLayout.implicitHeight + 28)
        Layout.preferredHeight: implicitHeight
        radius: Style.cornerRadius || 8
        readonly property bool isFocused: root.activeFocusSection && root.focusedRow === 0
        color: btPowerCard.isFocused ? Color.pickAlpha("surface.selected", "#22272e") : Color.pickAlpha("surface.subtle", "#181b1d")
        border.color: btPowerCard.isFocused ? Color.accent : "transparent"
        border.width: btPowerCard.isFocused ? 2 : 1

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.focusedRow = 0
            root.togglePower()
          }
        }

        RowLayout {
          id: btPowerRowLayout
          anchors.fill: parent
          anchors.margins: 14
          spacing: 14

          Rectangle {
            width: 44
            height: 44
            radius: 8
            color: root.powered ? Color.pickAlpha("accent.subtle", "#1f3b30") : Color.pickAlpha("surface.hover", "#20252b")

            Text {
              anchors.centerIn: parent
              text: root.powered ? "󰂯" : "󰂲"
              font.family: Style.font.family
              font.pixelSize: 20
              color: root.powered ? Color.accent : Color.foreground
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
                text: "Bluetooth Power"
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle || 14
                font.bold: true
                color: Color.foreground
              }
              Text {
                visible: btPowerCard.isFocused
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: "• Press [Enter/Space or b] to toggle"
                font.family: Style.font.family
                font.pixelSize: 11
                color: Color.accent
                elide: Text.ElideRight
              }
            }

            Text {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              text: root.powered ? "Bluetooth adapter is powered on and receptive." : "Bluetooth radio is completely switched off."
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
            color: root.powered ? Color.accent : Color.pickAlpha("surface.selected", "#2a3036")
            border.color: btPowerCard.isFocused ? Color.accent : "transparent"
            border.width: btPowerCard.isFocused ? 2 : 0

            Text {
              anchors.centerIn: parent
              text: root.powered ? "ON" : "OFF"
              font.family: Style.font.family
              font.pixelSize: 11
              font.bold: true
              color: root.powered ? "#000000" : Color.muted
            }
          }
        }
      }

      // Setting Row 1: Device Discovery / Scanning Card
      Rectangle {
        id: scanCard
        Layout.fillWidth: true
        implicitHeight: Math.max(64, scanRowLayout.implicitHeight + 28)
        Layout.preferredHeight: implicitHeight
        radius: Style.cornerRadius || 8
        readonly property bool isFocused: root.activeFocusSection && root.focusedRow === 1
        color: scanCard.isFocused ? Color.pickAlpha("surface.selected", "#22272e") : Color.pickAlpha("surface.subtle", "#181b1d")
        border.color: scanCard.isFocused ? Color.accent : "transparent"
        border.width: scanCard.isFocused ? 2 : 1
        visible: root.powered

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.focusedRow = 1
            root.triggerScan()
          }
        }

        RowLayout {
          id: scanRowLayout
          anchors.fill: parent
          anchors.margins: 14
          spacing: 14

          Rectangle {
            width: 36
            height: 36
            radius: 8
            color: root.discovering ? Color.pickAlpha("accent.subtle", "#1f3b30") : Color.pickAlpha("surface.hover", "#20252b")

            Text {
              anchors.centerIn: parent
              text: "󰂰"
              font.family: Style.font.family
              font.pixelSize: 18
              color: root.discovering ? Color.accent : Color.muted
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
                text: "Device Discovery"
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle || 13
                font.bold: true
                color: Color.foreground
              }
              Text {
                visible: scanCard.isFocused
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: "• Press [Enter/Space or s] to scan"
                font.family: Style.font.family
                font.pixelSize: 11
                color: Color.accent
                elide: Text.ElideRight
              }
            }

            Text {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              text: root.discovering ? "Actively scanning for nearby devices..." : "Discover nearby devices in pairing mode."
              font.family: Style.font.family
              font.pixelSize: Style.font.subtext || 11
              color: Color.muted
              elide: Text.ElideRight
            }
          }

          Rectangle {
            width: 100
            height: 28
            radius: 14
            color: root.discovering ? Color.accent : Color.pickAlpha("surface.selected", "#2a3036")
            border.color: scanCard.isFocused ? Color.accent : "transparent"
            border.width: scanCard.isFocused ? 1 : 0

            Text {
              anchors.centerIn: parent
              text: root.discovering ? "SCANNING..." : "SCAN"
              font.family: Style.font.family
              font.pixelSize: 10
              font.bold: true
              color: root.discovering ? "#000000" : Color.foreground
            }
          }
        }
      }

      // Section Header: Devices List
      RowLayout {
        Layout.fillWidth: true
        visible: root.powered
        spacing: 8

        Text {
          text: "BLUETOOTH DEVICES (" + root.devices.length + ")"
          font.family: Style.font.family
          font.pixelSize: 11
          font.bold: true
          color: Color.muted
        }

        Item { Layout.fillWidth: true }

        Text {
          text: "[Enter/Space] Connect/Disconnect/Pair"
          font.family: Style.font.family
          font.pixelSize: 10
          color: Color.muted
        }
      }

      // Devices List
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 6
        visible: root.powered

        Repeater {
          id: devicesRepeater
          model: root.devices

          delegate: Rectangle {
            id: delegateCard
            Layout.fillWidth: true
            implicitHeight: Math.max(52, delegateBtRowLayout.implicitHeight + 16)
            Layout.preferredHeight: implicitHeight
            radius: Style.cornerRadius || 6
            readonly property bool isFocused: root.activeFocusSection && root.focusedRow === (index + 2)
            color: delegateCard.isFocused
              ? Color.pickAlpha("surface.selected", "#22272e")
              : (modelData.connected ? Color.pickAlpha("surface.subtle", "#1c2220") : Color.pickAlpha("surface.subtle", "#181b1d"))
            border.color: delegateCard.isFocused ? Color.accent : (modelData.connected ? Color.pickAlpha("accent.subtle", "#304030") : "transparent")
            border.width: delegateCard.isFocused ? 2 : 1

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.focusedRow = index + 2
                root.toggleDevice(modelData)
              }
            }

            RowLayout {
              id: delegateBtRowLayout
              anchors.fill: parent
              anchors.leftMargin: 14
              anchors.rightMargin: 14
              spacing: 12

              // Device Type Icon
              Text {
                text: {
                  var t = modelData.iconType || ""
                  if (t.indexOf("audio") !== -1) return "󰥰"
                  if (t.indexOf("keyboard") !== -1) return "󰌌"
                  if (t.indexOf("mouse") !== -1) return "󰍽"
                  if (t.indexOf("phone") !== -1) return "󰄋"
                  if (t.indexOf("gaming") !== -1) return "󰄡"
                  return "󰂯"
                }
                font.family: Style.font.family
                font.pixelSize: 18
                color: modelData.connected ? Color.accent : (delegateCard.isFocused ? Color.accent : Color.foreground)
              }

              // Device Info
              ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 2

                RowLayout {
                  Layout.fillWidth: true
                  Layout.minimumWidth: 0
                  spacing: 6
                  Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: modelData.name || modelData.mac
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body || 13
                    font.bold: modelData.connected || delegateCard.isFocused
                    color: modelData.connected ? Color.accent : Color.foreground
                    elide: Text.ElideRight
                  }

                  Text {
                    visible: modelData.connected
                    text: "✓"
                    font.family: Style.font.family
                    font.pixelSize: 12
                    font.bold: true
                    color: Color.accent
                  }
                }

                RowLayout {
                  spacing: 8
                  Text {
                    text: modelData.mac
                    font.family: Style.font.family
                    font.pixelSize: 10
                    color: Color.muted
                  }

                  Text {
                    text: "• " + (modelData.paired ? (modelData.connected ? "Connected" : "Paired") : "Available")
                    font.family: Style.font.family
                    font.pixelSize: 10
                    color: modelData.connected ? Color.accent : Color.muted
                  }
                }
              }

              // Action / Status Pill
              Rectangle {
                width: modelData.connected ? 104 : (modelData.paired ? 96 : 74)
                height: 28
                radius: 14
                color: modelData.connected
                  ? Color.pickAlpha("accent.subtle", "#1f3b30")
                  : (delegateCard.isFocused ? Color.pickAlpha("surface.hover", "#2a3036") : "transparent")
                border.color: modelData.connected ? Color.accent : (delegateCard.isFocused ? Color.accent : Color.pickAlpha("surface.hover", "#2a3036"))
                border.width: 1

                Text {
                  anchors.centerIn: parent
                  text: modelData.connected ? "CONNECTED" : (modelData.paired ? (delegateCard.isFocused ? "CONNECT" : "PAIRED") : "PAIR")
                  font.family: Style.font.family
                  font.pixelSize: 10
                  font.bold: modelData.connected || delegateCard.isFocused
                  color: modelData.connected ? Color.accent : (delegateCard.isFocused ? Color.foreground : Color.muted)
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
