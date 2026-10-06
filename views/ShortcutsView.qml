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
  readonly property bool isContentFocused: panelRoot ? panelRoot.focusSection === "content" : activeFocusSection
  property bool hasActiveInput: searchField.activeFocus
  property string statusMessage: ""

  onActiveFocusSectionChanged: {
    if (!activeFocusSection) {
      blurInput()
    }
  }

  function focusToInput() {
    if (searchField) {
      searchField.forceActiveFocus()
    }
  }

  function blurInput() {
    if (searchField) {
      searchField.focus = false
    }
  }
  property string searchQuery: ""
  property string activeCategory: "all" // "all", "windows", "apps", "workspaces", "media", "system"

  property int totalCount: 0
  property var allBindings: []
  property var filteredBindings: []
  property bool isRefreshing: false
  property int focusedIndex: 0
  onFocusedIndexChanged: ensureShortcutVisible(focusedIndex)

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
    if (focusedIndex >= res.length) {
      focusedIndex = Math.max(0, res.length - 1)
    }
  }

  onSearchQueryChanged: updateFiltered()
  onActiveCategoryChanged: updateFiltered()

  function ensureShortcutVisible(index) {
    if (!shortcutsScroll || !shortcutsScroll.contentItem || !bindingsRepeater) return
    var item = bindingsRepeater.itemAt(index)
    if (item && item.visible) {
      var flick = shortcutsScroll.contentItem
      var pos = item.mapToItem(shortcutsScroll, 0, 0)
      var maxScroll = Math.max(0, flick.contentHeight - flick.height)
      if (pos.y < 8) {
        flick.contentY = Math.max(0, Math.min(maxScroll, flick.contentY + pos.y - 8))
      } else if (pos.y + item.height > shortcutsScroll.height - 8) {
        flick.contentY = Math.max(0, Math.min(maxScroll, flick.contentY + (pos.y + item.height - shortcutsScroll.height + 8)))
      }
    }
  }

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

  function copyToClipboard(keys) {
    if (!keys) return
    actionProcess.command = ["sh", "-c", "printf '%s' \"" + keys.replace(/"/g, '\\"') + "\" | wl-copy"]
    actionProcess.running = true
    notifyStatus("Copied to clipboard: " + keys)
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
      if (filteredBindings.length > 0) {
        focusedIndex = Math.max(0, Math.min(filteredBindings.length - 1, focusedIndex + dy))
        ensureShortcutVisible(focusedIndex)
        return true
      }
      return false
    } else if (dx !== 0) {
      var ids = categoryList.map(function(c) { return c.id })
      var idx = ids.indexOf(activeCategory)
      if (idx < 0) idx = 0
      if (dx < 0 && idx === 0) return false
      var nextIdx = Math.max(0, Math.min(ids.length - 1, idx + (dx > 0 ? 1 : -1)))
      if (nextIdx === idx) return false
      activeCategory = ids[nextIdx]
      return true
    }
    return false
  }

  function handleActivate() {
    if (focusedIndex >= 0 && focusedIndex < filteredBindings.length) {
      var item = filteredBindings[focusedIndex]
      if (item && item.keys) {
        copyToClipboard(item.keys)
        return
      }
    }
    openMenu()
  }

  function handleTextKey(key) {
    if (hasActiveInput) return false

    var k = key.toLowerCase()
    if (k === "h") {
      return handleMove(-1, 0)
    } else if (k === "l") {
      return handleMove(1, 0)
    } else if (k === "j") {
      return handleMove(0, 1)
    } else if (k === "k") {
      return handleMove(0, -1)
    } else if (k === "m") {
      openMenu()
      return true
    } else if (k === "e") {
      openConfig()
      return true
    } else if (k === "r") {
      refresh()
      notifyStatus("Refreshed keybindings")
      return true
    } else if (k === "s") {
      searchField.forceActiveFocus()
      return true
    } else if (key === "1") {
      activeCategory = "all"
      return true
    } else if (key === "2") {
      activeCategory = "windows"
      return true
    } else if (key === "3") {
      activeCategory = "apps"
      return true
    } else if (key === "4") {
      activeCategory = "workspaces"
      return true
    } else if (key === "5") {
      activeCategory = "media"
      return true
    } else if (key === "6") {
      activeCategory = "system"
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
      color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
      border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60)
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
      id: topBannerCard
      Layout.fillWidth: true
      implicitHeight: Math.max(64, topBannerRow.implicitHeight + 28)
      Layout.preferredHeight: implicitHeight
      radius: Style.cornerRadius || 8
      color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02)
      border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
      border.width: 1

      RowLayout {
        id: topBannerRow
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 14
        spacing: 14

        Rectangle {
          width: 36
          height: 36
          radius: 18
          color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
          border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60)
          border.width: 1

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
          Layout.preferredWidth: 0
          Layout.minimumWidth: 0
          spacing: 2

          Flow {
            Layout.fillWidth: true
            width: parent.width
            spacing: 8

            Text {
              text: "Shortcuts & Keybindings"
              font.family: Style.font.family
              font.pixelSize: 15
              font.bold: true
              color: Color.foreground
            }

            Rectangle {
              width: countText.implicitWidth + 12
              height: 18
              radius: 9
              color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
              border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60)
              border.width: 1

              Text {
                id: countText
                anchors.centerIn: parent
                text: root.totalCount + " bindings"
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
            text: "Browse, filter, and customize Hyprland shortcuts in ~/.config/hypr/bindings.lua"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.muted
          }
        }

        Rectangle {
          id: searchMenuBtn
          implicitWidth: searchMenuText.implicitWidth + 20
          implicitHeight: 28
          radius: 6
          readonly property bool btnHover: searchMenuMouse.containsMouse
          color: btnHover ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.10) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.05)
          border.color: btnHover ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.30) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
          border.width: 1

          Text {
            id: searchMenuText
            anchors.centerIn: parent
            text: "󰍉 Search Menu [M]"
            font.family: Style.font.family
            font.pixelSize: 11
            font.bold: true
            color: parent.btnHover ? Color.foreground : Color.muted
          }

          MouseArea {
            id: searchMenuMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openMenu()
          }
        }

        Rectangle {
          id: editConfigBtn
          implicitWidth: editConfigText.implicitWidth + 20
          implicitHeight: 28
          radius: 6
          readonly property bool btnHover: editConfigMouse.containsMouse
          color: btnHover ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.10) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.05)
          border.color: btnHover ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.30) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
          border.width: 1

          Text {
            id: editConfigText
            anchors.centerIn: parent
            text: "󰏫 Edit Config [E]"
            font.family: Style.font.family
            font.pixelSize: 11
            font.bold: true
            color: parent.btnHover ? Color.foreground : Color.muted
          }

          MouseArea {
            id: editConfigMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openConfig()
          }
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
        color: searchField.activeFocus
          ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
          : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.03)
        border.color: searchField.activeFocus ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
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
            placeholderText: "Type to search shortcuts... (e.g. terminal, window, close, super+q) [S]"
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

            Keys.onTabPressed: function(event) {
              event.accepted = true
              searchField.focus = false
              if (panelRoot && typeof panelRoot.toggleFocusSection === "function") {
                panelRoot.toggleFocusSection()
              } else if (panelRoot) {
                panelRoot.focusSection = "sidebar"
                if (typeof panelRoot.returnFocusToKeyCatcher === "function") {
                  panelRoot.returnFocusToKeyCatcher()
                }
              }
            }

            Keys.onBacktabPressed: function(event) {
              event.accepted = true
              searchField.focus = false
              if (panelRoot && typeof panelRoot.toggleFocusSection === "function") {
                panelRoot.toggleFocusSection()
              } else if (panelRoot) {
                panelRoot.focusSection = "sidebar"
                if (typeof panelRoot.returnFocusToKeyCatcher === "function") {
                  panelRoot.returnFocusToKeyCatcher()
                }
              }
            }
          }

          Rectangle {
            visible: searchField.text.length > 0
            width: 22
            height: 22
            radius: 11
            color: clearMouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)

            Text {
              anchors.centerIn: parent
              text: "✕"
              font.pixelSize: 10
              color: Color.muted
            }

            MouseArea {
              id: clearMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: searchField.text = ""
            }
          }
        }
      }
    }

    // Category Tabs Row
    Flow {
      Layout.fillWidth: true
      width: parent.width
      spacing: 6

      Repeater {
        model: root.categoryList

        delegate: Rectangle {
          id: catPill
          height: 28
          width: catRow.implicitWidth + 20
          radius: 14
          readonly property bool isActive: root.activeCategory === modelData.id
          readonly property bool isHovered: catMouse.containsMouse

          color: isActive
            ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, isHovered ? 0.28 : 0.20)
            : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04))
          border.color: isActive
            ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60)
            : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12))
          border.width: 1

          MouseArea {
            id: catMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (root.panelRoot) root.panelRoot.focusSection = "content"
              root.activeCategory = modelData.id
            }
          }

          RowLayout {
            id: catRow
            anchors.centerIn: parent
            spacing: 5

            Rectangle {
              visible: catPill.isActive
              width: 5
              height: 5
              radius: 2.5
              color: Color.accent
            }

            Text {
              id: catText
              text: modelData.label
              font.family: Style.font.family
              font.pixelSize: 11
              font.bold: catPill.isActive
              color: catPill.isActive ? Color.accent : (catPill.isHovered ? Color.foreground : Color.muted)
            }
          }
        }
      }

      Text {
        topPadding: 5
        leftPadding: 4
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
        width: Math.max(200, shortcutsScroll.availableWidth - 12)
        spacing: 6

        // Empty state
        Rectangle {
          visible: root.filteredBindings.length === 0
          Layout.fillWidth: true
          Layout.preferredHeight: 120
          radius: Style.cornerRadius || 8
          color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02)
          border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
          border.width: 1

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

            Rectangle {
              Layout.alignment: Qt.AlignHCenter
              implicitWidth: clearSearchText.implicitWidth + 20
              implicitHeight: 28
              radius: 6
              readonly property bool btnHover: clearSearchMouse.containsMouse
              color: btnHover ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.10) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.05)
              border.color: btnHover ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.30) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
              border.width: 1

              Text {
                id: clearSearchText
                anchors.centerIn: parent
                text: "Clear Search Filter"
                font.family: Style.font.family
                font.pixelSize: 11
                color: Color.foreground
              }

              MouseArea {
                id: clearSearchMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: searchField.text = ""
              }
            }
          }
        }

        // Bindings Items
        Repeater {
          id: bindingsRepeater
          model: root.filteredBindings

          delegate: Rectangle {
            id: bindingCard
            Layout.fillWidth: true
            implicitHeight: Math.max(42, bindingRowLayout.implicitHeight + 14)
            Layout.preferredHeight: implicitHeight
            radius: 6
            readonly property bool isFocused: root.isContentFocused && root.focusedIndex === index
            readonly property bool isHovered: bindingMouse.containsMouse

            color: isFocused
              ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
              : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02))
            border.color: isFocused
              ? Color.accent
              : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08))
            border.width: isFocused ? 2 : 1

            MouseArea {
              id: bindingMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (root.panelRoot) root.panelRoot.focusSection = "content"
                root.focusedIndex = index
              }
              onDoubleClicked: {
                root.copyToClipboard(modelData.keys)
              }
            }

            RowLayout {
              id: bindingRowLayout
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.margins: 7
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
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: modelData.desc
                font.family: Style.font.family
                font.pixelSize: 13
                font.bold: isFocused
                color: Color.foreground
                wrapMode: Text.WordWrap
              }

              // Keyboard Sequence Badge
              Rectangle {
                Layout.preferredHeight: 24
                Layout.preferredWidth: keyText.implicitWidth + 16
                radius: 4
                color: isFocused
                  ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
                  : (bindingCard.isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06))
                border.color: isFocused
                  ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60)
                  : (bindingCard.isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12))
                border.width: 1

                Text {
                  id: keyText
                  anchors.centerIn: parent
                  text: modelData.keys
                  font.family: Style.font.monospace || Style.font.family
                  font.pixelSize: 11
                  font.bold: true
                  color: isFocused ? Color.accent : Color.foreground
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
