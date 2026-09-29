import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Item {
  id: root

  property string pluginPath: "/home/ac/.config/omarchy/plugins/ac.control-panel"
  onPluginPathChanged: refresh()
  property string currentTheme: "Tokyo Night"
  property var themes: []
  property bool activeFocusSection: false
  property int focusedIndex: 0
  readonly property bool hasActiveInput: searchField.activeFocus

  readonly property var filteredThemes: {
    var query = searchField.text.trim().toLowerCase()
    if (!query) return themes
    return themes.filter(function(t) {
      return t.toLowerCase().indexOf(query) !== -1
    })
  }

  onFilteredThemesChanged: {
    if (focusedIndex >= filteredThemes.length) {
      focusedIndex = Math.max(0, filteredThemes.length - 1)
    }
  }

  function handleMove(dx, dy) {
    if (filteredThemes.length === 0) return false
    if (dy !== 0) {
      focusedIndex = Math.max(0, Math.min(filteredThemes.length - 1, focusedIndex + dy))
      return true
    }
    return false
  }

  function handleActivate() {
    if (focusedIndex >= 0 && focusedIndex < filteredThemes.length) {
      setTheme(filteredThemes[focusedIndex])
    }
  }

  function handleTextKey(key) {
    if (key === "/" || key === "f") {
      searchField.forceActiveFocus()
    } else if (key === "r" || key === "R") {
      refresh()
    }
  }

  function refresh() {
    if (!stateProcess.running && pluginPath.length > 0) {
      stateProcess.command = [pluginPath + "/scripts/system-control.sh", "theme-get"]
      stateProcess.running = true
    }
  }

  function setTheme(name) {
    root.currentTheme = name
    setThemeProcess.command = [pluginPath + "/scripts/system-control.sh", "theme-set", name]
    setThemeProcess.running = true
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
          if (data.current) root.currentTheme = data.current
          if (Array.isArray(data.themes)) {
            root.themes = data.themes
            for (var i = 0; i < data.themes.length; i++) {
              if (data.themes[i].toLowerCase() === root.currentTheme.toLowerCase()) {
                root.focusedIndex = i
                break
              }
            }
          }
        } catch (e) {
          console.warn("AppearanceView: JSON parse error", e)
        }
      }
    }
  }

  // Set Theme Process
  Process {
    id: setThemeProcess
    onRunningChanged: if (!running) root.refresh()
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: 12

    // Header Card
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 70
      color: Color.pickAlpha("surface.subtle", "#181b1d")
      radius: Style.cornerRadius || 8

      RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 14

        Rectangle {
          width: 42
          height: 42
          radius: 8
          color: Color.pickAlpha("surface.selected", "#2a3036")

          Text {
            anchors.centerIn: parent
            text: ""
            font.family: Style.font.family
            font.pixelSize: 22
            color: Color.accent
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2

          RowLayout {
            spacing: 8
            Text {
              text: "Current: " + root.currentTheme
              font.family: Style.font.family
              font.pixelSize: Style.font.title || 15
              font.bold: true
              color: Color.foreground
            }

            Rectangle {
              width: 52
              height: 18
              radius: 4
              color: Color.pickAlpha("accent.subtle", "#1f3b30")

              Text {
                anchors.centerIn: parent
                text: "Active"
                font.family: Style.font.family
                font.pixelSize: 10
                font.bold: true
                color: Color.accent
              }
            }
          }

          Text {
            text: "Select a desktop theme below to apply wallpaper, colors, and styling."
            font.family: Style.font.family
            font.pixelSize: Style.font.subtext || 11
            color: Color.muted
          }
        }

        Button {
          text: "Refresh"
          iconText: ""
          onClicked: root.refresh()
        }
      }
    }

    // Search / Filter Input Bar
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 42
      color: Color.pickAlpha("surface.subtle", "#181b1d")
      radius: Style.cornerRadius || 6
      border.color: searchField.activeFocus ? Color.accent : "transparent"
      border.width: searchField.activeFocus ? 2 : 1

      RowLayout {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 8

        Text {
          text: "  "
          font.family: Style.font.family
          font.pixelSize: 13
          color: searchField.activeFocus ? Color.accent : Color.muted
        }

        TextField {
          id: searchField
          Layout.fillWidth: true
          Layout.fillHeight: true
          placeholderText: "Type to filter themes... (Press '/' to search, [↑/↓] to select, [Enter] to apply)"
          background: null
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.body || 13

          Keys.onEscapePressed: {
            if (text.length > 0) {
              text = ""
            } else {
              focus = false
            }
          }

          Keys.onDownPressed: {
            root.handleMove(0, 1)
          }

          Keys.onUpPressed: {
            root.handleMove(0, -1)
          }

          Keys.onReturnPressed: {
            root.handleActivate()
          }
        }

        Text {
          text: root.filteredThemes.length + " / " + root.themes.length
          font.family: Style.font.family
          font.pixelSize: 11
          color: Color.muted
          visible: root.themes.length > 0
        }

        Button {
          visible: searchField.text.length > 0
          text: "✕"
          implicitWidth: 26
          implicitHeight: 26
          onClicked: {
            searchField.text = ""
            searchField.forceActiveFocus()
          }
        }
      }
    }

    // Themes List in ScrollView
    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      color: Color.pickAlpha("surface.subtle", "#181b1d")
      radius: Style.cornerRadius || 8

      ScrollView {
        id: themesScroll
        anchors.fill: parent
        anchors.margins: 10
        clip: true

        ColumnLayout {
          width: themesScroll.width - 12
          spacing: 6

          Repeater {
            model: root.filteredThemes

            delegate: Rectangle {
              Layout.fillWidth: true
              Layout.preferredHeight: 40
              radius: 6
              readonly property bool isCurrent: root.currentTheme.toLowerCase() === modelData.toLowerCase()
              readonly property bool isCursorTarget: root.activeFocusSection && root.focusedIndex === index
              color: isCursorTarget
                ? Color.pickAlpha("surface.selected", "#2a3036")
                : (isCurrent
                  ? Color.pickAlpha("surface.selected", "#22272e")
                  : (mouseArea.containsMouse ? Color.pickAlpha("surface.hover", "#1b1f23") : "transparent"))
              border.color: isCursorTarget
                ? Color.accent
                : (isCurrent ? Color.pickAlpha("accent.subtle", "#40ffffff") : "transparent")
              border.width: isCursorTarget ? 2 : 1

              MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.focusedIndex = index
                  root.setTheme(modelData)
                }
              }

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10

                Rectangle {
                  width: 10
                  height: 10
                  radius: 5
                  color: isCurrent ? Color.accent : (isCursorTarget ? Color.accent : Color.muted)
                }

                Text {
                  Layout.fillWidth: true
                  text: modelData
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body || 13
                  font.bold: isCurrent || isCursorTarget
                  color: isCurrent ? Color.accent : Color.foreground
                  elide: Text.ElideRight
                }

                Rectangle {
                  visible: isCurrent
                  width: 58
                  height: 20
                  radius: 4
                  color: Color.pickAlpha("accent.subtle", "#1f3b30")

                  Text {
                    anchors.centerIn: parent
                    text: "✓ ACTIVE"
                    font.family: Style.font.family
                    font.pixelSize: 10
                    font.bold: true
                    color: Color.accent
                  }
                }

                Text {
                  visible: isCursorTarget && !isCurrent
                  text: "⏎ apply"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  color: Color.muted
                }
              }
            }
          }

          Item {
            visible: root.filteredThemes.length === 0
            Layout.fillWidth: true
            Layout.preferredHeight: 80

            ColumnLayout {
              anchors.centerIn: parent
              spacing: 6

              Text {
                text: "No themes matching \"" + searchField.text + "\""
                font.family: Style.font.family
                font.pixelSize: Style.font.body || 13
                color: Color.muted
              }
            }
          }
        }
      }
    }
  }
}
