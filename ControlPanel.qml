import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool closingFromHost: false
  property string currentCategory: "search"
  property string focusSection: "content" // "sidebar" or "content"
  readonly property string pluginPath: manifest && manifest.__sourceDir ? manifest.__sourceDir : "/home/ac/.config/omarchy/plugins/ac.control-panel"

  readonly property var categories: [
    { id: "search", label: "Search & Overview", icon: "", key: "S" },
    { id: "displays", label: "Displays", icon: "󰍹", key: "1" },
    { id: "power", label: "Power & Battery", icon: "󰂄", key: "2" },
    { id: "appearance", label: "Appearance", icon: "", key: "3" },
    { id: "sound", label: "Sound", icon: "󰕾", key: "4" },
    { id: "network", label: "Network & Wi-Fi", icon: "󰤨", key: "5" },
    { id: "bluetooth", label: "Bluetooth", icon: "󰂯", key: "6" },
    { id: "input", label: "Touch & Input", icon: "󰆽", key: "7" },
    { id: "windows", label: "Window Manager", icon: "", key: "8" },
    { id: "defaults", label: "Default Apps", icon: "󰌢", key: "9" },
    { id: "updates", label: "Updates & Storage", icon: "󰚰", key: "U" },
    { id: "notifications", label: "Notifications", icon: "󰂚", key: "N" },
    { id: "shortcuts", label: "Shortcuts & Keys", icon: "󰌌", key: "K" },
    { id: "agents", label: "AI & Agents", icon: "󰚩", key: "A" },
    { id: "region", label: "Time & Language", icon: "󰅐", key: "L" },
    { id: "about", label: "About System", icon: "", key: "0" }
  ]

  function open(payloadJson) {
    closingFromHost = false
    window.visible = true
    if (payloadJson) {
      try {
        var parsed = JSON.parse(String(payloadJson))
        if (parsed && typeof parsed.category === "string") {
          currentCategory = parsed.category
          focusSection = (parsed.category === "search") ? "content" : "sidebar"
        }
      } catch (e) {}
    } else {
      currentCategory = "search"
      focusSection = "content"
    }
    if (categoryLoader.item && typeof categoryLoader.item.refresh === "function") {
      categoryLoader.item.refresh()
    }
    Qt.callLater(function() {
      if (root.focusSection === "sidebar" && keyCatcher) {
        keyCatcher.forceActiveFocus()
      } else if (root.focusSection === "content" && categoryLoader.item && categoryLoader.item.searchField) {
        categoryLoader.item.searchField.forceActiveFocus()
      }
    })
  }

  function close() {
    closingFromHost = true
    window.visible = false
    closingFromHost = false
  }

  function dismiss() {
    if (root.shell && typeof root.shell.hide === "function") {
      root.shell.hide((root.manifest && root.manifest.id) || "ac.control-panel")
    } else {
      close()
    }
  }

  function cycleCategory(delta) {
    var ids = categories.map(function(c) { return c.id })
    var idx = ids.indexOf(currentCategory)
    if (idx < 0) idx = 0
    var nextIdx = (idx + delta + ids.length) % ids.length
    currentCategory = ids[nextIdx]
    ensureSidebarCategoryVisible(nextIdx)
  }

  function ensureSidebarCategoryVisible(index) {
    if (!sidebarScroll || !sidebarScroll.contentItem) return
    var itemY = index * 50
    var flick = sidebarScroll.contentItem
    if (itemY < flick.contentY) {
      flick.contentY = Math.max(0, itemY)
    } else if (itemY + 44 > flick.contentY + sidebarScroll.height) {
      flick.contentY = Math.max(0, itemY + 44 - sidebarScroll.height)
    }
  }

  onCurrentCategoryChanged: {
    var ids = categories.map(function(c) { return c.id })
    var idx = ids.indexOf(currentCategory)
    if (idx >= 0) ensureSidebarCategoryVisible(idx)
  }

  function navigateToSetting(categoryId, cardIndex) {
    currentCategory = categoryId
    focusSection = "content"
    Qt.callLater(function() {
      if (categoryLoader.item) {
        if ("focusedCard" in categoryLoader.item) {
          categoryLoader.item.focusedCard = cardIndex
        } else if ("focusedRow" in categoryLoader.item) {
          categoryLoader.item.focusedRow = cardIndex
        }
        if (typeof categoryLoader.item.ensureCardVisible === "function") {
          categoryLoader.item.ensureCardVisible(cardIndex)
        }
      }
    })
  }

  function returnFocusToKeyCatcher() {
    if (keyCatcher) keyCatcher.forceActiveFocus()
  }

  FloatingWindow {
    id: window
    title: "Control Panel"
    color: Color.background
    implicitWidth: 880
    implicitHeight: 640
    minimumSize: Qt.size(760, 520)

    onVisibleChanged: {
      if (visible) {
        Qt.callLater(function() {
          if (root.focusSection === "sidebar" && keyCatcher) {
            keyCatcher.forceActiveFocus()
          } else if (root.focusSection === "content" && categoryLoader.item && categoryLoader.item.searchField) {
            categoryLoader.item.searchField.forceActiveFocus()
          }
        })
      } else if (!root.closingFromHost && root.shell && typeof root.shell.hide === "function") {
        root.shell.hide((root.manifest && root.manifest.id) || "ac.control-panel")
      }
    }

    Item {
      id: scrollKeyHandler
      Keys.onPressed: function(event) {
        if (categoryLoader.item && categoryLoader.item.hasActiveInput === true) return

        var targetScroll = null
        if (root.focusSection === "sidebar") {
          targetScroll = sidebarScroll
        } else if (categoryLoader.item) {
          if (categoryLoader.item.scrollArea) targetScroll = categoryLoader.item.scrollArea
          else if (categoryLoader.item.themesScroll) targetScroll = categoryLoader.item.themesScroll
          else if (categoryLoader.item.resultsScroll) targetScroll = categoryLoader.item.resultsScroll
          else if (categoryLoader.item.shortcutsScroll) targetScroll = categoryLoader.item.shortcutsScroll
          else if (categoryLoader.item.updatesScroll) targetScroll = categoryLoader.item.updatesScroll
        }

        if (!targetScroll || !targetScroll.contentItem) return
        var flick = targetScroll.contentItem
        var pageStep = Math.max(120, targetScroll.height * 0.7)
        var maxScroll = Math.max(0, flick.contentHeight - flick.height)

        if (event.key === Qt.Key_PageDown) {
          flick.contentY = Math.max(0, Math.min(maxScroll, flick.contentY + pageStep))
          event.accepted = true
        } else if (event.key === Qt.Key_PageUp) {
          flick.contentY = Math.max(0, Math.min(maxScroll, flick.contentY - pageStep))
          event.accepted = true
        } else if (event.key === Qt.Key_Home && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier))) {
          flick.contentY = 0
          if (root.focusSection === "sidebar") {
            root.cycleCategory(-100)
          } else if (categoryLoader.item && "focusedCard" in categoryLoader.item) {
            categoryLoader.item.focusedCard = 0
          } else if (categoryLoader.item && "focusedRow" in categoryLoader.item) {
            categoryLoader.item.focusedRow = 0
          } else if (categoryLoader.item && "focusedIndex" in categoryLoader.item) {
            categoryLoader.item.focusedIndex = 0
          }
          event.accepted = true
        } else if (event.key === Qt.Key_End && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier))) {
          flick.contentY = maxScroll
          if (root.focusSection === "sidebar") {
            root.cycleCategory(100)
          } else if (categoryLoader.item && "focusedCard" in categoryLoader.item) {
            categoryLoader.item.focusedCard = 999
          }
          event.accepted = true
        }
      }
    }

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      Keys.forwardTo: [scrollKeyHandler]
      blocked: categoryLoader.item && categoryLoader.item.hasActiveInput === true

      onCloseRequested: root.dismiss()

      onTabRequested: function(direction) {
        if (root.focusSection === "sidebar") {
          root.focusSection = "content"
        } else {
          root.focusSection = "sidebar"
        }
      }

      onMoveRequested: function(dx, dy) {
        if (root.focusSection === "sidebar") {
          if (dy !== 0) {
            root.cycleCategory(dy)
          } else if (dx > 0) {
            root.focusSection = "content"
          }
        } else {
          if (categoryLoader.item && typeof categoryLoader.item.handleMove === "function") {
            categoryLoader.item.handleMove(dx, dy)
          }
        }
      }

      onTextKey: function(key) {
        if (root.focusSection === "content" && categoryLoader.item && typeof categoryLoader.item.handleTextKey === "function") {
          var handled = categoryLoader.item.handleTextKey(key)
          if (handled === true) return
        }

        if (root.focusSection === "sidebar") {
          if (key === "s" || key === "S" || key === "/") { root.currentCategory = "search"; root.focusSection = "content" }
          else if (key === "1") { root.currentCategory = "displays" }
          else if (key === "2") { root.currentCategory = "power" }
          else if (key === "3") { root.currentCategory = "appearance" }
          else if (key === "4") { root.currentCategory = "sound" }
          else if (key === "5") { root.currentCategory = "network" }
          else if (key === "6") { root.currentCategory = "bluetooth" }
          else if (key === "7") { root.currentCategory = "input" }
          else if (key === "8") { root.currentCategory = "windows" }
          else if (key === "9") { root.currentCategory = "defaults" }
          else if (key === "u" || key === "U") { root.currentCategory = "updates" }
          else if (key === "n" || key === "N") { root.currentCategory = "notifications" }
          else if (key === "k" || key === "K") { root.currentCategory = "shortcuts" }
          else if (key === "a" || key === "A") { root.currentCategory = "agents" }
          else if (key === "l" || key === "L") { root.currentCategory = "region" }
          else if (key === "0") { root.currentCategory = "about" }
        } else if (root.focusSection === "content" && categoryLoader.item && typeof categoryLoader.item.handleTextKey === "function") {
          categoryLoader.item.handleTextKey(key)
        }
      }

      onActivateRequested: {
        if (root.focusSection === "sidebar") {
          root.focusSection = "content"
        } else {
          if (categoryLoader.item && typeof categoryLoader.item.handleActivate === "function") {
            categoryLoader.item.handleActivate()
          }
        }
      }

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12

        // Window Header
        RowLayout {
          Layout.fillWidth: true
          spacing: 12

          Text {
            text: "󰘵"
            font.family: Style.font.family
            font.pixelSize: Style.font.title || 18
            color: Color.accent
          }

          Text {
            text: "Control Panel"
            font.family: Style.font.family
            font.pixelSize: Style.font.title || 18
            font.bold: true
            color: Color.foreground
          }

          Item { Layout.fillWidth: true }

          // Active Panel Indicator & Switcher Pills
          RowLayout {
            spacing: 6

            Rectangle {
              height: 24
              width: 82
              radius: 12
              color: root.focusSection === "sidebar"
                ? Color.pickAlpha("accent.subtle", "#203a30")
                : Color.pickAlpha("surface.subtle", "#181b1d")
              border.color: root.focusSection === "sidebar" ? Color.accent : "transparent"
              border.width: 1

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.focusSection = "sidebar"
              }

              Text {
                anchors.centerIn: parent
                text: "󰁥 Sidebar"
                font.family: Style.font.family
                font.pixelSize: 11
                font.bold: root.focusSection === "sidebar"
                color: root.focusSection === "sidebar" ? Color.accent : Color.muted
              }
            }

            Rectangle {
              height: 24
              width: 88
              radius: 12
              color: root.focusSection === "content"
                ? Color.pickAlpha("accent.subtle", "#203a30")
                : Color.pickAlpha("surface.subtle", "#181b1d")
              border.color: root.focusSection === "content" ? Color.accent : "transparent"
              border.width: 1

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.focusSection = "content"
              }

              Text {
                anchors.centerIn: parent
                text: "Settings 󰁤"
                font.family: Style.font.family
                font.pixelSize: 11
                font.bold: root.focusSection === "content"
                color: root.focusSection === "content" ? Color.accent : Color.muted
              }
            }
          }

          Button {
            text: "✕"
            onClicked: root.dismiss()
          }
        }

        Rectangle {
          Layout.fillWidth: true
          height: 1
          color: Color.muted
          opacity: 0.25
        }

        // Main content area: Sidebar + Details View
        RowLayout {
          id: mainRow
          Layout.fillWidth: true
          Layout.preferredWidth: 0
          Layout.maximumWidth: parent.width
          Layout.fillHeight: true
          spacing: 16

          // Left Sidebar (Touch-scrollable)
          ScrollView {
            id: sidebarScroll
            Layout.preferredWidth: 220
            Layout.fillHeight: true
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            ColumnLayout {
              width: Math.max(200, sidebarScroll.availableWidth - 8)
              spacing: 6

              Repeater {
                model: root.categories

                delegate: Rectangle {
                  Layout.fillWidth: true
                  Layout.preferredHeight: 44
                  radius: Style.cornerRadius || 6
                  color: (root.currentCategory === modelData.id)
                    ? (root.focusSection === "sidebar" ? Color.pickAlpha("surface.selected", "#2a3036") : Color.pickAlpha("surface.subtle", "#20252b"))
                    : (mouseArea.containsMouse ? Color.pickAlpha("surface.hover", "#1b1f23") : "transparent")
                  border.color: (root.currentCategory === modelData.id)
                    ? (root.focusSection === "sidebar" ? Color.accent : Color.pickAlpha("accent.subtle", "#40ffffff"))
                    : "transparent"
                  border.width: (root.currentCategory === modelData.id && root.focusSection === "sidebar") ? 2 : 1

                  // Accent bar when sidebar has focus
                  Rectangle {
                    width: 3
                    height: 22
                    radius: 2
                    color: Color.accent
                    anchors.left: parent.left
                    anchors.leftMargin: 3
                    anchors.verticalCenter: parent.verticalCenter
                    visible: (root.currentCategory === modelData.id) && (root.focusSection === "sidebar")
                  }

                  MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      root.currentCategory = modelData.id
                      root.focusSection = "sidebar"
                    }
                  }

                  RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    Text {
                      text: modelData.icon
                      font.family: Style.font.family
                      font.pixelSize: 16
                      color: (root.currentCategory === modelData.id) ? Color.accent : Color.muted
                    }

                    Text {
                      Layout.fillWidth: true
                      text: modelData.label
                      font.family: Style.font.family
                      font.pixelSize: Style.font.body || 13
                      font.bold: (root.currentCategory === modelData.id)
                      color: Color.foreground
                    }

                    Rectangle {
                      width: 18
                      height: 18
                      radius: 3
                      color: Color.pickAlpha("surface.subtle", "#121416")

                      Text {
                        anchors.centerIn: parent
                        text: modelData.key
                        font.family: Style.font.family
                        font.pixelSize: 10
                        color: Color.muted
                      }
                    }
                  }
                }
              }

              Item { Layout.fillHeight: true }
            }
          }

          Rectangle {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            color: Color.muted
            opacity: 0.2
          }

          // Right Panel View
          Rectangle {
            id: rightPanelView
            Layout.fillWidth: true
            Layout.preferredWidth: 0
            Layout.minimumWidth: 460
            Layout.fillHeight: true
            clip: true
            color: "transparent"

            DragHandler {
              id: touchSwipeHandler
              target: null
              xAxis.enabled: true
              yAxis.enabled: false
              dragThreshold: 50
              onActiveChanged: {
                if (!active) {
                  if (translation.x < -dragThreshold) {
                    root.cycleCategory(1)
                  } else if (translation.x > dragThreshold) {
                    root.cycleCategory(-1)
                  }
                }
              }
            }

            MouseArea {
              anchors.fill: parent
              onPressed: root.focusSection = "content"
            }

            ColumnLayout {
              anchors.fill: parent
              spacing: 12

              RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                  Layout.fillWidth: true
                  text: {
                    for (var i = 0; i < root.categories.length; i++) {
                      if (root.categories[i].id === root.currentCategory)
                        return root.categories[i].label
                    }
                    return "Settings"
                  }
                  font.family: Style.font.family
                  font.pixelSize: Style.font.subtitle || 16
                  font.bold: true
                  color: Color.foreground
                }

                Rectangle {
                  Layout.preferredHeight: 22
                  Layout.preferredWidth: navHintText.implicitWidth + 12
                  radius: 4
                  visible: root.currentCategory !== "search" && rightPanelView.width > 300
                  color: Color.pickAlpha("surface.subtle", "#181b1d")

                  Text {
                    id: navHintText
                    anchors.centerIn: parent
                    text: "◄ Swipe tabs ►"
                    font.family: Style.font.family
                    font.pixelSize: 10
                    color: Color.muted
                  }
                }
              }

              Loader {
                id: categoryLoader
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                Layout.fillHeight: true

                source: {
                  if (root.currentCategory === "search") return "views/SearchView.qml"
                  if (root.currentCategory === "displays") return "views/DisplaysView.qml"
                  if (root.currentCategory === "power") return "views/PowerView.qml"
                  if (root.currentCategory === "appearance") return "views/AppearanceView.qml"
                  if (root.currentCategory === "sound") return "views/SoundView.qml"
                  if (root.currentCategory === "network") return "views/NetworkView.qml"
                  if (root.currentCategory === "bluetooth") return "views/BluetoothView.qml"
                  if (root.currentCategory === "input") return "views/TouchInputView.qml"
                  if (root.currentCategory === "windows") return "views/WindowManagerView.qml"
                  if (root.currentCategory === "defaults") return "views/DefaultsView.qml"
                  if (root.currentCategory === "updates") return "views/UpdatesStorageView.qml"
                  if (root.currentCategory === "notifications") return "views/NotificationsView.qml"
                  if (root.currentCategory === "shortcuts") return "views/ShortcutsView.qml"
                  if (root.currentCategory === "agents") return "views/AgentsView.qml"
                  if (root.currentCategory === "region") return "views/TimeLanguageView.qml"
                  if (root.currentCategory === "about") return "views/AboutView.qml"
                  return ""
                }

                onLoaded: {
                  if (item) {
                    item.width = Qt.binding(function() { return categoryLoader.width })
                    item.height = Qt.binding(function() { return categoryLoader.height })
                  }
                  if (item && "pluginPath" in item) {
                    item.pluginPath = root.pluginPath
                  }
                  if (item && "activeFocusSection" in item) {
                    item.activeFocusSection = Qt.binding(function() { return root.focusSection === "content" })
                  }
                  if (item && "panelRoot" in item) {
                    item.panelRoot = root
                  }
                  if (item && typeof item.refresh === "function") {
                    item.refresh()
                  }
                }

                Rectangle {
                  anchors.fill: parent
                  visible: categoryLoader.status !== Loader.Ready
                  color: Color.pickAlpha("surface.subtle", "#181b1d")
                  radius: Style.cornerRadius || 8

                  Text {
                    anchors.centerIn: parent
                    text: "Loading " + root.currentCategory + "..."
                    color: Color.muted
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body || 13
                  }
                }
              }
            }
          }
        }

        // Bottom Keyboard Hints Footer
        Rectangle {
          Layout.fillWidth: true
          height: 1
          color: Color.muted
          opacity: 0.2
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: 12

          Text {
            text: "⌨ Shortcuts: [Tab] Switch Panels  •  [↑/↓ or j/k] Select Setting  •  [Enter/Space] Activate  •  [S or /] Search  •  [0-9/U/N/K/A/L] Categories  •  [Esc] Close"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.muted
          }

          Item { Layout.fillWidth: true }
        }
      }
    }
  }
}
