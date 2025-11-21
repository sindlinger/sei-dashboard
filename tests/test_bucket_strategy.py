import unittest

from seiautomation.offline.doc_classifier import DocumentBucket
from seiautomation.offline.extract_reports import (
    BUCKET_REQUIREMENTS,
    DocumentText,
    ExtractionResult,
    ProcessContext,
    _should_expand_bucket,
)


class BucketStrategyTests(unittest.TestCase):
    def _context_with_anchor(self) -> ProcessContext:
        ctx = ProcessContext()
        ctx.register(DocumentText(name="doc", text="conteúdo"))
        return ctx

    def test_should_expand_when_no_anchor(self) -> None:
        ctx = ProcessContext()
        res = ExtractionResult()
        self.assertTrue(_should_expand_bucket(DocumentBucket.PRINCIPAL, ctx, res))

    def test_stops_after_principal_when_required_fields_present(self) -> None:
        ctx = self._context_with_anchor()
        res = ExtractionResult()
        for field in BUCKET_REQUIREMENTS[DocumentBucket.PRINCIPAL]:
            res.data[field] = "ok"
        self.assertFalse(_should_expand_bucket(DocumentBucket.PRINCIPAL, ctx, res))

    def test_laudo_only_when_species_missing(self) -> None:
        ctx = self._context_with_anchor()
        res = ExtractionResult()
        for field in BUCKET_REQUIREMENTS[DocumentBucket.APOIO]:
            if field in {"ESPÉCIE DE PERÍCIA", "Fator", "Valor Tabelado Anexo I - Tabela I"}:
                continue
            res.data[field] = "ok"
        self.assertTrue(_should_expand_bucket(DocumentBucket.APOIO, ctx, res))
        res.data["ESPÉCIE DE PERÍCIA"] = "Grafotécnica"
        res.data["Fator"] = "A"
        res.data["Valor Tabelado Anexo I - Tabela I"] = "R$ 100,00"
        self.assertFalse(_should_expand_bucket(DocumentBucket.APOIO, ctx, res))


if __name__ == "__main__":
    unittest.main()
