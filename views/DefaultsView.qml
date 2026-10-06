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
  readonly property bool isContentFocused: root.panelRoot ? (root.panelRoot.focusSection === "content") : root.activeFocusSection

  property int focusedCard: 0 // 0: Browser, 1: Editor, 2: Terminal, 3: File Manager
  onFocusedCardChanged: ensureCardVisible(focusedCard)

  property int browserFocusIndex: -1
  property int editorFocusIndex: -1
  property int terminalFocusIndex: -1
  property int fileManagerFocusIndex: -1

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
  onCurrentBrowserChanged: browserFocusIndex = currentBrowserIndex()

  property string currentEditor: "nvim"
  property var installedEditors: []
  onCurrentEditorChanged: editorFocusIndex = currentEditorIndex()

  property string currentTerminal: "Alacritty.desktop"
  property var installedTerminals: []
  onCurrentTerminalChanged: terminalFocusIndex = currentTerminalIndex()

  property string currentFileManager: "org.gnome.Nautilus.desktop"
  property var installedFileManagers: []
  onCurrentFileManagerChanged: fileManagerFocusIndex = currentFileManagerIndex()

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
    if (installedBrowsers.length === 0) return false
    var cur = (browserFocusIndex >= 0) ? browserFocusIndex : currentBrowserIndex()
    if (delta < 0 && cur === 0) return false
    var next = Math.max(0, Math.min(installedBrowsers.length - 1, cur + delta))
    if (next === cur) return false
    browserFocusIndex = next
    setBrowser(installedBrowsers[next].id, installedBrowsers[next].name)
    return true
  }

  function cycleEditor(delta) {
    if (installedEditors.length === 0) return false
    var cur = (editorFocusIndex >= 0) ? editorFocusIndex : currentEditorIndex()
    if (delta < 0 && cur === 0) return false
    var next = Math.max(0, Math.min(installedEditors.length - 1, cur + delta))
    if (next === cur) return false
    editorFocusIndex = next
    setEditor(installedEditors[next].code, installedEditors[next].id, installedEditors[next].name)
    return true
  }

  function cycleTerminal(delta) {
    if (installedTerminals.length === 0) return false
    var cur = (terminalFocusIndex >= 0) ? terminalFocusIndex : currentTerminalIndex()
    if (delta < 0 && cur === 0) return false
    var next = Math.max(0, Math.min(installedTerminals.length - 1, cur + delta))
    if (next === cur) return false
    terminalFocusIndex = next
    setTerminal(installedTerminals[next].id, installedTerminals[next].name)
    return true
  }

  function cycleFileManager(delta) {
    if (installedFileManagers.length === 0) return false
    var cur = (fileManagerFocusIndex >= 0) ? fileManagerFocusIndex : currentFileManagerIndex()
    if (delta < 0 && cur === 0) return false
    var next = Math.max(0, Math.min(installedFileManagers.length - 1, cur + delta))
    if (next === cur) return false
    fileManagerFocusIndex = next
    setFileManager(installedFileManagers[next].id, installedFileManagers[next].name)
    return true
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
      if (focusedCard === 0) return cycleBrowser(dx)
      else if (focusedCard === 1) return cycleEditor(dx)
      else if (focusedCard === 2) return cycleTerminal(dx)
      else if (focusedCard === 3) return cycleFileManager(dx)
    }
    return false
  }

  function handleActivate() {
    if (focusedCard === 0) {
      var bIdx = (browserFocusIndex >= 0) ? browserFocusIndex : currentBrowserIndex()
      if (installedBrowsers[bIdx]) setBrowser(installedBrowsers[bIdx].id, installedBrowsers[bIdx].name)
    } else if (focusedCard === 1) {
      var eIdx = (editorFocusIndex >= 0) ? editorFocusIndex : currentEditorIndex()
      if (installedEditors[eIdx]) setEditor(installedEditors[eIdx].code, installedEditors[eIdx].id, installedEditors[eIdx].name)
    } else if (focusedCard === 2) {
      var tIdx = (terminalFocusIndex >= 0) ? terminalFocusIndex : currentTerminalIndex()
      if (installedTerminals[tIdx]) setTerminal(installedTerminals[tIdx].id, installedTerminals[tIdx].name)
    } else if (focusedCard === 3) {
      var fIdx = (fileManagerFocusIndex >= 0) ? fileManagerFocusIndex : currentFileManagerIndex()
      if (installedFileManagers[fIdx]) setFileManager(installedFileManagers[fIdx].id, installedFileManagers[fIdx].name)
    }
  }

  function handleTextKey(key) {
    var k = key.toLowerCase()
    if (k === "h") {
      return handleMove(-1, 0)
    } else if (k === "l") {
      return handleMove(1, 0)
    } else if (k === "b") {
      focusedCard = 0
      return true
    } else if (k === "e") {
      focusedCard = 1
      return true
    } else if (k === "t") {
      focusedCard = 2
      return true
    } else if (k === "f") {
      focusedCard = 3
      return true
    } else if (k === "r") {
      refresh()
      notifyStatus("Refreshed default applications")
      return true
    }
    return false
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
        color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15)
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
        implicitHeight: Math.max(116, browserCol.implicitHeight + 24)
        Layout.preferredHeight: implicitHeight
        radius: Style.cornerRadius || 8
        readonly property bool isFocused: root.isContentFocused && root.focusedCard === 0
        readonly property bool isHovered: browserCardMouse.containsMouse
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02)
        border.color: isFocused ? Color.accent : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08))
        border.width: isFocused ? 2 : 1

        MouseArea {
          id: browserCardMouse
          anchors.fill: parent
          hoverEnabled: true
          onClicked: {
            if (root.panelRoot) root.panelRoot.focusSection = "content"
            root.focusedCard = 0
          }
        }

        ColumnLayout {
          id: browserCol
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 12
          spacing: 8

          Flow {
            Layout.fillWidth: true
            width: parent.width
            spacing: 8

            RowLayout {
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
            }

            RowLayout {
              spacing: 6
              Rectangle {
                width: 18
                height: 18
                radius: 3
                color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
                border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
                border.width: 1
                Text {
                  anchors.centerIn: parent
                  text: "B"
                  font.family: Style.font.family
                  font.pixelSize: 10
                  color: Color.muted
                }
              }

              Rectangle {
                implicitWidth: 64
                implicitHeight: 24
                radius: 4
                readonly property bool btnHover: browserLaunchMouse.containsMouse
                color: btnHover ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06)
                border.color: btnHover ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.3) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
                border.width: 1

                Text {
                  anchors.centerIn: parent
                  text: "Launch"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  color: parent.btnHover ? Color.foreground : Color.muted
                }

                MouseArea {
                  id: browserLaunchMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.launchApp("browser")
                }
              }
            }
          }

          Text {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: "Handles web links, authentication sign-ins, and browser web applications"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.muted
            wrapMode: Text.WordWrap
          }

          Flow {
            id: browserFlow
            Layout.fillWidth: true
            width: parent.width
            spacing: 8

            readonly property int count: root.installedBrowsers.length
            readonly property int minItemWidth: 120
            readonly property int cols: Math.max(1, Math.min(count, Math.floor((width + spacing) / (minItemWidth + spacing))))
            readonly property real itemWidth: Math.max(80, Math.floor((width - (cols - 1) * spacing) / cols))

            Repeater {
              model: root.installedBrowsers

              delegate: Rectangle {
                width: browserFlow.itemWidth
                height: 38
                radius: 6
                readonly property bool isActive: root.currentBrowser === modelData.id
                readonly property bool isCursorFocused: root.isContentFocused && root.focusedCard === 0 && index === ((root.browserFocusIndex >= 0) ? root.browserFocusIndex : root.currentBrowserIndex())
                readonly property bool isHovered: browserItemMouse.containsMouse

                color: isActive
                  ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, isHovered ? 0.28 : 0.20)
                  : (isCursorFocused ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, isHovered ? 0.18 : 0.14) : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.03)))

                border.color: isCursorFocused
                  ? Color.accent
                  : (isActive ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60) : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)))
                border.width: isCursorFocused ? 2 : 1

                MouseArea {
                  id: browserItemMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (root.panelRoot) root.panelRoot.focusSection = "content"
                    root.focusedCard = 0
                    root.browserFocusIndex = index
                    root.setBrowser(modelData.id, modelData.name)
                  }
                }

                RowLayout {
                  anchors.centerIn: parent
                  width: Math.min(implicitWidth, parent.width - 16)
                  spacing: 6

                  Text {
                    text: modelData.icon
                    font.family: Style.font.family
                    font.pixelSize: 14
                    color: isActive ? Color.accent : Color.foreground
                  }

                  Text {
                    text: modelData.name
                    font.family: Style.font.family
                    font.pixelSize: 12
                    font.bold: isActive || isCursorFocused
                    color: isActive ? Color.accent : (isCursorFocused ? Color.foreground : Color.foreground)
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    elide: Text.ElideRight
                  }

                  Rectangle {
                    visible: isActive
                    width: 6
                    height: 6
                    radius: 3
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
        implicitHeight: Math.max(116, editorCol.implicitHeight + 24)
        Layout.preferredHeight: implicitHeight
        radius: Style.cornerRadius || 8
        readonly property bool isFocused: root.isContentFocused && root.focusedCard === 1
        readonly property bool isHovered: editorCardMouse.containsMouse
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02)
        border.color: isFocused ? Color.accent : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08))
        border.width: isFocused ? 2 : 1

        MouseArea {
          id: editorCardMouse
          anchors.fill: parent
          hoverEnabled: true
          onClicked: {
            if (root.panelRoot) root.panelRoot.focusSection = "content"
            root.focusedCard = 1
          }
        }

        ColumnLayout {
          id: editorCol
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 12
          spacing: 8

          Flow {
            Layout.fillWidth: true
            width: parent.width
            spacing: 8

            RowLayout {
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
            }

            RowLayout {
              spacing: 6
              Rectangle {
                width: 18
                height: 18
                radius: 3
                color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
                border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
                border.width: 1
                Text {
                  anchors.centerIn: parent
                  text: "E"
                  font.family: Style.font.family
                  font.pixelSize: 10
                  color: Color.muted
                }
              }

              Rectangle {
                implicitWidth: 64
                implicitHeight: 24
                radius: 4
                readonly property bool btnHover: editorLaunchMouse.containsMouse
                color: btnHover ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06)
                border.color: btnHover ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.3) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
                border.width: 1

                Text {
                  anchors.centerIn: parent
                  text: "Launch"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  color: parent.btnHover ? Color.foreground : Color.muted
                }

                MouseArea {
                  id: editorLaunchMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.launchApp("editor")
                }
              }
            }
          }

          Text {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: "Launched by Super + E, git commit editor, and configuration file editing"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.muted
            wrapMode: Text.WordWrap
          }

          Flow {
            id: editorFlow
            Layout.fillWidth: true
            width: parent.width
            spacing: 8

            readonly property int count: root.installedEditors.length
            readonly property int minItemWidth: 120
            readonly property int cols: Math.max(1, Math.min(count, Math.floor((width + spacing) / (minItemWidth + spacing))))
            readonly property real itemWidth: Math.max(80, Math.floor((width - (cols - 1) * spacing) / cols))

            Repeater {
              model: root.installedEditors

              delegate: Rectangle {
                width: editorFlow.itemWidth
                height: 38
                radius: 6
                readonly property bool isActive: (root.currentEditor === modelData.code || root.currentEditor === modelData.id)
                readonly property bool isCursorFocused: root.isContentFocused && root.focusedCard === 1 && index === ((root.editorFocusIndex >= 0) ? root.editorFocusIndex : root.currentEditorIndex())
                readonly property bool isHovered: editorItemMouse.containsMouse

                color: isActive
                  ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, isHovered ? 0.28 : 0.20)
                  : (isCursorFocused ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, isHovered ? 0.18 : 0.14) : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.03)))

                border.color: isCursorFocused
                  ? Color.accent
                  : (isActive ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60) : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)))
                border.width: isCursorFocused ? 2 : 1

                MouseArea {
                  id: editorItemMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (root.panelRoot) root.panelRoot.focusSection = "content"
                    root.focusedCard = 1
                    root.editorFocusIndex = index
                    root.setEditor(modelData.code, modelData.id, modelData.name)
                  }
                }

                RowLayout {
                  anchors.centerIn: parent
                  width: Math.min(implicitWidth, parent.width - 16)
                  spacing: 6

                  Text {
                    text: modelData.icon
                    font.family: Style.font.family
                    font.pixelSize: 14
                    color: isActive ? Color.accent : Color.foreground
                  }

                  Text {
                    text: modelData.name
                    font.family: Style.font.family
                    font.pixelSize: 12
                    font.bold: isActive || isCursorFocused
                    color: isActive ? Color.accent : (isCursorFocused ? Color.foreground : Color.foreground)
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    elide: Text.ElideRight
                  }

                  Rectangle {
                    visible: isActive
                    width: 6
                    height: 6
                    radius: 3
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
        implicitHeight: Math.max(116, terminalCol.implicitHeight + 24)
        Layout.preferredHeight: implicitHeight
        radius: Style.cornerRadius || 8
        readonly property bool isFocused: root.isContentFocused && root.focusedCard === 2
        readonly property bool isHovered: terminalCardMouse.containsMouse
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02)
        border.color: isFocused ? Color.accent : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08))
        border.width: isFocused ? 2 : 1

        MouseArea {
          id: terminalCardMouse
          anchors.fill: parent
          hoverEnabled: true
          onClicked: {
            if (root.panelRoot) root.panelRoot.focusSection = "content"
            root.focusedCard = 2
          }
        }

        ColumnLayout {
          id: terminalCol
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 12
          spacing: 8

          Flow {
            Layout.fillWidth: true
            width: parent.width
            spacing: 8

            RowLayout {
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
            }

            RowLayout {
              spacing: 6
              Rectangle {
                width: 18
                height: 18
                radius: 3
                color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
                border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
                border.width: 1
                Text {
                  anchors.centerIn: parent
                  text: "T"
                  font.family: Style.font.family
                  font.pixelSize: 10
                  color: Color.muted
                }
              }

              Rectangle {
                implicitWidth: 64
                implicitHeight: 24
                radius: 4
                readonly property bool btnHover: terminalLaunchMouse.containsMouse
                color: btnHover ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06)
                border.color: btnHover ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.3) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
                border.width: 1

                Text {
                  anchors.centerIn: parent
                  text: "Launch"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  color: parent.btnHover ? Color.foreground : Color.muted
                }

                MouseArea {
                  id: terminalLaunchMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.launchApp("terminal")
                }
              }
            }
          }

          Text {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: "Launched by Super + Return and system terminal execution (xdg-terminal-exec)"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.muted
            wrapMode: Text.WordWrap
          }

          Flow {
            id: terminalFlow
            Layout.fillWidth: true
            width: parent.width
            spacing: 8

            readonly property int count: root.installedTerminals.length
            readonly property int minItemWidth: 120
            readonly property int cols: Math.max(1, Math.min(count, Math.floor((width + spacing) / (minItemWidth + spacing))))
            readonly property real itemWidth: Math.max(80, Math.floor((width - (cols - 1) * spacing) / cols))

            Repeater {
              model: root.installedTerminals

              delegate: Rectangle {
                width: terminalFlow.itemWidth
                height: 38
                radius: 6
                readonly property bool isActive: root.currentTerminal === modelData.id
                readonly property bool isCursorFocused: root.isContentFocused && root.focusedCard === 2 && index === ((root.terminalFocusIndex >= 0) ? root.terminalFocusIndex : root.currentTerminalIndex())
                readonly property bool isHovered: terminalItemMouse.containsMouse

                color: isActive
                  ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, isHovered ? 0.28 : 0.20)
                  : (isCursorFocused ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, isHovered ? 0.18 : 0.14) : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.03)))

                border.color: isCursorFocused
                  ? Color.accent
                  : (isActive ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60) : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)))
                border.width: isCursorFocused ? 2 : 1

                MouseArea {
                  id: terminalItemMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (root.panelRoot) root.panelRoot.focusSection = "content"
                    root.focusedCard = 2
                    root.terminalFocusIndex = index
                    root.setTerminal(modelData.id, modelData.name)
                  }
                }

                RowLayout {
                  anchors.centerIn: parent
                  width: Math.min(implicitWidth, parent.width - 16)
                  spacing: 6

                  Text {
                    text: modelData.icon
                    font.family: Style.font.family
                    font.pixelSize: 14
                    color: isActive ? Color.accent : Color.foreground
                  }

                  Text {
                    text: modelData.name
                    font.family: Style.font.family
                    font.pixelSize: 12
                    font.bold: isActive || isCursorFocused
                    color: isActive ? Color.accent : (isCursorFocused ? Color.foreground : Color.foreground)
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    elide: Text.ElideRight
                  }

                  Rectangle {
                    visible: isActive
                    width: 6
                    height: 6
                    radius: 3
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
        implicitHeight: Math.max(116, fileManagerCol.implicitHeight + 24)
        Layout.preferredHeight: implicitHeight
        radius: Style.cornerRadius || 8
        readonly property bool isFocused: root.isContentFocused && root.focusedCard === 3
        readonly property bool isHovered: fileManagerCardMouse.containsMouse
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02)
        border.color: isFocused ? Color.accent : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08))
        border.width: isFocused ? 2 : 1

        MouseArea {
          id: fileManagerCardMouse
          anchors.fill: parent
          hoverEnabled: true
          onClicked: {
            if (root.panelRoot) root.panelRoot.focusSection = "content"
            root.focusedCard = 3
          }
        }

        ColumnLayout {
          id: fileManagerCol
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 12
          spacing: 8

          Flow {
            Layout.fillWidth: true
            width: parent.width
            spacing: 8

            RowLayout {
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
            }

            RowLayout {
              spacing: 6
              Rectangle {
                width: 18
                height: 18
                radius: 3
                color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
                border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
                border.width: 1
                Text {
                  anchors.centerIn: parent
                  text: "F"
                  font.family: Style.font.family
                  font.pixelSize: 10
                  color: Color.muted
                }
              }

              Rectangle {
                implicitWidth: 64
                implicitHeight: 24
                radius: 4
                readonly property bool btnHover: fileManagerLaunchMouse.containsMouse
                color: btnHover ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06)
                border.color: btnHover ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.3) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
                border.width: 1

                Text {
                  anchors.centerIn: parent
                  text: "Launch"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  color: parent.btnHover ? Color.foreground : Color.muted
                }

                MouseArea {
                  id: fileManagerLaunchMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.launchApp("file-manager")
                }
              }
            }
          }

          Text {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: "Opens directory paths, downloads folders, and file browsing requests (Super + Shift + E)"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.muted
            wrapMode: Text.WordWrap
          }

          Flow {
            id: fileManagerFlow
            Layout.fillWidth: true
            width: parent.width
            spacing: 8

            readonly property int count: root.installedFileManagers.length
            readonly property int minItemWidth: 120
            readonly property int cols: Math.max(1, Math.min(count, Math.floor((width + spacing) / (minItemWidth + spacing))))
            readonly property real itemWidth: Math.max(80, Math.floor((width - (cols - 1) * spacing) / cols))

            Repeater {
              model: root.installedFileManagers

              delegate: Rectangle {
                width: fileManagerFlow.itemWidth
                height: 38
                radius: 6
                readonly property bool isActive: root.currentFileManager === modelData.id
                readonly property bool isCursorFocused: root.isContentFocused && root.focusedCard === 3 && index === ((root.fileManagerFocusIndex >= 0) ? root.fileManagerFocusIndex : root.currentFileManagerIndex())
                readonly property bool isHovered: fileManagerItemMouse.containsMouse

                color: isActive
                  ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, isHovered ? 0.28 : 0.20)
                  : (isCursorFocused ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, isHovered ? 0.18 : 0.14) : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.03)))

                border.color: isCursorFocused
                  ? Color.accent
                  : (isActive ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60) : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)))
                border.width: isCursorFocused ? 2 : 1

                MouseArea {
                  id: fileManagerItemMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (root.panelRoot) root.panelRoot.focusSection = "content"
                    root.focusedCard = 3
                    root.fileManagerFocusIndex = index
                    root.setFileManager(modelData.id, modelData.name)
                  }
                }

                RowLayout {
                  anchors.centerIn: parent
                  width: Math.min(implicitWidth, parent.width - 16)
                  spacing: 6

                  Text {
                    text: modelData.icon
                    font.family: Style.font.family
                    font.pixelSize: 14
                    color: isActive ? Color.accent : Color.foreground
                  }

                  Text {
                    text: modelData.name
                    font.family: Style.font.family
                    font.pixelSize: 12
                    font.bold: isActive || isCursorFocused
                    color: isActive ? Color.accent : (isCursorFocused ? Color.foreground : Color.foreground)
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    elide: Text.ElideRight
                  }

                  Rectangle {
                    visible: isActive
                    width: 6
                    height: 6
                    radius: 3
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
