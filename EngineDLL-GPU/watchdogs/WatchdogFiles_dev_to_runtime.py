#!/usr/bin/env python3
"""
Watchdog Files Dev -> Runtime
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Monitora as arvores Dev/ e runtime/ para manter os artefatos alinhados.
Por padrao apenas registra diferencas; use --apply para copiar os arquivos
novos/alterados do Dev/ para runtime/.

Categorias monitoradas:
  - bin          : Dev/bin -> runtime/bin                (arquivos de build)
  - agents       : Dev/bin -> AgentsFiles-to-tester_folder_terminals/*/MQL5/Libraries (*.dll, *.lib, *.exe)
  - indicators   : Dev/Indicators -> runtime/Indicators  (*.mq5, *.ex5)
  - experts      : Dev/Experts -> runtime/Experts        (*.mq5, *.ex5)
  - include      : Dev/Include -> runtime/Include        (*.mqh, *.mq5)
  - scripts      : Dev/Scripts -> runtime/Scripts        (*.mq5, *.ex5)

Exemplos:
    python WatchdogFiles_dev_to_runtime.py --once
    python WatchdogFiles_dev_to_runtime.py --apply        # monitora continuamente
    python WatchdogFiles_dev_to_runtime.py --apply --once # copia e finaliza
    python WatchdogFiles_dev_to_runtime.py --interval 60  # verifica a cada 60 segundos
"""

from __future__ import annotations

import argparse
import shutil
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Tuple


@dataclass
class FileInfo:
    size: int
    mtime: float


@dataclass
class WatchPair:
    name: str
    source: Path
    target: Path
    recursive: bool = True
    extensions: Optional[Tuple[str, ...]] = None

    def iter_files(self) -> Iterable[Path]:
        if not self.source.exists():
            return []
        iterator: Iterable[Path]
        if self.recursive:
            iterator = self.source.rglob("*")
        else:
            iterator = self.source.glob("*")
        return iterator

    def accept(self, path: Path) -> bool:
        if not path.is_file():
            return False
        if self.extensions and path.suffix.lower() not in self.extensions:
            return False
        return True


def detect_repo_root() -> Path:
    """Detect the raiz do repositório procurando por arquivos-âncora."""

    script_path = Path(__file__).resolve()
    for parent in script_path.parents:
        if (parent / "links_config.json").exists():
            return parent
    # fallback: sobe apenas um nível (WaveSpecGPU) caso nenhum marcador seja encontrado
    return script_path.parents[1]


def build_snapshot(pair: WatchPair) -> Dict[Path, FileInfo]:
    snapshot: Dict[Path, FileInfo] = {}
    for file_path in pair.iter_files():
        if not pair.accept(file_path):
            continue
        rel = file_path.relative_to(pair.source)
        stat = file_path.stat()
        snapshot[rel] = FileInfo(size=stat.st_size, mtime=stat.st_mtime)
    return snapshot


def build_target_snapshot(pair: WatchPair) -> Dict[Path, FileInfo]:
    if not pair.target.exists():
        return {}
    snapshot: Dict[Path, FileInfo] = {}
    iterator: Iterable[Path]
    if pair.recursive:
        iterator = pair.target.rglob("*")
    else:
        iterator = pair.target.glob("*")
    for file_path in iterator:
        if not file_path.is_file():
            continue
        if pair.extensions and file_path.suffix.lower() not in pair.extensions:
            continue
        rel = file_path.relative_to(pair.target)
        stat = file_path.stat()
        snapshot[rel] = FileInfo(size=stat.st_size, mtime=stat.st_mtime)
    return snapshot


def diff_snapshots(
    pair: WatchPair,
    source_snapshot: Dict[Path, FileInfo],
    target_snapshot: Dict[Path, FileInfo],
) -> Tuple[List[Path], List[Tuple[str, Path]]]:
    to_copy: List[Path] = []
    notes: List[Tuple[str, Path]] = []

    for rel, src_info in source_snapshot.items():
        tgt_info = target_snapshot.get(rel)
        if tgt_info is None:
            to_copy.append(rel)
            notes.append(("novo", rel))
        elif src_info.size != tgt_info.size or abs(src_info.mtime - tgt_info.mtime) > 0.001:
            to_copy.append(rel)
            notes.append(("alterado", rel))

    for rel in target_snapshot:
        if rel not in source_snapshot:
            notes.append(("obsoleto", rel))

    return to_copy, notes


def copy_files(pair: WatchPair, rel_paths: Iterable[Path], verbose: bool = True) -> None:
    for rel in rel_paths:
        src = pair.source / rel
        dst = pair.target / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
        if verbose:
            print(f"[watchdog:{pair.name}] copiado {rel.as_posix()}")


def describe_changes(pair: WatchPair, notes: Iterable[Tuple[str, Path]]) -> None:
    entries = list(notes)
    if not entries:
        return
    print(f"[watchdog:{pair.name}] diferencas detectadas:")
    for status, rel in entries:
        print(f"  - {status:<9} {rel.as_posix()}")


def default_pairs(base_root: Path) -> List[WatchPair]:
    dev_root = base_root / "Dev"
    runtime_root = base_root / "runtime"

    pairs: List[WatchPair] = [
        WatchPair(
            name="indicators",
            source=dev_root / "Indicators",
            target=runtime_root / "Indicators",
            recursive=True,
            extensions=(".mq5", ".ex5"),
        ),
        WatchPair(
            name="experts",
            source=dev_root / "Experts",
            target=runtime_root / "Experts",
            recursive=True,
            extensions=(".mq5", ".ex5"),
        ),
        WatchPair(
            name="include",
            source=dev_root / "Include",
            target=runtime_root / "Include",
            recursive=True,
            extensions=(".mqh", ".mq5"),
        ),
        WatchPair(
            name="scripts",
            source=dev_root / "Scripts",
            target=runtime_root / "Scripts",
            recursive=True,
            extensions=(".mq5", ".ex5"),
        ),
    ]

    bin_extensions = (".dll", ".lib", ".exp", ".pdb", ".exe")
    dev_bin = dev_root / "bin"
    runtime_bin = runtime_root / "bin"
    pairs.append(
        WatchPair(
            name="bin-runtime",
            source=dev_bin,
            target=runtime_bin,
            recursive=False,
            extensions=bin_extensions,
        )
    )

    agents_root = base_root / "AgentsFiles-to-tester_folder_terminals"
    shared_root = agents_root / "Shared"
    if shared_root.exists():
        slot_dirs = sorted(shared_root.glob("Slot*/MQL5/Libraries"))
        for slot_dir in slot_dirs:
            try:
                slot_name = slot_dir.parents[1].name  # SlotXX
            except IndexError:
                slot_name = slot_dir.name
            pairs.append(
                WatchPair(
                    name=f"agent-{slot_name.lower()}",
                    source=dev_bin,
                    target=slot_dir,
                    recursive=False,
                    extensions=bin_extensions,
                )
            )

    return pairs


def run_watchdog(pairs: List[WatchPair], interval: float, once: bool, apply_changes: bool, verbose: bool) -> None:
    state: Dict[str, Dict[Path, FileInfo]] = {}
    last_notes: Dict[str, List[Tuple[str, Path]]] = {}

    def evaluate() -> None:
        for pair in pairs:
            source_snapshot = build_snapshot(pair)
            target_snapshot = build_target_snapshot(pair)
            to_copy, notes = diff_snapshots(pair, source_snapshot, target_snapshot)

            # Apenas loga se houve mudanca em relacao ao ultimo ciclo
            previous = last_notes.get(pair.name, [])
            if notes != previous:
                describe_changes(pair, notes)
                last_notes[pair.name] = notes

            if apply_changes and to_copy:
                copy_files(pair, to_copy, verbose=verbose)
                # recalcule o snapshot de destino apos copiar
                state[pair.name] = build_snapshot(pair)
            else:
                state[pair.name] = source_snapshot

    evaluate()
    if once:
        return

    print(f"[watchdog] monitorando pares Dev -> runtime a cada {interval:.0f}s (modo {'copia' if apply_changes else 'registro'})")
    try:
        while True:
            evaluate()
            time.sleep(interval)
    except KeyboardInterrupt:
        print("\n[watchdog] encerrado pelo usuario.")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Monitora Dev/ e runtime/ para manter arquivos atualizados."
    )
    default_root = detect_repo_root()
    parser.add_argument(
        "--root",
        type=Path,
        default=default_root,
        help="raiz do projeto (padrao: diretorio dois niveis acima deste script)",
    )
    parser.add_argument(
        "--interval",
        type=float,
        default=600.0,
        help="intervalo em segundos entre verificacoes (padrao: 600 = 10 minutos)",
    )
    parser.add_argument(
        "--once",
        action="store_true",
        help="executa apenas uma avaliacao e encerra",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="copia automaticamente os arquivos novos/alterados para runtime/",
    )
    parser.add_argument(
        "--quiet",
        action="store_true",
        help="oculta logs de copia ao aplicar alteracoes",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    pairs = default_pairs(args.root.resolve())
    run_watchdog(
        pairs=pairs,
        interval=max(5.0, args.interval),
        once=args.once,
        apply_changes=args.apply,
        verbose=not args.quiet,
    )


if __name__ == "__main__":
    main()
