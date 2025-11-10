# WaveSpec GPU – Estrutura de Desenvolvimento

Este repositorio gira em torno de tres diretorios principais:

- `Dev/` – arvore versionada contendo codigo-fonte MQL5/C++ e os binarios gerados (subpasta `bin/`).
- `runtime/` – cópia gerada automaticamente para distribuição (agentes/testers); o MetaTrader aponta diretamente para `Dev/` via junções.
- `Versionamento/` – snapshots opcionais criados via `DevSync.ps1 -Snapshot`.

## Scripts principais

| Script            | Funcao |
|-------------------|--------|
| `Build.ps1` | Executa CMake + build (`build_vs`) e grava artefatos em `Dev\bin`; orquestra as etapas de build. |
| `DevSync.ps1`     | Copia `Dev/` -> `runtime/` (incremental por padrao, `-All` para espelhar). Opcionais: `-Snapshot` (`Versionamento/<timestamp>`) e `-DryRun`. |
| `GPUDevCLI.ps1`   | Menu interativo com as operacoes mais comuns (build, build limpo, sync, snapshot). |
| `WatchdogFiles_dev_to_runtime.py` | Monitora/copia arquivos de `Dev/` (bin, Indicators, Experts, Include, Scripts) para `runtime/` e `AgentsFiles-to-tester_folder_terminals\MQL5\Libraries` (`python watchdogs/WatchdogFiles_dev_to_runtime.py [--apply]`). |
| `WatchdogLinks_runtime_m5folders.py` | Verifica e, com `--fix`, garante que os diretórios do MetaTrader apontem para `Dev/`. |
| `SetupRuntimeLinks.ps1` | Recria junções das instâncias MetaTrader apontando para `Dev/`, `runtime/` ou um diretório customizado (`-SourceMode`). |
| `RemoveLinks.ps1` | Remove links simbolicos/junctions de um diretorio (`./RemoveLinks.ps1 -Path <dir> [-Recurse]`). |
| `SetupAgentTesterLinks.ps1` | Cria links `MQL5\Libraries` dos agentes tester para `AgentsFiles-to-tester_folder_terminals\MQL5\Libraries`. |

### Legado

O codigo anterior ao fluxo atual permanece em `legacy_mql_gpu_original_*`. Consulte
`docs/legacy_mql_gpu.md` para detalhes. Esses arquivos sao apenas referencia
historica e nao participam dos builds ou deploys atuais.

### Agents tester

- Os binários ficam em 12 slots compartilhados: `AgentsFiles-to-tester_folder_terminals\Shared\SlotXX\MQL5\Libraries`.
- `WatchdogFiles_dev_to_runtime.py` (hook “After compile” ou execução manual) sincroniza o conteúdo de `Dev/bin` para cada slot.
- `./SetupAgentTesterLinks.ps1` (PowerShell **administrador**) recria as juncoes `MQL5\Libraries` de cada agente nas duas instalacoes (`C:\Program Files\MetaTrader 5` e `C:\Program Files\Dukascopy MetaTrader 5`). Se algum agente nao existir, o script registra um aviso e segue.
- Detalhes adicionais: `docs/agents_tester_links.md`.

### MetaEditor After Compile

- Em *Tools -> Options -> General -> After compile run*, use:
  `powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "<repo>\WatchdogAfterCompile.ps1" "%path%"`.
- Isso dispara `WatchdogFiles_dev_to_runtime.py --apply --once`, atualizando `runtime/` (para deploy) e `AgentsFiles-to-tester_folder_terminals\MQL5\Libraries` após cada compilação no MetaEditor.



Todos os scripts devem ser executados no **Developer PowerShell for VS 2022** (ou prompt equivalente) na pasta `MQL5\WaveSpecGPU`.

## Fluxo de trabalho sugerido

1. `./Build.ps1 -Clean` (somente quando precisar regenerar `build_vs`).
2. `./Build.ps1` para rebuilds incrementais (artefatos já são copiados para `Dev/bin` e replicados via watchdog).
3. `python watchdogs/WatchdogFiles_dev_to_runtime.py --apply --once` (opcional) para refletir alteracoes manuais de `Dev/` no runtime e no repositorio de agentes.
4. `python watchdogs/WatchdogLinks_runtime_m5folders.py --fix` para garantir que as instâncias continuem apontando para `Dev/`.
5. `./SetupAgentTesterLinks.ps1` (administrador) para atualizar `MQL5\Libraries` dos agentes tester.
6. `./DevSync.ps1 -Snapshot -Label <texto>` para registrar marcos relevantes.
7. Recompile indicadores/EAs no MetaEditor64 (gera `.ex5` em `Dev/`) e use `./DevSync.ps1` para propagá-los ao `runtime/` quando necessário.

Para alternar rapidamente as junções:
- `./GPUDevCLI.ps1 -Run 11` → links para `Dev/` (padrão).
- `./GPUDevCLI.ps1 -Run 12` → links para `runtime/` (modo teste).
- `./GPUDevCLI.ps1 -Run 13,<caminho>` → pergunta um diretório base customizado.

> Observação: a opção 1 (pipeline completo) precisa encerrar `GpuEngineService.exe`. Execute o CLI como administrador ou use a opção 12 para migrar temporariamente o serviço para `runtime/` antes de recompilar. Ao final, ela exibe um mini-relatório com o tempo e status de cada etapa.

Cronograma rapido via CLI:

```powershell
.\GPUDevCLI.ps1   # abre menu interativo
```

## Links nas instancias MetaTrader

Use `SetupRuntimeLinks.ps1` (ou o pipeline 9 do `GPUDevCLI.ps1`) para recriar as junções
automaticamente. O script consulta `links_config.json` e ajusta somente as pastas do
WaveSpecGPU, deixando os headers padrões do MetaTrader intocados.

Pastas atualmente mapeadas para `Dev/`:

- `MQL5\Indicators\GPU` → `<repo>\Dev\Indicators\GPU`
- `MQL5\Experts\GPU` → `<repo>\Dev\Experts\GPU`
- `MQL5\Include\GPU`, `\client_ipc`, `\engine_core`, `\ipc`, `\service` → `<repo>\Dev\Include\...`
- `MQL5\Libraries` → `<repo>\Dev\bin`
- `MQL5\Files\WaveSpecGPU\logs` → `<repo>\logs`

Mantenha `runtime/` sincronizado com `DevSync.ps1` quando precisar distribuir arquivos para
testers ou agentes. Snapshots opcionais ficam disponíveis em `Versionamento/`.
