from __future__ import annotations

import os
from pathlib import Path
from typing import Callable, Iterable

from playwright.sync_api import Locator, Page, TimeoutError

from ..browser import launch_session
from ..config import Settings
from ..navigation import iterar_paginas, login_and_open_bloco
from ..storage import sanitize_processo_numero, zip_exists

ProgressFn = Callable[[str], None] | None


def _log(message: str, progress: ProgressFn) -> None:
    if progress:
        progress(message)
    else:
        print(message)


def _baixar_zip_de_linha(
    row: Locator, page: Page, numero: str, download_dir: Path, progress: ProgressFn
) -> str | None:
    sanitized = sanitize_processo_numero(numero)
    context = page.context
    row_link = row.locator("td").nth(2).locator("a").first
    with context.expect_page() as popup_info:
        row_link.click()
    popup = popup_info.value
    popup.wait_for_load_state("domcontentloaded")

    frame = popup.frame(name="ifrConteudoVisualizacao")
    if frame is None:
        popup.close()
        raise RuntimeError("iframe ifrConteudoVisualizacao não encontrado ao abrir processo.")

    frame.locator("img[title='Gerar Arquivo ZIP do Processo']").click()
    zip_frame = popup.frame(name="ifrVisualizacao")
    if zip_frame is None:
        popup.close()
        raise RuntimeError("iframe ifrVisualizacao não encontrado ao gerar ZIP.")

    zip_frame.wait_for_load_state("domcontentloaded")
    radio = zip_frame.locator("label:has-text('Todos os documentos disponíveis') input[type='radio']")
    if radio.count() and not radio.first.is_checked():
        radio.first.check()

    with popup.expect_download() as download_info:
        zip_frame.locator("a:has-text('Gerar'), button:has-text('Gerar')").first.click()
    download = download_info.value
    suggested = download.suggested_filename.replace(" ", "_")
    filename = f"{sanitized}_{suggested}"
    download.save_as(str(download_dir / filename))
    popup.close()
    _log(f"ZIP salvo: {filename}", progress)
    return filename


def download_zip_lote(
    settings: Settings,
    *,
    headless: bool = True,
    progress: ProgressFn = None,
    skip_existentes: bool = True,
    limite: int | None = None,
    auto_credentials: bool = True,
) -> Iterable[str]:
    """
    Faz o download em lote dos ZIPs do bloco configurado.

    Args:
        settings: configurações carregadas.
        headless: executa navegador em modo headless.
        progress: função opcional para atualizar status.
        skip_existentes: se True, não baixa novamente arquivos já existentes.
        limite: limita quantidade de processos a baixar (útil para testes).

    Returns:
        Um iterável com os nomes dos arquivos ZIP criados ou reutilizados.
    """

    arquivos_gerados: list[str] = []
    with launch_session(headless=headless) as session:
        page = session.page
        login_and_open_bloco(page, settings, progress=progress, auto_credentials=auto_credentials)
        download_dir = settings.download_dir

        contador = 0
        for row, numero in iterar_paginas(page, progress=progress):
            if limite is not None and contador >= limite:
                break
            if skip_existentes and zip_exists(download_dir, numero):
                _log(f"Pulando {numero} (já existe ZIP)", progress)
                contador += 1
                continue
            try:
                arquivo = _baixar_zip_de_linha(row, page, numero, download_dir, progress)
                if arquivo:
                    arquivos_gerados.append(arquivo)
            except TimeoutError:
                _log(f"Tempo esgotado ao baixar {numero}", progress)
            except Exception as exc:  # noqa: BLE001
                _log(f"Falha ao baixar {numero}: {exc}", progress)
            finally:
                contador += 1
                page.bring_to_front()

    return arquivos_gerados
