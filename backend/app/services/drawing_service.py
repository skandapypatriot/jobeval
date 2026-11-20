"""Drawing Analysis Service - PDF/DXF parsing and annotation extraction."""

import hashlib
import logging
import math
import re
import time
from pathlib import Path
from typing import Any
from uuid import UUID

import fitz  # PyMuPDF
import cv2
import numpy as np
import pytesseract
from paddleocr import PaddleOCR

from app.core.config import get_settings
from app.schemas.cad_specs import (
    BoundingBox3D, CADSpecs, CrossValidationCheck, CrossValidationReport,
    DrawingAnnotations, DrawingDimension, DrawingNote, DrawingPage, DrawingView,
    FeatureType, GDTAnnotation, GDTSymbol, GeometrySummary, SourceFile,
    SurfaceFinishAnnotation, TitleBlock, UnitSystem, ValidationStatus, Vector3D,
    WarningItem
)
from app.services.geometry_utils import identify_units

settings = get_settings()
logger = logging.getLogger(__name__)

# Initialize PaddleOCR (lazy singleton)
_paddle_ocr: PaddleOCR | None = None


def get_paddle_ocr() -> PaddleOCR:
    """Get or create PaddleOCR instance."""
    global _paddle_ocr
    if _paddle_ocr is None:
        try:
            _paddle_ocr = PaddleOCR(use_angle_cls=True, lang='en')
        except TypeError:
            _paddle_ocr = PaddleOCR(use_angle_cls=True, lang='en', show_log=False)
    return _paddle_ocr


class DrawingService:
    """Service for engineering drawing analysis (PDF/DXF)."""

    def __init__(self) -> None:
        self.settings = settings
        self.ocr_languages = settings.OCR_LANGUAGES
        self.ocr_confidence_threshold = settings.OCR_CONFIDENCE_THRESHOLD
        self.render_dpi = settings.PDF_RENDER_DPI

    # --------------------------------------------------------------------- #
    # Main entry point
    # --------------------------------------------------------------------- #

    def process_drawing(self, file_path: Path, project_id: UUID) -> DrawingAnnotations:
        """Process a drawing file (PDF/DXF) and extract annotations."""
        suffix = file_path.suffix.lower()

        if suffix == ".pdf":
            return self._process_pdf(file_path)
        elif suffix == ".dxf":
            return self._process_dxf(file_path)
        else:
            raise ValueError(f"Unsupported drawing format: {suffix}")

    # --------------------------------------------------------------------- #
    # PDF Processing
    # --------------------------------------------------------------------- #

    def _process_pdf(self, file_path: Path) -> DrawingAnnotations:
        """Process a PDF engineering drawing."""
        start_time = time.time()
        doc = fitz.open(str(file_path))
        total_pages = doc.page_count
        pages: list[DrawingPage] = []

        for page_num in range(total_pages):
            page = doc[page_num]
            page_idx = page_num + 1  # 1-based

            logger.info(f"Processing PDF page {page_idx}/{total_pages}")

            # 1. Extract text blocks with positions
            text_blocks = self._extract_text_blocks(page, page_idx)

            # 2. Extract vector drawings (lines, arcs, curves)
            vector_drawings = self._extract_vector_drawings(page, page_idx)

            # 3. Render page to image for OCR and symbol detection
            pix = page.get_pixmap(dpi=self.render_dpi)
            img_data = np.frombuffer(pix.samples, dtype=np.uint8).reshape(
                pix.height, pix.width, pix.n
            )
            # Convert RGBA/RGB to BGR for OpenCV
            if pix.n == 4:
                img_bgr = cv2.cvtColor(img_data, cv2.COLOR_RGBA2BGR)
            elif pix.n == 3:
                img_bgr = cv2.cvtColor(img_data, cv2.COLOR_RGB2BGR)
            else:
                img_bgr = img_data

            # 4. OCR the page
            ocr_results = self._ocr_page(img_bgr, page_idx)

            # 5. Merge text blocks and OCR results
            all_text = self._merge_text_sources(text_blocks, ocr_results)

            # 6. Extract title block
            title_block = self._extract_title_block(all_text, page_idx, img_bgr)

            # 7. Extract dimensions
            dimensions = self._extract_dimensions(all_text, page_idx, vector_drawings)

            # 8. Extract GD&T annotations
            gd_t = self._extract_gd_t(all_text, page_idx, img_bgr)

            # 9. Extract surface finish annotations
            surface_finish = self._extract_surface_finish(all_text, page_idx, img_bgr)

            # 10. Extract general notes
            notes = self._extract_notes(all_text, page_idx)

            # 11. Detect drawing views
            views = self._detect_views(all_text, vector_drawings, page_idx)

            # 12. Detect units
            unit = self._detect_units(all_text, title_block)

            page_width = pix.width / self.render_dpi * 25.4  # mm
            page_height = pix.height / self.render_dpi * 25.4  # mm

            pages.append(DrawingPage(
                page_num=page_idx,
                width=round(page_width, 2),
                height=round(page_height, 2),
                unit=unit,
                views=views,
                dimensions=dimensions,
                gd_t=gd_t,
                surface_finish=surface_finish,
                notes=notes,
                title_block=title_block,
                raw_text=all_text,
            ))

        doc.close()

        processing_time = time.time() - start_time
        logger.info(f"PDF processing complete: {total_pages} pages in {processing_time:.2f}s")

        return DrawingAnnotations(
            pages=pages,
            total_pages=total_pages,
        )

    # --------------------------------------------------------------------- #
    # Text Extraction
    # --------------------------------------------------------------------- #

    def _extract_text_blocks(self, page: fitz.Page, page_num: int) -> list[dict[str, Any]]:
        """Extract text blocks from a PDF page with positions."""
        blocks = []
        text_dict = page.get_text("dict")

        for block in text_dict.get("blocks", []):
            if block.get("type") != 0:  # Skip non-text blocks
                continue

            bbox = block.get("bbox", [0, 0, 0, 0])
            block_text = ""

            for line in block.get("lines", []):
                for span in line.get("spans", []):
                    block_text += span.get("text", "") + " "
                block_text = block_text.rstrip() + "\n"

            block_text = block_text.strip()
            if not block_text:
                continue

            blocks.append({
                "text": block_text,
                "x": bbox[0],
                "y": bbox[1],
                "w": bbox[2] - bbox[0],
                "h": bbox[3] - bbox[1],
                "page": page_num,
                "source": "pdf_vector",
                "confidence": 1.0,
            })

        return blocks

    def _ocr_page(self, image: np.ndarray, page_num: int) -> list[dict[str, Any]]:
        """Run OCR on a rendered page image."""
        results = []

        # Tesseract OCR
        try:
            tesseract_data = pytesseract.image_to_data(
                image,
                config=f"--psm 11 -l {'+'.join(self.ocr_languages)}",
                output_type=pytesseract.Output.DICT,
            )

            for i in range(len(tesseract_data["text"])):
                text = tesseract_data["text"][i].strip()
                if not text:
                    continue

                conf = float(tesseract_data["conf"][i])
                if conf < self.ocr_confidence_threshold * 100:
                    continue

                x = tesseract_data["left"][i]
                y = tesseract_data["top"][i]
                w = tesseract_data["width"][i]
                h = tesseract_data["height"][i]

                results.append({
                    "text": text,
                    "x": x,
                    "y": y,
                    "w": w,
                    "h": h,
                    "page": page_num,
                    "source": "tesseract",
                    "confidence": conf / 100.0,
                })
        except Exception as e:
            logger.warning(f"Tesseract OCR failed: {e}")

        # PaddleOCR as supplement
        try:
            paddle_results = get_paddle_ocr().ocr(image, cls=True)
            if paddle_results and paddle_results[0]:
                for line in paddle_results[0]:
                    box = line[0]
                    text = line[1][0]
                    conf = float(line[1][1])

                    if conf < self.ocr_confidence_threshold:
                        continue

                    # Box is [[x1,y1], [x2,y1], [x2,y2], [x1,y2]]
                    x_coords = [p[0] for p in box]
                    y_coords = [p[1] for p in box]
                    x = min(x_coords)
                    y = min(y_coords)
                    w = max(x_coords) - x
                    h = max(y_coords) - y

                    results.append({
                        "text": text,
                        "x": int(x),
                        "y": int(y),
                        "w": int(w),
                        "h": int(h),
                        "page": page_num,
                        "source": "paddleocr",
                        "confidence": conf,
                    })
        except Exception as e:
            logger.warning(f"PaddleOCR failed: {e}")

        return results

    def _merge_text_sources(
        self,
        pdf_text: list[dict[str, Any]],
        ocr_text: list[dict[str, Any]],
    ) -> list[dict[str, Any]]:
        """Merge PDF vector text and OCR results, deduplicating overlaps."""
        merged = list(pdf_text)

        # Add OCR results that don't overlap significantly with PDF text
        for ocr_item in ocr_text:
            is_duplicate = False
            for pdf_item in pdf_text:
                if self._boxes_overlap(ocr_item, pdf_item, threshold=0.7):
                    is_duplicate = True
                    # Keep higher confidence
                    if ocr_item["confidence"] > pdf_item["confidence"]:
                        merged.remove(pdf_item)
                        merged.append(ocr_item)
                    break

            if not is_duplicate:
                merged.append(ocr_item)

        return merged

    def _boxes_overlap(self, box1: dict, box2: dict, threshold: float = 0.5) -> bool:
        """Check if two bounding boxes overlap above a threshold."""
        x1_min, y1_min = box1["x"], box1["y"]
        x1_max, y1_max = box1["x"] + box1["w"], box1["y"] + box1["h"]
        x2_min, y2_min = box2["x"], box2["y"]
        x2_max, y2_max = box2["x"] + box2["w"], box2["y"] + box2["h"]

        inter_x = max(0, min(x1_max, x2_max) - max(x1_min, x2_min))
        inter_y = max(0, min(y1_max, y2_max) - max(y1_min, y2_min))
        inter_area = inter_x * inter_y

        if inter_area == 0:
            return False

        area1 = box1["w"] * box1["h"]
        area2 = box2["w"] * box2["h"]
        min_area = min(area1, area2)

        return (inter_area / min_area) >= threshold if min_area > 0 else False

    # --------------------------------------------------------------------- #
    # Dimension Extraction
    # --------------------------------------------------------------------- #

    def _extract_dimensions(
        self,
        text_items: list[dict[str, Any]],
        page_num: int,
        vector_drawings: list[dict[str, Any]],
    ) -> list[DrawingDimension]:
        """Extract dimensions from text items."""
        dimensions = []
        dim_id_counter = 0

        # Patterns for different dimension types
        patterns = {
            "diameter": re.compile(r'(?:Ø|DIAM|DIAMETER)\s*([\d.]+)\s*(?:±\s*([\d.]+))?', re.IGNORECASE),
            "radius": re.compile(r'(?:R|RADIUS)\s*([\d.]+)\s*(?:±\s*([\d.]+))?', re.IGNORECASE),
            "depth": re.compile(r'(?:DEPTH|⌴)\s*([\d.]+)', re.IGNORECASE),
            "thread": re.compile(r'(?:M|UNC|UNF|UNEF)\s*([\d.]+)\s*(?:x\s*([\d.]+))?\s*(?:-)?\s*(\d+)?', re.IGNORECASE),
            "linear": re.compile(r'^([\d.]+)\s*(?:±\s*([\d.]+))?$'),
            "angular": re.compile(r'([\d.]+)\s*°', re.IGNORECASE),
            "chamfer": re.compile(r'(?:CHAMFER|CHM)\s*([\d.]+)', re.IGNORECASE),
            "fillet": re.compile(r'(?:FILLET|R)\s*([\d.]+)', re.IGNORECASE),
        }

        for item in text_items:
            text = item["text"].strip()
            if not text:
                continue

            matched = False

            # Try diameter
            m = patterns["diameter"].search(text)
            if m:
                try:
                    value = float(m.group(1))
                    tolerance_upper = float(m.group(2)) if m.group(2) else None
                    tolerance_lower = -tolerance_upper if tolerance_upper else None
                    dimensions.append(DrawingDimension(
                        id=f"D-{dim_id_counter:04d}",
                        type="diameter",
                        value=value,
                        unit=UnitSystem.MM,
                        tolerance={"upper": tolerance_upper, "lower": tolerance_lower} if tolerance_upper else None,
                        text=text,
                        position=[item["x"], item["y"]],
                        page=page_num,
                        confidence=item["confidence"],
                    ))
                    dim_id_counter += 1
                    matched = True
                except (ValueError, TypeError):
                    pass

            # Try radius
            if not matched:
                m = patterns["radius"].search(text)
                if m:
                    try:
                        value = float(m.group(1))
                        tolerance_upper = float(m.group(2)) if m.group(2) else None
                        dimensions.append(DrawingDimension(
                            id=f"D-{dim_id_counter:04d}",
                            type="radius",
                            value=value,
                            unit=UnitSystem.MM,
                            tolerance={"upper": tolerance_upper, "lower": -tolerance_upper} if tolerance_upper else None,
                            text=text,
                            position=[item["x"], item["y"]],
                            page=page_num,
                            confidence=item["confidence"],
                        ))
                        dim_id_counter += 1
                        matched = True
                    except (ValueError, TypeError):
                        pass

            # Try thread callout
            if not matched:
                m = patterns["thread"].search(text)
                if m:
                    try:
                        major_dia = float(m.group(1))
                        pitch = float(m.group(2)) if m.group(2) else None
                        thread_class = m.group(3) if m.group(3) else None
                        dimensions.append(DrawingDimension(
                            id=f"D-{dim_id_counter:04d}",
                            type="thread",
                            value=major_dia,
                            unit=UnitSystem.MM,
                            tolerance={"pitch": pitch, "class": thread_class} if pitch or thread_class else None,
                            text=text,
                            position=[item["x"], item["y"]],
                            page=page_num,
                            confidence=item["confidence"],
                        ))
                        dim_id_counter += 1
                        matched = True
                    except (ValueError, TypeError):
                        pass

            # Try linear dimension
            if not matched:
                m = patterns["linear"].match(text)
                if m and len(text) < 20:  # Avoid matching long text blocks
                    try:
                        value = float(m.group(1))
                        tolerance_upper = float(m.group(2)) if m.group(2) else None
                        dimensions.append(DrawingDimension(
                            id=f"D-{dim_id_counter:04d}",
                            type="linear",
                            value=value,
                            unit=UnitSystem.MM,
                            tolerance={"upper": tolerance_upper, "lower": -tolerance_upper} if tolerance_upper else None,
                            text=text,
                            position=[item["x"], item["y"]],
                            page=page_num,
                            confidence=item["confidence"],
                        ))
                        dim_id_counter += 1
                        matched = True
                    except (ValueError, TypeError):
                        pass

            # Try angular dimension
            if not matched:
                m = patterns["angular"].search(text)
                if m:
                    try:
                        value = float(m.group(1))
                        dimensions.append(DrawingDimension(
                            id=f"D-{dim_id_counter:04d}",
                            type="angular",
                            value=value,
                            unit=UnitSystem.MM,  # Angular is degrees
                            text=text,
                            position=[item["x"], item["y"]],
                            page=page_num,
                            confidence=item["confidence"],
                        ))
                        dim_id_counter += 1
                        matched = True
                    except (ValueError, TypeError):
                        pass

        return dimensions

    # --------------------------------------------------------------------- #
    # GD&T Extraction
    # --------------------------------------------------------------------- #

    def _extract_gd_t(
        self,
        text_items: list[dict[str, Any]],
        page_num: int,
        image: np.ndarray,
    ) -> list[GDTAnnotation]:
        """Extract GD&T annotations from text and symbol detection."""
        gd_t_annotations = []
        gt_id_counter = 0

        # GD&T symbol patterns
        gd_patterns = {
            "flatness": re.compile(r'(?:⏥|FLATNESS)', re.IGNORECASE),
            "straightness": re.compile(r'(?:—|STRAIGHTNESS)', re.IGNORECASE),
            "circularity": re.compile(r'(?:○|CIRCULARITY|ROUNDNESS)', re.IGNORECASE),
            "cylindricity": re.compile(r'(?:⌭|CYLINDRICITY)', re.IGNORECASE),
            "parallelism": re.compile(r'(?:∥|PARALLELISM)', re.IGNORECASE),
            "perpendicularity": re.compile(r'(?:⊥|PERPENDICULARITY)', re.IGNORECASE),
            "angularity": re.compile(r'(?:∠|ANGULARITY)', re.IGNORECASE),
            "position": re.compile(r'(?:⌖|POSITION|POS)', re.IGNORECASE),
            "concentricity": re.compile(r'(?:◎|CONCENTRICITY)', re.IGNORECASE),
            "symmetry": re.compile(r'(?:∣|SYMMETRY)', re.IGNORECASE),
            "runout": re.compile(r'(?:↱|RUNOUT)', re.IGNORECASE),
        }

        # Datums pattern (letters in boxes)
        datum_pattern = re.compile(r'\b([A-Z])\b')

        for item in text_items:
            text = item["text"].strip()
            if not text:
                continue

            matched_type = None
            matched_symbol = None

            for gt_type, pattern in gd_patterns.items():
                if pattern.search(text):
                    matched_type = gt_type
                    matched_symbol = pattern.pattern
                    break

            if matched_type:
                # Extract value (number after symbol)
                value_match = re.search(r'([\d.]+)', text)
                try:
                    value = float(value_match.group(1)) if value_match else None
                except (ValueError, TypeError):
                    value = None

                # Extract datums
                datums = datum_pattern.findall(text)

                # Map to GDTSymbol enum
                try:
                    gt_enum = GDTSymbol(matched_type)
                except ValueError:
                    gt_enum = GDTSymbol.POSITION  # fallback

                gd_t_annotations.append(GDTAnnotation(
                    id=f"GT-{gt_id_counter:04d}",
                    type=gt_enum,
                    value=value,
                    datums=datums[:3],  # Max 3 datums typically
                    text=text,
                    position=[item["x"], item["y"]],
                    page=page_num,
                    confidence=item["confidence"],
                ))
                gt_id_counter += 1

        return gd_t_annotations

    # --------------------------------------------------------------------- #
    # Surface Finish Extraction
    # --------------------------------------------------------------------- #

    def _extract_surface_finish(
        self,
        text_items: list[dict[str, Any]],
        page_num: int,
        image: np.ndarray,
    ) -> list[SurfaceFinishAnnotation]:
        """Extract surface finish annotations."""
        surface_finish = []
        sf_id_counter = 0

        # Surface finish patterns
        sf_patterns = [
            re.compile(r'(?:Ra)\s*([\d.]+)', re.IGNORECASE),
            re.compile(r'(?:Rz)\s*([\d.]+)', re.IGNORECASE),
            re.compile(r'(?:⌇|SURFACE\s*FINISH)', re.IGNORECASE),
        ]

        for item in text_items:
            text = item["text"].strip()
            if not text:
                continue

            ra_match = re.search(r'(?:Ra)\s*([\d.]+)', text, re.IGNORECASE)
            rz_match = re.search(r'(?:Rz)\s*([\d.]+)', text, re.IGNORECASE)

            if ra_match or rz_match or re.search(r'⌇', text):
                try:
                    ra = float(ra_match.group(1)) if ra_match else None
                except (ValueError, TypeError):
                    ra = None
                try:
                    rz = float(rz_match.group(1)) if rz_match else None
                except (ValueError, TypeError):
                    rz = None

                surface_finish.append(SurfaceFinishAnnotation(
                    id=f"SF-{sf_id_counter:04d}",
                    symbol="⌇",
                    ra=ra,
                    rz=rz,
                    text=text,
                    position=[item["x"], item["y"]],
                    page=page_num,
                    confidence=item["confidence"],
                ))
                sf_id_counter += 1

        return surface_finish

    # --------------------------------------------------------------------- #
    # Notes Extraction
    # --------------------------------------------------------------------- #

    def _extract_notes(
        self,
        text_items: list[dict[str, Any]],
        page_num: int,
    ) -> list[DrawingNote]:
        """Extract general notes from text items."""
        notes = []
        note_id_counter = 0

        note_categories = {
            "material": re.compile(r'(?:MATERIAL|MAT|AL\s*6061|STAINLESS|BRASS|COPPER|STEEL)', re.IGNORECASE),
            "finish": re.compile(r'(?:FINISH|ANODIZE|PLATE|PAINT|COAT)', re.IGNORECASE),
            "heat_treat": re.compile(r'(?:HEAT\s*TREAT|TEMPER|ANNEAL|HARDEN)', re.IGNORECASE),
            "general": re.compile(r'(?:NOTE|GENERAL|REMARK)', re.IGNORECASE),
        }

        for item in text_items:
            text = item["text"].strip()
            if not text:
                continue

            category = "general"
            for cat_name, pattern in note_categories.items():
                if pattern.search(text):
                    category = cat_name
                    break

            notes.append(DrawingNote(
                id=f"N-{note_id_counter:04d}",
                text=text,
                category=category,
                position=[item["x"], item["y"]],
                page=page_num,
                confidence=item["confidence"],
            ))
            note_id_counter += 1

        return notes

    # --------------------------------------------------------------------- #
    # Title Block Extraction
    # --------------------------------------------------------------------- #

    def _extract_title_block(
        self,
        text_items: list[dict[str, Any]],
        page_num: int,
        image: np.ndarray,
    ) -> TitleBlock | None:
        """Extract title block information from drawing."""
        # Look for title block in bottom-right corner typically
        # Title blocks contain: part number, revision, material, scale, etc.

        tb_text = ""
        for item in text_items:
            # Check if in bottom region (title block area)
            if item["y"] > image.shape[0] * 0.85:  # Bottom 15%
                tb_text += item["text"] + " "

        if not tb_text.strip():
            return None

        # Extract fields using patterns
        part_number = None
        revision = None
        material = None
        finish = None
        scale = None
        sheet = None

        patterns = {
            "part_number": re.compile(r'(?:PART\s*NO|P/N|PART\s*#)\s*[:]?\s*([A-Z0-9\-]+)', re.IGNORECASE),
            "revision": re.compile(r'(?:REV|REVISION)\s*[:]?\s*([A-Z0-9]+)', re.IGNORECASE),
            "material": re.compile(r'(?:MATERIAL|MAT)\s*[:]?\s*([A-Z0-9\s]+)', re.IGNORECASE),
            "finish": re.compile(r'(?:FINISH)\s*[:]?\s*([A-Z0-9\s]+)', re.IGNORECASE),
            "scale": re.compile(r'(?:SCALE)\s*[:]?\s*([\d:]+)', re.IGNORECASE),
            "sheet": re.compile(r'(?:SHEET)\s*[:]?\s*(\d+)\s*(?:OF\s*(\d+))?', re.IGNORECASE),
        }

        for field, pattern in patterns.items():
            m = pattern.search(tb_text)
            if m:
                if field == "part_number":
                    part_number = m.group(1)
                elif field == "revision":
                    revision = m.group(1)
                elif field == "material":
                    material = m.group(1).strip()
                elif field == "finish":
                    finish = m.group(1).strip()
                elif field == "scale":
                    scale = m.group(1)
                elif field == "sheet":
                    sheet = m.group(1)

        return TitleBlock(
            part_number=part_number,
            revision=revision,
            material=material,
            finish=finish,
            scale=scale,
            sheet=sheet,
        )

    # --------------------------------------------------------------------- #
    # View Detection
    # --------------------------------------------------------------------- #

    def _detect_views(
        self,
        text_items: list[dict[str, Any]],
        vector_drawings: list[dict[str, Any]],
        page_num: int,
    ) -> list[DrawingView]:
        """Detect orthographic and section views on the page."""
        views = []
        view_id_counter = 0

        view_keywords = {
            "TOP": ["TOP", "PLAN"],
            "FRONT": ["FRONT", "ELEVATION", "FRONTAL"],
            "SIDE": ["SIDE", "PROFILE"],
            "RIGHT": ["RIGHT", "R.H."],
            "LEFT": ["LEFT", "L.H."],
            "ISOMETRIC": ["ISO", "ISOMETRIC"],
            "SECTION": ["SECTION", "SECT", "A-A", "B-B"],
            "DETAIL": ["DETAIL", "DET"],
        }

        for item in text_items:
            text = item["text"].strip().upper()
            if not text:
                continue

            view_type = "orthographic"
            view_label = None

            for label, keywords in view_keywords.items():
                for kw in keywords:
                    if kw in text:
                        view_label = label
                        if label == "ISOMETRIC":
                            view_type = "isometric"
                        elif label == "SECTION":
                            view_type = "section"
                        elif label == "DETAIL":
                            view_type = "detail"
                        break
                if view_label:
                    break

            if view_label:
                views.append(DrawingView(
                    label=view_label,
                    type=view_type,
                    bbox=[item["x"], item["y"], item["w"], item["h"]],
                    scale=None,
                    projection=None,
                ))
                view_id_counter += 1

        return views

    # --------------------------------------------------------------------- #
    # Unit Detection
    # --------------------------------------------------------------------- #

    def _detect_units(
        self,
        text_items: list[dict[str, Any]],
        title_block: TitleBlock | None,
    ) -> UnitSystem:
        """Detect drawing units from text and title block."""
        # Check title block first
        if title_block and title_block.units:
            return title_block.units

        # Scan text for unit indicators
        all_text = " ".join(item["text"] for item in text_items).upper()

        if re.search(r'(?:MM|MILLIMETER)', all_text):
            return UnitSystem.MM
        elif re.search(r'(?:INCH|IN|\")', all_text):
            return UnitSystem.INCH
        elif re.search(r'(?:CM|CENTIMETER)', all_text):
            return UnitSystem.CM

        return UnitSystem.MM  # Default

    # --------------------------------------------------------------------- #
    # Vector Drawing Extraction (placeholder)
    # --------------------------------------------------------------------- #

    def _extract_vector_drawings(self, page: fitz.Page, page_num: int) -> list[dict[str, Any]]:
        """Extract vector drawing elements (lines, arcs, etc.)."""
        drawings = []
        paths = page.get_drawings()

        for path in paths:
            items = path.get("items", [])
            for item in items:
                drawings.append({
                    "type": item[0],
                    "rect": path.get("rect", [0, 0, 0, 0]),
                    "page": page_num,
                })

        return drawings

    # --------------------------------------------------------------------- #
    # DXF Processing (placeholder)
    # --------------------------------------------------------------------- #

    def _process_dxf(self, file_path: Path) -> DrawingAnnotations:
        """Process a DXF drawing file."""
        # TODO: Implement with ezdxf
        logger.warning("DXF processing not yet implemented")
        return DrawingAnnotations(pages=[], total_pages=0)

    # --------------------------------------------------------------------- #
    # Cross-Validation
    # --------------------------------------------------------------------- #

    def compare_with_model(
        self,
        drawing_annotations: DrawingAnnotations,
        geometry_summary: GeometrySummary | None,
        model_features: list[Any],
    ) -> CrossValidationReport:
        """Compare drawing annotations with 3D model features."""
        checks = []
        summary = {
            "matches": 0,
            "mismatches": 0,
            "drawing_only": 0,
            "model_only": 0,
            "within_tolerance": 0,
        }

        # Extract model dimensions for comparison
        model_dims = self._extract_model_dimensions(geometry_summary, model_features)

        # Compare overall dimensions
        if geometry_summary:
            bbox = geometry_summary.bbox
            model_length = bbox.max.x - bbox.min.x
            model_width = bbox.max.y - bbox.min.y
            model_height = bbox.max.z - bbox.min.z

            # Find drawing overall dimensions
            drawing_lengths = [
                d for d in self._get_all_dimensions(drawing_annotations)
                if d.type == "linear" and abs(d.value - model_length) < 50
            ]

            if drawing_lengths:
                for dd in drawing_lengths[:1]:
                    diff = abs(dd.value - model_length)
                    status = ValidationStatus.MATCH if diff < 1.0 else ValidationStatus.MISMATCH
                    if status == ValidationStatus.MATCH:
                        summary["matches"] += 1
                    else:
                        summary["mismatches"] += 1
                    checks.append(CrossValidationCheck(
                        property="overall_length",
                        drawing=dd.value,
                        model=round(model_length, 2),
                        status=status,
                        tolerance=1.0,
                        details=f"Drawing: {dd.value}mm, Model: {model_length:.2f}mm, diff: {diff:.2f}mm",
                    ))
            else:
                summary["drawing_only"] += 1
                checks.append(CrossValidationCheck(
                    property="overall_length",
                    drawing=None,
                    model=round(model_length, 2),
                    status=ValidationStatus.MODEL_ONLY,
                    details="Dimension not found on drawing",
                ))

        # Compare hole counts
        drawing_holes = len([
            d for d in self._get_all_dimensions(drawing_annotations)
            if d.type in ("diameter", "thread")
        ])
        model_holes = len([
            f for f in model_features
            if f.type in ("through_hole", "blind_hole", "counterbore", "countersink")
        ])

        if drawing_holes == model_holes and drawing_holes > 0:
            summary["matches"] += 1
            checks.append(CrossValidationCheck(
                property="hole_count",
                drawing=drawing_holes,
                model=model_holes,
                status=ValidationStatus.MATCH,
                details=f"Both show {drawing_holes} holes",
            ))
        elif drawing_holes != model_holes:
            summary["mismatches"] += 1
            checks.append(CrossValidationCheck(
                property="hole_count",
                drawing=drawing_holes,
                model=model_holes,
                status=ValidationStatus.MISMATCH,
                details=f"Drawing: {drawing_holes}, Model: {model_holes}",
            ))

        # Material comparison
        drawing_material = self._extract_drawing_material(drawing_annotations)
        model_material = self._extract_model_material(model_features)

        if drawing_material and model_material:
            if drawing_material.lower() == model_material.lower():
                summary["matches"] += 1
                checks.append(CrossValidationCheck(
                    property="material",
                    drawing=drawing_material,
                    model=model_material,
                    status=ValidationStatus.MATCH,
                ))
            else:
                summary["mismatches"] += 1
                checks.append(CrossValidationCheck(
                    property="material",
                    drawing=drawing_material,
                    model=model_material,
                    status=ValidationStatus.MISMATCH,
                ))
        elif drawing_material and not model_material:
            summary["drawing_only"] += 1
            checks.append(CrossValidationCheck(
                property="material",
                drawing=drawing_material,
                model=None,
                status=ValidationStatus.DRAWING_ONLY,
            ))

        return CrossValidationReport(checks=checks, summary=summary)

    def _get_all_dimensions(self, annotations: DrawingAnnotations) -> list[DrawingDimension]:
        """Get all dimensions from all pages."""
        dims = []
        for page in annotations.pages:
            dims.extend(page.dimensions)
        return dims

    def _extract_model_dimensions(
        self,
        geometry_summary: GeometrySummary | None,
        model_features: list[Any],
    ) -> dict[str, Any]:
        """Extract comparable dimensions from model."""
        dims = {}
        if geometry_summary:
            bbox = geometry_summary.bbox
            dims["length"] = bbox.max.x - bbox.min.x
            dims["width"] = bbox.max.y - bbox.min.y
            dims["height"] = bbox.max.z - bbox.min.z
            dims["volume"] = geometry_summary.volume
        return dims

    def _extract_drawing_material(self, annotations: DrawingAnnotations) -> str | None:
        """Extract material from drawing notes/title block."""
        for page in annotations.pages:
            if page.title_block and page.title_block.material:
                return page.title_block.material
            for note in page.notes:
                if note.category == "material":
                    return note.text
        return None

    def _extract_model_material(self, model_features: list[Any]) -> str | None:
        """Extract material from model (if specified)."""
        # STEP files may contain material info
        # For now return None as it's typically not in STEP
        return None