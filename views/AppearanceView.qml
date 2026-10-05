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
  property string currentTheme: "Tokyo Night"
  property var themes: []
  property bool activeFocusSection: false
  property int focusedIndex: 0
  property string focusTarget: "search" // "search" or "list"
  readonly property bool hasActiveInput: searchField.activeFocus

  onActiveFocusSectionChanged: {
    if (activeFocusSection) {
      if (focusTarget === "search") {
        searchField.forceActiveFocus()
      }
    } else {
      searchField.focus = false
    }
  }

  function focusToInput() {
    focusTarget = "search"
    if (searchField) {
      searchField.forceActiveFocus()
    }
  }

  function blurInput() {
    if (searchField) {
      searchField.focus = false
    }
  }

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
    if (dx < 0) {
      if (panelRoot) panelRoot.focusSection = "sidebar"
      return true
    }
    if (dy !== 0) {
      if (dy < 0 && focusedIndex === 0) {
        focusTarget = "search"
        searchField.forceActiveFocus()
        return true
      }
      if (filteredThemes.length > 0) {
        focusedIndex = Math.max(0, Math.min(filteredThemes.length - 1, focusedIndex + dy))
        ensureVisible(focusedIndex)
        return true
      }
    }
    return false
  }

  function handleActivate() {
    if (focusTarget === "search") {
      if (filteredThemes.length > 0) {
        setTheme(filteredThemes[0])
      }
    } else if (focusedIndex >= 0 && focusedIndex < filteredThemes.length) {
      setTheme(filteredThemes[focusedIndex])
    }
  }

  function handleTextKey(key) {
    if (key === "\b") {
      focusTarget = "search"
      searchField.forceActiveFocus()
      if (searchField.text.length > 0) {
        searchField.text = searchField.text.slice(0, -1)
      }
      return
    }
    if (key.length === 1 && key >= " ") {
      focusTarget = "search"
      searchField.forceActiveFocus()
      searchField.text = searchField.text + key
      searchField.cursorPosition = searchField.text.length
    }
  }

  function ensureVisible(index) {
    if (!themesScroll || !themesScroll.contentItem) return
    var itemY = index * 46
    var flick = themesScroll.contentItem
    if (itemY < flick.contentY) {
      flick.contentY = Math.max(0, itemY)
    } else if (itemY + 46 > flick.contentY + themesScroll.height) {
      flick.contentY = Math.max(0, itemY + 46 - themesScroll.height)
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

  // Reactive inotify watcher for theme changes
  FileView {
    id: themeWatcher
    path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme.name"
    watchChanges: true
    printErrors: false
    onFileChanged: root.refresh()
  }

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
    onRunningChanged: {
      if (!running) {
        root.refresh()
        if (panelRoot && typeof panelRoot.notifySettingChanged === "function") {
          panelRoot.notifySettingChanged()
        }
      }
    }
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: 12

    // Header Card
    Rectangle {
      Layout.fillWidth: true
      implicitHeight: Math.max(70, headerLayout.implicitHeight + 28)
      Layout.preferredHeight: implicitHeight
      color: Color.pickAlpha("surface.subtle", "#181b1d")
      radius: Style.cornerRadius || 8

      RowLayout {
        id: headerLayout
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
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
          Layout.preferredWidth: 0
          Layout.minimumWidth: 0
          spacing: 2

          Flow {
            Layout.fillWidth: true
            width: parent.width
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
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            wrapMode: Text.WordWrap
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
      border.color: (root.activeFocusSection && (searchField.activeFocus || root.focusTarget === "search")) ? Color.accent : "transparent"
      border.width: (root.activeFocusSection && (searchField.activeFocus || root.focusTarget === "search")) ? 2 : 1

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.IBeamCursor
        onClicked: {
          root.focusTarget = "search"
          searchField.forceActiveFocus()
        }
      }

      RowLayout {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 8

        Text {
          text: "  "
          font.family: Style.font.family
          font.pixelSize: 13
          color: (root.activeFocusSection && (searchField.activeFocus || root.focusTarget === "search")) ? Color.accent : Color.muted
        }

        TextField {
          id: searchField
          Layout.fillWidth: true
          Layout.fillHeight: true
          placeholderText: "Type to filter themes directly... ([↓] to browse list, [Enter] to apply)"
          background: null
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.body || 13

          onPressed: {
            root.focusTarget = "search"
          }

          Keys.onEscapePressed: function(event) {
            if (text.length > 0) {
              text = ""
              event.accepted = true
            } else {
              searchField.focus = false
              if (root.panelRoot) root.panelRoot.focusSection = "sidebar"
              if (root.panelRoot && typeof root.panelRoot.returnFocusToKeyCatcher === "function") {
                root.panelRoot.returnFocusToKeyCatcher()
              }
              event.accepted = true
            }
          }

          Keys.onDownPressed: function(event) {
            if (root.filteredThemes.length > 0) {
              root.focusTarget = "list"
              searchField.focus = false
              if (root.panelRoot && typeof root.panelRoot.returnFocusToKeyCatcher === "function") {
                root.panelRoot.returnFocusToKeyCatcher()
              }
              root.ensureVisible(root.focusedIndex)
              event.accepted = true
            }
          }

          Keys.onLeftPressed: function(event) {
            if (cursorPosition === 0 && selectionStart === selectionEnd) {
              searchField.focus = false
              if (root.panelRoot) root.panelRoot.focusSection = "sidebar"
              if (root.panelRoot && typeof root.panelRoot.returnFocusToKeyCatcher === "function") {
                root.panelRoot.returnFocusToKeyCatcher()
              }
              event.accepted = true
            } else {
              event.accepted = false
            }
          }

          Keys.onTabPressed: function(event) {
            event.accepted = true
            searchField.focus = false
            if (root.panelRoot && typeof root.panelRoot.toggleFocusSection === "function") {
              root.panelRoot.toggleFocusSection()
            } else if (root.panelRoot) {
              root.panelRoot.focusSection = "sidebar"
              if (typeof root.panelRoot.returnFocusToKeyCatcher === "function") {
                root.panelRoot.returnFocusToKeyCatcher()
              }
            }
          }

          Keys.onBacktabPressed: function(event) {
            event.accepted = true
            searchField.focus = false
            if (root.panelRoot && typeof root.panelRoot.toggleFocusSection === "function") {
              root.panelRoot.toggleFocusSection()
            } else if (root.panelRoot) {
              root.panelRoot.focusSection = "sidebar"
              if (typeof root.panelRoot.returnFocusToKeyCatcher === "function") {
                root.panelRoot.returnFocusToKeyCatcher()
              }
            }
          }

          Keys.onReturnPressed: function(event) {
            root.handleActivate()
            event.accepted = true
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
            root.focusTarget = "search"
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
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        ColumnLayout {
          width: Math.max(200, themesScroll.availableWidth - 12)
          spacing: 6

          Repeater {
            model: root.filteredThemes

            delegate: Rectangle {
              Layout.fillWidth: true
              implicitHeight: Math.max(40, themeRowLayout.implicitHeight + 12)
              Layout.preferredHeight: implicitHeight
              radius: 6
              readonly property bool isCurrent: root.currentTheme.toLowerCase() === modelData.toLowerCase()
              readonly property bool isCursorTarget: root.activeFocusSection && root.focusTarget === "list" && root.focusedIndex === index
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
                  root.focusTarget = "list"
                  root.setTheme(modelData)
                }
              }

              RowLayout {
                id: themeRowLayout
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 6
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
