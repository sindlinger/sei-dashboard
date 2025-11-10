WaveSpec GPU — Visão Geral do Fluxo
===================================

Este documento resume como o projeto WaveSpec GPU está estruturado após as
correções recentes. O objetivo é deixar claro quem escreve em cada pasta,
como os scripts sincronizam os artefatos e o que o MetaTrader efetivamente
enxerga.

Fontes, runtime e logs
----------------------

- `Dev/` — árvore-fonte versionada (Indicators, Experts, Include, Scripts e
  `Dev/bin` com os binários gerados).
- `runtime/` — cópia de distribuição. Recebe espelhos de `Dev/` e pode ser
  enviada para usuários ou agentes.
- `logs/` — diretório versionado que mantém `gpu_interactions.log`. O
  terminal aponta para cá via junction.

Integração com o MetaTrader (instância GUID)
-------------------------------------------

Dentro de `C:\Users\pichau\AppData\Roaming\MetaQuotes\Terminal\<GUID>` apenas as
pastas do WaveSpecGPU são reencaminhadas para `Dev/`:

- `MQL5\Indicators\GPU` → `Dev/Indicators/GPU`.
- `MQL5\Experts\GPU` → `Dev/Experts/GPU`.
- `MQL5\Include\GPU`, `\client_ipc`, `\engine_core`, `\ipc`, `\service` → `Dev/Include/...`.
- `MQL5\Scripts` (quando presente) → `Dev/Scripts`.
- `MQL5\Libraries` → `Dev/bin`.
- `MQL5\Files\WaveSpecGPU\logs` → `logs/`.

Com isso, o MetaEditor salva diretamente na árvore `Dev/`, e os binários
compilados ficam disponíveis para todos os consumidores (terminal, serviços e
agentes) a partir de `Dev/bin`.

Orquestração pelo CLI (GPUDevCLI.ps1)
-------------------------------------

A opção **1** do CLI executa o pipeline completo:

1. `Build.ps1` — recompila o GpuEngine (MSBuild + CUDA) e coloca tudo em `Dev/bin`.
2. `watchdogs/WatchdogFiles_dev_to_runtime.py --apply --once` — espelha `Dev/*` em `runtime/*`.
3. `SetupRuntimeLinks.ps1` — recria as junctions da instância atual apontando para `Dev/`.
4. `watchdogs/WatchdogLinks_runtime_m5folders.py --fix` — garante que todas as instâncias GUID tenham as mesmas junctions.
5. `Doctor --auto` — valida conteúdos (Dev vs runtime) e os links definidos em `links_config.json`.
6. Reinicia `runtime/bin\GpuEngineService.exe` no modo usuário.

Qualquer etapa também pode ser executada isoladamente (menu do CLI opções 2 a 10).
Se o serviço estiver em execução como administrador, rode o CLI elevado (ou encerre manualmente) antes da etapa de build para evitar bloqueios nas DLLs.

Esquema visual do fluxo
-----------------------

```
             ┌────────────────────────────────────────────┐
             │      MetaEditor / MT5 (instância GUID)      │
             │                                            │
             │  MQL5\Indicators ─┐                        │
             │  MQL5\Experts   ──┼──► Junctions ─────────┐│
             │  MQL5\Include   ──┤                       ││
             │  MQL5\Scripts   ──┤                       ││
             │  MQL5\Libraries ──┘                       ││
             │                                            ││
             └────────────────────────────────────────────┘│
                         │                                 │
                         ▼                                 │
                ┌────────────────┐                         │
                │      Dev/      │<────────────────────┐   │
                │  (fonte git)   │                     │   │
                └────────────────┘                     │   │
                         │                               │   │
                         │ Build.ps1                     │   │
                         │                               │   │
                         ▼                               │   │
                ┌────────────────┐                       │   │
                │    Dev/bin     │<────┐                 │   │
                └────────────────┘     │                 │   │
                         │             │ Watchdog        │   │
                         │             ▼                 │   │
                         │     ┌──────────────┐          │   │
                         └────►│   runtime/   │──────────┘   │
                               └──────────────┘              │
                                       │                     │
                                       ▼                     │
                              MetaTrader Agents/Deploy       │
                                                             │
            logs/ ◄────────── Junction ◄────────── MQL5\Files\WaveSpecGPU\logs
```

Agentes tester (12 slots locais)
--------------------------------

- A pasta `AgentsFiles-to-tester_folder_terminals/` permanece **dentro do
  projeto**, mas fora do versionamento (listada no `.gitignore`).
- `SetupAgentTesterLinks.ps1` e o watchdog dedicado continuam propagando os
  binários de `Dev/bin` e os artefatos MQL5 necessários para cada agente
  (`C:\Program Files\MetaTrader 5\Tester\Agent-0.0.0.0-20xx`).
- Após o pipeline (opção 1 do CLI), utilize a opção **9** se quiser garantir
  que os 12 agentes recebam as últimas atualizações logo depois do build.

Validação
---------

- `Doctor` (`GPUDevCLI.ps1 -Run 10`) compara conteúdo de `Dev/` com `runtime/`
  e valida cada junction listada em `links_config.json`.
- `watchdogs/WatchdogLinks_runtime_m5folders.py --fix` corrigiu o problema de
  `shutil.rmtree` em junctions; agora ele remove links quebrados com `lstat`
  antes de recriar.
