from __future__ import annotations

"""Heurísticas para classificar documentos dos ZIPs do SEI."""

from enum import Enum
from typing import Iterable


class DocumentBucket(str, Enum):
    """Categorias de documentos usadas durante a extração."""

    PRINCIPAL = "principal"
    APOIO = "apoio"
    LAUDO = "laudo"
    OUTRO = "outro"


def _contains(text: str, keywords: Iterable[str]) -> bool:
    return any(keyword in text for keyword in keywords)


def classify_document(name: str, text: str | None) -> DocumentBucket:
    """Retorna o bucket ideal para o documento baseado no nome/conteúdo."""

    name_lower = (name or "").lower()
    text_lower = (text or "").lower() if text else ""
    snippet = text_lower[:2000]

    if _is_laudo(name_lower, snippet):
        return DocumentBucket.LAUDO
    if _is_principal(name_lower, snippet):
        return DocumentBucket.PRINCIPAL
    if _is_apoio(name_lower, snippet):
        return DocumentBucket.APOIO
    return DocumentBucket.OUTRO


def _is_laudo(name: str, snippet: str) -> bool:
    laudo_keywords = (
        "laudo",
        "parecer",
        "relatorio pericial",
        "relatório pericial",
        "relatorio de pericia",
        "relatório de perícia",
    )
    return _contains(name, laudo_keywords) or _contains(snippet, laudo_keywords)


def _is_principal(name: str, snippet: str) -> bool:
    principal_name = (
        "despacho",
        "autorizacao",
        "autorização",
        "diesp",
        "diretoria especial",
        "magistratura",
        "cm_",
        "conselho da magistratura",
    )
    principal_text = (
        "assunto: autorizacao de pagamento",
        "assunto: autorização de pagamento",
        "pagamento de honorarios",
        "pagamento de honorários",
        "conselho da magistratura",
        "diretoria especial",
    )
    # Certidões com CM costumam ter o deferimento principal.
    certidao_cm = "certida" in name and ("magistratura" in name or "cm" in name)
    return certidao_cm or _contains(name, principal_name) or _contains(snippet, principal_text)


def _is_apoio(name: str, snippet: str) -> bool:
    apoio_name = (
        "certida",
        "certidão",
        "informacao",
        "informação",
        "oficio",
        "ofício",
        "memorando",
        "interessado",
        "perito",
        "manifestacao",
        "manifestação",
    )
    apoio_text = (
        "interessado",
        "perito",
        "movido por",
        "em face de",
        "juizo",
        "juízo",
    )
    return _contains(name, apoio_name) or _contains(snippet, apoio_text)


__all__ = ["DocumentBucket", "classify_document"]
