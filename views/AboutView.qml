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
  property string osName: "Omarchy"
  property string osVersion: "4.0.4"
  property string kernel: ""
  property string cpu: ""
  property string ram: ""
  property string uptime: ""
  property string hostname: ""
  property string timezone: ""
  property string ntp: ""
  property string statusMessage: ""
  property var backupsList: []
  property bool isBackingUp: false
  property bool isRestoring: false

  property bool activeFocusSection: false
  readonly property bool isContentFocused: panelRoot ? panelRoot.focusSection === "content" : activeFocusSection
  property int focusedRow: 0   // 0: Hero Card, 1: Hardware Specs, 2: Timezone Card, 3: Backups Card
  onFocusedRowChanged: ensureRowVisible(focusedRow)

  function ensureRowVisible(index) {
    if (!scrollArea || !scrollArea.contentItem) return
    var item = null
    if (index === 0) item = heroCard
    else if (index === 1) item = specsCard
    else if (index === 2) item = tzCard
    else if (index === 3) item = backupsCard
    if (item && item.visible) {
      var flick = scrollArea.contentItem
      var pos = item.mapToItem(scrollArea, 0, 0)
      var maxScroll = Math.max(0, flick.contentHeight - flick.height)
      if (pos.y < 12) {
        flick.contentY = Math.max(0, Math.min(maxScroll, flick.contentY + pos.y - 12))
      } else if (pos.y + item.height > scrollArea.height - 12) {
        if (item.height >= scrollArea.height) {
          flick.contentY = Math.max(0, Math.min(maxScroll, flick.contentY + pos.y - 12))
        } else {
          flick.contentY = Math.max(0, Math.min(maxScroll, flick.contentY + (pos.y + item.height - scrollArea.height + 12)))
        }
      }
    }
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
    if (dy !== 0) {
      focusedRow = Math.max(0, Math.min(3, focusedRow + dy))
      return true
    }
    if (dx < 0) return false
    return true
  }

  function handleActivate() {
    if (focusedRow === 0) refresh()
    else if (focusedRow === 2) openTimezonePicker()
    else if (focusedRow === 3) createBackup()
    else refresh()
  }

  function handleTextKey(key) {
    var k = key.toLowerCase()
    if (k === "h") {
      return handleMove(-1, 0)
    } else if (k === "l") {
      return handleMove(1, 0)
    } else if (k === "r") {
      refresh()
      return true
    } else if (k === "t") {
      openTimezonePicker()
      return true
    } else if (k === "b") {
      createBackup()
      return true
    }
    return false
  }

  function openTimezonePicker() {
    notifyStatus("Opening timezone selector...")
    actionProcess.command = [pluginPath + "/scripts/system-control.sh", "about-set-timezone"]
    actionProcess.running = true
  }

  function createBackup() {
    if (isBackingUp) return
    isBackingUp = true
    notifyStatus("Creating configuration snapshot...")
    backupExportProcess.command = [pluginPath + "/scripts/system-control.sh", "backup-export"]
    backupExportProcess.running = true
  }

  function restoreBackup(fname) {
    if (isRestoring) return
    isRestoring = true
    notifyStatus("Restoring configuration: " + fname + "...")
    backupRestoreProcess.command = [pluginPath + "/scripts/system-control.sh", "backup-restore", fname]
    backupRestoreProcess.running = true
  }

  function deleteBackup(fname) {
    notifyStatus("Deleting backup " + fname + "...")
    backupDeleteProcess.command = [pluginPath + "/scripts/system-control.sh", "backup-delete", fname]
    backupDeleteProcess.running = true
  }

  function loadBackups() {
    if (pluginPath.length > 0) {
      backupsListProcess.command = [pluginPath + "/scripts/system-control.sh", "backup-list"]
      backupsListProcess.running = true
    }
  }

  function refresh() {
    if (!stateProcess.running && pluginPath.length > 0) {
      notifyStatus("Refreshed system information")
      stateProcess.command = [pluginPath + "/scripts/system-control.sh", "about-get"]
      stateProcess.running = true
      loadBackups()
    }
  }

  Component.onCompleted: refresh()

  // Action Process
  Process {
    id: actionProcess
  }

  // State Process
  Process {
    id: stateProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var data = JSON.parse(text)
          if (data.os) root.osName = data.os
          if (data.version) root.osVersion = data.version
          if (data.kernel) root.kernel = data.kernel
          if (data.cpu) root.cpu = data.cpu
          if (data.ram) root.ram = data.ram
          if (data.uptime) root.uptime = data.uptime
          if (data.hostname) root.hostname = data.hostname
          if (data.timezone) root.timezone = data.timezone
          if (data.ntp) root.ntp = data.ntp
        } catch (e) {
          console.warn("AboutView: JSON parse error", e)
        }
      }
    }
  }

  // Backup Export Process
  Process {
    id: backupExportProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.isBackingUp = false
        try {
          var res = JSON.parse(text)
          if (res.success) {
            root.notifyStatus("Backup saved: " + (res.filename || "archive created"))
            root.loadBackups()
          } else {
            root.notifyStatus("Backup failed: " + (res.error || "unknown error"))
          }
        } catch (e) {
          root.notifyStatus("Backup finished")
          root.loadBackups()
        }
      }
    }
  }

  // Backups List Process
  Process {
    id: backupsListProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var arr = JSON.parse(text)
          root.backupsList = Array.isArray(arr) ? arr : []
        } catch (e) {
          root.backupsList = []
        }
      }
    }
  }

  // Backup Restore Process
  Process {
    id: backupRestoreProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.isRestoring = false
        try {
          var res = JSON.parse(text)
          if (res.success) {
            root.notifyStatus("Backup restored successfully!")
            root.refresh()
          } else {
            root.notifyStatus("Restore error: " + (res.error || "failed"))
          }
        } catch (e) {
          root.notifyStatus("Restore finished")
          root.refresh()
        }
      }
    }
  }

  // Backup Delete Process
  Process {
    id: backupDeleteProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.notifyStatus("Backup removed")
        root.loadBackups()
      }
    }
  }

  ScrollView {
    id: scrollArea
    anchors.fill: parent
    clip: true
    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
    ScrollBar.vertical.policy: ScrollBar.AsNeeded

    ColumnLayout {
      width: Math.max(200, scrollArea.availableWidth - 12)
      spacing: 16

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

      // Hero Card (Row 0)
      Rectangle {
        id: heroCard
        Layout.fillWidth: true
        implicitHeight: Math.max(90, heroLayout.implicitHeight + 32)
        Layout.preferredHeight: implicitHeight
        radius: Style.cornerRadius || 8
        readonly property bool isFocused: root.isContentFocused && root.focusedRow === 0
        readonly property bool isHovered: heroMouse.containsMouse

        color: isFocused
          ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
          : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02))
        border.color: isFocused
          ? Color.accent
          : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08))
        border.width: isFocused ? 2 : 1

        MouseArea {
          id: heroMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (root.panelRoot) root.panelRoot.focusSection = "content"
            root.focusedRow = 0
          }
        }

        RowLayout {
          id: heroLayout
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 16
          spacing: 16

          Rectangle {
            width: 56
            height: 56
            radius: 12
            color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
            border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60)
            border.width: 1

            Text {
              anchors.centerIn: parent
              text: "󰣇"
              font.family: Style.font.family
              font.pixelSize: 32
              color: Color.accent
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: 4

            Flow {
              Layout.fillWidth: true
              width: parent.width
              spacing: 8
              Text {
                text: root.osName
                font.family: Style.font.family
                font.pixelSize: 20
                font.bold: true
                color: Color.foreground
              }

              Rectangle {
                width: versionText.implicitWidth + 14
                height: 20
                radius: 4
                color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
                border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60)
                border.width: 1

                RowLayout {
                  anchors.centerIn: parent
                  spacing: 4
                  Rectangle {
                    width: 5
                    height: 5
                    radius: 2.5
                    color: Color.accent
                  }
                  Text {
                    id: versionText
                    text: "v" + root.osVersion
                    font.family: Style.font.family
                    font.pixelSize: 11
                    font.bold: true
                    color: Color.accent
                  }
                }
              }
            }

            Text {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              wrapMode: Text.WordWrap
              text: "Arch Linux based • Hyprland compositor • Quickshell desktop"
              font.family: Style.font.family
              font.pixelSize: Style.font.subtext || 12
              color: Color.muted
            }
          }

          Rectangle {
            id: refreshBtn
            implicitWidth: refreshBtnLayout.implicitWidth + 24
            implicitHeight: 30
            radius: 6
            readonly property bool btnHover: refreshBtnMouse.containsMouse
            readonly property bool isBtnFocused: heroCard.isFocused
            color: isBtnFocused
              ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, btnHover ? 0.18 : 0.14)
              : (btnHover ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04))
            border.color: isBtnFocused
              ? Color.accent
              : (btnHover ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12))
            border.width: isBtnFocused ? 2 : 1

            RowLayout {
              id: refreshBtnLayout
              anchors.centerIn: parent
              spacing: 6
              Text {
                text: ""
                font.family: Style.font.family
                font.pixelSize: 13
                color: refreshBtn.isBtnFocused ? Color.accent : (refreshBtn.btnHover ? Color.foreground : Color.muted)
              }
              Text {
                text: "Refresh [R]"
                font.family: Style.font.family
                font.pixelSize: 11
                font.bold: refreshBtn.isBtnFocused
                color: refreshBtn.isBtnFocused ? Color.accent : (refreshBtn.btnHover ? Color.foreground : Color.muted)
              }
            }

            MouseArea {
              id: refreshBtnMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (root.panelRoot) root.panelRoot.focusSection = "content"
                root.focusedRow = 0
                root.refresh()
              }
            }
          }
        }
      }

      // Hardware Specs Card (Row 1)
      Rectangle {
        id: specsCard
        Layout.fillWidth: true
        implicitHeight: Math.max(200, specsLayout.implicitHeight + 32)
        Layout.preferredHeight: implicitHeight
        radius: Style.cornerRadius || 8
        readonly property bool isFocused: root.isContentFocused && root.focusedRow === 1
        readonly property bool isHovered: specsMouse.containsMouse

        color: isFocused
          ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
          : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02))
        border.color: isFocused
          ? Color.accent
          : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08))
        border.width: isFocused ? 2 : 1

        MouseArea {
          id: specsMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (root.panelRoot) root.panelRoot.focusSection = "content"
            root.focusedRow = 1
          }
        }

        ColumnLayout {
          id: specsLayout
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 16
          spacing: 12

          Text {
            text: "󰍹  Hardware & System Details"
            font.family: Style.font.family
            font.pixelSize: Style.font.subtitle || 14
            font.bold: true
            color: specsCard.isFocused ? Color.accent : Color.foreground
          }

          GridLayout {
            Layout.fillWidth: true
            columns: parent.width >= 480 ? 2 : 1
            rowSpacing: 10
            columnSpacing: 20

            // Row 1
            Text {
              text: "Hostname:"
              color: Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.body || 13
            }
            Text {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              wrapMode: Text.WordWrap
              text: root.hostname
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.body || 13
              font.bold: true
            }

            // Row 2
            Text {
              text: "Processor (CPU):"
              color: Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.body || 13
            }
            Text {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              wrapMode: Text.WordWrap
              text: root.cpu
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.body || 13
              font.bold: true
            }

            // Row 3
            Text {
              text: "Memory (RAM):"
              color: Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.body || 13
            }
            Text {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              wrapMode: Text.WordWrap
              text: root.ram
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.body || 13
              font.bold: true
            }

            // Row 4
            Text {
              text: "Linux Kernel:"
              color: Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.body || 13
            }
            Text {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              wrapMode: Text.WordWrap
              text: root.kernel
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.body || 13
              font.bold: true
            }

            // Row 5
            Text {
              text: "System Uptime:"
              color: Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.body || 13
            }
            Text {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              wrapMode: Text.WordWrap
              text: root.uptime
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.body || 13
              font.bold: true
            }
          }
        }
      }

      // Time & Region Card (Row 2)
      Rectangle {
        id: tzCard
        Layout.fillWidth: true
        implicitHeight: Math.max(76, tzColLayout.implicitHeight + 28)
        Layout.preferredHeight: implicitHeight
        radius: Style.cornerRadius || 8
        readonly property bool isFocused: root.isContentFocused && root.focusedRow === 2
        readonly property bool isHovered: tzMouse.containsMouse

        color: isFocused
          ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
          : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02))
        border.color: isFocused
          ? Color.accent
          : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08))
        border.width: isFocused ? 2 : 1

        MouseArea {
          id: tzMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (root.panelRoot) root.panelRoot.focusSection = "content"
            root.focusedRow = 2
          }
        }

        ColumnLayout {
          id: tzColLayout
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 16
          spacing: 12

          RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
              width: 38
              height: 38
              radius: 8
              color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
              border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60)
              border.width: 1

              Text {
                anchors.centerIn: parent
                text: "󰃭"
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
                  text: "Timezone & Network Time"
                  font.family: Style.font.family
                  font.pixelSize: 13
                  font.bold: true
                  color: tzCard.isFocused ? Color.accent : Color.foreground
                }

                Rectangle {
                  visible: root.ntp.length > 0
                  width: ntpText.implicitWidth + 14
                  height: 18
                  radius: 4
                  color: (root.ntp === "active") ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06)
                  border.color: (root.ntp === "active") ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
                  border.width: 1

                  RowLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    Rectangle {
                      visible: root.ntp === "active"
                      width: 5
                      height: 5
                      radius: 2.5
                      color: Color.accent
                    }
                    Text {
                      id: ntpText
                      text: "NTP: " + root.ntp.toUpperCase()
                      font.family: Style.font.family
                      font.pixelSize: 10
                      font.bold: true
                      color: (root.ntp === "active") ? Color.accent : Color.muted
                    }
                  }
                }
              }

              Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                wrapMode: Text.WordWrap
                text: root.timezone.length > 0 ? root.timezone : "Loading timezone..."
                font.family: Style.font.family
                font.pixelSize: 12
                color: Color.muted
              }
            }

            Rectangle {
              id: tzBtn
              implicitWidth: tzBtnLayout.implicitWidth + 24
              implicitHeight: 30
              radius: 6
              readonly property bool btnHover: tzBtnMouse.containsMouse
              readonly property bool isBtnFocused: tzCard.isFocused
              color: isBtnFocused
                ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, btnHover ? 0.18 : 0.14)
                : (btnHover ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04))
              border.color: isBtnFocused
                ? Color.accent
                : (btnHover ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12))
              border.width: isBtnFocused ? 2 : 1

              RowLayout {
                id: tzBtnLayout
                anchors.centerIn: parent
                spacing: 6
                Text {
                  text: "󰃭"
                  font.family: Style.font.family
                  font.pixelSize: 13
                  color: tzBtn.isBtnFocused ? Color.accent : (tzBtn.btnHover ? Color.foreground : Color.muted)
                }
                Text {
                  text: "Change Timezone [T]"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  font.bold: tzBtn.isBtnFocused
                  color: tzBtn.isBtnFocused ? Color.accent : (tzBtn.btnHover ? Color.foreground : Color.muted)
                }
              }

              MouseArea {
                id: tzBtnMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (root.panelRoot) root.panelRoot.focusSection = "content"
                  root.focusedRow = 2
                  root.openTimezonePicker()
                }
              }
            }
          }
        }
      }

      // Configuration Backups & Restore Card (Row 3)
      Rectangle {
        id: backupsCard
        Layout.fillWidth: true
        implicitHeight: Math.max(90, backupsColLayout.implicitHeight + 28)
        Layout.preferredHeight: implicitHeight
        radius: Style.cornerRadius || 8
        readonly property bool isFocused: root.isContentFocused && root.focusedRow === 3
        readonly property bool isHovered: backupsMouse.containsMouse

        color: isFocused
          ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
          : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02))
        border.color: isFocused
          ? Color.accent
          : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08))
        border.width: isFocused ? 2 : 1

        MouseArea {
          id: backupsMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (root.panelRoot) root.panelRoot.focusSection = "content"
            root.focusedRow = 3
          }
        }

        ColumnLayout {
          id: backupsColLayout
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 16
          spacing: 12

          RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
              width: 38
              height: 38
              radius: 8
              color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
              border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60)
              border.width: 1

              Text {
                anchors.centerIn: parent
                text: "󰁯"
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
                  text: "Configuration Backups & Restore"
                  font.family: Style.font.family
                  font.pixelSize: 13
                  font.bold: true
                  color: backupsCard.isFocused ? Color.accent : Color.foreground
                }

                Rectangle {
                  visible: root.backupsList.length > 0
                  width: countText.implicitWidth + 14
                  height: 18
                  radius: 4
                  color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
                  border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60)
                  border.width: 1

                  RowLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    Rectangle {
                      width: 5
                      height: 5
                      radius: 2.5
                      color: Color.accent
                    }
                    Text {
                      id: countText
                      text: root.backupsList.length + " Saved"
                      font.family: Style.font.family
                      font.pixelSize: 10
                      font.bold: true
                      color: Color.accent
                    }
                  }
                }
              }

              Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                wrapMode: Text.WordWrap
                text: "Create snapshot archives of Hyprland configs, Shell bindings, and system themes."
                font.family: Style.font.family
                font.pixelSize: 12
                color: Color.muted
              }
            }

            Rectangle {
              id: backupCreateBtn
              implicitWidth: backupCreateLayout.implicitWidth + 24
              implicitHeight: 30
              radius: 6
              readonly property bool btnHover: backupCreateMouse.containsMouse
              readonly property bool isBtnFocused: backupsCard.isFocused
              color: isBtnFocused
                ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, btnHover ? 0.18 : 0.14)
                : (btnHover ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04))
              border.color: isBtnFocused
                ? Color.accent
                : (btnHover ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12))
              border.width: isBtnFocused ? 2 : 1

              RowLayout {
                id: backupCreateLayout
                anchors.centerIn: parent
                spacing: 6
                Text {
                  text: root.isBackingUp ? "󰑮" : "󰆓"
                  font.family: Style.font.family
                  font.pixelSize: 13
                  color: backupCreateBtn.isBtnFocused ? Color.accent : (backupCreateBtn.btnHover ? Color.foreground : Color.muted)
                }
                Text {
                  text: root.isBackingUp ? "Saving..." : "Create Backup [B]"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  font.bold: backupCreateBtn.isBtnFocused
                  color: backupCreateBtn.isBtnFocused ? Color.accent : (backupCreateBtn.btnHover ? Color.foreground : Color.muted)
                }
              }

              MouseArea {
                id: backupCreateMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (root.panelRoot) root.panelRoot.focusSection = "content"
                  root.focusedRow = 3
                  root.createBackup()
                }
              }
            }
          }

          // Backups List
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: root.backupsList.length > 0

            Rectangle {
              Layout.fillWidth: true
              height: 1
              color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
            }

            Repeater {
              model: root.backupsList.slice(0, 5)

              Rectangle {
                Layout.fillWidth: true
                implicitHeight: itemRow.implicitHeight + 14
                radius: 6
                color: itemHover.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04) : Qt.transparent
                border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06)
                border.width: 1

                MouseArea {
                  id: itemHover
                  anchors.fill: parent
                  hoverEnabled: true
                }

                RowLayout {
                  id: itemRow
                  anchors.fill: parent
                  anchors.leftMargin: 10
                  anchors.rightMargin: 10
                  spacing: 10

                  Text {
                    text: "󰁯"
                    font.family: Style.font.family
                    font.pixelSize: 14
                    color: Color.accent
                  }

                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                      text: modelData.timestamp || modelData.filename
                      font.family: Style.font.family
                      font.pixelSize: 12
                      font.bold: true
                      color: Color.foreground
                    }

                    Text {
                      text: (modelData.filename || "") + " • " + (modelData.size || "") + " • " + (modelData.filesCount || 0) + " config files"
                      font.family: Style.font.family
                      font.pixelSize: 11
                      color: Color.muted
                      elide: Text.ElideMiddle
                    }
                  }

                  // Restore button
                  Rectangle {
                    implicitWidth: restText.implicitWidth + 16
                    implicitHeight: 26
                    radius: 4
                    color: restHover.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.12)
                    border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.50)
                    border.width: 1

                    Text {
                      id: restText
                      anchors.centerIn: parent
                      text: "Restore"
                      font.family: Style.font.family
                      font.pixelSize: 11
                      font.bold: true
                      color: Color.accent
                    }

                    MouseArea {
                      id: restHover
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.restoreBackup(modelData.filename)
                    }
                  }

                  // Delete button
                  Rectangle {
                    implicitWidth: 26
                    implicitHeight: 26
                    radius: 4
                    color: delHover.containsMouse ? Qt.rgba(240/255, 80/255, 80/255, 0.20) : Qt.transparent
                    border.color: delHover.containsMouse ? Qt.rgba(240/255, 80/255, 80/255, 0.50) : Qt.transparent
                    border.width: 1

                    Text {
                      anchors.centerIn: parent
                      text: ""
                      font.family: Style.font.family
                      font.pixelSize: 12
                      color: delHover.containsMouse ? Qt.rgba(255/255, 100/255, 100/255, 1.0) : Color.muted
                    }

                    MouseArea {
                      id: delHover
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.deleteBackup(modelData.filename)
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
