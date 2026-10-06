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
  readonly property bool isContentFocused: {
    if (root.panelRoot && root.panelRoot.focusSection !== undefined) {
      return root.panelRoot.focusSection === "content"
    }
    return activeFocusSection
  }
  property int gapFocusIndex: -1
  property int roundingFocusIndex: -1
  property int borderFocusIndex: -1
  property int opacityFocusIndex: -1
  property int focusedCard: 0   // 0: Animations, 1: Gaps, 2: Single Window Aspect, 3: Rounding, 4: Border, 5: Opacity, 6: Blur, 7: Bar Hidden, 8: Bar Position, 9: Bar Transparency, 10: Workspace Layout
  onFocusedCardChanged: {
    ensureCardVisible(focusedCard)
    if (focusedCard !== 1) gapFocusIndex = currentGapIndex()
    if (focusedCard !== 3) roundingFocusIndex = currentRoundingIndex()
    if (focusedCard !== 4) borderFocusIndex = currentBorderIndex()
    if (focusedCard !== 5) opacityFocusIndex = currentOpacityIndex()
  }

  function ensureCardVisible(index) {
    if (!scrollArea || !scrollArea.contentItem) return
    var targets = [animCard, gapsRow, aspectRow, roundingRow, borderRow, opacityRow, blurRow, barRow, barPosRow, barTransRow, layoutRow]
    if (index >= 0 && index < targets.length) {
      var item = targets[index]
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
  }

  property string statusMessage: ""

  // State properties
  property bool animations: true
  property int gapsIn: 5
  onGapsInChanged: gapFocusIndex = currentGapIndex()
  property int gapsOut: 10
  onGapsOutChanged: gapFocusIndex = currentGapIndex()
  property int borderSize: 2
  onBorderSizeChanged: borderFocusIndex = currentBorderIndex()
  property int rounding: 0
  onRoundingChanged: roundingFocusIndex = currentRoundingIndex()
  property real inactiveOpacity: 1.0
  onInactiveOpacityChanged: opacityFocusIndex = currentOpacityIndex()
  property bool blur: false
  property bool barHidden: false
  property string barPosition: "top"
  property bool barTransparent: false
  property bool showPercentage: true
  property bool singleWindowAspect: false
  property string workspaceLayout: "dwindle"

  readonly property var gapPresets: [
    { label: "None (0px)", inGap: 0, outGap: 0 },
    { label: "Subtle (2px)", inGap: 2, outGap: 4 },
    { label: "Compact (4px)", inGap: 3, outGap: 6 },
    { label: "Default (8px)", inGap: 5, outGap: 10 },
    { label: "Spacious (14px)", inGap: 8, outGap: 14 },
    { label: "Expansive (20px)", inGap: 12, outGap: 20 },
    { label: "Maximal (28px)", inGap: 16, outGap: 28 }
  ]

  readonly property var roundingOptions: [0, 2, 4, 6, 8, 10, 12, 16, 20, 24]
  readonly property var borderOptions: [0, 1, 2, 3, 4, 5, 6, 8]
  readonly property var opacityOptions: [1.0, 0.95, 0.90, 0.85, 0.80, 0.75, 0.70, 0.65, 0.60]

  function currentGapIndex() {
    var best = 3
    var minDiff = 999
    for (var i = 0; i < gapPresets.length; i++) {
      var diff = Math.abs(gapPresets[i].inGap - root.gapsIn)
      if (diff < minDiff) {
        minDiff = diff
        best = i
      }
    }
    return best
  }

  function currentRoundingIndex() {
    var best = 0
    var minDiff = 999
    for (var i = 0; i < roundingOptions.length; i++) {
      var diff = Math.abs(roundingOptions[i] - root.rounding)
      if (diff < minDiff) {
        minDiff = diff
        best = i
      }
    }
    return best
  }

  function currentBorderIndex() {
    var best = 2
    var minDiff = 999
    for (var i = 0; i < borderOptions.length; i++) {
      if (borderOptions[i] === root.borderSize) return i
      var diff = Math.abs(borderOptions[i] - root.borderSize)
      if (diff < minDiff) { minDiff = diff; best = i }
    }
    return best
  }

  function currentOpacityIndex() {
    var best = 0
    var minDiff = 999
    for (var i = 0; i < opacityOptions.length; i++) {
      var diff = Math.abs(opacityOptions[i] - root.inactiveOpacity)
      if (diff < minDiff) {
        minDiff = diff
        best = i
      }
    }
    return best
  }

  function cycleGaps(delta) {
    var cur = (gapFocusIndex >= 0) ? gapFocusIndex : currentGapIndex()
    if (delta < 0 && cur === 0) return false
    var next = Math.max(0, Math.min(gapPresets.length - 1, cur + delta))
    if (next === cur) return false
    gapFocusIndex = next
    return true
  }

  function cycleRounding(delta) {
    var cur = (roundingFocusIndex >= 0) ? roundingFocusIndex : currentRoundingIndex()
    if (delta < 0 && cur === 0) return false
    var next = Math.max(0, Math.min(roundingOptions.length - 1, cur + delta))
    if (next === cur) return false
    roundingFocusIndex = next
    return true
  }

  function cycleBorder(delta) {
    var cur = (borderFocusIndex >= 0) ? borderFocusIndex : currentBorderIndex()
    if (delta < 0 && cur === 0) return false
    var next = Math.max(0, Math.min(borderOptions.length - 1, cur + delta))
    if (next === cur) return false
    borderFocusIndex = next
    return true
  }

  function cycleOpacity(delta) {
    var cur = (opacityFocusIndex >= 0) ? opacityFocusIndex : currentOpacityIndex()
    if (delta < 0 && cur === 0) return false
    var next = Math.max(0, Math.min(opacityOptions.length - 1, cur + delta))
    if (next === cur) return false
    opacityFocusIndex = next
    return true
  }

  function cycleBarPosition() {
    var target = (root.barPosition === "bottom") ? "top" : "bottom"
    setBarPosition(target)
  }

  function refresh() {
    if (!stateProcess.running && pluginPath.length > 0) {
      stateProcess.command = [pluginPath + "/scripts/wm-control.sh", "get-state"]
      stateProcess.running = true
    }
  }

  function toggleAnimations() {
    var target = !root.animations
    actionProcess.command = [pluginPath + "/scripts/wm-control.sh", "set-animations", target ? "true" : "false"]
    actionProcess.running = true
    notifyStatus(target ? "Window Animations Enabled" : "Window Animations Disabled (Instant)")
  }

  function setGaps(gin, gout) {
    actionProcess.command = [pluginPath + "/scripts/wm-control.sh", "set-gaps", String(gin), String(gout)]
    actionProcess.running = true
    notifyStatus("Window Gaps: " + gin + "px / " + gout + "px")
  }

  function setRounding(rad) {
    actionProcess.command = [pluginPath + "/scripts/wm-control.sh", "set-rounding", String(rad)]
    actionProcess.running = true
    notifyStatus("Corner Rounding: " + rad + "px")
  }

  function setBorderSize(bsize) {
    actionProcess.command = [pluginPath + "/scripts/wm-control.sh", "set-border-size", String(bsize)]
    actionProcess.running = true
    notifyStatus("Border Thickness: " + bsize + "px")
  }

  function setInactiveOpacity(op) {
    actionProcess.command = [pluginPath + "/scripts/wm-control.sh", "set-inactive-opacity", String(op)]
    actionProcess.running = true
    notifyStatus("Inactive Window Opacity: " + Math.round(op * 100) + "%")
  }

  function toggleBlur() {
    var target = !root.blur
    actionProcess.command = [pluginPath + "/scripts/wm-control.sh", "set-blur", target ? "true" : "false"]
    actionProcess.running = true
    notifyStatus(target ? "Window Background Blur Enabled" : "Window Background Blur Disabled")
  }

  function toggleBar() {
    actionProcess.command = [pluginPath + "/scripts/wm-control.sh", "toggle-bar"]
    actionProcess.running = true
    notifyStatus(root.barHidden ? "Menu Bar Visible" : "Menu Bar Hidden")
  }

  function setBarPosition(pos) {
    actionProcess.command = [pluginPath + "/scripts/wm-control.sh", "set-bar-position", pos]
    actionProcess.running = true
    notifyStatus("Menu Bar Position: " + pos)
  }

  function toggleBarTransparent() {
    actionProcess.command = [pluginPath + "/scripts/wm-control.sh", "toggle-bar-transparent"]
    actionProcess.running = true
    notifyStatus(root.barTransparent ? "Menu Bar Solid" : "Menu Bar Transparent")
  }

  function toggleBatteryPercentage() {
    actionProcess.command = [pluginPath + "/scripts/wm-control.sh", "toggle-battery-percentage"]
    actionProcess.running = true
    notifyStatus(root.showPercentage ? "Battery Percentage Hidden" : "Battery Percentage Visible")
  }

  function toggleSingleWindowAspect() {
    actionProcess.command = [pluginPath + "/scripts/wm-control.sh", "toggle-single-window-aspect"]
    actionProcess.running = true
    notifyStatus(root.singleWindowAspect ? "Single Window Aspect Ratio Disabled" : "1-Window Square Aspect Enabled")
  }

  function toggleWorkspaceLayout() {
    actionProcess.command = [pluginPath + "/scripts/wm-control.sh", "toggle-workspace-layout"]
    actionProcess.running = true
    notifyStatus("Workspace Layout: " + (root.workspaceLayout === "dwindle" ? "Scrolling" : "Dwindle"))
  }

  function notifyStatus(msg) {
    statusMessage = msg
    statusClearTimer.restart()
  }

  Timer {
    id: statusClearTimer
    interval: 3000
    repeat: false
    onTriggered: root.statusMessage = ""
  }

  function handleMove(dx, dy) {
    if (dy !== 0) {
      focusedCard = Math.max(0, Math.min(10, focusedCard + dy))
      ensureCardVisible(focusedCard)
      return true
    } else if (dx !== 0) {
      if (focusedCard === 0) {
        if (dx < 0) return false
        toggleAnimations()
        return true
      }
      else if (focusedCard === 1) return cycleGaps(dx)
      else if (focusedCard === 2) {
        if (dx < 0) return false
        toggleSingleWindowAspect()
        return true
      }
      else if (focusedCard === 3) return cycleRounding(dx)
      else if (focusedCard === 4) return cycleBorder(dx)
      else if (focusedCard === 5) return cycleOpacity(dx)
      else if (focusedCard === 6) {
        if (dx < 0) return false
        toggleBlur()
        return true
      }
      else if (focusedCard === 7) {
        if (dx < 0) return false
        toggleBar()
        return true
      }
      else if (focusedCard === 8) {
        if (dx < 0 && root.barPosition === "top") return false
        cycleBarPosition()
        return true
      }
      else if (focusedCard === 9) {
        if (dx < 0) return false
        toggleBarTransparent()
        return true
      }
      else if (focusedCard === 10) {
        if (dx < 0) return false
        toggleWorkspaceLayout()
        return true
      }
    }
    return false
  }

  function handleActivate() {
    if (focusedCard === 0) toggleAnimations()
    else if (focusedCard === 1) {
      var gIdx = (gapFocusIndex >= 0) ? gapFocusIndex : currentGapIndex()
      setGaps(gapPresets[gIdx].inGap, gapPresets[gIdx].outGap)
    }
    else if (focusedCard === 2) toggleSingleWindowAspect()
    else if (focusedCard === 3) {
      var rIdx = (roundingFocusIndex >= 0) ? roundingFocusIndex : currentRoundingIndex()
      setRounding(roundingOptions[rIdx])
    }
    else if (focusedCard === 4) {
      var bIdx = (borderFocusIndex >= 0) ? borderFocusIndex : currentBorderIndex()
      setBorderSize(borderOptions[bIdx])
    }
    else if (focusedCard === 5) {
      var oIdx = (opacityFocusIndex >= 0) ? opacityFocusIndex : currentOpacityIndex()
      setInactiveOpacity(opacityOptions[oIdx])
    }
    else if (focusedCard === 6) toggleBlur()
    else if (focusedCard === 7) toggleBar()
    else if (focusedCard === 8) cycleBarPosition()
    else if (focusedCard === 9) toggleBarTransparent()
    else if (focusedCard === 10) toggleWorkspaceLayout()
  }

  function handleTextKey(key) {
    var k = key.toLowerCase()
    if (k === "h") {
      return handleMove(-1, 0)
    } else if (k === "l") {
      return handleMove(1, 0)
    } else if (k === "a") {
      focusedCard = 0
      toggleAnimations()
      return true
    } else if (k === "g") {
      focusedCard = 1
      cycleGaps(1)
      return true
    } else if (k === "s") {
      focusedCard = 2
      toggleSingleWindowAspect()
      return true
    } else if (k === "r") {
      focusedCard = 3
      cycleRounding(1)
      return true
    } else if (k === "b") {
      focusedCard = 4
      cycleBorder(1)
      return true
    } else if (k === "d") {
      focusedCard = 5
      cycleOpacity(1)
      return true
    } else if (k === "t") {
      focusedCard = 7
      toggleBar()
      return true
    } else if (k === "p") {
      focusedCard = 8
      cycleBarPosition()
      return true
    } else if (k === "e") {
      focusedCard = 9
      toggleBarTransparent()
      return true
    } else if (k === "c") {
      toggleBatteryPercentage()
      return true
    } else if (k === "w") {
      focusedCard = 10
      toggleWorkspaceLayout()
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
        try {
          var data = JSON.parse(text)
          if (data.animations !== undefined) root.animations = data.animations === true
          if (typeof data.gapsIn === "number") root.gapsIn = data.gapsIn
          if (typeof data.gapsOut === "number") root.gapsOut = data.gapsOut
          if (typeof data.borderSize === "number") root.borderSize = data.borderSize
          if (typeof data.rounding === "number") root.rounding = data.rounding
          if (typeof data.inactiveOpacity === "number") root.inactiveOpacity = data.inactiveOpacity
          if (data.blur !== undefined) root.blur = data.blur === true
          if (data.barHidden !== undefined) root.barHidden = data.barHidden === true
          if (data.barPosition) root.barPosition = String(data.barPosition)
          if (data.barTransparent !== undefined) root.barTransparent = data.barTransparent === true
          if (data.showPercentage !== undefined) root.showPercentage = data.showPercentage === true
          if (data.singleWindowAspect !== undefined) root.singleWindowAspect = data.singleWindowAspect === true
          if (data.workspaceLayout) root.workspaceLayout = String(data.workspaceLayout)
        } catch (e) {}
      }
    }
  }

  // Action Process
  Process {
    id: actionProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var data = JSON.parse(text)
          if (data.animations !== undefined) root.animations = data.animations === true
          if (typeof data.gapsIn === "number") root.gapsIn = data.gapsIn
          if (typeof data.gapsOut === "number") root.gapsOut = data.gapsOut
          if (typeof data.borderSize === "number") root.borderSize = data.borderSize
          if (typeof data.rounding === "number") root.rounding = data.rounding
          if (typeof data.inactiveOpacity === "number") root.inactiveOpacity = data.inactiveOpacity
          if (data.blur !== undefined) root.blur = data.blur === true
          if (data.barHidden !== undefined) root.barHidden = data.barHidden === true
          if (data.barPosition) root.barPosition = String(data.barPosition)
          if (data.barTransparent !== undefined) root.barTransparent = data.barTransparent === true
          if (data.showPercentage !== undefined) root.showPercentage = data.showPercentage === true
          if (data.singleWindowAspect !== undefined) root.singleWindowAspect = data.singleWindowAspect === true
          if (data.workspaceLayout) root.workspaceLayout = String(data.workspaceLayout)
        } catch (e) {}
        if (panelRoot && typeof panelRoot.notifySettingChanged === "function") {
          panelRoot.notifySettingChanged()
        }
      }
    }
    onRunningChanged: if (!running) root.refresh()
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

      // Card 1: Window Animations Hero Card
      Rectangle {
        id: animCard
        Layout.fillWidth: true
        implicitHeight: Math.max(76, animRow.implicitHeight + 28)
        Layout.preferredHeight: implicitHeight
        radius: Style.cornerRadius || 8
        readonly property bool isFocused: root.isContentFocused && root.focusedCard === 0
        readonly property bool isHovered: animMouse.containsMouse
        color: isFocused ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, isHovered ? 0.07 : 0.05) : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02))
        border.color: isFocused ? Color.accent : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08))
        border.width: isFocused ? 2 : 1

        MouseArea {
          id: animMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (root.panelRoot) root.panelRoot.focusSection = "content"
            root.focusedCard = 0
            root.toggleAnimations()
          }
        }

        RowLayout {
          id: animRow
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 14
          spacing: 14

          Rectangle {
            width: 48
            height: 48
            radius: 8
            color: root.animations ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
            border.color: root.animations ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.30) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
            border.width: 1

            Text {
              anchors.centerIn: parent
              text: "󰓅"
              font.family: Style.font.family
              font.pixelSize: 26
              color: root.animations ? Color.accent : Color.muted
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
                text: "Window Animations"
                font.family: Style.font.family
                font.pixelSize: Style.font.title || 15
                font.bold: true
                color: Color.foreground
              }

              Rectangle {
                Layout.preferredHeight: 20
                Layout.preferredWidth: animStatusText.implicitWidth + 14
                radius: 4
                color: root.animations ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
                border.color: root.animations ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
                border.width: 1

                Text {
                  id: animStatusText
                  anchors.centerIn: parent
                  text: root.animations ? "SMOOTH (ON)" : "INSTANT (OFF)"
                  font.family: Style.font.family
                  font.pixelSize: 10
                  font.bold: true
                  color: root.animations ? Color.accent : Color.muted
                }
              }

              Rectangle {
                width: 18
                height: 18
                radius: 3
                color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
                border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
                border.width: 1
                Text {
                  anchors.centerIn: parent
                  text: "A"
                  font.family: Style.font.family
                  font.pixelSize: 10
                  color: Color.muted
                }
              }
            }

            Text {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              text: root.animations
                ? "Fluid window opening, closing, and workspace transitions active"
                : "Zero animation delay for maximum snappiness and low battery draw"
              font.family: Style.font.family
              font.pixelSize: 11
              color: Color.muted
              wrapMode: Text.WordWrap
            }
          }

          Rectangle {
            width: 70
            height: 32
            radius: 16
            color: root.animations ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
            border.color: root.animations ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
            border.width: 1

            Text {
              anchors.centerIn: parent
              text: root.animations ? "ON" : "OFF"
              font.family: Style.font.family
              font.pixelSize: 11
              font.bold: true
              color: root.animations ? Color.accent : Color.muted
            }
          }
        }
      }

      // Card 2: Window Spacing & Layout
      Rectangle {
        id: spacingCard
        Layout.fillWidth: true
        implicitHeight: spacingCol.implicitHeight + 24
        Layout.preferredHeight: implicitHeight
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02)
        border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
        border.width: 1
        radius: Style.cornerRadius || 8

        ColumnLayout {
          id: spacingCol
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 12
          spacing: 10

          // Row 1: Gaps Stepper
          Rectangle {
            id: gapsRow
            Layout.fillWidth: true
            implicitHeight: Math.max(46, gapsInnerRow.implicitHeight + 14)
            Layout.preferredHeight: implicitHeight
            radius: 6
            readonly property bool isFocused: root.isContentFocused && root.focusedCard === 1
            readonly property bool isHovered: gapsMouse.containsMouse
            color: isFocused ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, isHovered ? 0.18 : 0.14) : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : "transparent")
            border.color: isFocused ? Color.accent : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : "transparent")
            border.width: isFocused ? 2 : 1

            MouseArea {
              id: gapsMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (root.panelRoot) root.panelRoot.focusSection = "content"
                root.focusedCard = 1
              }
            }

            RowLayout {
              id: gapsInnerRow
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.margins: 8
              spacing: 10

              Text {
                text: ""
                font.family: Style.font.family
                font.pixelSize: 16
                color: Color.accent
              }

              ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 1

                Flow {
                  Layout.fillWidth: true
                  width: parent.width
                  spacing: 6

                  Text {
                    text: "Window Gaps"
                    font.family: Style.font.family
                    font.pixelSize: 13
                    font.bold: true
                    color: Color.foreground
                  }

                  Rectangle {
                    width: 18
                    height: 18
                    radius: 3
                    color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
                    border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
                    border.width: 1
                    Text {
                      anchors.centerIn: parent
                      text: "G"
                      font.family: Style.font.family
                      font.pixelSize: 10
                      color: Color.muted
                    }
                  }
                }

                Text {
                  Layout.fillWidth: true
                  Layout.minimumWidth: 0
                  text: "Spacing between tiled windows and display edges"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  color: Color.muted
                  wrapMode: Text.WordWrap
                }
              }

              RowLayout {
                spacing: 4

                Button {
                  text: "◀"
                  implicitWidth: 30
                  implicitHeight: 28
                  bordered: true
                  onClicked: {
                    if (root.panelRoot) root.panelRoot.focusSection = "content"
                    root.focusedCard = 1
                    root.cycleGaps(-1)
                  }
                }

                Rectangle {
                  implicitWidth: 108
                  implicitHeight: 28
                  radius: 14
                  readonly property int effectiveGapIdx: root.gapFocusIndex >= 0 ? root.gapFocusIndex : root.currentGapIndex()
                  readonly property bool isPendingFocus: root.isContentFocused && (root.focusedCard === 1) && (effectiveGapIdx !== root.currentGapIndex())

                  color: isPendingFocus
                    ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.14)
                    : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
                  border.color: isPendingFocus
                    ? Color.accent
                    : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60)
                  border.width: isPendingFocus ? 2 : 1

                  RowLayout {
                    anchors.centerIn: parent
                    spacing: 5
                    Rectangle {
                      visible: !parent.parent.isPendingFocus
                      width: 5
                      height: 5
                      radius: 2.5
                      color: Color.accent
                    }
                    Text {
                      text: root.gapPresets[parent.parent.effectiveGapIdx].label
                      font.family: Style.font.family
                      font.pixelSize: 11
                      font.bold: true
                      color: parent.parent.isPendingFocus ? Color.foreground : Color.accent
                    }
                  }
                }

                Button {
                  text: "▶"
                  implicitWidth: 30
                  implicitHeight: 28
                  bordered: true
                  onClicked: {
                    if (root.panelRoot) root.panelRoot.focusSection = "content"
                    root.focusedCard = 1
                    root.cycleGaps(1)
                  }
                }
              }
            }
          }

          // Row 2: Single Window Aspect Ratio
          Rectangle {
            id: aspectRow
            Layout.fillWidth: true
            implicitHeight: Math.max(46, aspectInnerRow.implicitHeight + 14)
            Layout.preferredHeight: implicitHeight
            radius: 6
            readonly property bool isFocused: root.isContentFocused && root.focusedCard === 2
            readonly property bool isHovered: aspectMouse.containsMouse
            color: isFocused ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, isHovered ? 0.18 : 0.14) : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : "transparent")
            border.color: isFocused ? Color.accent : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : "transparent")
            border.width: isFocused ? 2 : 1

            MouseArea {
              id: aspectMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (root.panelRoot) root.panelRoot.focusSection = "content"
                root.focusedCard = 2
                root.toggleSingleWindowAspect()
              }
            }

            RowLayout {
              id: aspectInnerRow
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.margins: 8
              spacing: 10

              Text {
                text: ""
                font.family: Style.font.family
                font.pixelSize: 16
                color: Color.muted
              }

              ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 1

                Flow {
                  Layout.fillWidth: true
                  width: parent.width
                  spacing: 6

                  Text {
                    text: "1-Window Square Aspect Ratio"
                    font.family: Style.font.family
                    font.pixelSize: 13
                    font.bold: true
                    color: Color.foreground
                  }

                  Rectangle {
                    width: 18
                    height: 18
                    radius: 3
                    color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
                    border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
                    border.width: 1
                    Text {
                      anchors.centerIn: parent
                      text: "S"
                      font.family: Style.font.family
                      font.pixelSize: 10
                      color: Color.muted
                    }
                  }
                }

                Text {
                  Layout.fillWidth: true
                  Layout.minimumWidth: 0
                  text: "Prevents solitary windows from stretching ultra-wide across widescreen displays"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  color: Color.muted
                  wrapMode: Text.WordWrap
                }
              }

              Rectangle {
                width: 64
                height: 28
                radius: 14
                color: root.singleWindowAspect ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
                border.color: root.singleWindowAspect ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
                border.width: 1

                Text {
                  anchors.centerIn: parent
                  text: root.singleWindowAspect ? "ON" : "OFF"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  font.bold: true
                  color: root.singleWindowAspect ? Color.accent : Color.muted
                }
              }
            }
          }
        }
      }

      // Card 3: Window Decoration & Styling
      Rectangle {
        id: card3
        Layout.fillWidth: true
        implicitHeight: Math.max(120, card3Col.implicitHeight + 24)
        Layout.preferredHeight: implicitHeight
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02)
        border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
        border.width: 1
        radius: Style.cornerRadius || 8

        ColumnLayout {
          id: card3Col
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 12
          spacing: 8

          // Header
          RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
              text: "󰆷"
              font.family: Style.font.family
              font.pixelSize: 18
              color: Color.accent
            }

            Text {
              text: "Decoration & Borders"
              font.family: Style.font.family
              font.pixelSize: Style.font.subtitle || 14
              font.bold: true
              color: Color.foreground
            }
          }

          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Color.muted
            opacity: 0.15
          }

          // Corner Rounding
          Rectangle {
            id: roundingRow
            Layout.fillWidth: true
            implicitHeight: Math.max(46, roundingInnerRow.implicitHeight + 14)
            Layout.preferredHeight: implicitHeight
            radius: 6
            readonly property bool isFocused: root.isContentFocused && root.focusedCard === 3
            readonly property bool isHovered: roundingMouse.containsMouse
            color: isFocused ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, isHovered ? 0.18 : 0.14) : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : "transparent")
            border.color: isFocused ? Color.accent : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : "transparent")
            border.width: isFocused ? 2 : 1

            MouseArea {
              id: roundingMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (root.panelRoot) root.panelRoot.focusSection = "content"
                root.focusedCard = 3
              }
            }

            RowLayout {
              id: roundingInnerRow
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.margins: 8
              spacing: 10

              ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 1

                Flow {
                  Layout.fillWidth: true
                  width: parent.width
                  spacing: 6

                  Text {
                    text: "Corner Rounding"
                    font.family: Style.font.family
                    font.pixelSize: 12
                    font.bold: true
                    color: Color.foreground
                  }

                  Rectangle {
                    width: 16
                    height: 16
                    radius: 3
                    color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
                    border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
                    border.width: 1
                    Text {
                      anchors.centerIn: parent
                      text: "R"
                      font.family: Style.font.family
                      font.pixelSize: 9
                      color: Color.muted
                    }
                  }
                }

                Text {
                  Layout.fillWidth: true
                  Layout.minimumWidth: 0
                  text: "Border corner radius on tiled and floating application windows"
                  font.family: Style.font.family
                  font.pixelSize: 10
                  color: Color.muted
                  wrapMode: Text.WordWrap
                }
              }

              RowLayout {
                spacing: 4

                Button {
                  text: "◀"
                  implicitWidth: 28
                  implicitHeight: 26
                  bordered: true
                  onClicked: {
                    if (root.panelRoot) root.panelRoot.focusSection = "content"
                    root.focusedCard = 3
                    root.cycleRounding(-1)
                  }
                }

                Rectangle {
                  implicitWidth: 84
                  implicitHeight: 28
                  radius: 14
                  readonly property int effectiveRoundingIdx: root.roundingFocusIndex >= 0 ? root.roundingFocusIndex : root.currentRoundingIndex()
                  readonly property int focusedVal: root.roundingOptions[effectiveRoundingIdx] !== undefined ? root.roundingOptions[effectiveRoundingIdx] : root.rounding
                  readonly property bool isPendingFocus: root.isContentFocused && (root.focusedCard === 3) && (effectiveRoundingIdx !== root.currentRoundingIndex())

                  color: isPendingFocus
                    ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.14)
                    : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
                  border.color: isPendingFocus
                    ? Color.accent
                    : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60)
                  border.width: isPendingFocus ? 2 : 1

                  RowLayout {
                    anchors.centerIn: parent
                    spacing: 5
                    Rectangle {
                      visible: !parent.parent.isPendingFocus
                      width: 5
                      height: 5
                      radius: 2.5
                      color: Color.accent
                    }
                    Text {
                      text: parent.parent.focusedVal === 0 ? "Sharp (0)" : (parent.parent.focusedVal + "px")
                      font.family: Style.font.family
                      font.pixelSize: 11
                      font.bold: true
                      color: parent.parent.isPendingFocus ? Color.foreground : Color.accent
                    }
                  }
                }

                Button {
                  text: "▶"
                  implicitWidth: 28
                  implicitHeight: 26
                  bordered: true
                  onClicked: {
                    if (root.panelRoot) root.panelRoot.focusSection = "content"
                    root.focusedCard = 3
                    root.cycleRounding(1)
                  }
                }
              }
            }
          }

          // Border Thickness
          Rectangle {
            id: borderRow
            Layout.fillWidth: true
            implicitHeight: Math.max(46, borderInnerRow.implicitHeight + 14)
            Layout.preferredHeight: implicitHeight
            radius: 6
            readonly property bool isFocused: root.isContentFocused && root.focusedCard === 4
            readonly property bool isHovered: borderMouse.containsMouse
            color: isFocused ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, isHovered ? 0.18 : 0.14) : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : "transparent")
            border.color: isFocused ? Color.accent : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : "transparent")
            border.width: isFocused ? 2 : 1

            MouseArea {
              id: borderMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (root.panelRoot) root.panelRoot.focusSection = "content"
                root.focusedCard = 4
              }
            }

            RowLayout {
              id: borderInnerRow
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.margins: 8
              spacing: 10

              ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 1

                Flow {
                  Layout.fillWidth: true
                  width: parent.width
                  spacing: 6

                  Text {
                    text: "Border Thickness"
                    font.family: Style.font.family
                    font.pixelSize: 12
                    font.bold: true
                    color: Color.foreground
                  }

                  Rectangle {
                    width: 16
                    height: 16
                    radius: 3
                    color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
                    border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
                    border.width: 1
                    Text {
                      anchors.centerIn: parent
                      text: "B"
                      font.family: Style.font.family
                      font.pixelSize: 9
                      color: Color.muted
                    }
                  }
                }

                Text {
                  Layout.fillWidth: true
                  Layout.minimumWidth: 0
                  text: "Active and inactive window outline border width"
                  font.family: Style.font.family
                  font.pixelSize: 10
                  color: Color.muted
                  wrapMode: Text.WordWrap
                }
              }

              RowLayout {
                spacing: 4

                Button {
                  text: "◀"
                  implicitWidth: 28
                  implicitHeight: 26
                  bordered: true
                  onClicked: {
                    if (root.panelRoot) root.panelRoot.focusSection = "content"
                    root.focusedCard = 4
                    root.cycleBorder(-1)
                  }
                }

                Rectangle {
                  implicitWidth: 80
                  implicitHeight: 28
                  radius: 14
                  readonly property int effectiveBorderIdx: root.borderFocusIndex >= 0 ? root.borderFocusIndex : root.currentBorderIndex()
                  readonly property int focusedVal: root.borderOptions[effectiveBorderIdx] !== undefined ? root.borderOptions[effectiveBorderIdx] : root.borderSize
                  readonly property bool isPendingFocus: root.isContentFocused && (root.focusedCard === 4) && (effectiveBorderIdx !== root.currentBorderIndex())

                  color: isPendingFocus
                    ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.14)
                    : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
                  border.color: isPendingFocus
                    ? Color.accent
                    : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60)
                  border.width: isPendingFocus ? 2 : 1

                  RowLayout {
                    anchors.centerIn: parent
                    spacing: 5
                    Rectangle {
                      visible: !parent.parent.isPendingFocus
                      width: 5
                      height: 5
                      radius: 2.5
                      color: Color.accent
                    }
                    Text {
                      text: parent.parent.focusedVal === 0 ? "None (0)" : (parent.parent.focusedVal + "px")
                      font.family: Style.font.family
                      font.pixelSize: 11
                      font.bold: true
                      color: parent.parent.isPendingFocus ? Color.foreground : Color.accent
                    }
                  }
                }

                Button {
                  text: "▶"
                  implicitWidth: 28
                  implicitHeight: 26
                  bordered: true
                  onClicked: {
                    if (root.panelRoot) root.panelRoot.focusSection = "content"
                    root.focusedCard = 4
                    root.cycleBorder(1)
                  }
                }
              }
            }
          }

          // Inactive Dimming & Blur
          Rectangle {
            id: opacityRow
            Layout.fillWidth: true
            implicitHeight: Math.max(46, opacityInnerRow.implicitHeight + 14)
            Layout.preferredHeight: implicitHeight
            radius: 6
            readonly property bool isFocused: root.isContentFocused && root.focusedCard === 5
            readonly property bool isHovered: opacityMouse.containsMouse
            color: isFocused ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, isHovered ? 0.18 : 0.14) : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : "transparent")
            border.color: isFocused ? Color.accent : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : "transparent")
            border.width: isFocused ? 2 : 1

            MouseArea {
              id: opacityMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (root.panelRoot) root.panelRoot.focusSection = "content"
                root.focusedCard = 5
              }
            }

            RowLayout {
              id: opacityInnerRow
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.margins: 8
              spacing: 10

              ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 1

                Flow {
                  Layout.fillWidth: true
                  width: parent.width
                  spacing: 6

                  Text {
                    text: "Inactive Window Opacity"
                    font.family: Style.font.family
                    font.pixelSize: 12
                    font.bold: true
                    color: Color.foreground
                  }

                  Rectangle {
                    width: 16
                    height: 16
                    radius: 3
                    color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
                    border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
                    border.width: 1
                    Text {
                      anchors.centerIn: parent
                      text: "D"
                      font.family: Style.font.family
                      font.pixelSize: 9
                      color: Color.muted
                    }
                  }
                }

                Text {
                  Layout.fillWidth: true
                  Layout.minimumWidth: 0
                  text: "Subtly dim unfocused windows to direct focus to active application"
                  font.family: Style.font.family
                  font.pixelSize: 10
                  color: Color.muted
                  wrapMode: Text.WordWrap
                }
              }

              RowLayout {
                spacing: 4

                Button {
                  text: "◀"
                  implicitWidth: 28
                  implicitHeight: 26
                  bordered: true
                  onClicked: {
                    if (root.panelRoot) root.panelRoot.focusSection = "content"
                    root.focusedCard = 5
                    root.cycleOpacity(-1)
                  }
                }

                Rectangle {
                  implicitWidth: 80
                  implicitHeight: 28
                  radius: 14
                  readonly property int effectiveOpacityIdx: root.opacityFocusIndex >= 0 ? root.opacityFocusIndex : root.currentOpacityIndex()
                  readonly property real focusedVal: root.opacityOptions[effectiveOpacityIdx] !== undefined ? root.opacityOptions[effectiveOpacityIdx] : root.inactiveOpacity
                  readonly property bool isPendingFocus: root.isContentFocused && (root.focusedCard === 5) && (effectiveOpacityIdx !== root.currentOpacityIndex())

                  color: isPendingFocus
                    ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.14)
                    : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
                  border.color: isPendingFocus
                    ? Color.accent
                    : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60)
                  border.width: isPendingFocus ? 2 : 1

                  RowLayout {
                    anchors.centerIn: parent
                    spacing: 5
                    Rectangle {
                      visible: !parent.parent.isPendingFocus
                      width: 5
                      height: 5
                      radius: 2.5
                      color: Color.accent
                    }
                    Text {
                      text: Math.round(parent.parent.focusedVal * 100) + "%"
                      font.family: Style.font.family
                      font.pixelSize: 11
                      font.bold: true
                      color: parent.parent.isPendingFocus ? Color.foreground : Color.accent
                    }
                  }
                }

                Button {
                  text: "▶"
                  implicitWidth: 28
                  implicitHeight: 26
                  bordered: true
                  onClicked: {
                    if (root.panelRoot) root.panelRoot.focusSection = "content"
                    root.focusedCard = 5
                    root.cycleOpacity(1)
                  }
                }
              }
            }
          }

          // Blur Toggle
          Rectangle {
            id: blurRow
            Layout.fillWidth: true
            implicitHeight: Math.max(46, blurInnerRow.implicitHeight + 14)
            Layout.preferredHeight: implicitHeight
            radius: 6
            readonly property bool isFocused: root.isContentFocused && root.focusedCard === 6
            readonly property bool isHovered: blurMouse.containsMouse
            color: isFocused ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, isHovered ? 0.18 : 0.14) : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : "transparent")
            border.color: isFocused ? Color.accent : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : "transparent")
            border.width: isFocused ? 2 : 1

            MouseArea {
              id: blurMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (root.panelRoot) root.panelRoot.focusSection = "content"
                root.focusedCard = 6
                root.toggleBlur()
              }
            }

            RowLayout {
              id: blurInnerRow
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.margins: 8
              spacing: 10

              ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 1

                Flow {
                  Layout.fillWidth: true
                  width: parent.width
                  spacing: 6

                  Text {
                    text: "Background Blur"
                    font.family: Style.font.family
                    font.pixelSize: 12
                    font.bold: true
                    color: Color.foreground
                  }

                  Rectangle {
                    width: 16
                    height: 16
                    radius: 3
                    color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
                    border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
                    border.width: 1
                    Text {
                      anchors.centerIn: parent
                      text: "L"
                      font.family: Style.font.family
                      font.pixelSize: 9
                      color: Color.muted
                    }
                  }
                }

                Text {
                  Layout.fillWidth: true
                  Layout.minimumWidth: 0
                  text: "Dual-kawase backdrop blur behind translucent shell windows"
                  font.family: Style.font.family
                  font.pixelSize: 10
                  color: Color.muted
                  wrapMode: Text.WordWrap
                }
              }

              Rectangle {
                width: 60
                height: 28
                radius: 14
                color: root.blur ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
                border.color: root.blur ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
                border.width: 1

                Text {
                  anchors.centerIn: parent
                  text: root.blur ? "ON" : "OFF"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  font.bold: true
                  color: root.blur ? Color.accent : Color.muted
                }
              }
            }
          }
        }
      }

      // Card 4: Menu Bar & Workspace Tiling
      Rectangle {
        id: card4
        Layout.fillWidth: true
        implicitHeight: card4Col.implicitHeight + 24
        Layout.preferredHeight: implicitHeight
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02)
        border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
        border.width: 1
        radius: Style.cornerRadius || 8

        ColumnLayout {
          id: card4Col
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 12
          spacing: 8

          // Header
          RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
              text: "󰍜"
              font.family: Style.font.family
              font.pixelSize: 18
              color: Color.accent
            }

            Text {
              text: "Top Bar & Workspace Layout"
              font.family: Style.font.family
              font.pixelSize: Style.font.subtitle || 14
              font.bold: true
              color: Color.foreground
            }
          }

          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Color.muted
            opacity: 0.15
          }

          // Top Bar Visibility
          Rectangle {
            id: barRow
            Layout.fillWidth: true
            implicitHeight: Math.max(46, barInnerRow.implicitHeight + 14)
            Layout.preferredHeight: implicitHeight
            radius: 6
            readonly property bool isFocused: root.isContentFocused && root.focusedCard === 7
            readonly property bool isHovered: barMouse.containsMouse
            color: isFocused ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, isHovered ? 0.18 : 0.14) : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : "transparent")
            border.color: isFocused ? Color.accent : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : "transparent")
            border.width: isFocused ? 2 : 1

            MouseArea {
              id: barMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (root.panelRoot) root.panelRoot.focusSection = "content"
                root.focusedCard = 7
                root.toggleBar()
              }
            }

            RowLayout {
              id: barInnerRow
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.margins: 8
              spacing: 10

              ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 1

                Flow {
                  Layout.fillWidth: true
                  width: parent.width
                  spacing: 6

                  Text {
                    text: "Menu Bar Visibility"
                    font.family: Style.font.family
                    font.pixelSize: 12
                    font.bold: true
                    color: Color.foreground
                  }

                  Rectangle {
                    width: 16
                    height: 16
                    radius: 3
                    color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
                    border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
                    border.width: 1
                    Text {
                      anchors.centerIn: parent
                      text: "T"
                      font.family: Style.font.family
                      font.pixelSize: 9
                      color: Color.muted
                    }
                  }
                }

                Text {
                  Layout.fillWidth: true
                  Layout.minimumWidth: 0
                  text: "Toggle status bar visibility without stopping the Omarchy shell"
                  font.family: Style.font.family
                  font.pixelSize: 10
                  color: Color.muted
                  wrapMode: Text.WordWrap
                }
              }

              Rectangle {
                width: 78
                height: 28
                radius: 14
                color: !root.barHidden ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
                border.color: !root.barHidden ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
                border.width: 1

                Text {
                  anchors.centerIn: parent
                  text: root.barHidden ? "HIDDEN" : "VISIBLE"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  font.bold: true
                  color: !root.barHidden ? Color.accent : Color.muted
                }
              }
            }
          }

          // Bar Edge Position
          Rectangle {
            id: barPosRow
            Layout.fillWidth: true
            implicitHeight: Math.max(46, barPosInnerRow.implicitHeight + 14)
            Layout.preferredHeight: implicitHeight
            radius: 6
            readonly property bool isFocused: root.isContentFocused && root.focusedCard === 8
            readonly property bool isHovered: barPosMouse.containsMouse
            color: isFocused ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, isHovered ? 0.18 : 0.14) : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : "transparent")
            border.color: isFocused ? Color.accent : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : "transparent")
            border.width: isFocused ? 2 : 1

            MouseArea {
              id: barPosMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (root.panelRoot) root.panelRoot.focusSection = "content"
                root.focusedCard = 8
                root.cycleBarPosition()
              }
            }

            RowLayout {
              id: barPosInnerRow
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.margins: 8
              spacing: 10

              ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 1

                Flow {
                  Layout.fillWidth: true
                  width: parent.width
                  spacing: 6

                  Text {
                    text: "Bar Edge Position"
                    font.family: Style.font.family
                    font.pixelSize: 12
                    font.bold: true
                    color: Color.foreground
                  }

                  Rectangle {
                    width: 16
                    height: 16
                    radius: 3
                    color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
                    border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
                    border.width: 1
                    Text {
                      anchors.centerIn: parent
                      text: "P"
                      font.family: Style.font.family
                      font.pixelSize: 9
                      color: Color.muted
                    }
                  }
                }

                Text {
                  Layout.fillWidth: true
                  Layout.minimumWidth: 0
                  text: "Dock the menu bar to top or bottom screen edge"
                  font.family: Style.font.family
                  font.pixelSize: 10
                  color: Color.muted
                  wrapMode: Text.WordWrap
                }
              }

              Rectangle {
                width: 78
                height: 28
                radius: 14
                color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
                border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60)
                border.width: 1

                Text {
                  anchors.centerIn: parent
                  text: root.barPosition.toUpperCase()
                  font.family: Style.font.family
                  font.pixelSize: 11
                  font.bold: true
                  color: Color.accent
                }
              }
            }
          }

          // Bar Transparency
          Rectangle {
            id: barTransRow
            Layout.fillWidth: true
            implicitHeight: Math.max(46, barTransInnerRow.implicitHeight + 14)
            Layout.preferredHeight: implicitHeight
            radius: 6
            readonly property bool isFocused: root.isContentFocused && root.focusedCard === 9
            readonly property bool isHovered: barTransMouse.containsMouse
            color: isFocused ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, isHovered ? 0.18 : 0.14) : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : "transparent")
            border.color: isFocused ? Color.accent : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : "transparent")
            border.width: isFocused ? 2 : 1

            MouseArea {
              id: barTransMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (root.panelRoot) root.panelRoot.focusSection = "content"
                root.focusedCard = 9
                root.toggleBarTransparent()
              }
            }

            RowLayout {
              id: barTransInnerRow
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.margins: 8
              spacing: 10

              ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 1

                Flow {
                  Layout.fillWidth: true
                  width: parent.width
                  spacing: 6

                  Text {
                    text: "Bar Transparency"
                    font.family: Style.font.family
                    font.pixelSize: 12
                    font.bold: true
                    color: Color.foreground
                  }

                  Rectangle {
                    width: 16
                    height: 16
                    radius: 3
                    color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
                    border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
                    border.width: 1
                    Text {
                      anchors.centerIn: parent
                      text: "E"
                      font.family: Style.font.family
                      font.pixelSize: 9
                      color: Color.muted
                    }
                  }
                }

                Text {
                  Layout.fillWidth: true
                  Layout.minimumWidth: 0
                  text: "Transparent floating island vs solid edge bar style"
                  font.family: Style.font.family
                  font.pixelSize: 10
                  color: Color.muted
                  wrapMode: Text.WordWrap
                }
              }

              Rectangle {
                width: 96
                height: 28
                radius: 14
                color: root.barTransparent ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
                border.color: root.barTransparent ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
                border.width: 1

                Text {
                  anchors.centerIn: parent
                  text: root.barTransparent ? "TRANSPARENT" : "SOLID"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  font.bold: true
                  color: root.barTransparent ? Color.accent : Color.muted
                }
              }
            }
          }

          // Workspace Tiling Layout
          Rectangle {
            id: layoutRow
            Layout.fillWidth: true
            implicitHeight: Math.max(46, layoutInnerRow.implicitHeight + 14)
            Layout.preferredHeight: implicitHeight
            radius: 6
            readonly property bool isFocused: root.isContentFocused && root.focusedCard === 10
            readonly property bool isHovered: layoutMouse.containsMouse
            color: isFocused ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, isHovered ? 0.18 : 0.14) : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : "transparent")
            border.color: isFocused ? Color.accent : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : "transparent")
            border.width: isFocused ? 2 : 1

            MouseArea {
              id: layoutMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (root.panelRoot) root.panelRoot.focusSection = "content"
                root.focusedCard = 10
                root.toggleWorkspaceLayout()
              }
            }

            RowLayout {
              id: layoutInnerRow
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.margins: 8
              spacing: 10

              ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 1

                Flow {
                  Layout.fillWidth: true
                  width: parent.width
                  spacing: 6

                  Text {
                    text: "Workspace Tiling Layout"
                    font.family: Style.font.family
                    font.pixelSize: 12
                    font.bold: true
                    color: Color.foreground
                  }

                  Rectangle {
                    width: 16
                    height: 16
                    radius: 3
                    color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
                    border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
                    border.width: 1
                    Text {
                      anchors.centerIn: parent
                      text: "W"
                      font.family: Style.font.family
                      font.pixelSize: 9
                      color: Color.muted
                    }
                  }
                }

                Text {
                  Layout.fillWidth: true
                  Layout.minimumWidth: 0
                  text: "Tiling algorithm on active workspace (Dwindle spiral vs horizontal scrolling)"
                  font.family: Style.font.family
                  font.pixelSize: 10
                  color: Color.muted
                  wrapMode: Text.WordWrap
                }
              }

              Rectangle {
                width: 96
                height: 28
                radius: 14
                color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
                border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60)
                border.width: 1

                Text {
                  anchors.centerIn: parent
                  text: root.workspaceLayout === "dwindle" ? "DWINDLE" : "SCROLLING"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  font.bold: true
                  color: Color.accent
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
