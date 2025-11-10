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
SEI_IS_ADMIN=false
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

`headless=True` executa sem abrir a janela do navegador. Há também o parâmetro `auto_credentials` para desabilitar o preenchimento automático de login (a interface só habilita essa opção para administradores – `SEI_IS_ADMIN=true`).

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

Para automatizar sem interface (ideal em servidores/CI), use o módulo `seiautomation.cli`:

```bash
python -m seiautomation.cli list
python -m seiautomation.cli download annotate --limit 20 --no-skip-existing
```

Argumentos úteis:

- `download`, `annotate` e `list` podem ser combinados; execute apenas o que precisar.
- `list` gera apenas o relatório dos processos (detalhes + totais) sem baixar/alterar nada.
- `--pending-only`, `--ok-only` filtram por anotação; `--only-downloaded` e `--only-missing-zip` filtram pelo status do ZIP armazenado.
- `--summary-only` mostra apenas o painel (sem linhas individuais) – útil para checagens rápidas no terminal/CI.
- `--no-headless` exibe o navegador (se houver ambiente gráfico disponível).
- `--limit` restringe quantos protocolos serão processados no download (ajuda em testes).
- `--no-skip-existing` força o re-download dos ZIPs que já existem em `SEI_DOWNLOAD_DIR`.
- `--auto-credentials/--no-auto-credentials` sobrescrevem a regra padrão (usar auto-preenchimento apenas se `SEI_IS_ADMIN=true`).
- `--username` / `--password` permitem informar as credenciais apenas para a execução corrente (sobrescrevem o `.env`).

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
     seiautomation download
   ```

   Troque o último argumento para `annotate` (ou adicione ambos) conforme a tarefa desejada:

   ```bash
   docker run --rm --env-file .env \
     -v "$(pwd)/playwright-downloads:/app/playwright-downloads" \
     seiautomation download annotate
   ```

   Para apenas consultar a fila (lista + totais) sem baixar nada:

   ```bash
   docker run --rm --env-file .env seiautomation list --summary-only
   ```

4. **Personalize opções** passando os mesmos parâmetros da CLI, por exemplo:

   ```bash
   docker run --rm --env-file .env \
     -v "$(pwd)/playwright-downloads:/app/playwright-downloads" \
     seiautomation download --limit 10 --no-skip-existing
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
