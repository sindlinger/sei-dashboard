from __future__ import annotations

from pathlib import Path
from typing import Dict, List, Sequence, Tuple

from transformers import AutoTokenizer, pipeline

from preprocessamento.inputs import resolve_input_paths
from qa.context_selector import load_documents, select_contexts
from qa.questions import FIELD_QUESTIONS
from seiautomation.offline.extract_reports import process_zip


def _build_qa_inputs(
    records: List[Tuple[str, str, Dict[str, List[dict]], Dict[str, str]]],
    fields: Sequence[str] | None,
    max_per_field: int,
) -> Tuple[List[dict], List[Tuple[str, str, dict]]]:
    qa_inputs: List[dict] = []
    metadata: List[Tuple[str, str, dict]] = []
    target_fields = list(fields) if fields else None
    for display_name, resolved, contexts, _ in records:
        filtered_fields = target_fields or list(contexts.keys())
        for field in filtered_fields:
            snippets = contexts.get(field, [])
            if not snippets:
                continue
            question = FIELD_QUESTIONS.get(field, f"Qual é o valor do campo {field}?")
            for entry in snippets[:max_per_field]:
                qa_inputs.append({"question": question, "context": entry["context"]})
                metadata.append((display_name, field, entry))
    return qa_inputs, metadata


def _prepare_records(
    prepared_inputs,
    fields: Sequence[str] | None,
    max_per_field: int,
) -> List[Tuple[str, str, Dict[str, List[dict]], Dict[str, str]]]:
    records: List[Tuple[str, str, Dict[str, List[dict]], Dict[str, str]]] = []
    for prepared in prepared_inputs:
        resolved_path = Path(prepared.resolved)
        res = process_zip(resolved_path)
        documents = load_documents(resolved_path)
        contexts = select_contexts(res, documents, fields=fields, limit_override=max_per_field)
        records.append((prepared.original.name, str(resolved_path), contexts, res.data.copy()))
    return records


def run_match(
    *,
    zip_paths: Sequence[Path],
    pdf_paths: Sequence[Path],
    limit: int | None,
    fields: Sequence[str] | None,
    device: int,
    model_name: str,
    min_score: float,
    max_per_field: int = 3,
) -> Dict[str, Dict[str, Dict[str, object]]]:
    prepared_inputs, tmp_dir = resolve_input_paths(zip_paths=zip_paths, pdf_paths=pdf_paths, limit=limit)
    try:
        if not prepared_inputs:
            return {}
        records = _prepare_records(prepared_inputs, fields, max_per_field=max_per_field)
        qa_inputs, metadata = _build_qa_inputs(records, fields, max_per_field=max_per_field)
        tokenizer = AutoTokenizer.from_pretrained(model_name, use_fast=True)
        qa_pipe = pipeline(
            "question-answering",
            model=model_name,
            tokenizer=tokenizer,
            device=device,
        )
        qa_payloads: Dict[str, Dict[str, List[dict]]] = {}
        if qa_inputs:
            # batch_size=1 e padding ajudam a evitar KeyError em mapeamentos char/token na HF
            answers = qa_pipe(qa_inputs, batch_size=1, padding=True)
            if isinstance(answers, dict):
                answers = [answers]
            for answer, (display_name, field, entry) in zip(answers, metadata):
                normalized = {
                    "answer": (answer.get("answer") or "").strip(),
                    "score": float(answer.get("score", 0.0)),
                    "source": entry.get("source"),
                }
                qa_payloads.setdefault(display_name, {}).setdefault(field, []).append(normalized)

        combined: Dict[str, Dict[str, Dict[str, object]]] = {}
        for display_name, _, _, regex_data in records:
            entry_fields = list(fields) if fields else sorted(set(list(regex_data.keys()) + list(qa_payloads.get(display_name, {}).keys())))
            field_map: Dict[str, Dict[str, object]] = {}
            for field in entry_fields:
                regex_value = regex_data.get(field, "")
                answers = qa_payloads.get(display_name, {}).get(field, [])
                best = None
                for candidate in answers:
                    if candidate["answer"] and candidate["score"] >= min_score:
                        if not best or candidate["score"] > best["score"]:
                            best = candidate
                field_map[field] = {
                    "regex": regex_value,
                    "qa": best["answer"] if best else "",
                    "qa_score": best["score"] if best else 0.0,
                    "qa_source": best["source"] if best else None,
                }
            combined[display_name] = field_map
        return combined
    finally:
        if tmp_dir:
            tmp_dir.cleanup()
