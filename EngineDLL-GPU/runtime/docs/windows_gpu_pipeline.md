# Pipeline Windows – Build, Runtime e Verificacao

Este guia consolida o fluxo oficial para compilar e disponibilizar o conjunto **GpuEngine** em ambientes Windows (terminais MetaTrader e agentes locais).

## Pre-requisitos

- **Windows 10/11** com privilegios de administrador (necessario para criar junctions/symlinks).
- **Visual Studio 2022 Build Tools** com os workloads *Desktop development with C++* e *C++ CMake tools for Windows*.
- **CUDA Toolkit 13.0** instalado em `C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.0`.
- **CMake 3.23+** com suporte ao gerador *Visual Studio 17 2022*.
- Abra sempre o **Developer PowerShell for VS 2022** (ou *x64 Native Tools Command Prompt*) antes de executar os scripts.

## Diretorios principais

- `Dev/` – arvore versionada que editamos (inclui `bin`, `src`, `Experts`, `Indicators`, etc.).
- `runtime/` – copia fisica usada pelas instancias; os links dos terminais apontam aqui.
- `Versionamento/` – snapshots opcionais criados manualmente (ex.: `DevSync.ps1 -Snapshot`).

## 1. Build + Deploy

Script: `Build.ps1`

```powershell
cd C:\Users\pichau\AppData\Roaming\MetaQuotes\Terminal\3CA1B4AB7DFED5C81B1C7F1007926D06\MQL5\WaveSpecGPU
.\Build.ps1 [-Clean] [-Configuration Release|Debug] [-SkipSync]
```

O script:

1. Executa CMake (VS 2022) e compila `GpuEngine`, `GpuEngineClient` e `GpuEngineService`.
2. Deposita os artefatos em `Dev\bin` (DLLs, LIB/EXP, `cudadevrt.lib`, etc.).

## 2. Sincronizacao e snapshots

Script: `DevSync.ps1`

```powershell
.\DevSync.ps1 [-All] [-Snapshot] [-Label texto] [-DryRun]
```

- Sem parametros: copia somente arquivos novos/alterados de `Dev/` para `runtime/`.
- `-All`: espelha (`/MIR`) removendo arquivos obsoletos no runtime.
- `-Snapshot`: cria um diretorio em `Versionamento/<timestamp>[_Label]` com a foto atual do `Dev/`.
- `-DryRun`: mostra as operacoes sem tocar nos arquivos.

## 3. CLI de desenvolvimento

Script: `GPUDevCLI.ps1`

Menu interativo que expoe:

1. Build incremental (atualiza runtime/bin)
2. Build limpo
3. `DevSync.ps1`
4. `DevSync.ps1 -Snapshot`
5. Correcao de links (`WatchdogLinks_runtime_m5folders.py --fix`)
6. Remocao de links (`RemoveLinks.ps1`)
7. Diagnostico (`CheckLinks.ps1`)

Execute em PowerShell:

```powershell
.\GPUDevCLI.ps1
```

## 4. Links para as instancias

Execute `SetupRuntimeLinks.ps1` sempre que precisar recriar as junções. Ele lê
`links_config.json` e ajusta somente as pastas do WaveSpecGPU, mantendo os headers nativos
do MetaTrader no lugar.

Pastas padrão mapeadas para `Dev/`:

- `MQL5\Indicators\GPU`
- `MQL5\Experts\GPU`
- `MQL5\Include\GPU`, `\client_ipc`, `\engine_core`, `\ipc`, `\service`
- `MQL5\Libraries`
- `MQL5\Files\WaveSpecGPU\logs`

Após os links existirem, use `DevSync.ps1`/`watchdogs` para manter `runtime/` alinhado
quando for distribuir artefatos.

## Fluxo recomendado

1. `./Build.ps1 -Clean` (somente quando necessario limpar `build_vs`).
2. `./Build.ps1` para rebuilds incrementais (Dev/bin e runtime/bin atualizados).
3. `python watchdogs/WatchdogFiles_dev_to_runtime.py --apply --once` (opcional) para refletir alteracoes manuais em `Dev/` (bin, Indicators, Experts, Include, Scripts) no runtime entre builds.
4. `python watchdogs/WatchdogLinks_runtime_m5folders.py --fix` para manter as instancias apontando para `runtime/`.
5. `./SetupAgentTesterLinks.ps1` (administrador) para alinhar `MQL5\Libraries` dos agentes tester.
6. `./DevSync.ps1 -Snapshot -Label <texto>` sempre que quiser registrar uma versao.
7. Recompile indicadores/EAs no MetaEditor64 (gera `.ex5` em `Dev/`) e use `./DevSync.ps1` quando precisar propagar essas alteracoes para `runtime/`.

Links rápidos:
- `./GPUDevCLI.ps1 -Run 11` → junções para `Dev/` (modo padrão).
- `./GPUDevCLI.ps1 -Run 12` → junções para `runtime/` (modo teste).
- `./GPUDevCLI.ps1 -Run 13=C:\caminho\custom` → junções para um diretório customizado.

## 5. Watchdog Dev/runtime

O utilitario Python `watchdogs/WatchdogFiles_dev_to_runtime.py` mantem `runtime/` alinhado com `Dev/` (bin, Indicators, Experts, Include e Scripts):

```powershell
python watchdogs/WatchdogFiles_dev_to_runtime.py            # monitoramento continuo (somente registro)
python watchdogs/WatchdogFiles_dev_to_runtime.py --once     # varredura unica
python watchdogs/WatchdogFiles_dev_to_runtime.py --apply    # registra e tambem copia arquivos novos/alterados
```

Use `--interval` para ajustar o tempo entre verificacoes (padrao: 600s = 10 minutos) e `--quiet` para reduzir os logs.

Para revisar e recriar juncoes quando necessario:

```powershell
python watchdogs/WatchdogLinks_runtime_m5folders.py --fix
```

## Selecao de backend (servico × DLL)

- Os EAs/indicadores importam `GpuEngineClient.dll`. Fora do Strategy Tester, o servico (`GpuEngineService.exe`) e usado; no tester, `GpuEngineTester.dll`.
- Logs expoem o backend ativo (`service`, `tester`).
- Parametros de fallback existem apenas para compatibilidade — o fluxo oficial usa sempre o servico.

## Notas sobre agentes tester

- Diretorios fisicos: `AgentsFiles-to-tester_folder_terminals/<Vendor>/Agent-0.0.0.0-XXXX/MQL5/Libraries`.
- Consulte `docs/agents_tester_links.md` para passos completos.

## Observacoes finais

- Git guarda historico de `Dev/`; use `Versionamento/` apenas para snapshots manuais.
- Scripts anteriores (BuildGpuSuite, ManageGpuSetup, SetupLinks, etc.) estao arquivados em `Versionamento/scripts_legacy/`.

## MetaEditor After Compile

- Configure em *Tools -> Options -> General -> After compile run*: `powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "<repo>\WatchdogAfterCompile.ps1" "%path%"`.
- O script executa `WatchdogFiles_dev_to_runtime.py --apply --once`, garantindo que runtime e agentes recebam os artefatos apos cada compilacao.
