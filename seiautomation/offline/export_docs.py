from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path
from zipfile import ZipFile, BadZipFile

from . import DocumentBucket


def _load_entries(path: Path, limit: int | None = None) -> list[dict]:
    entries: list[dict] = []
    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            if not line.strip():
                continue
            entry = json.loads(line)
            entries.append(entry)
            if limit and len(entries) >= limit:
                break
    return entries


def _ensure_dest(base: Path, zip_name: str, bucket: DocumentBucket) -> Path:
    stem = Path(zip_name).stem
    dest_dir = base / stem / bucket.value
    dest_dir.mkdir(parents=True, exist_ok=True)
    return dest_dir


def copy_documents(
    sources_jsonl: Path,
    output_dir: Path,
    bucket_filter: set[DocumentBucket] | None = None,
    limit: int | None = None,
) -> list[tuple[str, str]]:
    entries = _load_entries(sources_jsonl, limit=limit)
    copied: list[tuple[str, str]] = []
    for entry in entries:
        zip_name = entry.get("zip", "")
        zip_path_value = entry.get("zip_path")
        if not zip_path_value:
            continue
        zip_path = Path(zip_path_value)
        if not zip_path.exists():
            continue
        documents = entry.get("documents") or []
        try:
            with ZipFile(zip_path) as zf:
                members = set(zf.namelist())
                for doc in documents:
                    bucket_name = doc.get("bucket")
                    try:
                        bucket = DocumentBucket(bucket_name)
                    except ValueError:
                        continue
                    if bucket_filter and bucket not in bucket_filter:
                        continue
                    member_name = doc.get("name")
                    if not member_name or member_name not in members:
                        continue
                    dest_dir = _ensure_dest(output_dir, zip_name, bucket)
                    dest_path = dest_dir / Path(member_name).name
                    with zf.open(member_name) as src, dest_path.open("wb") as dst:
                        shutil.copyfileobj(src, dst)
                    copied.append((zip_name, str(dest_path)))
        except BadZipFile:
            continue
    return copied


def main() -> None:
    parser = argparse.ArgumentParser(description="Exporta documentos relevantes por processo/bucket.")
    parser.add_argument("--sources", required=True, type=Path, help="Arquivo JSONL gerado por extract_reports (run-id.sources.jsonl).")
    parser.add_argument("--output", required=True, type=Path, help="Diretório base onde os arquivos serão copiados.")
    parser.add_argument("--buckets", nargs="*", choices=[bucket.value for bucket in DocumentBucket], default=[DocumentBucket.PRINCIPAL.value, DocumentBucket.APOIO.value], help="Buckets que devem ser exportados (default: principal e apoio).")
    parser.add_argument("--limit", type=int, help="Processa apenas os primeiros N processos do JSONL.")
    args = parser.parse_args()

    buckets = {DocumentBucket(name) for name in args.buckets}
    copied = copy_documents(args.sources, args.output, bucket_filter=buckets, limit=args.limit)
    print(f"{len(copied)} arquivo(s) copiado(s).")


if __name__ == "__main__":
    main()
