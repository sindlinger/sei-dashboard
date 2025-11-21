from __future__ import annotations

import subprocess
import sys
from pathlib import Path

from ..constants import DEFAULT_QA_MODEL
from ..utils import ensure_path


def register(subparsers) -> None:
    parser = subparsers.add_parser("qa", help="Roda o QA supervisionado nos documentos")
    parser.add_argument("--zip", dest="qa_zip", help="Arquivo ZIP individual para QA.")
    parser.add_argument("--zip-dir", dest="qa_zip_dir", help="Diretório com ZIPs (default: SEI_DOWNLOAD_DIR).")
    parser.add_argument("--pdf", dest="qa_pdf", help="PDF consolidado individual para QA.")
    parser.add_argument("--pdf-dir", dest="qa_pdf_dir", help="Diretório com PDFs avulsos.")
    parser.add_argument("--limit", dest="qa_limit", type=int, help="Limita a quantidade de arquivos processados.")
    parser.add_argument("--fields", dest="qa_fields", nargs="*", help="Campos a consultar.")
    parser.add_argument("--max-per-field", dest="qa_max_per_field", type=int, default=3, help="Quantidade de contextos por campo (default=3).")
    parser.add_argument("--min-score", dest="qa_min_score", type=float, default=0.25, help="Score mínimo para aceitar respostas.")
    parser.add_argument("--model", dest="qa_model", default=str(DEFAULT_QA_MODEL), help="Checkpoint do modelo QA.")
    # Mantido por compatibilidade; o pipeline atual não usa workers, apenas ignora.
    parser.add_argument("--workers", dest="qa_workers", type=int, default=None, help="(Ignorado) workers para seleção de contextos.")
    parser.add_argument("--batch-size", dest="qa_batch_size", type=int, default=16, help="Perguntas por lote enviado ao modelo.")
    parser.add_argument("--output", dest="qa_output", default="qa-results.json", help="JSON de saída com as respostas.")
    parser.add_argument("--device", dest="qa_device", type=int, default=0, help="GPU usada (use -1 para CPU).")
    parser.add_argument("--verbose", dest="qa_verbose", action="store_true", help="Mostra logs detalhados do QA.")
    parser.set_defaults(handler=_run)


def _add_sources(cmd: list[str], zip_value: str | None, pdf_value: str | None, flag_zip: str, flag_pdf: str) -> bool:
    added = False
    if zip_value:
        cmd.extend([flag_zip, str(ensure_path(zip_value))])
        added = True
    if pdf_value:
        cmd.extend([flag_pdf, str(ensure_path(pdf_value))])
        added = True
    return added


def _run(args, settings) -> int:
    cmd = [sys.executable, "-m", "qa.run_context_qa"]

    def _add(flag: str, value: str | None) -> bool:
        if value:
            cmd.extend([flag, str(ensure_path(value))])
            return True
        return False

    sources_added = False
    sources_added |= _add("--zip", args.qa_zip)
    if args.qa_zip_dir:
        cmd.extend(["--zip-dir", str(ensure_path(args.qa_zip_dir))])
        sources_added = True
    sources_added |= _add("--pdf", args.qa_pdf)
    if args.qa_pdf_dir:
        cmd.extend(["--pdf-dir", str(ensure_path(args.qa_pdf_dir))])
        sources_added = True

    if not sources_added:
        cmd.extend(["--zip-dir", str(settings.download_dir)])

    if args.qa_limit:
        cmd.extend(["--limit", str(args.qa_limit)])
    if args.qa_fields:
        cmd.append("--fields")
        cmd.extend(args.qa_fields)
    if args.qa_max_per_field:
        cmd.extend(["--max-per-field", str(args.qa_max_per_field)])
    if args.qa_workers is not None:
        cmd.extend(["--workers", str(max(0, args.qa_workers))])
    if args.qa_batch_size:
        cmd.extend(["--batch-size", str(max(1, args.qa_batch_size))])
    if args.qa_model:
        model_path = Path(args.qa_model).expanduser()
        cmd.extend(["--model-name", str(model_path)])
    cmd.extend(["--device", str(args.qa_device)])
    cmd.extend(["--min-score", str(args.qa_min_score)])
    if args.qa_output:
        cmd.extend(["--output", args.qa_output])
    if args.qa_verbose:
        cmd.append("--verbose")

    try:
        subprocess.run(cmd, check=True)
    except subprocess.CalledProcessError as exc:
        return exc.returncode
    return 0
