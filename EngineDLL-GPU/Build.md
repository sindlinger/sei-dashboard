# Build.ps1

## Propósito
- Automatiza a configuração e compilação dos projetos CMake da WaveSpecGPU usando Visual Studio 2022 (x64).
- Valida a estrutura `Dev/` antes de iniciar e garante que `Dev/bin` receba os artefatos.

## Fluxo
- `Resolve-CMake` procura `cmake.exe` compatível com o gerador solicitado (via `vswhere`, PATH e caminhos padrão).
- Opcionalmente remove o diretório de build (`--Clean`).
- Executa `cmake -S . -B <BuildDir> -G "Visual Studio 17 2022" -A x64`, a menos que `--SkipConfigure` esteja ativo.
- Chama `cmake --build <BuildDir> --config <Configuration>` (Release por padrão).
- Após o build, confirma que `Dev/bin` foi criado e exibe mensagem final apontando os artefatos.

## Parâmetros
- `-BuildDir`: pasta do build (default `build_vs`).
- `-Configuration`: `Release` (default) ou `Debug`.
- `-Clean`: remove build anterior.
- `-SkipConfigure`: reutiliza cache existente.

## Integração
- Usado pela CLI (`GPUDevCLI.ps1`) para builds incremental/limpo.
- Deve ser executado antes de `SetupRuntimeLinks.ps1` para garantir binários atualizados.
