from __future__ import annotations

from datetime import datetime
from threading import Thread

from sqlalchemy.orm import Session

from seiautomation.config import Settings as AutomationSettings

from .database import SessionLocal
from .models import TaskRun, User
from .schemas import TaskRunCreate
from .tasks_runner import execute_task, TASKS


def _append_log(db: Session, run: TaskRun, message: str) -> None:
    run.log = (run.log or "") + message + "\n"
    db.add(run)
    db.commit()


def _task_worker(run_id: str, user_id: int, request: TaskRunCreate) -> None:
    db = SessionLocal()
    try:
        run = db.query(TaskRun).get(run_id)
        user = db.query(User).get(user_id)
        if not run or not user:
            return

        run.status = "running"
        run.created_at = datetime.utcnow()
        db.commit()

        def progress(message: str) -> None:
            _append_log(db, run, message)

        try:
            execute_task(request, user, progress)
            run.status = "success"
        except Exception as exc:  # noqa: BLE001
            _append_log(db, run, f"Erro: {exc}")
            run.status = "failed"
        finally:
            run.finished_at = datetime.utcnow()
            db.commit()
    finally:
        db.close()


def enqueue_task(request: TaskRunCreate, user: User) -> TaskRun:
    if request.task_slug not in TASKS:
        raise ValueError("Tarefa não encontrada.")

    db = SessionLocal()
    try:
        run = TaskRun(
            task_name=TASKS[request.task_slug].name,
            params=request.model_dump(),
            status="pending",
            user_id=user.id,
        )
        db.add(run)
        db.commit()
        db.refresh(run)

        thread = Thread(target=_task_worker, args=(run.id, user.id, request), daemon=True)
        thread.start()
        return run
    finally:
        db.close()

