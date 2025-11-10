# SetupRuntimeLinks.ps1

## Propósito
- Cria links (junctions ou symlinks) das instalações MetaTrader locais para os arquivos em `Dev/`.
- Usa `links_config.json` como fonte de verdade, permitindo configurar múltiplos destinos (indicadores, experts, includes, DLLs, serviços).

## Fluxo
- Valida existência de `Dev/` (e `Dev/bin` para os binários) quando o modo é `Dev`.
- Carrega `links_config.json`; se ausente, gera template com exemplos e aborta.
- Para cada entrada (`Target`, `Source`, `Type`):
  - Constrói o caminho base de acordo com `-SourceMode`:
    - `Dev` (padrão): usa os caminhos `Dev\...` definidos no JSON.
    - `Runtime`: converte automaticamente o prefixo `Dev\` para `runtime\`.
    - `Custom`: exige `-CustomRoot` e aplica a mesma estrutura relativa de `Dev\` sobre o diretório informado.
  - Move o destino existente para backup (se for diretório físico) ou remove link antigo.
- Cria o link correspondente (`New-Item -ItemType Junction` para diretórios, `Copy-Item` para arquivos).
- Suporta múltiplas entradas por pasta (ex.: subdiretórios de `MQL5\Include`), permitindo
  mapear apenas partes específicas sem substituir o diretório inteiro do MetaTrader.
- `-DryRun` apenas relata operações sem executar.

## Modos suportados
- `-SourceMode Dev` — fluxo padrão (instâncias apontam para a árvore `Dev/`).
- `-SourceMode Runtime` — ideal para liberar `Dev/bin` durante testes que bloqueiam DLL.
- `-SourceMode Custom -CustomRoot <dir>` — reponta para um diretório arbitrário (usando a estrutura relativa de `Dev/`).

## Integração
- Deve ser executado após garantir que `Dev/` está atualizado (build + watchdog).
- Trabalha em conjunto com `WatchdogLinks_runtime_m5folders.py` para validar os links posteriormente.
- Inclua no `links_config.json` a junction `MQL5\Files\WaveSpecGPU\logs -> logs` para centralizar os registros gerados.
