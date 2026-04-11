import importlib.util
import unittest
from pathlib import Path


MODULE_PATH = (
    Path(__file__).resolve().parents[2]
    / ".github"
    / "scripts"
    / "review_output_parser.py"
)

spec = importlib.util.spec_from_file_location("review_output_parser", MODULE_PATH)
review_output_parser = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(review_output_parser)


class ReviewOutputParserTests(unittest.TestCase):
    def test_extract_review_text_deduplicates_nested_output(self):
        data = {
            "output": [
                {
                    "type": "message",
                    "content": [
                        {"type": "output_text", "text": "first"},
                        {"type": "text", "text": "second"},
                    ],
                    "output_text": "first",
                }
            ]
        }

        text = review_output_parser.extract_review_text(data)

        self.assertEqual(text, "first\nsecond")

    def test_extract_review_text_falls_back_to_json_dump(self):
        data = {"output": [{"type": "message", "content": []}]}

        text = review_output_parser.extract_review_text(data)

        self.assertIn("OpenAI 응답을 파싱하지 못했습니다.", text)
        self.assertIn('"output"', text)


if __name__ == "__main__":
    unittest.main()
