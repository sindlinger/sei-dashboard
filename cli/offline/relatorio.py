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
    parser.add_argument("--workers", dest="report_workers", type=int, default=24, help="Workers paralelos (default=24).")
    parser.add_argument("--checkpoint-interval", dest="report_checkpoint", type=int, default=25, help="Consolida Excel a cada N arquivos (default=25).")
    parser.add_argument("--full", dest="report_skip_existing", action="store_false", help="Reprocessa tudo (não pula linhas já presentes).")
    parser.add_argument("--no-log-cleanup", action="store_true", help="Não varre/limpa logs antigos antes de iniciar.")
    parser.add_argument("--no-run-log", action="store_true", help="Não grava o .log em disco (somente console).")
    parser.add_argument("--no-audit-log", action="store_true", help="Não grava o JSONL de fontes/offsets.")
    parser.add_argument("--no-file-log", action="store_true", help="Compatível: igual a --no-run-log.")
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
    if args.report_workers:
        cmd += ["--workers", str(args.report_workers)]
    if args.report_checkpoint:
        cmd += ["--checkpoint-interval", str(args.report_checkpoint)]
    if args.no_log_cleanup:
        cmd.append("--no-log-cleanup")
    if args.no_run_log or args.no_file_log:
        cmd.append("--no-run-log")
    if args.no_audit_log:
        cmd.append("--no-audit-log")
    try:
        subprocess.run(cmd, check=True)
    except subprocess.CalledProcessError as exc:
        return exc.returncode
    return 0
