"""
Atribui um score de confiança às espécies de laudos já revisadas.

Le:
  outputs/laudos_por_especie/laudos_por_especie_revisado.csv
Escreve:
  outputs/laudos_por_especie/laudos_por_especie_scored.csv

Heurística simples de score (0 a 1):
  - origem conselho:*        -> 0.95
  - origem texto             -> 0.85
  - origem especialidade     -> 0.80
  - origem auto              -> 0.75
  - sem_match                -> 0.10
  - qualquer outro caso      -> 0.50
Se ESPECIE_REV for SEM_ESPECIE, força score = 0.05.
"""

from __future__ import annotations

import csv
from pathlib import Path

IN_CSV = Path("outputs/laudos_por_especie/laudos_por_especie_revisado.csv")
OUT_CSV = Path("outputs/laudos_por_especie/laudos_por_especie_scored.csv")


def score_row(especie_rev: str, origem: str) -> tuple[float, str]:
    esp_lower = (especie_rev or "").lower()
    if esp_lower == "sem_especie":
        return 0.05, "sem_especie"

    orig_lower = (origem or "").lower()
    if orig_lower.startswith("conselho:"):
        return 0.95, "conselho"
    if orig_lower == "texto":
        return 0.85, "texto"
    if orig_lower == "especialidade":
        return 0.80, "especialidade"
    if orig_lower == "auto":
        return 0.75, "auto"
    if orig_lower == "sem_match":
        return 0.10, "sem_match"
    return 0.50, "default"


def main() -> None:
    rows = list(csv.reader(IN_CSV.open("r", encoding="utf-8")))
    header = rows[0]
    data = rows[1:]

    out_rows = [header + ["CONF_SCORE", "CONF_SOURCE"]]
    for r in data:
        # r = [zip, doc, especie, especialidade, dest, kws, especie_auto, especie_rev, origem_rev]
        especie_rev = r[7] if len(r) > 7 else ""
        origem = r[8] if len(r) > 8 else ""
        score, reason = score_row(especie_rev, origem)
        out_rows.append(r + [f"{score:.2f}", reason])

    OUT_CSV.parent.mkdir(parents=True, exist_ok=True)
    with OUT_CSV.open("w", newline="", encoding="utf-8") as fo:
        writer = csv.writer(fo)
        writer.writerows(out_rows)
    print(f"Score escrito em {OUT_CSV}")


if __name__ == "__main__":
    main()

