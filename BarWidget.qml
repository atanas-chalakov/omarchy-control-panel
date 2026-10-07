import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "ac.control-panel"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    horizontalMargin: 7.5
    onPressed: function(btn) {
      if (!root.bar) return
      if (btn === Qt.RightButton) {
        root.bar.run("omarchy-shell shell toggle ac.control-panel '{\"diff\":true}'")
      } else {
        root.bar.run("omarchy-shell shell toggle ac.control-panel")
      }
    }
  }
}
