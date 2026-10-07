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

  property string pluginPath: (Quickshell.env("HOME") || "/home/ac") + "/.config/omarchy/plugins/ac.control-panel"
  onPluginPathChanged: refresh()
  property var panelRoot: null
  property bool wifiEnabled: true
  property var activeConnection: null
  property var networks: []
  property string statusMessage: ""
  property bool isScanning: false
  property bool wasScanning: false
  property double lastScanTime: 0

  property string passwordSsid: ""
  property string passwordText: ""
  property bool showPasswordText: false
  property string passwordError: ""
  property bool isConnecting: false
  property string connectingSsid: ""
  property Item activePasswordInput: null
  property Item activeShowPwBtn: null
  property Item activeConnectBtn: null
  property Item activeCancelBtn: null
  property int promptFocusIndex: 0 // 0: Password Input, 1: Show/Hide, 2: Connect, 3: Cancel

  property var wifiQrData: null
  property bool showWifiQrModal: false
  property bool isLoadingQr: false
  property int qrRefreshCounter: 0

  readonly property bool hasActiveInput: (passwordSsid !== "") || showWifiQrModal

  onActiveFocusSectionChanged: {
    if (!activeFocusSection) {
      blurInput()
    }
  }

  function setPromptFocus(idx) {
    if (passwordSsid === "") return
    promptFocusIndex = (idx % 4 + 4) % 4
    if (promptFocusIndex === 0) {
      if (activePasswordInput) {
        activePasswordInput.focus = true
        activePasswordInput.forceActiveFocus()
      }
    } else if (promptFocusIndex === 1) {
      if (activeShowPwBtn) {
        activeShowPwBtn.focus = true
        activeShowPwBtn.forceActiveFocus()
      }
    } else if (promptFocusIndex === 2) {
      if (activeConnectBtn) {
        activeConnectBtn.focus = true
        activeConnectBtn.forceActiveFocus()
      }
    } else if (promptFocusIndex === 3) {
      if (activeCancelBtn) {
        activeCancelBtn.focus = true
        activeCancelBtn.forceActiveFocus()
      }
    }
  }

  function focusToInput() {
    if (passwordSsid !== "") {
      setPromptFocus(promptFocusIndex)
    }
  }

  function blurInput() {
    if (activePasswordInput) activePasswordInput.focus = false
    if (activeShowPwBtn) activeShowPwBtn.focus = false
    if (activeConnectBtn) activeConnectBtn.focus = false
    if (activeCancelBtn) activeCancelBtn.focus = false
  }

  function openPasswordPrompt(ssid) {
    if (passwordSsid !== ssid) {
      passwordText = ""
      passwordError = ""
      showPasswordText = false
    }
    passwordSsid = ssid
    promptFocusIndex = 0
    for (var i = 0; i < root.networks.length; i++) {
      if (root.networks[i].ssid === ssid) {
        root.focusedRow = i + 1
        break
      }
    }
    Qt.callLater(function() {
      ensureRowVisible(root.focusedRow)
    })
  }

  function cancelPasswordPrompt() {
    passwordSsid = ""
    passwordText = ""
    passwordError = ""
    showPasswordText = false
    promptFocusIndex = 0
    activePasswordInput = null
    activeShowPwBtn = null
    activeConnectBtn = null
    activeCancelBtn = null
  }

  function submitPasswordConnect() {
    if (passwordSsid === "" || passwordText.length === 0 || isConnecting) return
    connectToNetwork(passwordSsid, passwordText)
  }

  function openWifiQrModal(ssid) {
    var target = ssid || (root.activeConnection ? root.activeConnection.ssid : "")
    if (!target) {
      notifyStatus("No Wi-Fi network selected")
      return
    }
    isLoadingQr = true
    showWifiQrModal = true
    wifiQrProcess.command = [pluginPath + "/scripts/network-control.sh", "wifi-get-qr", target]
    wifiQrProcess.running = true
  }

  function closeWifiQrModal() {
    showWifiQrModal = false
    wifiQrData = null
  }

  function copyToClipboard(str, label) {
    if (!str) return
    if (pluginPath.length > 0) {
      clipboardProcess.command = [pluginPath + "/scripts/config-tracker.sh", "copy", str]
    } else {
      clipboardProcess.command = ["wl-copy", str]
    }
    clipboardProcess.running = true
    notifyStatus(label || "Copied to clipboard!")
  }

  property bool activeFocusSection: false
  readonly property bool isContentFocused: {
    if (root.panelRoot && root.panelRoot.focusSection !== undefined) {
      return root.panelRoot.focusSection === "content"
    }
    return activeFocusSection
  }
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
    if (hasActiveInput) return true
    var maxRow = root.networks.length
    if (dy !== 0) {
      focusedRow = Math.max(0, Math.min(maxRow, focusedRow + dy))
      ensureRowVisible(focusedRow)
      return true
    }
    if (dx !== 0) {
      if (dx < 0) return false
      return true
    }
    return false
  }

  function handleActivate() {
    if (hasActiveInput) return
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
    if (showWifiQrModal) {
      if (key === "q" || key === "Q" || key === "Escape") {
        closeWifiQrModal()
        return true
      }
      return true
    }
    if (hasActiveInput) return false
    if (key === "h" || key === "H") {
      return handleMove(-1, 0)
    } else if (key === "l" || key === "L") {
      return handleMove(1, 0)
    } else if (key === "r" || key === "R") {
      rescan(true)
      return true
    } else if (key === "w" || key === "W") {
      focusedRow = 0
      toggleWifi()
      return true
    } else if (key === "d" || key === "D") {
      disconnectActive()
      return true
    }
    return false
  }

  function refresh() {
    refreshState()
    if (root.wifiEnabled) {
      var now = Date.now()
      if (now - lastScanTime >= 4000) {
        rescan(false)
      }
    }
  }

  function refreshState() {
    if (!stateProcess.running && pluginPath.length > 0) {
      stateProcess.command = [pluginPath + "/scripts/network-control.sh", "get-state"]
      stateProcess.running = true
    }
  }

  function rescan(force) {
    if (!root.wifiEnabled) return
    var now = Date.now()
    if (!force && root.isScanning) return
    if (!force && (now - lastScanTime < 4000)) return
    lastScanTime = now
    root.isScanning = true
    root.wasScanning = true
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
      return
    }
    if (net.requiresPassword && !net.isKnown) {
      if (passwordSsid === net.ssid) {
        cancelPasswordPrompt()
      } else {
        openPasswordPrompt(net.ssid)
      }
      return
    }
    connectToNetwork(net.ssid, "")
  }

  function connectToNetwork(ssid, pass) {
    isConnecting = true
    connectingSsid = ssid
    passwordError = ""
    notifyStatus("Connecting to " + ssid + "...")
    if (pass && pass.length > 0) {
      connectProcess.command = [pluginPath + "/scripts/network-control.sh", "wifi-connect", ssid, pass]
    } else {
      connectProcess.command = [pluginPath + "/scripts/network-control.sh", "wifi-connect", ssid]
    }
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
          if (root.wasScanning) {
            root.wasScanning = false
            root.notifyStatus("Scan complete • " + root.networks.length + " networks found")
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
    onRunningChanged: {
      if (!running) {
        root.refreshState()
        if (root.wifiEnabled) {
          root.rescan(true)
        }
        if (panelRoot && typeof panelRoot.notifySettingChanged === "function") {
          panelRoot.notifySettingChanged()
        }
      }
    }
  }

  // Rescan Process
  Process {
    id: rescanProcess
    onRunningChanged: {
      if (!running) {
        root.isScanning = false
        root.refreshState()
      }
    }
  }

  // Connect Process
  Process {
    id: connectProcess
    stdout: StdioCollector {
      id: connectStdout
      waitForEnd: true
    }
    stderr: StdioCollector {
      id: connectStderr
      waitForEnd: true
    }
    onExited: function(exitCode) {
      root.isConnecting = false
      var outText = String(connectStdout.text || "").trim()
      var errText = String(connectStderr.text || "").trim()
      var res = null
      if (outText.length > 0) {
        try {
          res = JSON.parse(outText)
        } catch (e) {}
      }
      if (exitCode === 0) {
        root.notifyStatus("Connected to " + root.connectingSsid)
        root.cancelPasswordPrompt()
        root.refresh()
        if (panelRoot && typeof panelRoot.notifySettingChanged === "function") {
          panelRoot.notifySettingChanged()
        }
      } else {
        var msg = (res && res.error) ? res.error : (errText || outText || "Connection failed. Please check password.")
        root.passwordError = msg
        root.notifyStatus("Failed: " + msg)
        if (root.passwordSsid === "" && root.connectingSsid !== "") {
          root.openPasswordPrompt(root.connectingSsid)
        }
      }
    }
  }

  // Disconnect Process
  Process {
    id: disconnectProcess
    onRunningChanged: {
      if (!running) {
        root.refresh()
        if (panelRoot && typeof panelRoot.notifySettingChanged === "function") {
          panelRoot.notifySettingChanged()
        }
      }
    }
  }

  // Wi-Fi QR Process
  Process {
    id: wifiQrProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.isLoadingQr = false
        try {
          var res = JSON.parse(text)
          if (res && res.success) {
            root.wifiQrData = res
            root.qrRefreshCounter++
          } else {
            root.notifyStatus((res && res.error) ? res.error : "Could not retrieve Wi-Fi credentials")
            root.closeWifiQrModal()
          }
        } catch (e) {
          root.notifyStatus("Failed to parse Wi-Fi QR data")
          root.closeWifiQrModal()
        }
      }
    }
  }

  // Clipboard Process
  Process {
    id: clipboardProcess
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

      // Wi-Fi Hero Card
      Rectangle {
        id: networkHeroCard
        Layout.fillWidth: true
        implicitHeight: Math.max(76, networkHeroRow.implicitHeight + 28)
        Layout.preferredHeight: implicitHeight
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04)
        border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
        border.width: 1
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
            color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
            border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
            border.width: 1

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
                color: root.activeConnection ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
                border.color: root.activeConnection ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
                border.width: 1

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
                : (root.wifiEnabled ? (root.isScanning ? "Scanning for available wireless networks..." : "Select a network below or press [r] to scan") : "Turn on Wi-Fi interface to discover wireless networks")
              font.family: Style.font.family
              font.pixelSize: Style.font.subtext || 12
              color: Color.muted
            }
          }

          RowLayout {
            spacing: 8

            Button {
              visible: root.activeConnection !== null && (root.activeConnection.ssid || "").length > 0
              text: "Share QR"
              iconText: "󰐲"
              onClicked: root.openWifiQrModal()
            }

            Button {
              text: root.isScanning ? "Scanning..." : "Scan"
              iconText: ""
              enabled: root.wifiEnabled && !root.isScanning
              onClicked: root.rescan(true)
            }
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
        readonly property bool isFocused: root.isContentFocused && root.focusedRow === 0
        readonly property bool isHovered: wifiToggleMouse.containsMouse
        color: {
          if (isFocused) {
            return Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, isHovered ? 0.18 : 0.14)
          }
          if (isHovered) {
            return Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
          }
          return Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02)
        }
        border.color: {
          if (isFocused) return Color.accent
          if (isHovered) return Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28)
          return "transparent"
        }
        border.width: isFocused ? 2 : 1

        MouseArea {
          id: wifiToggleMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (root.panelRoot) root.panelRoot.focusSection = "content"
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
            color: root.wifiEnabled ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
            border.color: root.wifiEnabled ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.30) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
            border.width: 1

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
              text: root.wifiEnabled ? (root.isScanning ? "Wireless network interface is active and scanning..." : "Wireless network interface is active.") : "Wireless radio is switched off."
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
            color: root.wifiEnabled ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
            border.color: root.wifiEnabled ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
            border.width: 1

            Text {
              anchors.centerIn: parent
              text: root.wifiEnabled ? "ENABLED" : "DISABLED"
              font.family: Style.font.family
              font.pixelSize: 11
              font.bold: true
              color: root.wifiEnabled ? Color.accent : Color.muted
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
            readonly property bool isPasswordOpen: root.passwordSsid !== "" && root.passwordSsid === modelData.ssid
            property alias passwordField: passwordInput

            onIsPasswordOpenChanged: {
              if (isPasswordOpen) {
                root.activePasswordInput = passwordInput
                root.activeShowPwBtn = showPwBtn
                root.activeConnectBtn = connectBtn
                root.activeCancelBtn = cancelBtn
                root.promptFocusIndex = 0
                Qt.callLater(function() {
                  if (passwordInput) passwordInput.forceActiveFocus()
                })
              }
            }

            Component.onCompleted: {
              if (isPasswordOpen) {
                root.activePasswordInput = passwordInput
                root.activeShowPwBtn = showPwBtn
                root.activeConnectBtn = connectBtn
                root.activeCancelBtn = cancelBtn
                root.promptFocusIndex = 0
                Qt.callLater(function() {
                  if (passwordInput) passwordInput.forceActiveFocus()
                })
              }
            }

            implicitHeight: Math.max(52, cardColumn.implicitHeight + 16)
            Layout.preferredHeight: implicitHeight
            radius: Style.cornerRadius || 6
            readonly property bool isActive: (modelData.inUse === true)
            readonly property bool isFocused: root.isContentFocused && root.focusedRow === (index + 1)
            readonly property bool isHovered: netMouseArea.containsMouse

            color: {
              if (delegateCard.isFocused) {
                if (isActive) return Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, isHovered ? 0.28 : 0.24)
                return Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, isHovered ? 0.18 : 0.14)
              }
              if (isActive) return Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, isHovered ? 0.28 : 0.20)
              if (isHovered) return Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
              return Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02)
            }
            border.color: {
              if (delegateCard.isFocused || delegateCard.isPasswordOpen) return Color.accent
              if (isActive) return Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60)
              if (isHovered) return Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28)
              return "transparent"
            }
            border.width: (delegateCard.isFocused || delegateCard.isPasswordOpen) ? 2 : 1

            // Clickable header area for toggling connection or password prompt
            MouseArea {
              id: netMouseArea
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.right: parent.right
              height: Math.max(48, delegateRowLayout.implicitHeight + 16)
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (root.panelRoot) root.panelRoot.focusSection = "content"
                root.focusedRow = index + 1
                root.toggleNetwork(modelData)
              }
            }

            ColumnLayout {
              id: cardColumn
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.margins: 8
              anchors.leftMargin: 14
              anchors.rightMargin: 14
              spacing: 10

              RowLayout {
                id: delegateRowLayout
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                  visible: delegateCard.isActive
                  width: 5
                  height: 5
                  radius: 2.5
                  color: Color.accent
                }

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

                    Text {
                      visible: modelData.isKnown && !modelData.inUse
                      text: "• Saved Profile"
                      font.family: Style.font.family
                      font.pixelSize: 10
                      color: Color.accent
                    }
                  }
                }

                // Key / Password button for protected networks
                Rectangle {
                  visible: modelData.requiresPassword && !modelData.inUse
                  width: 28
                  height: 28
                  Layout.preferredWidth: 28
                  Layout.preferredHeight: 28
                  radius: 14
                  color: keyBtnMouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : "transparent"
                  border.color: delegateCard.isPasswordOpen ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
                  border.width: 1

                  Text {
                    anchors.centerIn: parent
                    text: "󰌾"
                    font.family: Style.font.family
                    font.pixelSize: 12
                    color: delegateCard.isPasswordOpen ? Color.accent : Color.muted
                  }

                  MouseArea {
                    id: keyBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      if (root.panelRoot) root.panelRoot.focusSection = "content"
                      root.focusedRow = index + 1
                      if (delegateCard.isPasswordOpen) {
                        root.cancelPasswordPrompt()
                      } else {
                        root.openPasswordPrompt(modelData.ssid)
                      }
                    }
                  }
                }

                // QR Share button for active or saved network
                Rectangle {
                  visible: modelData.inUse || modelData.isKnown
                  width: 28
                  height: 28
                  Layout.preferredWidth: 28
                  Layout.preferredHeight: 28
                  radius: 14
                  color: qrBtnMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04)
                  border.color: qrBtnMouse.containsMouse ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
                  border.width: 1

                  Text {
                    anchors.centerIn: parent
                    text: "󰐲"
                    font.family: Style.font.family
                    font.pixelSize: 13
                    color: qrBtnMouse.containsMouse ? Color.accent : Color.foreground
                  }

                  MouseArea {
                    id: qrBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      root.openWifiQrModal(modelData.ssid)
                    }
                  }
                }

                // Action / Status Pill
                Rectangle {
                  width: modelData.inUse ? 96 : (delegateCard.isPasswordOpen ? 76 : (modelData.isKnown ? 80 : 84))
                  height: 28
                  Layout.preferredWidth: width
                  Layout.preferredHeight: 28
                  radius: 14
                  color: {
                    if (modelData.inUse) {
                      return Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
                    }
                    if (delegateCard.isFocused) {
                      return Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.14)
                    }
                    return Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04)
                  }
                  border.color: {
                    if (delegateCard.isFocused) return Color.accent
                    if (modelData.inUse) return Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60)
                    return Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12)
                  }
                  border.width: 1

                  Text {
                    anchors.centerIn: parent
                    text: {
                      if (modelData.inUse) return "✓ CONNECTED"
                      if (delegateCard.isPasswordOpen) return "CLOSE"
                      if (delegateCard.isFocused) return "⏎ CONNECT"
                      if (modelData.isKnown) return "CONNECT"
                      return "CONNECT"
                    }
                    font.family: Style.font.family
                    font.pixelSize: 10
                    font.bold: modelData.inUse || delegateCard.isFocused
                    color: modelData.inUse ? Color.accent : (delegateCard.isFocused ? Color.foreground : Color.muted)
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      if (root.panelRoot) root.panelRoot.focusSection = "content"
                      root.focusedRow = index + 1
                      root.toggleNetwork(modelData)
                    }
                  }
                }
              }

              // Inline Password Entry Section
              ColumnLayout {
                id: passwordSection
                visible: delegateCard.isPasswordOpen
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                  Layout.fillWidth: true
                  height: 1
                  color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
                  opacity: 0.5
                }

                RowLayout {
                  Layout.fillWidth: true
                  spacing: 10

                  // Password Input Box
                  Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: 6
                    color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.05)
                    border.color: (passwordInput.activeFocus || root.promptFocusIndex === 0) ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
                    border.width: (passwordInput.activeFocus || root.promptFocusIndex === 0) ? 2 : 1

                    RowLayout {
                      anchors.fill: parent
                      anchors.leftMargin: 10
                      anchors.rightMargin: 6
                      spacing: 8

                      Text {
                        text: "󰌾"
                        font.family: Style.font.family
                        font.pixelSize: 14
                        color: (passwordInput.activeFocus || root.promptFocusIndex === 0) ? Color.accent : Color.muted
                      }

                      TextField {
                        id: passwordInput
                        Layout.fillWidth: true
                        placeholderText: "Enter Wi-Fi password for " + modelData.ssid + "... [Enter]"
                        placeholderTextColor: Color.muted
                        color: Color.foreground
                        font.family: Style.font.family
                        font.pixelSize: 12
                        echoMode: root.showPasswordText ? TextInput.Normal : TextInput.Password
                        background: Item {}
                        text: root.passwordText
                        enabled: !root.isConnecting

                        onTextChanged: {
                          if (delegateCard.isPasswordOpen && root.passwordText !== text) {
                            root.passwordText = text
                          }
                        }

                        onActiveFocusChanged: {
                          if (activeFocus && delegateCard.isPasswordOpen) {
                            root.promptFocusIndex = 0
                          }
                        }

                        onAccepted: root.submitPasswordConnect()

                        Keys.onTabPressed: function(event) {
                          event.accepted = true
                          root.setPromptFocus(1)
                        }

                        Keys.onBacktabPressed: function(event) {
                          event.accepted = true
                          root.setPromptFocus(3)
                        }

                        Keys.onDownPressed: function(event) {
                          event.accepted = true
                          root.setPromptFocus(2) // Jump directly to Connect button
                        }

                        Keys.onEscapePressed: function(event) {
                          event.accepted = true
                          root.cancelPasswordPrompt()
                          if (root.panelRoot && typeof root.panelRoot.returnFocusToKeyCatcher === "function") {
                            root.panelRoot.returnFocusToKeyCatcher()
                          }
                        }

                        Keys.onPressed: function(event) {
                          if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_H || event.key === Qt.Key_P)) {
                            event.accepted = true
                            root.showPasswordText = !root.showPasswordText
                          }
                        }
                      }

                      // Show / Hide Password Button
                      Rectangle {
                        id: showPwBtn
                        width: 28
                        height: 28
                        radius: 4
                        focus: root.promptFocusIndex === 1
                        color: (root.promptFocusIndex === 1 || showPwMouse.containsMouse)
                          ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
                          : "transparent"
                        border.color: (root.promptFocusIndex === 1) ? Color.accent : "transparent"
                        border.width: (root.promptFocusIndex === 1) ? 2 : 0

                        Text {
                          anchors.centerIn: parent
                          text: root.showPasswordText ? "󰈈" : "󰈉"
                          font.family: Style.font.family
                          font.pixelSize: 14
                          color: (root.showPasswordText || root.promptFocusIndex === 1) ? Color.accent : Color.muted
                        }

                        MouseArea {
                          id: showPwMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            root.setPromptFocus(1)
                            root.showPasswordText = !root.showPasswordText
                          }
                        }

                        Keys.onTabPressed: function(event) {
                          event.accepted = true
                          root.setPromptFocus(2)
                        }

                        Keys.onBacktabPressed: function(event) {
                          event.accepted = true
                          root.setPromptFocus(0)
                        }

                        Keys.onLeftPressed: function(event) {
                          event.accepted = true
                          root.setPromptFocus(0)
                        }

                        Keys.onRightPressed: function(event) {
                          event.accepted = true
                          root.setPromptFocus(2)
                        }

                        Keys.onUpPressed: function(event) {
                          event.accepted = true
                          root.setPromptFocus(0)
                        }

                        Keys.onDownPressed: function(event) {
                          event.accepted = true
                          root.setPromptFocus(2)
                        }

                        Keys.onReturnPressed: function(event) {
                          event.accepted = true
                          root.showPasswordText = !root.showPasswordText
                        }

                        Keys.onEnterPressed: function(event) {
                          event.accepted = true
                          root.showPasswordText = !root.showPasswordText
                        }

                        Keys.onSpacePressed: function(event) {
                          event.accepted = true
                          root.showPasswordText = !root.showPasswordText
                        }

                        Keys.onEscapePressed: function(event) {
                          event.accepted = true
                          root.cancelPasswordPrompt()
                          if (root.panelRoot && typeof root.panelRoot.returnFocusToKeyCatcher === "function") {
                            root.panelRoot.returnFocusToKeyCatcher()
                          }
                        }
                      }
                    }
                  }

                  // Connect Button
                  Rectangle {
                    id: connectBtn
                    Layout.preferredWidth: 84
                    Layout.preferredHeight: 36
                    radius: 6
                    focus: root.promptFocusIndex === 2
                    color: (root.passwordText.length > 0 && !root.isConnecting)
                      ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25)
                      : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.05)
                    opacity: (root.passwordText.length > 0 && !root.isConnecting) ? 1.0 : 0.6
                    border.color: (root.promptFocusIndex === 2)
                      ? Color.accent
                      : ((root.passwordText.length > 0 && !root.isConnecting) ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60) : "transparent")
                    border.width: (root.promptFocusIndex === 2) ? 2 : 1

                    Text {
                      anchors.centerIn: parent
                      text: root.isConnecting ? "Connecting..." : "Connect"
                      font.family: Style.font.family
                      font.pixelSize: 11
                      font.bold: true
                      color: (root.passwordText.length > 0 && !root.isConnecting) ? Color.accent : Color.muted
                    }

                    MouseArea {
                      id: connectMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      enabled: root.passwordText.length > 0 && !root.isConnecting
                      cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                      onClicked: {
                        root.setPromptFocus(2)
                        root.submitPasswordConnect()
                      }
                    }

                    Keys.onTabPressed: function(event) {
                      event.accepted = true
                      root.setPromptFocus(3)
                    }

                    Keys.onBacktabPressed: function(event) {
                      event.accepted = true
                      root.setPromptFocus(1)
                    }

                    Keys.onLeftPressed: function(event) {
                      event.accepted = true
                      root.setPromptFocus(1)
                    }

                    Keys.onRightPressed: function(event) {
                      event.accepted = true
                      root.setPromptFocus(3)
                    }

                    Keys.onUpPressed: function(event) {
                      event.accepted = true
                      root.setPromptFocus(0)
                    }

                    Keys.onDownPressed: function(event) {
                      event.accepted = true
                      root.setPromptFocus(3)
                    }

                    Keys.onReturnPressed: function(event) {
                      event.accepted = true
                      root.submitPasswordConnect()
                    }

                    Keys.onEnterPressed: function(event) {
                      event.accepted = true
                      root.submitPasswordConnect()
                    }

                    Keys.onSpacePressed: function(event) {
                      event.accepted = true
                      root.submitPasswordConnect()
                    }

                    Keys.onEscapePressed: function(event) {
                      event.accepted = true
                      root.cancelPasswordPrompt()
                      if (root.panelRoot && typeof root.panelRoot.returnFocusToKeyCatcher === "function") {
                        root.panelRoot.returnFocusToKeyCatcher()
                      }
                    }
                  }

                  // Cancel Button
                  Rectangle {
                    id: cancelBtn
                    Layout.preferredWidth: 70
                    Layout.preferredHeight: 36
                    radius: 6
                    focus: root.promptFocusIndex === 3
                    color: (root.promptFocusIndex === 3)
                      ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.14)
                      : (cancelMouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.03))
                    border.color: (root.promptFocusIndex === 3) ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
                    border.width: (root.promptFocusIndex === 3) ? 2 : 1

                    Text {
                      anchors.centerIn: parent
                      text: "Cancel"
                      font.family: Style.font.family
                      font.pixelSize: 11
                      color: (root.promptFocusIndex === 3) ? Color.accent : Color.muted
                    }

                    MouseArea {
                      id: cancelMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        root.setPromptFocus(3)
                        root.cancelPasswordPrompt()
                        if (root.panelRoot && typeof root.panelRoot.returnFocusToKeyCatcher === "function") {
                          root.panelRoot.returnFocusToKeyCatcher()
                        }
                      }
                    }

                    Keys.onTabPressed: function(event) {
                      event.accepted = true
                      root.setPromptFocus(0)
                    }

                    Keys.onBacktabPressed: function(event) {
                      event.accepted = true
                      root.setPromptFocus(2)
                    }

                    Keys.onLeftPressed: function(event) {
                      event.accepted = true
                      root.setPromptFocus(2)
                    }

                    Keys.onRightPressed: function(event) {
                      event.accepted = true
                      root.setPromptFocus(0)
                    }

                    Keys.onUpPressed: function(event) {
                      event.accepted = true
                      root.setPromptFocus(0)
                    }

                    Keys.onDownPressed: function(event) {
                      event.accepted = true
                      root.setPromptFocus(0)
                    }

                    Keys.onReturnPressed: function(event) {
                      event.accepted = true
                      root.cancelPasswordPrompt()
                      if (root.panelRoot && typeof root.panelRoot.returnFocusToKeyCatcher === "function") {
                        root.panelRoot.returnFocusToKeyCatcher()
                      }
                    }

                    Keys.onEnterPressed: function(event) {
                      event.accepted = true
                      root.cancelPasswordPrompt()
                      if (root.panelRoot && typeof root.panelRoot.returnFocusToKeyCatcher === "function") {
                        root.panelRoot.returnFocusToKeyCatcher()
                      }
                    }

                    Keys.onSpacePressed: function(event) {
                      event.accepted = true
                      root.cancelPasswordPrompt()
                      if (root.panelRoot && typeof root.panelRoot.returnFocusToKeyCatcher === "function") {
                        root.panelRoot.returnFocusToKeyCatcher()
                      }
                    }

                    Keys.onEscapePressed: function(event) {
                      event.accepted = true
                      root.cancelPasswordPrompt()
                      if (root.panelRoot && typeof root.panelRoot.returnFocusToKeyCatcher === "function") {
                        root.panelRoot.returnFocusToKeyCatcher()
                      }
                    }
                  }
                }

                // Error message if connection failed
                RowLayout {
                  Layout.fillWidth: true
                  visible: root.passwordError.length > 0
                  spacing: 6

                  Text {
                    text: "⚠ " + root.passwordError
                    font.family: Style.font.family
                    font.pixelSize: 11
                    color: Color.urgent || "#e06c75"
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
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

  // Wi-Fi QR Code Sharing Modal Overlay
  Rectangle {
    id: wifiQrModalOverlay
    anchors.fill: parent
    visible: root.showWifiQrModal
    z: 200
    color: Qt.rgba(0, 0, 0, 0.65)

    MouseArea {
      anchors.fill: parent
      onClicked: root.closeWifiQrModal()
    }

    Rectangle {
      id: qrModalCard
      anchors.centerIn: parent
      width: Math.min(380, root.width - 32)
      implicitHeight: qrModalContent.implicitHeight + 36
      radius: Style.cornerRadius || 10
      color: Qt.rgba(Color.background.r, Color.background.g, Color.background.b, 0.98)
      border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
      border.width: 1

      MouseArea {
        anchors.fill: parent
      }

      ColumnLayout {
        id: qrModalContent
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 18
        spacing: 14

        // Header
        RowLayout {
          Layout.fillWidth: true
          spacing: 10

          Rectangle {
            width: 32
            height: 32
            radius: 6
            color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15)
            border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3)
            border.width: 1

            Text {
              anchors.centerIn: parent
              text: "󰐲"
              font.family: Style.font.family
              font.pixelSize: 16
              color: Color.accent
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Text {
              text: "Share Wi-Fi Network"
              font.family: Style.font.family
              font.pixelSize: 14
              font.bold: true
              color: Color.foreground
            }

            Text {
              text: "Scan with a mobile phone or tablet to connect"
              font.family: Style.font.family
              font.pixelSize: 11
              color: Color.muted
            }
          }

          Rectangle {
            width: 26
            height: 26
            radius: 4
            color: closeQrMouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12) : "transparent"

            Text {
              anchors.centerIn: parent
              text: "✕"
              font.family: Style.font.family
              font.pixelSize: 12
              color: Color.muted
            }

            MouseArea {
              id: closeQrMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.closeWifiQrModal()
            }
          }
        }

        // QR Code Display Container
        Rectangle {
          Layout.alignment: Qt.AlignHCenter
          width: 184
          height: 184
          radius: 8
          color: "#FFFFFF"
          border.color: Qt.rgba(0, 0, 0, 0.12)
          border.width: 1

          Image {
            id: qrImg
            anchors.centerIn: parent
            width: 164
            height: 164
            fillMode: Image.PreserveAspectFit
            smooth: false
            source: (root.wifiQrData && root.wifiQrData.hasQr && root.wifiQrData.qrPath)
              ? ("file://" + root.wifiQrData.qrPath + "?t=" + root.qrRefreshCounter)
              : ""
            visible: !root.isLoadingQr && root.wifiQrData && root.wifiQrData.hasQr
          }

          ColumnLayout {
            anchors.centerIn: parent
            visible: root.isLoadingQr || !root.wifiQrData || !root.wifiQrData.hasQr
            spacing: 6

            Text {
              Layout.alignment: Qt.AlignHCenter
              text: root.isLoadingQr ? "󰑮" : "󰌾"
              font.family: Style.font.family
              font.pixelSize: 24
              color: "#333333"
            }

            Text {
              Layout.alignment: Qt.AlignHCenter
              text: root.isLoadingQr ? "Generating QR..." : "QR Unavailable"
              font.family: Style.font.family
              font.pixelSize: 11
              color: "#555555"
            }
          }
        }

        // Credentials details container
        Rectangle {
          Layout.fillWidth: true
          implicitHeight: detailsCol.implicitHeight + 16
          radius: 6
          color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04)
          border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
          border.width: 1

          ColumnLayout {
            id: detailsCol
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            // SSID Row
            RowLayout {
              Layout.fillWidth: true
              spacing: 8

              Text {
                text: "SSID:"
                font.family: Style.font.family
                font.pixelSize: 11
                font.bold: true
                color: Color.muted
                Layout.preferredWidth: 60
              }

              Text {
                Layout.fillWidth: true
                text: root.wifiQrData ? root.wifiQrData.ssid : ""
                font.family: Style.font.family
                font.pixelSize: 12
                font.bold: true
                color: Color.foreground
                elide: Text.ElideRight
              }

              Rectangle {
                width: 58
                height: 22
                radius: 4
                color: copySsidMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06)
                border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12)
                border.width: 1

                RowLayout {
                  anchors.centerIn: parent
                  spacing: 3
                  Text { text: "󰆏"; font.family: Style.font.family; font.pixelSize: 10; color: Color.foreground }
                  Text { text: "Copy"; font.family: Style.font.family; font.pixelSize: 10; color: Color.foreground }
                }

                MouseArea {
                  id: copySsidMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.copyToClipboard(root.wifiQrData ? root.wifiQrData.ssid : "", "SSID copied!")
                }
              }
            }

            // Password Row
            RowLayout {
              Layout.fillWidth: true
              spacing: 8

              Text {
                text: "Password:"
                font.family: Style.font.family
                font.pixelSize: 11
                font.bold: true
                color: Color.muted
                Layout.preferredWidth: 60
              }

              Text {
                Layout.fillWidth: true
                text: (root.wifiQrData && root.wifiQrData.password) ? root.wifiQrData.password : "(Open / No password)"
                font.family: Style.font.family
                font.pixelSize: 12
                font.bold: true
                color: (root.wifiQrData && root.wifiQrData.password) ? Color.accent : Color.muted
                elide: Text.ElideRight
              }

              Rectangle {
                visible: root.wifiQrData && (root.wifiQrData.password || "").length > 0
                width: 58
                height: 22
                radius: 4
                color: copyPassMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06)
                border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12)
                border.width: 1

                RowLayout {
                  anchors.centerIn: parent
                  spacing: 3
                  Text { text: "󰆏"; font.family: Style.font.family; font.pixelSize: 10; color: Color.foreground }
                  Text { text: "Copy"; font.family: Style.font.family; font.pixelSize: 10; color: Color.foreground }
                }

                MouseArea {
                  id: copyPassMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.copyToClipboard(root.wifiQrData ? root.wifiQrData.password : "", "Password copied!")
                }
              }
            }
          }
        }

        // Close button
        Button {
          Layout.alignment: Qt.AlignHCenter
          text: "Done"
          iconText: "✓"
          onClicked: root.closeWifiQrModal()
        }
      }
    }
  }
}
