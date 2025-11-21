from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path
from typing import Iterable, List, Optional, Sequence

LOG_DIR = Path(__file__).resolve().parents[1] / "logs"


@dataclass
class LogEntry:
    run_id: str
    log_path: Path
    state_path: Optional[Path]
    mtime: datetime
    size_bytes: int


def _iter_logs() -> Iterable[LogEntry]:
    if not LOG_DIR.exists():
        return []
    entries: List[LogEntry] = []
    for log_file in LOG_DIR.glob("*.log"):
        state = log_file.with_suffix(".state.json")
        try:
            stat = log_file.stat()
        except FileNotFoundError:
            continue
        entries.append(
            LogEntry(
                run_id=log_file.stem,
                log_path=log_file,
                state_path=state if state.exists() else None,
                mtime=datetime.fromtimestamp(stat.st_mtime),
                size_bytes=stat.st_size,
            )
        )
    entries.sort(key=lambda e: e.mtime, reverse=True)
    return entries


def list_logs(limit: int | None = None) -> List[LogEntry]:
    entries = list(_iter_logs())
    if limit is not None:
        entries = entries[: limit]
    return entries


def show_log(run_id: str, tail: bool = False, lines: int = 50) -> str:
    log_path = LOG_DIR / f"{run_id}.log"
    if not log_path.exists():
        raise FileNotFoundError(f"Log {log_path} não encontrado")
    content = log_path.read_text(encoding="utf-8", errors="ignore").splitlines()
    if tail and lines > 0:
        content = content[-lines:]
    return "\n".join(content)


def show_state(run_id: str) -> str:
    state_path = LOG_DIR / f"{run_id}.state.json"
    if not state_path.exists():
        raise FileNotFoundError(f"Checkpoint {state_path} não encontrado")
    return state_path.read_text(encoding="utf-8")


def cleanup_logs(max_days: int | None = None, max_mb: int | None = None) -> dict:
    deleted = []
    entries = list(_iter_logs())
    total_bytes = sum(entry.size_bytes for entry in entries)
    limit_bytes = max_mb * 1024 * 1024 if max_mb else None
    now = datetime.now()

    def _delete(entry: LogEntry) -> None:
        try:
            entry.log_path.unlink(missing_ok=True)
            if entry.state_path:
                entry.state_path.unlink(missing_ok=True)
        except Exception:
            pass
        deleted.append(entry.run_id)

    if max_days and max_days > 0:
        cutoff = now - timedelta(days=max_days)
        for entry in entries:
            if entry.mtime < cutoff:
                _delete(entry)
                total_bytes -= entry.size_bytes

    if limit_bytes and limit_bytes > 0:
        for entry in sorted(entries, key=lambda e: e.mtime):
            if total_bytes <= limit_bytes:
                break
            if entry.run_id not in deleted:
                _delete(entry)
                total_bytes -= entry.size_bytes

    return {"deleted": deleted, "remaining_bytes": total_bytes}
