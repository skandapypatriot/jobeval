"""Helpers for building test fixture files (STEP, PDF, DXF)."""

from __future__ import annotations

from pathlib import Path

from build123d import Box, Cylinder, export_step


def write_step_block_with_hole(path: Path) -> Path:
    """Write a 40x30x20 mm block with a 12 mm diameter through-hole to STEP."""
    part = Box(40, 30, 20).cut(Cylinder(6, 25))
    export_step(part, str(path))
    return path


def write_pdf_drawing(path: Path) -> Path:
    """Write a simple PDF drawing with text dimensions and a title block."""
    import fitz

    document = fitz.open()
    page = document.new_page()
    page.insert_text((72, 72), "PART NO: ABC-123", fontsize=12)
    page.insert_text((72, 96), "REV: A", fontsize=12)
    page.insert_text((72, 120), "MATERIAL: AL 6061", fontsize=12)
    page.insert_text((72, 144), "TITLE: Test Bracket", fontsize=12)
    page.insert_text((72, 168), "Overall Length 100.0", fontsize=12)
    page.insert_text((72, 192), "Ø10.0 THRU", fontsize=12)
    page.insert_text((72, 216), "FLATNESS 0.1", fontsize=12)
    document.save(str(path))
    document.close()
    return path


def write_dxf_drawing(path: Path) -> Path:
    """Write a simple DXF drawing with text and a circle."""
    import ezdxf

    document = ezdxf.new("R2010")
    msp = document.modelspace()
    msp.add_text("PART NO: DXF-9", dxfattribs={"insert": (0, 0), "height": 5})
    msp.add_text("MATERIAL: ALUMIN", dxfattribs={"insert": (0, 10), "height": 5})
    msp.add_text("Overall Length 100.0", dxfattribs={"insert": (0, 20), "height": 5})
    msp.add_text("Ø10.0 THRU", dxfattribs={"insert": (0, 30), "height": 5})
    msp.add_circle((50, 50), 5)
    document.saveas(str(path))
    return path
