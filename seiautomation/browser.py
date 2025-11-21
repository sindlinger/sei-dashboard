from __future__ import annotations

import os
from contextlib import contextmanager
from dataclasses import dataclass
from pathlib import Path
from typing import Iterator

from playwright.sync_api import Browser, BrowserContext, Page, sync_playwright

from seiautomation.config import Settings


_TMP_ENV_VARS = ("TMPDIR", "TEMP", "TMP")


def _is_windows_mount(path: Path) -> bool:
    """Detecta se o caminho reside em /mnt (filesystem do Windows)."""

    try:
        resolved = path.expanduser().resolve(strict=False)
    except Exception:  # noqa: BLE001
        resolved = path.expanduser()
    return str(resolved).startswith("/mnt/")


def _prepare_wsl_environment() -> None:
    """Garante que Playwright use diretórios locais ao rodar no WSL."""

    if "WSL_DISTRO_NAME" not in os.environ:
        return

    safe_tmp = Path("/tmp/seiautomation-playwright")
    safe_tmp.mkdir(parents=True, exist_ok=True)
    for key in _TMP_ENV_VARS:
        current = os.environ.get(key)
        if not current or current.startswith("/mnt/"):
            os.environ[key] = str(safe_tmp)

    browsers_dir = Path.home() / ".seiautomation-playwright-browsers"
    if _is_windows_mount(browsers_dir):
        browsers_dir = Path("/tmp/seiautomation-playwright-browsers")
    browsers_dir.mkdir(parents=True, exist_ok=True)

    current_path = os.environ.get("PLAYWRIGHT_BROWSERS_PATH")
    if not current_path or current_path.startswith("/mnt/"):
        os.environ["PLAYWRIGHT_BROWSERS_PATH"] = str(browsers_dir)


_prepare_wsl_environment()


@dataclass(slots=True)
class BrowserSession:
    browser: Browser
    context: BrowserContext
    page: Page


@contextmanager
def launch_session(headless: bool = True) -> Iterator[BrowserSession]:
    settings = Settings.load()
    entry_url = settings.process_list_url or settings.base_url

    with sync_playwright() as p:
        browser = p.chromium.launch(
            headless=headless,
            args=[
                "--disable-dev-shm-usage",
                "--no-sandbox",
            ],
        )
        context = browser.new_context(accept_downloads=True, user_agent=settings.user_agent)
        page = context.new_page()
        page.goto(entry_url, wait_until="domcontentloaded")
        try:
            yield BrowserSession(browser=browser, context=context, page=page)
        finally:
            context.close()
            browser.close()
