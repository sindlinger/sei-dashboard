# WatchdogLinks_runtime_m5folders.py

## Propósito
- Valida e (opcionalmente) corrige links/junctions das instâncias MetaTrader que devem apontar para a árvore `Dev/`.
- Garante que bibliotecas, includes, indicadores, experts e scripts carregados pelos terminais sejam a versão sincronizada.

## Funcionamento
- Aplica `DEFAULT_LINKS` (bibliotecas, indicadores, experts, scripts e subpastas de
  include do WaveSpecGPU) ou uma lista custom via `--links`.
- Descobre GUIDs de terminais em `%APPDATA%\MetaQuotes\Terminal` (ou raiz alternativa `--root`).
- `check_link` verifica existência, tipo (symlink/junction) e destino esperado (dentro de `Dev/`).
- Com `--fix`, remove conteúdos físicos ou links antigos e cria junctions (`mklink /J`) ou symlinks (em ambientes não Windows).

## Argumentos principais
- `--root`: diretório contendo os GUIDs dos terminais.
- `--source`: raiz da árvore `Dev/` usada como origem dos links.
- `--guid`: restringe a verificação a uma instância específica.
- `--links`: permite sobrescrever os alvos padrão (`relative_path=dev_path`).
- `--fix`: tenta ajustar automaticamente links ausentes ou incorretos.

## Integração
- Chamado pelo menu `GPUDevCLI.ps1` (opções de diagnóstico e correção).
- Deve ser executado sempre que `SetupRuntimeLinks.ps1` ou `DevSync.ps1` promove novos arquivos para o terminal, garantindo que os terminais apontem para a árvore correta (nunca `%APPDATA%\MetaQuotes\Terminal\<GUID>` diretamente).
