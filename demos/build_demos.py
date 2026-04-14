#!/usr/bin/env python3
# Reads demo-order.json and assembles demos.json from individual .lua files.

import json
import sys
from pathlib import Path

DEMOS_DIR = Path(__file__).parent
ORDER_FILE = DEMOS_DIR / "demo-order.json"
OUTPUT_FILE = DEMOS_DIR / "demos.json"


def main() -> None:
	if not ORDER_FILE.exists():
		print(f"Error: {ORDER_FILE} not found.")
		sys.exit(1)

	with open(ORDER_FILE, encoding="utf-8") as f:
		order = json.load(f)

	demos = []
	for name in order:
		filename = name if name.endswith(".lua") else f"{name}.lua"
		filepath = DEMOS_DIR / filename
		title = name.removesuffix(".lua")

		if not filepath.exists():
			print(f"Warning: {filename} not found, skipping.")
			continue

		code = filepath.read_text(encoding="utf-8")
		demos.append({"title": title, "code": code})

	with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
		json.dump(demos, f, ensure_ascii=False, separators=(",", ":"))

	print(f"Wrote {len(demos)} demos to {OUTPUT_FILE.name} ({OUTPUT_FILE.stat().st_size} bytes)")


if __name__ == "__main__":
	main()
