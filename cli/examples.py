from __future__ import annotations

from typing import List, Tuple

from .utils import print_examples

EXAMPLES: List[Tuple[str, str]] = [
    (
        "Baixar 100 processos via navegador (headless):",
        "python -m cli online baixar --limit 100",
    ),
    (
        "Atualizar anotações OK usando auto-login:",
        "python -m cli online ok",
    ),
    (
        "Ver apenas pendentes no painel resumido:",
        "python -m cli online painel --pending-only --summary",
    ),
    (
        "Gerar relatorio-pericias.xlsx com ZIP + PDFs extras:",
        'python -m cli offline relatorio --zip-dir "C:/Users/pichau/Downloads/DE/playwright-downloads" --pdf-dir "C:/Users/pichau/Desktop/geral_pdf/pdf_cache" --full',
    ),
    (
        "Rodar QA para PROMOVENTE/PROMOVIDO usando todos os ZIPs:",
        'python -m cli offline qa --fields PROMOVENTE PROMOVIDO --zip-dir "C:/Users/pichau/Downloads/DE/playwright-downloads" --output qa-resultados.json --device 0',
    ),
    (
        "Comparar regex × QA diretamente no terminal:",
        'python -m cli offline match --zip playwright-downloads/000219_17_2025_8_15_SEI_000219_17.2025.8.15.zip --fields PROMOVENTE PROMOVIDO',
    ),
    (
        "Ver e limpar logs antigos:",
        "python -m cli offline logs --limit 5 --show <run-id> --tail 50",
    ),
]


def register_examples(subparsers) -> None:
    parser = subparsers.add_parser("exemplos", aliases=["examples", "help-exemplo"], help="Mostra comandos prontos.")

    def _handler(args, settings) -> int:
        print_examples(EXAMPLES)
        return 0

    parser.set_defaults(handler=_handler)
