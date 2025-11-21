from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path

from seiautomation.config import Settings

from .examples import register_examples
from .offline import register_offline
from .online import register_online


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="CLI para tarefas do SEIAutomation")
    parser.add_argument("--username", help="Sobrescreve SEI_USERNAME durante esta execução")
    parser.add_argument("--password", help="Sobrescreve SEI_PASSWORD durante esta execução")
    subparsers = parser.add_subparsers(dest="section", required=True)
    register_examples(subparsers)
    register_online(subparsers)
    register_offline(subparsers)
    return parser


def _should_proxy_to_windows(args: argparse.Namespace) -> bool:
    return args.section == "online" and os.name != "nt"


def _proxy_to_windows(argv: list[str]) -> int:
    project_root = Path(__file__).resolve().parents[1]
    try:
        win_root = (
            subprocess.check_output(["wslpath", "-w", str(project_root)], text=True)
            .strip()
        )
    except Exception:
        raise SystemExit(
            "Para os comandos online, execute no Windows (não foi possível resolver o caminho via wslpath)."
        )
    python_win = Path(win_root) / ".venvwin" / "Scripts" / "python.exe"
    if not python_win.exists():
        raise SystemExit(
            f"Ambiente .venvwin não encontrado em {python_win}. Crie-o e instale as dependências no Windows."
        )
    cmdline = subprocess.list2cmdline(["-m", "cli", *argv])
    command = f"cd /d {win_root} && {python_win} {cmdline}"
    completed = subprocess.run(["cmd.exe", "/c", command])
    return completed.returncode


def run(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if _should_proxy_to_windows(args):
        original_argv = argv if argv is not None else sys.argv[1:]
        return _proxy_to_windows(original_argv)
    handler = getattr(args, "handler", None)
    if handler is None:
        parser.error("Escolha um comando. Use 'exemplos' para ver sugestões.")
    settings = Settings.load(username=args.username, password=args.password)
    return handler(args, settings)
