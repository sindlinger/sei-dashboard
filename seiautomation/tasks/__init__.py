"""Coleção de tarefas automatizadas do SEIAutomation."""

from .annotate_ok import preencher_anotacoes_ok
from .download_zip import download_zip_lote
from .list_processes import listar_processos

__all__ = ["download_zip_lote", "preencher_anotacoes_ok", "listar_processos"]
