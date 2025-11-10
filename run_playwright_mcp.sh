#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env.playwright"
OUTPUT_DIR="$SCRIPT_DIR/playwright-downloads"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Arquivo de segredos não encontrado: $ENV_FILE" >&2
  echo "Crie-o (ou renomeie o existente) antes de rodar este script." >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

CODEx_CONFIG=(
  "-c"
  "mcp_servers.playwright.args=[\"run\",\"-i\",\"--rm\",\"-v\",\"$ENV_FILE:/run/secrets/playwright.env:ro\",\"-v\",\"$OUTPUT_DIR:/outputs\",\"mcp/playwright\",\"--secrets\",\"/run/secrets/playwright.env\",\"--output-dir\",\"/outputs\",\"--caps\",\"pdf\"]"
)

PROMPT="Use o servidor MCP Playwright em modo com cabeça. 1) Garanta que o navegador esteja pronto (chame browser_install se necessário). 2) Vá para https://sei.tjpb.jus.br/sei/controlador.php?acao=rel_bloco_protocolo_listar&acao_origem=bloco_interno_listar&acao_retorno=bloco_interno_listar&id_bloco=55&infra_sistema=100000100&infra_unidade_atual=110001126&infra_hash=690d9b506cdaebfd184ce29559b0b07d2a5737eb2675eb2d381dab74b39883d8 . 3) Faça login com process.env.SEI_USERNAME, process.env.SEI_PASSWORD e process.env.SEI_OTP (se existir). 4) Após logar, clique no menu lateral em “Blocos”, depois em “Internos”. 5) Na lista que abrir, localize a linha “Peritos” e clique no número “55” no início dessa linha; aguarde a lista de processos carregar. 6) Para cada processo listado, abra-o, procure o ícone de ZIP ou PDF, clique nele e em seguida clique no botão “Gerar” que aparecer. 7) Aguarde o download terminar em /outputs e registre o caminho de cada arquivo. 8) Repita até concluir todos os processos, reportando falhas ou exceções."

exec codex exec --skip-git-repo-check --sandbox workspace-write "${CODEx_CONFIG[@]}" "$PROMPT"
