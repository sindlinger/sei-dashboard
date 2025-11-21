import unittest

from seiautomation.offline.doc_classifier import DocumentBucket
from seiautomation.offline.extract_reports import (
    DocumentText,
    ExtractionResult,
    ProcessContext,
    _result_to_audit_entry,
    _summarize_documents,
)


class AuditLogTests(unittest.TestCase):
    def test_summarize_documents_collects_fields(self) -> None:
        ctx = ProcessContext()
        doc = DocumentText(name="despacho.pdf", text="conteúdo", bucket=DocumentBucket.PRINCIPAL)
        ctx.register(doc)
        result = ExtractionResult()
        result.data["PROCESSO Nº"] = "0801234-56.2024.8.15.0001"
        result.sources["PROCESSO Nº"] = "despacho.pdf"
        result.meta["PROCESSO Nº"] = {
            "pattern": "processo_regex",
            "snippet": "Processo nº 0801234-56.2024.8.15.0001",
        }
        summaries = _summarize_documents(ctx, result)
        self.assertEqual(len(summaries), 1)
        self.assertEqual(summaries[0]["name"], "despacho.pdf")
        self.assertEqual(summaries[0]["bucket"], DocumentBucket.PRINCIPAL.value)
        self.assertEqual(summaries[0]["fields"][0]["field"], "PROCESSO Nº")

    def test_audit_entry_uses_document_summary(self) -> None:
        result = ExtractionResult()
        result.data["PROCESSO Nº"] = "0801234-56.2024.8.15.0001"
        result.sources["PROCESSO Nº"] = "despacho.pdf"
        result.meta["PROCESSO Nº"] = {
            "pattern": "processo_regex",
            "snippet": "Processo nº 0801234-56.2024.8.15.0001",
        }
        result.meta["_documents"] = [
            {
                "name": "despacho.pdf",
                "bucket": DocumentBucket.PRINCIPAL.value,
                "fields": [{"field": "PROCESSO Nº"}],
            }
        ]
        result.meta["_bucket_usage"] = {"counts": {DocumentBucket.PRINCIPAL.value: 1}}
        result.meta["_zip_path"] = "/tmp/sample.zip"
        entry = _result_to_audit_entry("0000001.zip", result, "run-123")
        self.assertEqual(entry["zip"], "0000001.zip")
        self.assertEqual(entry["zip_path"], "/tmp/sample.zip")
        self.assertEqual(entry["bucket_counts"][DocumentBucket.PRINCIPAL.value], 1)
        self.assertEqual(entry["fields"][0]["bucket"], DocumentBucket.PRINCIPAL.value)


if __name__ == "__main__":
    unittest.main()
