# Notas de Procedimento - Honorários Periciais

## Arbitramento DE vs CM
- **Valor Tabelado**: usar a tabela oficial (`docs/tabela_honorarios.csv`) como referência padrão. Esse valor representa o teto previsto na Resolução CNJ 232/2016.
- **Valor Arbitrado - DE**: preencher apenas com valores expressamente arbitrados em despachos da Diretoria Especial (DIESP). Se o despacho da DE trouxer tanto o valor quanto a data de autorização, guardar ambos aqui.
- **Valor Arbitrado - CM**: quando a matéria for encaminhada ao Conselho da Magistratura (CM) e a certidão/decisão do CM arbitrar um valor, registrar aqui. Este é o valor definitivo quando não houve arbitramento da DE.
- **Data do arbitramento**: deve refletir o ato que fixou o valor. Se o valor veio da DE, usar a data do despacho que autorizou a despesa. Se o valor veio do CM, usar a data da certidão do Conselho da Magistratura.
- **Preenchimento final**: o campo `VALOR ARBITRADO` geral é preenchido com o valor CM, se existente; caso contrário, com o valor DE. Assim fica evidente no relatório tanto a origem quanto o valor final aplicado.
- **Adiantamento/percentual**: só preencher quando o mesmo documento que arbitrou o valor mencionar pagamento antecipado. Despachos da DIESP definem o adiantamento da DE; certidões do Conselho (cabeçalho “Assessoria do Conselho da Magistratura … CERTIDÃO”) definem o adiantamento do CM. Pagamentos em parcela única deixam `DATA ADIANTAMENTO`, `CHECAGEM ADIANTAMENTO` e `%` em branco.

Essas regras servem para respaldar a extração automática e para futura conferência manual na GUI/planilha.

### Competências DE x CM
- A DIESP só arbitra valores até o teto da tabela CNJ/Res. 232. Sempre que o pedido ultrapassa esse limite, a decisão final (valor e eventual adiantamento) sai do Conselho da Magistratura. Por isso os campos “VALOR ARBITRADO – DE” e “VALOR ARBITRADO – CM” coexistem: o primeiro registra o valor autorizado dentro dos limites da DIESP e o segundo o valor definitivo informado na certidão do CM quando há extrapolação.

## Integridade das extrações
- O extrator **só** usa dados que constam no próprio ZIP/processo. Nada é inferido a partir de outros processos ou campos.
- Se não houver referência clara e específica no documento, o campo fica em branco e vai para revisão manual. “Preencher por preencher” é proibido.
- A aba **Candidatos** lista todas as extrações daquele processo (valor, fonte, snippet, peso) para facilitar auditoria e cálculo de confiança. Essas entradas são apenas evidências; o campo principal só recebe valores que tenham respaldo claro no documento.
- **Processo CNJ x Processo SEI**: o processo administrativo (SEI) não aparece na sentença judicial; o que consta na sentença é o processo CNJ. Portanto, os campos devem ser mantidos separados: `PROCESSO ADMIN. Nº` armazena o número SEI/ADM (derivado do próprio ZIP), e `PROCESSO Nº` guarda exclusivamente o CNJ onde a perícia foi realizada. Divergências entre eles geram observações.
- **Validação do CNJ**: o número CNJ tem estrutura fixa (NNNNNNN-DD.AAAA.J.TR.OOOO). Devemos validar cada parte (número sequencial, dígitos verificadores, ano, órgão julgador etc.) para garantir que apenas CNJs válidos sejam aceitos. Se o formato falhar ou o DV não bater, o campo `PROCESSO Nº` permanece em branco.
- **Glossário CNJ (resumo didático)**: o CNJ segue a Resolução 65. Estrutura: `NNNNNNN` (sequencial), `DD` (dígito verificador calculado pelo algoritmo Módulo 97), `AAAA` (ano), `J` (segmento do Judiciário), `TR` (código do tribunal) e `OOOO` (unidade de origem). Para validar: remova a pontuação, aplique o Módulo 97 progressivo (resíduo em cada concatenação) e aceite apenas se o resultado final for 1. Essa regra será detalhada em um glossário específico.

## Notas operacionais recentes (nov/2025)
- **Pasta padrão de downloads**: quando o usuário não indica ZIP/PDF, o CLI usa `SEI_DOWNLOAD_DIR` (ou `playwright-downloads` por default). A GUI deve apontar essa mesma pasta por padrão; outro diretório só se o usuário escolher explicitamente.
- **PROCESSO ADMIN. Nº (SEI)**:
  - Vem diretamente da lista de downloads (processo administrativo/SEI) e deve ser confiável. Formato atual: dígitos puros; aceitamos também o formato legado (ano + dígitos, ex.: 2002xxxx).
  - Se vazio ou em formato inconsistente, sinalizar para revisão; nunca substituir por CNJ.
- **PROCESSO Nº (CNJ)**:
  - Deve ser validado com regex + DV (Res. 65). Se inválido ou ausente, manter em branco.
  - Observações que citam “CNJs adicionais” devem ser registradas, mas não substituem o campo principal.
- **Espécie de perícia e campos textuais**:
  - Valores sujos vêm do regex em alguns casos (ex.: checkboxes “( ) Tradução ( ) Interpretação ( x ) Perícia”, frases truncadas). Antes de treinar/gerar dataset QA, limpar esses textos e descartar NaN.
  - Priorizar o arquivo mais recente (`relatorio-pericias.xlsx`, gerado em 20/11/2025) para servir de base; o arquivo de 11/11/2025 é mais antigo.
- **Modelo QA**:
  - Checkpoint local padrão em `ml/models/qa-xlm` (deepset/xlm-roberta-large-squad2). Tokenizer fast.
  - Se nada for informado, `--device 0` (GPU). CPU apenas com `--device -1`.
- **Inferência/CLI**:
  - Comandos offline usam a pasta padrão se nenhum ZIP/PDF for passado.
  - Para evitar interrupção, o pipeline QA agora usa tokenizer fast; se surgirem spans inválidos, avaliar proteção adicional ou pós-processamento manual.
