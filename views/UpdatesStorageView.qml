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

  property string pluginPath: (Quickshell.env("HOME") || "/home/ac") + "/.config/omarchy/plugins/ac.control-panel"
  onPluginPathChanged: refresh()

  property var panelRoot: null
  property bool activeFocusSection: false
  readonly property bool isContentFocused: root.panelRoot ? (root.panelRoot.focusSection === "content") : root.activeFocusSection

  property int currentTab: 0 // 0: Updates, 1: Storage & Cache
  property int focusedAction: 0 // 0: Update All, 1: Prune Cache, 2: Vacuum Journal, 3: Remove Orphans
  property string statusMessage: ""

  readonly property var scrollArea: (currentTab === 0 ? updatesScroll : diskScroll)
  readonly property var updatesScroll: (currentTab === 0 ? updatesScroll : diskScroll)

  // State data
  property int totalUpdates: 0
  property int pacmanCount: 0
  property int aurCount: 0
  property var pacmanItems: []
  property var aurItems: []

  property var partitions: []
  property string pacmanCacheSize: "0B"
  property string journalSize: "0B"
  property string userCacheSize: "0B"
  property int orphansCount: 0
  property bool isRefreshing: false

  function refresh() {
    if (!stateProcess.running && pluginPath.length > 0) {
      isRefreshing = true
      stateProcess.command = [pluginPath + "/scripts/updates-storage-control.sh", "get-state"]
      stateProcess.running = true
    }
  }

  function launchUpdate() {
    actionProcess.command = [pluginPath + "/scripts/updates-storage-control.sh", "launch-update"]
    actionProcess.running = true
    notifyStatus("Launched System Update in terminal window")
  }

  function prunePacmanCache() {
    actionProcess.command = [pluginPath + "/scripts/updates-storage-control.sh", "prune-cache"]
    actionProcess.running = true
    notifyStatus("Launched package cache pruning")
  }

  function vacuumJournal() {
    actionProcess.command = [pluginPath + "/scripts/updates-storage-control.sh", "vacuum-journal"]
    actionProcess.running = true
    notifyStatus("Launched journal log vacuuming")
  }

  function removeOrphans() {
    actionProcess.command = [pluginPath + "/scripts/updates-storage-control.sh", "remove-orphans"]
    actionProcess.running = true
    notifyStatus("Checking orphaned packages in terminal")
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

  function ensureActionVisible(action) {
    if (currentTab !== 1 || !diskScroll || !diskScroll.contentItem) return
    var flick = diskScroll.contentItem
    if (action === 0) {
      flick.contentY = 0
      return
    }
    var target = null
    if (action === 1) target = pacmanCard
    else if (action === 2) target = journalCard
    else if (action === 3) target = orphansCard
    if (!target) return

    var pos = target.mapToItem(flick, 0, 0)
    var targetY = pos.y
    var targetH = target.height

    if (targetY < flick.contentY + 10) {
      flick.contentY = Math.max(0, targetY - 10)
    } else if (targetY + targetH > flick.contentY + diskScroll.height - 10) {
      flick.contentY = Math.max(0, targetY + targetH - diskScroll.height + 10)
    }
  }

  function handleMove(dx, dy) {
    if (dx !== 0) {
      if (dx < 0 && currentTab === 0) return false
      var nextTab = Math.max(0, Math.min(1, currentTab + (dx > 0 ? 1 : -1)))
      if (nextTab === currentTab) return true
      currentTab = nextTab
      ensureActionVisible(focusedAction)
      return true
    } else if (dy !== 0) {
      focusedAction = Math.max(0, Math.min(3, focusedAction + dy))
      ensureActionVisible(focusedAction)
      return true
    }
    return false
  }

  function handleActivate() {
    if (currentTab === 0) {
      launchUpdate()
    } else {
      if (focusedAction === 0) launchUpdate()
      else if (focusedAction === 1) prunePacmanCache()
      else if (focusedAction === 2) vacuumJournal()
      else if (focusedAction === 3) removeOrphans()
    }
  }

  function handleTextKey(key) {
    var k = key.toLowerCase()
    if (k === "h") {
      return handleMove(-1, 0)
    } else if (k === "l") {
      return handleMove(1, 0)
    } else if (k === "u") {
      launchUpdate()
      return true
    } else if (k === "p") {
      prunePacmanCache()
      return true
    } else if (k === "v") {
      vacuumJournal()
      return true
    } else if (k === "o") {
      removeOrphans()
      return true
    } else if (k === "r") {
      refresh()
      notifyStatus("Checking for updates and storage usage...")
      return true
    } else if (k === "1") {
      currentTab = 0
      return true
    } else if (k === "2") {
      currentTab = 1
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
          if (data.updates) {
            root.totalUpdates = Number(data.updates.total_count) || 0
            root.pacmanCount = Number(data.updates.pacman_count) || 0
            root.aurCount = Number(data.updates.aur_count) || 0
            root.pacmanItems = Array.isArray(data.updates.pacman_items) ? data.updates.pacman_items : []
            root.aurItems = Array.isArray(data.updates.aur_items) ? data.updates.aur_items : []
          }
          if (data.storage) {
            root.partitions = Array.isArray(data.storage.partitions) ? data.storage.partitions : []
            root.pacmanCacheSize = String(data.storage.pacman_cache || "0B")
            root.journalSize = String(data.storage.journal_size || "0B")
            root.userCacheSize = String(data.storage.user_cache || "0B")
            root.orphansCount = Number(data.storage.orphans_count) || 0
          }
        } catch (e) {
          console.log("Error parsing updates/storage state:", e)
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
      color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15)
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
      id: topBannerCard
      Layout.fillWidth: true
      implicitHeight: Math.max(90, topBannerCol.implicitHeight + 24)
      Layout.preferredHeight: implicitHeight
      radius: Style.cornerRadius || 8
      readonly property bool isFocused: root.isContentFocused && root.focusedAction === 0
      readonly property bool isHovered: topBannerMouse.containsMouse
      color: isFocused ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, isHovered ? 0.08 : 0.06) : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02))
      border.color: isFocused ? Color.accent : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08))
      border.width: isFocused ? 2 : 1

      MouseArea {
        id: topBannerMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          if (root.panelRoot) root.panelRoot.focusSection = "content"
          root.focusedAction = 0
        }
      }

      ColumnLayout {
        id: topBannerCol
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 12
        spacing: 10

        RowLayout {
          Layout.fillWidth: true
          spacing: 12

          // Big Status Icon
          Rectangle {
            width: 36
            height: 36
            radius: 18
            color: root.totalUpdates > 0
              ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
              : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06)
            border.color: root.totalUpdates > 0 ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.40) : "transparent"
            border.width: 1

            Text {
              anchors.centerIn: parent
              text: root.totalUpdates > 0 ? "󰚰" : "󰄬"
              font.family: Style.font.family
              font.pixelSize: 18
              color: root.totalUpdates > 0 ? Color.accent : Color.muted
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 0
            spacing: 2

            RowLayout {
              spacing: 8
              Text {
                text: root.totalUpdates > 0 ? (root.totalUpdates + " Updates Available") : "System is Up to Date"
                font.family: Style.font.family
                font.pixelSize: 15
                font.bold: true
                color: Color.foreground
              }

              Rectangle {
                visible: root.totalUpdates > 0
                Layout.preferredHeight: 20
                Layout.preferredWidth: updateCountText.implicitWidth + 14
                radius: 10
                color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
                border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60)
                border.width: 1

                Text {
                  id: updateCountText
                  anchors.centerIn: parent
                  text: root.pacmanCount + " pacman • " + root.aurCount + " aur"
                  font.family: Style.font.family
                  font.pixelSize: 10
                  font.bold: true
                  color: Color.accent
                }
              }
            }

            Text {
              Layout.fillWidth: true
              wrapMode: Text.WordWrap
              text: root.totalUpdates > 0
                ? "Arch Linux and AUR packages have newer versions ready to install"
                : "All packages and repositories are synced with latest versions"
              font.family: Style.font.family
              font.pixelSize: 12
              color: Color.muted
            }
          }
        }

        // Action Buttons
        RowLayout {
          Layout.fillWidth: true
          spacing: 8

          Item { Layout.fillWidth: true }

          Rectangle {
            implicitWidth: refreshBtnText.implicitWidth + 24
            implicitHeight: 28
            radius: 6
            readonly property bool btnHover: refreshBtnMouse.containsMouse
            color: btnHover ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06)
            border.color: btnHover ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.3) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
            border.width: 1

            Text {
              id: refreshBtnText
              anchors.centerIn: parent
              text: root.isRefreshing ? "Checking..." : "󰑐 Refresh [R]"
              font.family: Style.font.family
              font.pixelSize: 11
              font.bold: true
              color: parent.btnHover ? Color.foreground : Color.muted
            }

            MouseArea {
              id: refreshBtnMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              enabled: !root.isRefreshing
              onClicked: root.refresh()
            }
          }

          Rectangle {
            implicitWidth: updateBtnText.implicitWidth + 24
            implicitHeight: 28
            radius: 6
            readonly property bool btnHover: updateBtnMouse.containsMouse
            color: root.totalUpdates > 0
              ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, btnHover ? 0.30 : 0.20)
              : (btnHover ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06))
            border.color: root.totalUpdates > 0
              ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60)
              : (btnHover ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.3) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15))
            border.width: 1

            Text {
              id: updateBtnText
              anchors.centerIn: parent
              text: "󰚰 Update System [U]"
              font.family: Style.font.family
              font.pixelSize: 11
              font.bold: true
              color: root.totalUpdates > 0 ? Color.accent : (parent.btnHover ? Color.foreground : Color.muted)
            }

            MouseArea {
              id: updateBtnMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.launchUpdate()
            }
          }
        }
      }
    }

    // Tab Bar (Updates vs Disk & Storage - Responsive Flow)
    Flow {
      id: tabBarFlow
      Layout.fillWidth: true
      width: parent.width
      spacing: 8

      readonly property int count: 2
      readonly property int minItemWidth: 170
      readonly property int cols: Math.max(1, Math.min(count, Math.floor((width + spacing) / (minItemWidth + spacing))))
      readonly property real itemWidth: Math.max(100, Math.floor((width - (cols - 1) * spacing) / cols))

      Rectangle {
        id: tabUpdates
        width: tabBarFlow.itemWidth
        height: 36
        radius: 6
        readonly property bool isTabActive: root.currentTab === 0
        readonly property bool isTabHovered: tabUpdatesMouse.containsMouse
        color: isTabActive
          ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, isTabHovered ? 0.28 : 0.20)
          : (isTabHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.03))
        border.color: isTabActive ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60) : (isTabHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08))
        border.width: 1

        MouseArea {
          id: tabUpdatesMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (root.panelRoot) root.panelRoot.focusSection = "content"
            root.currentTab = 0
          }
        }

        RowLayout {
          anchors.centerIn: parent
          width: Math.min(implicitWidth, parent.width - 16)
          spacing: 6

          Rectangle {
            visible: tabUpdates.isTabActive
            width: 5
            height: 5
            radius: 2.5
            color: Color.accent
          }

          Text {
            text: "󰚰"
            font.family: Style.font.family
            font.pixelSize: 13
            color: tabUpdates.isTabActive ? Color.accent : Color.muted
          }

          Text {
            text: "Pending Updates (" + root.totalUpdates + ")"
            font.family: Style.font.family
            font.pixelSize: 12
            font.bold: tabUpdates.isTabActive
            color: tabUpdates.isTabActive ? Color.accent : Color.muted
            elide: Text.ElideRight
          }
        }
      }

      Rectangle {
        id: tabDisk
        width: tabBarFlow.itemWidth
        height: 36
        radius: 6
        readonly property bool isTabActive: root.currentTab === 1
        readonly property bool isTabHovered: tabDiskMouse.containsMouse
        color: isTabActive
          ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, isTabHovered ? 0.28 : 0.20)
          : (isTabHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.03))
        border.color: isTabActive ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60) : (isTabHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08))
        border.width: 1

        MouseArea {
          id: tabDiskMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (root.panelRoot) root.panelRoot.focusSection = "content"
            root.currentTab = 1
          }
        }

        RowLayout {
          anchors.centerIn: parent
          width: Math.min(implicitWidth, parent.width - 16)
          spacing: 6

          Rectangle {
            visible: tabDisk.isTabActive
            width: 5
            height: 5
            radius: 2.5
            color: Color.accent
          }

          Text {
            text: "󰋊"
            font.family: Style.font.family
            font.pixelSize: 13
            color: tabDisk.isTabActive ? Color.accent : Color.muted
          }

          Text {
            text: "Disk & Maintenance"
            font.family: Style.font.family
            font.pixelSize: 12
            font.bold: tabDisk.isTabActive
            color: tabDisk.isTabActive ? Color.accent : Color.muted
            elide: Text.ElideRight
          }
        }
      }
    }

    // Tab 0: Updates List
    ScrollView {
      id: updatesScroll
      visible: root.currentTab === 0
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true
      ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
      ScrollBar.vertical.policy: ScrollBar.AsNeeded

      ColumnLayout {
        width: Math.max(200, updatesScroll.availableWidth - 12)
        spacing: 8

        // Empty state
        Rectangle {
          visible: root.totalUpdates === 0
          Layout.fillWidth: true
          Layout.preferredHeight: 140
          radius: Style.cornerRadius || 8
          color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02)
          border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
          border.width: 1

          ColumnLayout {
            anchors.centerIn: parent
            spacing: 8

            Text {
              Layout.alignment: Qt.AlignHCenter
              text: "󰄬"
              font.family: Style.font.family
              font.pixelSize: 28
              color: Color.accent
            }

            Text {
              Layout.alignment: Qt.AlignHCenter
              text: "Your system is completely up to date!"
              font.family: Style.font.family
              font.pixelSize: 14
              font.bold: true
              color: Color.foreground
            }

            Text {
              Layout.alignment: Qt.AlignHCenter
              text: "Press [R] anytime to run another check"
              font.family: Style.font.family
              font.pixelSize: 12
              color: Color.muted
            }
          }
        }

        // Pacman Updates Section
        Text {
          visible: root.pacmanCount > 0
          text: "󰮯 Official Packages (" + root.pacmanCount + ")"
          font.family: Style.font.family
          font.pixelSize: 12
          font.bold: true
          color: Color.muted
        }

        Repeater {
          model: root.pacmanItems

          delegate: Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            radius: 6
            readonly property bool isHovered: pkgMouse.containsMouse
            color: isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02)
            border.color: isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
            border.width: 1

            MouseArea {
              id: pkgMouse
              anchors.fill: parent
              hoverEnabled: true
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 12
              anchors.rightMargin: 12
              spacing: 12

              Text {
                text: "󰮯"
                font.family: Style.font.family
                font.pixelSize: 14
                color: Color.accent
              }

              Text {
                text: modelData.name
                font.family: Style.font.family
                font.pixelSize: 13
                font.bold: true
                color: Color.foreground
              }

              Item { Layout.fillWidth: true }

              Text {
                text: modelData.old_version
                font.family: Style.font.family
                font.pixelSize: 11
                color: Color.muted
              }

              Text {
                text: "→"
                font.family: Style.font.family
                font.pixelSize: 11
                color: Color.muted
              }

              Rectangle {
                Layout.preferredHeight: 22
                Layout.preferredWidth: verText.implicitWidth + 14
                radius: 4
                color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
                border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60)
                border.width: 1

                Text {
                  id: verText
                  anchors.centerIn: parent
                  text: modelData.new_version
                  font.family: Style.font.family
                  font.pixelSize: 11
                  font.bold: true
                  color: Color.accent
                }
              }
            }
          }
        }

        // AUR Updates Section
        Text {
          visible: root.aurCount > 0
          Layout.topMargin: 8
          text: "󰣇 AUR Packages (" + root.aurCount + ")"
          font.family: Style.font.family
          font.pixelSize: 12
          font.bold: true
          color: Color.muted
        }

        Repeater {
          model: root.aurItems

          delegate: Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            radius: 6
            readonly property bool isHovered: aurMouse.containsMouse
            color: isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02)
            border.color: isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
            border.width: 1

            MouseArea {
              id: aurMouse
              anchors.fill: parent
              hoverEnabled: true
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 12
              anchors.rightMargin: 12
              spacing: 12

              Text {
                text: "󰣇"
                font.family: Style.font.family
                font.pixelSize: 14
                color: Color.accent
              }

              Text {
                text: modelData.name
                font.family: Style.font.family
                font.pixelSize: 13
                font.bold: true
                color: Color.foreground
              }

              Item { Layout.fillWidth: true }

              Text {
                text: modelData.old_version
                font.family: Style.font.family
                font.pixelSize: 11
                color: Color.muted
              }

              Text {
                text: "→"
                font.family: Style.font.family
                font.pixelSize: 11
                color: Color.muted
              }

              Rectangle {
                Layout.preferredHeight: 22
                Layout.preferredWidth: aurVerText.implicitWidth + 14
                radius: 4
                color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
                border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60)
                border.width: 1

                Text {
                  id: aurVerText
                  anchors.centerIn: parent
                  text: modelData.new_version
                  font.family: Style.font.family
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

    // Tab 1: Disk Partitions & Maintenance
    ScrollView {
      id: diskScroll
      visible: root.currentTab === 1
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true
      ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
      ScrollBar.vertical.policy: ScrollBar.AsNeeded

      ColumnLayout {
        width: Math.max(200, diskScroll.availableWidth - 12)
        spacing: 12

        // Partitions Header
        Text {
          text: "󰋊 Storage Partitions"
          font.family: Style.font.family
          font.pixelSize: 13
          font.bold: true
          color: Color.foreground
        }

        Repeater {
          model: root.partitions

          delegate: Rectangle {
            id: partCard
            Layout.fillWidth: true
            width: parent ? parent.width : undefined
            implicitHeight: Math.max(76, partCol.implicitHeight + 24)
            Layout.preferredHeight: implicitHeight
            radius: Style.cornerRadius || 8
            color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02)
            border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
            border.width: 1

            ColumnLayout {
              id: partCol
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.margins: 12
              spacing: 8

              Flow {
                Layout.fillWidth: true
                width: parent.width
                spacing: 8

                Text {
                  text: modelData.label
                  font.family: Style.font.family
                  font.pixelSize: 13
                  font.bold: true
                  color: Color.foreground
                }

                Text {
                  text: modelData.used_str + " used of " + modelData.total_str + " (" + modelData.percent + "%)"
                  font.family: Style.font.family
                  font.pixelSize: 12
                  font.bold: true
                  color: Color.muted
                }
              }

              // Usage Progress Bar
              Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 8
                radius: 4
                color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)

                Rectangle {
                  width: Math.max(8, parent.width * (Math.min(100, modelData.percent) / 100))
                  height: parent.height
                  radius: 4
                  color: modelData.percent > 90 ? "#e78284" : (modelData.percent > 75 ? "#e5c890" : Color.accent)
                }
              }

              Flow {
                Layout.fillWidth: true
                width: parent.width
                spacing: 8

                Text {
                  text: modelData.avail_str + " free"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  color: Color.muted
                }

                Text {
                  text: "Mounted on " + modelData.mount
                  font.family: Style.font.family
                  font.pixelSize: 11
                  color: Color.muted
                }
              }
            }
          }
        }

        // Maintenance & Cache Section
        Text {
          Layout.topMargin: 6
          text: "󰃢 Cache & Cleanup Tools"
          font.family: Style.font.family
          font.pixelSize: 13
          font.bold: true
          color: Color.foreground
        }

        // Card 1: Pacman Cache
        Rectangle {
          id: pacmanCard
          Layout.fillWidth: true
          width: parent ? parent.width : undefined
          implicitHeight: Math.max(68, pacmanCol.implicitHeight + 24)
          Layout.preferredHeight: implicitHeight
          radius: Style.cornerRadius || 8
          readonly property bool isFocused: root.isContentFocused && root.focusedAction === 1
          readonly property bool isHovered: pacmanMouse.containsMouse
          color: isFocused ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, isHovered ? 0.08 : 0.06) : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02))
          border.color: isFocused ? Color.accent : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08))
          border.width: isFocused ? 2 : 1

          MouseArea {
            id: pacmanMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (root.panelRoot) root.panelRoot.focusSection = "content"
              root.focusedAction = 1
            }
          }

          ColumnLayout {
            id: pacmanCol
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 12
            spacing: 8

            Flow {
              Layout.fillWidth: true
              width: parent.width
              spacing: 8

              RowLayout {
                spacing: 8
                Text {
                  text: "󰮯"
                  font.family: Style.font.family
                  font.pixelSize: 18
                  color: Color.accent
                }

                Text {
                  text: "Pacman Package Cache"
                  font.family: Style.font.family
                  font.pixelSize: 13
                  font.bold: true
                  color: Color.foreground
                }

                Rectangle {
                  height: 20
                  width: pacSizeText.implicitWidth + 12
                  radius: 4
                  color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
                  border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60)
                  border.width: 1

                  Text {
                    id: pacSizeText
                    anchors.centerIn: parent
                    text: root.pacmanCacheSize
                    font.family: Style.font.family
                    font.pixelSize: 11
                    font.bold: true
                    color: Color.accent
                  }
                }
              }

              Rectangle {
                implicitWidth: pruneBtnText.implicitWidth + 20
                implicitHeight: 26
                radius: 4
                readonly property bool btnHover: pruneBtnMouse.containsMouse
                color: btnHover ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06)
                border.color: btnHover ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.3) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
                border.width: 1

                Text {
                  id: pruneBtnText
                  anchors.centerIn: parent
                  text: "Prune Cache [P]"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  color: parent.btnHover ? Color.foreground : Color.muted
                }

                MouseArea {
                  id: pruneBtnMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (root.panelRoot) root.panelRoot.focusSection = "content"
                    root.focusedAction = 1
                    root.prunePacmanCache()
                  }
                }
              }
            }

            Text {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              wrapMode: Text.WordWrap
              text: "Prune superseded packages with paccache -rk2, keeping 2 offline rollback copies"
              font.family: Style.font.family
              font.pixelSize: 11
              color: Color.muted
            }
          }
        }

        // Card 2: Systemd Journal Logs
        Rectangle {
          id: journalCard
          Layout.fillWidth: true
          width: parent ? parent.width : undefined
          implicitHeight: Math.max(68, journalCol.implicitHeight + 24)
          Layout.preferredHeight: implicitHeight
          radius: Style.cornerRadius || 8
          readonly property bool isFocused: root.isContentFocused && root.focusedAction === 2
          readonly property bool isHovered: journalMouse.containsMouse
          color: isFocused ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, isHovered ? 0.08 : 0.06) : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02))
          border.color: isFocused ? Color.accent : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08))
          border.width: isFocused ? 2 : 1

          MouseArea {
            id: journalMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (root.panelRoot) root.panelRoot.focusSection = "content"
              root.focusedAction = 2
            }
          }

          ColumnLayout {
            id: journalCol
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 12
            spacing: 8

            Flow {
              Layout.fillWidth: true
              width: parent.width
              spacing: 8

              RowLayout {
                spacing: 8
                Text {
                  text: "󰌱"
                  font.family: Style.font.family
                  font.pixelSize: 18
                  color: Color.accent
                }

                Text {
                  text: "Systemd Journal Logs"
                  font.family: Style.font.family
                  font.pixelSize: 13
                  font.bold: true
                  color: Color.foreground
                }

                Rectangle {
                  height: 20
                  width: jnlSizeText.implicitWidth + 12
                  radius: 4
                  color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
                  border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
                  border.width: 1

                  Text {
                    id: jnlSizeText
                    anchors.centerIn: parent
                    text: root.journalSize
                    font.family: Style.font.family
                    font.pixelSize: 11
                    font.bold: true
                    color: Color.muted
                  }
                }
              }

              Rectangle {
                implicitWidth: vacuumBtnText.implicitWidth + 20
                implicitHeight: 26
                radius: 4
                readonly property bool btnHover: vacuumBtnMouse.containsMouse
                color: btnHover ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06)
                border.color: btnHover ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.3) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
                border.width: 1

                Text {
                  id: vacuumBtnText
                  anchors.centerIn: parent
                  text: "Vacuum Logs [V]"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  color: parent.btnHover ? Color.foreground : Color.muted
                }

                MouseArea {
                  id: vacuumBtnMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (root.panelRoot) root.panelRoot.focusSection = "content"
                    root.focusedAction = 2
                    root.vacuumJournal()
                  }
                }
              }
            }

            Text {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              wrapMode: Text.WordWrap
              text: "Vacuum older logs, keeping the last 7 days of diagnostics"
              font.family: Style.font.family
              font.pixelSize: 11
              color: Color.muted
            }
          }
        }

        // Card 3: Orphan Packages
        Rectangle {
          id: orphansCard
          Layout.fillWidth: true
          width: parent ? parent.width : undefined
          implicitHeight: Math.max(68, orphansCol.implicitHeight + 24)
          Layout.preferredHeight: implicitHeight
          radius: Style.cornerRadius || 8
          readonly property bool isFocused: root.isContentFocused && root.focusedAction === 3
          readonly property bool isHovered: orphansMouse.containsMouse
          color: isFocused ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, isHovered ? 0.08 : 0.06) : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02))
          border.color: isFocused ? Color.accent : (isHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08))
          border.width: isFocused ? 2 : 1

          MouseArea {
            id: orphansMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (root.panelRoot) root.panelRoot.focusSection = "content"
              root.focusedAction = 3
            }
          }

          ColumnLayout {
            id: orphansCol
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 12
            spacing: 8

            Flow {
              Layout.fillWidth: true
              width: parent.width
              spacing: 8

              RowLayout {
                spacing: 8
                Text {
                  text: "󰏗"
                  font.family: Style.font.family
                  font.pixelSize: 18
                  color: Color.accent
                }

                Text {
                  text: "Orphaned Packages"
                  font.family: Style.font.family
                  font.pixelSize: 13
                  font.bold: true
                  color: Color.foreground
                }

                Rectangle {
                  height: 20
                  width: orphText.implicitWidth + 12
                  radius: 4
                  color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
                  border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
                  border.width: 1

                  Text {
                    id: orphText
                    anchors.centerIn: parent
                    text: root.orphansCount + " packages"
                    font.family: Style.font.family
                    font.pixelSize: 11
                    font.bold: true
                    color: Color.muted
                  }
                }
              }

              Rectangle {
                implicitWidth: orphansBtnText.implicitWidth + 20
                implicitHeight: 26
                radius: 4
                readonly property bool btnHover: orphansBtnMouse.containsMouse
                color: btnHover ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06)
                border.color: btnHover ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.3) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
                border.width: 1

                Text {
                  id: orphansBtnText
                  anchors.centerIn: parent
                  text: "Check Orphans [O]"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  color: parent.btnHover ? Color.foreground : Color.muted
                }

                MouseArea {
                  id: orphansBtnMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (root.panelRoot) root.panelRoot.focusSection = "content"
                    root.focusedAction = 3
                    root.removeOrphans()
                  }
                }
              }
            }

            Text {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              wrapMode: Text.WordWrap
              text: "Review and safely remove dependency packages that are no longer needed"
              font.family: Style.font.family
              font.pixelSize: 11
              color: Color.muted
            }
          }
        }

        Item { Layout.fillHeight: true }
      }
    }
  }
}
