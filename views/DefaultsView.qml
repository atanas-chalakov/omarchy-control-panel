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
  property bool activeFocusSection: false
  property int focusedCard: 0 // 0: Browser, 1: Editor, 2: Terminal, 3: File Manager
  onFocusedCardChanged: ensureCardVisible(focusedCard)

  function ensureCardVisible(index) {
    if (!scrollArea || !scrollArea.contentItem) return
    var targets = [browserCard, editorCard, terminalCard, fileManagerCard]
    if (index >= 0 && index < targets.length) {
      var item = targets[index]
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
  }

  property string statusMessage: ""

  // State properties
  property string currentBrowser: "chromium.desktop"
  property var installedBrowsers: []

  property string currentEditor: "nvim"
  property var installedEditors: []

  property string currentTerminal: "Alacritty.desktop"
  property var installedTerminals: []

  property string currentFileManager: "org.gnome.Nautilus.desktop"
  property var installedFileManagers: []

  function currentBrowserIndex() {
    for (var i = 0; i < installedBrowsers.length; i++) {
      if (installedBrowsers[i].id === root.currentBrowser) return i
    }
    return 0
  }

  function currentEditorIndex() {
    for (var i = 0; i < installedEditors.length; i++) {
      if (installedEditors[i].code === root.currentEditor || installedEditors[i].id === root.currentEditor) return i
    }
    return 0
  }

  function currentTerminalIndex() {
    for (var i = 0; i < installedTerminals.length; i++) {
      if (installedTerminals[i].id === root.currentTerminal) return i
    }
    return 0
  }

  function currentFileManagerIndex() {
    for (var i = 0; i < installedFileManagers.length; i++) {
      if (installedFileManagers[i].id === root.currentFileManager) return i
    }
    return 0
  }

  function cycleBrowser(delta) {
    if (installedBrowsers.length === 0) return
    var idx = currentBrowserIndex()
    var next = (idx + delta + installedBrowsers.length) % installedBrowsers.length
    setBrowser(installedBrowsers[next].id, installedBrowsers[next].name)
  }

  function cycleEditor(delta) {
    if (installedEditors.length === 0) return
    var idx = currentEditorIndex()
    var next = (idx + delta + installedEditors.length) % installedEditors.length
    setEditor(installedEditors[next].code, installedEditors[next].id, installedEditors[next].name)
  }

  function cycleTerminal(delta) {
    if (installedTerminals.length === 0) return
    var idx = currentTerminalIndex()
    var next = (idx + delta + installedTerminals.length) % installedTerminals.length
    setTerminal(installedTerminals[next].id, installedTerminals[next].name)
  }

  function cycleFileManager(delta) {
    if (installedFileManagers.length === 0) return
    var idx = currentFileManagerIndex()
    var next = (idx + delta + installedFileManagers.length) % installedFileManagers.length
    setFileManager(installedFileManagers[next].id, installedFileManagers[next].name)
  }

  function refresh() {
    if (!stateProcess.running && pluginPath.length > 0) {
      stateProcess.command = [pluginPath + "/scripts/defaults-control.sh", "get-state"]
      stateProcess.running = true
    }
  }

  function setBrowser(desktopId, name) {
    root.currentBrowser = desktopId
    actionProcess.command = [pluginPath + "/scripts/defaults-control.sh", "set-browser", desktopId]
    actionProcess.running = true
    notifyStatus("Default Browser: " + (name || desktopId))
  }

  function setEditor(code, desktopId, name) {
    root.currentEditor = code
    actionProcess.command = [pluginPath + "/scripts/defaults-control.sh", "set-editor", code, desktopId]
    actionProcess.running = true
    notifyStatus("Default Editor: " + (name || code))
  }

  function setTerminal(desktopId, name) {
    root.currentTerminal = desktopId
    actionProcess.command = [pluginPath + "/scripts/defaults-control.sh", "set-terminal", desktopId]
    actionProcess.running = true
    notifyStatus("Default Terminal: " + (name || desktopId))
  }

  function setFileManager(desktopId, name) {
    root.currentFileManager = desktopId
    actionProcess.command = [pluginPath + "/scripts/defaults-control.sh", "set-file-manager", desktopId]
    actionProcess.running = true
    notifyStatus("Default File Manager: " + (name || desktopId))
  }

  function launchApp(kind) {
    actionProcess.command = [pluginPath + "/scripts/defaults-control.sh", "launch-app", kind]
    actionProcess.running = true
    notifyStatus("Launching " + kind + "...")
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

  function handleMove(dx, dy) {
    if (dy !== 0) {
      focusedCard = Math.max(0, Math.min(3, focusedCard + dy))
      ensureCardVisible(focusedCard)
      return true
    } else if (dx !== 0) {
      if (focusedCard === 0) cycleBrowser(dx)
      else if (focusedCard === 1) cycleEditor(dx)
      else if (focusedCard === 2) cycleTerminal(dx)
      else if (focusedCard === 3) cycleFileManager(dx)
      return true
    }
    return false
  }

  function handleActivate() {
    if (focusedCard === 0) cycleBrowser(1)
    else if (focusedCard === 1) cycleEditor(1)
    else if (focusedCard === 2) cycleTerminal(1)
    else if (focusedCard === 3) cycleFileManager(1)
  }

  function handleTextKey(key) {
    var k = key.toLowerCase()
    if (k === "b") {
      focusedCard = 0
      cycleBrowser(1)
    } else if (k === "e") {
      focusedCard = 1
      cycleEditor(1)
    } else if (k === "t") {
      focusedCard = 2
      cycleTerminal(1)
    } else if (k === "f") {
      focusedCard = 3
      cycleFileManager(1)
    } else if (k === "r") {
      refresh()
      notifyStatus("Refreshed default applications")
    }
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
          if (data.browser) {
            if (data.browser.current) root.currentBrowser = String(data.browser.current)
            if (Array.isArray(data.browser.installed)) root.installedBrowsers = data.browser.installed
          }
          if (data.editor) {
            if (data.editor.current) root.currentEditor = String(data.editor.current)
            if (Array.isArray(data.editor.installed)) root.installedEditors = data.editor.installed
          }
          if (data.terminal) {
            if (data.terminal.current) root.currentTerminal = String(data.terminal.current)
            if (Array.isArray(data.terminal.installed)) root.installedTerminals = data.terminal.installed
          }
          if (data.fileManager) {
            if (data.fileManager.current) root.currentFileManager = String(data.fileManager.current)
            if (Array.isArray(data.fileManager.installed)) root.installedFileManagers = data.fileManager.installed
          }
        } catch (e) {}
      }
    }
  }

  // Action Process
  Process {
    id: actionProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var data = JSON.parse(text)
          if (data.browser && data.browser.current) root.currentBrowser = String(data.browser.current)
          if (data.editor && data.editor.current) root.currentEditor = String(data.editor.current)
          if (data.terminal && data.terminal.current) root.currentTerminal = String(data.terminal.current)
          if (data.fileManager && data.fileManager.current) root.currentFileManager = String(data.fileManager.current)
        } catch (e) {}
        if (panelRoot && typeof panelRoot.notifySettingChanged === "function") {
          panelRoot.notifySettingChanged()
        }
      }
    }
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

      // Card 1: Default Web Browser
      Rectangle {
        id: browserCard
        Layout.fillWidth: true
        Layout.preferredHeight: 124
        color: Color.pickAlpha("surface.subtle", "#181b1d")
        radius: Style.cornerRadius || 8
        border.color: (root.activeFocusSection && root.focusedCard === 0) ? Color.accent : "transparent"
        border.width: (root.activeFocusSection && root.focusedCard === 0) ? 1 : 0

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 12
          spacing: 8

          RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
              text: "󰖟"
              font.family: Style.font.family
              font.pixelSize: 18
              color: Color.accent
            }

            Text {
              text: "Default Web Browser"
              font.family: Style.font.family
              font.pixelSize: Style.font.subtitle || 14
              font.bold: true
              color: Color.foreground
            }

            Item { Layout.fillWidth: true }

            Rectangle {
              width: 18
              height: 18
              radius: 3
              color: Color.pickAlpha("surface.selected", "#2a3036")
              Text {
                anchors.centerIn: parent
                text: "B"
                font.family: Style.font.family
                font.pixelSize: 10
                color: Color.muted
              }
            }

            Button {
              text: "Launch"
              implicitWidth: 64
              implicitHeight: 24
              bordered: true
              onClicked: root.launchApp("browser")
            }
          }

          Text {
            Layout.fillWidth: true
            text: "Handles web links, authentication sign-ins, and browser web applications"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.muted
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
              model: root.installedBrowsers

              delegate: Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: 6
                readonly property bool isSelected: root.currentBrowser === modelData.id
                color: isSelected ? Color.pickAlpha("accent.subtle", "#1f3b30") : Color.pickAlpha("surface.hover", "#1b1f23")
                border.color: isSelected ? Color.accent : "transparent"
                border.width: isSelected ? 1 : 0

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.focusedCard = 0
                    root.setBrowser(modelData.id, modelData.name)
                  }
                }

                RowLayout {
                  anchors.centerIn: parent
                  spacing: 6

                  Text {
                    text: modelData.icon
                    font.family: Style.font.family
                    font.pixelSize: 14
                    color: isSelected ? Color.accent : Color.foreground
                  }

                  Text {
                    text: modelData.name
                    font.family: Style.font.family
                    font.pixelSize: 12
                    font.bold: isSelected
                    color: isSelected ? Color.accent : Color.foreground
                  }

                  Rectangle {
                    visible: isSelected
                    width: 12
                    height: 12
                    radius: 6
                    color: Color.accent
                  }
                }
              }
            }
          }
        }
      }

      // Card 2: Default Code Editor
      Rectangle {
        id: editorCard
        Layout.fillWidth: true
        Layout.preferredHeight: 124
        color: Color.pickAlpha("surface.subtle", "#181b1d")
        radius: Style.cornerRadius || 8
        border.color: (root.activeFocusSection && root.focusedCard === 1) ? Color.accent : "transparent"
        border.width: (root.activeFocusSection && root.focusedCard === 1) ? 1 : 0

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 12
          spacing: 8

          RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
              text: "󰨞"
              font.family: Style.font.family
              font.pixelSize: 18
              color: Color.accent
            }

            Text {
              text: "Default Code Editor"
              font.family: Style.font.family
              font.pixelSize: Style.font.subtitle || 14
              font.bold: true
              color: Color.foreground
            }

            Item { Layout.fillWidth: true }

            Rectangle {
              width: 18
              height: 18
              radius: 3
              color: Color.pickAlpha("surface.selected", "#2a3036")
              Text {
                anchors.centerIn: parent
                text: "E"
                font.family: Style.font.family
                font.pixelSize: 10
                color: Color.muted
              }
            }

            Button {
              text: "Launch"
              implicitWidth: 64
              implicitHeight: 24
              bordered: true
              onClicked: root.launchApp("editor")
            }
          }

          Text {
            Layout.fillWidth: true
            text: "Launched by Super + E, git commit editor, and configuration file editing"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.muted
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
              model: root.installedEditors

              delegate: Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: 6
                readonly property bool isSelected: root.currentEditor === modelData.code || root.currentEditor === modelData.id
                color: isSelected ? Color.pickAlpha("accent.subtle", "#1f3b30") : Color.pickAlpha("surface.hover", "#1b1f23")
                border.color: isSelected ? Color.accent : "transparent"
                border.width: isSelected ? 1 : 0

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.focusedCard = 1
                    root.setEditor(modelData.code, modelData.id, modelData.name)
                  }
                }

                RowLayout {
                  anchors.centerIn: parent
                  spacing: 6

                  Text {
                    text: modelData.icon
                    font.family: Style.font.family
                    font.pixelSize: 14
                    color: isSelected ? Color.accent : Color.foreground
                  }

                  Text {
                    text: modelData.name
                    font.family: Style.font.family
                    font.pixelSize: 12
                    font.bold: isSelected
                    color: isSelected ? Color.accent : Color.foreground
                  }

                  Rectangle {
                    visible: isSelected
                    width: 12
                    height: 12
                    radius: 6
                    color: Color.accent
                  }
                }
              }
            }
          }
        }
      }

      // Card 3: Default Terminal Emulator
      Rectangle {
        id: terminalCard
        Layout.fillWidth: true
        Layout.preferredHeight: 124
        color: Color.pickAlpha("surface.subtle", "#181b1d")
        radius: Style.cornerRadius || 8
        border.color: (root.activeFocusSection && root.focusedCard === 2) ? Color.accent : "transparent"
        border.width: (root.activeFocusSection && root.focusedCard === 2) ? 1 : 0

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 12
          spacing: 8

          RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
              text: ""
              font.family: Style.font.family
              font.pixelSize: 18
              color: Color.accent
            }

            Text {
              text: "Default Terminal Emulator"
              font.family: Style.font.family
              font.pixelSize: Style.font.subtitle || 14
              font.bold: true
              color: Color.foreground
            }

            Item { Layout.fillWidth: true }

            Rectangle {
              width: 18
              height: 18
              radius: 3
              color: Color.pickAlpha("surface.selected", "#2a3036")
              Text {
                anchors.centerIn: parent
                text: "T"
                font.family: Style.font.family
                font.pixelSize: 10
                color: Color.muted
              }
            }

            Button {
              text: "Launch"
              implicitWidth: 64
              implicitHeight: 24
              bordered: true
              onClicked: root.launchApp("terminal")
            }
          }

          Text {
            Layout.fillWidth: true
            text: "Launched by Super + Return and system terminal execution (xdg-terminal-exec)"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.muted
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
              model: root.installedTerminals

              delegate: Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: 6
                readonly property bool isSelected: root.currentTerminal === modelData.id
                color: isSelected ? Color.pickAlpha("accent.subtle", "#1f3b30") : Color.pickAlpha("surface.hover", "#1b1f23")
                border.color: isSelected ? Color.accent : "transparent"
                border.width: isSelected ? 1 : 0

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.focusedCard = 2
                    root.setTerminal(modelData.id, modelData.name)
                  }
                }

                RowLayout {
                  anchors.centerIn: parent
                  spacing: 6

                  Text {
                    text: modelData.icon
                    font.family: Style.font.family
                    font.pixelSize: 14
                    color: isSelected ? Color.accent : Color.foreground
                  }

                  Text {
                    text: modelData.name
                    font.family: Style.font.family
                    font.pixelSize: 12
                    font.bold: isSelected
                    color: isSelected ? Color.accent : Color.foreground
                  }

                  Rectangle {
                    visible: isSelected
                    width: 12
                    height: 12
                    radius: 6
                    color: Color.accent
                  }
                }
              }
            }
          }
        }
      }

      // Card 4: Default File Manager
      Rectangle {
        id: fileManagerCard
        Layout.fillWidth: true
        Layout.preferredHeight: 124
        color: Color.pickAlpha("surface.subtle", "#181b1d")
        radius: Style.cornerRadius || 8
        border.color: (root.activeFocusSection && root.focusedCard === 3) ? Color.accent : "transparent"
        border.width: (root.activeFocusSection && root.focusedCard === 3) ? 1 : 0

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 12
          spacing: 8

          RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
              text: ""
              font.family: Style.font.family
              font.pixelSize: 18
              color: Color.accent
            }

            Text {
              text: "Default File Manager"
              font.family: Style.font.family
              font.pixelSize: Style.font.subtitle || 14
              font.bold: true
              color: Color.foreground
            }

            Item { Layout.fillWidth: true }

            Rectangle {
              width: 18
              height: 18
              radius: 3
              color: Color.pickAlpha("surface.selected", "#2a3036")
              Text {
                anchors.centerIn: parent
                text: "F"
                font.family: Style.font.family
                font.pixelSize: 10
                color: Color.muted
              }
            }

            Button {
              text: "Launch"
              implicitWidth: 64
              implicitHeight: 24
              bordered: true
              onClicked: root.launchApp("file-manager")
            }
          }

          Text {
            Layout.fillWidth: true
            text: "Opens directory paths, downloads folders, and file browsing requests (Super + Shift + E)"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.muted
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
              model: root.installedFileManagers

              delegate: Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: 6
                readonly property bool isSelected: root.currentFileManager === modelData.id
                color: isSelected ? Color.pickAlpha("accent.subtle", "#1f3b30") : Color.pickAlpha("surface.hover", "#1b1f23")
                border.color: isSelected ? Color.accent : "transparent"
                border.width: isSelected ? 1 : 0

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.focusedCard = 3
                    root.setFileManager(modelData.id, modelData.name)
                  }
                }

                RowLayout {
                  anchors.centerIn: parent
                  spacing: 6

                  Text {
                    text: modelData.icon
                    font.family: Style.font.family
                    font.pixelSize: 14
                    color: isSelected ? Color.accent : Color.foreground
                  }

                  Text {
                    text: modelData.name
                    font.family: Style.font.family
                    font.pixelSize: 12
                    font.bold: isSelected
                    color: isSelected ? Color.accent : Color.foreground
                  }

                  Rectangle {
                    visible: isSelected
                    width: 12
                    height: 12
                    radius: 6
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
