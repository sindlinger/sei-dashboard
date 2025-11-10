# GPU_Subwindows.mqh

## Propósito
- Encapsula operações de gerenciamento de sub-janelas de gráfico utilizando o helper `fxsaber/SubWindow.mqh`.
- Fornece utilidades para que o EA Hub anexe/detache indicadores Wave/Phase automaticamente, criando ou removendo sub-janelas conforme necessário.

## Estrutura
- Classe estática `CSubwindowController` com três métodos:
  - `EnsureCount(chart_id, desired_subwindow)`: cria sub-janela adicional (via `SUBWINDOW::Copy`) até atingir o índice desejado.
  - `Attach(chart_id, sub_window, indicator_handle)`: garante sub-janela e usa `ChartIndicatorAdd` para anexar o handle recebido.
  - `Detach(chart_id, sub_window, indicator_handle, short_name)`: remove o indicador (`ChartIndicatorDelete` + `IndicatorRelease`), libera sub-janela vazia usando `SUBWINDOW::Delete` e atualiza o ponteiro.
- Inclui salvaguardas para não operar com handles inválidos.

## Integração
- Utilizado por `GPU_EngineHub.mq5` ao lidar com botões/HUD: facilita anexar `GPU_WaveViz` e `GPU_PhaseViz` em sub-janelas configuráveis via inputs.
- Depende do pacote externo `fxsaber/SubWindow.mqh`; assegurar que o include esteja disponível na árvore `Include`.

## Uso
- Basta incluir `#include <GPU/GPU_Subwindows.mqh>` e chamar `CSubwindowController::Attach/Detach` ao gerenciar indicadores.
- Evita duplicação de lógica e mantém os scripts compatíveis com múltiplas versões do MetaTrader 5.
