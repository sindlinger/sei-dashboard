from qa.context_selector import select_contexts


class DummyExtraction:
    def __init__(self, candidates):
        self.candidates = candidates


def test_select_contexts_prefers_candidates_and_limits():
    extraction = DummyExtraction(
        {
            "PROMOVENTE": [
                {"snippet": "Fulano de Tal", "source": "doc1.pdf", "weight": 0.9},
                {"snippet": "Fulano duplicado", "source": "doc1.pdf", "weight": 0.5},
            ],
            "PROMOVIDO": [
                {"snippet": "Beltrano", "source": "doc2.pdf", "weight": 0.8},
            ],
        }
    )

    documents = [
        {"name": "doc1.pdf", "text": "Fulano de Tal aparece aqui"},
        {"name": "doc2.pdf", "text": "Beltrano aparece aqui"},
    ]

    contexts = select_contexts(extraction, documents, fields=["PROMOVENTE", "PROMOVIDO"], limit_override=1)

    assert set(contexts.keys()) == {"PROMOVENTE", "PROMOVIDO"}
    assert len(contexts["PROMOVENTE"]) == 1  # limitado a 1
    assert "Fulano" in contexts["PROMOVENTE"][0]["context"]
    assert "Beltrano" in contexts["PROMOVIDO"][0]["context"]
