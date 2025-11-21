from __future__ import annotations

"""
Seleção de contextos para o QA.

Fluxo:
1) Carrega documentos explodindo o ZIP (ou o PDF empacotado) via ``gather_texts``.
2) Usa os candidatos gerados pelo extrator (``extraction.candidates``) para
   montar janelas curtas por campo.
3) Se algum campo ficar sem contexto, faz fallback com trechos curtos dos
   documentos de bucket mais relevante.

Objetivo: alimentar o modelo de QA com o mínimo de texto útil por campo,
reduzindo custo e ruído.
"""

from collections import defaultdict
from pathlib import Path
from typing import Dict, List, Sequence

from preprocessamento.documents import gather_texts
from seiautomation.offline.doc_classifier import DocumentBucket

Candidate = dict
Document = dict
ExtractionResult = object  # anotação leve para evitar import circular


def load_documents(zip_path: Path) -> List[Document]:
    """
    Lê o ZIP/PDF e retorna a lista de documentos individuais com texto,
    já ordenados pelo heurístico de prioridade do extrator.

    Cada item contém: {"name": str, "text": str, "bucket": DocumentBucket|str}.
    """
    docs, _combined = gather_texts(zip_path)
    for doc in docs:
        bucket = doc.get("bucket")
        if isinstance(bucket, str):
            try:
                doc["bucket"] = DocumentBucket(bucket)
            except Exception:
                pass
    return docs


def _build_snippet(text: str, start: int | None, end: int | None, window: int = 260) -> str:
    if not text:
        return ""
    if start is None or end is None or start < 0 or end < 0:
        return text[:window]
    center = max(0, (start + end) // 2)
    half = window // 2
    seg_start = max(0, center - half)
    seg_end = min(len(text), center + half)
    return text[seg_start:seg_end]


def _doc_by_name(documents: Sequence[Document], name: str | None) -> Document | None:
    if not name:
        return None
    for doc in documents:
        if doc.get("name") == name:
            return doc
    return None


def select_contexts(
    extraction: ExtractionResult,
    documents: Sequence[Document],
    *,
    fields: Sequence[str] | None = None,
    limit_override: int | None = None,
) -> Dict[str, List[dict]]:
    """
    Monta os contextos por campo a partir dos candidatos da extração.

    Args:
        extraction: resultado do extrator (precisa ter attr ``candidates``).
        documents: lista de docs com texto/gênero.
        fields: lista de campos desejados (None = todos que aparecerem).
        limit_override: número máx. de contextos por campo (default=3).

    Retorno: dict[field] -> list[{"context": str, "source": str, ...}]
    """
    target_fields = set(fields) if fields else None
    limit = limit_override or 3
    grouped: dict[str, List[dict]] = defaultdict(list)

    candidates_map = getattr(extraction, "candidates", {}) or {}
    for field, candidates in candidates_map.items():
        if target_fields and field not in target_fields:
            continue
        for cand in candidates:
            source = cand.get("source") or cand.get("document") or ""
            doc = _doc_by_name(documents, source)
            snippet = (
                cand.get("snippet")
                or _build_snippet(doc.get("text", "") if doc else "", cand.get("start"), cand.get("end"))
            )
            if not snippet:
                continue
            entry = {
                "context": snippet,
                "source": source,
                "pattern": cand.get("pattern"),
                "page": cand.get("page"),
                "score": float(cand.get("weight", 0.0)),
            }
            grouped[field].append(entry)

    bucket_priority = {
        DocumentBucket.PRINCIPAL: 0,
        DocumentBucket.APOIO: 1,
        DocumentBucket.LAUDO: 2,
        DocumentBucket.OUTRO: 3,
    }
    sorted_docs = sorted(documents, key=lambda d: bucket_priority.get(d.get("bucket"), 99))
    fallback_fields = list(target_fields) if target_fields else list(grouped.keys())
    for field in fallback_fields:
        if grouped.get(field):
            continue
        for doc in sorted_docs[:limit]:
            text = doc.get("text", "")
            if not text:
                continue
            grouped[field].append(
                {
                    "context": text[:260],
                    "source": doc.get("name"),
                    "pattern": "fallback_doc",
                    "page": None,
                    "score": 0.0,
                }
            )

    trimmed: Dict[str, List[dict]] = {}
    for field, items in grouped.items():
        seen = set()
        uniq: List[dict] = []
        for item in sorted(items, key=lambda i: i.get("score", 0), reverse=True):
            ctx = item.get("context", "")
            if ctx in seen:
                continue
            seen.add(ctx)
            uniq.append(item)
            if len(uniq) >= limit:
                break
        trimmed[field] = uniq

    return trimmed
