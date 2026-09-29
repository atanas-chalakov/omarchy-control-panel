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
    { id: "displays", label: "Displays", icon: "󰍹" },
    { id: "power", label: "Power & Battery", icon: "󰂄" },
    { id: "appearance", label: "Appearance", icon: "" },
    { id: "sound", label: "Sound", icon: "󰕾" },
    { id: "network", label: "Network", icon: "󰛳" },
    { id: "about", label: "About System", icon: "" }
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

  FloatingWindow {
    id: window
    title: "Control Panel"
    color: Color.background
    implicitWidth: 840
    implicitHeight: 580
    minimumSize: Qt.size(680, 480)

    onVisibleChanged: {
      if (!visible && !root.closingFromHost && root.shell && typeof root.shell.hide === "function") {
        root.shell.hide((root.manifest && root.manifest.id) || "ac.control-panel")
      }
    }

    Item {
      anchors.fill: parent
      focus: true

      Keys.onEscapePressed: function(event) {
        root.dismiss()
        event.accepted = true
      }

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 14

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

        // Main content area: Sidebar + Details
        RowLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: 16

          // Left Sidebar
          Rectangle {
            Layout.preferredWidth: 200
            Layout.fillHeight: true
            color: "transparent"

            ColumnLayout {
              anchors.fill: parent
              spacing: 6

              Repeater {
                model: root.categories

                delegate: Button {
                  Layout.fillWidth: true
                  text: modelData.label
                  iconText: modelData.icon
                  selected: root.currentCategory === modelData.id
                  onClicked: root.currentCategory = modelData.id
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
                  return ""
                }

                onLoaded: {
                  if (item && "pluginPath" in item) {
                    item.pluginPath = root.pluginPath
                  }
                }

                Rectangle {
                  anchors.fill: parent
                  visible: categoryLoader.status !== Loader.Ready
                  color: Color.pickAlpha("surface.subtle", "#181b1d")
                  radius: Style.cornerRadius || 8

                  Text {
                    anchors.centerIn: parent
                    text: "Configure " + root.currentCategory + " settings here."
                    color: Color.muted
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body || 13
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
