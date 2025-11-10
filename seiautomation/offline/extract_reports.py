from __future__ import annotations

import argparse
import io
import re
import zipfile
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable, List, Sequence

import pdfplumber
from bs4 import BeautifulSoup
from dateutil import parser as date_parser
from openpyxl import Workbook


PROMOVENTE_LABELS = ("promovente", "parte autora", "autor", "requerente")
PROMOVIDO_LABELS = ("promovido", "requerido", "parte ré", "réu", "demandado")
PERITO_LABELS = ("perito", "perita")
CPF_LABELS = ("cpf", "cnpj")
ESPECIALIDADE_LABELS = ("especialidade", "área de atuação")
ESPECIE_LABELS = ("espécie de perícia", "espécie", "tipo de perícia")
FATOR_LABELS = ("fator",)
VALOR_TABELA_LABELS = ("valor tabelado", "valor tabela")
VALOR_ARBITRADO_LABELS = ("valor arbitrado", "valor da perícia", "honorários")
CHECAGEM_LABELS = ("checagem",)
DATA_ADIANTAMENTO_LABELS = ("data adiantamento", "data do adiantamento")
CHECAGEM_ADIANT_LABELS = ("checagem adiantamento",)
DATA_AUTORIZACAO_LABELS = ("data da autorização", "autorização da despesa")
SALDO_LABELS = ("saldo a receber",)

PROCESSO_NUM_PATTERN = re.compile(r"\d{7}-\d{2}\.\d{4}\.\d\.\d{2}\.\d{4}")
PROCESSO_ADMIN_PATTERN = re.compile(r"20\d{8}")
CPF_PATTERN = re.compile(r"\d{3}\.\d{3}\.\d{3}-\d{2}")
CNPJ_PATTERN = re.compile(r"\d{2}\.\d{3}\.\d{3}/\d{4}-\d{2}")
PERITO_PARAGRAPH_PATTERN = re.compile(
    r"Perit[oa]\s+(?P<esp>[^,]+),\s*(?P<nome>[A-Za-zÀ-ÿ' ]+),\s*CPF\s*(?P<cpf>\d{3}\.\d{3}\.\d{3}-\d{2})",
    re.IGNORECASE,
)
DATE_PATTERN = re.compile(
    r"\b\d{1,2}[-/ ]?(?:jan|fev|mar|abr|mai|jun|jul|ago|set|out|nov|dez)\.?-?\.?\d{2,4}\b",
    re.IGNORECASE,
)
JUÍZO_PATTERN = re.compile(r"\b\d+ª\s+Vara[^\n]+", re.IGNORECASE)
COMARCA_PATTERN = re.compile(r"Comarca\s+de\s+[A-Za-zÀ-ÿ ]+", re.IGNORECASE)
PARTES_REGEX = re.compile(
    r"movid[oa]\s+por\s+(?P<promovente>[^,\n]+?)(?:,|\s+CPF|\s+CNPJ|\se[mn]\s+face)"
    r"[^\n]*?em\s+face\s+de\s+(?P<promovido>[^,\n]+)",
    re.IGNORECASE,
)

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

    lines = _prepare_lines(lookup_text)

    res.data["PROCESSO Nº"] = _find_first(PROCESSO_NUM_PATTERN, lookup_text)
    res.data["PROCESSO ADMIN. Nº"] = _find_first(PROCESSO_ADMIN_PATTERN, lookup_text)
    res.data["JUÍZO"] = _find_first(JUÍZO_PATTERN, lookup_text)
    res.data["COMARCA"] = _find_first(COMARCA_PATTERN, lookup_text)

    if not res.data["JUÍZO"]:
        req_line = _line_value(lines, ("juízo", "vara"))
        if req_line:
            res.data["JUÍZO"] = req_line

    promovente, promovido = _extract_partes(lines, lookup_text)
    if promovente:
        res.data["PROMOVENTE"] = promovente
    else:
        res.data["PROMOVENTE"] = _line_value(lines, PROMOVENTE_LABELS)
    if promovido:
        res.data["PROMOVIDO"] = promovido
    else:
        res.data["PROMOVIDO"] = _line_value(lines, PROMOVIDO_LABELS)

    perito_info = _extract_perito_info(lines)
    if perito_info.nome:
        res.data["PERITO"] = perito_info.nome
    if perito_info.documento:
        res.data["CPF/CNPJ"] = perito_info.documento
    if perito_info.especialidade:
        res.data["ESPECIALIDADE"] = perito_info.especialidade
    else:
        res.data["ESPECIALIDADE"] = _line_value(lines, ESPECIALIDADE_LABELS)
    res.data["ESPÉCIE DE PERÍCIA"] = _line_value(lines, ESPECIE_LABELS)

    res.data["Fator"] = _line_value(lines, FATOR_LABELS)
    res.data["Valor Tabelado Anexo I - Tabela I"] = _line_value(lines, VALOR_TABELA_LABELS)

    valor_arbitrado = _line_value(lines, VALOR_ARBITRADO_LABELS)
    if not valor_arbitrado:
        valor_arbitrado = _first_currency(lines, keywords=("honor", "perícia", "perito"))
    res.data["VALOR ARBITRADO"] = valor_arbitrado

    res.data["CHECAGEM"] = _line_value(lines, CHECAGEM_LABELS)
    res.data["DATA ADIANTAMENTO"] = _line_value(lines, DATA_ADIANTAMENTO_LABELS)
    res.data["CHECAGEM ADIANTAMENTO"] = _line_value(lines, CHECAGEM_ADIANT_LABELS)
    res.data["Data da Autorização da Despesa"] = _line_value(lines, DATA_AUTORIZACAO_LABELS)
    res.data["SALDO A RECEBER"] = _line_value(lines, SALDO_LABELS)

    requisicao = _find_label_date(lookup_text, ["data da requisição", "data do requerimento", "campina grande", "joão pessoa", "patos", "sousa"])
    res.data["DATA DA REQUISIÇÃO"] = requisicao

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


@dataclass
class PeritoInfo:
    nome: str = ""
    documento: str = ""
    especialidade: str = ""


def _prepare_lines(text: str) -> list[str]:
    return [line.strip() for line in text.splitlines() if line.strip()]


def _line_value(lines: Sequence[str], labels: Iterable[str]) -> str:
    for line in lines:
        lower = line.lower()
        for label in labels:
            lbl = label.lower()
            if lower.startswith(lbl + ":"):
                return _clean_after_colon(line)
            if lbl in lower and ":" in line:
                before, after = line.split(":", 1)
                if lbl in before.lower():
                    return _clean_after_colon(line)
    return ""


def _clean_after_colon(line: str) -> str:
    after = line.split(":", 1)[1].strip()
    after = after.split(" – ")[0]
    after = after.split(" - ")[0]
    return after.strip()


def _extract_perito_info(lines: Sequence[str]) -> PeritoInfo:
    info = PeritoInfo()
    doc_text = "\n".join(lines)

    def candidate_lines(predicate):
        return [line for line in lines if predicate(line.lower())]

    preferred = candidate_lines(lambda l: "interessado" in l and "perit" in l)
    if not preferred:
        preferred = candidate_lines(lambda l: l.startswith("perito") or l.startswith("perita"))
    if not preferred:
        preferred = candidate_lines(lambda l: "perito" in l)

    for line in preferred:
        lower = line.lower()
        if "cpf" not in lower and ":" not in line:
            continue
        if "interessado" in lower and ":" in line:
            info.nome = _clean_after_colon(line)
            tail = line.split("–", 1)[1] if "–" in line else line.split("-", 1)[-1]
            info.especialidade = tail.split("-", 1)[0].strip()
        elif "cpf" in lower and "," in line:
            match = PERITO_PARAGRAPH_PATTERN.search(line)
            if match:
                info.nome = match.group("nome").strip()
                info.documento = match.group("cpf")
                info.especialidade = match.group("esp").strip()
        else:
            info.nome = line.split(" – ")[0].split(" - ")[0].strip()

        doc = CPF_PATTERN.search(line) or CNPJ_PATTERN.search(line)
        if doc:
            info.documento = doc.group(0)

        if not info.especialidade and "–" in line:
            info.especialidade = line.split("–", 1)[1].split("-", 1)[0].strip()
        elif not info.especialidade and "-" in line:
            info.especialidade = line.split("-", 1)[1].strip()
        if info.nome:
            break

    if not info.nome:
        match = PERITO_PARAGRAPH_PATTERN.search(doc_text)
        if match:
            info.nome = match.group("nome").strip()
            info.documento = match.group("cpf")
            info.especialidade = match.group("esp").strip()

    if not info.documento:
        doc = CPF_PATTERN.search(doc_text) or CNPJ_PATTERN.search(doc_text)
        if doc:
            info.documento = doc.group(0)
    return info


def _extract_partes(lines: Sequence[str], text: str) -> tuple[str, str]:
    match = PARTES_REGEX.search(text)
    if match:
        prom = _clean_entity(match.group("promovente"))
        prov = _clean_entity(match.group("promovido"))
        return prom, prov

    prom = _line_value(lines, PROMOVENTE_LABELS + ("autor", "parte autora", "exequente"))
    prov = _line_value(lines, PROMOVIDO_LABELS + ("réu", "executado", "parte ré"))
    return prom, prov


def _clean_entity(value: str) -> str:
    if not value:
        return ""
    value = value.split("CPF", 1)[0]
    value = value.split("CNPJ", 1)[0]
    value = value.replace("-", " ").strip()
    return value


def _first_currency(lines: Sequence[str], keywords: Iterable[str] | None = None) -> str:
    pattern = re.compile(r"R\$\s*[\d\.]+,\d{2}")
    for line in lines:
        lower = line.lower()
        if "r$" not in lower:
            continue
        if keywords and not any(keyword in lower for keyword in keywords):
            continue
        match = pattern.search(line)
        if match:
            return match.group(0)
    return ""


def _find_label_date(text: str, labels: Iterable[str]) -> str:
    lines = _prepare_lines(text)
    candidate = _line_value(lines, labels)
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
