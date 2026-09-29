import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Item {
  id: root

  property string pluginPath: ""
  property string currentTheme: "Tokyo Night"
  property var themes: []

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
          if (Array.isArray(data.themes)) root.themes = data.themes
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

  ScrollView {
    anchors.fill: parent
    clip: true

    ColumnLayout {
      width: parent.width - 24
      spacing: 16

      // Header card
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 76
        color: Color.pickAlpha("surface.subtle", "#181b1d")
        radius: Style.cornerRadius || 8

        RowLayout {
          anchors.fill: parent
          anchors.margins: 14
          spacing: 14

          Rectangle {
            width: 44
            height: 44
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
                text: "Current Theme: " + root.currentTheme
                font.family: Style.font.family
                font.pixelSize: Style.font.title || 16
                font.bold: true
                color: Color.foreground
              }

              Rectangle {
                width: 54
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
              text: "Click any theme below to apply desktop styling live."
              font.family: Style.font.family
              font.pixelSize: Style.font.subtext || 12
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

      // Theme Grid
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 380
        color: Color.pickAlpha("surface.subtle", "#181b1d")
        radius: Style.cornerRadius || 8

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 14
          spacing: 12

          Text {
            text: "Installed Desktop Themes (" + root.themes.length + ")"
            font.family: Style.font.family
            font.pixelSize: Style.font.subtitle || 14
            font.bold: true
            color: Color.foreground
          }

          ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            GridLayout {
              width: parent.width - 12
              columns: 3
              rowSpacing: 10
              columnSpacing: 10

              Repeater {
                model: root.themes

                delegate: Rectangle {
                  Layout.fillWidth: true
                  Layout.preferredHeight: 46
                  radius: 6
                  color: (root.currentTheme.toLowerCase() === modelData.toLowerCase())
                    ? Color.pickAlpha("surface.selected", "#2a3036")
                    : Color.pickAlpha("surface.hover", "#1f2327")
                  border.color: (root.currentTheme.toLowerCase() === modelData.toLowerCase()) ? Color.accent : "transparent"
                  border.width: 1

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.setTheme(modelData)
                  }

                  RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    Rectangle {
                      width: 12
                      height: 12
                      radius: 6
                      color: (root.currentTheme.toLowerCase() === modelData.toLowerCase()) ? Color.accent : Color.muted
                    }

                    Text {
                      Layout.fillWidth: true
                      text: modelData
                      font.family: Style.font.family
                      font.pixelSize: Style.font.body || 13
                      font.bold: (root.currentTheme.toLowerCase() === modelData.toLowerCase())
                      color: Color.foreground
                      elide: Text.ElideRight
                    }

                    Text {
                      visible: (root.currentTheme.toLowerCase() === modelData.toLowerCase())
                      text: "✓"
                      font.family: Style.font.family
                      font.pixelSize: 13
                      color: Color.accent
                    }
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
