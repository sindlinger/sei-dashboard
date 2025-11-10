# WatchdogAfterCompile.ps1

## Propósito
- Gancho pós-compilação que sincroniza `Dev/` → `runtime/` (e agentes) automaticamente após um build bem-sucedido.

## Funcionamento
- Resolve executável Python (`python`/`python3`).
- Executa `watchdogs/WatchdogFiles_dev_to_runtime.py --apply --once --quiet`.
- Loga arquivo recém-compilado (`-CompiledFile`) se informado.
- Em caso de erro, emite `Write-Warning` e retorna código 1.

## Integração
- Pode ser configurado como pós-build event em projetos Visual Studio ou integrado a pipelines para garantir runtime atualizado imediatamente após o build.
