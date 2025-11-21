# Pipeline de Extração SEI

## Estrutura geral
- **Fonte**: diretório `C:/Users/pichau/Downloads/DE/playwright-downloads` (um ZIP por processo administrativo do SEI/TJPB).
- Cada ZIP contém todo o histórico do processo administrativo: anexos PDF, laudos, certidões, despachos, documentos SIGHOP etc.
- Apenas alguns documentos de cada ZIP carregam os dados que precisamos (ex.: despacho "Assunto: Autorização de pagamento" ou certidão de laudo). Outros documentos são meramente processuais (\"Remetam-se os autos…\") e não devem apagar dados já coletados.
- Para reduzir processamento, cada documento é classificado em buckets (`principal`, `apoio`, `laudo`, `outro`). Processamos primeiro os `principais` e só abrimos os demais quando algum campo crítico permanece vazio (processo/partes → `apoio`, espécie/fator → `laudo`). Assim evitamos converter PDFs inúteis sem perder informações essenciais.
- Cada execução gera também `logs/<run-id>.sources.jsonl`, arquivo JSONL onde cada linha lista o ZIP processado, contagem de buckets usados, documentos de origem e os campos preenchidos (com snippet/pattern). Use esse arquivo para auditoria rápida sem abrir o Excel.
- Para separar fisicamente os documentos relevantes por processo, use `python -m seiautomation.offline.export_docs --sources logs/<run-id>.sources.jsonl --output ./docs_exportados --buckets principal apoio`. O comando extrai dos ZIPs apenas os arquivos marcados nos buckets informados e cria pastas `processo/bucket/arquivo`.

## Objetivo
- Preencher um relatório em Excel (`relatorio_pericias.xlsx`) com as colunas exigidas (processo judicial, partes, perito, valores, datas etc.).
- Gerar duas abas:
  - `Pericias`: todos os processos.
  - `Pendencias`: somente processos com algum campo crítico vazio para revisão manual.
- Gerar também a aba `Fontes`, que mapeia cada campo preenchido ao documento dentro do ZIP (facilita auditoria e permite reconstruir de onde veio cada informação).
- Gerar também um catálogo auxiliar (`peritos_catalogo.csv`) e manter a tabela oficial de honorários (`docs/tabela_honorarios.csv`).

## Regras principais de extração
1. **Filtragem por processo SEI**
   - O nome do ZIP define o número SEI esperado (ex.: `000219-17.2025.8.15`). Só aceitamos documentos que mencionem esse número ou que já estejam encadeados a um documento aprovado.
   - Se nenhum documento citar o processo correto deixamos todos os campos vazios e adicionamos `Sem documento compatível com o processo SEI` em `OBSERVACOES`.
   - Documentos rejeitados são listados (`"Documentos ignorados por divergência: ..."`) para facilitar auditoria.

2. **Iterar todos os documentos elegíveis**.
   - Prioridade: despachos completos com "Assunto: Autorização de pagamento", laudos assinados e certidões com o contexto do perito.
   - Documentos de encaminhamento não devem sobrescrever campos já preenchidos.

3. **Processo nº / Processo administrativo nº**
   - Capturar CNJ (`\d{7}-\d{2}.\d^{4}.\d.\d^{2}.\d^{4}`) e o número administrativo (que é o próprio número SEI). Para o administrativo aceitamos tanto o formato “novo” (`009889-67.2025.8.15`) quanto o legado (`2012.815`, `2015200000` etc.).
   - Se nenhum documento citar o SEI, usamos o número do próprio ZIP para preencher `PROCESSO ADMIN. Nº`, garantindo que o campo não fique vazio.
   - Quando há mais de um CNJ no mesmo ZIP, fazemos uma "votação": cada ocorrência ganha peso pelo número de vezes em que aparece e pela importância do documento (despachos/autorização valem mais do que certidões simples). O CNJ com maior pontuação vira o `PROCESSO Nº`; os demais são listados em `OBSERVACOES` como `CNJs adicionais mencionados: ...` para revisão manual.

4. **Promovente/Promovido**
   - Procurar padrões `"movido por ... em face de ..."` (agora cobrindo `de`, `da`, `do`, `dos`, `das`).
   - Fallback: linhas com `Autor`, `Requerente`, `Réu`, `Parte ré`, `Executado`.
   - Limpar CPF/CNPJ e símbolos e cortar trechos posteriores a `perante o Juízo...` antes de gravar o nome.

5. **Perito / CPF/CNPJ / Especialidade**
   - Qualquer linha contendo `"Interessad...: ... – Perito ..."` (funciona para “Interessado” ou “Interessada”) deve ser considerada o perito principal.
   - Aceitar tanto pessoa física quanto jurídica (CNPJ) – precisamos diferenciar quando o interessado é uma empresa (ex.: "Expertise Cálculos ...").
   - Se houver múltiplas linhas, manter a primeira que trouxer nome + CPF/CNPJ + especialidade.

6. **Valores (Valor Arbitrado, etc.)**
   - Procurar primeiro por rótulos (`"Valor arbitrado"`, `"Valor da perícia"`).
   - Caso não existam, pegar o primeiro `R$` associado ao trecho que menciona honorários/perito.
   - Preencher campo `R$` com o mesmo valor; campo `%` só se o texto trouxer explicitamente. Apenas o trecho `R$ ...` é armazenado (o restante do texto é descartado).

7. **Juízo / Comarca**
   - `Requerente: Juízo ...` é usado como fallback quando o despacho não traz o bloco formal do juízo.
   - A comarca é inferida automaticamente de qualquer trecho `Comarca de/da/do ...`, inclusive quando aparece dentro do próprio texto do juízo.

8. **Datas**
   - Tentar parser datas vizinhas a rótulos: "Data da requisição", "Data do adiantamento", "Data da autorização".
   - Se o rótulo não existir, buscamos datas nas primeiras páginas dos anexos: primeiro procuramos sequências como `Campina Grande, 09/11/2025` ou `João Pessoa – PB, 27 de maio de 2025`; depois varremos trechos próximos a `requisição/requerimento/solicitação`.
   - Caso nada seja encontrado, o campo permanece em branco para revisão manual.

9. **Observações**
   - Quando algum campo crítico (`Processo nº`, `Perito`, `Valor arbitrado`) não for localizado, adicionar `"Sem <campo>"` na coluna `OBSERVACOES`.
   - Esses registros aparecerão automaticamente na aba `Pendencias`.

10. **Tabela de honorários**
   - Referência oficial está em `docs/tabela_honorarios.csv` (área, descrição, ID, valor). Inclui o item adicional "Laudo grafotécnico" (R$ 300,00) conforme solicitado.

11. **Catálogo de peritos**
   - Script `python -m seiautomation.offline.build_peritos_catalog ...` percorre todos os ZIPs, coleta nome/CPF/especialidade e gera `peritos_catalogo.csv`. Serve apenas como referência manual.

## Fluxo padrão
1. **Atualizar dependências**: `pip install -r requirements.txt` (pdfplumber, BeautifulSoup, openpyxl, etc.).
2. **Gerar relatório completo**:
   ```bash
   python -m seiautomation.offline.extract_reports \
     --zip-dir "C:/Users/pichau/Downloads/DE/playwright-downloads" \
     --output relatorio_pericias.xlsx
   ```
   - Esse comando sobrescreve o arquivo, gera as duas abas e preenche `OBSERVACOES` com os campos faltantes.

3. **Opcional: processar lote de teste** (`--limit 10`) para validar uma mudança antes de rodar tudo.
4. **Gerar catálogo** (referência):
   ```bash
   python -m seiautomation.offline.build_peritos_catalog \
     --zip-dir "C:/Users/pichau/Downloads/DE/playwright-downloads" \
     --output peritos_catalogo.csv
   ```

5. **Onde ficam os arquivos**
   - `relatorio_pericias.xlsx` (raiz do repo): relatório principal.
   - `peritos_catalogo.csv` (raiz): catálogo de apoio.
   - `docs/tabela_honorarios.csv`: tabela oficial de valores.

## Futuras melhorias
- Mapear as 27 pendências atuais (especialmente `PROMOVIDO`, `VALOR ARBITRADO` e `PERITO`) e criar heurísticas específicas por tipo de documento (Despacho × Laudo × SIGHOP).
- Usar o catálogo de peritos para preencher CPF/CNPJ quando o despacho citar apenas o nome.
- Cruzar automaticamente com `docs/tabela_honorarios.csv` para sugerir `Fator`, `Valor Tabelado` e validar o `Valor Arbitrado`.
- Expor, além da aba `Fontes`, um relatório por processo listando qual documento/linha trouxe cada campo (facilita double-check manual).
