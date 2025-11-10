# RemoveLinks.ps1

## Propósito
- Remove links simbólicos/junctions dentro de um diretório, com opção recursiva.

## Funcionamento
- Resolve o caminho alvo (`-Path`) e coleta itens com atributo `ReparsePoint`.
- Exibe mensagens ao remover cada link; se nenhum for encontrado, informa e encerra.
- `-Recurse` permite varrer subdiretórios.

## Integração
- Utilizado pela CLI (`GPUDevCLI.ps1`, opção 7) para limpar links inválidos antes de recriá-los com outros scripts.
