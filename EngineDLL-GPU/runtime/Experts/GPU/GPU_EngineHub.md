# GPU_EngineHub.mq5 (runtime)

## Visão geral
- Mesma implementação do EA hub localizado em `Dev/Experts/GPU/GPU_EngineHub.mq5`.
- Orquestra jobs do `GpuEngineClient.dll` para alimentar `runtime/Include/GPU/GPU_Shared.mqh`, permitindo que indicadores no ambiente runtime tenham acesso às séries GPU.

## Papel no runtime
- Instalado automaticamente nas instâncias MetaTrader via `SetupRuntimeLinks.ps1`/`WatchdogFiles_dev_to_runtime.py`.
- Mantém timer, anexos de indicadores e publicação de HUDs exatamente como na versão de desenvolvimento; editar apenas na árvore `Dev/`.

## Integração e requisitos
- Requer que as DLLs estejam presentes nos diretórios físicos de agentes (`AgentsFiles-to-tester_folder_terminals/`).
- Depende dos includes runtime (`GPU_Shared.mqh`, `GPU_Subwindows.mqh`) que também são sincronizados.
