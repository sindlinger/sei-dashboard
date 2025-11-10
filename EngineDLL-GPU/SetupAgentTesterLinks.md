# SetupAgentTesterLinks.ps1

## Propósito
- Cria junctions `MQL5\Libraries` dos agentes tester (MetaTrader 5 e Dukascopy) apontando para os binários em `AgentsFiles-to-tester_folder_terminals/`.
- Garante que os agentes usem os DLLs/LIBs corretos sem copiar arquivos diretamente para `%ProgramFiles%`.

## Fluxo
- Lista agentes predefinidos (`Agent-0.0.0.0-2000` … `2015` e equivalentes Dukascopy).
- Para cada agente:
  - Verifica existência do diretório físico do agente e da pasta fonte correspondente dentro de `AgentsFiles-to-tester_folder_terminals/`.
  - Remove links antigos ou move conteúdo real para backup.
  - Cria junction (`mklink /J`) `MQL5\Libraries -> <fonte>`.
- Emite mensagens `OK`, substituição ou avisos quando diretórios não existem.

## Integração
- Deve ser executado após `WatchdogFiles_dev_to_runtime.py --apply` para garantir que os agentes estejam sincronizados.
- Referencia explicitamente os caminhos físicos dos agentes conforme instruções de documentação (não usar `%APPDATA%\MetaQuotes\Terminal`).
