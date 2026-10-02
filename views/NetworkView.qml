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
  property bool wifiEnabled: true
  property var activeConnection: null
  property var networks: []
  property string statusMessage: ""

  property bool activeFocusSection: false
  property int focusedRow: 0   // 0: Wi-Fi Toggle, 1..N: Network rows
  onFocusedRowChanged: ensureRowVisible(focusedRow)

  function ensureRowVisible(index) {
    if (!scrollArea || !scrollArea.contentItem) return
    var item = null
    if (index === 0) item = wifiToggleCard
    else if (index >= 1 && networksRepeater && index - 1 < networksRepeater.count) {
      item = networksRepeater.itemAt(index - 1)
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
    var maxRow = root.networks.length
    if (dy !== 0) {
      focusedRow = Math.max(0, Math.min(maxRow, focusedRow + dy))
      ensureRowVisible(focusedRow)
      return true
    }
    if (dx !== 0) {
      if (focusedRow === 0) {
        toggleWifi()
      } else {
        var netIdx = focusedRow - 1
        if (netIdx >= 0 && netIdx < root.networks.length) {
          toggleNetwork(root.networks[netIdx])
        }
      }
      return true
    }
    return false
  }

  function handleActivate() {
    if (focusedRow === 0) {
      toggleWifi()
    } else {
      var netIdx = focusedRow - 1
      if (netIdx >= 0 && netIdx < root.networks.length) {
        toggleNetwork(root.networks[netIdx])
      }
    }
  }

  function handleTextKey(key) {
    if (key === "r" || key === "R") {
      rescan()
    } else if (key === "w" || key === "W") {
      focusedRow = 0
      toggleWifi()
    } else if (key === "d" || key === "D") {
      disconnectActive()
    } else if (key === "h" || key === "H") {
      handleMove(-1, 0)
    } else if (key === "l" || key === "L") {
      handleMove(1, 0)
    }
  }

  function refresh() {
    if (!stateProcess.running && pluginPath.length > 0) {
      stateProcess.command = [pluginPath + "/scripts/network-control.sh", "get-state"]
      stateProcess.running = true
    }
  }

  function rescan() {
    notifyStatus("Scanning for Wi-Fi networks...")
    rescanProcess.command = [pluginPath + "/scripts/network-control.sh", "wifi-rescan"]
    rescanProcess.running = true
  }

  function toggleWifi() {
    root.wifiEnabled = !root.wifiEnabled
    toggleWifiProcess.command = [pluginPath + "/scripts/network-control.sh", "wifi-toggle"]
    toggleWifiProcess.running = true
    notifyStatus(root.wifiEnabled ? "Enabling Wi-Fi..." : "Disabling Wi-Fi...")
  }

  function toggleNetwork(net) {
    if (!net) return
    if (net.inUse) {
      disconnectActive()
    } else {
      connectToNetwork(net.ssid)
    }
  }

  function connectToNetwork(ssid) {
    notifyStatus("Connecting to " + ssid + "...")
    connectProcess.command = [pluginPath + "/scripts/network-control.sh", "wifi-connect", ssid]
    connectProcess.running = true
  }

  function disconnectActive() {
    notifyStatus("Disconnecting from network...")
    disconnectProcess.command = [pluginPath + "/scripts/network-control.sh", "wifi-disconnect"]
    disconnectProcess.running = true
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
          if (data.enabled !== undefined) root.wifiEnabled = data.enabled
          root.activeConnection = data.active
          if (Array.isArray(data.networks)) {
            root.networks = data.networks
          }
        } catch (e) {
          console.warn("NetworkView: JSON parse error", e)
        }
      }
    }
  }

  // Toggle Wi-Fi Process
  Process {
    id: toggleWifiProcess
    onRunningChanged: if (!running) root.refresh()
  }

  // Rescan Process
  Process {
    id: rescanProcess
    onRunningChanged: if (!running) root.refresh()
  }

  // Connect Process
  Process {
    id: connectProcess
    onRunningChanged: if (!running) root.refresh()
  }

  // Disconnect Process
  Process {
    id: disconnectProcess
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

      // Wi-Fi Hero Card
      Rectangle {
        id: networkHeroCard
        Layout.fillWidth: true
        implicitHeight: Math.max(76, networkHeroRow.implicitHeight + 28)
        Layout.preferredHeight: implicitHeight
        color: Color.pickAlpha("surface.subtle", "#181b1d")
        radius: Style.cornerRadius || 8

        RowLayout {
          id: networkHeroRow
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 14
          spacing: 14

          Rectangle {
            width: 46
            height: 46
            radius: 8
            color: Color.pickAlpha("surface.selected", "#2a3036")

            Text {
              anchors.centerIn: parent
              text: root.activeConnection ? "󰤨" : (root.wifiEnabled ? "󰤫" : "󰤮")
              font.family: Style.font.family
              font.pixelSize: 24
              color: root.activeConnection ? Color.accent : Color.muted
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
                text: root.activeConnection ? root.activeConnection.ssid : (root.wifiEnabled ? "Wi-Fi Ready" : "Wi-Fi Disabled")
                font.family: Style.font.family
                font.pixelSize: Style.font.title || 16
                font.bold: true
                color: Color.foreground
              }

              Rectangle {
                width: root.activeConnection ? 80 : 86
                height: 20
                radius: 4
                color: root.activeConnection ? Color.pickAlpha("accent.subtle", "#1f3b30") : Color.pickAlpha("surface.selected", "#2a3036")

                Text {
                  anchors.centerIn: parent
                  text: root.activeConnection ? "Connected" : (root.wifiEnabled ? "Disconnected" : "Disabled")
                  font.family: Style.font.family
                  font.pixelSize: 10
                  font.bold: true
                  color: root.activeConnection ? Color.accent : Color.muted
                }
              }
            }

            Text {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              wrapMode: Text.WordWrap
              text: root.activeConnection
                ? ("IP: " + (root.activeConnection.ip || "Obtaining...") + "  •  Signal: " + (root.activeConnection.signal || 100) + "%  •  Band: " + (root.activeConnection.frequency || "2.4GHz"))
                : (root.wifiEnabled ? "Select a network below or press [r] to scan" : "Turn on Wi-Fi interface to discover wireless networks")
              font.family: Style.font.family
              font.pixelSize: Style.font.subtext || 12
              color: Color.muted
            }
          }

          Button {
            text: "Scan"
            iconText: ""
            enabled: root.wifiEnabled
            onClicked: root.rescan()
          }
        }
      }

      // Setting Row 0: Wi-Fi Interface Radio Toggle Card
      Rectangle {
        id: wifiToggleCard
        Layout.fillWidth: true
        implicitHeight: Math.max(74, wifiToggleRowLayout.implicitHeight + 28)
        Layout.preferredHeight: implicitHeight
        radius: Style.cornerRadius || 8
        readonly property bool isFocused: root.activeFocusSection && root.focusedRow === 0
        color: wifiToggleCard.isFocused ? Color.pickAlpha("surface.selected", "#22272e") : Color.pickAlpha("surface.subtle", "#181b1d")
        border.color: wifiToggleCard.isFocused ? Color.accent : "transparent"
        border.width: wifiToggleCard.isFocused ? 2 : 1

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.focusedRow = 0
            root.toggleWifi()
          }
        }

        RowLayout {
          id: wifiToggleRowLayout
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 14
          spacing: 14

          Rectangle {
            width: 44
            height: 44
            radius: 8
            color: root.wifiEnabled ? Color.pickAlpha("accent.subtle", "#1f3b30") : Color.pickAlpha("surface.hover", "#20252b")

            Text {
              anchors.centerIn: parent
              text: root.wifiEnabled ? "󰤨" : "󰤮"
              font.family: Style.font.family
              font.pixelSize: 20
              color: root.wifiEnabled ? Color.accent : Color.foreground
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
                text: "Wi-Fi Interface"
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle || 14
                font.bold: true
                color: Color.foreground
              }
              Text {
                visible: wifiToggleCard.isFocused
                text: "• Press [Enter/Space or w] to toggle"
                font.family: Style.font.family
                font.pixelSize: 11
                color: Color.accent
              }
            }

            Text {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              wrapMode: Text.WordWrap
              text: root.wifiEnabled ? "Wireless network interface is active and scanning." : "Wireless radio is switched off."
              font.family: Style.font.family
              font.pixelSize: Style.font.subtext || 11
              color: Color.muted
            }
          }

          Rectangle {
            width: 90
            height: 32
            Layout.preferredWidth: 90
            Layout.minimumWidth: 90
            Layout.preferredHeight: 32
            radius: 16
            color: root.wifiEnabled ? Color.accent : Color.pickAlpha("surface.selected", "#2a3036")
            border.color: wifiToggleCard.isFocused ? Color.accent : "transparent"
            border.width: wifiToggleCard.isFocused ? 2 : 0

            Text {
              anchors.centerIn: parent
              text: root.wifiEnabled ? "ENABLED" : "DISABLED"
              font.family: Style.font.family
              font.pixelSize: 11
              font.bold: true
              color: root.wifiEnabled ? "#000000" : Color.muted
            }
          }
        }
      }

      // Section Header: Available Networks
      RowLayout {
        Layout.fillWidth: true
        visible: root.wifiEnabled
        spacing: 8

        Text {
          text: "AVAILABLE WI-FI NETWORKS (" + root.networks.length + ")"
          font.family: Style.font.family
          font.pixelSize: 11
          font.bold: true
          color: Color.muted
        }

        Item { Layout.fillWidth: true }

        Text {
          text: "[Enter/Space] Connect/Disconnect  •  [r] Rescan"
          font.family: Style.font.family
          font.pixelSize: 10
          color: Color.muted
        }
      }

      // Available Networks List
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 6
        visible: root.wifiEnabled

        Repeater {
          id: networksRepeater
          model: root.networks

          delegate: Rectangle {
            id: delegateCard
            Layout.fillWidth: true
            implicitHeight: Math.max(52, delegateRowLayout.implicitHeight + 16)
            Layout.preferredHeight: implicitHeight
            radius: Style.cornerRadius || 6
            readonly property bool isFocused: root.activeFocusSection && root.focusedRow === (index + 1)
            color: delegateCard.isFocused
              ? Color.pickAlpha("surface.selected", "#22272e")
              : (modelData.inUse ? Color.pickAlpha("surface.subtle", "#1c2220") : Color.pickAlpha("surface.subtle", "#181b1d"))
            border.color: delegateCard.isFocused ? Color.accent : (modelData.inUse ? Color.pickAlpha("accent.subtle", "#304030") : "transparent")
            border.width: delegateCard.isFocused ? 2 : 1

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.focusedRow = index + 1
                root.toggleNetwork(modelData)
              }
            }

            RowLayout {
              id: delegateRowLayout
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.margins: 8
              anchors.leftMargin: 14
              anchors.rightMargin: 14
              spacing: 12

              // Signal Strength Icon
              Text {
                text: {
                  var s = modelData.signal || 0
                  if (s >= 75) return "󰤨"
                  if (s >= 50) return "󰤥"
                  if (s >= 25) return "󰤢"
                  return "󰤟"
                }
                font.family: Style.font.family
                font.pixelSize: 18
                color: modelData.inUse ? Color.accent : (delegateCard.isFocused ? Color.accent : Color.foreground)
              }

              // Network Info
              ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 2

                Flow {
                  Layout.fillWidth: true
                  width: parent.width
                  spacing: 6
                  Text {
                    text: modelData.ssid
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body || 13
                    font.bold: modelData.inUse || delegateCard.isFocused
                    color: modelData.inUse ? Color.accent : Color.foreground
                    elide: Text.ElideRight
                  }

                  Text {
                    visible: modelData.inUse
                    text: "✓"
                    font.family: Style.font.family
                    font.pixelSize: 12
                    font.bold: true
                    color: Color.accent
                  }
                }

                Flow {
                  Layout.fillWidth: true
                  width: parent.width
                  spacing: 8
                  Text {
                    text: (modelData.security && modelData.security.length > 0) ? ("󰌾 " + modelData.security) : "󰌿 Open Network"
                    font.family: Style.font.family
                    font.pixelSize: 10
                    color: Color.muted
                  }

                  Text {
                    text: "• " + modelData.signal + "% signal"
                    font.family: Style.font.family
                    font.pixelSize: 10
                    color: Color.muted
                  }
                }
              }

              // Action / Status Pill
              Rectangle {
                width: modelData.inUse ? 96 : 84
                height: 28
                Layout.preferredWidth: modelData.inUse ? 96 : 84
                Layout.minimumWidth: modelData.inUse ? 96 : 84
                Layout.preferredHeight: 28
                radius: 14
                color: modelData.inUse
                  ? Color.pickAlpha("accent.subtle", "#1f3b30")
                  : (delegateCard.isFocused ? Color.pickAlpha("surface.hover", "#2a3036") : "transparent")
                border.color: modelData.inUse ? Color.accent : (delegateCard.isFocused ? Color.accent : Color.pickAlpha("surface.hover", "#2a3036"))
                border.width: 1

                Text {
                  anchors.centerIn: parent
                  text: modelData.inUse ? "CONNECTED" : (delegateCard.isFocused ? "CONNECT" : "SAVED")
                  font.family: Style.font.family
                  font.pixelSize: 10
                  font.bold: modelData.inUse || delegateCard.isFocused
                  color: modelData.inUse ? Color.accent : (delegateCard.isFocused ? Color.foreground : Color.muted)
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
