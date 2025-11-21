from __future__ import annotations

"""
Pipeline simplificado para executar QA sobre os contextos selecionados.
Ele foi reimplementado após a recuperação para garantir que o CLI volte a
funcionar mesmo sem os arquivos originais.
"""

import argparse
import json
import sys
from pathlib import Path
from typing import Sequence

from qa.match_runner import run_match


def _parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="QA supervisionado sobre contextos pré-selecionados.")
    parser.add_argument("--zip", dest="zip", help="ZIP único.")
    parser.add_argument("--zip-dir", dest="zip_dir", help="Diretório com ZIPs.")
    parser.add_argument("--pdf", dest="pdf", help="PDF consolidado único.")
    parser.add_argument("--pdf-dir", dest="pdf_dir", help="Diretório com PDFs avulsos.")
    parser.add_argument("--limit", dest="limit", type=int, help="Limita quantidade de arquivos processados.")
    parser.add_argument("--fields", nargs="*", help="Campos a consultar.")
    parser.add_argument("--max-per-field", dest="max_per_field", type=int, default=3, help="Contextos por campo.")
    parser.add_argument("--min-score", dest="min_score", type=float, default=0.25, help="Score mínimo para aceitar resposta.")
    parser.add_argument("--model-name", dest="model_name", default=None, help="Checkpoint do modelo QA.")
    parser.add_argument("--device", dest="device", type=int, default=0, help="GPU (use -1 para CPU).")
    parser.add_argument("--batch-size", dest="batch_size", type=int, default=16, help="Lote enviado para o modelo.")
    parser.add_argument("--output", dest="output", default="qa-results.json", help="Arquivo JSON de saída.")
    parser.add_argument("--verbose", action="store_true", help="Mostra resultados no stdout.")
    return parser.parse_args(argv)


def _collect_paths(args: argparse.Namespace) -> tuple[list[Path], list[Path]]:
    zips: list[Path] = []
    pdfs: list[Path] = []
    if args.zip:
        zips.append(Path(args.zip))
    if args.zip_dir:
        zips.extend(sorted(Path(args.zip_dir).glob("*.zip")))
    if args.pdf:
        pdfs.append(Path(args.pdf))
    if args.pdf_dir:
        pdfs.extend(sorted(Path(args.pdf_dir).glob("*.pdf")))
    if not zips and not pdfs:
        # fallback: usa diretório padrão de downloads
        default_dir = Path("playwright-downloads")
        zips.extend(sorted(default_dir.glob("*.zip")))
    return zips, pdfs


def run_context_qa(argv: Sequence[str] | None = None) -> int:
    args = _parse_args(argv)
    zip_paths, pdf_paths = _collect_paths(args)
    if args.limit is not None and args.limit >= 0:
        zip_paths = zip_paths[: args.limit]
        pdf_paths = pdf_paths[: max(0, args.limit - len(zip_paths))]

    model_name = args.model_name or "deepset/xlm-roberta-large-squad2"

    results = run_match(
        zip_paths=zip_paths,
        pdf_paths=pdf_paths,
        limit=None,
        fields=args.fields,
        device=args.device,
        model_name=model_name,
        min_score=args.min_score,
        max_per_field=args.max_per_field,
    )

    out_path = Path(args.output)
    out_path.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")

    if args.verbose:
        print(json.dumps(results, ensure_ascii=False, indent=2))
    else:
        print(f"QA concluído. Resultados salvos em {out_path}")
    return 0


if __name__ == "__main__":
    sys.exit(run_context_qa())
