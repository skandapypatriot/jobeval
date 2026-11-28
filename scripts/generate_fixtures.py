"""Generate deterministic JobEval CAD and drawing fixtures.

Usage (from the repository root)::

    python scripts/generate_fixtures.py
    python scripts/generate_fixtures.py --output fixtures --force

The STEP files are produced with build123d 0.13 (OCP/OCCT), the PDF with
PyMuPDF, and the DXF with ezdxf.  A fixed export timestamp keeps the fixture
bytes deterministic for the same library versions.
"""

from __future__ import annotations

import argparse
from datetime import datetime
from pathlib import Path

from build123d import (
    Align,
    Axis,
    Box,
    Compound,
    Cone,
    Cylinder,
    Location,
    Plane,
    Pos,
    chamfer,
    export_step,
    fillet,
)
import ezdxf
import fitz


FIXED_TIMESTAMP = datetime(2024, 1, 1, 0, 0, 0)


def export(name: str, shape, output: Path, unit=None) -> None:
    kwargs = {"timestamp": FIXED_TIMESTAMP}
    if unit is not None:
        kwargs["unit"] = unit
    export_step(shape, output, **kwargs)


def make_step_cases(output: Path) -> None:
    # A simple known block: 50 x 30 x 10 mm, volume 15,000 mm^3.
    export("known_block.step", Box(50, 30, 10), output / "known_block.step")

    # Through and blind holes in one solid.
    holes = Box(50, 30, 10)
    holes -= Pos(-12, 0, 0) * Cylinder(5, 20, align=(Align.CENTER, Align.CENTER, Align.CENTER))
    holes -= Pos(12, 0, 0) * Cylinder(4, 20, align=(Align.CENTER, Align.CENTER, Align.CENTER))
    export("holes.step", holes, output / "holes.step")

    # Coaxial counterbore and a countersink candidate.
    counter = Box(50, 30, 10)
    counter -= Pos(-12, 0, 0) * Cylinder(3, 20, align=(Align.CENTER, Align.CENTER, Align.CENTER))
    counter -= Pos(-12, 0, 4) * Cylinder(6, 4, align=(Align.CENTER, Align.CENTER, Align.CENTER))
    counter -= Pos(12, 0, 0) * Cylinder(3, 20, align=(Align.CENTER, Align.CENTER, Align.CENTER))
    # A simple conical cut is represented by a tapered cutter.
    countersink = Box(50, 30, 10)
    countersink -= Pos(12, 0, 0) * Cylinder(3, 20, align=(Align.CENTER, Align.CENTER, Align.CENTER))
    countersink -= Pos(12, 0, 3) * Cone(6, 3, 4, align=(Align.CENTER, Align.CENTER, Align.CENTER))
    export("counterbore_countersink.step", counter, output / "counterbore_countersink.step")
    export("countersink.step", countersink, output / "countersink.step")

    # Open slot and a rectangular pocket.
    slot = Box(50, 30, 10)
    slot -= Pos(0, 0, 2) * Box(24, 6, 6, align=(Align.CENTER, Align.CENTER, Align.CENTER))
    pocket = Box(50, 30, 10)
    pocket -= Pos(0, 0, 2) * Box(16, 12, 6, align=(Align.CENTER, Align.CENTER, Align.CENTER))
    export("slot.step", slot, output / "slot.step")
    export("pocket.step", pocket, output / "pocket.step")

    # A shoulder/step and a filleted/chamfered edge.
    stepped = Box(50, 30, 10)
    stepped -= Pos(15, 0, 0) * Box(20, 30, 10, align=(Align.CENTER, Align.CENTER, Align.CENTER))
    export("step.step", stepped, output / "step.step")
    filleted = Box(50, 30, 10)
    try:
        vertical_edges = filleted.edges().filter_by(Axis.Z)
        filleted = fillet(vertical_edges, radius=2)
    except Exception:
        # Keep fixture generation useful on minor build123d API differences.
        pass
    export("fillet.step", filleted, output / "fillet.step")
    chamfered = Box(50, 30, 10)
    try:
        vertical_edges = chamfered.edges().filter_by(Axis.Z)
        chamfered = chamfer(vertical_edges, length=1)
    except Exception:
        pass
    export("chamfer.step", chamfered, output / "chamfer.step")

    # Repeated holes are useful for pattern/dedup tests.
    repeated = Box(60, 30, 10)
    for x in (-20, -7, 7, 20):
        repeated -= Pos(x, 0, 0) * Cylinder(3, 20, align=(Align.CENTER, Align.CENTER, Align.CENTER))
    export("repeated_holes.step", repeated, output / "repeated_holes.step")

    # A compound with two independent solids.
    body_a = Pos(-20, 0, 0) * Box(20, 20, 10)
    body_b = Pos(20, 0, 0) * Box(20, 20, 10)
    try:
        multi = Compound(children=[body_a, body_b])
    except Exception:
        multi = body_a + body_b
    export("multi_body.step", multi, output / "multi_body.step")

    # Explicit inch export (1 x 2 x 0.5 inch).
    export("inch.step", Box(1, 2, 0.5), output / "inch.step", unit="in")

    # Deliberately invalid STEP content.  The API must reject it during
    # content validation and never attempt a silent repair.
    (output / "invalid.step").write_text("ISO-10303-21;\nHEADER;\nthis is not a valid STEP exchange file\nENDSEC;\nEND-ISO-10303-21;\n", encoding="utf-8")


def make_pdf(output: Path) -> None:
    document = fitz.open()
    page = document.new_page(width=842, height=595)  # A4 landscape
    page.insert_text((50, 60), "JOBEVAL DEMO DRAWING", fontsize=18)
    page.insert_text((50, 100), "PART NO: DEMO-001", fontsize=12)
    page.insert_text((50, 125), "MATERIAL: ALUMINUM 6061", fontsize=12)
    page.insert_text((50, 150), "FINISH: ANODIZE", fontsize=12)
    page.insert_text((50, 190), "LENGTH: 55 mm", fontsize=12)  # deliberate mismatch: model is 50 mm
    page.insert_text((50, 220), "WIDTH: 30 mm", fontsize=12)
    page.insert_text((50, 250), "HEIGHT: 10 mm", fontsize=12)
    page.insert_text((50, 290), "Ø10 THRU 2X", fontsize=12)
    page.insert_text((50, 320), "TOLERANCE: ±0.1 mm", fontsize=12)
    page.insert_text((50, 360), "POSITION: A B", fontsize=12)
    document.save(str(output / "known_block.pdf"), deflate=True)
    document.close()


def make_dxf(output: Path) -> None:
    document = ezdxf.new("R2010", setup=True)
    document.header["$INSUNITS"] = 4  # millimetres
    modelspace = document.modelspace()
    modelspace.add_line((0, 0), (50, 0))
    modelspace.add_line((50, 0), (50, 30))
    modelspace.add_line((50, 30), (0, 30))
    modelspace.add_line((0, 30), (0, 0))
    modelspace.add_text("PART NO: DEMO-001", dxfattribs={"height": 2}).set_placement((0, 40))
    modelspace.add_text("LENGTH: 50 mm", dxfattribs={"height": 2}).set_placement((0, 45))
    modelspace.add_text("MATERIAL: ALUMINUM 6061", dxfattribs={"height": 2}).set_placement((0, 50))
    modelspace.add_text("Ø10 THRU", dxfattribs={"height": 2}).set_placement((0, 55))
    document.saveas(output / "known_block.dxf")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=Path(__file__).resolve().parents[1] / "fixtures")
    parser.add_argument("--force", action="store_true", help="overwrite existing fixtures")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    existing = list(output.glob("*"))
    if existing and not args.force:
        print(f"Fixtures already exist in {output}; use --force to overwrite.")
        return
    make_step_cases(output)
    make_pdf(output)
    make_dxf(output)
    print(f"Generated {len(list(output.iterdir()))} fixtures in {output}")


if __name__ == "__main__":
    main()
