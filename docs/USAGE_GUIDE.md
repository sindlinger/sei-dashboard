# Guia de Uso e Refinamento

Este guia resume como navegar pelo projeto `sei-dashboard`, quais modos de execução estão disponíveis e como refinar os campos extraídos quando algo ficar em branco ou vier com "lixo" textual.

## Visão geral

| Componente | Função |
| --- | --- |
| `main.py` (PySide6) | Interface gráfica para selecionar tarefas (download/listagem/anotação) e inserir credenciais manualmente. |
| `cli` | CLI headless para scripts agendados/CI (`python -m cli ...`). |
| `seiautomation/offline` | Ferramentas offline (`extract_reports.py` e `build_peritos_catalog.py`) para trabalhar apenas com os ZIPs já baixados. |
| `docs/PROCESSO_SEI_PIPELINE.md` | Detalha as regras de extração e o pipeline da planilha. |
| `docs/tabela_honorarios.csv` | Tabela de referência (área, espécie, ID, valor) – inclui o item “Laudo grafotécnico”. |

Diretórios auxiliares como `EngineDLL-GPU`, `tmp`, `Versionamento` não fazem parte do programa e podem ser ignorados.

## Modos de execução

### GUI (PySide6)
1. Ative o ambiente virtual e instale dependências (`pip install -r requirements.txt` + `playwright install chromium`).
2. Rode `python main.py` a partir de `/mnt/b/dev/sei-dashboard` (ou o diretório onde estiver o repo). A janela traz:
   - Campos para credenciais (não precisa salvá-las no `.env`).
   - Checkboxes para `download`, `annotate`, `list` e opção de rodar headless.
   - Painel de contadores + filtros rápidos (pendentes, com/sem ZIP).
3. Clique **Executar** para iniciar a tarefa escolhida. Logs aparecem no rodapé; a janela pode ir para a bandeja.

### CLI (headless)
Agrupamos os comandos por fluxo:

```bash
python -m cli online baixar --limit 20 --no-headless --username 00000000000 --password ******
python -m cli online ok
python -m cli online painel --pending-only --summary
python -m cli offline relatorio --zip-dir /mnt/b/dev/playwright-downloads --full
python -m cli offline match --zip playwright-downloads/000219_17_2025_8_15_SEI_000219_17.2025.8.15.zip --fields PROMOVENTE PROMOVIDO
```

- `online baixar` → baixa/atualiza ZIPs (`--limit`, `--force`, `--no-headless`, `--no-auto-credentials`).
- `online ok` → automatiza a anotação “OK”.
- `online painel` → lista ou resume os processos (`--pending-only`, `--ok-only`, `--only-downloaded`, `--only-missing-zip`, `--summary`).
- `offline relatorio/qa/logs` → reutilizam exatamente os mesmos flags descritos no README (ZIP/PDF dir, workers, limpeza de logs, etc.).
- `offline match` → compara regex × QA diretamente no terminal, exibindo as fontes e os scores para cada campo solicitado.
- Rode `python -m cli exemplos` para ver o mosaico completo de comandos.

### Docker
1. Copie `.env.example` para `.env` e preencha as variáveis.
2. `docker build -t seiautomation .`
3. Execute montando a pasta de downloads para persistir os arquivos:
   ```bash
   docker run --rm --env-file .env \
     -v "$(pwd)/playwright-downloads:/app/playwright-downloads" \
     seiautomation online baixar
   docker run --rm --env-file .env \
     -v "$(pwd)/playwright-downloads:/app/playwright-downloads" \
     seiautomation online ok
   ```
4. Acrescente parâmetros extra exatamente como na CLI (`--limit`, `--force`, `--no-headless`, etc.).

### Backend/API
O diretório `backend` expõe uma API FastAPI (`uvicorn backend.app.main:app --reload`). Consulte o README para criar usuários e disparar tarefas via HTTP quando precisar integrar com outros sistemas.

## Extração offline & relatórios

1. Garanta que os ZIPs do SEI estejam em `C:/Users/<usuário>/Downloads/DE/playwright-downloads` (ou ajuste o caminho).
2. Rode:
   ```bash
   python -m seiautomation.offline.extract_reports \
     --zip-dir "C:/Users/pichau/Downloads/DE/playwright-downloads" \
     --output relatorio_pericias.xlsx
   ```
3. O Excel gerado contém:
   - Aba `Pericias`: dados consolidados.
   - Aba `Pendencias`: entradas com algum campo crítico vazio.
   - Aba `Fontes`: para cada campo preenchido, qual documento foi responsável.

A planilha lista observações como `Sem PROCESSO Nº` ou `Documentos ignorados por divergência: ...` sempre que algo precisa de revisão manual.

### Catálogo de peritos

```bash
python -m seiautomation.offline.build_peritos_catalog \
  --zip-dir "C:/Users/pichau/Downloads/DE/playwright-downloads" \
  --output peritos_catalogo.csv
```

O CSV ajuda a conferir nome + CPF/CNPJ + especialidade para preencher lacunas na planilha.

## Refinamento de campos

Use as heurísticas abaixo quando algum campo estiver vazio ou com “lixo” textual. As referências citadas estão em `docs/PROCESSO_SEI_PIPELINE.md`.

| Campo | Onde procurar primeiro | Limpeza automática | Ações manuais sugeridas |
| --- | --- | --- | --- |
| Processo SEI (adm.) | Nome do ZIP e cabeçalho dos despachos | Números como `009889-67-.2025.8.15` são normalizados (removendo hífens extras). | Se nenhum anexo citar o SEI, marque para rebaixar o processo direto do SEI e confirmar o despacho correto. |
| Processo judicial (CNJ) | Trechos “Processo nº … movido por …” | Votação por frequência + peso dos documentos. CNJs adicionais aparecem em `OBSERVACOES`. | Se o principal estiver errado, abra a aba `Fontes` para ver qual documento forneceu o valor e corrija manualmente. |
| Promovente / Promovido | Padrão “movido por … em face de …” | Remove CPF/CNPJ e corta antes de “perante/juízo/comarca”. | Quando o despacho não cita, procure nos laudos ou nos documentos SIGHOP dentro do ZIP. |
| Perito + CPF/CNPJ | Linha “Interessado: … – Perito …” ou blocos com “Perito … CPF …” | Só aceita linhas com “Interessad*/Perito”. Arquivos como “08 Laudo …” ficam marcados em `OBSERVACOES`. | Se faltar CPF, consulte `peritos_catalogo.csv` para completar; se houver múltiplos peritos, mantenha o documento mais recente. |
| Especialidade | Mesma linha do interessado ou rótulo “Especialidade: …” | A parte após o primeiro hífen é usada como especialidade. | Validar com a tabela de honorários (`docs/tabela_honorarios.csv`) quando precisar sugerir o fator/valor padrão. |
| Valor arbitrado | Rótulos “Valor arbitrado”, “honorários”, “Valor da perícia” | Extrai apenas o `R$` e descarta o texto restante. | Se o despacho não trouxer o valor final (casos iniciais), deixe em branco e registre “valor não informado” na revisão manual. |
| Juízo / Comarca | Cabeçalho do despacho ou trechos “Juízo da …” | Normaliza variações como “Juízo da 1 3 ª Vara …”. | Para certidões que não citam o juízo, use o despacho anterior dentro do mesmo ZIP. |

### Rastreamento de fontes
Sempre que tiver dúvida, abra o Excel e vá à aba `Fontes`. Ela informa: número da linha (`Nº DE PERÍCIAS`), campo, valor e documento de origem. Assim você sabe em qual PDF/HTML procurar o trecho real.

## Boas práticas
- Mantenha os ZIPs organizados por processo (um ZIP por pasta) apenas para conferência manual; o extrator já valida o SEI antes de aceitar qualquer documento.
- Registre no `OBSERVACOES` o motivo de cada falta (“Sem PERITO”, “CNJs adicionais …”) para que outra pessoa ou IA saiba por que aquele campo ficou vazio.
- Sempre que ajustar regex/heurísticas, rode `python -m seiautomation.offline.extract_reports --limit 5` para garantir que os casos problemáticos foram resolvidos antes do processamento completo.

## Links úteis
- [Pipeline de extração detalhado](./PROCESSO_SEI_PIPELINE.md)
- [Tabela de honorários](./tabela_honorarios.csv)
- [README (instalação e CLI)](../README.md)
