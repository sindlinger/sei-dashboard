"""
Exporta documentos classificados como LAUDO para pastas organizadas por espécie.

Fonte: logs/extract/<run-id>.sources.jsonl gerado pelo pipeline offline relatorio.
Saída: arquivos extraídos em outputs/laudos_por_especie/<ESPECIE>/<ZIP>/<docname>
       mais um CSV com metadados.
"""

from __future__ import annotations

import csv
import json
import re
import zipfile
from io import BytesIO
from pathlib import Path
from typing import Iterable, Optional

from PyPDF2 import PdfReader
# Ajuste aqui se quiser usar outro run-id ou outro diretório de ZIPs.
RUN_ID = "extract-20251121-220053-e5fa0f"
ZIP_DIR = Path("playwright-downloads")
LOG_PATH = Path("logs/extract") / f"{RUN_ID}.sources.jsonl"
OUTPUT_ROOT = Path("outputs/laudos_por_especie")
CSV_PATH = OUTPUT_ROOT / "laudos_por_especie.csv"

# Palavras-chave simples para “leitura semântica” (marcar presença no laudo).
KEYWORDS = [
    "engenharia",
    "engenheiro",
    "arquiteto",
    "arquiteta",
    "médico",
    "medico",
    "psicólogo",
    "psicologa",
    "psicologia",
    "assistente social",
    "estudo social",
    "odont",
    "grafotécnic",
    "contábil",
    "contabil",
    "balística",
    "ambiental",
    "topográf",
    "avaliação",
]


def iter_records(log_path: Path):
    with log_path.open("r", encoding="utf-8") as f:
        for line in f:
            yield json.loads(line)


def get_species(rec: dict) -> str:
    for fld in rec.get("fields", []):
        if fld.get("field") == "ESPÉCIE DE PERÍCIA":
            return fld.get("value", "").strip()
    return ""


def get_especialidade(rec: dict) -> str:
    for fld in rec.get("fields", []):
        if fld.get("field") == "ESPECIALIDADE":
            return fld.get("value", "").strip()
    return ""


def sanitize_folder(name: str) -> str:
    if not name:
        return "SEM_ESPECIE"
    safe = re.sub(r"[\\/:*?\"<>|]", "_", name)
    return safe.strip() or "SEM_ESPECIE"


def find_member(zf: zipfile.ZipFile, docname: str) -> Optional[str]:
    # Tenta match exato; se não achar, procura por sufixo igual.
    names = zf.namelist()
    if docname in names:
        return docname
    matches = [n for n in names if n.endswith(docname)]
    return matches[0] if matches else None


def extract_keywords(text: str, keywords: Iterable[str]) -> str:
    lower = text.lower()
    found = [k for k in keywords if k in lower]
    return ";".join(sorted(set(found)))


def read_doc_text(data: bytes, name: str) -> str:
    n = name.lower()
    if n.endswith(".pdf"):
        try:
            reader = PdfReader(BytesIO(data))
            return " ".join(p.extract_text() or "" for p in reader.pages)
        except Exception:
            return ""
    try:
        return data.decode("utf-8", errors="ignore")
    except Exception:
        return ""


def main():
    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    rows = []

    for rec in iter_records(LOG_PATH):
        zip_name = rec.get("zip")
        specie = get_species(rec)
        especialidade = get_especialidade(rec)
        laudo_docs = [d for d in rec.get("documents", []) if d.get("bucket") == "laudo"]
        if not laudo_docs:
            continue
        zip_path = ZIP_DIR / zip_name
        if not zip_path.exists():
            continue

        specie_folder = OUTPUT_ROOT / sanitize_folder(specie)
        for doc in laudo_docs:
            docname = doc.get("name")
            with zipfile.ZipFile(zip_path) as zf:
                member = find_member(zf, docname)
                if not member:
                    continue
                data = zf.read(member)
            target_dir = specie_folder / zip_name
            target_dir.mkdir(parents=True, exist_ok=True)
            target_file = target_dir / docname
            target_file.write_bytes(data)

            # “Leitura semântica”: marca palavras-chave simples presentes no texto (somente para HTML/texto).
            keywords_found = ""
            try:
                text = data.decode("utf-8", errors="ignore")
                keywords_found = extract_keywords(text, KEYWORDS)
            except Exception:
                keywords_found = ""

            rows.append(
                [
                    zip_name,
                    docname,
                    specie or "",
                    especialidade or "",
                    str(target_file),
                    keywords_found,
                ]
            )

    CSV_PATH.parent.mkdir(parents=True, exist_ok=True)
    with CSV_PATH.open("w", newline="", encoding="utf-8") as fo:
        writer = csv.writer(fo)
        writer.writerow(
            ["ZIP", "LAUDO", "ESPÉCIE DE PERÍCIA", "ESPECIALIDADE", "DESTINO", "KEYWORDS"]
        )
        writer.writerows(rows)

    print(f"Extraídos {len(rows)} laudos para {OUTPUT_ROOT}")
    print(f"CSV: {CSV_PATH}")


if __name__ == "__main__":
    main()
