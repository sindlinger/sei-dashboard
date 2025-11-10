# build_and_deploy_gpu.py

## Propósito
- Executa o pipeline completo de build + deploy da WaveSpecGPU em uma única chamada.
- Pode rodar tanto em Windows quanto no WSL; utiliza CMake para gerar artefatos e, em seguida, chama `deploy_gpu_binaries.py`.

## Fluxo principal
1. Resolve a raiz do projeto (`WaveSpecGPU/`) e cria `build/` se necessário.
2. Opcionalmente roda `cmake -S … -B …` com gerador/define/toolset especificados.
3. Executa `cmake --build` na configuração desejada (`Release` por padrão).
4. Aciona `deploy_gpu_binaries.main()` para promover binários para `bin/<config>` e sincronizar destinos adicionais/agentes.

## Argumentos relevantes
- `--configuration`: `Release` (default) ou `Debug`.
- `--generator` / `--toolset`: controlam o gerador CMake (Visual Studio 2022 por default) e toolset (ex.: `v143`).
- `--define`: múltiplas definições extras para `cmake -D`.
- `--target`: compila apenas um target específico.
- `--skip-configure`, `--skip-build`, `--skip-deploy`: pulam etapas do pipeline.
- `--skip-agents`: evita sincronizar agentes na etapa de deploy.
- `--extra-target`: diretórios adicionais para receber DLLs durante o deploy.
- `--no-color`: desabilita mensagens ANSI.

## Integração
- Pressupõe que os projetos CMake (`Dev/src/...`) estejam configurados conforme os arquivos desta árvore.
- Utilizado pelos scripts PowerShell (`GPUDevCLI.ps1`, `WatchdogAfterCompile.ps1`) como backend Python para automatizar builds.
