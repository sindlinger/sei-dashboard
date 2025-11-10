# GPUDevCLI.ps1

## Propósito
- Interface interativa (menu) para tarefas diárias de desenvolvimento da WaveSpecGPU em PowerShell.
- Centraliza build, sincronização, configuração de links e diagnósticos.

## Funcionalidades principais
- `[1]` Build incremental (`Build.ps1`).
- `[2]` Build limpo (`Build.ps1 -Clean`).
- `[3]` Copiar `Dev -> runtime` (`DevSync.ps1`).
- `[4]` Copiar + snapshot (`DevSync.ps1 -Snapshot`).
- `[5]` Corrigir links dos terminais (`WatchdogLinks_runtime_m5folders.py --fix` via Python).
- `[6]` Configurar links dos agentes tester (`SetupAgentTesterLinks.ps1`).
- `[7]` Remover links em um diretório (`RemoveLinks.ps1`).
- `[8]` Diagnóstico de junctions (`CheckLinks.ps1`).

## Integração
- Resolve automaticamente o executável Python (`python`/`python3`) para scripts auxiliares.
- Garantia de que os scripts respeitam os caminhos físicos de agentes definidos em `AgentsFiles-to-tester_folder_terminals/`.
