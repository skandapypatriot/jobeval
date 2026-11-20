#!/usr/bin/env python
"""Ingest raw test files from a source directory and auto-sort into testdata/ by extension."""

import hashlib
import shutil
import sys
from pathlib import Path

# Extension to folder mapping
EXT_MAP = {
    ".step": "step",
    ".stp": "step",
    ".iges": "iges",
    ".igs": "iges",
    ".stl": "stl",
    ".brep": "brep",
    ".dxf": "dxf",
    ".dwg": "dxf",  # DWG goes to dxf folder
    ".pdf": "pdf",
    ".svg": "pdf",  # SVG drawings go to pdf folder
    ".png": "pdf",  # Raster drawings go to pdf folder
    ".jpg": "pdf",
    ".jpeg": "pdf",
}

# Patterns to ignore (case-insensitive substring match)
IGNORE_PATTERNS = [
    "standard_instructions",
    "readme",
    "license",
    "changelog",
    ".git",
    "__pycache__",
    ".ds_store",
    "thumbs.db",
]

def should_ignore(file_path: Path) -> bool:
    """Check if file should be ignored based on name patterns."""
    name_lower = file_path.name.lower()
    # Check file name
    for pattern in IGNORE_PATTERNS:
        if pattern in name_lower:
            return True
    # Check parent directories
    for part in file_path.parts:
        part_lower = part.lower()
        for pattern in IGNORE_PATTERNS:
            if pattern in part_lower:
                return True
    return False


def ingest(source_dir: Path, target_root: Path = None):
    """Copy files from source_dir to testdata/ subfolders based on extension."""
    if target_root is None:
        target_root = Path(__file__).resolve().parents[1] / "testdata"

    source_dir = Path(source_dir).resolve()
    if not source_dir.exists():
        print(f"Source directory not found: {source_dir}")
        return 1

    # Create target subdirectories
    for subdir in EXT_MAP.values():
        (target_root / subdir).mkdir(parents=True, exist_ok=True)

    copied = 0
    skipped = 0
    ignored = 0

    for file_path in source_dir.rglob("*"):
        if not file_path.is_file():
            continue

        # Check ignore patterns
        if should_ignore(file_path):
            print(f"  Ignored: {file_path.relative_to(source_dir)}")
            ignored += 1
            continue

        ext = file_path.suffix.lower()
        if ext not in EXT_MAP:
            print(f"  Skipping unknown extension: {file_path.name}")
            skipped += 1
            continue

        target_dir = target_root / EXT_MAP[ext]
        target_path = target_dir / file_path.name

        # Handle duplicates
        if target_path.exists():
            # Add suffix if different content
            src_hash = hashlib.md5(file_path.read_bytes()).hexdigest()
            dst_hash = hashlib.md5(target_path.read_bytes()).hexdigest()
            if src_hash == dst_hash:
                print(f"  Duplicate (same content): {file_path.name}")
                skipped += 1
                continue
            # Different content - add counter
            counter = 1
            while target_path.exists():
                stem = file_path.stem
                target_path = target_dir / f"{stem}_{counter}{ext}"
                counter += 1

        shutil.copy2(file_path, target_path)
        print(f"  {ext:6} -> {EXT_MAP[ext]:6} : {file_path.relative_to(source_dir)}")
        copied += 1

    print(f"\nDone: {copied} copied, {skipped} skipped, {ignored} ignored")
    return 0


def main():
    if len(sys.argv) < 2:
        print("Usage: python ingest_testdata.py <source_directory>")
        print("Example: python ingest_testdata.py C:/Users/you/Downloads/cad_samples")
        return 1

    return ingest(Path(sys.argv[1]))


if __name__ == "__main__":
    sys.exit(main())