# CheckLinks.ps1

## Propósito
- Scaneia um diretório (opcionalmente recursivo) em busca de links simbólicos ou junctions, exibindo metadados e status do alvo.

## Funcionamento
- Aceita filtros para incluir apenas arquivos (`-IncludeFiles`), apenas diretórios (`-IncludeDirectories`) ou ambos.
- Para cada item com atributo `ReparsePoint`, tenta descobrir `LinkType`, caminho alvo e se o destino existe.
- Exibe resultado em tabela (`Path`, `Type`, `LinkType`, `Target`, `Exists`), com opção de resumo agregado (`-Summary`).

## Parâmetros principais
- `-Path`: diretório base (default `.`).
- `-Recurse`: percorre subdiretórios.
- `-IncludeFiles` / `-IncludeDirectories`: restringem o tipo de item.
- `-Summary`: imprime contagem final de links encontrados/missing.

## Integração
- Utilizado por `GPUDevCLI.ps1` (opção Diagnóstico) para validar junctions após rodar scripts de setup.
