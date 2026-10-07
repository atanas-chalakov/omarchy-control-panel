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
  property var panelRoot: null
  property bool activeFocusSection: false
  readonly property bool isContentFocused: panelRoot ? panelRoot.focusSection === "content" : activeFocusSection
  property string focusZone: "input" // "input", "chips", "tiles", "results"
  property int selectedChipIndex: 0
  property int selectedTileIndex: 0
  property int selectedResultIndex: 0

  readonly property bool hasActiveInput: (focusZone === "input" && searchField && searchField.activeFocus)

  onActiveFocusSectionChanged: {
    if (activeFocusSection) {
      focusToInput()
    } else {
      if (searchField) searchField.focus = false
    }
  }

  readonly property var quickChips: [
    { icon: "󰤨", label: "Wi-Fi", query: "wifi" },
    { icon: "󰂯", label: "Bluetooth", query: "bluetooth" },
    { icon: "󰕾", label: "Volume", query: "volume" },
    { icon: "󰍹", label: "Brightness", query: "brightness" },
    { icon: "󰆽", label: "Touchpad", query: "touchpad" },
    { icon: "󰅐", label: "Clock", query: "clock" },
    { icon: "", label: "Theme", query: "theme" },
    { icon: "󰚰", label: "Updates", query: "updates" }
  ]

  readonly property var quickTiles: [
    { title: "Brightness [1]", subtitle: "Displays & Scaling", icon: "󰍹", categoryId: "displays", cardIndex: 0 },
    { title: "Audio & Volume [4]", subtitle: "Speakers & Mic", icon: "󰕾", categoryId: "sound", cardIndex: 0 },
    { title: "Wi-Fi & Network [5]", subtitle: "Wireless Connections", icon: "󰤨", categoryId: "network", cardIndex: 0 },
    { title: "Bluetooth [6]", subtitle: "Paired Accessories", icon: "󰂯", categoryId: "bluetooth", cardIndex: 0 },
    { title: "Touchpad & Gestures [7]", subtitle: "Tap to Click & Scroll", icon: "󰆽", categoryId: "input", cardIndex: 3 },
    { title: "Time & Language [L]", subtitle: "Clock, Timezone & Layouts", icon: "󰅐", categoryId: "region", cardIndex: 5 },
    { title: "Themes & Styling [3]", subtitle: "Tokyo Night, Gruvbox", icon: "", categoryId: "appearance", cardIndex: 0 },
    { title: "System Updates [U]", subtitle: "Packages & Storage", icon: "󰚰", categoryId: "updates", cardIndex: 0 },
    { title: "Window Manager [8]", subtitle: "Gaps, Borders & Bar", icon: "", categoryId: "windows", cardIndex: 0 }
  ]

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
    { title: "Screen Timeout & Sleep", categoryId: "power", categoryName: "Power & Battery", categoryIcon: "󰂄", cardIndex: 3, desc: "Set idle timeout before display turns off or system suspends", keywords: "sleep screen timeout idle turn off screen display timeout suspend" },
    { title: "Stay Awake / Caffeine Mode", categoryId: "power", categoryName: "Power & Battery", categoryIcon: "󰂄", cardIndex: 1, desc: "Temporarily prevent screen sleep and system idling", keywords: "stay awake caffeine keep awake prevent sleep lock prevention" },
    { title: "Gaming & Performance Mode", categoryId: "power", categoryName: "Power & Battery", categoryIcon: "󰂄", cardIndex: 2, desc: "Max performance governor, disables compositor animations/blur, enables DND", keywords: "gaming game mode performance max fps governor latency speed dnd" },

    // Appearance
    { title: "Desktop Theme & Wallpaper", categoryId: "appearance", categoryName: "Appearance", categoryIcon: "", cardIndex: 0, desc: "Apply system-wide color scheme (Tokyo Night, Catppuccin, Gruvbox, etc.)", keywords: "theme appearance dark mode light mode tokyo night catppuccin gruvbox colors wallpaper style" },
    { title: "Theme Color Palette & Swatches", categoryId: "appearance", categoryName: "Appearance", categoryIcon: "", cardIndex: 0, desc: "Inspect active theme hex tokens (Accent, Foreground, Background, Muted) and copy values", keywords: "palette color hex swatches accent rgb colors tokens tokyo night gruvbox" },
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
    { title: "Operating System & Hostname", categoryId: "about", categoryName: "About System", categoryIcon: "", cardIndex: 1, desc: "Omarchy desktop version, Arch Linux base, and system hostname", keywords: "os omarchy arch linux hostname pc name device system info uptime" },
    { title: "Configuration Backup & Restore", categoryId: "about", categoryName: "About System", categoryIcon: "󰁯", cardIndex: 3, desc: "Snapshot, restore, and manage full Omarchy desktop configuration backups", keywords: "backup restore snapshot export config hyprland save archive rollback" },
    { title: "Cloud Sync & GitHub Gist Backups", categoryId: "about", categoryName: "About System", categoryIcon: "󰇮", cardIndex: 3, desc: "Export, import, and sync configuration archives via private GitHub Gists", keywords: "cloud sync gist github backup import export remote archive gist" }
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

  function focusToInput() {
    focusZone = "input"
    if (searchField) {
      searchField.forceActiveFocus()
      searchField.cursorPosition = searchField.text.length
    }
  }

  function blurInput() {
    if (searchField) {
      searchField.focus = false
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

  function activateChip(index) {
    if (index >= 0 && index < quickChips.length) {
      var chip = quickChips[index]
      if (searchField) {
        searchField.text = chip.query
        searchField.cursorPosition = searchField.text.length
      }
      focusZone = "results"
      selectedResultIndex = 0
      if (searchField) searchField.focus = false
      if (panelRoot && typeof panelRoot.returnFocusToKeyCatcher === "function") {
        panelRoot.returnFocusToKeyCatcher()
      }
    }
  }

  function activateTile(index) {
    if (index >= 0 && index < quickTiles.length) {
      var tile = quickTiles[index]
      if (panelRoot && typeof panelRoot.navigateToSetting === "function") {
        panelRoot.navigateToSetting(tile.categoryId, tile.cardIndex)
      } else if (panelRoot) {
        panelRoot.currentCategory = tile.categoryId
        panelRoot.focusSection = "content"
      }
    }
  }

  function ensureResultVisible(index) {
    if (!resultsScroll || !resultsScroll.contentItem) return
    var itemY = index * 72
    var flick = resultsScroll.contentItem
    if (itemY < flick.contentY) {
      flick.contentY = Math.max(0, itemY - 10)
    } else if (itemY + 64 > flick.contentY + resultsScroll.height - 10) {
      flick.contentY = Math.max(0, itemY + 64 - resultsScroll.height + 10)
    }
  }

  function ensureTileVisible(index) {
    if (!dashboardScroll || !dashboardScroll.contentItem) return
    var row = Math.floor(index / 3)
    var itemY = 30 + row * 94
    var flick = dashboardScroll.contentItem
    if (itemY < flick.contentY) {
      flick.contentY = Math.max(0, itemY - 10)
    } else if (itemY + 84 > flick.contentY + dashboardScroll.height - 10) {
      flick.contentY = Math.max(0, itemY + 84 - dashboardScroll.height + 10)
    }
  }

  function handleMove(dx, dy) {
    if (searchResults.length > 0 || (searchField && searchField.text.trim().length > 0)) {
      if (dy > 0) {
        selectedResultIndex = Math.min(searchResults.length - 1, selectedResultIndex + 1)
        ensureResultVisible(selectedResultIndex)
        return true
      } else if (dy < 0) {
        if (selectedResultIndex > 0) {
          selectedResultIndex--
          ensureResultVisible(selectedResultIndex)
          return true
        } else {
          focusToInput()
          return true
        }
      } else if (dx < 0) {
        if (panelRoot) panelRoot.focusSection = "sidebar"
        return true
      }
      return false
    }

    if (focusZone === "chips") {
      if (dx > 0) {
        if (selectedChipIndex < quickChips.length - 1) {
          selectedChipIndex++
          return true
        }
      } else if (dx < 0) {
        if (selectedChipIndex > 0) {
          selectedChipIndex--
          return true
        } else {
          if (panelRoot) panelRoot.focusSection = "sidebar"
          return true
        }
      } else if (dy > 0) {
        focusZone = "tiles"
        selectedTileIndex = Math.min(2, Math.floor(selectedChipIndex / 3))
        ensureTileVisible(selectedTileIndex)
        return true
      } else if (dy < 0) {
        focusToInput()
        return true
      }
    } else if (focusZone === "tiles") {
      if (dy > 0) {
        if (selectedTileIndex + 3 < quickTiles.length) {
          selectedTileIndex += 3
          ensureTileVisible(selectedTileIndex)
          return true
        }
      } else if (dy < 0) {
        if (selectedTileIndex >= 3) {
          selectedTileIndex -= 3
          ensureTileVisible(selectedTileIndex)
          return true
        } else {
          focusZone = "chips"
          selectedChipIndex = Math.min(quickChips.length - 1, selectedTileIndex * 3)
          return true
        }
      } else if (dx > 0) {
        if (selectedTileIndex % 3 < 2 && selectedTileIndex + 1 < quickTiles.length) {
          selectedTileIndex++
          ensureTileVisible(selectedTileIndex)
          return true
        }
      } else if (dx < 0) {
        if (selectedTileIndex % 3 > 0) {
          selectedTileIndex--
          ensureTileVisible(selectedTileIndex)
          return true
        } else {
          if (panelRoot) panelRoot.focusSection = "sidebar"
          return true
        }
      }
    }

    return false
  }

  function handleActivate() {
    if (searchResults.length > 0 || (searchField && searchField.text.trim().length > 0)) {
      activateResult(selectedResultIndex)
    } else if (focusZone === "chips") {
      activateChip(selectedChipIndex)
    } else if (focusZone === "tiles") {
      activateTile(selectedTileIndex)
    }
  }


  function handleTextKey(key) {
    if (focusZone === "input") return false

    var k = key.toLowerCase()
    if (k === "/" || k === "s") {
      focusToInput()
      return true
    }

    if (key.length === 1 && key >= " ") {
      focusToInput()
      if (searchField) {
        searchField.text = searchField.text + key
        searchField.cursorPosition = searchField.text.length
      }
      return true
    }
    return false
  }

  Component.onCompleted: {
    Qt.callLater(function() {
      if (typeof root !== "undefined" && root && typeof root.focusToInput === "function") {
        root.focusToInput()
      }
    })
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: 12

    // Search Input Bar (Direct Typing Enabled)
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 46
      color: (searchField && searchField.activeFocus)
        ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
        : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.03)
      radius: Style.cornerRadius || 8
      border.color: (searchField && searchField.activeFocus) ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
      border.width: (searchField && searchField.activeFocus) ? 2 : 1

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.IBeamCursor
        onClicked: root.focusToInput()
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
          color: (root.focusZone === "input" && searchField && searchField.activeFocus) ? Color.accent : Color.muted
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

          onTextChanged: {
            if (root.focusZone !== "input" && root.focusZone !== "results") {
              if (text.trim().length > 0) root.focusZone = "results"
            }
          }

          onAccepted: {
            if (root.searchResults.length > 0) {
              root.activateResult(root.selectedResultIndex)
            } else {
              root.focusZone = "tiles"
              root.selectedTileIndex = 0
              root.ensureTileVisible(0)
              Qt.callLater(function() {
                searchField.focus = false
                if (root.panelRoot && typeof root.panelRoot.returnFocusToKeyCatcher === "function") {
                  root.panelRoot.returnFocusToKeyCatcher()
                }
              })
            }
          }

          Keys.onDownPressed: function(event) {
            event.accepted = true
            if (root.searchResults.length > 0) {
              root.focusZone = "results"
              root.selectedResultIndex = 0
              root.ensureResultVisible(0)
            } else {
              root.focusZone = "tiles"
              root.selectedTileIndex = 0
              root.ensureTileVisible(0)
            }
            Qt.callLater(function() {
              searchField.focus = false
              if (root.panelRoot && typeof root.panelRoot.returnFocusToKeyCatcher === "function") {
                root.panelRoot.returnFocusToKeyCatcher()
              }
            })
          }

          Keys.onTabPressed: function(event) {
            event.accepted = true
            searchField.focus = false
            if (root.panelRoot && typeof root.panelRoot.toggleFocusSection === "function") {
              root.panelRoot.toggleFocusSection()
            } else if (root.panelRoot) {
              root.panelRoot.focusSection = "sidebar"
              if (typeof root.panelRoot.returnFocusToKeyCatcher === "function") {
                root.panelRoot.returnFocusToKeyCatcher()
              }
            }
          }

          Keys.onBacktabPressed: function(event) {
            event.accepted = true
            searchField.focus = false
            if (root.panelRoot && typeof root.panelRoot.toggleFocusSection === "function") {
              root.panelRoot.toggleFocusSection()
            } else if (root.panelRoot) {
              root.panelRoot.focusSection = "sidebar"
              if (typeof root.panelRoot.returnFocusToKeyCatcher === "function") {
                root.panelRoot.returnFocusToKeyCatcher()
              }
            }
          }

          Keys.onEscapePressed: function(event) {
            if (text.length > 0) {
              text = ""
              root.focusZone = "input"
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

        // Hint Badge: Jump to search or jump below
        Rectangle {
          visible: root.focusZone !== "input"
          Layout.preferredHeight: 22
          Layout.preferredWidth: searchHintBadgeText.implicitWidth + 12
          radius: 4
          color: searchHintBadgeMouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06)
          border.color: searchHintBadgeMouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.30) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12)
          border.width: 1

          MouseArea {
            id: searchHintBadgeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.focusToInput()
          }

          Text {
            id: searchHintBadgeText
            anchors.centerIn: parent
            text: "Press [ / ] to search"
            font.family: Style.font.family
            font.pixelSize: 10
            font.bold: true
            color: searchHintBadgeMouse.containsMouse ? Color.foreground : Color.muted
          }
        }

        Rectangle {
          visible: (root.focusZone === "input" && searchField && searchField.activeFocus && searchField.text.length === 0)
          Layout.preferredHeight: 22
          Layout.preferredWidth: inputHintBadgeText.implicitWidth + 12
          radius: 4
          color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06)
          border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12)
          border.width: 1

          Text {
            id: inputHintBadgeText
            anchors.centerIn: parent
            text: "Press [ ↓ ] for items below"
            font.family: Style.font.family
            font.pixelSize: 10
            color: Color.muted
          }
        }

        // Clear Search Button
        Rectangle {
          Layout.preferredHeight: 24
          Layout.preferredWidth: 24
          radius: 12
          visible: searchField.text.length > 0
          color: clearSearchMouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06)

          MouseArea {
            id: clearSearchMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              searchField.text = ""
              root.focusToInput()
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

    // Quick Search Suggestion Chips (When search is empty - Responsive Flow)
    Flow {
      Layout.fillWidth: true
      width: parent.width
      visible: searchField.text.trim().length === 0
      spacing: 6

      Text {
        text: (root.focusZone === "chips") ? "Quick Suggestions [←/→/Enter]:" : "Quick Suggestions:"
        font.family: Style.font.family
        font.pixelSize: 10
        font.bold: true
        color: (root.focusZone === "chips") ? Color.accent : Color.muted
        topPadding: 6
      }

      Repeater {
        model: root.quickChips

        delegate: Rectangle {
          id: chipCard
          height: 26
          width: chipContent.implicitWidth + 16
          radius: 5
          readonly property bool isChipFocused: (root.focusZone === "chips" && index === root.selectedChipIndex)
          readonly property bool isChipHovered: chipMouse.containsMouse

          color: isChipFocused
            ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, isChipHovered ? 0.28 : 0.20)
            : (isChipHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04))
          border.color: isChipFocused
            ? Color.accent
            : (isChipHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12))
          border.width: isChipFocused ? 2 : 1

          MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (root.panelRoot) root.panelRoot.focusSection = "content"
              root.selectedChipIndex = index
              root.activateChip(index)
            }
          }

          RowLayout {
            id: chipContent
            anchors.centerIn: parent
            spacing: 5

            Rectangle {
              visible: chipCard.isChipFocused
              width: 5
              height: 5
              radius: 2.5
              color: Color.accent
            }

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
              font.bold: chipCard.isChipFocused
              color: chipCard.isChipFocused ? Color.accent : (chipCard.isChipHovered ? Color.foreground : Color.muted)
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
        Layout.preferredWidth: countText.implicitWidth + 14
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
            text: root.searchResults.length + " matching " + (root.searchResults.length === 1 ? "setting" : "settings")
            font.family: Style.font.family
            font.pixelSize: 10
            font.bold: true
            color: Color.accent
          }
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
          color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02)
          border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
          border.width: 1
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
            implicitHeight: Math.max(64, resultInnerRow.implicitHeight + 20)
            Layout.preferredHeight: implicitHeight
            radius: Style.cornerRadius || 8
            readonly property bool isResultFocused: (index === root.selectedResultIndex)
            readonly property bool isResultHovered: resMouse.containsMouse

            color: isResultFocused
              ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
              : (isResultHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02))
            border.color: isResultFocused
              ? Color.accent
              : (isResultHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08))
            border.width: isResultFocused ? 2 : 1

            MouseArea {
              id: resMouse
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              hoverEnabled: true
              onEntered: root.selectedResultIndex = index
              onClicked: {
                if (root.panelRoot) root.panelRoot.focusSection = "content"
                root.selectedResultIndex = index
                root.activateResult(index)
              }
            }

            RowLayout {
              id: resultInnerRow
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.margins: 10
              spacing: 12

              // Category Icon Badge
              Rectangle {
                width: 38
                height: 38
                radius: 8
                color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
                border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.60)
                border.width: 1

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
                Layout.minimumWidth: 0
                spacing: 2

                Flow {
                  Layout.fillWidth: true
                  width: parent.width
                  spacing: 8

                  Text {
                    text: modelData.title
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body || 13
                    font.bold: true
                    color: resultCard.isResultFocused ? Color.accent : Color.foreground
                  }

                  Rectangle {
                    width: catBadgeText.implicitWidth + 10
                    height: 18
                    radius: 4
                    color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06)
                    border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12)
                    border.width: 1

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
                  Layout.minimumWidth: 0
                  wrapMode: Text.WordWrap
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
                color: resultCard.isResultFocused
                  ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25)
                  : (resultCard.isResultHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06))
                border.color: resultCard.isResultFocused
                  ? Color.accent
                  : (resultCard.isResultHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12))
                border.width: resultCard.isResultFocused ? 2 : 1

                RowLayout {
                  anchors.centerIn: parent
                  spacing: 4

                  Text {
                    text: "Open 󰅂"
                    font.family: Style.font.family
                    font.pixelSize: 11
                    font.bold: resultCard.isResultFocused
                    color: resultCard.isResultFocused ? Color.accent : Color.foreground
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
          width: parent.width
          spacing: 10

          Repeater {
            model: root.quickTiles

            delegate: Rectangle {
              id: tileCard
              width: parent.width > 680 ? Math.floor((parent.width - 20) / 3) : (parent.width > 340 ? Math.floor((parent.width - 10) / 2) : parent.width)
              implicitHeight: Math.max(76, tileRow.implicitHeight + 20)
              height: implicitHeight
              radius: 8
              readonly property bool isTileFocused: (root.focusZone === "tiles" && index === root.selectedTileIndex)
              readonly property bool isTileHovered: tileMouse.containsMouse

              color: isTileFocused
                ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
                : (isTileHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02))
              border.color: isTileFocused
                ? Color.accent
                : (isTileHovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08))
              border.width: isTileFocused ? 2 : 1

              MouseArea {
                id: tileMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (root.panelRoot) root.panelRoot.focusSection = "content"
                  root.selectedTileIndex = index
                  root.activateTile(index)
                }
              }

              RowLayout {
                id: tileRow
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 10
                spacing: 10

                Rectangle {
                  width: 36
                  height: 36
                  radius: 8
                  color: tileCard.isTileFocused
                    ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25)
                    : (tileCard.isTileHovered ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20) : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15))
                  border.color: tileCard.isTileFocused ? Color.accent : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.50)
                  border.width: 1

                  Text {
                    anchors.centerIn: parent
                    text: modelData.icon
                    font.family: Style.font.family
                    font.pixelSize: 18
                    color: Color.accent
                  }
                }

                ColumnLayout {
                  Layout.fillWidth: true
                  Layout.minimumWidth: 0
                  spacing: 2

                  Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: modelData.title
                    font.family: Style.font.family
                    font.pixelSize: 12
                    font.bold: true
                    color: tileCard.isTileFocused ? Color.accent : Color.foreground
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                  }

                  Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: tileCard.isTileFocused
                      ? ("󰌑 Enter to open • " + modelData.subtitle)
                      : modelData.subtitle
                    font.family: Style.font.family
                    font.pixelSize: 10
                    font.bold: tileCard.isTileFocused
                    color: tileCard.isTileFocused ? Color.accent : Color.muted
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                  }
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
          implicitHeight: Math.max(74, searchHintRow.implicitHeight + 28)
          Layout.preferredHeight: implicitHeight
          radius: 8
          color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.02)
          border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
          border.width: 1

          RowLayout {
            id: searchHintRow
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
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
              Layout.minimumWidth: 0
              spacing: 3

              Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                wrapMode: Text.WordWrap
                text: "Start typing directly anywhere in this panel to filter settings instantly."
                font.family: Style.font.family
                font.pixelSize: Style.font.body || 12
                font.bold: true
                color: Color.foreground
              }

              Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                wrapMode: Text.WordWrap
                text: "Use [↑/↓] to browse results, [Enter] to open that setting, or click any card."
                font.family: Style.font.family
                font.pixelSize: Style.font.subtext || 11
                color: Color.muted
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
