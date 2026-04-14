#!/usr/bin/env python3
"""
Solar2D HTML5 Build - Remove Blur Callback

Patches the .bin archive to remove the blur callback registration, which prevents
HTML5 builds from freezing when the user clicks outside of the app.
"""

import zipfile
import os
import sys
import shutil
import re
from pathlib import Path

LINE_LENGTH = 60


def remove_blur_callback(js_content: str) -> tuple[str, bool]:
	"""Remove the blur callback registration from _emscripten_set_blur_callback_on_thread."""
	pattern = r'(function _emscripten_set_blur_callback_on_thread\([^)]*\)\{)registerFocusEventCallback\([^)]*\);(return 0\})'
	modified = re.sub(pattern, r'\1\2', js_content)

	if modified != js_content:
		print("Successfully removed blur callback registration")
		return modified, True

	print("Warning: Could not find the expected function pattern.")
	print("This file may already be modified or have a different structure.")
	return js_content, False


def process_bin_file(bin_path: Path) -> bool:
	"""Extract the .bin archive, patch the JS file, and repack it."""
	if not bin_path.exists():
		print(f"Error: File '{bin_path}' not found!")
		return False

	print(f"Processing: {bin_path}")
	temp_dir = bin_path.parent / f"{bin_path.stem}_temp"

	try:
		print("Extracting files...")
		with zipfile.ZipFile(bin_path, 'r') as zip_ref:
			zip_ref.extractall(temp_dir)

		js_filename = bin_path.stem + ".js"
		js_file = temp_dir / js_filename

		if not js_file.exists():
			print(f"Error: {js_filename} not found in the archive!")
			js_files = list(temp_dir.glob("*.js"))
			if js_files:
				print(f"Found: {[f.name for f in js_files]}")
				print(f"Expected: {js_filename}")
			return False

		print(f"Found: {js_file.name}")

		with open(js_file, 'r', encoding='utf-8') as f:
			js_content = f.read()

		print("Modifying blur callback function...")
		modified_content, was_modified = remove_blur_callback(js_content)

		if not was_modified:
			print("No modifications made. The file may already be modified.")
			user_input = input("Continue anyway? (y/n): ").strip().lower()
			if user_input != 'y':
				return False

		with open(js_file, 'w', encoding='utf-8') as f:
			f.write(modified_content)

		print("Re-creating archive...")
		with zipfile.ZipFile(bin_path, 'w', zipfile.ZIP_DEFLATED) as zip_ref:
			for root, dirs, files in os.walk(temp_dir):
				for file in files:
					file_path = Path(root) / file
					arcname = file_path.relative_to(temp_dir)
					zip_ref.write(file_path, arcname)

		print(f"Successfully processed {bin_path.name}")
		return True

	except Exception as e:
		print(f"Error: {e}")
		return False

	finally:
		if temp_dir.exists():
			shutil.rmtree(temp_dir)
			print("Cleaned up temporary files")


def clean_path(raw_path: str) -> str:
	"""Clean up a path string from terminal input (handles drag-and-drop artifacts and quotes)."""
	path = raw_path.strip()

	# VS Code adds "& '" at the beginning when drag-dropping
	if path.startswith("& '") or path.startswith('& "'):
		path = path[2:].strip()

	return path.strip('"').strip("'")


def find_bin_in_dir(directory: Path) -> Path | None:
	"""Find a single .bin file in a directory. Returns the path or None."""
	if not directory.is_dir():
		return None

	bin_files = list(directory.glob("*.bin"))

	if len(bin_files) == 1:
		return bin_files[0]
	elif len(bin_files) > 1:
		print(f"Error: Multiple .bin files found in '{directory}':")
		for f in bin_files:
			print(f"  - {f.name}")
		print("Please specify which file to process.")

	return None


def resolve_bin_path(user_path: str) -> Path | None:
	"""Resolve user input to a .bin file path. Accepts a file or folder."""
	path = Path(user_path)

	if path.is_file() and path.suffix == '.bin':
		return path

	if path.is_dir():
		result = find_bin_in_dir(path)
		if result:
			return result
		print(f"Error: No .bin file found in '{path}'")
		return None

	if not path.exists():
		print(f"Error: '{path}' does not exist!")
		return None

	print(f"Error: '{path}' is not a .bin file or directory")
	return None


def auto_detect_bin() -> Path | None:
	"""Auto-detect .bin file in the script's directory or its 'bin' subdirectory."""
	script_dir = Path(__file__).parent

	result = find_bin_in_dir(script_dir)
	if result:
		return result

	bin_dir = script_dir / "bin"
	result = find_bin_in_dir(bin_dir)
	if result:
		return result

	print(f"Error: No .bin file found in '{script_dir}' or '{bin_dir}'")
	return None


def main() -> None:
	print("=" * LINE_LENGTH)
	print("Solar2D HTML5 - Remove Blur Callback")
	print("Patches .bin to remove blur callback")
	print("=" * LINE_LENGTH)
	print()

	bin_path = None

	if len(sys.argv) > 1:
		bin_path = resolve_bin_path(clean_path(sys.argv[1]))
	else:
		print("Provide the path to your .bin file or its folder by:")
		print("  - Typing or pasting a path to the .bin file or its folder")
		print("  - Dragging and dropping the file or its folder into this window")
		print("  - Pressing Enter to auto-detect the file in the current folder")
		print()

		try:
			user_input = input("> ").strip()
		except (KeyboardInterrupt, EOFError):
			print("\nExiting...")
			return

		if user_input:
			bin_path = resolve_bin_path(clean_path(user_input))
		else:
			print("Auto-detecting .bin file...")
			bin_path = auto_detect_bin()

	if not bin_path:
		input("\nPress Enter to exit...")
		return

	print(f"Found: {bin_path}")
	print()

	bin_success = process_bin_file(bin_path)

	print()
	print("=" * LINE_LENGTH)

	if bin_success:
		print("Done. Blur callback removed from .bin.")
	else:
		print("Process completed with warnings. Check the messages above.")

	print("=" * LINE_LENGTH)
	input("\nPress Enter to exit...")


if __name__ == "__main__":
	main()
