# WaveSpecGPU – Plano de Documentação Técnica

> **Aviso importantíssimo:** *Os agentes **NÃO** residem dentro das instâncias do MetaTrader (pasta `%APPDATA%\MetaQuotes\Terminal\<GUID>`).*  
> Os arquivos físicos dos agentes ficam em `WaveSpecGPU/AgentsFiles-to-tester_folder_terminals/` e os executáveis do MetaTrader (por exemplo, `C:\Program Files\MetaTrader 5\Tester\Agent-0.0.0.0-200X`).  
> Toda vez que um script mencionar agentes, valide se o alvo é um desses diretórios de executáveis – nunca a árvore da instância.

## Objetivo
Atribuir a um agente especialista a produção de documentação de referência para **todo** o código do projeto WaveSpecGPU.  
Cada arquivo-fonte deve possuir um arquivo `.md` homônimo (mesmo nome e pasta, apenas com a extensão alterada para `.md`), contendo:

- Descrição de alto nível (propósito geral, contexto no pipeline GPU/MetaTrader);
- Organização interna (principais classes, funções, estruturas, include/imports relevantes);
- Detalhes de integração com outros módulos (por ex. chamadas ao `GpuEngineClient`, scripts de watchdog, serviço Windows);
- Pontos de atenção conhecidos (requisitos de GPU, dependências externas, flags de compilação, etc.);
- Exemplos mínimos de uso quando fizer sentido (indicadores, scripts PowerShell, utilitários Python).

## Onde documentar
O especialista deverá atuar **no worktree `WaveSpecGPU_docs/`** recém-criado (`branch docs-documentation`).  
Para cada arquivo `Foo.ext` existir um `Foo.md` no mesmo diretório.  
Casos especiais:

- Arquivos binários ou gerados automaticamente **não** precisam de documentação.
- Diretórios com muitos arquivos correlatos (ex.: `Dev/src/engine_core/`) podem ganhar um `README.md` agregador adicional, mas isso **não** substitui os `.md` individuais.

## Visão geral do projeto (para orientar o especialista)

- `Dev/src/engine_core/` – código C++/CUDA que compila o `GpuEngine.dll` e `GpuEngineService.exe`.  
  - `CudaProcessor.cu`, `GpuEngineCore.cpp` e `exports.cpp` expõem a API consumida pelo cliente MQL5.
  - O CMake gera projetos Visual Studio; build padrão usa `Build.ps1`.

- `Dev/Indicators/GPU/` – indicadores MQL5 (WaveViz, PhaseViz, Hub, Solo, etc.) que chamam o cliente GPU.
  - Os indicadores **Solo** precisam funcionar sem o Hub; validem as chamadas diretas a `GpuEngineClient.dll`.
  - Arquivos complementares estão em `Dev/Include/GPU/` (estruturas, enums e helpers).

- `Dev/Experts/` e `Dev/Scripts/` – EAs e utilitários que também consomem o cliente GPU (ex.: `GPU_EngineHub.mq5`).

- `runtime/` – cópia sincronizada via `WatchdogFiles_dev_to_runtime.py`. É de onde as instâncias MetaTrader leem efetivamente os arquivos (juncionados por `SetupRuntimeLinks.ps1`).

- `AgentsFiles-to-tester_folder_terminals/` – 12 slots físicos de DLLs/LIBs usados por cada agente (`MetaTrader 5` e `Dukascopy MetaTrader 5`). Scripts importantes:
  - `SetupAgentTesterLinks.ps1` – cria as junctions dos agentes para os slots corretos.
  - `WatchdogLinks_runtime_m5folders.py` – garante que as instâncias apontem para `runtime/`.

- `GPUDevCLI.ps1` – CLI unificada com as opções realmente utilizadas:
  1. Pipeline completo (Build → Watchdog → Agentes)
  2. Build incremental
  3. Build limpo
  4. Watchdog Dev → runtime (`--apply --once`)
  5. Configurar agentes tester
  6. Corrigir links das instâncias
  7. Diagnóstico (`CheckLinks.ps1`)

## Fluxo sugerido para o especialista
1. Ler este documento para absorver o contexto e **respeitar o aviso sobre os agentes**.
2. Mapear todos os arquivos de código em `Dev/`, `runtime/`, `tooling/`, scripts `.ps1` e `.py`.
3. Criar as documentações `.md` diretamente na mesma pasta de cada arquivo.
4. Garantir que o conteúdo explique:
   - Papel na arquitetura (GPU Engine ↔ MetaTrader),
   - Dependências e contratos (parâmetros esperados, estruturas partilhadas),
   - Configuração necessária (por exemplo, execução como administrador, CUDA version, etc.).
5. Validar ortografia, tópicos e citações cruzadas (quando um arquivo depende de outro, linkar usando caminhos relativos).

## Entregáveis esperados
- Commit(s) no worktree `WaveSpecGPU_docs/` adicionando os `.md` homônimos.
- Opcionalmente, um `docs/Documentation-Index.md` com a tabela de conteúdos geral.
- Registro das dúvidas encontradas para eventual follow-up (pode ser um `TODO.md` na raiz).

## Contatos
- Em caso de incerteza sobre caminhos/junções, conferir `docs/agents_tester_links.md` e `README.md` atualizados na branch principal.
- Se o código depender de artefatos sincronizados (DLLs, LIBs), consultar `Build.ps1` e `WatchdogFiles_dev_to_runtime.py` para entender o pipeline.

Boa documentação!
