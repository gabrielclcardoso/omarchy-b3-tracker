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
  property string currentView: "market" // "market" or "manage"
  property string targetCategory: ""

  readonly property var availableCategories: {
    var base = ["Todas"]
    if (mainWidget && mainWidget.dataModel && mainWidget.dataModel.categories) {
      return base.concat(mainWidget.dataModel.categories)
    }
    return ["Todas", "Carteira Ações", "Watchlist", "FIIs"]
  }

  readonly property var configuredCategories: {
    if (mainWidget && mainWidget.dataModel && mainWidget.dataModel.categories) {
      return mainWidget.dataModel.categories
    }
    return ["Watchlist", "Carteira Ações", "FIIs"]
  }

  readonly property string effectiveTargetCategory: {
    if (targetCategory && configuredCategories.indexOf(targetCategory) !== -1)
      return targetCategory
    return configuredCategories.length > 0 ? configuredCategories[0] : "Watchlist"
  }

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
    contentHeight: panel.fittedContentHeight(Style.space(640))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.currentView === "manage"
      onCloseRequested: {
        if (root.currentView === "manage") root.currentView = "market"
        else root.close()
      }
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Item {
        anchors.fill: parent
        anchors.margins: Style.space(16)

        Column {
          id: mainCol
          anchors.fill: parent
          spacing: Style.space(12)

          // ---- Header Row
          Item {
            width: parent.width
            height: Style.space(32)

            Column {
              anchors.left: parent.left
              anchors.right: headerActionsRow.left
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Row {
                spacing: Style.space(6)

                Text {
                  text: root.currentView === "manage" ? "Gerenciar Listas & Ativos" : "B3 Mercado de Capitais"
                  color: Color.popups.text
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.title
                  font.bold: true
                }

                // Window indicator badge (market view only)
                Rectangle {
                  visible: root.currentView === "market"
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
                text: root.currentView === "manage"
                  ? "Adicione, remova ou organize os ativos monitorados por carteira"
                  : (mainWidget && mainWidget.dataModel && mainWidget.dataModel.updatedAt
                      ? ("Última cotação: " + mainWidget.dataModel.updatedAt + " • " + root.upCount + " em alta, " + root.downCount + " em baixa")
                      : "Carregando cotações...")
                color: Color.muted
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
                width: parent.width
              }
            }

            // Action buttons on top right
            Row {
              id: headerActionsRow
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(6)

              // Manage / Back toggle button
              MouseArea {
                width: manageBtn.width
                height: Style.space(26)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.currentView = (root.currentView === "market" ? "manage" : "market")
                }

                Rectangle {
                  id: manageBtn
                  width: manageRow.implicitWidth + Style.space(16)
                  height: Style.space(26)
                  radius: Style.space(4)
                  color: root.currentView === "manage" ? Color.accent : (parent.containsMouse ? Style.hoverStateColor(Color.background, Color.accent) : "transparent")
                  border.color: Color.accent
                  border.width: 1

                  Row {
                    id: manageRow
                    anchors.centerIn: parent
                    spacing: Style.space(4)

                    Text {
                      text: root.currentView === "manage" ? "←" : "⚙"
                      color: root.currentView === "manage" ? Color.background : Color.accent
                      font.pixelSize: Style.font.body
                    }

                    Text {
                      text: root.currentView === "manage" ? "Concluir" : "Editar"
                      color: root.currentView === "manage" ? Color.background : Color.accent
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.caption
                      font.bold: true
                    }
                  }
                }
              }

              // Refresh button (market view only)
              MouseArea {
                visible: root.currentView === "market"
                width: refreshBtn.width
                height: Style.space(26)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (mainWidget) mainWidget.fetch(true)

                Rectangle {
                  id: refreshBtn
                  width: refreshRow.implicitWidth + Style.space(14)
                  height: Style.space(26)
                  radius: Style.space(4)
                  color: parent.containsMouse ? Color.accent : "transparent"
                  border.color: Color.accent
                  border.width: 1

                  Row {
                    id: refreshRow
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
          }

          // ==========================================
          // VIEW 1: LIVE MARKET MONITOR
          // ==========================================
          Column {
            id: marketCol
            visible: root.currentView === "market"
            width: parent.width
            spacing: Style.space(12)

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

            // ---- Category Tabs + Sort (with overflow protection)
            Item {
              width: parent.width
              height: Style.space(28)

              // Sort Toggle on the right
              MouseArea {
                id: sortArea
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

              // Dynamic Category Filter (Scrollable flickable so it never collides with sortArea)
              Flickable {
                anchors.left: parent.left
                anchors.right: sortArea.left
                anchors.rightMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                height: Style.space(28)
                contentWidth: catRow.implicitWidth
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                Row {
                  id: catRow
                  spacing: Style.space(6)
                  anchors.verticalCenter: parent.verticalCenter

                  Repeater {
                    model: root.availableCategories

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

                  // Quick add / manage button at end of tabs
                  MouseArea {
                    width: Style.space(24)
                    height: Style.space(24)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.currentView = "manage"

                    Rectangle {
                      anchors.fill: parent
                      radius: Style.space(4)
                      color: parent.containsMouse ? Style.hoverStateColor(Color.background, Color.accent) : "transparent"
                      border.color: Color.muted
                      border.width: 1
                      opacity: 0.7

                      Text {
                        anchors.centerIn: parent
                        text: "+"
                        color: Color.accent
                        font.bold: true
                        font.pixelSize: Style.font.body
                      }
                    }
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
              height: Style.space(420)
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
                          text: {
                            if (modelData.category === "Carteira Ações") return "Ação"
                            if (modelData.category === "FIIs") return "FII"
                            if (modelData.category === "Watchlist") return "Watch"
                            return String(modelData.category || "").substring(0, 5)
                          }
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
              text: "💡 <b>Dica:</b> Clique em um ativo para abrir no Google Finance • Clique em <b>Editar</b> acima para gerenciar listas e ativos"
              color: Color.muted
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption * 0.85
              opacity: 0.85
            }
          }

          // ==========================================
          // VIEW 2: MANAGEMENT (ADD / REMOVE ASSETS & LISTS)
          // ==========================================
          Column {
            id: manageCol
            visible: root.currentView === "manage"
            width: parent.width
            spacing: Style.space(10)

            Keys.onEscapePressed: root.currentView = "market"

            // Card 1: Add Asset Form (Multi-row, guaranteed zero horizontal overflow)
            Rectangle {
              width: parent.width
              height: addAssetCol.implicitHeight + Style.space(20)
              radius: Style.space(6)
              color: Color.background
              border.color: Color.accent
              border.width: 1
              opacity: 0.95

              Column {
                id: addAssetCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.space(10)
                spacing: Style.space(8)

                Text {
                  text: "+ ADICIONAR NOVO ATIVO"
                  color: Color.accent
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }

                // Row 1: Ticker, Name (flex-width), and Salvar button
                Item {
                  width: parent.width
                  height: Style.space(30)

                  Row {
                    id: addInputsRow
                    anchors.left: parent.left
                    anchors.right: addBtnArea.left
                    anchors.rightMargin: Style.space(8)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(8)

                    TextField {
                      id: tickerInput
                      width: Style.space(110)
                      placeholderText: "PETR4"
                      font.capitalization: Font.AllUppercase
                      maximumLength: 8
                      Keys.onReturnPressed: addBtnArea.submit()
                    }

                    TextField {
                      id: nameInput
                      width: parent.width - tickerInput.width - parent.spacing
                      placeholderText: "Nome da empresa (opcional)"
                      Keys.onReturnPressed: addBtnArea.submit()
                    }
                  }

                  // Submit button - pinned securely to the right edge of the card
                  MouseArea {
                    id: addBtnArea
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: addBtnRect.width
                    height: Style.space(28)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    function submit() {
                      var sym = tickerInput.text.trim()
                      if (!sym || !mainWidget) return
                      mainWidget.addAsset(sym, nameInput.text.trim(), root.effectiveTargetCategory)
                      tickerInput.text = ""
                      nameInput.text = ""
                      tickerInput.forceActiveFocus()
                    }
                    onClicked: submit()

                    Rectangle {
                      id: addBtnRect
                      width: addBtnLabel.implicitWidth + Style.space(18)
                      height: Style.space(28)
                      radius: Style.space(4)
                      color: tickerInput.text.trim().length > 0 ? Color.accent : Color.muted
                      opacity: tickerInput.text.trim().length > 0 ? (parent.containsMouse ? 0.9 : 1.0) : 0.4

                      Text {
                        id: addBtnLabel
                        anchors.centerIn: parent
                        text: "Salvar"
                        color: Color.background
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.caption
                        font.bold: true
                      }
                    }
                  }
                }

                // Row 2: Target category selector (horizontally scrollable flickable)
                Row {
                  width: parent.width
                  spacing: Style.space(6)

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Adicionar na lista:"
                    color: Color.muted
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }

                  Flickable {
                    width: parent.width - x
                    height: Style.space(26)
                    contentWidth: catChipsRow.implicitWidth
                    flickableDirection: Flickable.HorizontalFlick
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    Row {
                      id: catChipsRow
                      spacing: Style.space(4)
                      anchors.verticalCenter: parent.verticalCenter

                      Repeater {
                        model: root.configuredCategories

                        delegate: MouseArea {
                          required property string modelData
                          readonly property bool isTarget: root.effectiveTargetCategory === modelData
                          width: catChipText.implicitWidth + Style.space(12)
                          height: Style.space(24)
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: root.targetCategory = modelData

                          Rectangle {
                            anchors.fill: parent
                            radius: Style.space(4)
                            color: isTarget ? Color.accent : (parent.containsMouse ? Style.hoverStateColor(Color.background, Color.accent) : "transparent")
                            border.color: isTarget ? Color.accent : Color.muted
                            border.width: 1

                            Text {
                              id: catChipText
                              anchors.centerIn: parent
                              text: modelData
                              color: isTarget ? Color.background : Color.foreground
                              font.family: root.bar ? root.bar.fontFamily : Style.font.family
                              font.pixelSize: Style.font.caption * 0.9
                              font.bold: isTarget
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }

            // Card 2: Create New List / Category Row (flex-width, zero overflow)
            Rectangle {
              width: parent.width
              height: Style.space(40)
              radius: Style.space(6)
              color: Color.background
              border.color: Color.muted
              border.width: 1
              opacity: 0.85

              Item {
                anchors.fill: parent
                anchors.leftMargin: Style.space(10)
                anchors.rightMargin: Style.space(10)

                Text {
                  id: newCatLabel
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  text: "+ Nova Lista:"
                  color: Color.muted
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }

                TextField {
                  id: newCatInput
                  anchors.left: newCatLabel.right
                  anchors.leftMargin: Style.space(8)
                  anchors.right: createCatArea.left
                  anchors.rightMargin: Style.space(8)
                  anchors.verticalCenter: parent.verticalCenter
                  placeholderText: "Ex: Dividendos, Cripto..."
                  Keys.onReturnPressed: createCatArea.submit()
                }

                MouseArea {
                  id: createCatArea
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  width: createCatBtn.width
                  height: Style.space(26)
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  function submit() {
                    var cat = newCatInput.text.trim()
                    if (!cat || !mainWidget) return
                    mainWidget.addCategory(cat)
                    root.targetCategory = cat
                    newCatInput.text = ""
                  }
                  onClicked: submit()

                  Rectangle {
                    id: createCatBtn
                    width: createCatLabel.implicitWidth + Style.space(14)
                    height: Style.space(26)
                    radius: Style.space(4)
                    color: newCatInput.text.trim().length > 0 ? Color.accent : "transparent"
                    border.color: Color.accent
                    border.width: 1
                    opacity: newCatInput.text.trim().length > 0 ? 1.0 : 0.5

                    Text {
                      id: createCatLabel
                      anchors.centerIn: parent
                      text: "Criar Lista"
                      color: newCatInput.text.trim().length > 0 ? Color.background : Color.accent
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.caption * 0.9
                      font.bold: true
                    }
                  }
                }
              }
            }

            // Section Header
            Text {
              text: "LISTAS E ATIVOS CONFIGURADOS"
              color: Color.muted
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption * 0.9
              font.bold: true
            }

            // Card 3: Scrollable Categorized Assets Overview
            ListView {
              id: manageList
              width: parent.width
              height: Style.space(340)
              clip: true
              spacing: Style.space(8)
              boundsBehavior: Flickable.StopAtBounds
              model: root.configuredCategories

              delegate: Rectangle {
                id: catBox
                required property string modelData
                readonly property var catItems: (mainWidget && mainWidget.dataModel && mainWidget.dataModel.rawCategories && mainWidget.dataModel.rawCategories[modelData]) ? mainWidget.dataModel.rawCategories[modelData] : []
                width: manageList.width
                height: catContentCol.implicitHeight + Style.space(14)
                radius: Style.space(6)
                color: Color.background
                border.color: Color.muted
                border.width: 1
                opacity: 0.9

                Column {
                  id: catContentCol
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.top: parent.top
                  anchors.margins: Style.space(8)
                  spacing: Style.space(6)

                  // Category Header
                  Item {
                    width: parent.width
                    height: Style.space(20)

                    Row {
                      anchors.left: parent.left
                      anchors.right: delCatArea.left
                      anchors.rightMargin: Style.space(8)
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(6)

                      Text {
                        text: catBox.modelData
                        color: Color.foreground
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.body
                        font.bold: true
                        elide: Text.ElideRight
                      }

                      Text {
                        text: "(" + catBox.catItems.length + (catBox.catItems.length === 1 ? " ativo" : " ativos") + ")"
                        color: Color.muted
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.caption
                      }
                    }

                    // Delete Category Button
                    MouseArea {
                      id: delCatArea
                      anchors.right: parent.right
                      anchors.verticalCenter: parent.verticalCenter
                      width: delCatLabel.implicitWidth + Style.space(8)
                      height: Style.space(18)
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        if (mainWidget) mainWidget.removeCategory(catBox.modelData)
                      }

                      Text {
                        id: delCatLabel
                        anchors.centerIn: parent
                        text: "Excluir Lista ✕"
                        color: parent.containsMouse ? "#f87171" : Color.muted
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.caption * 0.85
                        font.bold: parent.containsMouse
                      }
                    }
                  }

                  // Divider
                  Rectangle {
                    width: parent.width
                    height: 1
                    color: Color.muted
                    opacity: 0.2
                  }

                  // Empty State
                  Text {
                    visible: catBox.catItems.length === 0
                    text: "Nenhum ativo nesta lista. Selecione-a acima para adicionar."
                    color: Color.muted
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption
                    font.italic: true
                  }

                  // Flow of Asset Chips
                  Flow {
                    width: parent.width
                    spacing: Style.space(6)
                    visible: catBox.catItems.length > 0

                    Repeater {
                      model: catBox.catItems

                      delegate: Rectangle {
                        required property var modelData
                        width: Math.min(assetChipRow.implicitWidth + Style.space(12), parent.width)
                        height: Style.space(24)
                        radius: Style.space(4)
                        color: chipArea.containsMouse ? Style.hoverStateColor(Color.background, Color.accent) : Qt.rgba(1, 1, 1, 0.05)
                        border.color: Color.muted
                        border.width: 1

                        Row {
                          id: assetChipRow
                          anchors.centerIn: parent
                          spacing: Style.space(5)

                          Text {
                            text: modelData.symbol
                            color: Color.foreground
                            font.family: root.bar ? root.bar.fontFamily : Style.font.family
                            font.pixelSize: Style.font.caption
                            font.bold: true
                          }

                          Text {
                            visible: modelData.name && modelData.name !== modelData.symbol
                            text: "(" + modelData.name + ")"
                            color: Color.muted
                            font.family: root.bar ? root.bar.fontFamily : Style.font.family
                            font.pixelSize: Style.font.caption * 0.85
                            elide: Text.ElideRight
                            width: Math.min(implicitWidth, Style.space(130))
                          }

                          // Delete asset button
                          MouseArea {
                            id: chipArea
                            width: Style.space(16)
                            height: Style.space(16)
                            anchors.verticalCenter: parent.verticalCenter
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              if (mainWidget) mainWidget.removeAsset(modelData.symbol, catBox.modelData)
                            }

                            Text {
                              anchors.centerIn: parent
                              text: "✕"
                              color: parent.containsMouse ? "#f87171" : Color.muted
                              font.pixelSize: Style.font.caption * 0.9
                              font.bold: parent.containsMouse
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
