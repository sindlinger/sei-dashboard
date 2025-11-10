from __future__ import annotations

import argparse
import io
import re
import zipfile
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable, List

import pdfplumber
from bs4 import BeautifulSoup
from dateutil import parser as date_parser
from openpyxl import Workbook


LABEL_MAP = {
    "promovente": ["promovente", "requerente", "parte autora", "autor"],
    "promovido": ["promovido", "requerido", "parte ré", "réu"],
    "perito": ["perito", "perita"],
    "cpf": ["cpf", "cnpj"],
    "especialidade": ["especialidade", "área de atuação"],
    "especie": ["espécie de perícia", "espécie", "tipo de perícia"],
    "fator": ["fator"],
    "valor_tabelado": ["valor tabelado", "valor tabela"],
    "valor_arbitrado": ["valor arbitrado", "valor da perícia"],
    "checagem": ["checagem"],
    "data_adiantamento": ["data adiantamento", "data do adiantamento"],
    "checa_adiantamento": ["checagem adiantamento"],
    "data_autorizacao": ["data da autorização", "autorização da despesa"],
    "saldo_a_receber": ["saldo a receber"],
}

PROCESSO_NUM_PATTERN = re.compile(r"\d{7}-\d{2}\.\d{4}\.\d\.\d{2}\.\d{4}")
PROCESSO_ADMIN_PATTERN = re.compile(r"20\d{8}")
CPF_PATTERN = re.compile(r"\d{3}\.\d{3}\.\d{3}-\d{2}")
CNPJ_PATTERN = re.compile(r"\d{2}\.\d{3}\.\d{3}/\d{4}-\d{2}")
DATE_PATTERN = re.compile(
    r"\b\d{1,2}[-/ ]?(?:jan|fev|mar|abr|mai|jun|jul|ago|set|out|nov|dez)\.?-?\.?\d{2,4}\b",
    re.IGNORECASE,
)
JUÍZO_PATTERN = re.compile(r"\b\d+ª\s+Vara[^\n]+", re.IGNORECASE)
COMARCA_PATTERN = re.compile(r"Comarca\s+de\s+[A-Za-zÀ-ÿ ]+", re.IGNORECASE)

COLUMNS = [
    "Nº DE PERÍCIAS",
    "DATA DA REQUISIÇÃO",
    "PROCESSO ADMIN. Nº",
    "JUÍZO",
    "COMARCA",
    "PROCESSO Nº",
    "PROMOVENTE",
    "PROMOVIDO",
    "PERITO",
    "CPF/CNPJ",
    "ESPECIALIDADE",
    "ESPÉCIE DE PERÍCIA",
    "Fator",
    "Valor Tabelado Anexo I - Tabela I",
    "VALOR ARBITRADO",
    "CHECAGEM",
    "DATA ADIANTAMENTO",
    "R$",
    "%",
    "CHECAGEM ADIANTAMENTO",
    "Data da Autorização da Despesa",
    "SALDO A RECEBER",
    "ARQUIVO_ORIGEM",
    "OBSERVACOES",
]


@dataclass
class ExtractionResult:
    data: dict[str, str] = field(default_factory=dict)
    observations: List[str] = field(default_factory=list)

    def to_row(self, index: int, zip_name: str) -> list[str]:
        row = []
        for column in COLUMNS:
            if column == "Nº DE PERÍCIAS":
                row.append(f"{index:02d}")
            elif column == "ARQUIVO_ORIGEM":
                row.append(zip_name)
            elif column == "OBSERVACOES":
                row.append("; ".join(self.observations))
            else:
                row.append(self.data.get(column, ""))
        return row


def html_to_text(raw: bytes) -> str:
    soup = BeautifulSoup(raw, "html.parser")
    return soup.get_text("\n", strip=True)


def pdf_to_text(raw: bytes) -> str:
    with pdfplumber.open(io.BytesIO(raw)) as pdf:
        texts = [page.extract_text() or "" for page in pdf.pages]
    return "\n".join(texts)


def gather_texts(zip_path: Path) -> tuple[list[dict[str, str]], str]:
    sources: list[dict[str, str]] = []
    with zipfile.ZipFile(zip_path) as zf:
        for info in zf.infolist():
            if info.is_dir():
                continue
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
            else:
                continue
            sources.append({"name": name, "text": text})
    sources.sort(key=lambda s: ("despacho" not in s["name"].lower(), 0 if s["name"].lower().endswith(".html") else 1))
    combined = "\n".join(src["text"] for src in sources)
    return sources, combined


def extract_from_text(text: str, combined: str) -> ExtractionResult:
    res = ExtractionResult(data={})
    primary = text or combined
    lookup_text = primary if primary else combined
    if not lookup_text:
        res.observations.append("Sem texto legível no ZIP")
        return res

    res.data["PROCESSO Nº"] = _find_first(PROCESSO_NUM_PATTERN, lookup_text)
    res.data["PROCESSO ADMIN. Nº"] = _find_first(PROCESSO_ADMIN_PATTERN, lookup_text)
    res.data["JUÍZO"] = _find_first(JUÍZO_PATTERN, lookup_text)
    res.data["COMARCA"] = _find_first(COMARCA_PATTERN, lookup_text)

    res.data["PROMOVENTE"] = _extract_labeled_value(lookup_text, LABEL_MAP["promovente"])
    res.data["PROMOVIDO"] = _extract_labeled_value(lookup_text, LABEL_MAP["promovido"])

    perito = _extract_labeled_value(lookup_text, LABEL_MAP["perito"], max_chars=80)
    if not perito:
        # tenta encontrar em todo o texto combinado
        perito = _extract_labeled_value(combined, LABEL_MAP["perito"], max_chars=80)
    res.data["PERITO"] = perito

    cpf = _near_label_or_regex(lookup_text, LABEL_MAP["cpf"], [CPF_PATTERN, CNPJ_PATTERN])
    res.data["CPF/CNPJ"] = cpf

    res.data["ESPECIALIDADE"] = _extract_labeled_value(lookup_text, LABEL_MAP["especialidade"], max_chars=60)
    res.data["ESPÉCIE DE PERÍCIA"] = _extract_labeled_value(lookup_text, LABEL_MAP["especie"], max_chars=60)

    res.data["Fator"] = _extract_labeled_value(lookup_text, LABEL_MAP["fator"], max_chars=10)
    res.data["Valor Tabelado Anexo I - Tabela I"] = _extract_labeled_value(lookup_text, LABEL_MAP["valor_tabelado"], max_chars=40)
    res.data["VALOR ARBITRADO"] = _extract_labeled_value(lookup_text, LABEL_MAP["valor_arbitrado"], max_chars=40)
    res.data["CHECAGEM"] = _extract_labeled_value(lookup_text, LABEL_MAP["checagem"], max_chars=10)
    res.data["DATA ADIANTAMENTO"] = _extract_labeled_value(lookup_text, LABEL_MAP["data_adiantamento"], max_chars=40)
    res.data["CHECAGEM ADIANTAMENTO"] = _extract_labeled_value(lookup_text, LABEL_MAP["checa_adiantamento"], max_chars=20)
    res.data["Data da Autorização da Despesa"] = _extract_labeled_value(lookup_text, LABEL_MAP["data_autorizacao"], max_chars=40)
    res.data["SALDO A RECEBER"] = _extract_labeled_value(lookup_text, LABEL_MAP["saldo_a_receber"], max_chars=40)

    requisicao = _find_label_date(lookup_text, ["data da requisição", "data do requerimento"])
    res.data["DATA DA REQUISIÇÃO"] = requisicao

    # campos adicionais
    res.data["R$"] = res.data.get("VALOR ARBITRADO", "")
    res.data["%"] = _extract_percentage(lookup_text)

    # Observações para campos críticos ausentes
    for critical in ("PROCESSO Nº", "PERITO", "VALOR ARBITRADO"):
        if not res.data.get(critical):
            res.observations.append(f"Sem {critical}")

    return res


def _find_first(pattern: re.Pattern, text: str) -> str:
    if not text:
        return ""
    match = pattern.search(text)
    return match.group(0) if match else ""


def _extract_labeled_value(text: str, labels: Iterable[str], max_chars: int = 50) -> str:
    lowered = text.lower()
    for label in labels:
        key = label.lower()
        idx = lowered.find(key)
        if idx != -1:
            start = idx + len(key)
            snippet = text[start : start + max_chars]
            snippet = snippet.split("\n")[0]
            return snippet.strip(" :.-\t")
    return ""


def _near_label_or_regex(text: str, labels: Iterable[str], patterns: Iterable[re.Pattern]) -> str:
    value = _extract_labeled_value(text, labels, max_chars=30)
    if value:
        return value
    for pattern in patterns:
        found = _find_first(pattern, text)
        if found:
            return found
    return ""


def _find_label_date(text: str, labels: Iterable[str]) -> str:
    candidate = _extract_labeled_value(text, labels, max_chars=40)
    if candidate:
        parsed = _parse_date(candidate)
        return parsed or candidate
    match = DATE_PATTERN.search(text)
    if match:
        parsed = _parse_date(match.group(0))
        return parsed or match.group(0)
    return ""


def _parse_date(raw: str) -> str:
    try:
        dt = date_parser.parse(raw, dayfirst=True, fuzzy=True)
        return dt.strftime("%d/%m/%Y")
    except Exception:
        return ""


def _extract_percentage(text: str) -> str:
    match = re.search(r"(\d{1,3})%", text)
    return match.group(1) + "%" if match else ""


def process_zip(zip_path: Path) -> ExtractionResult:
    sources, combined = gather_texts(zip_path)
    primary_text = sources[0]["text"] if sources else combined
    result = extract_from_text(primary_text, combined)
    if not sources:
        result.observations.append("Nenhum documento legível no ZIP")
    return result


def write_excel(rows: list[list[str]], output: Path) -> None:
    wb = Workbook()
    ws = wb.active
    ws.title = "Pericias"
    ws.append(COLUMNS)
    for row in rows:
        ws.append(row)
    wb.save(output)


def main() -> None:
    parser = argparse.ArgumentParser(description="Extrai dados dos despachos do SEI a partir de ZIPs locais.")
    parser.add_argument("--zip-dir", type=Path, required=True, help="Diretório com os arquivos ZIP.")
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("relatorio-pericias.xlsx"),
        help="Caminho do arquivo XLSX de saída.",
    )
    parser.add_argument("--limit", type=int, default=None, help="Limita a quantidade de ZIPs processados.")
    args = parser.parse_args()

    zip_dir = args.zip_dir.expanduser()
    if not zip_dir.exists():
        raise SystemExit(f"Diretório não encontrado: {zip_dir}")

    zip_paths = sorted(path for path in zip_dir.glob("*.zip"))
    if args.limit:
        zip_paths = zip_paths[: args.limit]

    rows: list[list[str]] = []
    for idx, zip_path in enumerate(zip_paths, start=1):
        print(f"Processando {zip_path.name} ({idx}/{len(zip_paths)})...")
        result = process_zip(zip_path)
        rows.append(result.to_row(idx, zip_path.name))

    output = args.output
    output.parent.mkdir(parents=True, exist_ok=True)
    write_excel(rows, output)
    print(f"Relatório salvo em {output}")


if __name__ == "__main__":
    main()
