from __future__ import annotations

import io
import re
import zipfile
from collections import OrderedDict
from pathlib import Path
from typing import List, Sequence, Tuple

import pdfplumber
from bs4 import BeautifulSoup

from seiautomation.offline.doc_classifier import DocumentBucket, classify_document


def html_to_text(raw: bytes) -> str:
    soup = BeautifulSoup(raw, "html.parser")
    return soup.get_text("\n", strip=True)


def _extract_pdf_pages(raw: bytes) -> List[str]:
    with pdfplumber.open(io.BytesIO(raw)) as pdf:
        return [page.extract_text() or "" for page in pdf.pages]


def pdf_to_text(raw: bytes) -> str:
    return "\n".join(_extract_pdf_pages(raw))


def _extract_pdf_doc_number(page_text: str) -> int | None:
    if not page_text:
        return None
    lowered = page_text.lower()
    marker = "otnemucod"
    idx = lowered.find(marker)
    if idx == -1:
        return None
    window = lowered[max(0, idx - 12) : idx]
    match = re.search(r"(\d{1,3})\s*$", window)
    if not match:
        return None
    digits = match.group(1)
    try:
        return int(digits[::-1])
    except ValueError:
        return None


def _build_pdf_documents_from_pages(page_texts: Sequence[str], base_name: str) -> List[dict[str, str]]:
    documents: "OrderedDict[int | None, List[str]]" = OrderedDict()
    buffer: List[str] = []
    current_id: int | None = None

    for page_text in page_texts:
        doc_id = _extract_pdf_doc_number(page_text)
        if doc_id is not None:
            current_id = doc_id
            documents.setdefault(doc_id, [])
            if buffer:
                documents[doc_id].extend(buffer)
                buffer.clear()
            documents[doc_id].append(page_text)
            continue
        if current_id is None:
            if page_text:
                buffer.append(page_text)
        else:
            documents.setdefault(current_id, []).append(page_text)

    if buffer:
        target = current_id if current_id is not None else 0
        documents.setdefault(target, []).extend(buffer)

    if not documents:
        combined = "\n".join(filter(None, page_texts)).strip()
        if not combined:
            return []
        bucket = classify_document(base_name, combined)
        return [{"name": base_name, "text": combined, "bucket": bucket}]

    positive_ids = {doc_id for doc_id in documents if doc_id and doc_id > 0}
    fallback_label = 1

    def _next_label() -> int:
        nonlocal fallback_label
        while fallback_label in positive_ids:
            fallback_label += 1
        value = fallback_label
        fallback_label += 1
        return value

    results: List[dict[str, str]] = []
    stem = Path(base_name).stem or "documento"
    for doc_id, chunks in documents.items():
        text = "\n".join(filter(None, chunks)).strip()
        if not text:
            continue
        label = doc_id if doc_id and doc_id > 0 else _next_label()
        doc_name = f"{stem}_doc{int(label):02d}.pdf"
        bucket = classify_document(doc_name, text)
        results.append({"name": doc_name, "text": text, "bucket": bucket})
    return results


def split_combined_pdf(raw: bytes, base_name: str) -> List[dict[str, str]]:
    page_texts = _extract_pdf_pages(raw)
    if not page_texts:
        return []
    return _build_pdf_documents_from_pages(page_texts, base_name)


def document_priority(name: str, text: str) -> Tuple[int, int]:
    name_lower = name.lower()
    text_lower = text.lower()
    score = 10
    if "despacho" in name_lower:
        score -= 5
    if "laudo" in name_lower:
        score -= 4
    if "autoriz" in text_lower or "honor" in text_lower:
        score -= 3
    if "certidao" in name_lower:
        score -= 1
    if "laudo" in name_lower:
        score -= 2
    if name_lower.endswith(".html"):
        score -= 1
    return score, len(text) * -1


def gather_texts(zip_path: Path) -> tuple[list[dict[str, str]], str]:
    sources: list[dict[str, str]] = []
    with zipfile.ZipFile(zip_path) as zf:
        entries = [info for info in zf.infolist() if not info.is_dir()]
        if len(entries) == 1:
            single = entries[0]
            lower = single.filename.lower()
            if lower.endswith(".pdf"):
                try:
                    raw = zf.read(single)
                except KeyError:
                    raw = b""
                if raw:
                    split_docs = split_combined_pdf(raw, single.filename)
                    if split_docs:
                        sources.extend(split_docs)
                        sources.sort(key=lambda s: document_priority(s["name"], s["text"]))
                        combined = "\n".join(src["text"] for src in sources)
                        return sources, combined
        for info in entries:
            name = info.filename
            lower = name.lower()
            try:
                data = zf.read(info)
            except KeyError:
                continue
            text = ""
            if lower.endswith(".html") or "despacho" in lower:
                text = html_to_text(data)
            elif lower.endswith(".pdf"):
                try:
                    text = pdf_to_text(data)
                except Exception:
                    continue
            elif lower.endswith(".txt"):
                try:
                    text = data.decode("utf-8", errors="ignore")
                except Exception:
                    text = data.decode("latin-1", errors="ignore")
            else:
                continue
            if not text:
                continue
            bucket = classify_document(name, text)
            sources.append({"name": name, "text": text, "bucket": bucket})
    sources.sort(key=lambda s: document_priority(s["name"], s["text"]))
    return sources, ""  # combined removido
