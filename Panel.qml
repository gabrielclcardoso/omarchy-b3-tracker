import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "gcorreia.b3-tracker"
  ipcTarget: "gcorreia.b3-tracker.panel"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var mainWidget: null
  readonly property var barIdentity: hostWidget || root

  property string sortMode: "perfDesc" // perfDesc, perfAsc, alpha

  readonly property var windowLabels: ({
    "1d": "1D",
    "5d": "5D",
    "1mo": "1M",
    "3mo": "3M",
    "6mo": "6M",
    "ytd": "YTD",
    "1y": "1Y"
  })

  readonly property var windowNames: ({
    "1d": "Hoje (1 Dia)",
    "5d": "1 Semana (5 Dias)",
    "1mo": "1 Mês",
    "3mo": "3 Meses",
    "6mo": "6 Meses",
    "ytd": "Ano Atual (YTD)",
    "1y": "1 Ano"
  })

  function open() {
    setCenterHoverRevealSuppressed(false)
    root.controller.show()
  }

  function openFromHotkey() {
    root.controller.show()
    Qt.callLater(function() {
      if (root.opened) setCenterHoverRevealSuppressed(true)
    })
  }

  function close() {
    setCenterHoverRevealSuppressed(false)
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function setCenterHoverRevealSuppressed(value) {
    if (root.bar && typeof root.bar.setCenterHoverRevealSuppressed === "function")
      root.bar.setCenterHoverRevealSuppressed(value)
    else if (root.bar && "centerHoverRevealSuppressed" in root.bar)
      root.bar.centerHoverRevealSuppressed = value
  }

  // Assets filtered by active category and sorted by sortMode
  readonly property var processedAssets: {
    if (!mainWidget || !mainWidget.allAssets) return []
    var list = []
    var cat = mainWidget.activeCategory
    var raw = mainWidget.allAssets

    for (var i = 0; i < raw.length; i++) {
      if (cat === "Todas" || raw[i].category === cat) {
        list.push(raw[i])
      }
    }

    if (sortMode === "perfDesc") {
      list.sort(function(a, b) { return b.changePercent - a.changePercent })
    } else if (sortMode === "perfAsc") {
      list.sort(function(a, b) { return a.changePercent - b.changePercent })
    } else if (sortMode === "alpha") {
      list.sort(function(a, b) { return a.symbol.localeCompare(b.symbol) })
    }
    return list
  }

  // Count stats
  readonly property int upCount: {
    var c = 0
    for (var i = 0; i < processedAssets.length; i++) {
      if (processedAssets[i].changePercent > 0) c++
    }
    return c
  }

  readonly property int downCount: {
    var c = 0
    for (var i = 0; i < processedAssets.length; i++) {
      if (processedAssets[i].changePercent < 0) c++
    }
    return c
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(520))
    contentHeight: panel.fittedContentHeight(Style.space(620))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Item {
        anchors.fill: parent
        anchors.margins: Style.space(16)

        Column {
          id: mainCol
          anchors.fill: parent
          spacing: Style.space(12)

          // ---- Header Row (Item with Left and Right)
          Item {
            width: parent.width
            height: Style.space(32)

            Column {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Row {
                spacing: Style.space(6)

                Text {
                  text: "B3 Mercado de Capitais"
                  color: Color.popups.text
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.title
                  font.bold: true
                }

                // Window indicator badge
                Rectangle {
                  anchors.verticalCenter: parent.verticalCenter
                  width: windowTitleBadge.implicitWidth + Style.space(8)
                  height: windowTitleBadge.implicitHeight + Style.space(4)
                  radius: Style.space(4)
                  color: Color.accent
                  opacity: 0.85

                  Text {
                    id: windowTitleBadge
                    anchors.centerIn: parent
                    text: mainWidget ? (root.windowNames[mainWidget.timeWindow] || mainWidget.timeWindow) : "1 Mês"
                    color: Color.background
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                }
              }

              Text {
                text: mainWidget && mainWidget.dataModel && mainWidget.dataModel.updatedAt
                  ? ("Última cotação: " + mainWidget.dataModel.updatedAt + " • " + root.upCount + " em alta, " + root.downCount + " em baixa")
                  : "Carregando cotações..."
                color: Color.muted
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
              }
            }

            // Refresh button on top right
            MouseArea {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              width: refreshBtn.width + Style.space(12)
              height: Style.space(28)
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: if (mainWidget) mainWidget.fetch(true)

              Rectangle {
                id: refreshBtn
                anchors.centerIn: parent
                width: Style.space(78)
                height: Style.space(26)
                radius: Style.space(4)
                color: parent.containsMouse ? Color.accent : "transparent"
                border.color: Color.accent
                border.width: 1

                Row {
                  anchors.centerIn: parent
                  spacing: Style.space(4)

                  Text {
                    text: mainWidget && mainWidget.isFetching ? "⏳" : "↻"
                    color: parent.parent.parent.containsMouse ? Color.background : Color.accent
                    font.pixelSize: Style.font.body
                  }

                  Text {
                    text: "Atualizar"
                    color: parent.parent.parent.containsMouse ? Color.background : Color.accent
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                }
              }
            }
          }

          // ---- Time Window Selector Row
          Row {
            width: parent.width
            spacing: Style.space(6)

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "Período:"
              color: Color.muted
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            Repeater {
              model: ["1d", "5d", "1mo", "3mo", "6mo", "ytd", "1y"]

              delegate: MouseArea {
                required property string modelData
                readonly property bool isActive: mainWidget && mainWidget.timeWindow === modelData
                width: winText.implicitWidth + Style.space(14)
                height: Style.space(24)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: if (mainWidget) mainWidget.setWindow(modelData)

                Rectangle {
                  anchors.fill: parent
                  radius: Style.space(4)
                  color: isActive ? Color.accent : (parent.containsMouse ? Style.hoverStateColor(Color.background, Color.accent) : "transparent")
                  border.color: isActive ? Color.accent : Color.muted
                  border.width: 1
                  opacity: isActive ? 1.0 : (parent.containsMouse ? 0.9 : 0.6)

                  Text {
                    id: winText
                    anchors.centerIn: parent
                    text: root.windowLabels[modelData]
                    color: isActive ? Color.background : Color.foreground
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: isActive
                  }
                }
              }
            }
          }

          // ---- Category Tabs + Sort (Item with Left and Right)
          Item {
            width: parent.width
            height: Style.space(28)

            // Category Filter
            Row {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(6)

              Repeater {
                model: ["Todas", "Carteira Ações", "Watchlist", "FIIs"]

                delegate: MouseArea {
                  required property string modelData
                  readonly property bool isSelected: mainWidget && mainWidget.activeCategory === modelData
                  width: catText.implicitWidth + Style.space(12)
                  height: Style.space(24)
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor

                  onClicked: if (mainWidget) mainWidget.activeCategory = modelData

                  Rectangle {
                    anchors.fill: parent
                    radius: Style.space(4)
                    color: isSelected ? Color.background : "transparent"
                    border.color: isSelected ? Color.accent : "transparent"
                    border.width: 1

                    Text {
                      id: catText
                      anchors.centerIn: parent
                      text: modelData
                      color: isSelected ? Color.accent : (parent.parent.containsMouse ? Color.foreground : Color.muted)
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.caption
                      font.bold: isSelected
                    }
                  }
                }
              }
            }

            // Sort Toggle on the right
            MouseArea {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              width: sortRow.implicitWidth + Style.space(8)
              height: Style.space(24)
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (root.sortMode === "perfDesc") root.sortMode = "perfAsc"
                else if (root.sortMode === "perfAsc") root.sortMode = "alpha"
                else root.sortMode = "perfDesc"
              }

              Row {
                id: sortRow
                anchors.centerIn: parent
                spacing: Style.space(3)

                Text {
                  text: root.sortMode === "perfDesc" ? "▲ " : (root.sortMode === "perfAsc" ? "▼ " : "🔤 ")
                  color: Color.accent
                  font.pixelSize: Style.font.caption
                }

                Text {
                  text: root.sortMode === "perfDesc" ? "Melhores" : (root.sortMode === "perfAsc" ? "Piores" : "A-Z")
                  color: Color.muted
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                }
              }
            }
          }

          // Divider
          Rectangle {
            width: parent.width
            height: 1
            color: Color.muted
            opacity: 0.25
          }

          // ---- Scrollable Asset List
          ListView {
            id: assetList
            width: parent.width
            height: Style.space(410)
            clip: true
            spacing: Style.space(6)
            boundsBehavior: Flickable.StopAtBounds
            model: root.processedAssets

            delegate: Rectangle {
              id: assetCard
              required property var modelData
              width: assetList.width
              height: Style.space(46)
              radius: Style.space(6)
              color: cardMouse.containsMouse ? Style.hoverStateColor(Color.background, Color.accent) : Color.background
              opacity: cardMouse.containsMouse ? 0.95 : 0.85
              border.color: cardMouse.containsMouse ? Color.accent : "transparent"
              border.width: 1

              Behavior on color { ColorAnimation { duration: 120 } }

              Item {
                anchors.fill: parent
                anchors.leftMargin: Style.space(12)
                anchors.rightMargin: Style.space(12)

                // Left: Symbol & Name
                Column {
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  width: Style.space(130)
                  spacing: Style.space(1)

                  Row {
                    spacing: Style.space(6)

                    Text {
                      text: modelData.symbol
                      color: Color.foreground
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.body
                      font.bold: true
                    }

                    // Category tag
                    Rectangle {
                      anchors.verticalCenter: parent.verticalCenter
                      width: catTag.implicitWidth + Style.space(6)
                      height: catTag.implicitHeight + Style.space(2)
                      radius: Style.space(3)
                      color: Color.background
                      border.color: Color.muted
                      border.width: 1
                      opacity: 0.6

                      Text {
                        id: catTag
                        anchors.centerIn: parent
                        text: modelData.category === "Carteira Ações" ? "Ação" : (modelData.category === "FIIs" ? "FII" : "Watch")
                        color: Color.muted
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.caption * 0.75
                      }
                    }
                  }

                  Text {
                    text: modelData.name || modelData.symbol
                    color: Color.muted
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption * 0.9
                    elide: Text.ElideRight
                    width: Style.space(130)
                  }
                }

                // Center: Sparkline Canvas
                Canvas {
                  id: sparkline
                  anchors.centerIn: parent
                  width: Style.space(110)
                  height: Style.space(24)
                  readonly property var pts: modelData.points || []
                  readonly property bool isUp: modelData.changePercent >= 0

                  onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    if (!pts || pts.length < 2) return

                    var min = pts[0]
                    var max = pts[0]
                    for (var k = 1; k < pts.length; k++) {
                      if (pts[k] < min) min = pts[k]
                      if (pts[k] > max) max = pts[k]
                    }
                    var range = (max - min) || 1
                    var w = width
                    var h = height - 4

                    ctx.strokeStyle = isUp ? "#4ade80" : "#f87171"
                    ctx.lineWidth = 1.6
                    ctx.lineJoin = "round"
                    ctx.lineCap = "round"
                    ctx.beginPath()

                    for (var j = 0; j < pts.length; j++) {
                      var x = (j / (pts.length - 1)) * w
                      var y = h - ((pts[j] - min) / range) * (h - 4) + 2
                      if (j === 0) ctx.moveTo(x, y)
                      else ctx.lineTo(x, y)
                    }
                    ctx.stroke()
                  }

                  Component.onCompleted: requestPaint()
                  Connections {
                    target: root
                    function onProcessedAssetsChanged() { sparkline.requestPaint() }
                  }
                }

                // Right: Prices & Variation Badge
                Row {
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(10)

                  // Current price & start price
                  Column {
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                      anchors.right: parent.right
                      text: "R$ " + Number(modelData.price).toFixed(2)
                      color: Color.foreground
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.body
                      font.bold: true
                    }

                    Text {
                      anchors.right: parent.right
                      text: "Início: R$ " + Number(modelData.startPrice).toFixed(2)
                      color: Color.muted
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.caption * 0.85
                    }
                  }

                  // Variation Pill
                  Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Style.space(76)
                    height: Style.space(26)
                    radius: Style.space(4)
                    color: modelData.changePercent > 0
                      ? Qt.rgba(74/255, 222/255, 128/255, 0.15)
                      : (modelData.changePercent < 0 ? Qt.rgba(248/255, 113/255, 113/255, 0.15) : Qt.rgba(148/255, 163/255, 184/255, 0.15))
                    border.color: modelData.changePercent > 0 ? "#4ade80" : (modelData.changePercent < 0 ? "#f87171" : Color.muted)
                    border.width: 1

                    Text {
                      anchors.centerIn: parent
                      text: (modelData.changePercent > 0 ? "+ " : "") + Number(modelData.changePercent).toFixed(2) + "%"
                      color: modelData.changePercent > 0 ? "#4ade80" : (modelData.changePercent < 0 ? "#f87171" : Color.muted)
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.caption
                      font.bold: true
                    }
                  }
                }
              }

              MouseArea {
                id: cardMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (root.bar) {
                    var query = "https://www.google.com/finance/quote/" + modelData.symbol + ":BVMF"
                    root.bar.run("xdg-open '" + query + "'")
                  }
                }
              }
            }
          }

          // ---- Footer note
          Text {
            width: parent.width
            wrapMode: Text.WordWrap
            textFormat: Text.StyledText
            text: "💡 <b>Dica:</b> Clique em um ativo para abrir no navegador • Edite em <font color='" + Color.accent + "'>~/.config/omarchy/b3-tracker.json</font>"
            color: Color.muted
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption * 0.85
            opacity: 0.85
          }
        }
      }
    }
  }
}
