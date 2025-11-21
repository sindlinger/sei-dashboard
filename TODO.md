# SEIAutomation – Próximas tarefas

## Registrar histórico de processos no banco
- **Objetivo**: Persistir no banco (SQLite por enquanto) cada ação realizada sobre um processo – download de ZIP, extração de PDF, anotação "OK", consultas ao bloco, etc. A ideia é manter histórico de 1+ anos com identificação da execução (run_id) e timestamp.
- **Escopo inicial**:
  - Criar tabela `process_events` com campos: `id` (UUID), `processo_numero`, `acao` (`zip_baixado`, `pdf_extraido`, `anotacao_ok`, `consulta_bloco`, ...), `status` (`ok`, `pulado`, `erro`), `mensagem`, `caminho_arquivo` (opcional), `run_id`, `executado_em` (UTC).
  - Opcional futuro: `process_status` contendo o último estado agregado por processo para consultas rápidas.
- **Integração**:
  1. CLI/GUI (tarefas online):
     - `download_zip_lote` registra evento ao finalizar cada processo (inclusive quando pula por já existir ZIP). Armazena caminho do ZIP salvo.
     - `preencher_anotacoes_ok` registra evento quando a anotação muda para OK.
     - `listar_processos` / `report` podem registrar um snapshot com totais (para auditoria das consultas).
  2. Ferramentas offline:
     - `extract_reports.py` registra quando cada ZIP é aberto e quando gerar PDFs/linhas na planilha.
- **Execuções**: Cada chamada da CLI deve gerar `run_id` (UUID). Todos os eventos daquele comando carregam o mesmo ID para facilitar relatórios.
- **Próximos passos**:
  1. Definir migrations (SQLAlchemy) para criar a tabela.
  2. Implementar helper único `log_process_event(acao, processo, **dados)` reutilizado pelos módulos.
  3. Adicionar flag/param no CLI para informar `run_id` ou gerar automaticamente.
  4. Expor endpoint no backend para consultar o histórico (filtrar por data/ação/processo).

## Agendamentos automáticos
- **Objetivo**: Executar periodicamente (ex.: diário) as tarefas de consulta/download/anotação e registrar no banco.
- **Requisitos**:
  - Definir onde ficará o scheduler (cron/WSL, Windows Task Scheduler ou serviço no backend).
  - Cada execução agendada deve gerar `run_id`, salvar logs completos e escrever os eventos.
  - Permitir configurar a lista de ações por agendamento (ex.: `offline relatorio` às 8h, `online baixar`/`online ok` às 14h).
- **Dependências**: precisa do histórico funcionando (tarefa anterior) para validar resultados.
- **Pendências**: decidir se o scheduler roda no WSL ou se será implementado como worker dentro do backend FastAPI.
