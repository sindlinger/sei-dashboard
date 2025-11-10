from __future__ import annotations

from typing import Callable

from playwright.sync_api import TimeoutError

from ..browser import launch_session
from ..config import Settings
from ..navigation import iterar_paginas, login_and_open_bloco

ProgressFn = Callable[[str], None] | None


def _log(message: str, progress: ProgressFn) -> None:
    if progress:
        progress(message)
    else:
        print(message)


def _atualizar_anotacao(row, numero: str, page, progress: ProgressFn) -> bool:
    icon = row.locator("td").nth(5).locator("img[title='Anotações']").first
    icon.click()
    page.wait_for_timeout(250)
    modal = page.frame(name="modal-frame")
    if modal is None:
        raise RuntimeError("Frame modal-frame não encontrado após abrir anotações.")
    modal.fill("#txtAnotacao", "OK")
    try:
        modal.locator("button[name='sbmAlterarRelBlocoProtocolo']").click()
        page.wait_for_selector("iframe[name='modal-frame']", state="detached", timeout=10000)
    except TimeoutError:
        _log(f"Aviso: modal não fechou automaticamente para {numero}", progress)
    page.wait_for_timeout(200)
    return True


def preencher_anotacoes_ok(
    settings: Settings,
    *,
    headless: bool = True,
    progress: ProgressFn = None,
    auto_credentials: bool = True,
) -> int:
    """
    Define o texto \"OK\" em todas as anotações ainda vazias do bloco.

    Returns:
        Quantidade de processos atualizados.
    """
    total_atualizados = 0
    with launch_session(headless=headless) as session:
        page = session.page
        login_and_open_bloco(page, settings, progress=progress, auto_credentials=auto_credentials)

        for row, numero in iterar_paginas(page, progress=progress):
            anotacao = row.locator("td").nth(4).inner_text(timeout=5000).strip()
            if anotacao == "OK":
                continue
            try:
                _log(f"Atualizando anotação de {numero}…", progress)
                if _atualizar_anotacao(row, numero, page, progress):
                    total_atualizados += 1
            except Exception as exc:  # noqa: BLE001
                _log(f"Falha ao atualizar {numero}: {exc}", progress)
            finally:
                page.bring_to_front()

    _log(f"Total de anotações atualizadas: {total_atualizados}", progress)
    return total_atualizados
