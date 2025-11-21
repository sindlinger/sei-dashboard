import json
import tempfile
import unittest
from pathlib import Path
from zipfile import ZipFile

from seiautomation.offline import DocumentBucket
from seiautomation.offline.export_docs import copy_documents


class ExportDocsTests(unittest.TestCase):
    def test_copy_documents_extracts_selected_buckets(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            zip_path = tmp_path / "process.zip"
            with ZipFile(zip_path, "w") as zf:
                zf.writestr("principal/doc1.txt", "principal content")
                zf.writestr("apoio/doc2.txt", "apoio content")

            entry = {
                "run_id": "test-run",
                "zip": "process.zip",
                "zip_path": str(zip_path),
                "bucket_counts": {},
                "documents": [
                    {"name": "principal/doc1.txt", "bucket": DocumentBucket.PRINCIPAL.value, "fields": []},
                    {"name": "apoio/doc2.txt", "bucket": DocumentBucket.APOIO.value, "fields": []},
                ],
                "fields": [],
                "observations": [],
            }
            sources = tmp_path / "run.sources.jsonl"
            with sources.open("w", encoding="utf-8") as handle:
                handle.write(json.dumps(entry))
                handle.write("\n")

            output = tmp_path / "exported"
            copied = copy_documents(
                sources,
                output,
                bucket_filter={DocumentBucket.PRINCIPAL},
                limit=None,
            )

            dest_file = output / "process" / "principal" / "doc1.txt"
            self.assertTrue(dest_file.exists())
            self.assertEqual(dest_file.read_text(encoding="utf-8"), "principal content")
            self.assertEqual(len(copied), 1)


if __name__ == "__main__":
    unittest.main()
