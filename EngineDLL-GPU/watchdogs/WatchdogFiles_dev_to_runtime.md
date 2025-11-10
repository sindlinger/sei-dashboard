# WatchdogFiles_dev_to_runtime.py

## Propósito
- Monitora diferenças entre `Dev/` e `runtime/` (e entre `Dev/bin` e agentes) para manter os arquivos sincronizados.
- Pode operar apenas registrando mudanças ou copiando automaticamente do desenvolvimento para o runtime.

## Funcionamento
- Define pares (`WatchPair`) com origem, destino, extensões e modo recursivo:
  - `bin`, `indicators`, `experts`, `include`, `scripts`, além de cada pasta física em `AgentsFiles-to-tester_folder_terminals/`.
- `build_snapshot`/`build_target_snapshot` criam mapas com tamanho + mtime.
- `diff_snapshots` identifica arquivos novos/alterados/obsoletos, registrando notas.
- `copy_files` replica arquivos quando `--apply` está ativo.
- Laço principal (`run_watchdog`) executa avaliação contínua (`interval` configurável) ou única (`--once`).

## Opções
- `--root`: raiz do projeto. O default é detectado automaticamente (procura `links_config.json`
  subindo pastas) e cai na raiz do repositório WaveSpecGPU.
- `--interval`: segundos entre verificações (default 600; mínimo 5).
- `--once`: realiza uma verificação e encerra.
- `--apply`: copia arquivos novos/alterados do `Dev/` para o destino.
- `--quiet`: suprime logs de cópia quando `--apply` está ativo.

## Integração
- Invocado por `WatchdogAfterCompile.ps1` (com `--apply --once`) logo após compilações.
- É a ferramenta oficial para garantir que agentes recebam DLLs a partir da pasta física `AgentsFiles-to-tester_folder_terminals/`, respeitando o aviso sobre os agentes.
