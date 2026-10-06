import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Rectangle {
  id: root
  Layout.preferredWidth: 360
  Layout.minimumWidth: 360
  Layout.maximumWidth: 380
  Layout.fillHeight: true
  width: 360
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
  property bool hasDiff: false
  property string activeFile: ""
  property string activeDisplayFile: ""

  property bool pendingRefreshLatest: false

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

  function openFile(path) {
    if (!path) path = root.activeFile || (root.categoryFileInfo ? root.categoryFileInfo.file : "")
    if (path && !openEditorProcess.running && pluginPath.length > 0) {
      openEditorProcess.command = [pluginPath + "/scripts/config-tracker.sh", "open-editor", path]
      openEditorProcess.running = true
    }
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

  function clearHistory() {
    if (!clearProcess.running && pluginPath.length > 0) {
      clearProcess.command = [pluginPath + "/scripts/config-tracker.sh", "clear-history"]
      clearProcess.running = true
    }
  }

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
            if (!root.hasDiff) {
              root.activeFile = parsed.file || ""
              root.activeDisplayFile = parsed.displayFile || ""
            }
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
      }
    }
  }

  Component.onCompleted: {
    refresh()
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: 12
    spacing: 10

    // Top Header
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
          text: "Live file & diff audit"
          font.family: Style.font.family
          font.pixelSize: 9
          color: Color.muted
        }
      }

      // Close drawer button
      Rectangle {
        width: 24
        height: 24
        radius: 4
        color: closeMouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12) : "transparent"

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
          color: Color.muted
        }
      }
    }

    // Tab Navigation Bar (Diff | File | History)
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
              color: Color.accent
            }
          }
        }

        // Tab: Full File
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
            text: " File"
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

    // File Action Pill Bar
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 32
      radius: 6
      color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.05)

      RowLayout {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 6

        Text {
          text: {
            var f = (root.currentTab === "file" && root.categoryFileInfo)
              ? root.categoryFileInfo.displayFile
              : (root.activeDisplayFile || (root.categoryFileInfo ? root.categoryFileInfo.displayFile : ""))
            if (f.indexOf(".lua") !== -1) return ""
            if (f.indexOf(".json") !== -1) return "󰘦"
            return "󰅩"
          }
          font.family: Style.font.family
          font.pixelSize: 12
          color: Color.accent
        }

        Text {
          Layout.fillWidth: true
          text: (root.currentTab === "file" && root.categoryFileInfo)
            ? root.categoryFileInfo.displayFile
            : (root.activeDisplayFile || (root.categoryFileInfo ? root.categoryFileInfo.displayFile : "No file active"))
          font.family: Style.font.family
          font.pixelSize: 10
          font.bold: true
          color: Color.foreground
          elide: Text.ElideMiddle
        }

        // Open in Editor Button
        Rectangle {
          Layout.preferredHeight: 22
          Layout.preferredWidth: openBtnText.implicitWidth + 12
          radius: 4
          color: openBtnMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.30) : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
          border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60)
          border.width: 1

          MouseArea {
            id: openBtnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openFile(root.activeFile)
          }

          RowLayout {
            anchors.centerIn: parent
            spacing: 3

            Text {
              text: "󰏫"
              font.family: Style.font.family
              font.pixelSize: 10
              color: openBtnMouse.containsMouse ? Color.background : Color.accent
            }

            Text {
              id: openBtnText
              text: "Edit"
              font.family: Style.font.family
              font.pixelSize: 10
              font.bold: true
              color: openBtnMouse.containsMouse ? Color.background : Color.accent
            }
          }
        }
      }
    }

    // MAIN CONTENT AREA
    StackLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      currentIndex: root.currentTab === "diff" ? 0 : (root.currentTab === "file" ? 1 : 2)

      // VIEW 0: LIVE DIFF
      Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        ScrollView {
          anchors.fill: parent
          clip: true
          ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
          ScrollBar.vertical.policy: ScrollBar.AsNeeded

          ColumnLayout {
            width: Math.max(100, parent.width - 8)
            spacing: 8

            // Diff Status & Stats Bar
            Rectangle {
              visible: root.hasDiff && root.latestDiff !== null
              Layout.fillWidth: true
              Layout.preferredHeight: 46
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
                  spacing: 2

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
                  color: "#183b24"

                  Text {
                    id: addText
                    anchors.centerIn: parent
                    text: "+" + (root.latestDiff ? root.latestDiff.linesAdded : 0)
                    font.family: Style.font.family
                    font.pixelSize: 9
                    font.bold: true
                    color: "#73daca"
                  }
                }

                // Deletions badge
                Rectangle {
                  visible: root.latestDiff && root.latestDiff.linesRemoved > 0
                  Layout.preferredHeight: 18
                  Layout.preferredWidth: delText.implicitWidth + 8
                  radius: 3
                  color: "#3b181c"

                  Text {
                    id: delText
                    anchors.centerIn: parent
                    text: "-" + (root.latestDiff ? root.latestDiff.linesRemoved : 0)
                    font.family: Style.font.family
                    font.pixelSize: 9
                    font.bold: true
                    color: "#f7768e"
                  }
                }
              }
            }

            // Empty State (When no diffs recorded yet)
            Rectangle {
              visible: !root.hasDiff || root.latestDiff === null
              Layout.fillWidth: true
              Layout.preferredHeight: 180
              radius: 6
              color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02)

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
                  text: "Adjust any setting on the left to see live unified file diffs."
                  font.family: Style.font.family
                  font.pixelSize: 10
                  color: Color.muted
                }
              }
            }

            // Diff Lines List
            Repeater {
              model: (root.hasDiff && root.latestDiff && root.latestDiff.lines) ? root.latestDiff.lines : []

              delegate: Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(20, lineText.implicitHeight + 4)
                radius: 2
                color: (modelData.type === "add")
                  ? "#143320"
                  : ((modelData.type === "del") ? "#331418" : ((modelData.type === "header") ? "#172b38" : "transparent"))

                Text {
                  id: lineText
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.leftMargin: 6
                  anchors.rightMargin: 6
                  text: modelData.text
                  font.family: "monospace"
                  font.pixelSize: 10
                  font.bold: (modelData.type === "header")
                  color: (modelData.type === "add")
                    ? "#73daca"
                    : ((modelData.type === "del") ? "#f7768e" : ((modelData.type === "header") ? "#7dcfff" : "#9aa5ce"))
                  wrapMode: Text.WrapAnywhere
                }
              }
            }
          }
        }
      }

      // VIEW 1: FULL BACKING FILE
      Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        ScrollView {
          anchors.fill: parent
          clip: true
          ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
          ScrollBar.vertical.policy: ScrollBar.AsNeeded

          ColumnLayout {
            width: Math.max(100, parent.width - 8)
            spacing: 6

            RowLayout {
              Layout.fillWidth: true
              spacing: 6

              Text {
                text: "CURRENT CONFIGURATION"
                font.family: Style.font.family
                font.pixelSize: 9
                font.bold: true
                color: Color.accent
              }

              Item { Layout.fillWidth: true }

              Text {
                text: root.categoryFileInfo ? (root.categoryFileInfo.lineCount + " lines") : ""
                font.family: Style.font.family
                font.pixelSize: 9
                color: Color.muted
              }
            }

            Rectangle {
              Layout.fillWidth: true
              Layout.fillHeight: true
              Layout.minimumHeight: 280
              radius: 6
              color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02)
              border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
              border.width: 1

              ScrollView {
                anchors.fill: parent
                anchors.margins: 8
                clip: true

                Text {
                  width: parent.width
                  text: root.categoryFileInfo ? root.categoryFileInfo.content : "No file found"
                  font.family: "monospace"
                  font.pixelSize: 10
                  color: "#a9b1d6"
                  wrapMode: Text.WrapAnywhere
                }
              }
            }
          }
        }
      }

      // VIEW 2: SESSION AUDIT HISTORY
      Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        ScrollView {
          anchors.fill: parent
          clip: true
          ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
          ScrollBar.vertical.policy: ScrollBar.AsNeeded

          ColumnLayout {
            width: Math.max(100, parent.width - 8)
            spacing: 6

            RowLayout {
              Layout.fillWidth: true
              spacing: 6

              Text {
                text: "SESSION AUDIT TRAIL (" + root.historyList.length + ")"
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
                  color: clearMouse.containsMouse ? "#f7768e" : Color.muted
                }
              }
            }

            // Empty state for history
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
                  text: "No session history yet"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  color: Color.muted
                }
              }
            }

            // History Items
            Repeater {
              model: root.historyList

              delegate: Rectangle {
                id: histCard
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                radius: 6
                readonly property bool isSelected: (root.latestDiff && root.latestDiff.id === modelData.id)
                readonly property bool isHovered: histMouse.containsMouse
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
                      text: modelData.displayFile
                      font.family: Style.font.family
                      font.pixelSize: 9
                      color: Color.muted
                      elide: Text.ElideMiddle
                      Layout.fillWidth: true
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
                      text: "+" + modelData.linesAdded + " -" + modelData.linesRemoved
                      font.family: Style.font.family
                      font.pixelSize: 9
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
    }
  }
}
