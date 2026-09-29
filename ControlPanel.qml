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
  property string currentCategory: "displays"
  readonly property string pluginPath: manifest && manifest.__sourceDir ? manifest.__sourceDir : "/home/ac/.config/omarchy/plugins/ac.control-panel"

  readonly property var categories: [
    { id: "displays", label: "Displays", icon: "󰍹", key: "1" },
    { id: "power", label: "Power & Battery", icon: "󰂄", key: "2" },
    { id: "appearance", label: "Appearance", icon: "", key: "3" },
    { id: "sound", label: "Sound", icon: "󰕾", key: "4" },
    { id: "about", label: "About System", icon: "", key: "5" }
  ]

  function open(payloadJson) {
    closingFromHost = false
    window.visible = true
    if (payloadJson) {
      try {
        var parsed = JSON.parse(String(payloadJson))
        if (parsed && typeof parsed.category === "string") {
          currentCategory = parsed.category
        }
      } catch (e) {}
    }
    if (categoryLoader.item && typeof categoryLoader.item.refresh === "function") {
      categoryLoader.item.refresh()
    }
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
  }

  FloatingWindow {
    id: window
    title: "Control Panel"
    color: Color.background
    implicitWidth: 880
    implicitHeight: 620
    minimumSize: Qt.size(720, 520)

    onVisibleChanged: {
      if (!visible && !root.closingFromHost && root.shell && typeof root.shell.hide === "function") {
        root.shell.hide((root.manifest && root.manifest.id) || "ac.control-panel")
      }
    }

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onCloseRequested: root.dismiss()

      onTabRequested: function(direction) {
        root.cycleCategory(direction)
      }

      onMoveRequested: function(dx, dy) {
        if (dy !== 0) {
          root.cycleCategory(dy)
        } else if (dx !== 0) {
          if (categoryLoader.item && typeof categoryLoader.item.handleKeyH === "function") {
            categoryLoader.item.handleKeyH(dx)
          }
        }
      }

      onTextKey: function(key) {
        if (key === "1") root.currentCategory = "displays"
        else if (key === "2") root.currentCategory = "power"
        else if (key === "3") root.currentCategory = "appearance"
        else if (key === "4") root.currentCategory = "sound"
        else if (key === "5") root.currentCategory = "about"
        else if (categoryLoader.item && typeof categoryLoader.item.handleTextKey === "function") {
          categoryLoader.item.handleTextKey(key)
        }
      }

      onActivateRequested: {
        if (categoryLoader.item && typeof categoryLoader.item.handleActivate === "function") {
          categoryLoader.item.handleActivate()
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
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: 16

          // Left Sidebar
          Rectangle {
            Layout.preferredWidth: 220
            Layout.fillHeight: true
            color: "transparent"

            ColumnLayout {
              anchors.fill: parent
              spacing: 6

              Repeater {
                model: root.categories

                delegate: Rectangle {
                  Layout.fillWidth: true
                  Layout.preferredHeight: 44
                  radius: Style.cornerRadius || 6
                  color: (root.currentCategory === modelData.id)
                    ? Color.pickAlpha("surface.selected", "#2a3036")
                    : Color.pickAlpha("surface.hover", "#1b1f23")
                  border.color: (root.currentCategory === modelData.id) ? Color.accent : "transparent"
                  border.width: 1

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.currentCategory = modelData.id
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
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"

            ColumnLayout {
              anchors.fill: parent
              spacing: 12

              Text {
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

              Loader {
                id: categoryLoader
                Layout.fillWidth: true
                Layout.fillHeight: true

                source: {
                  if (root.currentCategory === "displays") return "views/DisplaysView.qml"
                  if (root.currentCategory === "power") return "views/PowerView.qml"
                  if (root.currentCategory === "appearance") return "views/AppearanceView.qml"
                  if (root.currentCategory === "sound") return "views/SoundView.qml"
                  if (root.currentCategory === "about") return "views/AboutView.qml"
                  return ""
                }

                onLoaded: {
                  if (item && "pluginPath" in item) {
                    item.pluginPath = root.pluginPath
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
            text: "⌨ Shortcuts: [1-5] Switch Category  •  [j/k] Navigate  •  [h/l] Adjust Slider  •  [m] Mute  •  [Esc] Close"
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
