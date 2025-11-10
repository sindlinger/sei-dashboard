from __future__ import annotations

from contextlib import contextmanager
from dataclasses import dataclass
from typing import Iterator

from playwright.sync_api import Browser, BrowserContext, Page, sync_playwright


@dataclass(slots=True)
class BrowserSession:
    browser: Browser
    context: BrowserContext
    page: Page


@contextmanager
def launch_session(headless: bool = True) -> Iterator[BrowserSession]:
    with sync_playwright() as p:
        browser = p.chromium.launch(
            headless=headless,
            args=[
                "--disable-dev-shm-usage",
                "--no-sandbox",
            ],
        )
        context = browser.new_context(accept_downloads=True)
        page = context.new_page()
        try:
            yield BrowserSession(browser=browser, context=context, page=page)
        finally:
            context.close()
            browser.close()

