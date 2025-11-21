from __future__ import annotations

from seiautomation.tasks import listar_processos

from ..utils import add_browser_flags, print_progress


def register(subparsers) -> None:
    parser = subparsers.add_parser("painel", aliases=["status", "lista"], help="Lista processos e pendências")
    add_browser_flags(parser)
    parser.add_argument("--limit", type=int, help="Limita a quantidade de linhas exibidas/processadas.")
    parser.add_argument("--pending-only", action="store_true", help="Mostra só processos sem anotação OK.")
    parser.add_argument("--ok-only", action="store_true", help="Mostra só processos já anotados como OK.")
    parser.add_argument("--only-downloaded", action="store_true", help="Filtra processos com ZIP salvo.")
    parser.add_argument("--only-missing-zip", action="store_true", help="Filtra processos ainda sem ZIP.")
    parser.add_argument("--summary", dest="summary_only", action="store_true", help="Oculta a lista e mostra apenas o painel de totais.")
    parser.set_defaults(summary_only=False, handler=_run)


def _run(args, settings) -> int:
    if args.pending_only and args.ok_only:
        raise SystemExit("Use apenas uma das flags --pending-only ou --ok-only.")
    if args.only_downloaded and args.only_missing_zip:
        raise SystemExit("Use apenas uma das flags --only-downloaded ou --only-missing-zip.")
    resultado = listar_processos(
        settings,
        headless=args.headless,
        progress=print_progress,
        auto_credentials=args.auto_credentials,
        limite=args.limit,
        somente_pendentes=args.pending_only,
        somente_ok=args.ok_only,
        somente_baixados=args.only_downloaded,
        somente_sem_zip=args.only_missing_zip,
        summary_only=args.summary_only,
    )

    if not resultado.processos:
        print_progress("Nenhum processo atende aos filtros aplicados.")

    return 0
