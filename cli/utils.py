from __future__ import annotations

import subprocess
from pathlib import Path
from typing import List

from rich.console import Console


def print_examples(examples: List[tuple[str, str]]) -> None:
    console = get_console()
    console.print("Comandos frequentes do CLI:\n")
    for title, command in examples:
        console.print(f"- {title}\n  {command}\n")


def add_browser_flags(parser) -> None:
    parser.set_defaults(headless=True, auto_credentials=True)
    parser.add_argument(
        "--no-headless",
        dest="headless",
        action="store_false",
        help="Mostra o navegador Playwright (default: headless).",
    )
    parser.add_argument(
        "--no-auto-credentials",
        dest="auto_credentials",
        action="store_false",
        help="Desativa o autopreenchimento de login.",
    )


def ensure_path(value: str) -> Path:
    path = Path(value).expanduser().resolve()
    if not path.exists():
        raise SystemExit(f"Arquivo/diretório inexistente: {path}")
    return path


def collect_offline_paths(args) -> tuple[list[Path], list[Path]]:
    zip_paths: list[Path] = []
    pdf_paths: list[Path] = []

    if getattr(args, "qa_zip", None):
        zip_paths.append(ensure_path(args.qa_zip))
    if getattr(args, "qa_zip_dir", None):
        directory = ensure_path(args.qa_zip_dir)
        zip_paths.extend(sorted(p for p in directory.glob("*.zip") if p.is_file()))
    if getattr(args, "qa_pdf", None):
        pdf_paths.append(ensure_path(args.qa_pdf))
    if getattr(args, "qa_pdf_dir", None):
        directory = ensure_path(args.qa_pdf_dir)
        pdf_paths.extend(sorted(p for p in directory.glob("*.pdf") if p.is_file()))

    if not zip_paths and not pdf_paths:
        raise SystemExit("Informe ZIP/PDF via --zip/--zip-dir/--pdf/--pdf-dir.")
    return zip_paths, pdf_paths


def run_subprocess(cmd: list[str]) -> int:
    try:
        subprocess.run(cmd, check=True)
    except subprocess.CalledProcessError as exc:
        return exc.returncode
    return 0


def print_progress(message: str) -> None:
    get_console().print(message, flush=True)


_CONSOLE: Console | None = None


def get_console() -> Console:
    global _CONSOLE
    if _CONSOLE is None:
        _CONSOLE = Console()
    return _CONSOLE
