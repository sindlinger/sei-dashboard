from __future__ import annotations

from typing import Any

from seiautomation.tasks import download_zip_lote

from ..utils import add_browser_flags, print_progress


def register(subparsers) -> None:
    parser = subparsers.add_parser("baixar", aliases=["pull", "dl"], help="Baixa/atualiza ZIPs do SEI")
    add_browser_flags(parser)
    parser.add_argument("--limit", type=int, help="Limita quantidade de processos a baixar.")
    parser.add_argument(
        "--force",
        dest="skip_existing",
        action="store_false",
        help="Rebaixa ZIPs já salvos (default: pula os existentes).",
    )
    parser.set_defaults(skip_existing=True, handler=_run)


def _run(args, settings) -> int:
    arquivos = list(
        download_zip_lote(
            settings,
            headless=args.headless,
            progress=print_progress,
            skip_existentes=args.skip_existing,
            limite=args.limit,
            auto_credentials=args.auto_credentials,
        )
    )
    if arquivos:
        print_progress(f"Total de ZIPs gerados/preservados: {len(arquivos)}")
    else:
        print_progress("Nenhum ZIP novo foi gerado (todos já existiam ou houve falhas).")
    return 0
