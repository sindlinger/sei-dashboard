from __future__ import annotations

import argparse
import csv
import io
import re
import zipfile
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

import pdfplumber
from bs4 import BeautifulSoup

CPF_PATTERN = re.compile(r"\d{3}\.\d{3}\.\d{3}-\d{2}")
CNPJ_PATTERN = re.compile(r"\d{2}\.\d{3}\.\d{3}/\d{4}-\d{2}")
PERITO_LABELS = ("perito", "perita")
ESPECIALIDADE_LABELS = ("especialidade", "área de atuação")


@dataclass
class PeritoInfo:
    nome: str = ""
    documento: str = ""
    especialidade: str = ""

    def merge(self, other: "PeritoInfo") -> "PeritoInfo":
        if not self.nome and other.nome:
            self.nome = other.nome
        if not self.documento and other.documento:
            self.documento = other.documento
        if not self.especialidade and other.especialidade:
            self.especialidade = other.especialidade
        return self


def html_to_text(raw: bytes) -> str:
    soup = BeautifulSoup(raw, "html.parser")
    return soup.get_text("\n", strip=True)


def pdf_to_text(raw: bytes) -> str:
    with pdfplumber.open(io.BytesIO(raw)) as pdf:
        texts = [page.extract_text() or "" for page in pdf.pages]
    return "\n".join(texts)


def gather_texts(zip_path: Path) -> list[str]:
    texts: list[str] = []
    with zipfile.ZipFile(zip_path) as zf:
        for info in zf.infolist():
            if info.is_dir():
                continue
            name = info.filename.lower()
            if not (name.endswith(".pdf") or name.endswith(".html")):
                continue
            try:
                raw = zf.read(info)
            except KeyError:
                continue
            if name.endswith(".html"):
                text = html_to_text(raw)
            else:
                try:
                    text = pdf_to_text(raw)
                except Exception:
                    continue
            if text:
                texts.append(text)
    return texts


def extract_perito_from_text(text: str) -> PeritoInfo:
    info = PeritoInfo()
    lines = text.splitlines()
    for line in lines:
        lower = line.lower()
        if any(label in lower for label in PERITO_LABELS) and ":" in line:
            after = line.split(":", 1)[1].strip()
            info.nome = _clean_name(after)
            doc = CPF_PATTERN.search(line) or CNPJ_PATTERN.search(line)
            if doc:
                info.documento = doc.group(0)
        if any(label in lower for label in ESPECIALIDADE_LABELS) and ":" in line:
            info.especialidade = line.split(":", 1)[1].strip()
        if info.nome and info.documento and info.especialidade:
            break
    if not info.documento:
        doc = CPF_PATTERN.search(text) or CNPJ_PATTERN.search(text)
        if doc:
            info.documento = doc.group(0)
    return info


def _clean_name(raw: str) -> str:
    tokens = raw.split("CPF", 1)[0]
    tokens = tokens.split("CNPJ", 1)[0]
    tokens = tokens.split("-", 1)[0]
    return tokens.strip(" -\t")


def process_zip(zip_path: Path) -> list[PeritoInfo]:
    texts = gather_texts(zip_path)
    results: list[PeritoInfo] = []
    for text in texts:
        info = extract_perito_from_text(text)
        if info.nome or info.documento:
            results.append(info)
    return results


def merge_catalog(entries: Iterable[PeritoInfo]) -> dict[str, PeritoInfo]:
    catalog: dict[str, PeritoInfo] = {}
    for entry in entries:
        key = entry.documento or entry.nome
        if not key:
            continue
        if key not in catalog:
            catalog[key] = entry
        else:
            catalog[key].merge(entry)
    return catalog


def main() -> None:
    parser = argparse.ArgumentParser(description="Gera um catálogo de peritos a partir dos ZIPs do SEI.")
    parser.add_argument("--zip-dir", type=Path, required=True, help="Diretório com os arquivos ZIP.")
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("peritos_catalogo.csv"),
        help="CSV de saída.",
    )
    parser.add_argument("--limit", type=int, default=None, help="Limite opcional de ZIPs processados.")
    args = parser.parse_args()

    zip_paths = sorted(Path(args.zip_dir).glob("*.zip"))
    if args.limit:
        zip_paths = zip_paths[: args.limit]

    collected: list[PeritoInfo] = []
    for idx, zip_path in enumerate(zip_paths, start=1):
        print(f"[Catálogo] Processando {zip_path.name} ({idx}/{len(zip_paths)})...")
        collected.extend(process_zip(zip_path))

    catalog = merge_catalog(collected)
    output = args.output
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", newline="", encoding="utf-8") as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow(["DOCUMENTO", "NOME", "ESPECIALIDADE"])
        for key, info in sorted(catalog.items()):
            writer.writerow([info.documento or "", info.nome, info.especialidade])

    print(f"Catálogo salvo em {output} com {len(catalog)} registros únicos.")


if __name__ == "__main__":
    main()
