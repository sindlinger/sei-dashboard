from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..auth import get_current_active_user, get_current_admin
from ..database import get_db
from ..models import TaskRun, User
from ..schemas import TaskDefinition, TaskRunCreate, TaskRunRead
from ..task_executor import enqueue_task
from ..tasks_runner import list_tasks

router = APIRouter(prefix="/tasks", tags=["tasks"])


@router.get("/", response_model=list[TaskDefinition])
def get_tasks(current_user: User = Depends(get_current_active_user)):
    return list(list_tasks())


@router.post("/run", response_model=TaskRunRead)
def run_task(
    payload: TaskRunCreate,
    current_user: User = Depends(get_current_active_user),
) -> TaskRunRead:
    run = enqueue_task(payload, current_user)
    return TaskRunRead.model_validate(run)


@router.get("/runs", response_model=list[TaskRunRead])
def list_runs(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
) -> list[TaskRunRead]:
    query = db.query(TaskRun)
    if not current_user.is_admin:
        query = query.filter(TaskRun.user_id == current_user.id)
    runs = query.order_by(TaskRun.created_at.desc()).limit(50).all()
    return [TaskRunRead.model_validate(run) for run in runs]


@router.get("/runs/{run_id}", response_model=TaskRunRead)
def get_run(
    run_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
) -> TaskRunRead:
    run = db.query(TaskRun).filter(TaskRun.id == run_id).first()
    if not run:
        raise HTTPException(status_code=404, detail="Execução não encontrada.")
    if not current_user.is_admin and run.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Acesso negado.")
    return TaskRunRead.model_validate(run)
