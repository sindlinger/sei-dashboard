from __future__ import annotations

from rich.table import Table

from ..constants import DEFAULT_QA_MODEL
from ..utils import collect_offline_paths, get_console
from qa.match_runner import run_match as match_run


def register(subparsers) -> None:
    parser = subparsers.add_parser("match", help="Compara regex × QA para campos específicos")
    parser.add_argument("--zip", dest="qa_zip", help="Arquivo ZIP individual.")
    parser.add_argument("--zip-dir", dest="qa_zip_dir", help="Diretório com ZIPs.")
    parser.add_argument("--pdf", dest="qa_pdf", help="Arquivo PDF individual.")
    parser.add_argument("--pdf-dir", dest="qa_pdf_dir", help="Diretório com PDFs.")
    parser.add_argument("--limit", dest="qa_limit", type=int, help="Limita a quantidade de arquivos.")
    parser.add_argument("--fields", dest="qa_fields", nargs="*", help="Campos a exibir (default: todos com candidatos).")
    parser.add_argument("--device", dest="qa_device", type=int, default=0, help="GPU usada (use -1 para CPU).")
    parser.add_argument("--min-score", dest="qa_min_score", type=float, default=0.25, help="Score mínimo para aceitar respostas QA.")
    parser.add_argument("--model", dest="qa_model", default=str(DEFAULT_QA_MODEL), help="Checkpoint do modelo QA.")
    parser.set_defaults(handler=_run)


def _run(args, settings) -> int:
    zip_paths, pdf_paths = collect_offline_paths(args)
    results = match_run(
        zip_paths=zip_paths,
        pdf_paths=pdf_paths,
        limit=args.qa_limit,
        fields=args.qa_fields,
        device=args.qa_device,
        model_name=args.qa_model,
        min_score=args.qa_min_score,
    )
    if not results:
        print("Nenhum dado para comparar.")
        return 0
    console = get_console()
    for zip_name, field_map in results.items():
        console.print(f"\n=== {zip_name} ===")
        if not field_map:
            console.print("(sem campos selecionados)")
            continue
        for field, payload in field_map.items():
            regex_value = payload.get("regex") or "-"
            qa_value = payload.get("qa") or "-"
            score = payload.get("qa_score")
            source = payload.get("qa_source") or "-"
            score_str = f"{score:.3f}" if score and qa_value != "-" else "-"
            console.print(f"[bold]{field}[/bold]")
            console.print(f"  Regex: {regex_value}")
            console.print(f"  QA:    {qa_value}")
            console.print(f"  Score: {score_str}")
            console.print(f"  Fonte: {source}\n")
    return 0
