from __future__ import annotations

from . import baixar, ok, painel


def register_online(subparsers) -> None:
    online_parser = subparsers.add_parser("online", aliases=["on"], help="Fluxo com Playwright (download/list/OK)")
    online_sub = online_parser.add_subparsers(dest="online_command", required=True)
    baixar.register(online_sub)
    ok.register(online_sub)
    painel.register(online_sub)
