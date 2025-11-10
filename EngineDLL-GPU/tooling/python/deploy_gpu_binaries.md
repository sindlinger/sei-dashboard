# deploy_gpu_binaries.py

## Propósito
- Distribui os binários produzidos pelo build (DLLs/EXEs/LIBs) para os destinos oficiais da WaveSpecGPU.
- Suporta dois modos: verificação de links (modo padrão) e cópia forçada (`--force-copy`) para cenários legados.

## Fluxo
1. Identifica a raiz canônica (`bin/`) e promove arquivos de `bin/Release` (ou diretório informado).
2. Verifica a presença de todos os artefatos essenciais (`GpuEngine.dll`, `GpuEngineClient.dll`, `GpuEngineService.exe`, bibliotecas CUDA).
3. Se `--force-copy`:
   - Copia arquivos para `Libraries/` (MQL5), destinos extras e `AgentsFiles-to-tester_folder_terminals` (quando `--skip-agents` não é usado).
   - Executa verificação pós-cópia comparando tamanhos/mtimes.
4. Caso contrário, apenas checa se junctions/symlinks apontam para `bin/`, relatando problemas.

## Opções principais
- `--release-dir`: origem dos binários recém-compilados (default `bin/Release`).
- `--targets`: caminhos adicionais para cópia (válidos somente com `--force-copy`).
- `--skip-agents`: evita sincronizar pastas `Agent-*`.
- `--force-copy`: habilita cópia física em vez de validação de links.

## Integração
- Chamado por `build_and_deploy_gpu.py` após a compilação.
- Respeita a estrutura de agentes descrita em `docs/Documentation_Instructions.md` (usar `AgentsFiles-to-tester_folder_terminals/` como fonte oficial).
