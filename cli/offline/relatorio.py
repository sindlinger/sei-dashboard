from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

from ..utils import ensure_path, ensure_dir_writable


def register(subparsers) -> None:
    parser = subparsers.add_parser("relatorio", aliases=["report", "excel"], help="Gera relatorio-pericias.xlsx")
    parser.add_argument("--zip-dir", dest="report_zip_dir", help="Diretório com os ZIPs (default: SEI_DOWNLOAD_DIR).")
    parser.add_argument("--pdf-dir", dest="report_pdf_dir", action="append", help="Diretórios extras com PDFs consolidados (pode repetir).")
    parser.add_argument("--txt-dir", dest="report_txt_dir", action="append", help="Diretórios extras com arquivos TXT (pode repetir).")
    parser.add_argument("--output", dest="report_output", default="relatorio-pericias.xlsx", help="Arquivo de saída.")
    parser.add_argument("--limit", dest="report_limit", type=int, help="Processa apenas os primeiros N arquivos (debug).")
    # Execução é sempre sequencial; flag de workers suprimida
    parser.add_argument("--full", dest="report_skip_existing", action="store_false", help="Reprocessa tudo (não pula linhas já presentes).")
    parser.set_defaults(report_skip_existing=True, handler=_run)


def _run(args, settings) -> int:
    zip_dir = Path(args.report_zip_dir).expanduser() if args.report_zip_dir else settings.download_dir
    output = Path(args.report_output).expanduser()
    # Preflight: diretórios e permissões
    if not zip_dir.exists():
        raise SystemExit(f"Diretório de ZIPs não encontrado: {zip_dir}")
    if not any(zip_dir.glob("*.zip")):
        raise SystemExit(f"Nenhum ZIP encontrado em {zip_dir}.")
    ensure_dir_writable(output.parent)
    ensure_dir_writable(settings.download_dir)
    ensure_dir_writable(Path("logs/extract"))
    output.parent.mkdir(parents=True, exist_ok=True)
    cmd = [
        sys.executable,
        "-m",
        "seiautomation.offline.extract_reports",
        "--zip-dir",
        str(zip_dir),
        "--output",
        str(output),
    ]
    for extra in args.report_pdf_dir or []:
        cmd.extend(["--pdf-dir", str(ensure_path(extra))])
    for extra in args.report_txt_dir or []:
        cmd.extend(["--txt-dir", str(ensure_path(extra))])
    if args.report_limit:
        cmd += ["--limit", str(args.report_limit)]
    if args.report_skip_existing:
        cmd.append("--skip-existing")
    try:
        subprocess.run(cmd, check=True)
    except subprocess.CalledProcessError as exc:
        return exc.returncode
    return 0
