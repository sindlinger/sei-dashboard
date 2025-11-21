from __future__ import annotations

import argparse
import json
import logging
import re
from concurrent.futures import ProcessPoolExecutor, as_completed
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Tuple

from seiautomation.offline.extract_reports import (
    COLUMNS,
    ExtractionResult,
    process_zip,
)

from qa.context_selector import load_documents
from qa.questions import FIELD_QUESTIONS

LOGGER = logging.getLogger("build_dataset")


@dataclass
class QAExample:
    id: str
    question: str
    context: str
    answers: Dict[str, List[int | str]]
    metadata: Dict[str, str]

    def to_json(self) -> str:
        payload = {
            "id": self.id,
            "question": self.question,
            "context": self.context,
            "answers": self.answers,
            "metadata": self.metadata,
        }
        return json.dumps(payload, ensure_ascii=False)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Gera dataset QA (JSONL) a partir dos ZIPs extraídos do SEI.")
    parser.add_argument("--zip-dir", required=True, help="Diretório contendo os arquivos ZIP.")
    parser.add_argument("--output", required=True, help="Arquivo JSONL de saída.")
    parser.add_argument(
        "--fields",
        nargs="*",
        help="Campos a incluir (default: conjunto pré-definido). Use nomes como aparecem na planilha.",
    )
    parser.add_argument("--limit", type=int, help="Limita a quantidade de ZIPs processados.")
    parser.add_argument(
        "--window",
        type=int,
        default=220,
        help="Raio da janela em caracteres ao redor da resposta (default=220).",
    )
    parser.add_argument(
        "--allow-empty",
        action="store_true",
        help="Inclui perguntas sem resposta explícita (answers vazios) quando o valor não for encontrado.",
    )
    parser.add_argument(
        "--workers",
        type=int,
        default=1,
        help="Número de processos em paralelo (default=1).",
    )
    return parser.parse_args()


def _iter_zip_paths(zip_dir: Path) -> Iterable[Path]:
    for path in sorted(zip_dir.glob("*.zip")):
        if path.is_file():
            yield path


def _find_answer_span(context: str, answer: str) -> Optional[Tuple[int, int]]:
    if not answer:
        return None
    answer = answer.strip()
    if not answer:
        return None
    idx = context.find(answer)
    if idx != -1:
        return idx, idx + len(answer)
    # Permite flexibilizar espaços múltiplos.
    pattern = re.escape(answer)
    pattern = pattern.replace(r"\ ", r"\s+")
    match = re.search(pattern, context, flags=re.IGNORECASE)
    if match:
        return match.start(), match.end()
    return None


def _window_text(text: str, start: int, end: int, radius: int) -> Tuple[str, int]:
    begin = max(0, start - radius)
    finish = min(len(text), end + radius)
    snippet = text[begin:finish]
    return snippet, begin


def _build_example(
    zip_name: str,
    field: str,
    question: str,
    value: str,
    doc_name: str,
    doc_text: str,
    window_radius: int,
) -> Optional[QAExample]:
    span = _find_answer_span(doc_text, value)
    if span:
        start, end = span
        context, offset = _window_text(doc_text, start, end, window_radius)
        return QAExample(
            id=f"{zip_name}:{field}",
            question=question,
            context=context,
            answers={"text": [doc_text[start:end]], "answer_start": [start - offset]},
            metadata={
                "zip": zip_name,
                "field": field,
                "source": doc_name,
            },
        )
    return None


def _process_zip_worker(
    zip_path_str: str,
    fields: List[str],
    window: int,
    allow_empty: bool,
) -> Tuple[str, List[str], int, int]:
    zip_path = Path(zip_path_str)
    result: ExtractionResult = process_zip(zip_path)
    documents = load_documents(zip_path)
    combined_text = documents.get("combined") or "\n".join(documents.values())
    entries: List[str] = []
    skipped_fields = 0
    skipped_align = 0
    for field in fields:
        value = (result.data or {}).get(field, "")
        if not value:
            skipped_fields += 1
            continue
        question = FIELD_QUESTIONS.get(field, f"Qual é o valor do campo {field}?")
        doc_name = result.sources.get(field, "")
        context_text = documents.get(doc_name) or combined_text
        if not context_text:
            skipped_align += 1
            continue
        example = _build_example(
            zip_path.stem,
            field,
            question,
            value,
            doc_name or "combined",
            context_text,
            window,
        )
        if example:
            entries.append(example.to_json())
        elif allow_empty:
            entries.append(
                QAExample(
                    id=f"{zip_path.stem}:{field}",
                    question=question,
                    context=context_text[: 2 * window],
                    answers={"text": [], "answer_start": []},
                    metadata={
                        "zip": zip_path.stem,
                        "field": field,
                        "source": doc_name or "combined",
                        "note": "sem-resposta-explícita",
                    },
                ).to_json()
            )
        else:
            skipped_align += 1
    return zip_path.name, entries, skipped_fields, skipped_align


def main() -> None:
    args = parse_args()
    logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
    zip_dir = Path(args.zip_dir)
    if not zip_dir.exists():
        raise SystemExit(f"Diretório inexistente: {zip_dir}")

    fields = args.fields or list(FIELD_QUESTIONS.keys())
    invalid = [field for field in fields if field not in COLUMNS and field not in FIELD_QUESTIONS]
    if invalid:
        LOGGER.warning("Campos não reconhecidos (serão usados mesmo assim): %s", ", ".join(invalid))

    total_examples = 0
    skipped_fields = 0
    skipped_align = 0

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    zip_paths = list(_iter_zip_paths(zip_dir))
    if args.limit:
        zip_paths = zip_paths[: args.limit]

    results_map: Dict[str, Tuple[List[str], int, int]] = {}

    if args.workers and args.workers > 1:
        LOGGER.info("Processando %d ZIP(s) com %d worker(s)...", len(zip_paths), args.workers)
        with ProcessPoolExecutor(max_workers=args.workers) as executor:
            futures = {
                executor.submit(
                    _process_zip_worker,
                    str(zip_path),
                    fields,
                    args.window,
                    args.allow_empty,
                ): zip_path.name
                for zip_path in zip_paths
            }
            for idx, future in enumerate(as_completed(futures), start=1):
                name, lines, sf, sa = future.result()
                results_map[name] = (lines, sf, sa)
                if idx % 10 == 0 or idx == len(futures):
                    LOGGER.info("ZIPs concluídos: %d/%d", idx, len(futures))
    else:
        LOGGER.info("Processando %d ZIP(s) em modo sequencial...", len(zip_paths))
        for idx, zip_path in enumerate(zip_paths, start=1):
            name, lines, sf, sa = _process_zip_worker(
                str(zip_path), fields, args.window, args.allow_empty
            )
            results_map[name] = (lines, sf, sa)
            if idx % 10 == 0 or idx == len(zip_paths):
                LOGGER.info("ZIPs concluídos: %d/%d", idx, len(zip_paths))

    with output_path.open("w", encoding="utf-8") as fout:
        for zip_path in zip_paths:
            entry = results_map.get(zip_path.name)
            if not entry:
                continue
            lines, sf, sa = entry
            skipped_fields += sf
            skipped_align += sa
            for line in lines:
                fout.write(line + "\n")
                total_examples += 1

    LOGGER.info(
        "Dataset salvo em %s | exemplos: %d | campos ausentes: %d | alinhamento falhou: %d",
        output_path,
        total_examples,
        skipped_fields,
        skipped_align,
    )


if __name__ == "__main__":
    main()
