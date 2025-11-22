from __future__ import annotations

import zipfile
from dataclasses import dataclass
from pathlib import Path
from tempfile import TemporaryDirectory
from typing import List, Sequence, Tuple
from uuid import uuid4


@dataclass
class PreparedInput:
    original: Path
    resolved: Path
    kind: str  # "zip", "pdf" ou "txt"


def _pack_single_file(path: Path, temp_dir: TemporaryDirectory) -> Path:
    stem = path.stem or "document"
    dest = Path(temp_dir.name) / f"{stem}-{uuid4().hex}.zip"
    with zipfile.ZipFile(dest, "w") as zf:
        zf.write(path, arcname=path.name)
    return dest


def resolve_input_paths(
    *,
    zip_paths: Sequence[Path] | None = None,
    pdf_paths: Sequence[Path] | None = None,
    limit: int | None = None,
) -> Tuple[List[PreparedInput], TemporaryDirectory | None]:
    tmp_dir: TemporaryDirectory | None = None
    prepared: List[PreparedInput] = []

    ordered: List[Path] = []
    if zip_paths:
        ordered.extend(sorted(zip_paths))
    if pdf_paths:
        ordered.extend(sorted(pdf_paths))

    if limit is not None and limit >= 0:
        ordered = ordered[:limit]

    for path in ordered:
        suffix = path.suffix.lower()
        if suffix == ".zip":
            prepared.append(PreparedInput(original=path, resolved=path, kind="zip"))
        elif suffix in {".pdf", ".txt"}:
            kind = suffix.lstrip(".") or "pdf"
            prepared.append(PreparedInput(original=path, resolved=path, kind=kind))
        else:
            # formato não suportado; apenas ignore
            continue

    return prepared, tmp_dir
