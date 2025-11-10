from __future__ import annotations

import argparse

from .config import Settings
from .tasks import download_zip_lote, listar_processos, preencher_anotacoes_ok


def _print_progress(message: str) -> None:
    print(message, flush=True)


def _run_download(settings: Settings, args: argparse.Namespace) -> int:
    arquivos = list(
        download_zip_lote(
            settings,
            headless=args.headless,
            progress=_print_progress,
            skip_existentes=args.skip_existing,
            limite=args.limit,
            auto_credentials=args.auto_credentials,
        )
    )
    if arquivos:
        _print_progress(f"Total de ZIPs gerados/preservados: {len(arquivos)}")
    else:
        _print_progress("Nenhum ZIP novo foi gerado (todos já existiam ou houve falhas).")
    return 0


def _run_annotate(settings: Settings, args: argparse.Namespace) -> int:
    total = preencher_anotacoes_ok(
        settings,
        headless=args.headless,
        progress=_print_progress,
        auto_credentials=args.auto_credentials,
    )
    _print_progress(f"Total de anotações atualizadas: {total}")
    return 0


def _run_list(settings: Settings, args: argparse.Namespace) -> int:
    resultado = listar_processos(
        settings,
        headless=args.headless,
        progress=_print_progress,
        auto_credentials=args.auto_credentials,
        limite=args.limit,
        somente_pendentes=args.pending_only,
        somente_ok=args.ok_only,
        somente_baixados=args.only_downloaded,
        somente_sem_zip=args.only_missing_zip,
        summary_only=args.summary_only,
    )

    if not resultado.processos:
        _print_progress("Nenhum processo atende aos filtros aplicados.")

    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="CLI para tarefas do SEIAutomation")
    parser.add_argument(
        "tasks",
        nargs="+",
        choices=("download", "annotate", "list"),
        help="Tarefas a executar (pode informar mais de uma)",
    )
    parser.add_argument(
        "--no-headless",
        dest="headless",
        action="store_false",
        default=True,
        help="Executa com janela visível",
    )
    parser.add_argument(
        "--username",
        help="Sobrescreve SEI_USERNAME durante esta execução",
    )
    parser.add_argument(
        "--password",
        help="Sobrescreve SEI_PASSWORD durante esta execução",
    )
    parser.add_argument(
        "--pending-only",
        action="store_true",
        help="Considera apenas processos sem anotação OK",
    )
    parser.add_argument(
        "--ok-only",
        action="store_true",
        help="Considera apenas processos com anotação OK",
    )
    parser.add_argument(
        "--only-downloaded",
        action="store_true",
        help="Considera apenas processos que já possuem ZIP salvo",
    )
    parser.add_argument(
        "--only-missing-zip",
        action="store_true",
        help="Considera apenas processos ainda sem ZIP salvo",
    )
    parser.add_argument(
        "--summary-only",
        action="store_true",
        help="Oculta a listagem linha a linha e mostra apenas o painel de totais",
    )
    parser.add_argument(
        "--no-auto-credentials",
        dest="auto_credentials",
        action="store_false",
        help="Desativa preenchimento automático de login",
    )
    parser.add_argument(
        "--auto-credentials",
        dest="auto_credentials",
        action="store_true",
        help="Força preenchimento automático de login (requer admin)",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=None,
        help="Limita quantidade de processos ao baixar ZIPs",
    )
    parser.add_argument(
        "--no-skip-existing",
        dest="skip_existing",
        action="store_false",
        default=True,
        help="Rebaixa ZIPs já existentes",
    )
    parser.set_defaults(auto_credentials=None)
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    settings = Settings.load(username=args.username, password=args.password)

    if args.pending_only and args.ok_only:
        parser.error("Use apenas uma das flags --pending-only ou --ok-only.")
    if args.only_downloaded and args.only_missing_zip:
        parser.error("Use apenas uma das flags --only-downloaded ou --only-missing-zip.")
    if args.auto_credentials is None:
        args.auto_credentials = settings.is_admin

    exit_code = 0
    for task in args.tasks:
        if task == "download":
            exit_code |= _run_download(settings, args)
        elif task == "annotate":
            exit_code |= _run_annotate(settings, args)
        elif task == "list":
            exit_code |= _run_list(settings, args)
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
