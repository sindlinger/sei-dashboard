# DevSync.ps1

## Propósito
- Copia a árvore `Dev/` para `runtime/`, opcionalmente realizando snapshot em `Versionamento/`.
- Facilita a preparação do runtime antes de criar links para terminais/agentes.

## Fluxo
- Verifica/gera diretórios `Dev/`, `runtime/` e `Versionamento/`.
- Se `-All` for usado, limpa `runtime/` antes de copiar todo o conteúdo de `Dev/`.
- `-DryRun` apenas exibe ações sem copiar.
- `-Snapshot` cria cópia adicional em `Versionamento/<timestamp>[_Label]`.

## Parâmetros
- `-All`: limpa `runtime/` antes da cópia.
- `-Snapshot`: gera snapshot em `Versionamento/`.
- `-Label`: sufixo opcional para identificar o snapshot.
- `-DryRun`: executa apenas verificações, sem copiar.

## Integração
- Chamado pela CLI (`GPUDevCLI.ps1`) e por pipelines manuais antes de `SetupRuntimeLinks.ps1`.
