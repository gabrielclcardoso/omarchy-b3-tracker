import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "gcorreia.b3-tracker"

  property string timeWindow: "1mo"
  property string activeCategory: "Todas"
  property var dataModel: null
  property var allAssets: dataModel && dataModel.assets ? dataModel.assets : []
  property var displayedAssets: []
  property int currentIndex: 0
  property var currentAsset: displayedAssets.length > 0 ? displayedAssets[currentIndex % displayedAssets.length] : null
  property bool isFetching: fetchProc.running

  readonly property string fetcherPath: Qt.resolvedUrl("b3_fetch.py").toString().replace(/^file:\/\//, "")
  readonly property var windowLabels: ({
    "1d": "1D",
    "5d": "5D",
    "1mo": "1M",
    "3mo": "3M",
    "6mo": "6M",
    "ytd": "YTD",
    "1y": "1Y"
  })

  function updateDisplayed() {
    if (!allAssets || allAssets.length === 0) {
      displayedAssets = []
      return
    }
    if (activeCategory === "Todas") {
      displayedAssets = allAssets
    } else {
      var filtered = []
      for (var i = 0; i < allAssets.length; i++) {
        if (allAssets[i].category === activeCategory) {
          filtered.push(allAssets[i])
        }
      }
      displayedAssets = filtered
    }
    if (currentIndex >= displayedAssets.length) {
      currentIndex = 0
    }
  }

  onAllAssetsChanged: updateDisplayed()
  onActiveCategoryChanged: updateDisplayed()

  function fetch(force) {
    if (fetchProc.running) return
    var args = ["python3", fetcherPath, "--window", root.timeWindow]
    if (force) args.push("--force")
    fetchProc.command = args
    fetchProc.running = true
  }

  function setWindow(win) {
    if (root.timeWindow === win) return
    root.timeWindow = win
    fetch(false)
  }

  function nextAsset() {
    if (displayedAssets.length > 1) {
      currentIndex = (currentIndex + 1) % displayedAssets.length
    }
  }

  // ---- Panel management
  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
    if ("mainWidget" in target) target.mainWidget = root
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item && panelLoader.item.open) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close()
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item && panelLoader.item.closeForPopoutSwitch) panelLoader.item.closeForPopoutSwitch()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  Process {
    id: fetchProc
    command: ["python3", root.fetcherPath, "--window", root.timeWindow]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim()
        if (!raw) return
        try {
          var parsed = JSON.parse(raw)
          root.dataModel = parsed
        } catch (e) {
          console.warn("b3-tracker: error parsing JSON", e)
        }
      }
    }
  }

  // Periodic background refresh every 3 minutes
  Timer {
    interval: 180000
    running: true
    repeat: true
    onTriggered: root.fetch(false)
  }

  // Cycle through assets on the bar every 4.5 seconds
  // Bulletproof pause: stops whenever panel is open OR mouse is hovering over the widget
  Timer {
    id: carouselTimer
    interval: 4500
    running: !root.opened && !button.tooltipHovered && displayedAssets.length > 1
    repeat: true
    onTriggered: root.nextAsset()
  }

  Component.onCompleted: {
    fetch(false)
  }

  IpcHandler {
    target: "gcorreia.b3-tracker"

    function refresh(): void { root.fetch(true) }
    function next(): void { root.nextAsset() }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.togglePanel() }
  }

  // Standard Omarchy Bar Button with fixed stable width to prevent hover drops
  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    labelVisible: false
    hasVisualContent: true
    fixedWidth: Style.space(210)
    tooltipText: root.currentAsset ? (root.currentAsset.name + " (" + root.currentAsset.category + ") • Clique para abrir painel") : "B3 Tracker"

    onPressed: function(b) {
      if (b === Qt.MiddleButton) {
        root.fetch(true)
      } else {
        root.togglePanel()
      }
    }

    Row {
      id: rowLayout
      anchors.centerIn: parent
      spacing: Style.space(6)

      // Prefix tag
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "B3"
        color: Color.accent
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: true
        opacity: 0.9
      }

      // Content when loading or empty
      Text {
        visible: !root.currentAsset
        anchors.verticalCenter: parent.verticalCenter
        text: root.isFetching ? "Atualizando..." : "Sem dados"
        color: root.bar ? root.bar.barForeground : Color.foreground
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.body
        opacity: 0.6
      }

      // Active asset display
      Row {
        visible: !!root.currentAsset
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(5)

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.currentAsset ? root.currentAsset.symbol : ""
          color: root.bar ? root.bar.barForeground : Color.foreground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.body
          font.bold: true
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.currentAsset ? ("R$ " + Number(root.currentAsset.price).toFixed(2)) : ""
          color: root.bar ? root.bar.barForeground : Color.foreground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.body
          opacity: 0.85
        }

        Text {
          id: changeText
          anchors.verticalCenter: parent.verticalCenter
          text: {
            if (!root.currentAsset) return ""
            var pct = Number(root.currentAsset.changePercent)
            var arrow = pct > 0 ? "▲ " : (pct < 0 ? "▼ " : "")
            var sign = pct > 0 ? "+" : ""
            return arrow + sign + pct.toFixed(2) + "%"
          }
          color: {
            if (!root.currentAsset) return Color.foreground
            var pct = Number(root.currentAsset.changePercent)
            if (pct > 0) return "#4ade80" // theme positive green
            if (pct < 0) return "#f87171" // theme negative red
            return Color.muted
          }
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
        }

        // Window badge
        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: windowTag.implicitWidth + Style.space(6)
          height: windowTag.implicitHeight + Style.space(2)
          radius: Style.space(3)
          color: Color.background
          border.color: Color.muted
          border.width: 1
          opacity: 0.75

          Text {
            id: windowTag
            anchors.centerIn: parent
            text: root.windowLabels[root.timeWindow] || root.timeWindow
            color: Color.foreground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption * 0.85
            font.bold: true
          }
        }
      }
    }
  }
}
