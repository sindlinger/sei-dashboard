from __future__ import annotations

from rich.table import Table

from ..utils import get_console
from seiautomation import logs as logs_mod


def register(subparsers) -> None:
    parser = subparsers.add_parser("logs", help="Lista, inspeciona e limpa logs/checkpoints")
    parser.add_argument("--limit", dest="logs_limit", type=int, default=20, help="Quantidade de execuções exibidas.")
    parser.add_argument("--show", dest="logs_show", help="Exibe o conteúdo do log para o run-id informado.")
    parser.add_argument("--checkpoint", dest="logs_show_state", help="Exibe o checkpoint (state) do run-id informado.")
    parser.add_argument("--tail", dest="logs_tail", type=int, default=0, help="Mostra só as últimas N linhas ao exibir um log.")
    parser.add_argument("--clean-days", dest="logs_clean_days", type=int, help="Remove logs mais antigos que N dias.")
    parser.add_argument("--clean-size", dest="logs_clean_size", type=int, help="Mantém o diretório de logs em N MB.")
    parser.set_defaults(handler=_run)


def _run(args, settings) -> int:
    console = get_console()
    entries = logs_mod.list_logs(limit=args.logs_limit)
    if entries:
        table = Table(show_header=True, header_style="bold")
        table.add_column("Run ID", overflow="fold")
        table.add_column("Data/Hora")
        table.add_column("Tamanho")
        table.add_column("Checkpoint")
        for entry in entries:
            size_mb = entry.size_bytes / (1024 * 1024)
            has_state = "sim" if entry.state_path and entry.state_path.exists() else "não"
            table.add_row(entry.run_id, f"{entry.mtime:%Y-%m-%d %H:%M:%S}", f"{size_mb:6.2f} MB", has_state)
        console.print(table)
    else:
        console.print("Nenhum log em logs/.")

    if args.logs_show:
        try:
            content = logs_mod.show_log(
                args.logs_show,
                tail=args.logs_tail > 0,
                lines=args.logs_tail if args.logs_tail > 0 else 50,
            )
            console.print(f"\n[bold]== Log {args.logs_show} ==[/bold]")
            console.print(content)
        except FileNotFoundError as exc:
            console.print(str(exc))

    if args.logs_show_state:
        try:
            content = logs_mod.show_state(args.logs_show_state)
            console.print(f"\n[bold]== Checkpoint {args.logs_show_state} ==[/bold]")
            console.print(content)
        except FileNotFoundError as exc:
            console.print(str(exc))

    if args.logs_clean_days or args.logs_clean_size:
        result = logs_mod.cleanup_logs(args.logs_clean_days, args.logs_clean_size)
        if result["deleted"]:
            console.print(f"Logs removidos: {', '.join(result['deleted'])}")
        else:
            console.print("Nenhum log removido.")
    return 0
