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
  property var panelRoot: null
  property bool activeFocusSection: false
  property int selectedResultIndex: 0

  readonly property bool hasActiveInput: searchField && searchField.activeFocus

  onActiveFocusSectionChanged: {
    if (activeFocusSection) {
      if (searchField) searchField.forceActiveFocus()
    } else {
      if (searchField) searchField.focus = false
    }
  }

  // Master index of all settings across all categories
  readonly property var settingsIndex: [
    // Displays
    { title: "Display Brightness", categoryId: "displays", categoryName: "Displays", categoryIcon: "󰍹", cardIndex: 0, desc: "Screen brightness slider, step increments, and dimming controls", keywords: "brightness screen light display backlight dim level" },
    { title: "Resolution & Refresh Rate", categoryId: "displays", categoryName: "Displays", categoryIcon: "󰍹", cardIndex: 1, desc: "Monitor resolution (e.g. 1920x1080) and refresh rate (60Hz, 144Hz)", keywords: "resolution refresh rate hz monitors display screen 1080p 4k 144hz 60hz" },
    { title: "Display Scaling & DPI", categoryId: "displays", categoryName: "Displays", categoryIcon: "󰍹", cardIndex: 2, desc: "Fractional and integer scaling factor for high-DPI displays", keywords: "scale scaling dpi zoom text size fractional scale monitor" },
    { title: "Night Light & Color Temperature", categoryId: "displays", categoryName: "Displays", categoryIcon: "󰍹", cardIndex: 3, desc: "Warm color temperature filter to reduce eye strain (Gammastep/Sunset)", keywords: "night light blue light temperature warm kelvin sunset gammastep eye strain" },
    { title: "Mirror & Extend Monitors", categoryId: "displays", categoryName: "Displays", categoryIcon: "󰍹", cardIndex: 0, desc: "Configure multi-monitor mirroring, extension, and position topology", keywords: "mirror extend dual monitors multiple screens external display layout" },

    // Power & Battery
    { title: "Power Profile & Performance", categoryId: "power", categoryName: "Power & Battery", categoryIcon: "󰂄", cardIndex: 0, desc: "Switch CPU governor between Performance, Balanced, and Power Saver", keywords: "power profile performance balanced power-saver battery cpu speed governor energy" },
    { title: "Battery Charge Threshold & Health", categoryId: "power", categoryName: "Power & Battery", categoryIcon: "󰂄", cardIndex: 1, desc: "Limit charge maximum (e.g. 80%) to prolong battery lifespan", keywords: "battery health charge limit threshold 80% battery longevity battery care" },
    { title: "Screen Timeout & Sleep", categoryId: "power", categoryName: "Power & Battery", categoryIcon: "󰂄", cardIndex: 2, desc: "Set idle timeout before display turns off or system suspends", keywords: "sleep screen timeout idle turn off screen display timeout suspend" },
    { title: "Stay Awake / Caffeine Mode", categoryId: "power", categoryName: "Power & Battery", categoryIcon: "󰂄", cardIndex: 3, desc: "Temporarily prevent screen sleep and system idling", keywords: "stay awake caffeine keep awake prevent sleep lock prevention" },

    // Appearance
    { title: "Desktop Theme & Wallpaper", categoryId: "appearance", categoryName: "Appearance", categoryIcon: "", cardIndex: 0, desc: "Apply system-wide color scheme (Tokyo Night, Catppuccin, Gruvbox, etc.)", keywords: "theme appearance dark mode light mode tokyo night catppuccin gruvbox colors wallpaper style" },
    { title: "Window Background Blur", categoryId: "appearance", categoryName: "Appearance", categoryIcon: "", cardIndex: 0, desc: "Kawase blur intensity behind translucent shell and windows", keywords: "blur transparent opacity glass frosted background blur" },

    // Sound
    { title: "Output Volume & Mute", categoryId: "sound", categoryName: "Sound", categoryIcon: "󰕾", cardIndex: 0, desc: "Adjust speaker or headphone volume and master mute", keywords: "volume sound audio speaker headphones loud mute volume slider" },
    { title: "Microphone & Input Volume", categoryId: "sound", categoryName: "Sound", categoryIcon: "󰕾", cardIndex: 1, desc: "Adjust recording level and mute input microphone", keywords: "mic microphone input voice record mute mic sound level" },
    { title: "Default Audio Device / Output Sink", categoryId: "sound", categoryName: "Sound", categoryIcon: "󰕾", cardIndex: 2, desc: "Select default PipeWire playback and recording device", keywords: "audio output speakers sound card pipewire wireplumber sink source" },

    // Network & Wi-Fi
    { title: "Wi-Fi Networks & Connections", categoryId: "network", categoryName: "Network & Wi-Fi", categoryIcon: "󰤨", cardIndex: 0, desc: "Scan, connect, and authenticate to available Wi-Fi access points", keywords: "wifi wireless network ssid internet connect wlan router" },
    { title: "Wi-Fi Power Toggle", categoryId: "network", categoryName: "Network & Wi-Fi", categoryIcon: "󰤨", cardIndex: 0, desc: "Turn Wi-Fi radio on or off (Airplane mode)", keywords: "wifi on wifi off airplane mode wireless enable radio" },
    { title: "Ethernet & IP Details", categoryId: "network", categoryName: "Network & Wi-Fi", categoryIcon: "󰤨", cardIndex: 1, desc: "Wired network connection status, IP address, and gateway", keywords: "ethernet lan cable wired ip address gateway mac address dns" },

    // Bluetooth
    { title: "Bluetooth Radio Toggle", categoryId: "bluetooth", categoryName: "Bluetooth", categoryIcon: "󰂯", cardIndex: 0, desc: "Enable or disable Bluetooth adapter power", keywords: "bluetooth bt wireless bluetooth on bluetooth off radio adapter" },
    { title: "Bluetooth Paired Devices", categoryId: "bluetooth", categoryName: "Bluetooth", categoryIcon: "󰂯", cardIndex: 1, desc: "Manage paired headphones, mice, keyboards, and gamepads", keywords: "pair connect bluetooth headphones mouse keyboard gamepad headset controller" },
    { title: "Bluetooth Device Scan", categoryId: "bluetooth", categoryName: "Bluetooth", categoryIcon: "󰂯", cardIndex: 2, desc: "Discover and pair nearby Bluetooth devices", keywords: "scan bluetooth discover pair new device nearby" },

    // Touch & Input
    { title: "Touchscreen Support", categoryId: "input", categoryName: "Touch & Input", categoryIcon: "󰆽", cardIndex: 0, desc: "Enable or disable touch screen input and stylus interaction", keywords: "touchscreen touch display stylus finger touch tablet touch" },
    { title: "Workspace Swipe Gesture", categoryId: "input", categoryName: "Touch & Input", categoryIcon: "󰆽", cardIndex: 1, desc: "Swipe with 3 fingers on touchscreen or touchpad to switch workspaces", keywords: "workspace swipe touch gesture swipe desktop 3 finger gestures" },
    { title: "Touchscreen Monitor Assignment", categoryId: "input", categoryName: "Touch & Input", categoryIcon: "󰆽", cardIndex: 2, desc: "Map touch digitizer to a specific monitor output", keywords: "touchscreen output map touch to screen display assignment" },
    { title: "Touchpad Enable / Disable", categoryId: "input", categoryName: "Touch & Input", categoryIcon: "󰆽", cardIndex: 3, desc: "Toggle internal laptop touchpad on or off", keywords: "touchpad trackpad disable touchpad enable touchpad mouse" },
    { title: "Natural Scrolling (Inverted)", categoryId: "input", categoryName: "Touch & Input", categoryIcon: "󰆽", cardIndex: 4, desc: "Reverse scrolling direction to mimic smartphone natural scroll", keywords: "natural scroll inverse scroll reverse scroll direction touchpad" },
    { title: "Touchpad Tap to Click", categoryId: "input", categoryName: "Touch & Input", categoryIcon: "󰆽", cardIndex: 5, desc: "Use 1-finger tap as left click and 2-finger tap as right click", keywords: "tap to click clickfinger tap touchpad left click right click tap" },
    { title: "Touchpad Scroll Speed Factor", categoryId: "input", categoryName: "Touch & Input", categoryIcon: "󰆽", cardIndex: 6, desc: "Adjust precision scroll multiplier for smooth web browsing", keywords: "scroll speed trackpad sensitivity scroll factor scroll multiplier" },
    { title: "Disable Touchpad While Typing", categoryId: "input", categoryName: "Touch & Input", categoryIcon: "󰆽", cardIndex: 7, desc: "Palm rejection to prevent accidental cursor movement while typing", keywords: "disable while typing palm rejection typing touchpad accidental clicks" },
    { title: "Pointer Sensitivity & Speed", categoryId: "input", categoryName: "Touch & Input", categoryIcon: "󰆽", cardIndex: 8, desc: "Mouse and touchpad pointer acceleration and base sensitivity", keywords: "pointer speed mouse sensitivity trackpad speed accel sensitivity cursor" },

    // Window Manager
    { title: "Window Animations", categoryId: "windows", categoryName: "Window Manager", categoryIcon: "", cardIndex: 0, desc: "Toggle window open, close, and workspace sliding animations", keywords: "animations window transitions fast instant smooth window animation" },
    { title: "Window Gaps (Inner & Outer)", categoryId: "windows", categoryName: "Window Manager", categoryIcon: "", cardIndex: 1, desc: "Set spacing distance between tiled windows and screen edges", keywords: "gaps gaps in gaps out margin spacing between windows padding" },
    { title: "Single Window Square Aspect", categoryId: "windows", categoryName: "Window Manager", categoryIcon: "", cardIndex: 2, desc: "Prevent solitary windows from stretching ultra-wide across widescreen monitors", keywords: "aspect ratio square window single window width widescreen 16:9 21:9" },
    { title: "Window Corner Rounding", categoryId: "windows", categoryName: "Window Manager", categoryIcon: "", cardIndex: 3, desc: "Adjust rounded corner radius (0px, 4px, 8px, 12px, 16px)", keywords: "rounding rounded corners border radius window corners round" },
    { title: "Window Border Thickness", categoryId: "windows", categoryName: "Window Manager", categoryIcon: "", cardIndex: 4, desc: "Set active and inactive window border outline width in pixels", keywords: "border border size window outline border width border thickness" },
    { title: "Inactive Window Dimming / Opacity", categoryId: "windows", categoryName: "Window Manager", categoryIcon: "", cardIndex: 5, desc: "Dim unfocused windows to focus on the active application", keywords: "inactive opacity focus dim dim unfocused windows transparency" },
    { title: "Window Background Blur", categoryId: "windows", categoryName: "Window Manager", categoryIcon: "", cardIndex: 6, desc: "Enable dual-kawase blur behind transparent applications", keywords: "blur window blur dual-kawase blur transparent blur" },
    { title: "Status Bar Visibility", categoryId: "windows", categoryName: "Window Manager", categoryIcon: "", cardIndex: 7, desc: "Show or hide the top status bar / menu bar", keywords: "menu bar top bar hide bar status bar taskbar autohide" },
    { title: "Status Bar Position (Top / Bottom)", categoryId: "windows", categoryName: "Window Manager", categoryIcon: "", cardIndex: 8, desc: "Dock status bar to either top or bottom screen edge", keywords: "bar position top bar bottom bar dock position edge" },
    { title: "Status Bar Transparency", categoryId: "windows", categoryName: "Window Manager", categoryIcon: "", cardIndex: 9, desc: "Toggle between floating translucent island and solid bar", keywords: "bar transparent solid bar translucent bar island floating" },
    { title: "Workspace Layout (Dwindle / Scrolling)", categoryId: "windows", categoryName: "Window Manager", categoryIcon: "", cardIndex: 10, desc: "Switch between automatic bspwm-style Dwindle and Scrolling layouts", keywords: "dwindle master scrolling layout tiling mode window layout hyprland" },

    // Default Apps
    { title: "Default Web Browser", categoryId: "defaults", categoryName: "Default Apps", categoryIcon: "󰌢", cardIndex: 0, desc: "Choose default browser (Brave, Chromium, Firefox, Chrome)", keywords: "browser web chrome chromium firefox brave default browser internet" },
    { title: "Default Text Editor", categoryId: "defaults", categoryName: "Default Apps", categoryIcon: "󰌢", cardIndex: 1, desc: "Choose default text editor (Neovim, VSCode, Nano, Vim)", keywords: "editor code nvim vim vscode nano text editor coding" },
    { title: "Default Terminal Emulator", categoryId: "defaults", categoryName: "Default Apps", categoryIcon: "󰌢", cardIndex: 2, desc: "Choose default terminal (Alacritty, Kitty, Ghostty, Foot)", keywords: "terminal console shell alacritty kitty foot ghostty prompt" },
    { title: "Default File Manager", categoryId: "defaults", categoryName: "Default Apps", categoryIcon: "󰌢", cardIndex: 3, desc: "Choose default file browser (Nautilus, Thunar, Dolphin)", keywords: "file manager files nautilus thunar dolphin folders directory explorer" },

    // Updates & Storage
    { title: "System Package Updates", categoryId: "updates", categoryName: "Updates & Storage", categoryIcon: "󰚰", cardIndex: 0, desc: "Check and apply Arch Linux system updates via pacman & yay", keywords: "updates upgrade pacman yay system update check updates software" },
    { title: "Disk Space & Storage Usage", categoryId: "updates", categoryName: "Updates & Storage", categoryIcon: "󰚰", cardIndex: 1, desc: "Monitor SSD/HDD disk usage across / and /home partitions", keywords: "disk space storage root partition home space free space drive ssd hdd" },
    { title: "Package Cache Cleaning", categoryId: "updates", categoryName: "Updates & Storage", categoryIcon: "󰚰", cardIndex: 2, desc: "Clean old pacman download cache to reclaim gigabytes of storage", keywords: "clean cache pacman cache free disk space paccache cleanup space" },
    { title: "Orphaned Package Removal", categoryId: "updates", categoryName: "Updates & Storage", categoryIcon: "󰚰", cardIndex: 3, desc: "Find and remove unused dependencies left over from uninstalled apps", keywords: "orphan packages unused packages dependencies cleanup uninstall remove" },

    // Notifications
    { title: "Do Not Disturb (DND)", categoryId: "notifications", categoryName: "Notifications", categoryIcon: "󰂚", cardIndex: 0, desc: "Mute notification popups and sounds during focus sessions", keywords: "do not disturb dnd mute notifications quiet mode silence alerts" },
    { title: "Notification Sounds & Chimes", categoryId: "notifications", categoryName: "Notifications", categoryIcon: "󰂚", cardIndex: 1, desc: "Toggle audio cues for desktop notification events", keywords: "notification sound chime alert sound sound effects audio popups" },
    { title: "Notification History & Logs", categoryId: "notifications", categoryName: "Notifications", categoryIcon: "󰂚", cardIndex: 2, desc: "View and clear recent desktop notifications", keywords: "notification history clear alerts notification center missed" },

    // Shortcuts & Keys
    { title: "Hyprland Keybindings List", categoryId: "shortcuts", categoryName: "Shortcuts & Keys", categoryIcon: "󰌌", cardIndex: 0, desc: "Browse system shortcuts (Super + Return, Super + Q, Super + E, etc.)", keywords: "shortcuts keybindings hotkeys super key keyboard shortcuts bindings" },
    { title: "Application Launcher Shortcut", categoryId: "shortcuts", categoryName: "Shortcuts & Keys", categoryIcon: "󰌌", cardIndex: 1, desc: "Super key or Super + Space shortcut for opening app menus", keywords: "app launcher rofi shortcut menu launch apps super space" },

    // AI & Agents
    { title: "Local AI Models & Ollama", categoryId: "agents", categoryName: "AI & Agents", categoryIcon: "󰚩", cardIndex: 0, desc: "Inspect available AI coding models, local LLMs, and agent status", keywords: "ai llm models ollama llama deepseek mistral artificial intelligence" },
    { title: "Agent Skills & Customizations", categoryId: "agents", categoryName: "AI & Agents", categoryIcon: "󰚩", cardIndex: 1, desc: "Antigravity coding assistant extensions, MCP tools, and skills", keywords: "agents antigravity coding assistant copilot tools skills extensions" },

    // Time & Language
    { title: "Clock Format (24-Hour vs 12-Hour)", categoryId: "region", categoryName: "Time & Language", categoryIcon: "󰅐", cardIndex: 0, desc: "Toggle between 24-hour military clock (14:30) and 12-hour AM/PM", keywords: "clock format 24-hour 12-hour am pm time format digital clock" },
    { title: "Clock Seconds Display", categoryId: "region", categoryName: "Time & Language", categoryIcon: "󰅐", cardIndex: 1, desc: "Show or hide real-time seconds (:ss) counter in status bar", keywords: "show seconds seconds counter clock seconds real-time clock" },
    { title: "Timezone & Network Time (NTP)", categoryId: "region", categoryName: "Time & Language", categoryIcon: "󰅐", cardIndex: 2, desc: "Configure system timezone, daylight saving time, and NTP sync", keywords: "timezone time zone timedatectl ntp sofia utc time sync clock time" },
    { title: "Weather Geolocation (Auto vs Custom)", categoryId: "region", categoryName: "Time & Language", categoryIcon: "󰅐", cardIndex: 3, desc: "Toggle IP-based auto detection or custom city weather reports", keywords: "weather location city ip geolocation temperature forecast climate" },
    { title: "Custom Weather City", categoryId: "region", categoryName: "Time & Language", categoryIcon: "󰅐", cardIndex: 4, desc: "Type custom city name for top bar weather report", keywords: "custom city set weather city weather location city name" },
    { title: "Switch Active Keyboard Layout", categoryId: "region", categoryName: "Time & Language", categoryIcon: "󰅐", cardIndex: 5, desc: "Cycle between active keyboard keymaps (English, Bulgarian, etc.)", keywords: "keyboard layout switch layout active keymap us bg de fr es" },
    { title: "Keyboard Layout Presets", categoryId: "region", categoryName: "Time & Language", categoryIcon: "󰅐", cardIndex: 6, desc: "One-click presets: US English, Bulgarian Phonetic, German, French, Spanish", keywords: "layout presets bulgarian german french spanish danish italian phonetic" },
    { title: "Layout Switching Shortcut", categoryId: "region", categoryName: "Time & Language", categoryIcon: "󰅐", cardIndex: 7, desc: "Select shortcut to switch keymaps: Alt+Shift, Super+Space, Caps Lock", keywords: "switch shortcut alt shift win space caps lock layout toggle shortcut" },
    { title: "Custom XKB Keyboard Layouts", categoryId: "region", categoryName: "Time & Language", categoryIcon: "󰅐", cardIndex: 8, desc: "Configure custom comma-separated XKB layouts and variants", keywords: "custom layout xkb layout variants phonetic comma separated" },
    { title: "System Locales & Fcitx5 IME", categoryId: "region", categoryName: "Time & Language", categoryIcon: "󰅐", cardIndex: 9, desc: "System LANG locale and multi-language input method framework (CJK)", keywords: "locales lang fcitx5 input methods ime cjk languages international" },

    // About System
    { title: "System Specifications & Hardware", categoryId: "about", categoryName: "About System", categoryIcon: "", cardIndex: 0, desc: "CPU model, total RAM, GPU drivers, and kernel version", keywords: "specs hardware cpu ram memory gpu processor specifications kernel arch" },
    { title: "Operating System & Hostname", categoryId: "about", categoryName: "About System", categoryIcon: "", cardIndex: 1, desc: "Omarchy desktop version, Arch Linux base, and system hostname", keywords: "os omarchy arch linux hostname pc name device system info uptime" }
  ]

  // Filtered results based on search query
  readonly property var searchResults: {
    var query = searchField ? searchField.text.trim().toLowerCase() : ""
    if (!query) return []

    var tokens = query.split(/\s+/).filter(function(t) { return t.length > 0 })
    if (tokens.length === 0) return []

    return settingsIndex.filter(function(item) {
      var haystack = (item.title + " " + item.categoryName + " " + item.desc + " " + item.keywords).toLowerCase()
      for (var i = 0; i < tokens.length; i++) {
        if (haystack.indexOf(tokens[i]) === -1) return false
      }
      return true
    })
  }

  onSearchResultsChanged: {
    if (selectedResultIndex >= searchResults.length) {
      selectedResultIndex = Math.max(0, searchResults.length - 1)
    }
  }

  function activateResult(index) {
    if (index >= 0 && index < searchResults.length) {
      var item = searchResults[index]
      if (panelRoot && typeof panelRoot.navigateToSetting === "function") {
        panelRoot.navigateToSetting(item.categoryId, item.cardIndex)
      } else if (panelRoot) {
        panelRoot.currentCategory = item.categoryId
        panelRoot.focusSection = "content"
      }
    }
  }

  function ensureVisible(index) {
    if (!resultsScroll || !resultsScroll.contentItem) return
    var itemY = index * 70
    var flick = resultsScroll.contentItem
    if (itemY < flick.contentY) {
      flick.contentY = Math.max(0, itemY)
    } else if (itemY + 70 > flick.contentY + resultsScroll.height) {
      flick.contentY = Math.max(0, itemY + 70 - resultsScroll.height)
    }
  }

  function handleMove(dx, dy) {
    if (dx < 0 && searchField.cursorPosition === 0) {
      if (panelRoot) panelRoot.focusSection = "sidebar"
      return true
    }
    if (dy !== 0) {
      if (searchResults.length > 0) {
        selectedResultIndex = Math.max(0, Math.min(searchResults.length - 1, selectedResultIndex + dy))
        ensureVisible(selectedResultIndex)
        return true
      }
    }
    return false
  }

  function handleActivate() {
    if (searchResults.length > 0) {
      activateResult(selectedResultIndex)
    }
  }

  function handleTextKey(key) {
    if (searchField) {
      searchField.forceActiveFocus()
      if (key.length === 1 && key >= " ") {
        searchField.text = searchField.text + key
        searchField.cursorPosition = searchField.text.length
        return true
      }
    }
    return false
  }

  Component.onCompleted: {
    Qt.callLater(function() {
      if (searchField) searchField.forceActiveFocus()
    })
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: 12

    // Search Input Bar (Direct Typing Enabled)
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 46
      color: Color.pickAlpha("surface.subtle", "#181b1d")
      radius: Style.cornerRadius || 8
      border.color: (searchField && searchField.activeFocus) ? Color.accent : Color.pickAlpha("surface.selected", "#2a3036")
      border.width: (searchField && searchField.activeFocus) ? 2 : 1

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.IBeamCursor
        onClicked: {
          if (searchField) searchField.forceActiveFocus()
        }
      }

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 12
        spacing: 10

        Text {
          text: ""
          font.family: Style.font.family
          font.pixelSize: 16
          color: (searchField && searchField.activeFocus) ? Color.accent : Color.muted
        }

        TextField {
          id: searchField
          Layout.fillWidth: true
          Layout.fillHeight: true
          placeholderText: "Type any setting to search directly (e.g. wifi, volume, bluetooth, touchpad, clock, theme)..."
          background: null
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.body || 14
          focus: true

          onAccepted: {
            if (root.searchResults.length > 0) {
              root.activateResult(root.selectedResultIndex)
            }
          }

          Keys.onDownPressed: function(event) {
            if (root.searchResults.length > 0) {
              root.selectedResultIndex = Math.min(root.searchResults.length - 1, root.selectedResultIndex + 1)
              root.ensureVisible(root.selectedResultIndex)
              event.accepted = true
            } else if (dashboardScroll && dashboardScroll.contentItem) {
              dashboardScroll.contentItem.contentY = Math.min(dashboardScroll.contentItem.contentHeight - dashboardScroll.height, dashboardScroll.contentItem.contentY + 60)
              event.accepted = true
            }
          }

          Keys.onUpPressed: function(event) {
            if (root.searchResults.length > 0) {
              root.selectedResultIndex = Math.max(0, root.selectedResultIndex - 1)
              root.ensureVisible(root.selectedResultIndex)
              event.accepted = true
            } else if (dashboardScroll && dashboardScroll.contentItem) {
              dashboardScroll.contentItem.contentY = Math.max(0, dashboardScroll.contentItem.contentY - 60)
              event.accepted = true
            }
          }

          Keys.onTabPressed: function(event) {
            searchField.focus = false
            if (root.panelRoot) {
              root.panelRoot.focusSection = "sidebar"
              if (typeof root.panelRoot.returnFocusToKeyCatcher === "function") {
                root.panelRoot.returnFocusToKeyCatcher()
              }
            }
            event.accepted = true
          }

          Keys.onEscapePressed: function(event) {
            if (text.length > 0) {
              text = ""
              event.accepted = true
            } else {
              searchField.focus = false
              if (root.panelRoot) root.panelRoot.focusSection = "sidebar"
              if (root.panelRoot && typeof root.panelRoot.returnFocusToKeyCatcher === "function") {
                root.panelRoot.returnFocusToKeyCatcher()
              }
              event.accepted = true
            }
          }

          Keys.onLeftPressed: function(event) {
            if (cursorPosition === 0 && selectionStart === selectionEnd) {
              searchField.focus = false
              if (root.panelRoot) root.panelRoot.focusSection = "sidebar"
              if (root.panelRoot && typeof root.panelRoot.returnFocusToKeyCatcher === "function") {
                root.panelRoot.returnFocusToKeyCatcher()
              }
              event.accepted = true
            } else {
              event.accepted = false
            }
          }
        }

        // Clear Search Button
        Rectangle {
          Layout.preferredHeight: 24
          Layout.preferredWidth: 24
          radius: 12
          visible: searchField.text.length > 0
          color: Color.pickAlpha("surface.selected", "#2a3036")

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              searchField.text = ""
              searchField.forceActiveFocus()
            }
          }

          Text {
            anchors.centerIn: parent
            text: "✕"
            font.family: Style.font.family
            font.pixelSize: 10
            color: Color.muted
          }
        }
      }
    }

    // Quick Search Suggestion Chips (When search is empty)
    RowLayout {
      Layout.fillWidth: true
      visible: searchField.text.trim().length === 0
      spacing: 6

      Text {
        text: "Quick Suggestions:"
        font.family: Style.font.family
        font.pixelSize: 10
        font.bold: true
        color: Color.muted
      }

      Flow {
        Layout.fillWidth: true
        spacing: 6

        Repeater {
          model: [
            { icon: "󰤨", label: "Wi-Fi", query: "wifi" },
            { icon: "󰂯", label: "Bluetooth", query: "bluetooth" },
            { icon: "󰕾", label: "Volume", query: "volume" },
            { icon: "󰍹", label: "Brightness", query: "brightness" },
            { icon: "󰆽", label: "Touchpad", query: "touchpad" },
            { icon: "󰅐", label: "Clock", query: "clock" },
            { icon: "", label: "Theme", query: "theme" },
            { icon: "󰚰", label: "Updates", query: "updates" }
          ]

          delegate: Rectangle {
            height: 24
            width: chipContent.implicitWidth + 14
            radius: 4
            color: Color.pickAlpha("surface.subtle", "#181b1d")
            border.color: chipMouse.containsMouse ? Color.accent : Color.pickAlpha("surface.selected", "#2a3036")
            border.width: 1

            MouseArea {
              id: chipMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                searchField.text = modelData.query
                searchField.cursorPosition = searchField.text.length
                searchField.forceActiveFocus()
              }
            }

            RowLayout {
              id: chipContent
              anchors.centerIn: parent
              spacing: 4

              Text {
                text: modelData.icon
                font.family: Style.font.family
                font.pixelSize: 11
                color: Color.accent
              }

              Text {
                text: modelData.label
                font.family: Style.font.family
                font.pixelSize: 10
                color: Color.foreground
              }
            }
          }
        }
      }
    }

    // Results Header Badge (When searching)
    RowLayout {
      Layout.fillWidth: true
      visible: searchField.text.trim().length > 0
      spacing: 8

      Text {
        text: "SEARCH RESULTS"
        font.family: Style.font.family
        font.pixelSize: 11
        font.bold: true
        color: Color.accent
      }

      Rectangle {
        Layout.preferredHeight: 18
        Layout.preferredWidth: countText.implicitWidth + 12
        radius: 4
        color: Color.pickAlpha("accent.subtle", "#1f3b30")

        Text {
          id: countText
          anchors.centerIn: parent
          text: root.searchResults.length + " matching " + (root.searchResults.length === 1 ? "setting" : "settings")
          font.family: Style.font.family
          font.pixelSize: 10
          font.bold: true
          color: Color.accent
        }
      }

      Item { Layout.fillWidth: true }

      Text {
        text: "Press [Enter] to open setting  •  [↑/↓] Browse"
        font.family: Style.font.family
        font.pixelSize: 11
        color: Color.muted
      }
    }

    // VIEW A: Live Search Results List (Visible when query is not empty)
    ScrollView {
      id: resultsScroll
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true
      visible: searchField.text.trim().length > 0
      ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
      ScrollBar.vertical.policy: ScrollBar.AsNeeded

      ColumnLayout {
        width: Math.max(200, resultsScroll.availableWidth - 12)
        spacing: 8

        // No Results State
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 120
          visible: root.searchResults.length === 0
          color: Color.pickAlpha("surface.subtle", "#181b1d")
          radius: Style.cornerRadius || 8

          ColumnLayout {
            anchors.centerIn: parent
            spacing: 6

            Text {
              Layout.alignment: Qt.AlignHCenter
              text: "󰍉"
              font.family: Style.font.family
              font.pixelSize: 28
              color: Color.muted
            }

            Text {
              Layout.alignment: Qt.AlignHCenter
              text: "No settings found for \"" + searchField.text.trim() + "\""
              font.family: Style.font.family
              font.pixelSize: Style.font.body || 13
              font.bold: true
              color: Color.foreground
            }

            Text {
              Layout.alignment: Qt.AlignHCenter
              text: "Try searching for keywords like wifi, sound, brightness, touchpad, or theme"
              font.family: Style.font.family
              font.pixelSize: Style.font.subtext || 11
              color: Color.muted
            }
          }
        }

        // Search Result Items
        Repeater {
          model: root.searchResults
          delegate: Rectangle {
            id: resultCard
            Layout.fillWidth: true
            Layout.preferredHeight: 64
            radius: Style.cornerRadius || 8
            color: (index === root.selectedResultIndex) ? Color.pickAlpha("surface.selected", "#222a30") : Color.pickAlpha("surface.subtle", "#181b1d")
            border.color: (index === root.selectedResultIndex) ? Color.accent : "transparent"
            border.width: (index === root.selectedResultIndex) ? 2 : 0

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              hoverEnabled: true
              onEntered: root.selectedResultIndex = index
              onClicked: root.activateResult(index)
            }

            RowLayout {
              anchors.fill: parent
              anchors.margins: 12
              spacing: 12

              // Category Icon Badge
              Rectangle {
                width: 38
                height: 38
                radius: 8
                color: Color.pickAlpha("accent.subtle", "#1f3b30")

                Text {
                  anchors.centerIn: parent
                  text: modelData.categoryIcon
                  font.family: Style.font.family
                  font.pixelSize: 18
                  color: Color.accent
                }
              }

              // Title and Description
              ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                spacing: 2

                RowLayout {
                  Layout.fillWidth: true
                  spacing: 8

                  Text {
                    text: modelData.title
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body || 13
                    font.bold: true
                    color: (index === root.selectedResultIndex) ? Color.accent : Color.foreground
                  }

                  Rectangle {
                    Layout.preferredHeight: 18
                    Layout.preferredWidth: catBadgeText.implicitWidth + 10
                    radius: 4
                    color: Color.pickAlpha("surface.selected", "#2a3036")

                    Text {
                      id: catBadgeText
                      anchors.centerIn: parent
                      text: modelData.categoryName
                      font.family: Style.font.family
                      font.pixelSize: 9
                      font.bold: true
                      color: Color.muted
                    }
                  }
                }

                Text {
                  Layout.fillWidth: true
                  elide: Text.ElideRight
                  text: modelData.desc
                  font.family: Style.font.family
                  font.pixelSize: Style.font.subtext || 11
                  color: Color.muted
                }
              }

              // Open Pill Button
              Rectangle {
                Layout.preferredHeight: 28
                Layout.preferredWidth: 84
                Layout.minimumWidth: 84
                radius: 5
                color: (index === root.selectedResultIndex) ? Color.accent : Color.pickAlpha("surface.selected", "#2a3036")

                RowLayout {
                  anchors.centerIn: parent
                  spacing: 4

                  Text {
                    text: "Open 󰅂"
                    font.family: Style.font.family
                    font.pixelSize: 11
                    font.bold: true
                    color: (index === root.selectedResultIndex) ? Color.background : Color.foreground
                  }
                }
              }
            }
          }
        }
      }
    }

    // VIEW B: Quick Overview Dashboard (Visible when query is empty)
    ScrollView {
      id: dashboardScroll
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true
      visible: searchField.text.trim().length === 0
      ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
      ScrollBar.vertical.policy: ScrollBar.AsNeeded

      ColumnLayout {
        width: Math.max(200, dashboardScroll.availableWidth - 12)
        spacing: 14

        // Section Title: Quick Access
        Text {
          text: "QUICK ACCESS & POPULAR SETTINGS"
          font.family: Style.font.family
          font.pixelSize: 11
          font.bold: true
          color: Color.accent
        }

        // Quick Grid of Essential Settings
        Flow {
          Layout.fillWidth: true
          spacing: 10

          // Tile 1: Displays & Brightness
          Rectangle {
            width: Math.max(160, (parent.width - 20) / 3)
            height: 84
            radius: 8
            color: Color.pickAlpha("surface.subtle", "#181b1d")

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (root.panelRoot && typeof root.panelRoot.navigateToSetting === "function") {
                  root.panelRoot.navigateToSetting("displays", 0)
                }
              }
            }

            RowLayout {
              anchors.fill: parent
              anchors.margins: 12
              spacing: 12

              Rectangle {
                width: 36
                height: 36
                radius: 8
                color: Color.pickAlpha("accent.subtle", "#1f3b30")
                Text {
                  anchors.centerIn: parent
                  text: "󰍹"
                  font.family: Style.font.family
                  font.pixelSize: 18
                  color: Color.accent
                }
              }

              ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                spacing: 2
                Text {
                  text: "Brightness [1]"
                  font.family: Style.font.family
                  font.pixelSize: 12
                  font.bold: true
                  color: Color.foreground
                }
                Text {
                  text: "Displays & Scaling"
                  font.family: Style.font.family
                  font.pixelSize: 10
                  color: Color.muted
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }
              }
            }
          }

          // Tile 2: Volume & Sound
          Rectangle {
            width: Math.max(160, (parent.width - 20) / 3)
            height: 84
            radius: 8
            color: Color.pickAlpha("surface.subtle", "#181b1d")

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (root.panelRoot && typeof root.panelRoot.navigateToSetting === "function") {
                  root.panelRoot.navigateToSetting("sound", 0)
                }
              }
            }

            RowLayout {
              anchors.fill: parent
              anchors.margins: 12
              spacing: 12

              Rectangle {
                width: 36
                height: 36
                radius: 8
                color: Color.pickAlpha("accent.subtle", "#1f3b30")
                Text {
                  anchors.centerIn: parent
                  text: "󰕾"
                  font.family: Style.font.family
                  font.pixelSize: 18
                  color: Color.accent
                }
              }

              ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                spacing: 2
                Text {
                  text: "Audio & Volume [4]"
                  font.family: Style.font.family
                  font.pixelSize: 12
                  font.bold: true
                  color: Color.foreground
                }
                Text {
                  text: "Speakers & Mic"
                  font.family: Style.font.family
                  font.pixelSize: 10
                  color: Color.muted
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }
              }
            }
          }

          // Tile 3: Wi-Fi Networks
          Rectangle {
            width: Math.max(160, (parent.width - 20) / 3)
            height: 84
            radius: 8
            color: Color.pickAlpha("surface.subtle", "#181b1d")

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (root.panelRoot && typeof root.panelRoot.navigateToSetting === "function") {
                  root.panelRoot.navigateToSetting("network", 0)
                }
              }
            }

            RowLayout {
              anchors.fill: parent
              anchors.margins: 12
              spacing: 12

              Rectangle {
                width: 36
                height: 36
                radius: 8
                color: Color.pickAlpha("accent.subtle", "#1f3b30")
                Text {
                  anchors.centerIn: parent
                  text: "󰤨"
                  font.family: Style.font.family
                  font.pixelSize: 18
                  color: Color.accent
                }
              }

              ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                spacing: 2
                Text {
                  text: "Wi-Fi & Network [5]"
                  font.family: Style.font.family
                  font.pixelSize: 12
                  font.bold: true
                  color: Color.foreground
                }
                Text {
                  text: "Wireless Connections"
                  font.family: Style.font.family
                  font.pixelSize: 10
                  color: Color.muted
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }
              }
            }
          }

          // Tile 4: Bluetooth Devices
          Rectangle {
            width: Math.max(160, (parent.width - 20) / 3)
            height: 84
            radius: 8
            color: Color.pickAlpha("surface.subtle", "#181b1d")

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (root.panelRoot && typeof root.panelRoot.navigateToSetting === "function") {
                  root.panelRoot.navigateToSetting("bluetooth", 0)
                }
              }
            }

            RowLayout {
              anchors.fill: parent
              anchors.margins: 12
              spacing: 12

              Rectangle {
                width: 36
                height: 36
                radius: 8
                color: Color.pickAlpha("accent.subtle", "#1f3b30")
                Text {
                  anchors.centerIn: parent
                  text: "󰂯"
                  font.family: Style.font.family
                  font.pixelSize: 18
                  color: Color.accent
                }
              }

              ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                spacing: 2
                Text {
                  text: "Bluetooth [6]"
                  font.family: Style.font.family
                  font.pixelSize: 12
                  font.bold: true
                  color: Color.foreground
                }
                Text {
                  text: "Paired Accessories"
                  font.family: Style.font.family
                  font.pixelSize: 10
                  color: Color.muted
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }
              }
            }
          }

          // Tile 5: Touchpad & Input
          Rectangle {
            width: Math.max(160, (parent.width - 20) / 3)
            height: 84
            radius: 8
            color: Color.pickAlpha("surface.subtle", "#181b1d")

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (root.panelRoot && typeof root.panelRoot.navigateToSetting === "function") {
                  root.panelRoot.navigateToSetting("input", 3)
                }
              }
            }

            RowLayout {
              anchors.fill: parent
              anchors.margins: 12
              spacing: 12

              Rectangle {
                width: 36
                height: 36
                radius: 8
                color: Color.pickAlpha("accent.subtle", "#1f3b30")
                Text {
                  anchors.centerIn: parent
                  text: "󰆽"
                  font.family: Style.font.family
                  font.pixelSize: 18
                  color: Color.accent
                }
              }

              ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                spacing: 2
                Text {
                  text: "Touchpad & Gestures [7]"
                  font.family: Style.font.family
                  font.pixelSize: 12
                  font.bold: true
                  color: Color.foreground
                }
                Text {
                  text: "Tap to Click & Scroll"
                  font.family: Style.font.family
                  font.pixelSize: 10
                  color: Color.muted
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }
              }
            }
          }

          // Tile 6: Keyboard Layouts & Time
          Rectangle {
            width: Math.max(160, (parent.width - 20) / 3)
            height: 84
            radius: 8
            color: Color.pickAlpha("surface.subtle", "#181b1d")

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (root.panelRoot && typeof root.panelRoot.navigateToSetting === "function") {
                  root.panelRoot.navigateToSetting("region", 5)
                }
              }
            }

            RowLayout {
              anchors.fill: parent
              anchors.margins: 12
              spacing: 12

              Rectangle {
                width: 36
                height: 36
                radius: 8
                color: Color.pickAlpha("accent.subtle", "#1f3b30")
                Text {
                  anchors.centerIn: parent
                  text: "󰅐"
                  font.family: Style.font.family
                  font.pixelSize: 18
                  color: Color.accent
                }
              }

              ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                spacing: 2
                Text {
                  text: "Time & Language [L]"
                  font.family: Style.font.family
                  font.pixelSize: 12
                  font.bold: true
                  color: Color.foreground
                }
                Text {
                  text: "Clock, Timezone & Layouts"
                  font.family: Style.font.family
                  font.pixelSize: 10
                  color: Color.muted
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }
              }
            }
          }

          // Tile 7: Desktop Themes
          Rectangle {
            width: Math.max(160, (parent.width - 20) / 3)
            height: 84
            radius: 8
            color: Color.pickAlpha("surface.subtle", "#181b1d")

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (root.panelRoot && typeof root.panelRoot.navigateToSetting === "function") {
                  root.panelRoot.navigateToSetting("appearance", 0)
                }
              }
            }

            RowLayout {
              anchors.fill: parent
              anchors.margins: 12
              spacing: 12

              Rectangle {
                width: 36
                height: 36
                radius: 8
                color: Color.pickAlpha("accent.subtle", "#1f3b30")
                Text {
                  anchors.centerIn: parent
                  text: ""
                  font.family: Style.font.family
                  font.pixelSize: 18
                  color: Color.accent
                }
              }

              ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                spacing: 2
                Text {
                  text: "Themes & Styling [3]"
                  font.family: Style.font.family
                  font.pixelSize: 12
                  font.bold: true
                  color: Color.foreground
                }
                Text {
                  text: "Tokyo Night, Gruvbox"
                  font.family: Style.font.family
                  font.pixelSize: 10
                  color: Color.muted
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }
              }
            }
          }

          // Tile 8: System Updates
          Rectangle {
            width: Math.max(160, (parent.width - 20) / 3)
            height: 84
            radius: 8
            color: Color.pickAlpha("surface.subtle", "#181b1d")

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (root.panelRoot && typeof root.panelRoot.navigateToSetting === "function") {
                  root.panelRoot.navigateToSetting("updates", 0)
                }
              }
            }

            RowLayout {
              anchors.fill: parent
              anchors.margins: 12
              spacing: 12

              Rectangle {
                width: 36
                height: 36
                radius: 8
                color: Color.pickAlpha("accent.subtle", "#1f3b30")
                Text {
                  anchors.centerIn: parent
                  text: "󰚰"
                  font.family: Style.font.family
                  font.pixelSize: 18
                  color: Color.accent
                }
              }

              ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                spacing: 2
                Text {
                  text: "System Updates [U]"
                  font.family: Style.font.family
                  font.pixelSize: 12
                  font.bold: true
                  color: Color.foreground
                }
                Text {
                  text: "Packages & Storage"
                  font.family: Style.font.family
                  font.pixelSize: 10
                  color: Color.muted
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }
              }
            }
          }

          // Tile 9: Window Manager
          Rectangle {
            width: Math.max(160, (parent.width - 20) / 3)
            height: 84
            radius: 8
            color: Color.pickAlpha("surface.subtle", "#181b1d")

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (root.panelRoot && typeof root.panelRoot.navigateToSetting === "function") {
                  root.panelRoot.navigateToSetting("windows", 0)
                }
              }
            }

            RowLayout {
              anchors.fill: parent
              anchors.margins: 12
              spacing: 12

              Rectangle {
                width: 36
                height: 36
                radius: 8
                color: Color.pickAlpha("accent.subtle", "#1f3b30")
                Text {
                  anchors.centerIn: parent
                  text: ""
                  font.family: Style.font.family
                  font.pixelSize: 18
                  color: Color.accent
                }
              }

              ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                spacing: 2
                Text {
                  text: "Window Manager [8]"
                  font.family: Style.font.family
                  font.pixelSize: 12
                  font.bold: true
                  color: Color.foreground
                }
                Text {
                  text: "Gaps, Borders & Bar"
                  font.family: Style.font.family
                  font.pixelSize: 10
                  color: Color.muted
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }
              }
            }
          }
        }

        // Section Title: Search Tips
        Text {
          text: "SEARCH HINTS"
          font.family: Style.font.family
          font.pixelSize: 11
          font.bold: true
          color: Color.accent
          Layout.topMargin: 6
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 74
          radius: 8
          color: Color.pickAlpha("surface.subtle", "#181b1d")

          RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            Text {
              text: "󰌌"
              font.family: Style.font.family
              font.pixelSize: 22
              color: Color.accent
            }

            ColumnLayout {
              Layout.fillWidth: true
              Layout.preferredWidth: 0
              spacing: 3

              Text {
                text: "Start typing directly anywhere in this panel to filter settings instantly."
                font.family: Style.font.family
                font.pixelSize: Style.font.body || 12
                font.bold: true
                color: Color.foreground
              }

              Text {
                text: "Use [↑/↓] to browse results, [Enter] to open that setting, or click any card."
                font.family: Style.font.family
                font.pixelSize: Style.font.subtext || 11
                color: Color.muted
                elide: Text.ElideRight
                Layout.fillWidth: true
              }
            }
          }
        }

        Item {
          Layout.preferredHeight: 12
        }
      }
    }
  }
}
