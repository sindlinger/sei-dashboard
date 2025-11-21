from __future__ import annotations

from . import relatorio, qa, match, logs


def register_offline(subparsers) -> None:
    offline_parser = subparsers.add_parser("offline", aliases=["off"], help="Ferramentas offline (relatório/QA/logs)")
    offline_sub = offline_parser.add_subparsers(dest="offline_command", required=True)
    relatorio.register(offline_sub)
    qa.register(offline_sub)
    match.register(offline_sub)
    logs.register(offline_sub)
