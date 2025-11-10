from __future__ import annotations

from dataclasses import dataclass
from typing import Callable

from ..browser import launch_session
from ..config import Settings
from ..navigation import iterar_paginas, login_and_open_bloco
from ..storage import build_zip_index, zip_exists

ProgressFn = Callable[[str], None] | None


@dataclass(slots=True)
class ProcessoResumo:
    numero: str
    descricao: str
    anotacao: str
    baixado: bool


@dataclass(slots=True)
class ResumoProcessos:
    total: int
    ok: int
    pendentes: int
    baixados: int
    faltando_zip: int


@dataclass(slots=True)
class ListaProcessosResultado:
    processos: list[ProcessoResumo]
    resumo: ResumoProcessos


def _log(message: str, progress: ProgressFn) -> None:
    if progress:
        progress(message)
    else:
        print(message)


def _safe_cell_text(row, index: int) -> str:
    try:
        return row.locator("td").nth(index).inner_text(timeout=3000).strip()
    except Exception:
        return ""


def listar_processos(
    settings: Settings,
    *,
    headless: bool = True,
    progress: ProgressFn = None,
    auto_credentials: bool = True,
    limite: int | None = None,
    somente_pendentes: bool = False,
    somente_ok: bool = False,
    somente_baixados: bool = False,
    somente_sem_zip: bool = False,
    summary_only: bool = False,
) -> ListaProcessosResultado:
    """Obtém a lista de processos do bloco configurado sem baixar arquivos."""

    if somente_pendentes and somente_ok:
        raise ValueError("Use apenas uma opção de filtro de anotação por vez.")
    if somente_baixados and somente_sem_zip:
        raise ValueError("Use apenas uma opção de filtro de download por vez.")

    resultados: list[ProcessoResumo] = []
    total = ok = baixados = 0
    zip_index = build_zip_index(settings.download_dir)
    with launch_session(headless=headless) as session:
        page = session.page
        login_and_open_bloco(page, settings, progress=progress, auto_credentials=auto_credentials)

        for row, numero in iterar_paginas(page, progress=progress):
            if limite is not None and len(resultados) >= limite:
                break

            descricao = _safe_cell_text(row, 3)
            anotacao = _safe_cell_text(row, 4)
            anotacao_limpa = anotacao.strip().upper()
            is_ok = anotacao_limpa == "OK"
            baixado = zip_exists(settings.download_dir, numero, cache=zip_index)

            total += 1
            if is_ok:
                ok += 1
            if baixado:
                baixados += 1

            incluir = True
            if somente_pendentes and is_ok:
                incluir = False
            if somente_ok and not is_ok:
                incluir = False
            if somente_baixados and not baixado:
                incluir = False
            if somente_sem_zip and baixado:
                incluir = False

            if not incluir:
                continue

            resumo = ProcessoResumo(numero=numero, descricao=descricao, anotacao=anotacao, baixado=baixado)
            resultados.append(resumo)
            if not summary_only:
                _log(
                    f"{len(resultados):03d} | {resumo.numero} | {resumo.descricao or '-'} | Anotação: {resumo.anotacao or '(vazia)'} | ZIP: {'Sim' if resumo.baixado else 'Não'}",
                    progress,
                )

    pendentes = total - ok
    faltando_zip = total - baixados
    resumo_contagem = ResumoProcessos(
        total=total,
        ok=ok,
        pendentes=pendentes,
        baixados=baixados,
        faltando_zip=faltando_zip,
    )

    _log(
        f"Resumo – Total: {total} | OK: {ok} | Pendentes: {pendentes} | ZIPs salvos: {baixados} | Sem ZIP: {faltando_zip}",
        progress,
    )

    return ListaProcessosResultado(processos=resultados, resumo=resumo_contagem)
