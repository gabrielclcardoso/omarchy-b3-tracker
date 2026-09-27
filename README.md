# Omarchy B3 Tracker

Monitor de ações e fundos imobiliários (FIIs) da B3 para a barra do **Omarchy 4**.

Diferente do Google Finance que foca apenas na variação diária, este plugin permite analisar a evolução percentual dos ativos em **janelas de tempo personalizadas** (1D, 5D, 1M, 3M, 6M, YTD e 1Y).

---

## Recursos

- **Ticker Rotativo na Barra:** Alterna entre os ativos da sua lista com preço atual (R$), variação percentual colorida e tag do período.
- **Pausa Inteligente ao Passar o Mouse:** Ao posicionar o cursor sobre o widget, a rotação pausa e exibe detalhes do ativo via tooltip.
- **Painel Interativo:** Clique no widget para abrir a visão completa de todos os ativos.
- **Janelas de Tempo Configuráveis:** Alterne rapidamente entre `1D`, `5D`, `1M`, `3M`, `6M`, `YTD` e `1Y`.
- **Filtro por Categorias:** Navegue entre grupos (*Carteira Ações*, *Watchlist*, *FIIs* ou *Todas*).
- **Ordenação:** Organize por melhores altas, maiores quedas ou ordem alfabética.
- **Mini Gráficos (Sparklines):** Curva de tendência desenhada em tempo real para cada ativo no período selecionado.
- **Links Diretos:** Clique em qualquer linha do painel para abrir a página do ativo no navegador.

---

## Estrutura dos Arquivos

- `manifest.json`: Manifesto de registro do plugin no Omarchy.
- `BarWidget.qml`: Widget da barra de status com rotação e ancoragem de painel.
- `Panel.qml`: Painel dropdown com filtros, sparklines e tabela detalhada.
- `b3_fetch.py`: Script Python concorrente que busca cotações históricas e calcula a variação com cache local.

---

## Configuração

A lista de ativos e categorias fica salva em:
`~/.config/omarchy/b3-tracker.json`

```json
{
  "defaultWindow": "1mo",
  "cycleSeconds": 4,
  "categories": {
    "Watchlist": [
      {"symbol": "CMIG3", "name": "Cemig"},
      {"symbol": "CPFE3", "name": "CPFL Energia"}
    ],
    "Carteira Ações": [
      {"symbol": "BBAS3", "name": "Banco do Brasil"},
      {"symbol": "ITSA4", "name": "Itaúsa"}
    ],
    "FIIs": [
      {"symbol": "HGLG11", "name": "Patria Log FII"}
    ]
  }
}
```

---

## Comandos IPC (Linha de Comando)

Você pode interagir com o plugin via terminal:

```bash
# Forçar atualização de cotações
omarchy shell gcorreia.b3-tracker refresh

# Avançar para o próximo ativo na barra
omarchy shell gcorreia.b3-tracker next

# Abrir / Fechar o painel dropdown
omarchy shell gcorreia.b3-tracker toggle
```
