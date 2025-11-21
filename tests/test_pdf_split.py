import unittest

from preprocessamento.documents import _build_pdf_documents_from_pages, _extract_pdf_doc_number
from seiautomation.offline.doc_classifier import DocumentBucket


class PdfSplitTests(unittest.TestCase):
    def test_extract_pdf_doc_number_recovers_digits(self) -> None:
        text = """0-12345.67890.00000.11111.EMDA\n,odanissa\n1\nanigáp\n41\notnemucoD"""
        self.assertEqual(_extract_pdf_doc_number(text), 14)

    def test_build_pdf_documents_groups_cover_and_pages(self) -> None:
        pages = [
            "Poder Judiciário\nProcesso Administrativo 2023",
            "1\notnemucoD\nDespacho – Assunto: Autorização de pagamento de honorários ao perito",
            "1\notnemucoD\nSegue o despacho com os dados do promovente",
            "2\notnemucoD\nLaudo pericial descrevendo conclusões finais",
        ]
        docs = _build_pdf_documents_from_pages(pages, "consolidado.pdf")
        self.assertEqual(len(docs), 2)
        first, second = docs
        self.assertTrue(first["name"].endswith("_doc01.pdf"))
        self.assertTrue(second["name"].endswith("_doc02.pdf"))
        self.assertIn("Poder Judiciário", first["text"])
        self.assertEqual(first["bucket"], DocumentBucket.PRINCIPAL)
        self.assertEqual(second["bucket"], DocumentBucket.LAUDO)

    def test_build_pdf_documents_fallback_without_markers(self) -> None:
        pages = ["Conteúdo breve sem marcador explícito"]
        docs = _build_pdf_documents_from_pages(pages, "unico.pdf")
        self.assertEqual(len(docs), 1)
        self.assertTrue(docs[0]["name"].endswith("_doc01.pdf"))
        self.assertEqual(docs[0]["bucket"], DocumentBucket.OUTRO)


if __name__ == "__main__":
    unittest.main()
