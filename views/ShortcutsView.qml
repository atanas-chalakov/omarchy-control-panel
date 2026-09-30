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

  property bool activeFocusSection: false
  property bool hasActiveInput: searchField.activeFocus
  property string statusMessage: ""
  property string searchQuery: ""
  property string activeCategory: "all" // "all", "windows", "apps", "workspaces", "media", "system"

  property int totalCount: 0
  property var allBindings: []
  property var filteredBindings: []
  property bool isRefreshing: false

  readonly property var categoryList: [
    { id: "all", label: "All" },
    { id: "windows", label: "Windows" },
    { id: "apps", label: "Applications" },
    { id: "workspaces", label: "Workspaces" },
    { id: "media", label: "Media & Audio" },
    { id: "system", label: "System" }
  ]

  function updateFiltered() {
    var q = searchQuery.trim().toLowerCase()
    var cat = activeCategory
    var res = []

    for (var i = 0; i < allBindings.length; i++) {
      var item = allBindings[i]
      if (cat !== "all" && item.category !== cat) {
        continue
      }
      if (q.length > 0) {
        var k = (item.keys || "").toLowerCase()
        var d = (item.desc || "").toLowerCase()
        if (k.indexOf(q) === -1 && d.indexOf(q) === -1) {
          continue
        }
      }
      res.push(item)
    }
    filteredBindings = res
  }

  onSearchQueryChanged: updateFiltered()
  onActiveCategoryChanged: updateFiltered()

  function refresh() {
    if (!stateProcess.running && pluginPath.length > 0) {
      isRefreshing = true
      stateProcess.command = [pluginPath + "/scripts/shortcuts-control.sh", "get-state"]
      stateProcess.running = true
    }
  }

  function openConfig() {
    actionProcess.command = [pluginPath + "/scripts/shortcuts-control.sh", "open-config"]
    actionProcess.running = true
    notifyStatus("Opening ~/.config/hypr/bindings.lua in editor")
  }

  function openMenu() {
    actionProcess.command = [pluginPath + "/scripts/shortcuts-control.sh", "open-menu"]
    actionProcess.running = true
    notifyStatus("Opening interactive keybindings menu")
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

  function handleMove(dx, dy) {
    if (searchField.activeFocus) {
      if (dy > 0) {
        searchField.focus = false
        if (panelRoot && typeof panelRoot.returnFocusToKeyCatcher === "function") {
          panelRoot.returnFocusToKeyCatcher()
        }
      }
      return true
    }

    if (dy !== 0) {
      if (shortcutsScroll && shortcutsScroll.contentItem) {
        var flick = shortcutsScroll.contentItem
        var maxScroll = Math.max(0, flick.contentHeight - flick.height)
        flick.contentY = Math.max(0, Math.min(maxScroll, flick.contentY + dy * 60))
        return true
      }
    } else if (dx !== 0) {
      var ids = categoryList.map(function(c) { return c.id })
      var idx = ids.indexOf(activeCategory)
      if (idx < 0) idx = 0
      var nextIdx = (idx + (dx > 0 ? 1 : -1) + ids.length) % ids.length
      activeCategory = ids[nextIdx]
      return true
    }
    return false
  }

  function handleActivate() {
    openMenu()
  }

  function handleTextKey(key) {
    if (hasActiveInput) return

    var k = key.toLowerCase()
    if (k === "m") {
      openMenu()
    } else if (k === "e") {
      openConfig()
    } else if (k === "r") {
      refresh()
      notifyStatus("Refreshed keybindings")
    } else if (k === "s") {
      searchField.forceActiveFocus()
    } else if (key === "1") {
      activeCategory = "all"
    } else if (key === "2") {
      activeCategory = "windows"
    } else if (key === "3") {
      activeCategory = "apps"
    } else if (key === "4") {
      activeCategory = "workspaces"
    } else if (key === "5") {
      activeCategory = "media"
    } else if (key === "6") {
      activeCategory = "system"
    }
  }

  Component.onCompleted: refresh()

  // State Process
  Process {
    id: stateProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.isRefreshing = false
        try {
          var data = JSON.parse(text)
          if (data.count !== undefined) root.totalCount = Number(data.count) || 0
          if (Array.isArray(data.bindings)) {
            root.allBindings = data.bindings
            root.updateFiltered()
          }
        } catch (e) {
          console.warn("ShortcutsView: parse error", e)
        }
      }
    }
  }

  // Action Process
  Process {
    id: actionProcess
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: 12

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
        spacing: 8

        Text {
          text: "󰄬"
          font.family: Style.font.family
          font.pixelSize: 13
          color: Color.accent
        }

        Text {
          Layout.fillWidth: true
          text: root.statusMessage
          font.family: Style.font.family
          font.pixelSize: 12
          color: Color.foreground
          elide: Text.ElideRight
        }
      }
    }

    // Top Header Banner
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 64
      radius: Style.cornerRadius || 8
      color: Color.pickAlpha("surface.subtle", "#181b1d")
      border.color: Color.pickAlpha("border.subtle", "#262b30")
      border.width: 1

      RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 14

        Rectangle {
          width: 36
          height: 36
          radius: 18
          color: Color.pickAlpha("accent.subtle", "#283b32")

          Text {
            anchors.centerIn: parent
            text: "󰌌"
            font.family: Style.font.family
            font.pixelSize: 18
            color: Color.accent
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2

          RowLayout {
            spacing: 8
            Text {
              text: "Shortcuts & Keybindings"
              font.family: Style.font.family
              font.pixelSize: 15
              font.bold: true
              color: Color.foreground
            }

            Rectangle {
              Layout.preferredHeight: 18
              Layout.preferredWidth: countText.implicitWidth + 10
              radius: 9
              color: Color.accent

              Text {
                id: countText
                anchors.centerIn: parent
                text: root.totalCount + " bindings"
                font.family: Style.font.family
                font.pixelSize: 10
                font.bold: true
                color: Color.background
              }
            }
          }

          Text {
            text: "Browse, filter, and customize Hyprland shortcuts in ~/.config/hypr/bindings.lua"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.muted
          }
        }

        Button {
          text: "󰍉 Search Menu [M]"
          onClicked: root.openMenu()
        }

        Button {
          text: "󰏫 Edit Config [E]"
          onClicked: root.openConfig()
        }
      }
    }

    // Search Box & Category Filters Row
    RowLayout {
      Layout.fillWidth: true
      spacing: 10

      // Search Box
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 36
        radius: 6
        color: Color.pickAlpha("surface.subtle", "#181b1d")
        border.color: searchField.activeFocus ? Color.accent : Color.pickAlpha("border.subtle", "#262b30")
        border.width: searchField.activeFocus ? 2 : 1

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 10
          anchors.rightMargin: 8
          spacing: 8

          Text {
            text: "󰍉"
            font.family: Style.font.family
            font.pixelSize: 14
            color: searchField.activeFocus ? Color.accent : Color.muted
          }

          TextField {
            id: searchField
            Layout.fillWidth: true
            placeholderText: "Type to search shortcuts... (e.g. terminal, window, close, super+q)"
            placeholderTextColor: Color.muted
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: 12
            background: Item {}
            text: root.searchQuery
            onTextChanged: root.searchQuery = text

            Keys.onEscapePressed: {
              if (text.length > 0) {
                text = ""
              } else {
                focus = false
                if (panelRoot && typeof panelRoot.returnFocusToKeyCatcher === "function") {
                  panelRoot.returnFocusToKeyCatcher()
                }
              }
            }

            Keys.onDownPressed: {
              focus = false
              if (panelRoot && typeof panelRoot.returnFocusToKeyCatcher === "function") {
                panelRoot.returnFocusToKeyCatcher()
              }
            }
          }

          Button {
            visible: searchField.text.length > 0
            text: "✕"
            implicitWidth: 24
            implicitHeight: 24
            onClicked: searchField.text = ""
          }
        }
      }
    }

    // Category Tabs Row
    RowLayout {
      Layout.fillWidth: true
      spacing: 6

      Repeater {
        model: root.categoryList

        delegate: Rectangle {
          Layout.preferredHeight: 28
          Layout.preferredWidth: catText.implicitWidth + 20
          radius: 14
          color: (root.activeCategory === modelData.id)
            ? Color.pickAlpha("accent.subtle", "#203a30")
            : Color.pickAlpha("surface.subtle", "#181b1d")
          border.color: (root.activeCategory === modelData.id) ? Color.accent : "transparent"
          border.width: 1

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.activeCategory = modelData.id
          }

          Text {
            id: catText
            anchors.centerIn: parent
            text: modelData.label
            font.family: Style.font.family
            font.pixelSize: 11
            font.bold: root.activeCategory === modelData.id
            color: (root.activeCategory === modelData.id) ? Color.accent : Color.muted
          }
        }
      }

      Item { Layout.fillWidth: true }

      Text {
        text: root.filteredBindings.length + " matching"
        font.family: Style.font.family
        font.pixelSize: 11
        color: Color.muted
      }
    }

    // Keybindings List
    ScrollView {
      id: shortcutsScroll
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true
      ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
      ScrollBar.vertical.policy: ScrollBar.AsNeeded

      ColumnLayout {
        width: Math.max(200, parent.width - 12)
        spacing: 6

        // Empty state
        Rectangle {
          visible: root.filteredBindings.length === 0
          Layout.fillWidth: true
          Layout.preferredHeight: 120
          radius: Style.cornerRadius || 8
          color: Color.pickAlpha("surface.subtle", "#181b1d")

          ColumnLayout {
            anchors.centerIn: parent
            spacing: 6

            Text {
              Layout.alignment: Qt.AlignHCenter
              text: "󰌌"
              font.family: Style.font.family
              font.pixelSize: 26
              color: Color.muted
            }

            Text {
              Layout.alignment: Qt.AlignHCenter
              text: "No shortcuts match \"" + root.searchQuery + "\""
              font.family: Style.font.family
              font.pixelSize: 13
              font.bold: true
              color: Color.foreground
            }

            Button {
              Layout.alignment: Qt.AlignHCenter
              text: "Clear Search Filter"
              onClicked: searchField.text = ""
            }
          }
        }

        // Bindings Items
        Repeater {
          model: root.filteredBindings

          delegate: Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            radius: 6
            color: Color.pickAlpha("surface.subtle", "#181b1d")
            border.color: Color.pickAlpha("border.subtle", "#262b30")
            border.width: 1

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 14
              anchors.rightMargin: 14
              spacing: 12

              // Category Indicator Dot
              Rectangle {
                width: 6
                height: 6
                radius: 3
                color: modelData.category === "windows" ? "#85c1dc"
                  : (modelData.category === "apps" ? "#a6d189"
                  : (modelData.category === "workspaces" ? "#e5c890"
                  : (modelData.category === "media" ? "#f4b8e4" : Color.accent)))
              }

              // Description
              Text {
                text: modelData.desc
                font.family: Style.font.family
                font.pixelSize: 13
                font.bold: true
                color: Color.foreground
                elide: Text.ElideRight
                Layout.preferredWidth: 260
              }

              Item { Layout.fillWidth: true }

              // Keyboard Sequence Badge
              Rectangle {
                Layout.preferredHeight: 24
                Layout.preferredWidth: keyText.implicitWidth + 16
                radius: 4
                color: Color.pickAlpha("surface.hover", "#22272c")
                border.color: Color.pickAlpha("border.subtle", "#30363d")
                border.width: 1

                Text {
                  id: keyText
                  anchors.centerIn: parent
                  text: modelData.keys
                  font.family: Style.font.monospace || Style.font.family
                  font.pixelSize: 11
                  font.bold: true
                  color: Color.accent
                }
              }
            }
          }
        }

        Item { Layout.fillHeight: true }
      }
    }
  }
}
