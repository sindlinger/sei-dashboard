# Pipeline de Extração SEI

## Estrutura geral
- **Fonte**: diretório `C:/Users/pichau/Downloads/DE/playwright-downloads` (um ZIP por processo administrativo do SEI/TJPB).
- Cada ZIP contém todo o histórico do processo administrativo: anexos PDF, laudos, certidões, despachos, documentos SIGHOP etc.
- Apenas alguns documentos de cada ZIP carregam os dados que precisamos (ex.: despacho "Assunto: Autorização de pagamento" ou certidão de laudo). Outros documentos são meramente processuais (\"Remetam-se os autos…\") e não devem apagar dados já coletados.

## Objetivo
- Preencher um relatório em Excel (`relatorio_pericias.xlsx`) com as colunas exigidas (processo judicial, partes, perito, valores, datas etc.).
- Gerar duas abas:
  - `Pericias`: todos os processos.
  - `Pendencias`: somente processos com algum campo crítico vazio para revisão manual.
- Gerar também um catálogo auxiliar (`peritos_catalogo.csv`) e manter a tabela oficial de honorários (`docs/tabela_honorarios.csv`).

## Regras principais de extração
1. **Iterar todos os documentos do ZIP**.
   - Prioridade: despachos completos com "Assunto: Autorização de pagamento", laudos assinados e certidões que contêm o contexto do perito.
   - Documentos de encaminhamento não devem sobrescrever campos já preenchidos.

2. **Processo nº / Processo administrativo nº**
   - Capturar CNJ (`\d{7}-\d{2}.\d{4}.\d.\d{2}.\d{4}`) e o número administrativo (ex.: `2020153102`).
   - Se múltiplos CNJs forem citados em um mesmo ZIP, manter aquele que aparece nos documentos com valor/perito.

3. **Promovente/Promovido**
   - Procurar padrões `"movido por ... em face de ..."`.
   - Fallback: linhas com `Autor`, `Requerente`, `Réu`, `Parte ré`, `Executado`.
   - Limpar CPF/CNPJ e símbolos antes de gravar o nome.

4. **Perito / CPF/CNPJ / Especialidade**
   - Qualquer linha contendo `"Interessado: ... – Perito ..."` deve ser considerada o perito principal.
   - Aceitar tanto pessoa física quanto jurídica (CNPJ) – precisamos diferenciar quando o interessado é uma empresa (ex.: "Expertise Cálculos ...").
   - Se houver múltiplas linhas, manter a primeira que trouxer nome + CPF/CNPJ + especialidade.

5. **Valores (Valor Arbitrado, etc.)**
   - Procurar primeiro por rótulos (`"Valor arbitrado"`, `"Valor da perícia"`).
   - Caso não existam, pegar o primeiro `R$` associado ao trecho que menciona honorários/perito.
   - Preencher campo `R$` com o mesmo valor; campo `%` só se o texto trouxer explicitamente.

6. **Datas**
   - Tentar parser datas vizinhas a rótulos: "Data da requisição", "Data do adiantamento", "Data da autorização". Caso não existam, deixar em branco.

7. **Observações**
   - Quando algum campo crítico (`Processo nº`, `Perito`, `Valor arbitrado`) não for localizado, adicionar `"Sem <campo>"` na coluna `OBSERVACOES`.
   - Esses registros aparecerão automaticamente na aba `Pendencias`.

8. **Tabela de honorários**
   - Referência oficial está em `docs/tabela_honorarios.csv` (área, descrição, ID, valor). Inclui o item adicional "Laudo grafotécnico" (R$ 300,00) conforme solicitado.

9. **Catálogo de peritos**
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
- Detectar automaticamente o documento completo dentro do ZIP (por exemplo, o despacho com "Assunto: Autorização"), evitando que documentos simples ("Remetam-se...") deixem o processo como vazio.
- Diferenciar pessoa física vs. jurídica no campo de perito (CPF × CNPJ) dependendo do tipo de interessado.
- Extrair datas e dados bancários quando disponíveis em anexos específicos.
- Cruzar automaticamente com a tabela de honorários para sugerir o valor padrão por especialidade.
