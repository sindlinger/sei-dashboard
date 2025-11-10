from __future__ import annotations

from dataclasses import dataclass
from typing import Callable, Dict, Iterable

from seiautomation.config import Settings as AutomationSettings
from seiautomation.tasks import download_zip_lote, preencher_anotacoes_ok

from .models import User
from .schemas import TaskDefinition, TaskRunCreate


@dataclass(slots=True, frozen=True)
class RegisteredTask:
    slug: str
    name: str
    description: str
    handler: Callable[[AutomationSettings, TaskRunCreate, User, Callable[[str], None]], None]


def _download_handler(
    settings: AutomationSettings,
    request: TaskRunCreate,
    user: User,
    progress: Callable[[str], None],
) -> None:
    download_zip_lote(
        settings,
        headless=request.headless,
        progress=progress,
        skip_existentes=True,
        limite=request.limit,
        auto_credentials=request.auto_credentials,
    )


def _annotate_handler(
    settings: AutomationSettings,
    request: TaskRunCreate,
    user: User,
    progress: Callable[[str], None],
) -> None:
    preencher_anotacoes_ok(
        settings,
        headless=request.headless,
        progress=progress,
        auto_credentials=request.auto_credentials,
    )


TASKS: Dict[str, RegisteredTask] = {
    "download_zip": RegisteredTask(
        slug="download_zip",
        name="Download de ZIPs",
        description="Baixa todos os processos do bloco configurado em formato ZIP.",
        handler=_download_handler,
    ),
    "annotate_ok": RegisteredTask(
        slug="annotate_ok",
        name="Atualizar anotações",
        description='Preenche o campo "Anotações" com o texto OK para os processos do bloco.',
        handler=_annotate_handler,
    ),
}


def list_tasks() -> Iterable[TaskDefinition]:
    for task in TASKS.values():
        yield TaskDefinition(name=task.name, slug=task.slug, description=task.description)


def execute_task(
    task_request: TaskRunCreate,
    user: User,
    progress: Callable[[str], None],
) -> None:
    task = TASKS.get(task_request.task_slug)
    if not task:
        raise ValueError("Tarefa desconhecida.")

    auto_credentials = task_request.auto_credentials and user.allow_auto_credentials
    if task_request.auto_credentials and not user.allow_auto_credentials:
        progress("Aviso: usuário não tem permissão para auto-preenchimento. Continuando em modo manual.")

    automation_settings = AutomationSettings.load()
    task.handler(
        automation_settings,
        TaskRunCreate(
            task_slug=task_request.task_slug,
            headless=task_request.headless,
            auto_credentials=auto_credentials,
            limit=task_request.limit,
        ),
        user,
        progress,
    )

