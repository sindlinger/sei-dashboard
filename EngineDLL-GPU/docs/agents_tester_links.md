# Agentes Tester - Estrutura compartilhada

Os agentes de Strategy Tester apenas leem arquivos fisicos; por isso os arquivos
mais recentes ficam no repositório `AgentsFiles-to-tester_folder_terminals/`.

## Conteudo fisico

- Manter **apenas 12 slots**: `AgentsFiles-to-tester_folder_terminals/Shared/SlotXX/MQL5/Libraries`.
- Cada slot recebe os DLLs/LIBs/EXEs gerados em `Dev/bin` (mantidos pelo `WatchdogFiles_dev_to_runtime.py`).

## Passos recomendados

1. `python watchdogs/WatchdogFiles_dev_to_runtime.py --apply --once`
   (apos cada build) - atualiza `runtime/` e todos os slots.
2. `./SetupAgentTesterLinks.ps1` (PowerShell **administrador**) - sincroniza os
   12 slots e recria as juncoes `MQL5\Libraries` de cada agente nas duas
   instalacoes (`MetaTrader 5` e `Dukascopy MetaTrader 5`). Caso algum agente
   nao exista, o script apenas registra um aviso no console/log.
3. Use `./RemoveLinks.ps1 -Path <agent>\MQL5 -Recurse` se quiser limpar links
   antigos antes do passo 2.

## Caminhos atendidos

- Slots numerados para os agentes `Agent-0.0.0.0-2000` ... `-2011`.
- Os 12 slots alimentam simultaneamente:
  - `C:\Program Files\MetaTrader 5\Tester\Agent-0.0.0.0-2000` ... `-2011`
  - `C:\Program Files\Dukascopy MetaTrader 5\Tester\Agent-0.0.0.0-2000` ... `-2011`

Se o MetaTrader encontrar menos agentes (por exemplo, apenas 12 em uma
instalacao), o script informa via log e prossegue com os que existem.

Edite `SetupAgentTesterLinks.ps1` caso novos agentes ou instalacoes sejam
adicionados.
