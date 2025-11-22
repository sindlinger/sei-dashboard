"""
Split multi‑document PDFs (SEI) into individual PDFs, using the reversed marker
“otnemucod” (palavra “documento” invertida) e heurísticas simples de texto.

Entrada:
  --input-dir   Diretório com PDFs (ex.: C:\\Users\\pichau\\Desktop\\geral_pdf\\pdf_cache)
  --output-dir  Diretório onde serão gravados os PDFs separados

Saídas:
  - PDFs separados: <output-dir>/<bucket>/<arquivo> (bucket: principal/apoio/laudo/outro)
  - CSV índice: <output-dir>/split_index.csv com colunas:
      original_pdf, doc_id, output_pdf, bucket, tag, pages

Heurísticas:
  - Quebra por marcador “otnemucod” (como em preprocessamento/documents.py)
  - Classificação por bucket usando seiautomation.offline.doc_classifier.classify_document
  - Tags extras: sentenca, certidao, conselho_magistratura, nota_empenho,
    habilitacao_perito, laudo, despacho.
"""

from __future__ import annotations

import argparse
import csv
import re
from pathlib import Path
from typing import List, Tuple

import pdfplumber
from PyPDF2 import PdfReader, PdfWriter

from preprocessamento.documents import _extract_pdf_doc_number
from seiautomation.offline.doc_classifier import classify_document


def extract_page_texts(pdf_path: Path) -> List[str]:
    with pdfplumber.open(pdf_path) as pdf:
        return [page.extract_text() or "" for page in pdf.pages]


def split_pages_by_doc_id(page_texts: List[str]) -> List[Tuple[int, int]]:
    """
    Retorna lista de (doc_id, start_page, end_page_exclusive).
    Se não houver marcador, retorna um único doc (id 1).
    """
    docs: List[Tuple[int, int]] = []
    current_id = None
    start = 0
    for i, text in enumerate(page_texts):
        doc_id = _extract_pdf_doc_number(text)
        if doc_id is not None:
            # fecha doc anterior
            if current_id is not None:
                docs.append((current_id, start, i))
            current_id = doc_id
            start = i
    # encerra último
    if current_id is not None:
        docs.append((current_id, start, len(page_texts)))
    if not docs:
        docs = [(1, 0, len(page_texts))]
    return docs


def tag_kind(text: str) -> str:
    t = text.lower()
    if "senten" in t or "acórd" in t or "acord" in t:
        return "sentenca"
    if "certidao" in t or "certidão" in t:
        return "certidao"
    if "conselho da magistratura" in t or "assessoria do conselho da magistratura" in t:
        return "conselho_magistratura"
    if "nota de empenho" in t or "empenho" in t:
        return "nota_empenho"
    if "habilitação" in t and "perito" in t:
        return "habilitacao_perito"
    if "laudo" in t:
        return "laudo"
    if "despacho" in t or "decisão" in t or "decisao" in t:
        return "despacho"
    return ""


def write_subpdf(src_reader: PdfReader, start: int, end: int, output_path: Path) -> None:
    writer = PdfWriter()
    for i in range(start, end):
        writer.add_page(src_reader.pages[i])
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("wb") as f:
        writer.write(f)


def process_pdf(pdf_path: Path, out_dir: Path, writer_rows: list) -> None:
    page_texts = extract_page_texts(pdf_path)
    splits = split_pages_by_doc_id(page_texts)
    src_reader = PdfReader(str(pdf_path))
    for doc_id, start, end in splits:
        pages_text = "\n".join(page_texts[start:end])
        bucket = classify_document(pdf_path.name, pages_text).value
        tag = tag_kind(pages_text)
        out_name = f"{pdf_path.stem}_doc{doc_id:02d}.pdf"
        out_path = out_dir / bucket / out_name
        write_subpdf(src_reader, start, end, out_path)
        writer_rows.append(
            {
                "original_pdf": str(pdf_path),
                "doc_id": doc_id,
                "output_pdf": str(out_path),
                "bucket": bucket,
                "tag": tag,
                "pages": end - start,
            }
        )


def main() -> None:
    parser = argparse.ArgumentParser(description="Split multi-document PDFs and classify buckets.")
    parser.add_argument("--input-dir", required=True, type=Path, help="Diretório com PDFs de entrada.")
    parser.add_argument("--output-dir", required=True, type=Path, help="Diretório para salvar PDFs separados.")
    args = parser.parse_args()

    pdfs = sorted(p for p in args.input_dir.glob("**/*.pdf"))
    if not pdfs:
        raise SystemExit("Nenhum PDF encontrado.")

    rows: list = []
    for pdf in pdfs:
        process_pdf(pdf, args.output_dir, rows)

    index_path = args.output_dir / "split_index.csv"
    index_path.parent.mkdir(parents=True, exist_ok=True)
    with index_path.open("w", newline="", encoding="utf-8") as fo:
        writer = csv.DictWriter(
            fo, fieldnames=["original_pdf", "doc_id", "output_pdf", "bucket", "tag", "pages"]
        )
        writer.writeheader()
        writer.writerows(rows)
    print(f"Processados {len(pdfs)} PDFs. Index: {index_path}")


if __name__ == "__main__":
    main()

