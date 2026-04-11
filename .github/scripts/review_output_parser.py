import json
import sys
from pathlib import Path


def append_piece(piece, pieces, seen):
    if isinstance(piece, str):
        normalized = piece.strip()
        if normalized and normalized not in seen:
            seen.add(normalized)
            pieces.append(normalized)


def collect_output_text(node, pieces, seen):
    if isinstance(node, dict):
        node_type = node.get("type")

        if node_type == "output_text":
            append_piece(node.get("text"), pieces, seen)

        if node_type in {"text", "input_text"}:
            append_piece(node.get("text"), pieces, seen)

        append_piece(node.get("output_text"), pieces, seen)

        message_content = node.get("content")
        if node_type == "message" and isinstance(message_content, list):
            collect_output_text(message_content, pieces, seen)

        for key, value in node.items():
            if key == "content" and node_type == "message":
                continue
            if isinstance(value, (dict, list)):
                collect_output_text(value, pieces, seen)

    elif isinstance(node, list):
        for item in node:
            collect_output_text(item, pieces, seen)


def extract_review_text(data):
    pieces = []
    seen = set()
    collect_output_text(data.get("output", []), pieces, seen)

    text = "\n".join(pieces).strip()
    if text:
        return text

    return (
        "OpenAI 응답을 파싱하지 못했습니다.\n\n```json\n"
        + json.dumps(data, ensure_ascii=False, indent=2)[:3000]
        + "\n```"
    )


def main(argv):
    if len(argv) != 3:
        raise SystemExit("usage: review_output_parser.py <input_json> <output_md>")

    input_path = Path(argv[1])
    output_path = Path(argv[2])

    data = json.loads(input_path.read_text(encoding="utf-8"))
    text = extract_review_text(data)
    final = "## OpenAI 코드 리뷰\n\n<!-- openai-review-bot -->\n\n" + text
    output_path.write_text(final, encoding="utf-8")


if __name__ == "__main__":
    main(sys.argv)
