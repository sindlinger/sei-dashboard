# SEIAutomation

Automação das tarefas repetitivas no SEI/TJPB. O projeto fornece:

1. **Scripts reutilizáveis**
   - Download dos processos do bloco interno configurado (ex.: *Peritos – bloco 55*) em formato ZIP.
   - Preenchimento automático do campo "Anotações" com o texto **OK** nos processos que ainda não possuem esse status.

2. **Aplicativo com interface (PySide6)**
   - Ícone na bandeja do sistema.
   - Janela simples com checkboxes para escolher quais tarefas executar e se o navegador roda em modo headless.

Compatível com Windows e WSL (necessário Python 3.10+).

---

## Instalação

1. **Criar e ativar um ambiente virtual (recomendado)**

```bash
python -m venv .venv
source .venv/bin/activate        # Linux/WSL
.venv\Scripts\activate           # Windows
```

2. **Instalar dependências**

```bash
pip install -r requirements.txt
playwright install chromium
```

3. **Configurar variáveis**

Copie `.env.example` para `.env` e informe usuário/senha:

```
SEI_USERNAME=00000000000
SEI_PASSWORD=sua_senha
SEI_BLOCO_ID=55
SEI_DOWNLOAD_DIR=playwright-downloads
SEI_BASE_URL=https://sei.tjpb.jus.br/sei/
```

> Se preferir não salvar as credenciais no disco, deixe `SEI_USERNAME`/`SEI_PASSWORD` vazios e informe-os diretamente na GUI ou na CLI (novas opções abaixo).

---

## Uso dos scripts

Você pode chamar as funções diretamente em Python:

```python
from seiautomation.config import Settings
from seiautomation.tasks import download_zip_lote, preencher_anotacoes_ok, listar_processos

settings = Settings.load()

# Baixa todos os ZIPs (ignora os que já existem)
download_zip_lote(settings, headless=True)

# Preenche anotações com "OK"
preencher_anotacoes_ok(settings, headless=False)

# Apenas lista (sem baixar/alterar) e devolve as linhas encontradas
resultado = listar_processos(settings, headless=True)
print(f"Total na pasta: {resultado.resumo.total}")
for processo in resultado.processos:
    print(processo.numero, processo.anotacao, "ZIP salvo?", processo.baixado)
```

`headless=True` executa sem abrir a janela do navegador. Há também o parâmetro `auto_credentials` para controlar o preenchimento automático de login (a interface traz uma caixa de seleção específica para isso).

---

## Aplicativo gráfico

Para abrir a interface (com bandeja do sistema):

```bash
python main.py
```

Selecione as tarefas desejadas (baixar ZIPs, preencher anotações ou apenas listar processos), escolha se o navegador deve ser headless e clique em **Executar**. Logs aparecem em tempo real com o total de registros, e a janela pode ser minimizada para o tray.

Além dos botões principais, a janela traz:

- Grupo "Credenciais do SEI" para preencher usuário (CPF) e senha dinamicamente.
- Painel de contadores (Total, OK, Pendentes, ZIPs salvos e Sem ZIP) atualizado automaticamente quando a tarefa "Listar" é executada ou manualmente pelo botão **Atualizar painel** — ideal para consultar o status da pasta antes de decidir a ação.
- Grupo "Filtros da listagem" com combos para mostrar apenas pendentes/OK e apenas processos com ou sem ZIP; ao rodar a listagem pela GUI os filtros são respeitados, enquanto o botão **Atualizar painel** ignora os filtros para refletir o estado geral da pasta.

---

## Gerar executável (opcional)

Requer [PyInstaller](https://pyinstaller.org/):

```bash
pip install pyinstaller
pyinstaller --noconfirm --windowed --onefile main.py
```

O executável ficará em `dist/main.exe`.

---

## Integração com automações futuras

Os módulos estão organizados para permitir inclusão de novas tarefas. Cada rotina deve receber um objeto `Settings` e uma função de `progress` opcional, garantindo que possam ser reutilizadas tanto pelos scripts quanto pela GUI ou qualquer outro orquestrador (por exemplo, chamadas via Docker/MCP/Codex CLI).

---

## CLI headless

Para automatizar sem interface (ideal em servidores/CI), use `python -m cli <grupo> <comando>`. Rode `python -m cli exemplos` (ou `help-exemplo`) para ver um “cheat sheet” pronto. Exemplos práticos:

```bash
python -m cli online baixar --limit 20 --no-headless
python -m cli online ok
python -m cli online painel --pending-only --summary
python -m cli offline relatorio --zip-dir /mnt/b/dev/playwright-downloads --pdf-dir /mnt/b/dev/pdfs --full
python -m cli offline qa --fields PROMOVENTE PROMOVIDO --zip-dir /mnt/b/dev/playwright-downloads --output qa.json
python -m cli offline match --zip playwright-downloads/000219_17_2025_8_15_SEI_000219_17.2025.8.15.zip --fields PROMOVENTE PROMOVIDO
python -m cli offline logs --limit 5 --show extract-20251119-101530-ab12 --tail 50
```

Principais opções:

- `online baixar` baixa/atualiza ZIPs. Use `--limit` para lotes pequenos, `--force` para rebaixar arquivos existentes, `--no-headless` para ver o navegador e `--no-auto-credentials` se quiser digitar login/senha manualmente.
- `online ok` replica a automação de anotar “OK”. Herdam as mesmas flags de headless/auto-login.
- `online painel` mostra a lista ou apenas o painel (`--summary`). Filtros: `--pending-only`, `--ok-only`, `--only-downloaded`, `--only-missing-zip`, além de `--limit` para cortar a listagem.
- `offline relatorio` chama `extract_reports.py`. Combine `--zip-dir`, `--pdf-dir`, `--txt-dir`, `--output`, `--limit`, `--workers` e `--full` (para reprocessar tudo em vez de pular linhas já presentes).
- `offline qa` roda o modelo de Perguntas & Respostas. Flags: `--zip/--zip-dir`, `--pdf/--pdf-dir`, `--limit`, `--fields`, `--max-per-field`, `--min-score`, `--model`, `--workers`, `--batch-size`, `--device`, `--output`, `--verbose`. PDFs “consolidados” passam automaticamente pelo mesmo particionamento em “Documento 1/2/…” usado nos ZIPs.
- `offline match` usa o mesmo pré-processamento e imprime no terminal os valores encontrados via regex + QA para cada campo (útil para revisões rápidas sem abrir o Excel). Aceita as mesmas flags de seleção (`--zip/--zip-dir/--pdf/--pdf-dir`, `--limit`, `--fields`, `--device`, `--min-score`).
- `offline logs` lista execuções recentes (`--limit`), abre um log específico (`--show` + `--tail`), exibe checkpoints (`--checkpoint`) e aplica limpeza (`--clean-days`, `--clean-size`).
- Flags globais `--username` / `--password` permitem sobrescrever o `.env` apenas naquela execução.

---

## Extração offline de despachos e geração de Excel

Quando os processos já estiverem baixados em ZIP (ex.: `C:\\Users\\pichau\\Downloads\\DE\\playwright-downloads`), execute:

```bash
python -m seiautomation.offline.extract_reports \\n  --zip-dir "C:/Users/pichau/Downloads/DE/playwright-downloads" \\n  --pdf-dir "C:/Users/pichau/Desktop/geral_pdf/pdf_cache" \\n  --output relatorio-pericias.xlsx
```

Use `--pdf-dir`/`--txt-dir` (podem ser repetidos) para apontar pastas extras; o script empacota cada arquivo temporariamente e descarta em seguida, sem duplicar o acervo. Quando encontra PDFs consolidados (aqueles exportados com vários “Documento X” dentro), o utilitário agora separa automaticamente cada trecho antes de aplicar as heurísticas, como se fossem arquivos individuais do ZIP. Além disso, `--skip-existing` faz o script ler o arquivo atual, pular os registros que já estão na aba **Pericias** e acrescentar apenas os novos, preservando “Pendencias” e “Fontes”.

Se quiser copiar apenas os documentos relevantes por processo/bucket, execute depois:

```bash
python -m seiautomation.offline.export_docs \
  --sources logs/<run-id>.sources.jsonl \
  --output ./docs_exportados \
  --buckets principal apoio
```
Isso extrai dos ZIPs somente os arquivos aceitos nos buckets informados e organiza em `processo/bucket/arquivo`. 

Cada execução gera um `run-id` (ex.: `extract-20251119-101530-ab12`) gravado em `logs/`. Use `--run-id` para definir o identificador manualmente ou `--resume <run-id>` para continuar de onde parou (o script mantém checkpoints incrementais e salva a planilha a cada lote de registros). O parâmetro `--checkpoint-interval` controla quantos arquivos são processados antes de salvar novamente (default: 25).

O utilitário identifica o documento de despacho (e complementa com PDFs anexos quando necessário) e tenta preencher automaticamente as colunas da planilha:

- nº de perícias (numeração sequencial), datas (requisição, adiantamento, autorização) e processos (administrativo e judicial)
- juízo, comarca, promovente, promovido, perito, CPF/CNPJ, especialidade, espécie da perícia
- fator, valores tabelado/arbitrado, checagens e saldo a receber

Campos não encontrados permanecem em branco e recebem a observação “Sem …” para facilitar a revisão manual. Use `--limit 10` para processar apenas alguns ZIPs durante testes.

> Referência de valores: a tabela oficial de honorários (área, espécie e valor) está em `docs/tabela_honorarios.csv`, já incluindo o item extra “Laudo grafotécnico” solicitado.

Para uma visão completa do pipeline e das heurísticas de limpeza/validação (inclusive como usar a aba `Fontes` para rastrear cada campo), consulte também:

- `docs/PROCESSO_SEI_PIPELINE.md` – regras detalhadas de extração e pendências mais comuns.
- `docs/USAGE_GUIDE.md` – tutorial passo a passo cobrindo GUI, CLI, Docker e dicas para refinar os campos da planilha.

---

## Catálogo de peritos (referência)

Para montar um arquivo auxiliar com nome, CPF/CNPJ e especialidade dos peritos encontrados nos ZIPs, rode:

```bash
python -m seiautomation.offline.build_peritos_catalog \
  --zip-dir "C:/Users/pichau/Downloads/DE/playwright-downloads" \
  --output peritos_catalogo.csv
```

O CSV resultante não é usado automaticamente pela planilha, mas serve como apoio para revisar dados faltantes e checar inconsistências. Você pode reaproveitá-lo em planilhas auxiliares ou em consultas rápidas.

---

## Execução via Docker

Containerizar o projeto garante que dependências (Playwright, PySide6, backend) fiquem replicáveis.

1. **Copie o `.env.example` para `.env`** e ajuste as variáveis (credenciais, bloco, pasta de downloads etc.).
2. **Monte a imagem:**

   ```bash
   docker build -t seiautomation .
   ```

3. **Execute montando a pasta de downloads para persistir os ZIPs:**

   ```bash
  docker run --rm \
    --env-file .env \
    -v "$(pwd)/playwright-downloads:/app/playwright-downloads" \
    seiautomation online baixar
   ```

   Troque o último argumento para `annotate` (ou adicione ambos) conforme a tarefa desejada:

   ```bash
  docker run --rm --env-file .env \
    -v "$(pwd)/playwright-downloads:/app/playwright-downloads" \
    seiautomation online baixar
  docker run --rm --env-file .env \
    -v "$(pwd)/playwright-downloads:/app/playwright-downloads" \
    seiautomation online ok
   ```

   Para apenas consultar a fila (lista + totais) sem baixar nada:

   ```bash
  docker run --rm --env-file .env seiautomation online painel --summary
   ```

4. **Personalize opções** passando os mesmos parâmetros da CLI, por exemplo:

   ```bash
  docker run --rm --env-file .env \
    -v "$(pwd)/playwright-downloads:/app/playwright-downloads" \
    seiautomation online baixar --limit 10 --force
   ```

Observações:

- O container já inclui o Playwright com Chromium (`mcr.microsoft.com/playwright/python`).
- `SEI_DOWNLOAD_DIR` deve apontar para `playwright-downloads` (padrão) para que o volume montado seja usado.
- A GUI PySide6 continua disponível fora do container (`python main.py`) caso deseje rodar localmente.

---

## Backend API (FastAPI)

O diretório `backend/app` contém uma API que expõe autenticação, catálogo de tarefas e execução assíncrona.

### Instalação

```bash
pip install -r requirements.txt
playwright install chromium      # necessário para as tarefas reutilizadas
```

Defina no `.env` os valores:

```
APP_DATABASE_URL=sqlite:///./seiautomation.db
APP_JWT_SECRET=troque_esta_chave
APP_JWT_EXPIRES_MINUTES=120
```

Crie o primeiro administrador:

```bash
python -m backend.app.manage create-admin --email admin@exemplo.com
```

### Execução

```bash
uvicorn backend.app.main:app --reload
```

Rotas principais:

- `POST /auth/login` – retorna JWT.
- `GET /tasks/` – lista tarefas disponíveis.
- `POST /tasks/run` – dispara uma execução (necessita token).
- `GET /tasks/runs` – histórico do usuário (ou de todos, se admin).

As execuções reutilizam `seiautomation.tasks` e respeitam as permissões `allow_auto_credentials` dos usuários.
