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
  property int focusedRow: 0   // 0: DND Toggle, 1: Actions Row, 2+: History Items
  property int actionFocusIndex: 0 // 0: Replay, 1: Dismiss, 2: Send Test, 3: Clear History
  onFocusedRowChanged: ensureRowVisible(focusedRow)

  function ensureRowVisible(index) {
    if (!scrollArea || !scrollArea.contentItem) return
    var item = null
    if (index === 0) item = dndCard
    else if (index === 1) item = actionsCard
    else if (index >= 2 && historyRepeater && index - 2 < historyRepeater.count) {
      item = historyRepeater.itemAt(index - 2)
    }
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

  property string statusMessage: ""

  // State data
  property bool dndEnabled: false
  property int historyCount: 0
  property var historyItems: []
  property bool isRefreshing: false

  function formatTime(timestamp) {
    if (!timestamp) return ""
    var d = new Date(timestamp)
    var hours = d.getHours().toString().padStart(2, "0")
    var minutes = d.getMinutes().toString().padStart(2, "0")
    var now = new Date()
    var isToday = (d.toDateString() === now.toDateString())
    if (isToday) {
      return hours + ":" + minutes
    }
    var day = d.getDate().toString().padStart(2, "0")
    var month = (d.getMonth() + 1).toString().padStart(2, "0")
    return day + "/" + month + " " + hours + ":" + minutes
  }

  function stripHtml(text) {
    if (!text) return ""
    return String(text).replace(/<[^>]*>/g, "").replace(/\n+/g, " ")
  }

  function refresh() {
    if (!stateProcess.running && pluginPath.length > 0) {
      isRefreshing = true
      stateProcess.command = [pluginPath + "/scripts/notifications-control.sh", "get-state"]
      stateProcess.running = true
    }
  }

  function toggleDnd() {
    actionProcess.command = [pluginPath + "/scripts/notifications-control.sh", "toggle-dnd"]
    actionProcess.running = true
    notifyStatus(root.dndEnabled ? "Notifications unmuted" : "Do Not Disturb activated")
  }

  function showHistory() {
    actionProcess.command = [pluginPath + "/scripts/notifications-control.sh", "show-history"]
    actionProcess.running = true
    notifyStatus("Replaying recent notifications on screen")
  }

  function dismissAll() {
    actionProcess.command = [pluginPath + "/scripts/notifications-control.sh", "dismiss-all"]
    actionProcess.running = true
    notifyStatus("Dismissed on-screen notifications")
  }

  function clearHistory() {
    actionProcess.command = [pluginPath + "/scripts/notifications-control.sh", "clear-history"]
    actionProcess.running = true
    notifyStatus("Cleared notification history")
  }

  function sendTest() {
    actionProcess.command = [pluginPath + "/scripts/notifications-control.sh", "send-test"]
    actionProcess.running = true
    notifyStatus("Sent test notification")
  }

  function triggerAction(idx) {
    if (idx === 0) showHistory()
    else if (idx === 1) dismissAll()
    else if (idx === 2) sendTest()
    else if (idx === 3) clearHistory()
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
      var maxRow = 1 + (historyItems.length > 0 ? historyItems.length : 0)
      focusedRow = Math.max(0, Math.min(maxRow, focusedRow + dy))
      ensureRowVisible(focusedRow)
      return true
    }
    if (dx !== 0) {
      if (dx < 0 && focusedRow !== 1) return false
      if (focusedRow === 0) {
        if (dx > 0) toggleDnd()
        return true
      } else if (focusedRow === 1) {
        if (dx < 0 && actionFocusIndex === 0) return false
        actionFocusIndex = Math.max(0, Math.min(3, actionFocusIndex + dx))
        return true
      }
      return false
    }
    return false
  }

  function handleActivate() {
    if (focusedRow === 0) toggleDnd()
    else if (focusedRow === 1) triggerAction(actionFocusIndex)
    else if (focusedRow >= 2) showHistory()
  }

  function handleTextKey(key) {
    var k = key.toLowerCase()
    if (k === "h") {
      return handleMove(-1, 0)
    } else if (k === "l") {
      return handleMove(1, 0)
    } else if (k === "d") {
      toggleDnd()
      return true
    } else if (k === "p") {
      showHistory()
      return true
    } else if (k === "x") {
      dismissAll()
      return true
    } else if (k === "t") {
      sendTest()
      return true
    } else if (k === "c") {
      clearHistory()
      return true
    } else if (k === "r") {
      refresh()
      notifyStatus("Refreshed notifications status")
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
          if (data.dnd !== undefined) root.dndEnabled = data.dnd === true
          if (data.historyCount !== undefined) root.historyCount = Number(data.historyCount) || 0
          if (Array.isArray(data.history)) root.historyItems = data.history
        } catch (e) {
          console.warn("NotificationsView: parse error", e)
        }
      }
    }
  }

  // Action Process
  Process {
    id: actionProcess
    onRunningChanged: {
      if (!running) {
        root.refresh()
        if (panelRoot && typeof panelRoot.notifySettingChanged === "function") {
          panelRoot.notifySettingChanged()
        }
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
      spacing: 14

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

      // Setting Row 0: Do Not Disturb Card
      Rectangle {
        id: dndCard
        Layout.fillWidth: true
        implicitHeight: Math.max(78, dndRowLayout.implicitHeight + 24)
        Layout.preferredHeight: implicitHeight
        radius: Style.cornerRadius || 8
        readonly property bool isFocused: root.isContentFocused && root.focusedRow === 0
        readonly property bool isHovered: dndCardMouse.containsMouse
        color: isFocused
          ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
          : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02))
        border.color: isFocused
          ? Color.accent
          : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08))
        border.width: isFocused ? 2 : 1

        MouseArea {
          id: dndCardMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (root.panelRoot) root.panelRoot.focusSection = "content"
            root.focusedRow = 0
            root.toggleDnd()
          }
        }

        RowLayout {
          id: dndRowLayout
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 14
          spacing: 14

          Rectangle {
            width: 44
            height: 44
            radius: 8
            color: root.dndEnabled
              ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.20)
              : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
            border.color: root.dndEnabled
              ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.60)
              : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60)
            border.width: 1

            Text {
              anchors.centerIn: parent
              text: root.dndEnabled ? "󰂛" : "󰂚"
              font.family: Style.font.family
              font.pixelSize: 22
              color: root.dndEnabled ? Color.urgent : Color.accent
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 0
            Layout.minimumWidth: 0
            spacing: 3

            Flow {
              Layout.fillWidth: true
              width: parent.width
              spacing: 8

              Text {
                text: "Do Not Disturb (Silence Notifications)"
                font.family: Style.font.family
                font.pixelSize: 14
                font.bold: true
                color: Color.foreground
              }

              Rectangle {
                width: dndPillText.implicitWidth + 12
                height: 18
                radius: 4
                color: root.dndEnabled
                  ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.25)
                  : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25)
                border.color: root.dndEnabled ? Color.urgent : Color.accent
                border.width: 1

                Text {
                  id: dndPillText
                  anchors.centerIn: parent
                  text: root.dndEnabled ? "SILENCED" : "ACTIVE"
                  font.family: Style.font.family
                  font.pixelSize: 10
                  font.bold: true
                  color: root.dndEnabled ? Color.urgent : Color.accent
                }
              }
            }

            Text {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              wrapMode: Text.WordWrap
              text: root.dndEnabled
                ? "Notifications are silenced and archived straight into history without on-screen popups."
                : "Incoming notifications appear as popups in the top-right corner."
              font.family: Style.font.family
              font.pixelSize: 11
              color: Color.muted
            }
          }

          Rectangle {
            id: dndActionBtn
            implicitWidth: dndActionBtnText.implicitWidth + 24
            implicitHeight: 30
            radius: 6
            readonly property bool btnHover: dndActionBtnMouse.containsMouse
            color: root.dndEnabled
              ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, btnHover ? 0.28 : 0.20)
              : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, btnHover ? 0.28 : 0.20)
            border.color: root.dndEnabled
              ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.60)
              : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60)
            border.width: 1

            RowLayout {
              anchors.centerIn: parent
              spacing: 6
              Rectangle {
                width: 5
                height: 5
                radius: 2.5
                color: root.dndEnabled ? Color.urgent : Color.accent
              }
              Text {
                id: dndActionBtnText
                text: root.dndEnabled ? "Unmute [D]" : "Silence [D]"
                font.family: Style.font.family
                font.pixelSize: 11
                font.bold: true
                color: root.dndEnabled ? Color.urgent : Color.accent
              }
            }

            MouseArea {
              id: dndActionBtnMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (root.panelRoot) root.panelRoot.focusSection = "content"
                root.focusedRow = 0
                root.toggleDnd()
              }
            }
          }
        }
      }

      // Quick Actions Row
      Rectangle {
        id: actionsCard
        Layout.fillWidth: true
        implicitHeight: Math.max(52, actionsFlow.implicitHeight + 20)
        Layout.preferredHeight: implicitHeight
        radius: Style.cornerRadius || 8
        readonly property bool isFocused: root.isContentFocused && root.focusedRow === 1
        readonly property bool isHovered: actionsCardMouse.containsMouse
        color: isFocused
          ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
          : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02))
        border.color: isFocused
          ? Color.accent
          : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08))
        border.width: isFocused ? 2 : 1

        MouseArea {
          id: actionsCardMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.ArrowCursor
          onClicked: {
            if (root.panelRoot) root.panelRoot.focusSection = "content"
            root.focusedRow = 1
          }
        }

        Flow {
          id: actionsFlow
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 10
          spacing: 8

          Text {
            topPadding: 6
            text: "Actions:"
            font.family: Style.font.family
            font.pixelSize: 12
            font.bold: true
            color: Color.muted
          }

          Repeater {
            model: [
              { label: "󰂚 Replay Toasts [P]", actionIdx: 0 },
              { label: "✕ Dismiss All [X]", actionIdx: 1 },
              { label: "󰄬 Send Test [T]", actionIdx: 2 },
              { label: "🗑 Clear History [C]", actionIdx: 3 }
            ]

            delegate: Rectangle {
              id: actBtn
              implicitWidth: actBtnText.implicitWidth + 20
              implicitHeight: 28
              radius: 6
              readonly property bool isBtnFocused: root.isContentFocused && root.focusedRow === 1 && root.actionFocusIndex === modelData.actionIdx
              readonly property bool btnHover: actBtnMouse.containsMouse

              color: isBtnFocused
                ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, btnHover ? 0.18 : 0.14)
                : (btnHover ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04))
              border.color: isBtnFocused
                ? Color.accent
                : (btnHover ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12))
              border.width: isBtnFocused ? 2 : 1

              Text {
                id: actBtnText
                anchors.centerIn: parent
                text: modelData.label
                font.family: Style.font.family
                font.pixelSize: 11
                font.bold: isBtnFocused
                color: isBtnFocused ? Color.accent : (actBtn.btnHover ? Color.foreground : Color.muted)
              }

              MouseArea {
                id: actBtnMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (root.panelRoot) root.panelRoot.focusSection = "content"
                  root.focusedRow = 1
                  root.actionFocusIndex = modelData.actionIdx
                  root.triggerAction(modelData.actionIdx)
                }
              }
            }
          }
        }
      }

      // History Header
      RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 4
        spacing: 8

        Text {
          text: "RECENT NOTIFICATIONS (" + root.historyCount + ")"
          font.family: Style.font.family
          font.pixelSize: 11
          font.bold: true
          color: Color.muted
        }

        Item { Layout.fillWidth: true }

        Text {
          text: "Press [P] to replay on screen"
          font.family: Style.font.family
          font.pixelSize: 10
          color: Color.muted
        }
      }

      // Empty State
      Rectangle {
        visible: root.historyCount === 0
        Layout.fillWidth: true
        Layout.preferredHeight: 90
        radius: Style.cornerRadius || 8
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02)
        border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
        border.width: 1

        ColumnLayout {
          anchors.centerIn: parent
          spacing: 6

          Text {
            Layout.alignment: Qt.AlignHCenter
            text: "󰂛"
            font.family: Style.font.family
            font.pixelSize: 22
            color: Color.muted
          }

          Text {
            Layout.alignment: Qt.AlignHCenter
            text: "No recent notification history"
            font.family: Style.font.family
            font.pixelSize: 12
            color: Color.muted
          }
        }
      }

      // History Items List
      Repeater {
        id: historyRepeater
        model: root.historyItems

        delegate: Rectangle {
          id: histItemCard
          Layout.fillWidth: true
          implicitHeight: Math.max(56, histRowLayout.implicitHeight + 16)
          Layout.preferredHeight: implicitHeight
          radius: 6
          readonly property bool isFocused: root.isContentFocused && root.focusedRow === (2 + index)
          readonly property bool isHovered: histMouse.containsMouse
          color: isFocused
            ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
            : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02))
          border.color: isFocused
            ? Color.accent
            : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08))
          border.width: isFocused ? 2 : 1

          MouseArea {
            id: histMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (root.panelRoot) root.panelRoot.focusSection = "content"
              root.focusedRow = 2 + index
            }
          }

          RowLayout {
            id: histRowLayout
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 8
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 12

            // App Icon Pill
            Rectangle {
              width: 32
              height: 32
              radius: 6
              color: modelData.urgency === 2
                ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.20)
                : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15)
              border.color: modelData.urgency === 2
                ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.60)
                : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.40)
              border.width: 1

              Text {
                anchors.centerIn: parent
                text: modelData.urgency === 2 ? "󰀦" : (modelData.app === "Brave" ? "󰌢" : "󰂚")
                font.family: Style.font.family
                font.pixelSize: 15
                color: modelData.urgency === 2 ? Color.urgent : Color.accent
              }
            }

            ColumnLayout {
              id: histColLayout
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              spacing: 2

              Flow {
                Layout.fillWidth: true
                width: parent.width
                spacing: 6

                Text {
                  text: modelData.app
                  font.family: Style.font.family
                  font.pixelSize: 10
                  font.bold: true
                  color: Color.accent
                }

                Text {
                  text: "•"
                  font.family: Style.font.family
                  font.pixelSize: 10
                  color: Color.muted
                }

                Text {
                  text: modelData.summary
                  font.family: Style.font.family
                  font.pixelSize: 12
                  font.bold: true
                  color: isFocused ? Color.foreground : Color.foreground
                  elide: Text.ElideRight
                }

                Text {
                  text: root.formatTime(modelData.timestamp)
                  font.family: Style.font.family
                  font.pixelSize: 10
                  color: Color.muted
                }
              }

              Text {
                visible: modelData.body && modelData.body.length > 0
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: root.stripHtml(modelData.body)
                font.family: Style.font.family
                font.pixelSize: 11
                color: Color.muted
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
              }
            }
          }
        }
      }

      Item { Layout.preferredHeight: 12 }
    }
  }
}
