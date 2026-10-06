import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Rectangle {
  id: root
  Layout.preferredWidth: (panelRoot && panelRoot.diffInspectorExpanded) ? 520 : (panelRoot && panelRoot.isCompactScreen ? 280 : 360)
  Layout.minimumWidth: (panelRoot && panelRoot.diffInspectorExpanded) ? 460 : (panelRoot && panelRoot.isCompactScreen ? 240 : 300)
  Layout.maximumWidth: (panelRoot && panelRoot.diffInspectorExpanded) ? 640 : (panelRoot && panelRoot.isCompactScreen ? 320 : 400)
  Layout.fillHeight: true
  width: Layout.preferredWidth
  color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.03)
  border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12)
  border.width: 1
  radius: 8
  clip: true

  property string pluginPath: "/home/ac/.config/omarchy/plugins/ac.control-panel"
  property var panelRoot: null
  property string activeCategory: "windows"
  property string currentTab: "diff" // "diff", "file", "history"
  
  property var latestDiff: null
  property var historyList: []
  property var categoryFileInfo: null
  property var allConfigsList: []
  property string selectedConfigId: ""
  property var selectedConfigFileInfo: null
  property string fileSearchQuery: ""
  property string historyCategoryFilter: "all"
  
  property bool hasDiff: false
  property string activeFile: ""
  property string activeDisplayFile: ""

  property bool pendingRefreshLatest: false
  property string toastMessage: ""
  property bool showToast: false
  readonly property bool isExpanded: panelRoot ? panelRoot.diffInspectorExpanded : false

  // Adaptive semantic color helpers
  readonly property color positiveColor: Qt.color("#34d399")
  readonly property color urgentColor: Color.urgent

  function showNotification(msg) {
    root.toastMessage = msg
    root.showToast = true
    toastTimer.restart()
  }

  Timer {
    id: toastTimer
    interval: 2400
    repeat: false
    onTriggered: root.showToast = false
  }

  // Reactive watcher for real-time diff file writes
  FileView {
    id: latestDiffWatcher
    path: "/tmp/omarchy-control-panel/latest.json"
    watchChanges: true
    printErrors: false
    onFileChanged: root.refresh()
  }

  onActiveCategoryChanged: {
    refreshCategoryFile()
  }

  function refresh() {
    refreshLatest()
    refreshHistory()
    refreshCategoryFile()
    refreshAllConfigs()
  }

  function refreshLatest() {
    if (pluginPath.length === 0) return
    if (latestProcess.running) {
      pendingRefreshLatest = true
      return
    }
    latestProcess.command = [pluginPath + "/scripts/config-tracker.sh", "get-latest"]
    latestProcess.running = true
  }

  function refreshHistory() {
    if (!historyProcess.running && pluginPath.length > 0) {
      historyProcess.command = [pluginPath + "/scripts/config-tracker.sh", "get-history"]
      historyProcess.running = true
    }
  }

  function refreshCategoryFile() {
    if (!categoryFileProcess.running && pluginPath.length > 0) {
      categoryFileProcess.command = [pluginPath + "/scripts/config-tracker.sh", "get-category-file", activeCategory]
      categoryFileProcess.running = true
    }
  }

  function refreshAllConfigs() {
    if (!allConfigsProcess.running && pluginPath.length > 0) {
      allConfigsProcess.command = [pluginPath + "/scripts/config-tracker.sh", "get-all-configs"]
      allConfigsProcess.running = true
    }
  }

  function selectConfigFile(cfg) {
    if (!cfg) return
    selectedConfigId = cfg.id
    if (!selectedConfigFileProcess.running && pluginPath.length > 0) {
      selectedConfigFileProcess.command = [pluginPath + "/scripts/config-tracker.sh", "get-file-content", cfg.file]
      selectedConfigFileProcess.running = true
    }
  }

  function openFile(path) {
    if (!path) path = root.activeFile || (root.selectedConfigFileInfo ? root.selectedConfigFileInfo.file : (root.categoryFileInfo ? root.categoryFileInfo.file : ""))
    if (path && !openEditorProcess.running && pluginPath.length > 0) {
      openEditorProcess.command = [pluginPath + "/scripts/config-tracker.sh", "open-editor", path]
      openEditorProcess.running = true
      showNotification("Opening in editor: " + (path.split("/").pop()))
    }
  }

  function revertChange(entryId) {
    if (revertProcess.running || pluginPath.length === 0) return
    var targetId = entryId ? String(entryId) : (root.latestDiff ? String(root.latestDiff.id) : "latest")
    revertProcess.command = [pluginPath + "/scripts/config-tracker.sh", "revert", targetId]
    revertProcess.running = true
  }

  function copyToClipboard(text, label) {
    if (copyProcess.running || pluginPath.length === 0) return
    if (!text || text.length === 0) return
    copyProcess.command = [pluginPath + "/scripts/config-tracker.sh", "copy", text]
    copyProcess.running = true
    showNotification(label || "Copied to clipboard!")
  }

  function reRunCommand(cmd) {
    if (reRunProcess.running || pluginPath.length === 0 || !cmd) return
    reRunProcess.command = [pluginPath + "/scripts/config-tracker.sh", "re-run", cmd]
    reRunProcess.running = true
    showNotification("Executing command...")
  }

  function selectHistoryEntry(entry) {
    latestDiff = entry
    hasDiff = true
    activeFile = entry.file || ""
    activeDisplayFile = entry.displayFile || ""
    currentTab = "diff"
  }

  function cycleTab(direction) {
    var tabs = ["diff", "file", "history"]
    var idx = tabs.indexOf(currentTab)
    if (idx < 0) idx = 0
    var next = (idx + direction + tabs.length) % tabs.length
    currentTab = tabs[next]
  }

  function toggleExpand() {
    if (panelRoot) {
      panelRoot.diffInspectorExpanded = !panelRoot.diffInspectorExpanded
    }
  }

  function clearHistory() {
    if (!clearProcess.running && pluginPath.length > 0) {
      clearProcess.command = [pluginPath + "/scripts/config-tracker.sh", "clear-history"]
      clearProcess.running = true
    }
  }

  // PROCESSES
  Process {
    id: latestProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var parsed = JSON.parse(text.trim())
          if (parsed && parsed.hasDiff) {
            root.latestDiff = parsed
            root.hasDiff = true
            root.activeFile = parsed.file || ""
            root.activeDisplayFile = parsed.displayFile || ""
          } else if (parsed && !parsed.hasDiff) {
            root.hasDiff = false
            root.latestDiff = null
          }
        } catch (e) {}
      }
    }
    onRunningChanged: {
      if (!running && root.pendingRefreshLatest) {
        root.pendingRefreshLatest = false
        root.refreshLatest()
      }
    }
  }

  Process {
    id: historyProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var parsed = JSON.parse(text.trim())
          if (Array.isArray(parsed)) {
            root.historyList = parsed
          }
        } catch (e) {}
      }
    }
  }

  Process {
    id: categoryFileProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var parsed = JSON.parse(text.trim())
          if (parsed) {
            root.categoryFileInfo = parsed
            if (!root.hasDiff && !root.selectedConfigFileInfo) {
              root.activeFile = parsed.file || ""
              root.activeDisplayFile = parsed.displayFile || ""
            }
          }
        } catch (e) {}
      }
    }
  }

  Process {
    id: allConfigsProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var parsed = JSON.parse(text.trim())
          if (Array.isArray(parsed)) {
            root.allConfigsList = parsed
            if (!root.selectedConfigId && parsed.length > 0) {
              root.selectConfigFile(parsed[0])
            }
          }
        } catch (e) {}
      }
    }
  }

  Process {
    id: selectedConfigFileProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var parsed = JSON.parse(text.trim())
          if (parsed) {
            root.selectedConfigFileInfo = parsed
          }
        } catch (e) {}
      }
    }
  }

  Process {
    id: revertProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var parsed = JSON.parse(text.trim())
          if (parsed && parsed.success) {
            root.showNotification("✓ " + (parsed.title || "Change reverted"))
            root.refresh()
          } else if (parsed) {
            root.showNotification("✗ " + (parsed.message || "Revert failed"))
          }
        } catch (e) {
          root.showNotification("Revert processed")
          root.refresh()
        }
      }
    }
  }

  Process { id: copyProcess }
  Process {
    id: reRunProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var parsed = JSON.parse(text.trim())
          if (parsed && parsed.success) {
            root.showNotification("✓ Command re-executed successfully")
            root.refresh()
          } else {
            root.showNotification("✗ Command execution failed")
          }
        } catch (e) {}
      }
    }
  }

  Process { id: openEditorProcess }
  Process {
    id: clearProcess
    onRunningChanged: {
      if (!running) {
        root.latestDiff = null
        root.hasDiff = false
        root.historyList = []
        root.refresh()
        root.showNotification("History cleared")
      }
    }
  }

  Component.onCompleted: {
    refresh()
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: 10
    spacing: 8

    // TOP HEADER
    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      Rectangle {
        width: 26
        height: 26
        radius: 6
        color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
        border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60)
        border.width: 1

        Text {
          anchors.centerIn: parent
          text: "󰊢"
          font.family: Style.font.family
          font.pixelSize: 14
          color: Color.accent
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 1

        Text {
          text: "Config Inspector"
          font.family: Style.font.family
          font.pixelSize: 12
          font.bold: true
          color: Color.foreground
        }

        Text {
          text: "Audit, diff & instant rollback"
          font.family: Style.font.family
          font.pixelSize: 9
          color: Color.muted
        }
      }

      // Expand / Compact width toggle button
      Rectangle {
        width: 24
        height: 24
        radius: 4
        color: expandMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20) : "transparent"
        border.color: expandMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.50) : "transparent"
        border.width: 1

        MouseArea {
          id: expandMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.toggleExpand()
        }

        Text {
          anchors.centerIn: parent
          text: root.isExpanded ? "󰍋" : "󰍉"
          font.family: Style.font.family
          font.pixelSize: 12
          color: expandMouse.containsMouse ? Color.accent : Color.muted
        }
      }

      // Close drawer button
      Rectangle {
        width: 24
        height: 24
        radius: 4
        color: closeMouse.containsMouse ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.20) : "transparent"

        MouseArea {
          id: closeMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (panelRoot) panelRoot.showDiffInspector = false
          }
        }

        Text {
          anchors.centerIn: parent
          text: "✕"
          font.family: Style.font.family
          font.pixelSize: 11
          color: closeMouse.containsMouse ? Color.urgent : Color.muted
        }
      }
    }

    // TOAST NOTIFICATION BANNER (appears on revert, copy, etc.)
    Rectangle {
      visible: root.showToast
      Layout.fillWidth: true
      Layout.preferredHeight: 24
      radius: 4
      color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25)
      border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.70)
      border.width: 1

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 6

        Text {
          text: "󰄬"
          font.family: Style.font.family
          font.pixelSize: 10
          color: Color.accent
        }

        Text {
          Layout.fillWidth: true
          text: root.toastMessage
          font.family: Style.font.family
          font.pixelSize: 10
          font.bold: true
          color: Color.foreground
          elide: Text.ElideRight
        }
      }
    }

    // TAB NAVIGATION BAR (Diff | Files | History)
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 30
      radius: 6
      color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04)

      RowLayout {
        anchors.fill: parent
        anchors.margins: 2
        spacing: 2

        // Tab: Diff
        Rectangle {
          Layout.fillWidth: true
          Layout.fillHeight: true
          radius: 4
          readonly property bool isTabActive: root.currentTab === "diff"
          readonly property bool isTabHovered: tabDiffMouse.containsMouse
          color: isTabActive
            ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, isTabHovered ? 0.28 : 0.20)
            : (isTabHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : "transparent")
          border.color: isTabActive ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60) : "transparent"
          border.width: isTabActive ? 1 : 0

          MouseArea {
            id: tabDiffMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.currentTab = "diff"
          }

          RowLayout {
            anchors.centerIn: parent
            spacing: 4

            Text {
              text: "󰊢 Diff"
              font.family: Style.font.family
              font.pixelSize: 10
              font.bold: isTabActive
              color: isTabActive ? Color.accent : (parent.parent.isTabHovered ? Color.foreground : Color.muted)
            }

            Rectangle {
              visible: root.hasDiff
              Layout.preferredHeight: 6
              Layout.preferredWidth: 6
              radius: 3
              color: root.positiveColor
            }
          }
        }

        // Tab: Files Explorer
        Rectangle {
          Layout.fillWidth: true
          Layout.fillHeight: true
          radius: 4
          readonly property bool isTabActive: root.currentTab === "file"
          readonly property bool isTabHovered: tabFileMouse.containsMouse
          color: isTabActive
            ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, isTabHovered ? 0.28 : 0.20)
            : (isTabHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : "transparent")
          border.color: isTabActive ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60) : "transparent"
          border.width: isTabActive ? 1 : 0

          MouseArea {
            id: tabFileMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.currentTab = "file"
          }

          Text {
            anchors.centerIn: parent
            text: " Files"
            font.family: Style.font.family
            font.pixelSize: 10
            font.bold: isTabActive
            color: isTabActive ? Color.accent : (parent.isTabHovered ? Color.foreground : Color.muted)
          }
        }

        // Tab: History
        Rectangle {
          Layout.fillWidth: true
          Layout.fillHeight: true
          radius: 4
          readonly property bool isTabActive: root.currentTab === "history"
          readonly property bool isTabHovered: tabHistMouse.containsMouse
          color: isTabActive
            ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, isTabHovered ? 0.28 : 0.20)
            : (isTabHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : "transparent")
          border.color: isTabActive ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60) : "transparent"
          border.width: isTabActive ? 1 : 0

          MouseArea {
            id: tabHistMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.currentTab = "history"
          }

          RowLayout {
            anchors.centerIn: parent
            spacing: 4

            Text {
              text: " History"
              font.family: Style.font.family
              font.pixelSize: 10
              font.bold: isTabActive
              color: isTabActive ? Color.accent : (parent.parent.isTabHovered ? Color.foreground : Color.muted)
            }

            Rectangle {
              visible: root.historyList.length > 0
              Layout.preferredHeight: 14
              Layout.preferredWidth: histCountText.implicitWidth + 8
              radius: 4
              color: isTabActive ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.30) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.10)

              Text {
                id: histCountText
                anchors.centerIn: parent
                text: String(root.historyList.length)
                font.family: Style.font.family
                font.pixelSize: 8
                font.bold: true
                color: isTabActive ? Color.accent : Color.foreground
              }
            }
          }
        }
      }
    }

    // ACTION & CONTEXT TOOLBAR
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 34
      radius: 6
      color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04)
      border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
      border.width: 1

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 6

        // File icon or Command icon
        Text {
          text: {
            if (root.currentTab === "diff" && root.latestDiff && root.latestDiff.changeType === "command") return "󰘳"
            var f = (root.currentTab === "file" && root.selectedConfigFileInfo)
              ? root.selectedConfigFileInfo.displayFile
              : (root.activeDisplayFile || (root.categoryFileInfo ? root.categoryFileInfo.displayFile : ""))
            if (f.indexOf(".lua") !== -1) return ""
            if (f.indexOf(".json") !== -1) return "󰘦"
            return "󰅩"
          }
          font.family: Style.font.family
          font.pixelSize: 12
          color: Color.accent
        }

        // File path or runtime target label
        Text {
          Layout.fillWidth: true
          text: {
            if (root.currentTab === "diff" && root.latestDiff && root.latestDiff.changeType === "command") {
              return "Runtime: " + (root.latestDiff.title || "CLI Action")
            }
            if (root.currentTab === "file" && root.selectedConfigFileInfo) {
              return root.selectedConfigFileInfo.displayFile
            }
            return root.activeDisplayFile || (root.categoryFileInfo ? root.categoryFileInfo.displayFile : "No config active")
          }
          font.family: Style.font.family
          font.pixelSize: 10
          font.bold: true
          color: Color.foreground
          elide: Text.ElideMiddle
        }

        // REVERT / ROLLBACK BUTTON (Visible when current diff is reversible)
        Rectangle {
          visible: root.currentTab === "diff" && root.hasDiff && root.latestDiff !== null && root.latestDiff.changeType !== "command" && root.latestDiff.isReversible !== false
          Layout.preferredHeight: 22
          Layout.preferredWidth: revertBtnText.implicitWidth + 18
          radius: 4
          color: revertBtnMouse.containsMouse ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.35) : Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.20)
          border.color: Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.70)
          border.width: 1

          MouseArea {
            id: revertBtnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.revertChange()
          }

          RowLayout {
            anchors.centerIn: parent
            spacing: 4

            Text {
              text: "󰑓"
              font.family: Style.font.family
              font.pixelSize: 10
              color: Color.urgent
            }

            Text {
              id: revertBtnText
              text: "Revert"
              font.family: Style.font.family
              font.pixelSize: 9
              font.bold: true
              color: Color.foreground
            }
          }
        }

        // COPY BUTTON (Copies diff patch, command, or file path)
        Rectangle {
          Layout.preferredHeight: 22
          Layout.preferredWidth: copyBtnText.implicitWidth + 16
          radius: 4
          color: copyBtnMouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.14) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06)
          border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
          border.width: 1

          MouseArea {
            id: copyBtnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (root.currentTab === "diff" && root.latestDiff) {
                if (root.latestDiff.changeType === "command") {
                  root.copyToClipboard(root.latestDiff.command, "Command copied!")
                } else {
                  root.copyToClipboard(root.latestDiff.diff, "Diff patch copied!")
                }
              } else if (root.currentTab === "file" && root.selectedConfigFileInfo) {
                root.copyToClipboard(root.selectedConfigFileInfo.file, "File path copied!")
              } else {
                root.copyToClipboard(root.activeFile, "File path copied!")
              }
            }
          }

          RowLayout {
            anchors.centerIn: parent
            spacing: 3

            Text {
              text: "󰆏"
              font.family: Style.font.family
              font.pixelSize: 10
              color: Color.muted
            }

            Text {
              id: copyBtnText
              text: "Copy"
              font.family: Style.font.family
              font.pixelSize: 9
              color: Color.foreground
            }
          }
        }

        // EDIT IN EXTERNAL EDITOR BUTTON
        Rectangle {
          Layout.preferredHeight: 22
          Layout.preferredWidth: openBtnText.implicitWidth + 14
          radius: 4
          color: openBtnMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.30) : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.18)
          border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60)
          border.width: 1

          MouseArea {
            id: openBtnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openFile()
          }

          RowLayout {
            anchors.centerIn: parent
            spacing: 3

            Text {
              text: "󰏫"
              font.family: Style.font.family
              font.pixelSize: 10
              color: Color.accent
            }

            Text {
              id: openBtnText
              text: "Edit"
              font.family: Style.font.family
              font.pixelSize: 9
              font.bold: true
              color: Color.accent
            }
          }
        }
      }
    }

    // MAIN CONTENT AREA STACK
    StackLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      currentIndex: root.currentTab === "diff" ? 0 : (root.currentTab === "file" ? 1 : 2)

      // ==========================================
      // VIEW 0: LIVE DIFF & RUNTIME ACTION
      // ==========================================
      Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        ScrollView {
          anchors.fill: parent
          clip: true
          ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
          ScrollBar.vertical.policy: ScrollBar.AsNeeded

          ColumnLayout {
            width: Math.max(100, parent.width - 6)
            spacing: 8

            // CASE A: EMPTY STATE
            Rectangle {
              visible: !root.hasDiff || root.latestDiff === null
              Layout.fillWidth: true
              Layout.preferredHeight: 200
              radius: 6
              color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02)
              border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06)
              border.width: 1

              ColumnLayout {
                anchors.centerIn: parent
                spacing: 8
                width: parent.width - 32

                Text {
                  Layout.alignment: Qt.AlignHCenter
                  text: "󰊢"
                  font.family: Style.font.family
                  font.pixelSize: 32
                  color: Color.muted
                }

                Text {
                  Layout.alignment: Qt.AlignHCenter
                  text: "Ready for Modifications"
                  font.family: Style.font.family
                  font.pixelSize: 12
                  font.bold: true
                  color: Color.foreground
                }

                Text {
                  Layout.fillWidth: true
                  horizontalAlignment: Text.AlignHCenter
                  wrapMode: Text.WordWrap
                  text: "Adjust any setting in the control panel to see real-time unified line diffs, syntax-aware line numbers, and instant rollback."
                  font.family: Style.font.family
                  font.pixelSize: 10
                  color: Color.muted
                }
              }
            }

            // CASE B: RUNTIME COMMAND ACTION CARD
            Rectangle {
              visible: root.hasDiff && root.latestDiff !== null && root.latestDiff.changeType === "command"
              Layout.fillWidth: true
              Layout.preferredHeight: cmdContentCol.implicitHeight + 24
              radius: 6
              color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.03)
              border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35)
              border.width: 1

              ColumnLayout {
                id: cmdContentCol
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                RowLayout {
                  Layout.fillWidth: true
                  spacing: 6

                  Rectangle {
                    width: 20
                    height: 20
                    radius: 4
                    color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
                    Text {
                      anchors.centerIn: parent
                      text: "󰘳"
                      font.family: Style.font.family
                      font.pixelSize: 11
                      color: Color.accent
                    }
                  }

                  Text {
                    Layout.fillWidth: true
                    text: root.latestDiff ? root.latestDiff.title : ""
                    font.family: Style.font.family
                    font.pixelSize: 11
                    font.bold: true
                    color: Color.foreground
                  }

                  Text {
                    text: root.latestDiff ? root.latestDiff.timestamp : ""
                    font.family: Style.font.family
                    font.pixelSize: 9
                    color: Color.muted
                  }
                }

                // Command terminal display box
                Rectangle {
                  Layout.fillWidth: true
                  Layout.preferredHeight: cmdTextItem.implicitHeight + 14
                  radius: 4
                  color: Qt.rgba(Color.background.r, Color.background.g, Color.background.b, 0.70)
                  border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12)
                  border.width: 1

                  RowLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 6

                    Text {
                      text: "$"
                      font.family: "monospace"
                      font.pixelSize: 10
                      font.bold: true
                      color: Color.accent
                    }

                    Text {
                      id: cmdTextItem
                      Layout.fillWidth: true
                      text: root.latestDiff ? (root.latestDiff.command || "") : ""
                      font.family: "monospace"
                      font.pixelSize: 10
                      color: Color.foreground
                      wrapMode: Text.WrapAnywhere
                    }
                  }
                }

                // Note / Detail
                Text {
                  visible: root.latestDiff && root.latestDiff.note && root.latestDiff.note.length > 0
                  Layout.fillWidth: true
                  text: root.latestDiff ? ("Note: " + root.latestDiff.note) : ""
                  font.family: Style.font.family
                  font.pixelSize: 9
                  color: Color.muted
                  wrapMode: Text.WordWrap
                }

                // Action buttons for command
                RowLayout {
                  Layout.fillWidth: true
                  spacing: 6

                  Rectangle {
                    Layout.preferredHeight: 22
                    Layout.preferredWidth: copyCmdTxt.implicitWidth + 14
                    radius: 4
                    color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
                    border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
                    border.width: 1

                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.copyToClipboard(root.latestDiff ? root.latestDiff.command : "", "Command copied!")
                    }

                    Text {
                      id: copyCmdTxt
                      anchors.centerIn: parent
                      text: "󰆏 Copy Command"
                      font.family: Style.font.family
                      font.pixelSize: 9
                      color: Color.foreground
                    }
                  }

                  Rectangle {
                    Layout.preferredHeight: 22
                    Layout.preferredWidth: rerunCmdTxt.implicitWidth + 14
                    radius: 4
                    color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
                    border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.50)
                    border.width: 1

                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.reRunCommand(root.latestDiff ? root.latestDiff.command : "")
                    }

                    Text {
                      id: rerunCmdTxt
                      anchors.centerIn: parent
                      text: "󰑓 Re-run"
                      font.family: Style.font.family
                      font.pixelSize: 9
                      font.bold: true
                      color: Color.accent
                    }
                  }
                }
              }
            }

            // CASE C: REAL UNIFIED FILE DIFF
            // Diff Stats Banner
            Rectangle {
              visible: root.hasDiff && root.latestDiff !== null && root.latestDiff.changeType !== "command"
              Layout.fillWidth: true
              Layout.preferredHeight: 44
              radius: 6
              color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.03)
              border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
              border.width: 1

              RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 1

                  Text {
                    text: root.latestDiff ? root.latestDiff.title : ""
                    font.family: Style.font.family
                    font.pixelSize: 11
                    font.bold: true
                    color: Color.accent
                    elide: Text.ElideRight
                  }

                  Text {
                    text: root.latestDiff ? ("Recorded at " + root.latestDiff.timestamp) : ""
                    font.family: Style.font.family
                    font.pixelSize: 9
                    color: Color.muted
                  }
                }

                // Additions badge
                Rectangle {
                  visible: root.latestDiff && root.latestDiff.linesAdded > 0
                  Layout.preferredHeight: 18
                  Layout.preferredWidth: addText.implicitWidth + 8
                  radius: 3
                  color: Qt.rgba(0.2, 0.75, 0.4, 0.20)
                  border.color: Qt.rgba(0.2, 0.75, 0.4, 0.50)
                  border.width: 1

                  Text {
                    id: addText
                    anchors.centerIn: parent
                    text: "+" + (root.latestDiff ? root.latestDiff.linesAdded : 0)
                    font.family: Style.font.family
                    font.pixelSize: 9
                    font.bold: true
                    color: root.positiveColor
                  }
                }

                // Deletions badge
                Rectangle {
                  visible: root.latestDiff && root.latestDiff.linesRemoved > 0
                  Layout.preferredHeight: 18
                  Layout.preferredWidth: delText.implicitWidth + 8
                  radius: 3
                  color: Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.20)
                  border.color: Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.50)
                  border.width: 1

                  Text {
                    id: delText
                    anchors.centerIn: parent
                    text: "-" + (root.latestDiff ? root.latestDiff.linesRemoved : 0)
                    font.family: Style.font.family
                    font.pixelSize: 9
                    font.bold: true
                    color: root.urgentColor
                  }
                }
              }
            }

            // Gutter Header (Old | New | Code)
            Rectangle {
              visible: root.hasDiff && root.latestDiff !== null && root.latestDiff.changeType !== "command" && root.latestDiff.lines && root.latestDiff.lines.length > 0
              Layout.fillWidth: true
              Layout.preferredHeight: 18
              color: "transparent"

              RowLayout {
                anchors.fill: parent
                spacing: 0

                Text {
                  width: 26
                  text: "OLD"
                  font.family: "monospace"
                  font.pixelSize: 8
                  font.bold: true
                  color: Color.muted
                  horizontalAlignment: Text.AlignRight
                }

                Rectangle { width: 4; height: 1; color: "transparent" }

                Text {
                  width: 26
                  text: "NEW"
                  font.family: "monospace"
                  font.pixelSize: 8
                  font.bold: true
                  color: Color.muted
                  horizontalAlignment: Text.AlignRight
                }

                Rectangle { width: 14; height: 1; color: "transparent" }

                Text {
                  Layout.fillWidth: true
                  text: "MODIFIED LINES"
                  font.family: Style.font.family
                  font.pixelSize: 8
                  font.bold: true
                  color: Color.muted
                }
              }
            }

            // Diff Lines Repeater with Two-Column Gutter
            Repeater {
              model: (root.hasDiff && root.latestDiff && root.latestDiff.changeType !== "command" && root.latestDiff.lines) ? root.latestDiff.lines : []

              delegate: Rectangle {
                id: lineDelegate
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(19, lineTextCol.implicitHeight + 4)
                radius: 2

                readonly property bool isAdd: modelData.type === "add"
                readonly property bool isDel: modelData.type === "del"
                readonly property bool isHdr: modelData.type === "header"

                color: isAdd
                  ? Qt.rgba(0.2, 0.75, 0.4, 0.12)
                  : (isDel ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.14) : (isHdr ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.08) : "transparent"))

                // Left indicator strip for modified lines
                Rectangle {
                  anchors.left: parent.left
                  anchors.top: parent.top
                  anchors.bottom: parent.bottom
                  width: 3
                  visible: isAdd || isDel || isHdr
                  color: isAdd ? root.positiveColor : (isDel ? root.urgentColor : Color.accent)
                }

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: 4
                  anchors.rightMargin: 6
                  spacing: 4

                  // Old line number column
                  Text {
                    width: 24
                    Layout.preferredWidth: 24
                    horizontalAlignment: Text.AlignRight
                    text: modelData.oldLine || ""
                    font.family: "monospace"
                    font.pixelSize: 9
                    color: isDel ? root.urgentColor : Color.muted
                    opacity: isDel ? 1.0 : 0.6
                  }

                  // New line number column
                  Text {
                    width: 24
                    Layout.preferredWidth: 24
                    horizontalAlignment: Text.AlignRight
                    text: modelData.newLine || ""
                    font.family: "monospace"
                    font.pixelSize: 9
                    color: isAdd ? root.positiveColor : Color.muted
                    opacity: isAdd ? 1.0 : 0.6
                  }

                  // Marker column (+, -, or section)
                  Text {
                    width: 12
                    Layout.preferredWidth: 12
                    horizontalAlignment: Text.AlignHCenter
                    text: isAdd ? "+" : (isDel ? "-" : " ")
                    font.family: "monospace"
                    font.pixelSize: 9
                    font.bold: true
                    color: isAdd ? root.positiveColor : (isDel ? root.urgentColor : (isHdr ? Color.accent : Color.muted))
                  }

                  // Line code text
                  ColumnLayout {
                    id: lineTextCol
                    Layout.fillWidth: true

                    Text {
                      Layout.fillWidth: true
                      text: modelData.text
                      font.family: "monospace"
                      font.pixelSize: 10
                      font.bold: isHdr
                      color: isAdd
                        ? root.positiveColor
                        : (isDel ? root.urgentColor : (isHdr ? Color.accent : Color.foreground))
                      wrapMode: Text.WrapAnywhere
                    }
                  }
                }
              }
            }
          }
        }
      }

      // ==========================================
      // VIEW 1: FULL CONFIG FILES EXPLORER
      // ==========================================
      Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        ColumnLayout {
          anchors.fill: parent
          spacing: 6

          // Config File Selection Pills Bar
          ScrollView {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            ScrollBar.horizontal.policy: ScrollBar.AsNeeded
            ScrollBar.vertical.policy: ScrollBar.AlwaysOff

            RowLayout {
              spacing: 4

              Repeater {
                model: root.allConfigsList

                delegate: Rectangle {
                  Layout.preferredHeight: 24
                  Layout.preferredWidth: pillRow.implicitWidth + 12
                  radius: 4
                  readonly property bool isSelected: root.selectedConfigId === modelData.id
                  color: isSelected
                    ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25)
                    : (cfgPillMouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.03))
                  border.color: isSelected ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
                  border.width: 1

                  MouseArea {
                    id: cfgPillMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selectConfigFile(modelData)
                  }

                  RowLayout {
                    id: pillRow
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                      text: modelData.icon || "󰅩"
                      font.family: Style.font.family
                      font.pixelSize: 10
                      color: isSelected ? Color.accent : Color.muted
                    }

                    Text {
                      text: modelData.name
                      font.family: Style.font.family
                      font.pixelSize: 9
                      font.bold: isSelected
                      color: isSelected ? Color.accent : Color.foreground
                    }
                  }
                }
              }
            }
          }

          // Search / Filter Input Field
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 26
            radius: 4
            color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04)
            border.color: fileSearchInput.activeFocus ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12)
            border.width: 1

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 6
              anchors.rightMargin: 6
              spacing: 4

              Text {
                text: "󰍉"
                font.family: Style.font.family
                font.pixelSize: 10
                color: Color.muted
              }

              TextInput {
                id: fileSearchInput
                Layout.fillWidth: true
                text: root.fileSearchQuery
                color: Color.foreground
                font.family: Style.font.family
                font.pixelSize: 10
                onTextChanged: root.fileSearchQuery = text

                Text {
                  anchors.fill: parent
                  visible: !fileSearchInput.text && !fileSearchInput.activeFocus
                  text: "Filter config lines (e.g. gaps, timeout, bindings)..."
                  color: Color.muted
                  font.family: Style.font.family
                  font.pixelSize: 10
                  opacity: 0.6
                }
              }

              Text {
                visible: fileSearchInput.text.length > 0
                text: "✕"
                font.family: Style.font.family
                font.pixelSize: 9
                color: Color.muted
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    fileSearchInput.text = ""
                    root.fileSearchQuery = ""
                  }
                }
              }
            }
          }

          // File Content Viewer
          Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 6
            color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02)
            border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
            border.width: 1

            ScrollView {
              anchors.fill: parent
              anchors.margins: 6
              clip: true

              ColumnLayout {
                width: parent.width
                spacing: 2

                Repeater {
                  model: {
                    var info = root.selectedConfigFileInfo || root.categoryFileInfo
                    if (!info || !info.content) return ["No configuration file loaded"]
                    var rawLines = info.content.split("\n")
                    if (!root.fileSearchQuery || root.fileSearchQuery.trim().length === 0) {
                      return rawLines
                    }
                    var q = root.fileSearchQuery.toLowerCase()
                    var filtered = []
                    for (var i = 0; i < rawLines.length; i++) {
                      if (rawLines[i].toLowerCase().indexOf(q) !== -1) {
                        filtered.push("[" + (i + 1) + "] " + rawLines[i])
                      }
                    }
                    return filtered.length > 0 ? filtered : ["No lines matching '" + root.fileSearchQuery + "'"]
                  }

                  delegate: Text {
                    width: parent.width
                    text: modelData
                    font.family: "monospace"
                    font.pixelSize: 10
                    color: {
                      if (root.fileSearchQuery && modelData.indexOf("[") === 0) return Color.accent
                      return Color.foreground
                    }
                    wrapMode: Text.WrapAnywhere
                  }
                }
              }
            }
          }
        }
      }

      // ==========================================
      // VIEW 2: SESSION AUDIT HISTORY
      // ==========================================
      Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        ColumnLayout {
          anchors.fill: parent
          spacing: 6

          // Filter bar & Clear History
          RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
              text: "AUDIT TRAIL (" + root.historyList.length + ")"
              font.family: Style.font.family
              font.pixelSize: 9
              font.bold: true
              color: Color.accent
            }

            Item { Layout.fillWidth: true }

            // Clear button
            Rectangle {
              visible: root.historyList.length > 0
              Layout.preferredHeight: 18
              Layout.preferredWidth: clearTxt.implicitWidth + 8
              radius: 3
              color: clearMouse.containsMouse ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.25) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06)

              MouseArea {
                id: clearMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.clearHistory()
              }

              Text {
                id: clearTxt
                anchors.centerIn: parent
                text: "Clear"
                font.family: Style.font.family
                font.pixelSize: 9
                color: clearMouse.containsMouse ? Color.urgent : Color.muted
              }
            }
          }

          // Category filter pills
          ScrollView {
            Layout.fillWidth: true
            Layout.preferredHeight: 24
            ScrollBar.horizontal.policy: ScrollBar.AsNeeded
            ScrollBar.vertical.policy: ScrollBar.AlwaysOff

            RowLayout {
              spacing: 4

              Repeater {
                model: ["all", "windows", "displays", "power", "shortcuts", "defaults"]

                delegate: Rectangle {
                  Layout.preferredHeight: 20
                  Layout.preferredWidth: histFilterTxt.implicitWidth + 10
                  radius: 3
                  readonly property bool isSelected: root.historyCategoryFilter === modelData
                  color: isSelected ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04)
                  border.color: isSelected ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.50) : "transparent"
                  border.width: 1

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.historyCategoryFilter = modelData
                  }

                  Text {
                    id: histFilterTxt
                    anchors.centerIn: parent
                    text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                    font.family: Style.font.family
                    font.pixelSize: 8
                    font.bold: isSelected
                    color: isSelected ? Color.accent : Color.muted
                  }
                }
              }
            }
          }

          // History items list
          ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            ColumnLayout {
              width: Math.max(100, parent.width - 6)
              spacing: 6

              // Empty state
              Rectangle {
                visible: root.historyList.length === 0
                Layout.fillWidth: true
                Layout.preferredHeight: 140
                radius: 6
                color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02)

                ColumnLayout {
                  anchors.centerIn: parent
                  spacing: 6

                  Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: ""
                    font.family: Style.font.family
                    font.pixelSize: 24
                    color: Color.muted
                  }

                  Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "No session history recorded yet"
                    font.family: Style.font.family
                    font.pixelSize: 11
                    color: Color.muted
                  }
                }
              }

              // History list repeater
              Repeater {
                model: {
                  if (root.historyCategoryFilter === "all") return root.historyList
                  var filtered = []
                  for (var i = 0; i < root.historyList.length; i++) {
                    if (root.historyList[i].category === root.historyCategoryFilter) {
                      filtered.push(root.historyList[i])
                    }
                  }
                  return filtered
                }

                delegate: Rectangle {
                  id: histCard
                  Layout.fillWidth: true
                  Layout.preferredHeight: 52
                  radius: 6
                  readonly property bool isSelected: (root.latestDiff && root.latestDiff.id === modelData.id)
                  readonly property bool isHovered: histMouse.containsMouse
                  readonly property bool isCommand: modelData.changeType === "command"
                  readonly property bool isReversible: modelData.isReversible !== false && !isCommand

                  color: isSelected
                    ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, isHovered ? 0.28 : 0.20)
                    : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.03))
                  border.color: isSelected
                    ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60)
                    : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08))
                  border.width: 1

                  MouseArea {
                    id: histMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selectHistoryEntry(modelData)
                  }

                  RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8

                    // Icon
                    Text {
                      text: histCard.isCommand ? "󰘳" : "󰊢"
                      font.family: Style.font.family
                      font.pixelSize: 12
                      color: histCard.isSelected ? Color.accent : Color.muted
                    }

                    ColumnLayout {
                      Layout.fillWidth: true
                      spacing: 2

                      RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                          text: modelData.title
                          font.family: Style.font.family
                          font.pixelSize: 11
                          font.bold: true
                          color: histCard.isSelected ? Color.accent : Color.foreground
                          elide: Text.ElideRight
                          Layout.fillWidth: true
                        }

                        Text {
                          text: modelData.timestamp
                          font.family: Style.font.family
                          font.pixelSize: 9
                          color: Color.muted
                        }
                      }

                      Text {
                        text: modelData.displayFile || modelData.file
                        font.family: Style.font.family
                        font.pixelSize: 9
                        color: Color.muted
                        elide: Text.ElideMiddle
                        Layout.fillWidth: true
                      }
                    }

                    // Direct Revert button on history card
                    Rectangle {
                      visible: histCard.isReversible
                      Layout.preferredHeight: 20
                      Layout.preferredWidth: 20
                      radius: 3
                      color: histRevMouse.containsMouse ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.30) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
                      border.color: histRevMouse.containsMouse ? Color.urgent : "transparent"
                      border.width: 1

                      MouseArea {
                        id: histRevMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.revertChange(modelData.id)
                      }

                      Text {
                        anchors.centerIn: parent
                        text: "󰑓"
                        font.family: Style.font.family
                        font.pixelSize: 9
                        color: histRevMouse.containsMouse ? Color.urgent : Color.muted
                      }
                    }

                    // Changes pill
                    Rectangle {
                      Layout.preferredHeight: 20
                      Layout.preferredWidth: changesTxt.implicitWidth + 8
                      radius: 3
                      color: histCard.isSelected
                        ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.30)
                        : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
                      border.color: histCard.isSelected ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
                      border.width: 1

                      Text {
                        id: changesTxt
                        anchors.centerIn: parent
                        text: histCard.isCommand ? "CMD" : ("+" + modelData.linesAdded + " -" + modelData.linesRemoved)
                        font.family: Style.font.family
                        font.pixelSize: 8
                        font.bold: true
                        color: histCard.isCommand ? Color.accent : (modelData.linesAdded > 0 ? root.positiveColor : Color.foreground)
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
