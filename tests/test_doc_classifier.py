import unittest

from seiautomation.offline.doc_classifier import DocumentBucket, classify_document


class DocumentClassifierTests(unittest.TestCase):
    def test_classifies_laudo_by_name(self) -> None:
        bucket = classify_document("Laudo_Pericial_Financas.pdf", "Laudo pericial em engenharia")
        self.assertEqual(bucket, DocumentBucket.LAUDO)

    def test_classifies_principal_by_text(self) -> None:
        text = "Assunto: Autorização de pagamento de honorários em favor do perito."
        bucket = classify_document("doc001.pdf", text)
        self.assertEqual(bucket, DocumentBucket.PRINCIPAL)

    def test_classifies_apoio_by_keywords(self) -> None:
        text = "Certidão. Interessado: Fulano de Tal – Perito Contábil."
        bucket = classify_document("certidao_interessado.pdf", text)
        self.assertEqual(bucket, DocumentBucket.APOIO)

    def test_defaults_to_outro(self) -> None:
        bucket = classify_document("comprovante_envio.pdf", "Documento genérico sem palavras chave.")
        self.assertEqual(bucket, DocumentBucket.OUTRO)


if __name__ == "__main__":
    unittest.main()
