from __future__ import annotations

from seiautomation.tasks import preencher_anotacoes_ok

from ..utils import add_browser_flags, print_progress


def register(subparsers) -> None:
    parser = subparsers.add_parser("ok", aliases=["marcar"], help="Atualiza anotações para OK")
    add_browser_flags(parser)
    parser.set_defaults(handler=_run)


def _run(args, settings) -> int:
    total = preencher_anotacoes_ok(
        settings,
        headless=args.headless,
        progress=print_progress,
        auto_credentials=args.auto_credentials,
    )
    print_progress(f"Total de anotações atualizadas: {total}")
    return 0
