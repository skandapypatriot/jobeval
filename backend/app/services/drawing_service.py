"""PDF and DXF drawing extraction.

Text and vector information is extracted deterministically from the source
file.  OCR is optional; when an OCR engine is not installed the result
explicitly says so instead of pretending that an image was recognised.
"""

from __future__ import annotations

import re
import shutil
from pathlib import Path
from typing import Any

_DIMENSION_PATTERNS = (
    ("diameter", re.compile(r"(?:Ø|DIAM(?:ETER)?)\s*([0-9]+(?:\.[0-9]+)?)", re.I)),
    ("radius", re.compile(r"(?:R|RADIUS)\s*([0-9]+(?:\.[0-9]+)?)", re.I)),
    ("depth", re.compile(r"(?:DEPTH|⌴)\s*([0-9]+(?:\.[0-9]+)?)", re.I)),
    ("thread", re.compile(r"\b(?:M|UNC|UNF)\s*([0-9]+(?:\.[0-9]+)?)", re.I)),
    ("chamfer", re.compile(r"(?:CHAMFER|CHM)\s*([0-9]+(?:\.[0-9]+)?)", re.I)),
    ("fillet_radius", re.compile(r"(?:FILLET)\s*R?\s*([0-9]+(?:\.[0-9]+)?)", re.I)),
    ("angular", re.compile(r"([0-9]+(?:\.[0-9]+)?)\s*°", re.I)),
    (
        "linear",
        re.compile(r"^([0-9]+(?:\.[0-9]+)?)\s*(?:mm|MM)?(?:\s*±\s*([0-9]+(?:\.[0-9]+)?))?$", re.I),
    ),
)


class DrawingService:
    """Extract dimensions, notes, title data, and evidence from drawings."""

    def __init__(self, ocr_languages: list[str] | None = None) -> None:
        from app.core.config import get_settings

        settings = get_settings()
        self.ocr_languages = (
            ocr_languages or settings.OCR_LANGUAGES
            if hasattr(settings, "OCR_LANGUAGES")
            else ["en"]
        )
        self.ocr_available = False
        self.ocr_reason = "OCR is disabled by configuration"
        try:
            if shutil.which("tesseract"):
                self.ocr_available = True
                self.ocr_reason = "Tesseract OCR is available"
            else:
                self.ocr_reason = "Tesseract executable is not installed"
        except Exception:
            self.ocr_reason = "pytesseract is not installed"

    def process_drawing(self, file_path: Path, project_id: str | None = None) -> dict[str, Any]:
        path = Path(file_path)
        suffix = path.suffix.lower()
        if suffix == ".pdf":
            result = self._process_pdf(path)
        elif suffix == ".dxf":
            result = self._process_dxf(path)
        else:
            raise ValueError(f"Unsupported drawing format: {suffix}")
        result["source_file"] = {
            "filename": path.name,
            "path": str(path),
            "size_bytes": path.stat().st_size,
        }
        result["project_id"] = project_id
        result["ocr"] = {
            "available": self.ocr_available,
            "reason": self.ocr_reason,
            "used": False,
        }
        return result

    @staticmethod
    def _bbox(box: Any) -> list[float]:
        values = [round(float(value), 3) for value in box] if box else [0.0, 0.0, 0.0, 0.0]
        # Always return 4 values (x1, y1, x2, y2) so downstream code can index safely.
        while len(values) < 4:
            values.append(0.0)
        return values[:4]

    def _parse_dimensions(
        self, text: str, page: int, bbox: list[float], source: str
    ) -> list[dict[str, Any]]:
        dimensions: list[dict[str, Any]] = []
        for dimension_type, pattern in _DIMENSION_PATTERNS:
            match = pattern.search(text)
            if not match:
                continue
            try:
                value = float(match.group(1))
            except (TypeError, ValueError):
                continue
            tolerance = None
            if len(match.groups()) > 1 and match.group(2):
                tolerance = {
                    "upper": float(match.group(2)),
                    "lower": -float(match.group(2)),
                    "text": match.group(0),
                }
            dimensions.append(
                {
                    "id": f"D-{page}-{len(dimensions):03d}",
                    "type": dimension_type,
                    "value": value,
                    "unit": "mm",
                    "tolerance": tolerance,
                    "text": text,
                    "page": page,
                    "bbox": bbox,
                    "source": source,
                    "confidence": 0.92 if source.endswith("text") else 0.75,
                    "evidence": {"page": page, "bbox": bbox, "text": text, "source": source},
                }
            )
            break
        return dimensions

    @staticmethod
    def _categorise_note(text: str) -> str:
        upper = text.upper()
        if any(
            word in upper for word in ("MATERIAL", "AL 6061", "ALUMIN", "STEEL", "BRASS", "COPPER")
        ):
            return "material"
        if any(word in upper for word in ("FINISH", "ANOD", "PLATE", "PAINT", "COAT")):
            return "finish"
        if any(
            word in upper for word in ("TOLERANCE", "GD&T", "FLATNESS", "POSITION", "PERPENDICULAR")
        ):
            return "gdt_or_tolerance"
        return "general"

    def _extract_gdt(self, text: str, page: int, bbox: list[float]) -> list[dict[str, Any]]:
        patterns = {
            "flatness": r"FLATNESS|⏥",
            "straightness": r"STRAIGHTNESS",
            "circularity": r"CIRCULARITY|ROUNDNESS",
            "cylindricity": r"CYLINDRICITY",
            "parallelism": r"PARALLELISM",
            "perpendicularity": r"PERPENDICULARITY",
            "angularity": r"ANGULARITY",
            "position": r"POSITION|POS",
            "concentricity": r"CONCENTRICITY",
        }
        for name, pattern in patterns.items():
            if re.search(pattern, text, re.I):
                value_match = re.search(r"([0-9]+(?:\.[0-9]+)?)", text)
                return [
                    {
                        "id": f"GT-{page}-001",
                        "type": name,
                        "value": float(value_match.group(1)) if value_match else None,
                        "datums": re.findall(r"\b([A-Z])\b", text)[:3],
                        "text": text,
                        "page": page,
                        "bbox": bbox,
                        "source": "text",
                        "confidence": 0.88,
                        "evidence": {"page": page, "bbox": bbox, "text": text},
                    }
                ]
        return []

    def _title_block(self, texts: list[dict[str, Any]]) -> dict[str, Any] | None:
        if not texts:
            return None
        # Prefer the lower/right portion of a page, but retain all text as a
        # fallback for simple generated drawings.
        candidates = sorted(
            texts,
            key=lambda item: (item.get("bbox", [0, 0, 0, 0])[1], item.get("bbox", [0, 0, 0, 0])[0]),
            reverse=True,
        )
        blob = " ".join(item["text"] for item in candidates)
        fields: dict[str, Any] = {}
        patterns = {
            "part_number": r"(?:PART\s*(?:NO|NUMBER|#)|P/N)\s*[:]?\s*([A-Z0-9._-]+)",
            "revision": r"(?:REV(?:ISION)?)\s*[:]?\s*([A-Z0-9]+)",
            "material": r"(?:MATERIAL|MAT)\s*[:]?\s*([A-Za-z0-9 ._-]+)",
            "finish": r"(?:FINISH)\s*[:]?\s*([A-Za-z0-9 ._-]+)",
            "title": r"(?:TITLE|DESCRIPTION)\s*[:]?\s*([A-Za-z0-9 ._-]+)",
            "scale": r"(?:SCALE)\s*[:]?\s*([0-9:]+)",
        }
        for key, pattern in patterns.items():
            match = re.search(pattern, blob, re.I)
            if match:
                fields[key] = match.group(1).strip()
        return fields or None

    def _process_pdf(self, path: Path) -> dict[str, Any]:
        try:
            import fitz  # type: ignore
        except Exception as exc:
            raise RuntimeError("PDF parsing requires PyMuPDF (fitz)") from exc
        document = fitz.open(str(path))
        pages: list[dict[str, Any]] = []
        try:
            for page_index, page in enumerate(document):
                page_number = page_index + 1
                raw_text = page.get_text("dict")
                texts: list[dict[str, Any]] = []
                dimensions: list[dict[str, Any]] = []
                notes: list[dict[str, Any]] = []
                gdt: list[dict[str, Any]] = []
                for block in raw_text.get("blocks", []):
                    if block.get("type") != 0:
                        continue
                    bbox = self._bbox(block.get("bbox", [0, 0, 0, 0]))
                    text = " ".join(
                        span.get("text", "")
                        for line in block.get("lines", [])
                        for span in line.get("spans", [])
                    ).strip()
                    if not text:
                        continue
                    item = {"text": text, "bbox": bbox, "page": page_number, "source": "pdf_text"}
                    texts.append(item)
                    dimensions.extend(self._parse_dimensions(text, page_number, bbox, "pdf_text"))
                    gdt.extend(self._extract_gdt(text, page_number, bbox))
                    notes.append(
                        {
                            "id": f"N-{page_number}-{len(notes):03d}",
                            "text": text,
                            "category": self._categorise_note(text),
                            "page": page_number,
                            "bbox": bbox,
                            "source": "pdf_text",
                            "confidence": 0.95,
                            "evidence": {"page": page_number, "bbox": bbox, "text": text},
                        }
                    )
                vectors = []
                for drawing in page.get_drawings():
                    vectors.append(
                        {
                            "type": "vector_path",
                            "rect": self._bbox(drawing.get("rect", [0, 0, 0, 0])),
                            "item_count": len(drawing.get("items", [])),
                            "page": page_number,
                            "source": "pdf_vector",
                        }
                    )
                pages.append(
                    {
                        "page": page_number,
                        "width": round(float(page.rect.width), 3),
                        "height": round(float(page.rect.height), 3),
                        "unit": "pt",
                        "texts": texts,
                        "raw_text": texts,
                        "dimensions": dimensions,
                        "notes": notes,
                        "gdt": gdt,
                        "vectors": vectors,
                        "title_block": self._title_block(texts),
                        "source": {"format": "pdf", "page": page_number},
                    }
                )
        finally:
            document.close()
        return self._aggregate(pages, "pdf")

    def _process_dxf(self, path: Path) -> dict[str, Any]:
        try:
            import ezdxf  # type: ignore
        except Exception as exc:
            raise RuntimeError("DXF parsing requires ezdxf") from exc
        document = ezdxf.readfile(str(path))
        page_texts: list[dict[str, Any]] = []
        dimensions: list[dict[str, Any]] = []
        vectors: list[dict[str, Any]] = []
        notes: list[dict[str, Any]] = []
        for entity in document.modelspace():
            dxftype = entity.dxftype()
            try:
                raw_bbox = list(entity.dxf.bbox()) if hasattr(entity.dxf, "bbox") else []
            except Exception:
                raw_bbox = []
            bbox = self._bbox(raw_bbox)
            if dxftype in {"TEXT", "MTEXT", "ATTRIB", "ATTDEF"}:
                text = entity.dxf.text if dxftype == "TEXT" else getattr(entity.dxf, "text", "")
                if not text and dxftype == "MTEXT":
                    text = entity.text
                item = {
                    "text": str(text).strip(),
                    "bbox": bbox,
                    "page": 1,
                    "source": "dxf_text",
                }
                page_texts.append(item)
                dimensions.extend(self._parse_dimensions(item["text"], 1, item["bbox"], "dxf_text"))
                notes.append(
                    {
                        "id": f"N-1-{len(notes):03d}",
                        "text": item["text"],
                        "category": self._categorise_note(item["text"]),
                        "page": 1,
                        "bbox": bbox,
                        "source": "dxf_text",
                        "confidence": 0.95,
                        "evidence": {"page": 1, "bbox": bbox, "text": item["text"]},
                    }
                )
            elif dxftype == "DIMENSION":
                try:
                    measurement = float(entity.get_measurement())
                except Exception:
                    measurement = None
                text = str(entity.dxf.text if hasattr(entity.dxf, "text") else "")
                item = {
                    "id": f"D-DXF-{len(dimensions):03d}",
                    "type": "linear",
                    "value": measurement,
                    "unit": "mm",
                    "text": text,
                    "page": 1,
                    "bbox": bbox,
                    "source": "dxf_dimension",
                    "confidence": 0.9,
                    "evidence": {"page": 1, "bbox": bbox, "entity": dxftype},
                }
                dimensions.append(item)
            elif dxftype in {"LINE", "CIRCLE", "ARC", "LWPOLYLINE", "POLYLINE", "SPLINE"}:
                vectors.append(
                    {
                        "type": dxftype.lower(),
                        "bbox": bbox,
                        "page": 1,
                        "source": "dxf_vector",
                    }
                )
        unit_code = document.header.get("$INSUNITS", 0)
        unit = {1: "inch", 2: "feet", 4: "mm", 5: "cm", 6: "m"}.get(unit_code, "mm")
        page = {
            "page": 1,
            "width": 0.0,
            "height": 0.0,
            "unit": unit,
            "texts": page_texts,
            "raw_text": page_texts,
            "dimensions": dimensions,
            "notes": notes,
            "gdt": [],
            "vectors": vectors,
            "title_block": self._title_block(page_texts),
            "source": {"format": "dxf", "page": 1},
        }
        return self._aggregate([page], "dxf")

    @staticmethod
    def _aggregate(pages: list[dict[str, Any]], format_name: str) -> dict[str, Any]:
        all_text = [text for page in pages for text in page.get("raw_text", [])]
        all_dimensions = [dimension for page in pages for dimension in page.get("dimensions", [])]
        all_notes = [note for page in pages for note in page.get("notes", [])]
        all_gdt = [item for page in pages for item in page.get("gdt", [])]
        vectors = [item for page in pages for item in page.get("vectors", [])]
        material = next(
            (note["text"] for note in all_notes if note["category"] == "material"), None
        )
        finish = next((note["text"] for note in all_notes if note["category"] == "finish"), None)
        title = next((page.get("title_block") for page in pages if page.get("title_block")), None)
        return {
            "format": format_name,
            "pages": pages,
            "total_pages": len(pages),
            "dimensions": all_dimensions,
            "notes": all_notes,
            "gdt": all_gdt,
            "vectors": vectors,
            "candidates": {
                "dimensions": all_dimensions,
                "tolerances": [d for d in all_dimensions if d.get("tolerance")],
                "material": material,
                "finish": finish,
                "title": title,
                "gdt": all_gdt,
            },
            "warnings": []
            if all_text
            else ["No text was found; OCR may be required for scanned drawings."],
        }
