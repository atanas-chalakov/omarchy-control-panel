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

  property string defaultAgent: "agy"
  property var agents: []
  property var usage: []
  property string statusMessage: ""

  property bool activeFocusSection: false
  property int focusedRow: 0       // 0: Default Assistant Card, 1: Launch Actions, 2+: Provider Usage Cards
  property int selectedAgentIdx: 0  // Index within agents array for keyboard cycling

  // Inotify reactive watcher on default agent file
  FileView {
    id: defaultAgentWatcher
    path: Quickshell.env("HOME") + "/.config/omarchy/defaults/agent"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      var ag = text().trim()
      if (ag && ag.length > 0) {
        root.defaultAgent = ag
        syncSelectedAgentIdx()
      }
    }
  }

  function syncSelectedAgentIdx() {
    for (var i = 0; i < agents.length; i++) {
      if (agents[i].id === defaultAgent) {
        selectedAgentIdx = i
        break
      }
    }
  }

  function notifyStatus(msg) {
    statusMessage = msg
    statusTimer.restart()
  }

  Timer {
    id: statusTimer
    interval: 3500
    repeat: false
    onTriggered: root.statusMessage = ""
  }

  function cycleAgent(delta) {
    if (agents.length === 0) return
    selectedAgentIdx = (selectedAgentIdx + delta + agents.length) % agents.length
    var target = agents[selectedAgentIdx]
    setDefault(target.id, target.name)
  }

  function setDefault(id, name) {
    root.defaultAgent = id
    notifyStatus("Default agent set to " + (name || id))
    setDefaultProcess.command = [pluginPath + "/scripts/system-control.sh", "agent-set-default", id]
    setDefaultProcess.running = true
  }

  function launchAgent(id) {
    var target = id || root.defaultAgent
    notifyStatus("Launching " + target + " in terminal...")
    launchProcess.command = [pluginPath + "/scripts/system-control.sh", "agent-launch", target]
    launchProcess.running = true
  }

  function refreshUsage() {
    notifyStatus("Refreshing agent usage & limits...")
    refreshUsageProcess.command = [pluginPath + "/scripts/system-control.sh", "agent-refresh-usage"]
    refreshUsageProcess.running = true
  }

  function refresh() {
    if (!stateProcess.running && pluginPath.length > 0) {
      stateProcess.command = [pluginPath + "/scripts/system-control.sh", "agents-get"]
      stateProcess.running = true
    }
  }

  function formatTokens(count) {
    var n = Number(count || 0)
    if (n >= 1000000) return (n / 1000000).toFixed(1) + "M"
    if (n >= 1000) return (n / 1000).toFixed(1) + "k"
    return n.toLocaleString()
  }

  function totalTodayTokens() {
    var total = 0
    for (var i = 0; i < usage.length; i++) {
      total += Number(usage[i].todayTotalTokens || 0)
    }
    return total
  }

  function handleMove(dx, dy) {
    var maxRow = 1 + (usage.length > 0 ? usage.length : 0)
    if (dy !== 0) {
      focusedRow = Math.max(0, Math.min(maxRow, focusedRow + dy))
      return true
    }
    if (dx !== 0) {
      if (focusedRow === 0) {
        cycleAgent(dx)
        return true
      }
    }
    return false
  }

  function handleActivate() {
    if (focusedRow === 0) {
      if (agents.length > 0 && selectedAgentIdx >= 0 && selectedAgentIdx < agents.length) {
        setDefault(agents[selectedAgentIdx].id, agents[selectedAgentIdx].name)
      }
    } else if (focusedRow === 1) {
      launchAgent()
    } else {
      refreshUsage()
    }
  }

  function handleTextKey(key) {
    if (key === "r" || key === "R") {
      refreshUsage()
    } else if (key === "l" || key === "L") {
      launchAgent()
    } else if (key >= "1" && key <= "7") {
      var idx = parseInt(key) - 1
      if (idx >= 0 && idx < agents.length) {
        selectedAgentIdx = idx
        setDefault(agents[idx].id, agents[idx].name)
      }
    }
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
          if (data.defaultAgent) root.defaultAgent = data.defaultAgent
          if (Array.isArray(data.agents)) {
            root.agents = data.agents
            root.syncSelectedAgentIdx()
          }
          if (Array.isArray(data.usage)) root.usage = data.usage
        } catch (e) {
          console.warn("AgentsView: JSON parse error", e)
        }
      }
    }
  }

  // Set Default Agent Process
  Process {
    id: setDefaultProcess
    onRunningChanged: if (!running) root.refresh()
  }

  // Launch Agent Process
  Process {
    id: launchProcess
  }

  // Refresh Usage Process
  Process {
    id: refreshUsageProcess
    onRunningChanged: if (!running) root.refresh()
  }

  // Inline Usage Meter Component
  component UsageMeter: Item {
    id: meterItem
    property real value: 0
    property bool alarming: false
    implicitHeight: 6

    Rectangle {
      anchors.fill: parent
      radius: height / 2
      color: Color.pickAlpha("surface.selected", "#2a3036")
    }

    Rectangle {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      height: parent.height
      radius: height / 2
      width: parent.width * Math.max(0, Math.min(1, meterItem.value))
      color: meterItem.alarming ? Color.urgent : Color.accent

      Behavior on width {
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
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
        color: Color.pickAlpha("accent.subtle", "#1f3b30")
        border.color: Color.accent
        border.width: 1

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 12
          anchors.rightMargin: 12

          Text {
            text: "✓  " + root.statusMessage
            font.family: Style.font.family
            font.pixelSize: 12
            font.bold: true
            color: Color.accent
          }
        }
      }

      // Section Header: Overview
      Text {
        text: "AI CODING ASSISTANTS & DEFAULT RUNTIME"
        font.family: Style.font.family
        font.pixelSize: 11
        font.bold: true
        color: Color.muted
        Layout.topMargin: 4
      }

      // Hero Card: Current Default & Actions
      Rectangle {
        id: heroCard
        Layout.fillWidth: true
        implicitHeight: Math.max(88, heroLayout.implicitHeight + 28)
        Layout.preferredHeight: implicitHeight
        radius: Style.cornerRadius || 8
        color: Color.pickAlpha("surface.subtle", "#181b1d")

        RowLayout {
          id: heroLayout
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 14
          spacing: 14

          Rectangle {
            width: 48
            height: 48
            radius: 10
            color: Color.pickAlpha("surface.selected", "#2a3036")

            Image {
              anchors.centerIn: parent
              width: 26
              height: 26
              source: root.pluginPath + "/assets/agents/" + root.defaultAgent + ".svg"
              sourceSize.width: 52
              sourceSize.height: 52
              fillMode: Image.PreserveAspectFit
              visible: status === Image.Ready
            }

            Text {
              anchors.centerIn: parent
              visible: root.defaultAgent.length === 0 || parent.children[0].status !== Image.Ready
              text: "󰚩"
              font.family: Style.font.family
              font.pixelSize: 24
              color: Color.accent
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: 3

            Flow {
              Layout.fillWidth: true
              width: parent.width
              spacing: 8

              Text {
                text: "Default: " + (root.defaultAgent === "agy" ? "Antigravity" : root.defaultAgent.toUpperCase())
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle || 15
                font.bold: true
                color: Color.foreground
              }

              Rectangle {
                width: 62
                height: 20
                radius: 4
                color: Color.pickAlpha("accent.subtle", "#1f3b30")

                Text {
                  anchors.centerIn: parent
                  text: "PRIMARY"
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
              text: "Today's Total: " + root.formatTokens(root.totalTodayTokens()) + " tokens across " + root.usage.length + " configured agent subscriptions."
              font.family: Style.font.family
              font.pixelSize: Style.font.subtext || 11
              color: Color.muted
              wrapMode: Text.WordWrap
            }
          }

          RowLayout {
            spacing: 8

            Button {
              text: "Launch"
              iconText: "󰘳"
              bordered: true
              hasCursor: root.activeFocusSection && root.focusedRow === 1
              onClicked: root.launchAgent()
            }

            Button {
              text: "Refresh"
              iconText: ""
              bordered: true
              onClicked: root.refreshUsage()
            }
          }
        }
      }

      // Setting Row 0: Default Assistant Card
      Rectangle {
        id: selectorCard
        Layout.fillWidth: true
        implicitHeight: Math.max(130, selectorColLayout.implicitHeight + 28)
        Layout.preferredHeight: implicitHeight
        radius: Style.cornerRadius || 8
        readonly property bool isFocused: root.activeFocusSection && root.focusedRow === 0
        color: selectorCard.isFocused ? Color.pickAlpha("surface.selected", "#22272e") : Color.pickAlpha("surface.subtle", "#181b1d")
        border.color: selectorCard.isFocused ? Color.accent : "transparent"
        border.width: selectorCard.isFocused ? 2 : 1

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.focusedRow = 0
        }

        ColumnLayout {
          id: selectorColLayout
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 14
          spacing: 12

          RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
              text: "󰚩"
              font.family: Style.font.family
              font.pixelSize: 18
              color: selectorCard.isFocused ? Color.accent : Color.foreground
            }

            ColumnLayout {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              spacing: 2

              Flow {
                Layout.fillWidth: true
                width: parent.width
                spacing: 8

                Text {
                  text: "Default Coding Assistant"
                  font.family: Style.font.family
                  font.pixelSize: Style.font.subtitle || 14
                  font.bold: true
                  color: Color.foreground
                }

                Text {
                  visible: selectorCard.isFocused
                  text: "• Use [←/→ or h/l] to cycle, [Enter] to set default"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  color: Color.accent
                }
              }

              Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: "Select the agent invoked by terminal keybindings, scripts, and omarchy-agent."
                font.family: Style.font.family
                font.pixelSize: Style.font.subtext || 11
                color: Color.muted
                wrapMode: Text.WordWrap
              }
            }

            // Stepper buttons
            RowLayout {
              spacing: 6

              Button {
                text: "◀"
                implicitWidth: 32
                implicitHeight: 32
                bordered: true
                onClicked: {
                  root.focusedRow = 0
                  root.cycleAgent(-1)
                }
              }

              Button {
                text: "▶"
                implicitWidth: 32
                implicitHeight: 32
                bordered: true
                onClicked: {
                  root.focusedRow = 0
                  root.cycleAgent(1)
                }
              }
            }
          }

          // Agent Selector Grid
          GridLayout {
            Layout.fillWidth: true
            columns: selectorCard.width >= 560 ? 3 : (selectorCard.width >= 380 ? 2 : 1)
            rowSpacing: 8
            columnSpacing: 8

            Repeater {
              model: root.agents

              delegate: Rectangle {
                id: agentDelegate
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredHeight: 46
                radius: 6
                readonly property bool isSelected: modelData.id === root.defaultAgent
                readonly property bool isCursorTarget: selectorCard.isFocused && root.selectedAgentIdx === index

                color: isSelected
                  ? Color.pickAlpha("accent.subtle", "#1f3b30")
                  : (isCursorTarget
                    ? Color.pickAlpha("surface.selected", "#262b32")
                    : (delegateMouse.containsMouse ? Color.pickAlpha("surface.hover", "#1b1f23") : Color.pickAlpha("surface.selected", "#1a1e22")))
                border.color: isSelected ? Color.accent : (isCursorTarget ? Color.accent : "transparent")
                border.width: isSelected || isCursorTarget ? 2 : 1

                MouseArea {
                  id: delegateMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.focusedRow = 0
                    root.selectedAgentIdx = index
                    root.setDefault(modelData.id, modelData.name)
                  }
                }

                RowLayout {
                  anchors.fill: parent
                  anchors.margins: 8
                  spacing: 8

                  Rectangle {
                    width: 28
                    height: 28
                    radius: 5
                    color: isSelected ? Color.pickAlpha("accent.subtle", "#2a4d3e") : Color.pickAlpha("surface.selected", "#23282e")

                    Image {
                      anchors.centerIn: parent
                      width: 16
                      height: 16
                      source: root.pluginPath + "/assets/agents/" + modelData.id + ".svg"
                      sourceSize.width: 32
                      sourceSize.height: 32
                      fillMode: Image.PreserveAspectFit
                      visible: status === Image.Ready
                    }

                    Text {
                      anchors.centerIn: parent
                      visible: parent.children[0].status !== Image.Ready
                      text: "󰚩"
                      font.family: Style.font.family
                      font.pixelSize: 14
                      color: isSelected ? Color.accent : Color.foreground
                    }
                  }

                  ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 1

                    Text {
                      Layout.fillWidth: true
                      Layout.minimumWidth: 0
                      text: modelData.name
                      font.family: Style.font.family
                      font.pixelSize: Style.font.bodySmall || 12
                      font.bold: isSelected
                      color: isSelected ? Color.accent : Color.foreground
                      elide: Text.ElideRight
                    }

                    Text {
                      Layout.fillWidth: true
                      Layout.minimumWidth: 0
                      text: modelData.installed ? "Installed CLI" : "Available"
                      font.family: Style.font.family
                      font.pixelSize: 10
                      color: modelData.installed ? Color.muted : Color.pickAlpha("muted", "#666666")
                      elide: Text.ElideRight
                    }
                  }

                  Text {
                    visible: isSelected
                    text: "✓"
                    font.family: Style.font.family
                    font.pixelSize: 12
                    font.bold: true
                    color: Color.accent
                  }
                }
              }
            }
          }
        }
      }

      // Section Header: Active Usage
      Text {
        text: "ACTIVE SUBSCRIPTIONS & TOKEN QUOTAS"
        font.family: Style.font.family
        font.pixelSize: 11
        font.bold: true
        color: Color.muted
        Layout.topMargin: 8
      }

      // Provider Usage Cards
      Repeater {
        model: root.usage

        delegate: Rectangle {
          id: providerCard
          Layout.fillWidth: true
          implicitHeight: Math.max(120, providerLayout.implicitHeight + 28)
          Layout.preferredHeight: implicitHeight
          radius: Style.cornerRadius || 8
          readonly property int myRowIndex: 2 + index
          readonly property bool isFocused: root.activeFocusSection && root.focusedRow === myRowIndex
          color: providerCard.isFocused ? Color.pickAlpha("surface.selected", "#22272e") : Color.pickAlpha("surface.subtle", "#181b1d")
          border.color: providerCard.isFocused ? Color.accent : "transparent"
          border.width: providerCard.isFocused ? 2 : 1

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.focusedRow = providerCard.myRowIndex
          }

          ColumnLayout {
            id: providerLayout
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 14
            spacing: 12

            // Top Row: Agent Header + Status Pill
            RowLayout {
              Layout.fillWidth: true
              spacing: 12

              Rectangle {
                width: 36
                height: 36
                radius: 8
                color: Color.pickAlpha("surface.selected", "#2a3036")

                Image {
                  anchors.centerIn: parent
                  width: 20
                  height: 20
                  source: root.pluginPath + "/assets/agents/" + modelData.id + ".svg"
                  sourceSize.width: 40
                  sourceSize.height: 40
                  fillMode: Image.PreserveAspectFit
                  visible: status === Image.Ready
                }

                Text {
                  anchors.centerIn: parent
                  visible: parent.children[0].status !== Image.Ready
                  text: "󰚩"
                  font.family: Style.font.family
                  font.pixelSize: 18
                  color: Color.accent
                }
              }

              ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 2

                Flow {
                  Layout.fillWidth: true
                  width: parent.width
                  spacing: 8

                  Text {
                    text: modelData.name
                    font.family: Style.font.family
                    font.pixelSize: Style.font.subtitle || 14
                    font.bold: true
                    color: Color.foreground
                  }

                  Rectangle {
                    visible: !!modelData.tierLabel && modelData.tierLabel.length > 0
                    height: 18
                    radius: 4
                    color: Color.pickAlpha("accent.subtle", "#1f3b30")
                    width: tierLabelText.implicitWidth + 12

                    Text {
                      id: tierLabelText
                      anchors.centerIn: parent
                      text: modelData.tierLabel || ""
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
                  text: modelData.usageStatusText || (modelData.ready ? "Subscription active" : "Status pending")
                  font.family: Style.font.family
                  font.pixelSize: Style.font.subtext || 11
                  color: Color.muted
                  wrapMode: Text.WordWrap
                }
              }

              // Ready/Active Badge
              Rectangle {
                width: 76
                height: 24
                radius: 12
                color: modelData.ready ? Color.pickAlpha("accent.subtle", "#1f3b30") : Color.pickAlpha("surface.selected", "#2a3036")
                border.color: modelData.ready ? Color.accent : "transparent"
                border.width: 1

                Text {
                  anchors.centerIn: parent
                  text: modelData.ready ? "ACTIVE" : "STANDBY"
                  font.family: Style.font.family
                  font.pixelSize: 10
                  font.bold: true
                  color: modelData.ready ? Color.accent : Color.muted
                }
              }
            }

            // Metrics Row
            GridLayout {
              Layout.fillWidth: true
              columns: providerCard.width >= 500 ? 4 : 2
              rowSpacing: 6
              columnSpacing: 12

              // Metric 1: Today Tokens
              ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                  text: "Today's Tokens"
                  font.family: Style.font.family
                  font.pixelSize: 10
                  color: Color.muted
                }
                Text {
                  text: root.formatTokens(modelData.todayTotalTokens || 0)
                  font.family: Style.font.family
                  font.pixelSize: 13
                  font.bold: true
                  color: Color.foreground
                }
              }

              // Metric 2: Today Prompts
              ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                  text: "Today Prompts"
                  font.family: Style.font.family
                  font.pixelSize: 10
                  color: Color.muted
                }
                Text {
                  text: (modelData.todayPrompts || 0) + " (" + (modelData.todaySessions || 0) + " ses.)"
                  font.family: Style.font.family
                  font.pixelSize: 13
                  font.bold: true
                  color: Color.foreground
                }
              }

              // Metric 3: Total Prompts
              ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                  text: "Lifetime Prompts"
                  font.family: Style.font.family
                  font.pixelSize: 10
                  color: Color.muted
                }
                Text {
                  text: (modelData.totalPrompts || 0) + " prompts"
                  font.family: Style.font.family
                  font.pixelSize: 13
                  font.bold: true
                  color: Color.foreground
                }
              }

              // Metric 4: Active Days
              ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                  text: "Active History"
                  font.family: Style.font.family
                  font.pixelSize: 10
                  color: Color.muted
                }
                Text {
                  text: (modelData.activeDays || 0) + " days active"
                  font.family: Style.font.family
                  font.pixelSize: 13
                  font.bold: true
                  color: Color.foreground
                }
              }
            }

            // Auth Help Warning Box if present
            Rectangle {
              visible: !!modelData.authHelpText && modelData.authHelpText.length > 0
              Layout.fillWidth: true
              implicitHeight: authHelpRow.implicitHeight + 12
              Layout.preferredHeight: implicitHeight
              radius: 6
              color: Color.pickAlpha("urgent.subtle", "#2e1818")
              border.color: Color.urgent
              border.width: 1

              RowLayout {
                id: authHelpRow
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 6
                spacing: 8

                Text {
                  text: "󰅚"
                  font.family: Style.font.family
                  font.pixelSize: 14
                  color: Color.urgent
                }

                Text {
                  Layout.fillWidth: true
                  Layout.minimumWidth: 0
                  text: modelData.authHelpText || ""
                  font.family: Style.font.family
                  font.pixelSize: 11
                  color: Color.urgent
                  wrapMode: Text.WordWrap
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
